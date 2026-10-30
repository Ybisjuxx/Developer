from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware

from .database import Base, engine, ensure_sqlite_schema
from .routers import auth, caja, clientes, devoluciones, enfermedades, ia, inventario, medicos, ventas

# Crear tablas y evolucionar columnas en SQLite automáticamente al iniciar
Base.metadata.create_all(bind=engine)
ensure_sqlite_schema(engine)

app = FastAPI(
    title="FarmaControl API - Backend Farmacéutico",
    description="API para farmacias con control FEFO de inventario, recetas médicas, catálogo CIE-10, turnos de caja, devoluciones, mermas e IA de sustitución.",
    version="1.4.0",
)

# Compresión GZip para reducir la latencia de transferencia de catálogos y listados pesados
app.add_middleware(GZipMiddleware, minimum_size=500)

# Habilitar CORS para permitir conexión desde Flutter (Web en Chrome, Desktop y Móvil)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Registrar Routers
app.include_router(auth.router)
app.include_router(caja.router)
app.include_router(clientes.router)
app.include_router(devoluciones.router)
app.include_router(medicos.router)
app.include_router(enfermedades.router)
app.include_router(ia.router)
app.include_router(inventario.router)
app.include_router(ventas.router)


@app.get("/", tags=["General"])
def root():
    return {
        "status": "online",
        "service": "FarmaControl API Backend",
        "version": "1.1.0",
        "docs_url": "/docs",
        "endpoints": [
            "/api/auth",
            "/api/caja",
            "/api/devoluciones",
            "/api/medicos",
            "/api/enfermedades",
            "/api/inventario/productos",
            "/api/inventario/lotes",
            "/api/inventario/kardex",
            "/api/ventas",
        ],
    }


@app.get("/api/health", tags=["General"])
def health():
    return {"status": "healthy"}
