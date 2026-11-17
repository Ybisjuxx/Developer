"""Pruebas de regresión de los hallazgos de la auditoría v1.4.7."""
import datetime
import hashlib

from app.database import SessionLocal
from app.models import Usuario
from app.security import create_token, decode_token, hash_password, verify_password


# --- Autenticación -----------------------------------------------------------
def test_hash_pbkdf2_y_verificacion():
    h = hash_password("secreto")
    assert h.startswith("pbkdf2_sha256$")
    assert verify_password("secreto", h)
    assert not verify_password("otro", h)


def test_login_rechaza_hash_como_contrasena(client):
    db = SessionLocal()
    admin = db.query(Usuario).filter_by(username="admin").first()
    admin.password_hash = hashlib.sha256(b"admin123").hexdigest()  # hash heredado
    db.commit()
    legacy = admin.password_hash
    db.close()
    r = client.post("/api/auth/login", json={"username": "admin", "password": legacy})
    assert r.status_code == 401


def test_login_migra_hash_heredado_y_emite_token_firmado(client):
    r = client.post("/api/auth/login", json={"username": "admin", "password": "admin123"})
    assert r.status_code == 200, r.text
    payload = decode_token(r.json()["access_token"])
    assert payload and payload["rol"] == "ADMINISTRADOR"
    db = SessionLocal()
    assert db.query(Usuario).filter_by(username="admin").first().password_hash.startswith("pbkdf2_sha256$")
    db.close()


def test_token_alterado_es_rechazado(client):
    r = client.get("/api/auth/usuarios", headers={"Authorization": "Bearer abc.def"})
    assert r.status_code == 401


def test_cajero_no_puede_crear_usuarios(client):
    db = SessionLocal()
    cajero = db.query(Usuario).filter_by(username="cajero").first()
    token = create_token(cajero)
    db.close()
    r = client.post("/api/auth/usuarios", headers={"Authorization": f"Bearer {token}"},
                    json={"username": "x_admin", "password": "1234", "nombre_completo": "Intruso", "rol": "ADMINISTRADOR"})
    assert r.status_code == 403


def test_rol_del_token_prevalece_sobre_rol_del_body(client):
    db = SessionLocal()
    token = create_token(db.query(Usuario).filter_by(username="cajero").first())
    db.close()
    lote = client.get("/api/inventario/lotes").json()[0]
    r = client.post(f"/api/inventario/lotes/{lote['id']}/ajuste", headers={"Authorization": f"Bearer {token}"},
                    json={"nuevo_stock": lote["stock_actual"] + 1, "motivo": "prueba", "rol_usuario": "ADMINISTRADOR"})
    assert r.status_code == 403


# --- Ventas / FEFO -----------------------------------------------------------
def test_no_se_despachan_lotes_caducados(client, producto_factory):
    p = producto_factory(lotes=(("2020-01-01", 5),))
    r = client.post("/api/ventas/", json={"items": [{"producto_id": p["id"], "cantidad": 1}],
                                          "metodo_pago": "TARJETA"})
    assert r.status_code == 400
    assert "caducado" in r.json()["detail"]


def test_fefo_toma_primero_el_lote_vigente_mas_proximo(client, producto_factory):
    p = producto_factory(lotes=(("2020-01-01", 5), ("2099-06-30", 3), ("2098-01-31", 3)))
    r = client.post("/api/ventas/", json={"items": [{"producto_id": p["id"], "cantidad": 4}],
                                          "metodo_pago": "TARJETA"})
    assert r.status_code == 201, r.text
    lotes = {l["id"]: l for l in client.get(f"/api/inventario/lotes?producto_id={p['id']}").json()}
    por_cad = {l["fecha_caducidad"]: l["stock_actual"] for l in lotes.values()}
    assert por_cad == {"2020-01-01": 5, "2098-01-31": 0, "2099-06-30": 2}


def test_efectivo_insuficiente_rechazado(client, producto_factory):
    p = producto_factory(precio=50)
    r = client.post("/api/ventas/", json={"items": [{"producto_id": p["id"], "cantidad": 1}],
                                          "metodo_pago": "EFECTIVO", "monto_recibido": 10})
    assert r.status_code == 400


def test_descuento_arbitrario_rechazado(client, producto_factory):
    p = producto_factory(precio=50)
    r = client.post("/api/ventas/", json={"items": [{"producto_id": p["id"], "cantidad": 1}],
                                          "metodo_pago": "TARJETA", "descuento": 9999})
    assert r.status_code == 400


