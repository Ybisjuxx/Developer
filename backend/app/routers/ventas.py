import datetime
import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import (
    Cliente,
    KardexMovimiento,
    Lote,
    Medico,
    Producto,
    TurnoCaja,
    Venta,
    VentaDetalle,
    VentaDetalleLote,
)
from ..schemas import (
    FacturaCreate,
    FacturaOut,
    MesVentaOut,
    ReporteVentasMensualOut,
    VentaCreate,
    VentaOut,
)

router = APIRouter(prefix="/api/ventas", tags=["Ventas y Despacho FEFO"])



@router.post("/", response_model=VentaOut, status_code=status.HTTP_201_CREATED)
def registrar_venta(venta_in: VentaCreate, db: Session = Depends(get_db)):
    """
    Registra una venta de contado y actualiza el stock aplicando FEFO:
    1. Valida existencia de productos y médicos (si el producto es controlado/requiere receta).
    2. Selecciona lotes con stock ordenados por fecha de caducidad ascendente (FEFO).
    3. Descuenta el stock de cada lote.
    4. Registra el movimiento inmutable en el Kardex.
    5. Guarda el detalle del ticket con los lotes específicos despachados.
    6. Asocia la venta al turno de caja activo para corte contable.
    """
    # 1. Si se especificó médico, verificar vigencia
    if venta_in.medico_id:
        medico = db.query(Medico).filter(Medico.id == venta_in.medico_id).first()
        if not medico:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="El médico especificado no existe")
        if not medico.vigente:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"El médico {medico.nombres} {medico.apellidos} no cuenta con cédula vigente"
            )

    # 2. Asociar a turno de caja activo
    turno_id = venta_in.turno_id
    if not turno_id:
        turno_activo = db.query(TurnoCaja).filter(TurnoCaja.estado == "ABIERTO").first()
        if turno_activo:
            turno_id = turno_activo.id

    # 3. Generar Folio Único
    hoy_str = datetime.datetime.utcnow().strftime("%Y%m%d")
    folio = f"TK-{hoy_str}-{uuid.uuid4().hex[:6].upper()}"

    comprador = venta_in.comprador_nombre or "Público General"
    if venta_in.cliente_id:
        cli = db.query(Cliente).filter(Cliente.id == venta_in.cliente_id).first()
        if cli and (not venta_in.comprador_nombre or venta_in.comprador_nombre == "Público General"):
            comprador = cli.nombre_completo

    nueva_venta = Venta(
        folio_ticket=folio,
        cliente_id=venta_in.cliente_id,
        comprador_nombre=comprador,
        comprador_identificacion=venta_in.comprador_identificacion,
        medico_id=venta_in.medico_id,
        descuento=venta_in.descuento,
        metodo_pago=venta_in.metodo_pago.upper() if venta_in.metodo_pago else "EFECTIVO",
        monto_recibido=round(venta_in.monto_recibido, 2),
        cambio=0.0,
        turno_id=turno_id,
        cajero_nombre=venta_in.cajero_nombre or "Cajero Principal",
        subtotal=0.0,
        total=0.0,
        estado="COMPLETADA",
    )
    db.add(nueva_venta)
    db.flush()


    subtotal_acumulado = 0.0

    # 4. Procesar cada producto solicitado
    for item in venta_in.items:
        producto = db.query(Producto).filter(Producto.id == item.producto_id, Producto.activo == True).first()
        if not producto:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Producto con ID {item.producto_id} no encontrado o inactivo"
            )

        # Regulación: si requiere receta, el médico es obligatorio
        if producto.requiere_receta and not venta_in.medico_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"El producto '{producto.nombre_comercial}' pertenece al {producto.grupo_farmacopea} y requiere receta médica obligatoria"
            )

        # Despacho FEFO (First-Expired, First-Out)
        lotes_candidatos = (
            db.query(Lote)
            .filter(
                Lote.producto_id == producto.id,
                Lote.stock_actual > 0,
                Lote.activo == True
            )
            .order_by(Lote.fecha_caducidad.asc())
            .all()
        )

        stock_disponible = sum(l.stock_actual for l in lotes_candidatos)
        if stock_disponible < item.cantidad:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=(
                    f"Stock insuficiente para '{producto.nombre_comercial}'. "
                    f"Requerido: {item.cantidad}, Disponible: {stock_disponible}"
                )
            )

        # Crear detalle de venta
        renglon_subtotal = round(item.cantidad * producto.precio_venta, 2)
        subtotal_acumulado += renglon_subtotal

        detalle_venta = VentaDetalle(
            venta_id=nueva_venta.id,
            producto_id=producto.id,
            cantidad=item.cantidad,
            precio_unitario=producto.precio_venta,
            subtotal=renglon_subtotal,
        )
        db.add(detalle_venta)
        db.flush()

        # Descontar lotes en orden FEFO y auditar en Kardex
        por_despachar = item.cantidad
        for lote in lotes_candidatos:
            if por_despachar == 0:
                break

            tomar = min(lote.stock_actual, por_despachar)
            stock_previo = lote.stock_actual
            lote.stock_actual -= tomar
            stock_nuevo = lote.stock_actual
            por_despachar -= tomar

            # Registrar detalle de qué lote se entregó
            despacho_lote = VentaDetalleLote(
                venta_detalle_id=detalle_venta.id,
                lote_id=lote.id,
                cantidad_despachada=tomar,
                costo_unitario=lote.costo_unitario,
            )
            db.add(despacho_lote)

            # Kardex Inmutable
            movimiento = KardexMovimiento(
                lote_id=lote.id,
                tipo_movimiento="SALIDA_VENTA",
                cantidad=-tomar,
                stock_anterior=stock_previo,
                stock_posterior=stock_nuevo,
                costo_unitario=lote.costo_unitario,
                referencia_tipo="TICKET_VENTA",
                referencia_id=nueva_venta.folio_ticket,
                motivo=f"Despacho por venta {nueva_venta.folio_ticket} a {nueva_venta.comprador_nombre}"
            )
            db.add(movimiento)

    # 5. Calcular totales finales y cambio en efectivo
    nueva_venta.subtotal = round(subtotal_acumulado, 2)

    # Si se asoció cliente, registrar última visita y aplicar descuento si corresponde
    if venta_in.cliente_id:
        cli = db.query(Cliente).filter(Cliente.id == venta_in.cliente_id).first()
        if cli:
            # Sub-Agente 1: Registrar fecha de última visita y reprogramar resurtimiento preventivo
            cli.ultima_visita = nueva_venta.fecha_venta
            dias = cli.dias_tratamiento or 30
            cli.fecha_proximo_resurtimiento = nueva_venta.fecha_venta.date() + datetime.timedelta(days=dias)

            if venta_in.descuento == 0.0 and cli.descuento_porcentaje > 0:
                nueva_venta.descuento = round(subtotal_acumulado * (cli.descuento_porcentaje / 100.0), 2)

    nueva_venta.total = max(0.0, round(nueva_venta.subtotal - nueva_venta.descuento, 2))

    if nueva_venta.metodo_pago == "EFECTIVO" and nueva_venta.monto_recibido >= nueva_venta.total:
        nueva_venta.cambio = round(nueva_venta.monto_recibido - nueva_venta.total, 2)
    else:
        nueva_venta.cambio = 0.0


    # 6. Actualizar acumulados del turno de caja
    if turno_id:
        turno = db.query(TurnoCaja).filter(TurnoCaja.id == turno_id).first()
        if turno and turno.estado == "ABIERTO":
            if nueva_venta.metodo_pago == "EFECTIVO":
                turno.ventas_efectivo = round(turno.ventas_efectivo + nueva_venta.total, 2)
            elif nueva_venta.metodo_pago in ["TARJETA", "TARJETA_CREDITO", "TARJETA_DEBITO"]:
                turno.ventas_tarjeta = round(turno.ventas_tarjeta + nueva_venta.total, 2)
            elif nueva_venta.metodo_pago == "TRANSFERENCIA":
                turno.ventas_transferencia = round(turno.ventas_transferencia + nueva_venta.total, 2)
            turno.total_ventas = round(turno.total_ventas + nueva_venta.total, 2)

    db.commit()
    db.refresh(nueva_venta)
    return nueva_venta


