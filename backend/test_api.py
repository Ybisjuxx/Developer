import datetime
import sys
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def test_endpoints():
    print("========================================")
    print("INICIANDO PRUEBAS DE ENDPOINTS FASTAPI")
    print("========================================")

    # 1. Test Autenticación y Roles
    print("\n[TEST] 1. Probando Autenticación y Roles...")
    res_login = client.post("/api/auth/login", json={"username": "admin", "password": "admin123"})
    assert res_login.status_code == 200, f"Error en login: {res_login.text}"
    auth_data = res_login.json()
    print(f"[OK] Login exitoso: Usuario '{auth_data['usuario']['username']}', Rol: '{auth_data['usuario']['rol']}'")

    res_roles = client.get("/api/auth/roles")
    assert res_roles.status_code == 200
    print(f"[OK] Roles disponibles verificados: {[r['id'] for r in res_roles.json()]}")

    # 2. Test Turnos y Cortes de Caja
    print("\n[TEST] 2. Probando Turnos y Cortes de Caja...")
    res_turno = client.get("/api/caja/turno-activo")
    assert res_turno.status_code == 200
    turno = res_turno.json()
    if not turno:
        # Abrir uno
        res_abrir = client.post("/api/caja/abrir", json={
            "cajero_nombre": "Juan Daniel Morales",
            "monto_apertura": 1000.0,
            "notas": "Apertura desde test automatizado",
        })
        assert res_abrir.status_code == 201
        turno = res_abrir.json()
        print(f"[OK] Nuevo turno de caja abierto: ID {turno['id']}, Fondo Inicial: ${turno['monto_apertura']}")
    else:
        print(f"[OK] Turno de caja activo detectado: ID {turno['id']}, Cajero: {turno['cajero_nombre']}")

    # 3. Test Médicos
    print("\n[TEST] 3. Probando Médicos...")
    res_medicos = client.get("/api/medicos/")
    assert res_medicos.status_code == 200
    medicos = res_medicos.json()
    assert len(medicos) > 0
    print(f"[OK] Médicos encontrados: {len(medicos)}")
    medico_id = medicos[0]["id"]

    # 4. Test Inventario y Stock
    print("\n[TEST] 4. Probando Inventario de Productos y Lotes...")
    res_inv = client.get("/api/inventario/productos")
    assert res_inv.status_code == 200
    productos = res_inv.json()
    print(f"[OK] Productos en inventario: {len(productos)}")

    paracetamol = next((p for p in productos if "Paracetamol" in p["nombre_comercial"]), None)
    assert paracetamol is not None

    # 5. Test Venta con Método de Pago y Arqueo
    print("\n[TEST] 5. Realizando Venta en Efectivo (2 piezas de Paracetamol con pago de $100)...")
    venta_payload = {
        "comprador_nombre": "Carlos Slim",
        "medico_id": None,
        "descuento": 0.0,
        "metodo_pago": "EFECTIVO",
        "monto_recibido": 100.0,
        "turno_id": turno["id"],
        "cajero_nombre": turno["cajero_nombre"],
        "items": [
            {
                "producto_id": paracetamol["id"],
                "cantidad": 2,
            }
        ],
    }
    res_venta = client.post("/api/ventas/", json=venta_payload)
    assert res_venta.status_code == 201, f"Fallo venta: {res_venta.text}"
    ticket = res_venta.json()
    print(f"[OK] Venta registrada con éxito: Folio {ticket['folio_ticket']}, Total: ${ticket['total']}, Cambio: ${ticket['cambio']}")

    # 6. Test Resumen de Caja en Vivo
    print("\n[TEST] 6. Verificando Arqueo en Vivo de Caja...")
    res_resumen = client.get("/api/caja/resumen")
    assert res_resumen.status_code == 200
    resumen = res_resumen.json()
    print(f"[OK] Resumen de Turno: Ventas Efectivo: ${resumen['turno']['ventas_efectivo']}, Efectivo Esperado en Caja: ${resumen['efectivo_esperado_en_caja']}")

    # 7. Test Devolución (1 pza en Buen Estado)
    print("\n[TEST] 7. Probando Devolución Sanitaria...")
    primer_detalle = ticket["detalles"][0]
    primer_despacho = primer_detalle["despachos_lotes"][0]

    devolucion_payload = {
        "venta_id": ticket["id"],
        "motivo": "Empaque con ligero maltrato exterior, paciente solicita cambio",
        "metodo_reembolso": "EFECTIVO",
        "cajero_nombre": turno["cajero_nombre"],
        "items": [
            {
                "producto_id": primer_detalle["producto_id"],
                "lote_id": primer_despacho["lote_id"],
                "cantidad": 1,
                "estado_producto": "BUEN_ESTADO",
            }
        ],
    }
    res_dev = client.post("/api/devoluciones/", json=devolucion_payload)
    assert res_dev.status_code == 201, f"Error en devolución: {res_dev.text}"
    dev_out = res_dev.json()
    print(f"[OK] Devolución procesada con Folio: {dev_out['folio_devolucion']}, Reembolsado: ${dev_out['total_reembolsado']}")

    # 8. Test Kardex
    res_kardex = client.get("/api/inventario/kardex")
    assert res_kardex.status_code == 200
    print(f"[OK] Kardex verificado con {len(res_kardex.json())} movimientos auditados.")

    # 9. Test Catálogo CIE-10 (Búsqueda e Importación Dinámica)
    print("\n[TEST] 9. Probando Catálogo Oficial CIE-10 y Registro Dinámico...")
    res_cie = client.get("/api/enfermedades/catalogo-cie/buscar?q=asma")
    assert res_cie.status_code == 200, f"Error en búsqueda CIE: {res_cie.text}"
    cie_items = res_cie.json()
    assert len(cie_items) > 0, "No se encontraron diagnósticos CIE para 'asma'"
    print(f"[OK] Búsqueda CIE exitosa: {len(cie_items)} diagnósticos devueltos (ej: {cie_items[0]['codigo_cie']} - {cie_items[0]['descripcion']})")

    # Importar diagnóstico con 1 clic
    item_a_importar = cie_items[0]
    res_import = client.post("/api/enfermedades/catalogo-cie/importar", json={
        "codigo_cie": item_a_importar["codigo_cie"],
        "descripcion": item_a_importar["descripcion"],
        "categoria": item_a_importar["categoria"],
        "comentarios_especiales": item_a_importar["comentarios_especiales"],
        "activo": True
    })
    assert res_import.status_code in [200, 201], f"Error al importar CIE: {res_import.text}"
    print(f"[OK] Diagnóstico {item_a_importar['codigo_cie']} importado a base de datos de farmacia.")

    # 10. Test Sub-Agente 1: Base de Datos de Clientes e Historial Clínico CIE
    print("\n[TEST] 10. Probando Sub-Agente 1: Clientes e Historial Clínico CIE...")
    cliente_payload = {
        "nombre": "Laura",
        "apellido": "Gómez Valdés",
        "correo_electronico": "laura.gomez@test.com",
        "telefono": "555-443-2211",
        "direccion": "Calle Sol 102",
        "descuento_porcentaje": 8.0,
        "notas_clinicas": "Control trimestral de presión arterial.",
        "enfermedades_ids": [],
    }
    res_cli = client.post("/api/clientes/", json=cliente_payload)
    assert res_cli.status_code == 201, f"Error al crear cliente: {res_cli.text}"
    cliente_creado = res_cli.json()
    cli_id = cliente_creado["id"]
    print(f"[OK] Cliente registrado: {cliente_creado['nombre']} {cliente_creado['apellido']} (ID: {cli_id}) con {cliente_creado['descuento_porcentaje']}% de descuento.")

    # 11. Test Sub-Agente 2: Venta vinculando Cliente y Descuento Automático
    print("\n[TEST] 11. Probando Sub-Agente 2: Venta vinculando Cliente y Descuento...")
    venta_cli_payload = {
        "cliente_id": cli_id,
        "descuento": 0.0,  # Backend debe calcular automáticamente el 8% de Laura
        "metodo_pago": "EFECTIVO",
        "monto_recibido": 500.0,
        "turno_id": turno["id"],
        "cajero_nombre": turno["cajero_nombre"],
        "items": [
            {
                "producto_id": primer_detalle["producto_id"],
                "cantidad": 1,
            }
        ],
    }
    res_vcli = client.post("/api/ventas/", json=venta_cli_payload)
    assert res_vcli.status_code == 201, f"Error en venta con cliente: {res_vcli.text}"
    vcli_out = res_vcli.json()
    assert vcli_out["descuento"] > 0, "No se aplicó el descuento automático del cliente"
    assert vcli_out["comprador_nombre"] == "Laura Gómez Valdés"
    print(f"[OK] Venta con cliente #{vcli_out['folio_ticket']}: Subtotal ${vcli_out['subtotal']}, Descuento Cliente ${vcli_out['descuento']}, Total ${vcli_out['total']}")

    # 12. Test Sub-Agente 3: Ajuste de Piezas y Baja de Lote con Restricción de Roles
    print("\n[TEST] 12. Probando Sub-Agente 3: Gestión de Inventario con Restricción de Roles...")
    lotes_res = client.get("/api/inventario/lotes")
    assert lotes_res.status_code == 200 and len(lotes_res.json()) > 0
    target_lote = lotes_res.json()[0]
    target_lote_id = target_lote["id"]

    # 12.1 Intentar ajustar como CAJERO -> Debe responder 403 Forbidden
    res_cajero_blocked = client.post(f"/api/inventario/lotes/{target_lote_id}/ajuste", json={
        "nuevo_stock": 50,
        "motivo": "Intento no autorizado",
        "usuario": "Cajero Juan",
        "rol_usuario": "CAJERO",
    })
    assert res_cajero_blocked.status_code == 403, "Cajero no debió poder ajustar inventario"
    print("[OK] Restricción de rol verificada: Cajero bloqueado con 403 Forbidden.")

    # 12.2 Ajustar como ADMINISTRADOR -> Permitido
    stock_original = target_lote["stock_actual"]
    res_admin_ajuste = client.post(f"/api/inventario/lotes/{target_lote_id}/ajuste", json={
        "nuevo_stock": stock_original + 5,
        "motivo": "Reconteo físico de piezas en anaquel",
        "usuario": "Admin Farmacia",
        "rol_usuario": "ADMINISTRADOR",
    })
    assert res_admin_ajuste.status_code == 200, f"Error en ajuste de admin: {res_admin_ajuste.text}"
    print(f"[OK] Ajuste de piezas exitoso por Administrador. Nuevo stock: {res_admin_ajuste.json()['stock_actual']}")

    # 13. Test Sub-Agente 4: Configuración y Edición de Usuarios
    print("\n[TEST] 13. Probando Sub-Agente 4: Edición de Usuarios en Configuración...")
    res_users = client.get("/api/auth/usuarios")
    assert res_users.status_code == 200
    user_test = res_users.json()[0]
    res_update_user = client.put(f"/api/auth/usuarios/{user_test['id']}", json={
        "nombre_completo": f"{user_test['nombre_completo']} (Actualizado)",
    })
    assert res_update_user.status_code == 200
    print(f"[OK] Usuario #{user_test['id']} actualizado correctamente en configuración.")

    # 14. Test Sub-Agente 5: Comentarios y Detección de Irregularidades en Kardex
    print("\n[TEST] 14. Probando Sub-Agente 5: Comentarios de Auditoría en Kardex...")
    movs = client.get("/api/inventario/kardex").json()
    primer_mov = movs[0]
    res_obs = client.post(f"/api/inventario/kardex/{primer_mov['id']}/observaciones", json={
        "observaciones": "Movimiento auditado y validado en revisión nocturna.",
        "es_irregular": True,
        "usuario_auditor": "Lic. Alejandro Mendoza",
    })
    assert res_obs.status_code == 200, f"Error al comentar kardex: {res_obs.text}"
    mov_auditado = res_obs.json()
    assert mov_auditado["es_irregular"] is True
    assert mov_auditado["observaciones_auditoria"] is not None
    print(f"[OK] Movimiento #{primer_mov['id']} del Kardex marcado con observación y bandera de anomalía.")

    # 15. Test Sub-Agente 1: Lotes con Alertas de Caducidad FEFO
    print("\n[TEST] 15. Probando Sub-Agente 1: Endpoint de Lotes Próximos a Caducar...")
    res_cad = client.get("/api/inventario/lotes/caducidades?dias=180")
    assert res_cad.status_code == 200, f"Error en lotes caducidades: {res_cad.text}"
    lotes_cad = res_cad.json()
    assert isinstance(lotes_cad, list)
    print(f"[OK] Lotes en riesgo de caducidad detectados: {len(lotes_cad)}")
    if lotes_cad:
        primer_lote_cad = lotes_cad[0]
        assert "urgencia" in primer_lote_cad
        assert "dias_restantes" in primer_lote_cad
        print(f"     Lote: {primer_lote_cad['numero_lote']}, Producto: {primer_lote_cad['nombre_comercial']}, Urgencia: {primer_lote_cad['urgencia']}, Días: {primer_lote_cad['dias_restantes']}")

    # 16. Test Sub-Agente 2: Registro de Lote con Laboratorio, Forma, Dosis y Fecha Ingreso
    print("\n[TEST] 16. Probando Sub-Agente 2: Registro de Lote con Forma, Dosis y Laboratorio...")
    num_lote_test = f"TEST-LAB-{datetime.datetime.now().strftime('%H%M%S')}"
    res_nuevo_lote = client.post("/api/inventario/lotes", json={
        "producto_id": paracetamol["id"],
        "numero_lote": num_lote_test,
        "fecha_caducidad": "2027-12-31",
        "stock_actual": 25,
        "costo_unitario": 20.0,
        "laboratorio_fabricante": "Laboratorios Liomont S.A.",
        "forma_farmaceutica": "Tabletas",
        "dosificacion": "500 mg",
        "fecha_ingreso": "2026-10-27",
    })
    assert res_nuevo_lote.status_code == 201, f"Error al registrar lote: {res_nuevo_lote.text}"
    lote_creado = res_nuevo_lote.json()
    assert lote_creado["laboratorio_fabricante"] == "Laboratorios Liomont S.A."
    assert lote_creado["forma_farmaceutica"] == "Tabletas"
    assert lote_creado["dosificacion"] == "500 mg"
    print(f"[OK] Lote con metadatos completos registrado: Lote {lote_creado['numero_lote']} ({lote_creado['forma_farmaceutica']} {lote_creado['dosificacion']}, Lab: {lote_creado['laboratorio_fabricante']})")

    # 17. Test Sub-Agente 3: Cliente con Fecha de Nacimiento y Sexo
    print("\n[TEST] 17. Probando Sub-Agente 3: Cliente con Fecha de Nacimiento y Sexo...")
    res_cli_nac = client.post("/api/clientes/", json={
        "nombre": "Beatriz",
        "apellido": "Gutiérrez Müller",
        "correo_electronico": "beatriz.gutierrez@email.com",
        "telefono": "5599887766",
        "direccion": "Col. San Ángel, CDMX",
        "descuento_porcentaje": 10.0,
        "fecha_nacimiento": "1969-01-13",
        "sexo": "FEMENINO",
        "notas_clinicas": "Alergia leve a sulfamidas",
        "enfermedades_ids": [],
    })
    assert res_cli_nac.status_code == 201, f"Error al crear cliente con fecha nacimiento: {res_cli_nac.text}"
    cli_creado = res_cli_nac.json()
    assert cli_creado["fecha_nacimiento"] == "1969-01-13"
    assert cli_creado["sexo"] == "FEMENINO"
    print(f"[OK] Cliente registrado con fecha de nacimiento ({cli_creado['fecha_nacimiento']}) y sexo ({cli_creado['sexo']})")

    # 18. Test Sub-Agente 5: Consulta IA de Medicamentos & Sustitutos
    print("\n[TEST] 18. Probando Sub-Agente 5: Consulta IA de Medicamentos y Sustitutos en Inventario...")
    res_ia = client.post("/api/ia/consulta-medicamento", json={
        "consulta": "¿Tienen Tempra o algún sustituto con Paracetamol en existencia?",
    })
    assert res_ia.status_code == 200, f"Error en consulta IA: {res_ia.text}"
    ia_res = res_ia.json()
    assert "respuesta_ia" in ia_res
    assert isinstance(ia_res["sustitutos_en_stock"], list)
    print(f"[OK] Respuesta IA generada exitosamente. Sustitutos en existencia encontrados: {len(ia_res['sustitutos_en_stock'])}")

    # 19. Test Sub-Agente 6: Reporte Mensual de Ventas Anual
    print("\n[TEST] 19. Probando Sub-Agente 6: Reporte Mensual de Ventas para Gráfico Anual...")
    res_rep = client.get("/api/ventas/reporte-mensual?anio=2026")
    assert res_rep.status_code == 200, f"Error en reporte mensual: {res_rep.text}"
    rep_data = res_rep.json()
    assert rep_data["anio"] == 2026
    assert len(rep_data["meses"]) == 12
    print(f"[OK] Reporte anual 2026 generado. Total Anual: ${rep_data['total_anual']} MXN, Mes Pico: {rep_data['mes_pico']}, Tickets: {rep_data['total_tickets_anual']}")

    # 20. Test Sub-Agente 5: Cliente con Apellido Paterno y Materno Desglosados
    print("\n[TEST] 20. Probando Sub-Agente 5: Cliente con Apellidos Paterno y Materno Separados...")
    res_cli_apellidos = client.post("/api/clientes/", json={
        "nombre": "Guillermo",
        "apellido_paterno": "del Toro",
        "apellido_materno": "Gómez",
        "telefono": "5544332211",
        "fecha_nacimiento": "1964-10-09",
        "sexo": "MASCULINO",
        "descuento_porcentaje": 12.0,
    })
    assert res_cli_apellidos.status_code == 201, f"Error al crear cliente con apellidos desglosados: {res_cli_apellidos.text}"
    cli_ap_data = res_cli_apellidos.json()
    assert cli_ap_data["apellido_paterno"] == "del Toro"
    assert cli_ap_data["apellido_materno"] == "Gómez"
    assert "del Toro Gómez" in cli_ap_data["apellido"]
    print(f"[OK] Cliente registrado con apellidos separados: {cli_ap_data['nombre']} {cli_ap_data['apellido_paterno']} / {cli_ap_data['apellido_materno']}")

    # 21. Test Sub-Agente 2: Consulta IA con Validación Terapéutica Estricta y Solicitud de Compra
    print("\n[TEST] 21. Probando Sub-Agente 2: Consulta IA con Validación Terapéutica Estricta...")
    res_ia_terap = client.post("/api/ia/consulta-medicamento", json={
        "consulta": "¿Qué alternativas tienen para Amoxicilina si no hay?",
    })
    assert res_ia_terap.status_code == 200, f"Error en consulta IA terapéutica: {res_ia_terap.text}"
    ia_terap_data = res_ia_terap.json()
    # Verificar que los sustitutos sean de la familia de antibióticos y NO analgésicos
    for sust in ia_terap_data["sustitutos_en_stock"]:
        assert "Paracetamol" not in sust["sustancia_activa"], "ERROR: Paracetamol sugerido para antibiótico!"
        assert "Ibuprofeno" not in sust["sustancia_activa"], "ERROR: AINE sugerido para antibiótico!"
    # Verificar mensaje de deslinde y orientación
    assert "orientativo" in ia_terap_data["respuesta_ia"].lower() or "orientativo" in ia_terap_data["aviso_sanitario"].lower()
    assert "humano" in ia_terap_data["respuesta_ia"].lower() or "humano" in ia_terap_data["aviso_sanitario"].lower()
    print("[OK] IA respetó la clase terapéutica estricta (sin cruzar analgésicos con antibióticos) e incluyó deslinde humano.")

    # 22. Test Sub-Agente 1: Dispositivos Médicos y Misceláneos en Catálogo
    print("\n[TEST] 22. Probando Sub-Agente 1: Dispositivos Médicos y Misceláneos en Catálogo...")
    res_prods_all = client.get("/api/inventario/productos")
    assert res_prods_all.status_code == 200
    prods_all = res_prods_all.json()
    grupos_presentes = set(p["grupo_farmacopea"] for p in prods_all)
    print(f"[OK] Grupos de catálogo presentes: {grupos_presentes}")

    print("\n========================================")
    print("TODAS LAS 22 PRUEBAS DE BACKEND PASARON EXITOSAMENTE")
    print("========================================")


if __name__ == "__main__":
    test_endpoints()