def test_descuento_cliente_lo_calcula_el_servidor(client, producto_factory):
    p = producto_factory(precio=100)
    cli = client.post("/api/clientes/", json={"nombre": "Ana", "apellido_paterno": "Prueba",
                                              "descuento_porcentaje": 10}).json()
    r = client.post("/api/ventas/", json={"items": [{"producto_id": p["id"], "cantidad": 1}],
                                          "cliente_id": cli["id"], "metodo_pago": "EFECTIVO",
                                          "monto_recibido": 90, "descuento": 10.0})
    assert r.status_code == 201, r.text
    assert r.json()["descuento"] == 10.0 and r.json()["total"] == 90.0 and r.json()["cambio"] == 0.0


# --- Devoluciones -------------------------------------------------------------
def _venta(client, p, cantidad):
    v = client.post("/api/ventas/", json={"items": [{"producto_id": p["id"], "cantidad": cantidad}],
                                          "metodo_pago": "TARJETA"}).json()
    lote_id = v["detalles"][0]["despachos_lotes"][0]["lote_id"]
    return v, lote_id


def _devolver(client, v, p, lote_id, cantidad):
    return client.post("/api/devoluciones/", json={
        "venta_id": v["id"], "motivo": "prueba", "metodo_reembolso": "EFECTIVO",
        "items": [{"producto_id": p["id"], "lote_id": lote_id, "cantidad": cantidad, "estado_producto": "BUEN_ESTADO"}],
    })


def test_devoluciones_repetidas_no_exceden_lo_vendido(client, producto_factory):
    p = producto_factory(precio=10)
    v, lote_id = _venta(client, p, 2)
    assert _devolver(client, v, p, lote_id, 1).status_code == 201
    assert _devolver(client, v, p, lote_id, 1).status_code == 201
    assert _devolver(client, v, p, lote_id, 1).status_code == 400
    assert client.get(f"/api/ventas/{v['id']}").json()["estado"] == "DEVUELTA"


def test_reembolso_usa_precio_del_ticket_no_el_actual(client, producto_factory):
    p = producto_factory(precio=10)
    v, lote_id = _venta(client, p, 1)
    # Simular cambio de precio posterior a la venta
    from app.models import Producto
    db = SessionLocal()
    db.query(Producto).filter_by(id=p["id"]).update({"precio_venta": 99.0})
    db.commit(); db.close()
    r = _devolver(client, v, p, lote_id, 1)
    assert r.status_code == 201 and r.json()["total_reembolsado"] == 10.0


def _alta_prod_ia(client, codigo, nombre, sustancia, presentacion, stock=0, receta=False, grupo="GRUPO_VI", generico=False, indicacion=None):
    r_p = client.post("/api/inventario/productos", json={
        "codigo_barras": codigo,
        "nombre_comercial": nombre,
        "sustancia_activa": sustancia,
        "presentacion": presentacion,
        "laboratorio": "Lab Test",
        "grupo_farmacopea": grupo,
        "requiere_receta": receta,
        "precio_venta": 100.0,
        "es_generico_intercambiable": generico,
        "indicacion_terapeutica": indicacion,
        "activo": True,
    })
    assert r_p.status_code == 201
    pid = r_p.json()["id"]
    if stock > 0:
        r_l = client.post("/api/inventario/lotes", json={
            "producto_id": pid,
            "numero_lote": f"LOT-{codigo}",
            "fecha_caducidad": (datetime.date.today() + datetime.timedelta(days=180)).isoformat(),
            "costo_unitario": 50.0,
            "stock_actual": stock,
        })
        assert r_l.status_code == 201
    return pid


