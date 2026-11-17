import datetime
import os
from dotenv import load_dotenv
from sqlalchemy import create_engine, event
from sqlalchemy.orm import declarative_base, sessionmaker

load_dotenv()

BACKEND_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_DB_PATH = os.path.join(BACKEND_DIR, "farmacia.db").replace("\\", "/")
DATABASE_URL = os.getenv("DATABASE_URL", f"sqlite:///{DEFAULT_DB_PATH}")

engine_kwargs = {}
if DATABASE_URL.startswith("sqlite"):
    engine_kwargs["connect_args"] = {"check_same_thread": False, "timeout": 15.0}
else:
    # Parámetros robustos para MySQL / MariaDB / PostgreSQL
    engine_kwargs["pool_pre_ping"] = True
    engine_kwargs["pool_recycle"] = 3600

engine = create_engine(DATABASE_URL, **engine_kwargs)

if DATABASE_URL.startswith("sqlite"):
    @event.listens_for(engine, "connect")
    def _set_sqlite_pragmas(dbapi_conn, _connection_record):
        cursor = dbapi_conn.cursor()
        cursor.execute("PRAGMA journal_mode=WAL")
        cursor.execute("PRAGMA busy_timeout=5000")
        cursor.execute("PRAGMA foreign_keys=ON")
        cursor.close()


def utc_now() -> datetime.datetime:
    """UTC naive compatible con SQLite sin DeprecationWarning de Python 3.12+."""
    return datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()