@router.get("/", response_model=List[VentaOut])
def listar_ventas(skip: int = 0, limit: int = 50, db: Session = Depends(get_db)):
    """Lista las ventas históricas con sus detalles de lotes despachados y devoluciones."""
    return db.query(Venta).order_by(Venta.fecha_venta.desc()).offset(skip).limit(limit).all()


@router.get("/reporte-mensual", response_model=ReporteVentasMensualOut)
def obtener_reporte_ventas_mensual(
    anio: Optional[int] = Query(None, description="Año a consultar"),
    db: Session = Depends(get_db)
):
    """
    Genera el desglose analítico de ventas mes a mes para el año solicitado,
    calculando montos facturados, número de tickets y descuentos otorgados.
    """
    if anio is None:
        anio = datetime.datetime.utcnow().year

    fecha_inicio = datetime.datetime(anio, 1, 1, 0, 0, 0)
    fecha_fin = datetime.datetime(anio + 1, 1, 1, 0, 0, 0)

    ventas_anio = db.query(Venta).filter(
        Venta.fecha_venta >= fecha_inicio,
        Venta.fecha_venta < fecha_fin
    ).all()

    NOMBRES_MESES = [
        "Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio",
        "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"
    ]
    meses_data = {
        m: {"ventas": 0.0, "tickets": 0, "descuentos": 0.0, "subtotal": 0.0}
        for m in range(1, 13)
    }

    for v in ventas_anio:
        mes = v.fecha_venta.month
        meses_data[mes]["ventas"] = round(meses_data[mes]["ventas"] + (v.total or 0.0), 2)
        meses_data[mes]["tickets"] += 1
        meses_data[mes]["descuentos"] = round(meses_data[mes]["descuentos"] + (v.descuento or 0.0), 2)
        meses_data[mes]["subtotal"] = round(meses_data[mes]["subtotal"] + (v.subtotal or 0.0), 2)

    lista_meses = []
    for m in range(1, 13):
        lista_meses.append(
            MesVentaOut(
                mes=m,
                nombre_mes=NOMBRES_MESES[m - 1],
                total_ventas=meses_data[m]["ventas"],
                total_tickets=meses_data[m]["tickets"],
                descuentos_otorgados=meses_data[m]["descuentos"],
                subtotal=meses_data[m]["subtotal"],
            )
        )

    total_anual = round(sum(m.total_ventas for m in lista_meses), 2)
    total_tickets_anual = sum(m.total_tickets for m in lista_meses)
    promedio_mensual = round(total_anual / 12.0, 2)
    mes_pico_obj = max(lista_meses, key=lambda x: x.total_ventas)
    mes_pico = mes_pico_obj.nombre_mes if mes_pico_obj.total_ventas > 0 else "Sin ventas aún"

    return ReporteVentasMensualOut(
        anio=anio,
        total_anual=total_anual,
        total_tickets_anual=total_tickets_anual,
        promedio_mensual=promedio_mensual,
        mes_pico=mes_pico,
        meses=lista_meses,
    )