def test_ia_auditoria_externa_reglas_completas(client):
    from app import security
    from app.models import ParSustitucion, Sustancia, TareaClasificacionFarmaceutica

    # 1. Ibuprofeno 400 sin stock, 600 con stock -> MISMA_SUSTANCIA_OTRA_PRESENTACION (CONFIRMAR_FARMACEUTICO)
    _alta_prod_ia(client, "7509001", "Motrin 400", "Ibuprofeno", "Tableta | 400 | mg", stock=0)
    _alta_prod_ia(client, "7509002", "Ibuprofeno 600 Gen", "Ibuprofeno", "Tableta | 600 | mg", stock=15)
    r1 = client.post("/api/ia/consulta-medicamento", json={"consulta": "ibuprofeno de 400"}).json()
    assert len(r1["sustitutos_en_stock"]) >= 1
    assert r1["sustitutos_en_stock"][0]["tipo_sustitucion"] == "MISMA_SUSTANCIA_OTRA_PRESENTACION"
    assert r1["sustitutos_en_stock"][0]["accion_requerida"] == "CONFIRMAR_FARMACEUTICO"

    # 2. Amoxicilina inyectable sin stock, capsulas y cefalexina (con par validado) con stock -> CONSULTAR_MEDICO, visible_para_cajero=False
    _alta_prod_ia(client, "7509003", "Amoxil Iny", "Amoxicilina", "Solucion Inyectable | 500 | mg", stock=0, receta=True, grupo="GRUPO_IV")
    _alta_prod_ia(client, "7509004", "Amoxicilina Cap", "Amoxicilina", "Capsula | 500 | mg", stock=20, receta=True, grupo="GRUPO_IV", generico=True)
    _alta_prod_ia(client, "7509005", "Keflex Cap", "Cefalexina", "Capsula | 500 | mg", stock=10, receta=True, grupo="GRUPO_IV")

    db = SessionLocal()
    for s_nom in ("AMOXICILINA", "CEFALEXINA"):
        s_row = db.query(Sustancia).filter_by(nombre_normalizado=s_nom).first()
        if s_row:
            s_row.estado_clasificacion = "CLASIFICADA"
    db.add(ParSustitucion(
        sustancia_origen="AMOXICILINA",
        sustancia_alternativa="CEFALEXINA",
        nivel="CONSULTAR_MEDICO",
        advertencias='["Posible alergia cruzada con penicilinas; la cefalexina es oral"]',
        validado_por="QFB Maria Lopez Ced. 12345",
        fecha_validacion=datetime.datetime.utcnow(),
    ))
    db.commit()
    db.close()

    r2 = client.post("/api/ia/consulta-medicamento", json={"consulta": "amoxicilina inyectable"}).json()
    tipos_r2 = {s["nombre_comercial"]: s for s in r2["sustitutos_en_stock"]}
    assert tipos_r2["Amoxicilina Cap"]["tipo_sustitucion"] == "CONSULTAR_MEDICO"
    assert tipos_r2["Amoxicilina Cap"]["visible_para_cajero"] is False
    assert tipos_r2["Keflex Cap"]["tipo_sustitucion"] == "CONSULTAR_MEDICO"
    assert any("alergia cruzada" in a.lower() for a in tipos_r2["Keflex Cap"]["advertencias"])

    # 3. Generico identico 500 mg capsulas -> INTERCAMBIABLE
    _alta_prod_ia(client, "7509006", "Amoxil 500 Marca", "Amoxicilina", "Capsula | 500 | mg", stock=0, receta=True, grupo="GRUPO_IV")
    r3 = client.post("/api/ia/consulta-medicamento", json={"consulta": "amoxicilina 500 mg capsula"}).json()
    assert r3["sustitutos_en_stock"][0]["tipo_sustitucion"] == "INTERCAMBIABLE"

    # 4. Combinacion != sustancia simple: Augmentin no sale como intercambiable de amoxicilina 500
    _alta_prod_ia(client, "7509007", "Augmentin 500", "Amoxicilina / Acido Clavulanico", "Tableta | 500 | mg", stock=12, receta=True, grupo="GRUPO_IV")
    r4 = client.post("/api/ia/consulta-medicamento", json={"consulta": "amoxicilina 500"}).json()
    assert all(s["nombre_comercial"] != "Augmentin 500" for s in r4["sustitutos_en_stock"])

    # 5. Melox -> identifica magaldrato/dimeticona, no meloxicam
    _alta_prod_ia(client, "7509008", "Melox Plus", "Magaldrato / Dimeticona", "Suspension | 80 | mg/ml", stock=8)
    _alta_prod_ia(client, "7509009", "Meloxicam 15", "Meloxicam", "Tableta | 15 | mg", stock=10)
    r5 = client.post("/api/ia/consulta-medicamento", json={"consulta": "Melox"}).json()
    assert all("Meloxicam" not in s["sustancia_activa"] for s in r5["sustitutos_en_stock"])

    # 6. Sin pares cruzados peligrosos: Losartan sin stock y Metoprolol con stock -> no aparece Metoprolol
    _alta_prod_ia(client, "7509010", "Cozaar 50", "Losartan", "Tableta | 50 | mg", stock=0, receta=True)
    _alta_prod_ia(client, "7509011", "Lopresor 100", "Metoprolol", "Tableta | 100 | mg", stock=15, receta=True)
    r6 = client.post("/api/ia/consulta-medicamento", json={"consulta": "Losartan"}).json()
    assert all(s["nombre_comercial"] != "Lopresor 100" for s in r6["sustitutos_en_stock"])

    # 7. Ibuprofeno sin stock, paracetamol y aspirina con stock -> ninguno aparece sin par validado
    _alta_prod_ia(client, "7509012", "Aspirina 500", "Acido Acetilsalicilico", "Tableta | 500 | mg", stock=20)
    r7 = client.post("/api/ia/consulta-medicamento", json={"consulta": "ibuprofeno 400"}).json()
    assert all(s["sustancia_activa"] not in ("Paracetamol", "Acido Acetilsalicilico") for s in r7["sustitutos_en_stock"])

    # 8. Par sin validado_por -> no se muestra
    db = SessionLocal()
    db.add(ParSustitucion(
        sustancia_origen="IBUPROFENO",
        sustancia_alternativa="NAPROXENO",
        nivel="CONSULTAR_MEDICO",
        advertencias='["AINE"]',
        validado_por=None,
    ))
    db.commit()
    db.close()
    _alta_prod_ia(client, "7509013", "Flanax 550", "Naproxeno", "Tableta | 550 | mg", stock=10)
    r8 = client.post("/api/ia/consulta-medicamento", json={"consulta": "ibuprofeno"}).json()
    assert all(s["nombre_comercial"] != "Flanax 550" for s in r8["sustitutos_en_stock"])

    # 9. Consulta de 2 caracteres ("as") -> sin coincidencias por subcadena
    r9 = client.post("/api/ia/consulta-medicamento", json={"consulta": "as"}).json()
    assert r9["sustitutos_en_stock"] == []

    # 10. Controlado sin stock -> no sugiere sustancias distintas (oculto para CAJERO)
    _alta_prod_ia(client, "7509014", "Controlado Prueba 2", "LorazepamControladoTest", "Tableta | 2 | mg", stock=0, receta=True, grupo="GRUPO_II")
    db = SessionLocal()
    caj_ia = db.query(Usuario).filter_by(rol="CAJERO").first()
    tok_caj_ia = security.create_token(caj_ia)
    db.close()
    r10 = client.post(
        "/api/ia/consulta-medicamento",
        json={"consulta": "LorazepamControladoTest"},
        headers={"Authorization": f"Bearer {tok_caj_ia}"},
    ).json()
    assert r10["sustitutos_en_stock"] == []

    # 11. Aviso sanitario siempre presente
    assert "profesional farmacéutico" in r10["aviso_sanitario"].lower()

    # 12 & 13. Sustancia nueva -> PENDIENTE + tarea al farmaceutico; consultada por nombre muestra existencia y "sin alternativas validadas", no aparece como sustituto de otra
    _alta_prod_ia(client, "7509015", "Lyrica Prueba", "PregabalinaTestNueva", "Capsula | 75 | mg", stock=12, receta=True, grupo="GRUPO_IV", indicacion="Alivia el dolor neuropático.")
    db = SessionLocal()
    s_preg = db.query(Sustancia).filter_by(nombre_normalizado="PREGABALINATESTNUEVA").first()
    assert s_preg is not None and s_preg.estado_clasificacion == "PENDIENTE"
    t_preg = db.query(TareaClasificacionFarmaceutica).filter_by(sustancia_id=s_preg.id).first()
    assert t_preg is not None and t_preg.estado == "PENDIENTE"
    db.close()

    r13 = client.post("/api/ia/consulta-medicamento", json={"consulta": "Lyrica Prueba"}).json()
    assert r13["disponible_en_stock"] is True
    assert "sin alternativas validadas" in r13["respuesta_ia"].lower()

    # 14. Busqueda por indicacion ("algo para el dolor") -> NO genera sustitutos por coincidencia de texto
    r14 = client.post("/api/ia/consulta-medicamento", json={"consulta": "algo para el dolor"}).json()
    assert r14["sustitutos_en_stock"] == []

    # 15. Mismo codigo ATC sin par firmado -> ninguno aparece como alternativa del otro
    db = SessionLocal()
    s_los = db.query(Sustancia).filter_by(nombre_normalizado="LOSARTAN").first()
    s_met = db.query(Sustancia).filter_by(nombre_normalizado="METOPROLOL").first()
    if s_los and s_met:
        s_los.codigo_atc = "C09CA01"
        s_los.estado_clasificacion = "CLASIFICADA"
        s_met.codigo_atc = "C09CA99"
        s_met.estado_clasificacion = "CLASIFICADA"
        db.commit()
    db.close()
    r15 = client.post("/api/ia/consulta-medicamento", json={"consulta": "Losartan"}).json()
    assert all("metoprolol" not in s["sustancia_activa"].lower() for s in r15["sustitutos_en_stock"])


