"""
Script de Migración Automática de SQLite a MySQL para FarmaControl
Permite transferir productos, lotes, clientes, médicos, ventas, kardex y usuarios
desde 'farmacia.db' directamente hacia tu base de datos MySQL local o remota.
"""

import sys
import getpass
import sqlalchemy
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.models import Base, Usuario, Medico, Enfermedad, Cliente, Producto, Lote, Venta, VentaDetalle, VentaDetalleLote, KardexMovimiento, TurnoCaja, Devolucion, DevolucionDetalle, cliente_enfermedades
from app.database import DEFAULT_DB_PATH

def migrar(mysql_user: str, mysql_pass: str, mysql_host: str = "localhost", mysql_port: int = 3306, mysql_db: str = "farmacontrol_db"):
    print(f"\n1. Conectando a SQLite origen ({DEFAULT_DB_PATH})...")
    sqlite_url = f"sqlite:///{DEFAULT_DB_PATH}"
    sqlite_engine = create_engine(sqlite_url)
    SqliteSession = sessionmaker(bind=sqlite_engine)
    src = SqliteSession()

    print(f"2. Conectando a MySQL destino ({mysql_host}:{mysql_port})...")
    # Conexión inicial sin especificar base de datos para crearla si no existe
    root_mysql_url = f"mysql+pymysql://{mysql_user}:{mysql_pass}@{mysql_host}:{mysql_port}"
    temp_engine = create_engine(root_mysql_url)
    with temp_engine.connect() as conn:
        conn.exec_driver_sql(f"CREATE DATABASE IF NOT EXISTS `{mysql_db}` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;")
        print(f"   ✓ Base de datos MySQL `{mysql_db}` verificada/creada.")

    # Conectar a la base de datos MySQL específica
    mysql_url = f"mysql+pymysql://{mysql_user}:{mysql_pass}@{mysql_host}:{mysql_port}/{mysql_db}"
    mysql_engine = create_engine(mysql_url, pool_pre_ping=True)
    
    print("3. Creando tablas en MySQL según los modelos de FarmaControl...")
    Base.metadata.create_all(bind=mysql_engine)
    MysqlSession = sessionmaker(bind=mysql_engine)
    dst = MysqlSession()

    try:
        # Lista ordenada de tablas para respetar llaves foráneas
        tablas_modelos = [
            ("Usuarios", Usuario),
            ("Médicos", Medico),
            ("Enfermedades CIE-10", Enfermedad),
            ("Clientes", Cliente),
            ("Productos", Producto),
            ("Lotes", Lote),
            ("Turnos de Caja", TurnoCaja),
            ("Ventas", Venta),
            ("Detalles de Venta", VentaDetalle),
            ("Despachos por Lote FEFO", VentaDetalleLote),
            ("Kardex", KardexMovimiento),
            ("Devoluciones", Devolucion),
            ("Detalles de Devolución", DevolucionDetalle),
        ]

        print("\n4. Copiando registros de SQLite a MySQL...")
        for nombre, modelo in tablas_modelos:
            registros = src.query(modelo).all()
            if registros:
                print(f"   -> Migrando {len(registros)} registros de {nombre}...")
                for r in registros:
                    # Inspeccionar y duplicar atributos
                    datos = {c.name: getattr(r, c.name) for c in modelo.__table__.columns}
                    # Verificar si ya existe en destino por ID
                    existe = dst.query(modelo).filter(modelo.id == datos["id"]).first()
                    if not existe:
                        nuevo_obj = modelo(**datos)
                        dst.add(nuevo_obj)
                dst.commit()
            else:
                print(f"   -> {nombre}: 0 registros encontrados.")

        # Migrar tabla pivote cliente_enfermedades
        pivotes = src.execute(cliente_enfermedades.select()).fetchall()
        if pivotes:
            print(f"   -> Migrando {len(pivotes)} asociaciones de historial clínico (CIE-10)...")
            for p in pivotes:
                try:
                    dst.execute(cliente_enfermedades.insert().values(cliente_id=p[0], enfermedad_id=p[1]))
                    dst.commit()
                except Exception:
                    dst.rollback()

        print("\n============================================================")
        print("¡MIGRACIÓN A MYSQL COMPLETADA CON ÉXITO!")
        print("============================================================")
        print(f"\nPara que FarmaControl use MySQL permanentemente, crea un archivo '.env' en backend con:")
        print(f"DATABASE_URL={mysql_url}")
        print("============================================================\n")

    finally:
        src.close()
        dst.close()

if __name__ == "__main__":
    print("====================================================")
    print("  ASISTENTE DE MIGRACIÓN: SQLite -> MySQL FarmaControl")
    print("====================================================")
    user = input("Usuario de MySQL [root]: ").strip() or "root"
    pwd = getpass.getpass("Contraseña de MySQL: ")
    host = input("Host de MySQL [localhost]: ").strip() or "localhost"
    port_in = input("Puerto de MySQL [3306]: ").strip() or "3306"
    db_name = input("Nombre de la base de datos destino [farmacontrol_db]: ").strip() or "farmacontrol_db"

    try:
        migrar(user, pwd, host, int(port_in), db_name)
    except Exception as e:
        print(f"\n❌ Error durante la migración: {e}")