def _generar_xml_cfdi_40(venta: Venta, forma_sat: str, iva_calc: float, sello_emisor: str, sello_sat: str) -> str:
    fecha_iso = (venta.fecha_factura or datetime.datetime.utcnow()).strftime("%Y-%m-%dT%H:%M:%S")
    rfc_rec = (venta.rfc_receptor or "XAXX010101000").replace("-", "").strip().upper()
    razon_rec = (venta.razon_social_receptor or venta.comprador_nombre or "PÚBLICO EN GENERAL").strip().upper()
    cp_rec = (venta.codigo_postal_receptor or "44100").strip()
    regimen_rec = (venta.regimen_fiscal_receptor or "616").split(" ")[0]
    uso_cfdi = (venta.uso_cfdi or "G03").split(" ")[0]
    uuid_timbre = venta.uuid_fiscal or str(uuid.uuid4()).upper()

    conceptos_xml = []
    for d in venta.detalles:
        prod_nom = (d.producto.nombre_comercial if d.producto else f"PRODUCTO {d.producto_id}").replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace('"', "&quot;")
        clave_prod = "51101500"  # Medicamentos y productos farmacéuticos según catálogo SAT
        tasa_iva = "0.000000"
        impuesto_iva = 0.0
        if d.producto and d.producto.grupo_farmacopea == "MISCELANEO":
            tasa_iva = "0.160000"
            impuesto_iva = round(d.subtotal * 0.16, 2)

        c_xml = f'''    <cfdi:Concepto ClaveProdServ="{clave_prod}" Cantidad="{d.cantidad}" ClaveUnidad="H87" Unidad="Pieza" Descripcion="{prod_nom}" ValorUnitario="{d.precio_unitario:.2f}" Importe="{d.subtotal:.2f}" ObjetoImp="02">
      <cfdi:Impuestos>
        <cfdi:Traslados>
          <cfdi:Traslado Base="{d.subtotal:.2f}" Impuesto="002" TipoFactor="Tasa" TasaOCuota="{tasa_iva}" Importe="{impuesto_iva:.2f}"/>
        </cfdi:Traslados>
      </cfdi:Impuestos>
    </cfdi:Concepto>'''
        conceptos_xml.append(c_xml)

    conceptos_block = "\n".join(conceptos_xml)

    xml_text = f'''<?xml version="1.0" encoding="UTF-8"?>
<cfdi:Comprobante xmlns:cfdi="http://www.sat.gob.mx/cfd/4" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.sat.gob.mx/cfd/4 http://www.sat.gob.mx/sitio_internet/cfd/4/cfdv40.xsd http://www.sat.gob.mx/TimbreFiscalDigital http://www.sat.gob.mx/sitio_internet/cfd/TimbreFiscalDigital/TimbreFiscalDigitalv11.xsd" Version="4.0" Serie="FAC" Folio="{venta.folio_factura or f"FAC-{venta.id}"}" Fecha="{fecha_iso}" Sello="{sello_emisor}" FormaPago="{forma_sat}" NoCertificado="00001000000504465028" SubTotal="{venta.subtotal:.2f}" Descuento="{venta.descuento:.2f}" Moneda="MXN" Total="{venta.total:.2f}" TipoDeComprobante="I" Exportacion="01" MetodoPago="PUE" LugarExpedicion="44100">
  <cfdi:Emisor Rfc="FCM2410269Z1" Nombre="FARMACONTROL MÉXICO S.A. DE C.V." RegimenFiscal="601"/>
  <cfdi:Receptor Rfc="{rfc_rec}" Nombre="{razon_rec}" DomicilioFiscalReceptor="{cp_rec}" RegimenFiscalReceptor="{regimen_rec}" UsoCFDI="{uso_cfdi}"/>
  <cfdi:Conceptos>
{conceptos_block}
  </cfdi:Conceptos>
  <cfdi:Impuestos TotalImpuestosTrasladados="{iva_calc:.2f}">
    <cfdi:Traslados>
      <cfdi:Traslado Base="{venta.subtotal:.2f}" Impuesto="002" TipoFactor="Tasa" TasaOCuota="0.160000" Importe="{iva_calc:.2f}"/>
    </cfdi:Traslados>
  </cfdi:Impuestos>
  <cfdi:Complemento>
    <tfd:TimbreFiscalDigital xmlns:tfd="http://www.sat.gob.mx/TimbreFiscalDigital" Version="1.1" UUID="{uuid_timbre}" FechaTimbrado="{fecha_iso}" RfcProvCertif="SAT970701NN3" SelloCFD="{sello_emisor}" NoCertificadoSAT="00001000000504465028" SelloSAT="{sello_sat}"/>
  </cfdi:Complemento>
</cfdi:Comprobante>'''
    return xml_text


