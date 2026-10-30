import sys
import datetime
sys.stdout.reconfigure(encoding='utf-8')
sys.path.insert(0, r"C:\Developer\backend")

from fastapi.testclient import TestClient
from app.main import app
from app.database import SessionLocal, get_db
from app.models import Cliente, Producto, Lote, Venta, VentaDetalle

client = TestClient(app)

def test_subagent_1_clientes_cronicos_y_resurtimiento():
    print("\n--- TEST SUBAGENTE 1: Clientes Crónicos y Alerta de Resurtimiento ---")
    db = SessionLocal()
    try:
        # Crear cliente de prueba con padecimiento crónico
        payload = {
            "nombre": "Juan",
            "apellido_paterno": "Pérez",
            "apellido_materno": "López",
            "telefono": "3312345678",
            "tiene_padecimientos_cronicos": True,
            "medicamento_cronico_principal": "Metformina 850mg",
            "dias_tratamiento": 30,
            "notas": "Paciente diabético tipo 2"
        }
        res = client.post("/api/clientes/", json=payload)
        assert res.status_code in [200, 201], f"Error creando cliente: {res.text}"
        cli_data = res.json()
        cli_id = cli_data["id"]
        print(f"Cliente creado ID {cli_id}: {cli_data['nombre']} {cli_data.get('apellido', '')}")
        assert cli_data["tiene_padecimientos_cronicos"] is True
        assert cli_data["medicamento_cronico_principal"] == "Metformina 850mg"

        # Simular una última visita hace 15 días (le quedan 15 días de tratamiento <= 21 días -> ALERTA ACTIVA)
        cli_obj = db.query(Cliente).filter(Cliente.id == cli_id).first()
        hace_15_dias = datetime.datetime.utcnow() - datetime.timedelta(days=15)
        cli_obj.ultima_visita = hace_15_dias
        cli_obj.fecha_proximo_resurtimiento = (hace_15_dias + datetime.timedelta(days=30)).date()
        db.commit()

        # Probar endpoint de alertas de resurtimiento
        res_alertas = client.get("/api/clientes/alertas-resurtimiento")
        assert res_alertas.status_code == 200, f"Error alertas: {res_alertas.text}"
        alertas = res_alertas.json()
        encontrado = any(c["id"] == cli_id for c in alertas)
        assert encontrado, f"El cliente {cli_id} no apareció en la lista de alertas de resurtimiento"
        print(f"Alerta de resurtimiento detectada exitosamente para cajero: {cli_obj.mensaje_alerta_resurtimiento}")

        # Probar que al registrar una venta, la última visita se actualiza automáticamente
        prod = db.query(Producto).filter(Producto.activo == True).first()
        if not prod:
            prod = Producto(
                codigo_barras="750123456789",
                nombre_comercial="Paracetamol Genérico",
                sustancia_activa="Paracetamol",
                forma_farmaceutica="Tableta",
                concentracion="500 mg",
                precio_compra=10.0,
                precio_venta=25.0,
                requiere_receta=False,
                grupo_farmacopea="MISCELANEO",
                activo=True
            )
            db.add(prod)
            db.flush()
        
        lote = db.query(Lote).filter(Lote.producto_id == prod.id, Lote.stock_actual > 0).first()
        if not lote:
            lote = Lote(
                producto_id=prod.id,
                numero_lote="TEST-LOT-01",
                fecha_caducidad=datetime.date.today() + datetime.timedelta(days=180),
                stock_inicial=50,
                stock_actual=50,
                activo=True
            )
            db.add(lote)
            db.flush()
        db.commit()

        venta_payload = {
            "cliente_id": cli_id,
            "metodo_pago": "EFECTIVO",
            "monto_recibido": 100.0,
            "items": [{"producto_id": prod.id, "cantidad": 1}]
        }
        res_venta = client.post("/api/ventas/", json=venta_payload)
        assert res_venta.status_code in [200, 201], f"Error en venta: {res_venta.text}"
        v_data = res_venta.json()
        print(f"Venta creada con éxito: Folio {v_data['folio_ticket']}")

        db.refresh(cli_obj)
        assert cli_obj.ultima_visita is not None
        print(f"Última visita actualizada automáticamente tras venta: {cli_obj.ultima_visita}")
        print("TEST SUBAGENTE 1: EXITOSO")
        return v_data["id"], v_data["folio_ticket"]
    finally:
        db.close()