def test_reportes_mensuales_rbac_por_area(client):
    from app import security

    # 1. ADMINISTRADOR ve las 6 áreas y 35 indicadores
    r_admin = client.get("/api/reportes/indicadores-mensuales")
    assert r_admin.status_code == 200
    data_admin = r_admin.json()
    assert data_admin["total_areas"] == 6
    assert data_admin["total_indicadores"] == 35
    claves_admin = [a["clave"] for a in data_admin["areas"]]
    assert claves_admin == [
        "01_mostrador_ventas",
        "02_almacen_inventario",
        "03_compras_proveedores",
        "04_finanzas_administracion",
        "05_calidad_atencion_farmaceutica",
        "06_regulacion_cofepris",
    ]

    # 2. RESPONSABLE_SANITARIO solo ve Áreas 2, 5 y 6 (sin finanzas/mostrador/compras)
    db = SessionLocal()
    resp_san = db.query(Usuario).filter_by(rol="RESPONSABLE_SANITARIO").first()
    if resp_san is None:
        resp_san = Usuario(
            username="resp_san_test",
            nombre_completo="Responsable Sanitario Test",
            rol="RESPONSABLE_SANITARIO",
            password_hash=hash_password("san123"),
            activo=True,
        )
        db.add(resp_san)
        db.commit()
        db.refresh(resp_san)
    token_san = create_token(resp_san)
    db.close()

    r_san = client.get(
        "/api/reportes/indicadores-mensuales",
        headers={"Authorization": f"Bearer {token_san}"},
    )
    assert r_san.status_code == 200
    data_san = r_san.json()
    assert data_san["acceso_completo"] is False
    claves_san = [a["clave"] for a in data_san["areas"]]
    assert claves_san == [
        "02_almacen_inventario",
        "05_calidad_atencion_farmaceutica",
        "06_regulacion_cofepris",
    ]

    # Descarga CSV para Responsable Sanitario también excluye finanzas/ventas
    r_csv = client.get(
        "/api/reportes/indicadores-mensuales/descargar?formato=csv",
        headers={"Authorization": f"Bearer {token_san}"},
    )
    assert r_csv.status_code == 200
    assert "Finanzas y Administración" not in r_csv.text
    assert "Regulación y Responsable Sanitario" in r_csv.text

    # 3. CAJERO recibe 403 Forbidden
    db = SessionLocal()
    cajero = db.query(Usuario).filter_by(rol="CAJERO").first()
    if cajero is None:
        cajero = Usuario(
            username="cajero_test_rep",
            nombre_completo="Cajero Test",
            rol="CAJERO",
            password_hash=hash_password("caj123"),
            activo=True,
        )
        db.add(cajero)
        db.commit()
        db.refresh(cajero)
    token_cajero = create_token(cajero)
    db.close()

    r_caj = client.get(
        "/api/reportes/indicadores-mensuales",
        headers={"Authorization": f"Bearer {token_cajero}"},
    )
    assert r_caj.status_code == 403