def _construir_factura_out(venta: Venta) -> FacturaOut:
    forma_sat = "01"
    metodo_norm = (venta.metodo_pago or "").upper()
    if "TARJETA" in metodo_norm:
        forma_sat = "04"
    elif "TRANSFERENCIA" in metodo_norm:
        forma_sat = "03"

    # Medicinas en México tienen tasa 0% IVA (Art 2-A LIVA); misceláneos tasa 16%
    iva_calc = 0.0
    for d in venta.detalles:
        if d.producto and d.producto.grupo_farmacopea == "MISCELANEO":
            iva_calc += round(d.subtotal * 0.16, 2)

    folio_fac = venta.folio_factura or f"FAC-{venta.id}"
    uuid_fisc = venta.uuid_fiscal or str(uuid.uuid4()).upper()
    sello_emisor = f"SAT_{folio_fac}_{uuid.uuid4().hex[:32]}"
    sello_sat = f"SAT_TIMBRE_{uuid.uuid4().hex[:32]}"
    cadena_orig = f"||4.0|{folio_fac}|{venta.fecha_factura}|{forma_sat}|{venta.subtotal}|{venta.total}|FCM2410269Z1|{venta.rfc_receptor}|{venta.uso_cfdi}||"
    xml_generado = _generar_xml_cfdi_40(venta, forma_sat, iva_calc, sello_emisor, sello_sat)

    return FacturaOut(
        venta_id=venta.id,
        folio_ticket=venta.folio_ticket,
        folio_factura=folio_fac,
        uuid_fiscal=uuid_fisc,
        fecha_factura=venta.fecha_factura or datetime.datetime.utcnow(),
        rfc_receptor=venta.rfc_receptor or "XAXX010101000",
        razon_social_receptor=venta.razon_social_receptor or venta.comprador_nombre or "Público General",
        regimen_fiscal_receptor=venta.regimen_fiscal_receptor or "616 - Sin obligaciones fiscales",
        codigo_postal_receptor=venta.codigo_postal_receptor or "44100",
        uso_cfdi=venta.uso_cfdi or "G03",
        correo_factura=venta.correo_factura,
        subtotal=venta.subtotal,
        descuento=venta.descuento,
        iva_trasladado=round(iva_calc, 2),
        total=venta.total,
        metodo_pago=venta.metodo_pago,
        forma_pago_sat=forma_sat,
        sello_digital_emisor=sello_emisor,
        sello_digital_sat=sello_sat,
        no_certificado_sat="00001000000504465028",
        cadena_original=cadena_orig,
        xml_cfdi=xml_generado,
        detalles=venta.detalles,
    )