def test_subagent_2_facturacion_y_ticket(venta_id: int, folio_ticket: str):
    print("\n--- TEST SUBAGENTE 2: Facturación CFDI 4.0 y Búsqueda por Ticket ---")
    
    # 1. Búsqueda por ticket exacto
    res_tk = client.get(f"/api/ventas/ticket/{folio_ticket}")
    assert res_tk.status_code == 200, f"Error buscando ticket: {res_tk.text}"
    print(f"Búsqueda por ticket exacto '{folio_ticket}': OK (Venta #{res_tk.json()['id']})")

    # 2. Búsqueda por folio parcial (ej. sin prefijo o sufijo)
    parte = folio_ticket.split("-")[-1]
    res_tk_parcial = client.get(f"/api/ventas/ticket/{parte}")
    assert res_tk_parcial.status_code == 200, f"Error buscando ticket parcial: {res_tk_parcial.text}"
    print(f"Búsqueda por folio parcial '{parte}': OK")

    # 3. Emitir factura con RFC que contiene guiones (prueba de sanitización de RFC)
    fac_payload = {
        "rfc_receptor": "XAXX-010101-000",  # Con guiones
        "razon_social_receptor": "PACIENTE DE PRUEBA S.A.",
        "regimen_fiscal_receptor": "616 - Sin obligaciones fiscales",
        "codigo_postal_receptor": "44100",
        "uso_cfdi": "G03 - Gastos en general",
        "correo_factura": "paciente@farmacia.com"
    }
    res_fac = client.post(f"/api/ventas/{venta_id}/facturar", json=fac_payload)
    assert res_fac.status_code in [200, 201], f"Error emitiendo factura: {res_fac.text}"
    fac_data = res_fac.json()
    print(f"Factura generada Folio: {fac_data['folio_factura']}, UUID: {fac_data['uuid_fiscal']}")
    assert fac_data["rfc_receptor"] == "XAXX010101000", f"El RFC no fue sanitizado: {fac_data['rfc_receptor']}"
    assert fac_data["xml_cfdi"] is not None and len(fac_data["xml_cfdi"]) > 100
    print("Contenido XML CFDI 4.0 generado en respuesta: OK")

    # 4. Descargar XML oficial mediante endpoint GET
    res_xml = client.get(f"/api/ventas/{venta_id}/factura/xml")
    assert res_xml.status_code == 200, f"Error descargando XML: {res_xml.text}"
    assert "xml" in res_xml.headers.get("content-type", "")
    xml_str = res_xml.text
    assert "<cfdi:Comprobante" in xml_str
    assert "FCM2410269Z1" in xml_str
    assert "<tfd:TimbreFiscalDigital" in xml_str
    print(f"Descarga de archivo XML CFDI 4.0: OK ({len(xml_str)} bytes)")
    print("TEST SUBAGENTE 2: EXITOSO")


def test_subagent_3_optimizacion_rendimiento():
    print("\n--- TEST SUBAGENTE 3: Optimización de Rendimiento y Carga ---")
    middlewares = [getattr(m, "cls", type(m)).__name__ for m in app.user_middleware]
    print(f"Middlewares configurados en FastAPI: {middlewares}")
    assert any("GZip" in m for m in middlewares), "GZipMiddleware no encontrado en user_middleware"
    print("GZipMiddleware activo para reducción de ancho de banda y carga ultrarrápida: OK")
    print("TEST SUBAGENTE 3: EXITOSO")


if __name__ == "__main__":
    vid, ftk = test_subagent_1_clientes_cronicos_y_resurtimiento()
    test_subagent_2_facturacion_y_ticket(vid, ftk)
    test_subagent_3_optimizacion_rendimiento()
    print("\n==============================================")
    print("TODAS LAS PRUEBAS DE LOS 3 SUBAGENTES PASARON CON ÉXITO")
    print("==============================================")