def test_seguridad_20_puntos(client, producto_factory):
    from fastapi.testclient import TestClient
    from app import security
    from app.main import app
    from app.models import Venta

    # 1. AUTH_REQUIRED=1 -> sin token devuelve 401
    anon = TestClient(app)
    r_unauth = anon.get("/api/clientes/")
    assert r_unauth.status_code == 401

    # 2. Security headers presentes en la respuesta
    r_health = anon.get("/api/health")
    assert r_health.status_code == 200
    assert r_health.headers.get("X-Content-Type-Options") == "nosniff"
    assert r_health.headers.get("X-Frame-Options") == "DENY"
    assert r_health.headers.get("Content-Security-Policy") == "default-src 'self'"

    # 3. Anti-Mass Assignment (extra='forbid' -> 422)
    r_mass = client.post(
        "/api/clientes/",
        json={"nombre": "Test", "campo_malicioso": "admin"},
    )
    assert r_mass.status_code == 422

    # 4. RBAC estricto para CAJERO en inventario y borrado de clientes
    db = SessionLocal()
    caj = db.query(Usuario).filter_by(rol="CAJERO").first()
    tok_caj = security.create_token(caj)
    db.close()
    r_del = client.delete("/api/clientes/1", headers={"Authorization": f"Bearer {tok_caj}"})
    assert r_del.status_code == 403

    # 5. Cifrado PII en comprador_identificacion (enc:: en BD, descifrado en VentaOut)
    p = producto_factory(precio=25.0)
    r_v = client.post(
        "/api/ventas/",
        json={
            "comprador_nombre": "Paciente PII",
            "comprador_identificacion": "INE-99887766",
            "metodo_pago": "EFECTIVO",
            "monto_recibido": 50.0,
            "items": [{"producto_id": p["id"], "cantidad": 1}],
        },
    )
    assert r_v.status_code == 201, r_v.text
    v_json = r_v.json()
    assert v_json["comprador_identificacion"] == "INE-99887766"
    db = SessionLocal()
    v_db = db.query(Venta).filter_by(id=v_json["id"]).first()
    assert v_db.comprador_identificacion.startswith("enc::")
    db.close()

    # 6. Rate limiting en /api/auth/login tras 5 fallos
    for _ in range(5):
        r_fail = anon.post("/api/auth/login", json={"username": "no_existe_ratelimit", "password": "bad"})
        assert r_fail.status_code == 401
    r_429 = anon.post("/api/auth/login", json={"username": "no_existe_ratelimit", "password": "bad"})
    assert r_429.status_code == 429

    # 7. Revocación de token en /api/auth/logout
    tok_temp = security.create_token(caj)
    r_ok = anon.get("/api/clientes/", headers={"Authorization": f"Bearer {tok_temp}"})
    assert r_ok.status_code == 200
    r_out = anon.post("/api/auth/logout", headers={"Authorization": f"Bearer {tok_temp}"})
    assert r_out.status_code == 204
    r_revoked = anon.get("/api/clientes/", headers={"Authorization": f"Bearer {tok_temp}"})
    assert r_revoked.status_code == 401


