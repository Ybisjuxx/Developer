import os
from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker

DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./farmacia.db")

engine = create_engine(
    DATABASE_URL,
    connect_args={"check_same_thread": False} if DATABASE_URL.startswith("sqlite") else {},
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()


def ensure_sqlite_schema(engine):
    """Añade columnas faltantes a tablas existentes en SQLite sin romper datos."""
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
    except Exception as e:
        print(f"Aviso en ensure_sqlite_schema: {e}")



def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
