import os

from fastapi import Depends, FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.middleware.httpsredirect import HTTPSRedirectMiddleware
from fastapi.responses import JSONResponse

from .database import Base, engine, ensure_sqlite_schema
from .security import ENV_MODE, auth_guard
from .routers import auth, caja, clientes, devoluciones, enfermedades, ia, inventario, medicos, reportes, ventas

APP_VERSION = "1.4.8"
MAX_REQUEST_BYTES = 1_048_576  # 1 MB
FORCE_HTTPS = os.getenv("FORCE_HTTPS", "0").strip().lower() in {"1", "true", "yes", "si"}

# Crear tablas y evolucionar columnas en SQLite automáticamente al iniciar
Base.metadata.create_all(bind=engine)
ensure_sqlite_schema(engine)

# Orígenes permitidos (coma-separados). "*" solo para desarrollo local.
_origins_env = os.getenv("CORS_ORIGINS", "http://localhost:8080,http://127.0.0.1:8080,https://ybisjuxx.github.io")
CORS_ORIGINS = [o.strip() for o in _origins_env.split(",") if o.strip()]

_IS_PROD = ENV_MODE == "production"

app = FastAPI(
    title="FarmaControl API - Backend Farmacéutico",
    description="API para farmacias con control FEFO de inventario, recetas médicas, catálogo CIE-10, turnos de caja, devoluciones, mermas e IA de sustitución.",
    version=APP_VERSION,
    docs_url=None if _IS_PROD else "/docs",
    redoc_url=None if _IS_PROD else "/redoc",
    openapi_url=None if _IS_PROD else "/openapi.json",
    dependencies=[Depends(auth_guard)],
)

if FORCE_HTTPS:
    app.add_middleware(HTTPSRedirectMiddleware)


@app.middleware("http")
async def security_headers_and_size_guard(request: Request, call_next):
    content_length = request.headers.get("content-length")
    if content_length:
        try:
            if int(content_length) > MAX_REQUEST_BYTES:
                return JSONResponse(
                    status_code=413,
                    content={"detail": "Payload demasiado grande (máximo 1 MB)."},
                )
        except ValueError:
            pass

    response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    response.headers["Permissions-Policy"] = "camera=(self), microphone=(), geolocation=()"
    response.headers["Content-Security-Policy"] = "default-src 'self'"
    if FORCE_HTTPS:
        response.headers["Strict-Transport-Security"] = "max-age=63072000; includeSubDomains"
    return response


# Compresión GZip para reducir la latencia de transferencia de catálogos y listados pesados
app.add_middleware(GZipMiddleware, minimum_size=500)

# Habilitar CORS para permitir conexión desde Flutter (Web en Chrome, Desktop y Móvil)
app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ORIGINS,
    allow_origin_regex=r"https?://(localhost|127\.0\.0\.1|192\.168\.\d+\.\d+|10\.\d+\.\d+\.\d+)(:\d+)?",
    allow_credentials="*" not in CORS_ORIGINS,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "Accept"],
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
app.include_router(reportes.router)
app.include_router(ventas.router)


@app.get("/", tags=["General"])
def root():
    return {
        "status": "online",
        "service": "FarmaControl API Backend",
        "version": APP_VERSION,
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