def test_indicadores_35_conectados_bd(client):
    from datetime import date, timedelta

    hoy = date.today()

    # 1. Registrar lectura ambiental COFEPRIS dentro de norma
    r_bit = client.post(
        "/api/reportes/bitacora-cofepris",
        json={
            "turno": "MATUTINO",
            "zona": "ANAQUEL_GENERAL",
            "temperatura_c": 21.5,
            "humedad_relativa_pct": 48.0,
            "observaciones": "Lectura de prueba auditoría",
        },
    )
    assert r_bit.status_code == 201, r_bit.text
    assert r_bit.json()["dentro_norma"] is True

    # 2. Actualizar parámetros financieros del mes actual
    r_fin = client.put(
        "/api/reportes/parametros-financieros",
        json={
            "anio": hoy.year,
            "mes": hoy.month,
            "gastos_fijos_mensuales": 18500.0,
            "nomina_mensual": 24000.0,
        },
    )
    assert r_fin.status_code == 200, r_fin.text
    assert r_fin.json()["gastos_fijos_mensuales"] == 18500.0

    # 3. Registrar documento sanitario vigente
    r_doc = client.post(
        "/api/reportes/documentos-sanitarios",
        json={
            "tipo_documento": "AVISO_FUNCIONAMIENTO",
            "folio_documento": "COF-2026-TEST-01",
            "fecha_emision": str(hoy - timedelta(days=30)),
            "fecha_vencimiento": str(hoy + timedelta(days=180)),
            "activo": True,
        },
    )
    assert r_doc.status_code == 201, r_doc.text
    assert r_doc.json()["dias_restantes"] >= 179

    # 4. Consultar indicadores mensuales y verificar cálculo dinámico de los 35 KPIs
    r_ind = client.get(f"/api/reportes/indicadores-mensuales?anio={hoy.year}&mes={hoy.month}")
    assert r_ind.status_code == 200, r_ind.text
    data = r_ind.json()
    kpis = {item["codigo"]: item for cat in data["areas"] for item in cat["indicadores"]}
    assert len(kpis) == 35
    assert "COF-04" in kpis and kpis["COF-04"]["valor"] == 100.0
    assert "COF-07" in kpis and kpis["COF-07"]["valor"] >= 30
    assert "FIN-03" in kpis and kpis["FIN-03"]["valor"] is not None


