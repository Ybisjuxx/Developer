import datetime
from app.database import SessionLocal
from app.models import Venta, Producto, Medico, Lote
from app.schemas import FacturaCreate, MedicoCreate, MedicoUpdate, LoteCreate
from app.routers.ventas import buscar_venta_por_ticket, generar_factura_venta, obtener_factura_venta
from app.routers.medicos import crear_medico, actualizar_medico, eliminar_medico
from app.routers.enfermedades import buscar_catalogo_cie
from app.routers.inventario import buscar_producto_por_codigo, registrar_lote

db = SessionLocal()

print("--- PROBANDO FUNCIONALIDADES SUB-AGENTES 1 A 6 DIRECTAMENTE ---")

# 1. Sub-Agente 1: Facturación y búsqueda por ticket
v = db.query(Venta).first()
assert v is not None
venta_encontrada = buscar_venta_por_ticket(v.folio_ticket, db=db)
assert venta_encontrada.id == v.id
print(f"[OK Sub-Agente 1] Búsqueda por ticket exitosa: {venta_encontrada.folio_ticket}")

fac_in = FacturaCreate(
    rfc_receptor="FME010101XYZ",
    razon_social_receptor="FARMACIAS DE MÉXICO S.A.",
    regimen_fiscal_receptor="601 - General de Ley Personas Morales",
    codigo_postal_receptor="44100",
    uso_cfdi="G03 - Gastos en general",
    correo_factura="facturas@farmaciasmexico.com"
)
factura = generar_factura_venta(v.id, fac_in, db=db)
assert factura.folio_factura.startswith("FAC-")
assert factura.uuid_fiscal is not None
print(f"[OK Sub-Agente 1] Factura CFDI generada: {factura.folio_factura} (UUID: {factura.uuid_fiscal})")

factura_recup = obtener_factura_venta(v.id, db=db)
assert factura_recup.uuid_fiscal == factura.uuid_fiscal
print(f"[OK Sub-Agente 1] Consulta de factura generada validada.")

# 2. Sub-Agente 2: Consulta CIE mejorada
cie_res = buscar_catalogo_cie(q="hipertension arterial", limit=30, db=db)
assert len(cie_res) > 0
assert any("I10" in r["codigo_cie"] for r in cie_res)
print(f"[OK Sub-Agente 2] Catálogo CIE enriquecido: {len(cie_res)} resultados para 'hipertension arterial' (Top: {cie_res[0]['codigo_cie']} - {cie_res[0]['descripcion']})")

cie_res2 = buscar_catalogo_cie(q="resfriado", limit=30, db=db)
assert len(cie_res2) > 0
print(f"[OK Sub-Agente 2] Búsqueda por síntoma 'resfriado' localizó: {cie_res2[0]['codigo_cie']} - {cie_res2[0]['descripcion']}")

# 3. Sub-Agente 3: Médico con apellidos separados
cedula = f"CED-{datetime.datetime.now().strftime('%H%M%S')}"
med_in = MedicoCreate(
    nombres="Manuel",
    apellido_paterno="de la Cruz",
    apellido_materno="Montes",
    cedula_profesional=cedula,
    especialidad="Medicina General",
    vigente=True
)
med = crear_medico(med_in, db=db)
assert med.apellido_paterno == "de la Cruz"
assert med.apellido_materno == "Montes"
assert "de la Cruz Montes" in med.apellidos
print(f"[OK Sub-Agente 3] Médico registrado con apellidos separados: {med.nombre_completo} (Cédula: {med.cedula_profesional})")

# 4. Sub-Agente 4: Editar y Borrar médico
med_up = MedicoUpdate(especialidad="Cardiología Clínica", telefono="3312345678")
med_edit = actualizar_medico(med.id, med_up, db=db)
assert med_edit.especialidad == "Cardiología Clínica"
print(f"[OK Sub-Agente 4] Médico #{med.id} editado exitosamente: {med_edit.especialidad}")

del_res = eliminar_medico(med.id, permanente=True, db=db)
assert del_res["eliminado_permanente"] is True
print(f"[OK Sub-Agente 4] Médico #{med.id} eliminado exitosamente ({del_res['mensaje']})")

# 5. Sub-Agente 5: Nombre del producto e ID de inventario en detalles
db.refresh(v)
det = v.detalles[0]
assert det.producto_id is not None
assert det.producto_nombre is not None and len(det.producto_nombre) > 0
print(f"[OK Sub-Agente 5] Detalle de venta contiene ID #{det.producto_id} y Nombre '{det.producto_nombre}' (Lote privado para devolución/merma)")

# 6. Sub-Agente 6: Dosis separada y verificación de código de barras
prod = db.query(Producto).first()
prod_buscado = buscar_producto_por_codigo(prod.codigo_barras, db=db)
assert prod_buscado.id == prod.id
print(f"[OK Sub-Agente 6] Código de barras previamente registrado verificado para autocompletado: {prod_buscado.codigo_barras} -> {prod_buscado.nombre_comercial}")

lote_num = f"DOSIS-{datetime.datetime.now().strftime('%H%M%S')}"
lote_in = LoteCreate(
    producto_id=prod.id,
    numero_lote=lote_num,
    fecha_caducidad=datetime.date(2028, 12, 31),
    stock_actual=15,
    costo_unitario=25.0,
    forma_farmaceutica="Tableta",
    dosis_valor="100",
    dosis_unidad="mg",
    fecha_ingreso=datetime.date.today(),
    activo=True
)
lote_creado = registrar_lote(lote_in, db=db)
assert lote_creado.dosis_valor == "100"
assert lote_creado.dosis_unidad == "mg"
assert "Tableta | 100 | mg" in lote_creado.dosificacion
print(f"[OK Sub-Agente 6] Lote con dosis separada de dosificación creado exitosamente: {lote_creado.dosificacion}")

db.close()
print("=========================================================================")
print("TODAS LAS VERIFICACIONES DE LOS SUB-AGENTES 1 AL 6 COMPLETADAS (100% OK)")
print("=========================================================================")
