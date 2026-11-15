"""Fixtures: cada sesión de pruebas usa una BD SQLite temporal sembrada con seed.py.
Nunca se toca backend/farmacia.db."""
import os
import sys
import tempfile

_tmpdir = tempfile.mkdtemp(prefix="farmacontrol_test_")
os.environ["DATABASE_URL"] = f"sqlite:///{os.path.join(_tmpdir, 'test.db')}"
os.environ.setdefault("FARMACONTROL_SECRET_KEY", "clave-solo-para-pruebas")
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

import seed  # noqa: E402
from app.database import SessionLocal  # noqa: E402
from app.main import app  # noqa: E402
from app.models import Usuario  # noqa: E402
from app.security import create_token  # noqa: E402

seed.seed_database()


@pytest.fixture(scope="session")
def client():
    db = SessionLocal()
    try:
        admin = db.query(Usuario).filter_by(username="admin").first()
        token = create_token(admin)
    finally:
        db.close()
    return TestClient(app, headers={"Authorization": f"Bearer {token}"})


@pytest.fixture()
def producto_factory(client):
    contador = {"n": 0}

    def _crear(precio=10.0, lotes=(("2099-12-31", 10),)):
        contador["n"] += 1
        import uuid
        cb = f"T{uuid.uuid4().hex[:10]}"
        p = client.post("/api/inventario/productos", json={
            "codigo_barras": cb, "nombre_comercial": f"Prueba {cb}", "sustancia_activa": "PARACETAMOL",
            "presentacion": "Caja 10", "laboratorio": "LabPrueba", "grupo_farmacopea": "GRUPO_VI",
            "requiere_receta": False, "precio_venta": precio,
        })
        assert p.status_code == 201, p.text
        p = p.json()
        for i, (cad, stock) in enumerate(lotes):
            r = client.post("/api/inventario/lotes", json={
                "producto_id": p["id"], "numero_lote": f"L{i}-{cb}", "fecha_caducidad": cad,
                "costo_unitario": precio / 2, "stock_actual": stock,
            })
            assert r.status_code == 201, r.text
        return p

    return _crear