def ensure_sqlite_schema(engine):
    """Añade columnas faltantes a tablas existentes en SQLite sin romper datos."""
    if not DATABASE_URL.startswith("sqlite"):
        return
    try:
        with engine.connect() as conn:
            # 1. Columnas en tabla ventas
            result = conn.exec_driver_sql("PRAGMA table_info(ventas)").fetchall()
            existing_cols = [r[1] for r in result]
            if existing_cols:
                if "metodo_pago" not in existing_cols:
                    conn.exec_driver_sql("ALTER TABLE ventas ADD COLUMN metodo_pago VARCHAR(30) DEFAULT 'EFECTIVO'")
                if "monto_recibido" not in existing_cols:
                    conn.exec_driver_sql("ALTER TABLE ventas ADD COLUMN monto_recibido FLOAT DEFAULT 0.0")
                if "cambio" not in existing_cols:
                    conn.exec_driver_sql("ALTER TABLE ventas ADD COLUMN cambio FLOAT DEFAULT 0.0")
                if "turno_id" not in existing_cols:
                    conn.exec_driver_sql("ALTER TABLE ventas ADD COLUMN turno_id INTEGER")
                if "cajero_nombre" not in existing_cols:
                    conn.exec_driver_sql("ALTER TABLE ventas ADD COLUMN cajero_nombre VARCHAR(150) DEFAULT 'Cajero Principal'")
                if "cliente_id" not in existing_cols:
                    conn.exec_driver_sql("ALTER TABLE ventas ADD COLUMN cliente_id INTEGER REFERENCES clientes(id)")
                if "facturada" not in existing_cols:
                    conn.exec_driver_sql("ALTER TABLE ventas ADD COLUMN facturada BOOLEAN DEFAULT 0")
                if "folio_factura" not in existing_cols:
                    conn.exec_driver_sql("ALTER TABLE ventas ADD COLUMN folio_factura VARCHAR(50)")
                if "rfc_receptor" not in existing_cols:
                    conn.exec_driver_sql("ALTER TABLE ventas ADD COLUMN rfc_receptor VARCHAR(20)")
                if "razon_social_receptor" not in existing_cols:
                    conn.exec_driver_sql("ALTER TABLE ventas ADD COLUMN razon_social_receptor VARCHAR(200)")
                if "regimen_fiscal_receptor" not in existing_cols:
                    conn.exec_driver_sql("ALTER TABLE ventas ADD COLUMN regimen_fiscal_receptor VARCHAR(100)")
                if "codigo_postal_receptor" not in existing_cols:
                    conn.exec_driver_sql("ALTER TABLE ventas ADD COLUMN codigo_postal_receptor VARCHAR(10)")
                if "uso_cfdi" not in existing_cols:
                    conn.exec_driver_sql("ALTER TABLE ventas ADD COLUMN uso_cfdi VARCHAR(50)")
                if "correo_factura" not in existing_cols:
                    conn.exec_driver_sql("ALTER TABLE ventas ADD COLUMN correo_factura VARCHAR(150)")
                if "fecha_factura" not in existing_cols:
                    conn.exec_driver_sql("ALTER TABLE ventas ADD COLUMN fecha_factura DATETIME")
                if "uuid_fiscal" not in existing_cols:
                    conn.exec_driver_sql("ALTER TABLE ventas ADD COLUMN uuid_fiscal VARCHAR(60)")
                if "tiempo_atencion_seg" not in existing_cols:
                    conn.exec_driver_sql("ALTER TABLE ventas ADD COLUMN tiempo_atencion_seg INTEGER DEFAULT 140")
                if "folio_receta" not in existing_cols:
                    conn.exec_driver_sql("ALTER TABLE ventas ADD COLUMN folio_receta VARCHAR(60)")
                if "receta_retenida" not in existing_cols:
                    conn.exec_driver_sql("ALTER TABLE ventas ADD COLUMN receta_retenida BOOLEAN DEFAULT 0")
                if "receta_sin_errores" not in existing_cols:
                    conn.exec_driver_sql("ALTER TABLE ventas ADD COLUMN receta_sin_errores BOOLEAN DEFAULT 1")
                if "receta_surtida_completa" not in existing_cols:
                    conn.exec_driver_sql("ALTER TABLE ventas ADD COLUMN receta_surtida_completa BOOLEAN DEFAULT 1")
                conn.commit()

            # 2. Columnas de auditoría e irregularidades en kardex_movimientos
            result_kardex = conn.exec_driver_sql("PRAGMA table_info(kardex_movimientos)").fetchall()
            existing_kardex_cols = [r[1] for r in result_kardex]
            if existing_kardex_cols:
                if "observaciones_auditoria" not in existing_kardex_cols:
                    conn.exec_driver_sql("ALTER TABLE kardex_movimientos ADD COLUMN observaciones_auditoria TEXT")
                if "es_irregular" not in existing_kardex_cols:
                    conn.exec_driver_sql("ALTER TABLE kardex_movimientos ADD COLUMN es_irregular BOOLEAN DEFAULT 0")
                if "usuario_auditor" not in existing_kardex_cols:
                    conn.exec_driver_sql("ALTER TABLE kardex_movimientos ADD COLUMN usuario_auditor VARCHAR(150)")
                conn.commit()

            # 3. Columnas en tabla clientes (fecha_nacimiento, sexo, apellido_paterno, apellido_materno)
            result_clientes = conn.exec_driver_sql("PRAGMA table_info(clientes)").fetchall()
            existing_clientes_cols = [r[1] for r in result_clientes]
            if existing_clientes_cols:
                if "fecha_nacimiento" not in existing_clientes_cols:
                    conn.exec_driver_sql("ALTER TABLE clientes ADD COLUMN fecha_nacimiento DATE")
                if "sexo" not in existing_clientes_cols:
                    conn.exec_driver_sql("ALTER TABLE clientes ADD COLUMN sexo VARCHAR(20)")
                if "apellido_paterno" not in existing_clientes_cols:
                    conn.exec_driver_sql("ALTER TABLE clientes ADD COLUMN apellido_paterno VARCHAR(100)")
                if "apellido_materno" not in existing_clientes_cols:
                    conn.exec_driver_sql("ALTER TABLE clientes ADD COLUMN apellido_materno VARCHAR(100)")
                if "ultima_visita" not in existing_clientes_cols:
                    conn.exec_driver_sql("ALTER TABLE clientes ADD COLUMN ultima_visita DATETIME")
                if "tiene_padecimientos_cronicos" not in existing_clientes_cols:
                    conn.exec_driver_sql("ALTER TABLE clientes ADD COLUMN tiene_padecimientos_cronicos BOOLEAN DEFAULT 0")
                if "dias_tratamiento" not in existing_clientes_cols:
                    conn.exec_driver_sql("ALTER TABLE clientes ADD COLUMN dias_tratamiento INTEGER DEFAULT 30")
                if "fecha_proximo_resurtimiento" not in existing_clientes_cols:
                    conn.exec_driver_sql("ALTER TABLE clientes ADD COLUMN fecha_proximo_resurtimiento DATE")
                if "medicamento_cronico_principal" not in existing_clientes_cols:
                    conn.exec_driver_sql("ALTER TABLE clientes ADD COLUMN medicamento_cronico_principal VARCHAR(150)")
                conn.commit()

            # 4. Columnas en tabla lotes (laboratorio_fabricante, forma_farmaceutica, dosificacion, fecha_ingreso, dosis_valor, dosis_unidad)
            result_lotes = conn.exec_driver_sql("PRAGMA table_info(lotes)").fetchall()
            existing_lotes_cols = [r[1] for r in result_lotes]
            if existing_lotes_cols:
                if "laboratorio_fabricante" not in existing_lotes_cols:
                    conn.exec_driver_sql("ALTER TABLE lotes ADD COLUMN laboratorio_fabricante VARCHAR(100)")
                if "forma_farmaceutica" not in existing_lotes_cols:
                    conn.exec_driver_sql("ALTER TABLE lotes ADD COLUMN forma_farmaceutica VARCHAR(100)")
                if "dosificacion" not in existing_lotes_cols:
                    conn.exec_driver_sql("ALTER TABLE lotes ADD COLUMN dosificacion VARCHAR(100)")
                if "dosis_valor" not in existing_lotes_cols:
                    conn.exec_driver_sql("ALTER TABLE lotes ADD COLUMN dosis_valor VARCHAR(50)")
                if "dosis_unidad" not in existing_lotes_cols:
                    conn.exec_driver_sql("ALTER TABLE lotes ADD COLUMN dosis_unidad VARCHAR(50)")
                if "fecha_ingreso" not in existing_lotes_cols:
                    conn.exec_driver_sql("ALTER TABLE lotes ADD COLUMN fecha_ingreso DATE")
                if "proveedor_nombre" not in existing_lotes_cols:
                    conn.exec_driver_sql("ALTER TABLE lotes ADD COLUMN proveedor_nombre VARCHAR(120) DEFAULT 'Distribuidor General'")
                if "piezas_solicitadas" not in existing_lotes_cols:
                    conn.exec_driver_sql("ALTER TABLE lotes ADD COLUMN piezas_solicitadas INTEGER")
                if "horas_entrega_lead_time" not in existing_lotes_cols:
                    conn.exec_driver_sql("ALTER TABLE lotes ADD COLUMN horas_entrega_lead_time FLOAT DEFAULT 24.0")
                if "costo_unitario_anterior" not in existing_lotes_cols:
                    conn.exec_driver_sql("ALTER TABLE lotes ADD COLUMN costo_unitario_anterior FLOAT")
                conn.commit()

            # 5. Columnas en tabla productos (familia_terapeutica, indicacion_terapeutica, presentación estructurada y sustancia)
            result_productos = conn.exec_driver_sql("PRAGMA table_info(productos)").fetchall()
            existing_prod_cols = [r[1] for r in result_productos]
            if existing_prod_cols:
                if "familia_terapeutica" not in existing_prod_cols:
                    conn.exec_driver_sql("ALTER TABLE productos ADD COLUMN familia_terapeutica VARCHAR(100)")
                if "indicacion_terapeutica" not in existing_prod_cols:
                    conn.exec_driver_sql("ALTER TABLE productos ADD COLUMN indicacion_terapeutica TEXT")
                if "sustancia_id" not in existing_prod_cols:
                    conn.exec_driver_sql("ALTER TABLE productos ADD COLUMN sustancia_id INTEGER")
                if "concentracion_valor" not in existing_prod_cols:
                    conn.exec_driver_sql("ALTER TABLE productos ADD COLUMN concentracion_valor FLOAT")
                if "concentracion_unidad" not in existing_prod_cols:
                    conn.exec_driver_sql("ALTER TABLE productos ADD COLUMN concentracion_unidad VARCHAR(20)")
                if "forma_farmaceutica" not in existing_prod_cols:
                    conn.exec_driver_sql("ALTER TABLE productos ADD COLUMN forma_farmaceutica VARCHAR(50)")
                if "via_administracion" not in existing_prod_cols:
                    conn.exec_driver_sql("ALTER TABLE productos ADD COLUMN via_administracion VARCHAR(30)")
                if "es_generico_intercambiable" not in existing_prod_cols:
                    conn.exec_driver_sql("ALTER TABLE productos ADD COLUMN es_generico_intercambiable BOOLEAN NOT NULL DEFAULT 0")
                if "requiere_revision_manual" not in existing_prod_cols:
                    conn.exec_driver_sql("ALTER TABLE productos ADD COLUMN requiere_revision_manual BOOLEAN NOT NULL DEFAULT 0")
                conn.commit()

            # 5. Columnas en tabla medicos (apellido_paterno, apellido_materno)
            result_medicos = conn.exec_driver_sql("PRAGMA table_info(medicos)").fetchall()
            existing_medicos_cols = [r[1] for r in result_medicos]
            if existing_medicos_cols:
                if "apellido_paterno" not in existing_medicos_cols:
                    conn.exec_driver_sql("ALTER TABLE medicos ADD COLUMN apellido_paterno VARCHAR(100)")
                if "apellido_materno" not in existing_medicos_cols:
                    conn.exec_driver_sql("ALTER TABLE medicos ADD COLUMN apellido_materno VARCHAR(100)")
                conn.commit()
    except Exception as e:
        print(f"Aviso en ensure_sqlite_schema: {e}")


# Ejecutar migración automática al cargar database
ensure_sqlite_schema(engine)


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