def test_bitacora_rangos_y_gastos_operativos_fechados(client):
    from datetime import date

    hoy = date.today()

    # 1. Consultar bitácora filtrada por rango=hoy, 7dias y mes
    for rango in ("hoy", "7dias", "mes"):
        r_b = client.get(f"/api/reportes/bitacora-cofepris?rango={rango}")
        assert r_b.status_code == 200, r_b.text
        assert isinstance(r_b.json(), list)

    # 2. Registrar gastos operativos fechados (Nómina + Renta)
    r_g1 = client.post(
        "/api/reportes/gastos-operativos",
        json={
            "fecha_gasto": str(hoy),
            "categoria": "NOMINA",
            "concepto": "Nómina quincenal mostrador",
            "monto": 12000.0,
            "metodo_pago": "TRANSFERENCIA",
        },
    )
    assert r_g1.status_code == 201, r_g1.text
    g1_id = r_g1.json()["id"]

    r_g2 = client.post(
        "/api/reportes/gastos-operativos",
        json={
            "fecha_gasto": str(hoy),
            "categoria": "RENTA",
            "concepto": "Renta local comercial",
            "monto": 8000.0,
            "metodo_pago": "TRANSFERENCIA",
            "comprobante_folio": "FAC-RENTA-11",
        },
    )
    assert r_g2.status_code == 201, r_g2.text

    # 3. Consultar resumen desglosado del mes
    r_list = client.get("/api/reportes/gastos-operativos?rango=mes")
    assert r_list.status_code == 200, r_list.text
    res = r_list.json()
    assert res["total_nomina"] >= 12000.0
    assert res["total_otros_gastos"] >= 8000.0
    assert res["total_monto"] >= 20000.0
    assert "NOMINA" in res["por_categoria"] and "RENTA" in res["por_categoria"]

    # 4. Eliminar gasto individual
    r_del = client.delete(f"/api/reportes/gastos-operativos/{g1_id}")
    assert r_del.status_code == 204


def test_regresion_thermos_mermas_caja_rbac(client, producto_factory):
    from app import security

    p = producto_factory(precio=100.0)

    # 1. Venta en efectivo por $100 y devolución dañada (crea SALIDA_MERMA)
    r_v = client.post(
        "/api/ventas/",
        json={
            "comprador_nombre": "Cliente Merma",
            "metodo_pago": "EFECTIVO",
            "monto_recibido": 100.0,
            "items": [{"producto_id": p["id"], "cantidad": 1}],
        },
    )
    assert r_v.status_code == 201, r_v.text
    v_json = r_v.json()
    v_id = v_json["id"]
    lote_id = v_json["detalles"][0]["despachos_lotes"][0]["lote_id"]

    r_dev = client.post(
        "/api/devoluciones/",
        json={
            "venta_id": v_id,
            "motivo": "Caja aplastada en mostrador",
            "metodo_reembolso": "EFECTIVO",
            "items": [{"producto_id": p["id"], "lote_id": lote_id, "cantidad": 1, "estado_producto": "DANADO"}],
        },
    )
    assert r_dev.status_code == 201, r_dev.text

    # 2. GET /api/devoluciones/mermas no debe fallar con ValidationError 500
    r_mermas = client.get("/api/devoluciones/mermas")
    assert r_mermas.status_code == 200, r_mermas.text
    assert len(r_mermas.json()) >= 1
    assert "costo_total" in r_mermas.json()[0]

    # 3. RBAC estricto para CAJERO en reporte-mensual y enfermedades
    db = SessionLocal()
    caj = db.query(Usuario).filter_by(rol="CAJERO").first()
    tok_caj = security.create_token(caj)
    db.close()

    r_rep = client.get("/api/ventas/reporte-mensual", headers={"Authorization": f"Bearer {tok_caj}"})
    assert r_rep.status_code == 403

    r_enf = client.post(
        "/api/enfermedades/",
        json={"codigo_cie10": "Z99", "nombre": "Prueba RBAC", "es_cronica": False},
        headers={"Authorization": f"Bearer {tok_caj}"},
    )
    assert r_enf.status_code == 403