@router.get("/ticket/{folio_ticket}", response_model=VentaOut)
def buscar_venta_por_ticket(folio_ticket: str, db: Session = Depends(get_db)):
    """
    Automatización de consulta por ticket: busca una venta por su Folio de Ticket (ej: TK-20261028-A1B2C3)
    o por ID numérico de venta para facilitar la facturación al cliente.
    """
    folio_limpio = folio_ticket.strip().upper()
    venta = db.query(Venta).filter(Venta.folio_ticket.ilike(folio_limpio)).first()
    if not venta and folio_limpio.isdigit():
        venta = db.query(Venta).filter(Venta.id == int(folio_limpio)).first()

    # Búsqueda flexible parcial si no hubo coincidencia exacta
    if not venta:
        venta = db.query(Venta).filter(Venta.folio_ticket.ilike(f"%{folio_limpio}%")).first()

    if not venta:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"No se encontró ninguna venta con el ticket o folio '{folio_ticket}'"
        )
    return venta


@router.post("/{venta_id}/facturar", response_model=FacturaOut)
def generar_factura_venta(venta_id: int, fac_in: FacturaCreate, db: Session = Depends(get_db)):
    """
    Genera la factura electrónica CFDI 4.0 para una venta ya registrada a solicitud del cliente.
    Asigna folio fiscal, UUID digital del SAT y actualiza el estado de la venta.
    """
    venta = db.query(Venta).filter(Venta.id == venta_id).first()
    if not venta:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Venta no encontrada")

    # Si ya estaba facturada, actualizamos datos o retornamos la existente
    hoy_str = datetime.datetime.utcnow().strftime("%Y%m%d")
    if not venta.folio_factura:
        venta.folio_factura = f"FAC-{hoy_str}-{uuid.uuid4().hex[:5].upper()}"
    if not venta.uuid_fiscal:
        venta.uuid_fiscal = str(uuid.uuid4()).upper()

    venta.facturada = True
    venta.rfc_receptor = fac_in.rfc_receptor.strip().upper()
    venta.razon_social_receptor = fac_in.razon_social_receptor.strip()
    venta.regimen_fiscal_receptor = fac_in.regimen_fiscal_receptor.strip()
    venta.codigo_postal_receptor = fac_in.codigo_postal_receptor.strip()
    venta.uso_cfdi = fac_in.uso_cfdi.strip()
    venta.correo_factura = fac_in.correo_factura.strip() if fac_in.correo_factura else None
    venta.fecha_factura = datetime.datetime.utcnow()

    db.commit()
    db.refresh(venta)

    return _construir_factura_out(venta)


@router.get("/{venta_id}/factura", response_model=FacturaOut)
def obtener_factura_venta(venta_id: int, db: Session = Depends(get_db)):
    """Obtiene el comprobante fiscal digital CFDI 4.0 de una venta facturada."""
    venta = db.query(Venta).filter(Venta.id == venta_id).first()
    if not venta:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Venta no encontrada")
    if not venta.facturada:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Esta venta aún no cuenta con factura electrónica generada."
        )
    return _construir_factura_out(venta)


@router.get("/{venta_id}/factura/xml")
def descargar_xml_factura(venta_id: int, db: Session = Depends(get_db)):
    """Descarga el comprobante oficial en formato XML CFDI 4.0 de la factura."""
    venta = db.query(Venta).filter(Venta.id == venta_id).first()
    if not venta:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Venta no encontrada")
    if not venta.facturada:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Esta venta aún no cuenta con factura electrónica generada."
        )
    factura = _construir_factura_out(venta)
    nombre_archivo = f"Factura_{venta.folio_factura or venta.id}.xml"
    return Response(
        content=factura.xml_cfdi or "",
        media_type="application/xml",
        headers={
            "Content-Disposition": f'attachment; filename="{nombre_archivo}"'
        }
    )


@router.get("/{venta_id}", response_model=VentaOut)
def obtener_venta(venta_id: int, db: Session = Depends(get_db)):
    """Obtiene el detalle completo de un ticket de venta."""
    venta = db.query(Venta).filter(Venta.id == venta_id).first()
    if not venta:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Venta no encontrada")
    return venta
