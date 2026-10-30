from datetime import date, datetime
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field, field_validator


# ============================================================================
# USUARIOS Y AUTENTICACIÓN
# ============================================================================
class UsuarioBase(BaseModel):
    username: str = Field(..., min_length=3, max_length=50)
    nombre_completo: str = Field(..., min_length=3, max_length=150)
    rol: str = Field(default="CAJERO", max_length=30)  # CAJERO, ADMINISTRADOR, RESPONSABLE_SANITARIO
    activo: bool = True


class UsuarioCreate(UsuarioBase):
    password: str = Field(..., min_length=4, max_length=50)


class UsuarioUpdate(BaseModel):
    nombre_completo: Optional[str] = None
    password: Optional[str] = None
    rol: Optional[str] = None
    activo: Optional[bool] = None


class UsuarioOut(UsuarioBase):
    id: int
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)


class LoginRequest(BaseModel):
    username: str
    password: str


class LoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    usuario: UsuarioOut


# ============================================================================
# MÉDICOS
# ============================================================================
class MedicoBase(BaseModel):
    nombres: str = Field(..., min_length=2, max_length=100)
    apellidos: Optional[str] = Field(None, max_length=100)
    apellido_paterno: Optional[str] = Field(None, max_length=100)
    apellido_materno: Optional[str] = Field(None, max_length=100)
    cedula_profesional: str = Field(..., min_length=4, max_length=30)
    especialidad: Optional[str] = Field(None, max_length=100)
    institucion_emisora: Optional[str] = Field(None, max_length=150)
    telefono: Optional[str] = Field(None, max_length=20)
    correo: Optional[str] = Field(None, max_length=100)
    vigente: bool = True


class MedicoCreate(MedicoBase):
    pass


class MedicoUpdate(BaseModel):
    nombres: Optional[str] = None
    apellidos: Optional[str] = None
    apellido_paterno: Optional[str] = None
    apellido_materno: Optional[str] = None
    cedula_profesional: Optional[str] = None
    especialidad: Optional[str] = None
    institucion_emisora: Optional[str] = None
    telefono: Optional[str] = None
    correo: Optional[str] = None
    vigente: Optional[bool] = None


class MedicoOut(MedicoBase):
    id: int
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)


# ============================================================================
# ENFERMEDADES (CIE)
# ============================================================================
class EnfermedadBase(BaseModel):
    codigo_cie: str = Field(..., min_length=2, max_length=15)
    descripcion: str = Field(..., min_length=3, max_length=255)
    categoria: Optional[str] = Field(None, max_length=100)
    comentarios_especiales: Optional[str] = None
    activo: bool = True


class EnfermedadCreate(EnfermedadBase):
    pass


class EnfermedadUpdate(BaseModel):
    codigo_cie: Optional[str] = None
    descripcion: Optional[str] = None
    categoria: Optional[str] = None
    comentarios_especiales: Optional[str] = None
    activo: Optional[bool] = None


class EnfermedadOut(EnfermedadBase):
    id: int
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)


# ============================================================================
# CLIENTES E HISTORIAL CLÍNICO
# ============================================================================
class ClienteBase(BaseModel):
    nombre: str = Field(..., min_length=2, max_length=100)
    apellido: Optional[str] = Field(None, max_length=100)
    apellido_paterno: Optional[str] = Field(None, max_length=100)
    apellido_materno: Optional[str] = Field(None, max_length=100)
    correo_electronico: Optional[str] = Field(None, max_length=150)
    telefono: Optional[str] = Field(None, max_length=30)
    direccion: Optional[str] = Field(None, max_length=255)
    descuento_porcentaje: float = Field(default=5.0, ge=0.0, le=100.0)
    fecha_nacimiento: Optional[date] = None
    sexo: Optional[str] = None  # MASCULINO, FEMENINO, OTRO
    notas_clinicas: Optional[str] = None
    activo: bool = True
    # Sub-Agente 1: Seguimiento de Pacientes Crónicos y Resurtimiento Preventivo
    ultima_visita: Optional[datetime] = None
    tiene_padecimientos_cronicos: bool = False
    dias_tratamiento: int = Field(default=30, ge=1)
    fecha_proximo_resurtimiento: Optional[date] = None
    medicamento_cronico_principal: Optional[str] = None


class ClienteCreate(ClienteBase):
    enfermedades_ids: List[int] = []


class ClienteUpdate(BaseModel):
    nombre: Optional[str] = None
    apellido: Optional[str] = None
    apellido_paterno: Optional[str] = None
    apellido_materno: Optional[str] = None
    correo_electronico: Optional[str] = None
    telefono: Optional[str] = None
    direccion: Optional[str] = None
    descuento_porcentaje: Optional[float] = None
    fecha_nacimiento: Optional[date] = None
    sexo: Optional[str] = None
    notas_clinicas: Optional[str] = None
    activo: Optional[bool] = None
    enfermedades_ids: Optional[List[int]] = None
    ultima_visita: Optional[datetime] = None
    tiene_padecimientos_cronicos: Optional[bool] = None
    dias_tratamiento: Optional[int] = None
    fecha_proximo_resurtimiento: Optional[date] = None
    medicamento_cronico_principal: Optional[str] = None


class ClienteOut(ClienteBase):
    id: int
    created_at: datetime
    enfermedades: List[EnfermedadOut] = []
    alerta_resurtimiento_activa: bool = False
    dias_para_resurtimiento: Optional[int] = None
    mensaje_alerta_resurtimiento: Optional[str] = None
    model_config = ConfigDict(from_attributes=True)


# ============================================================================
# LOTES E INVENTARIO
# ============================================================================
class LoteBase(BaseModel):
    numero_lote: str = Field(..., min_length=1, max_length=50)
    fecha_fabricacion: Optional[date] = None
    fecha_caducidad: date
    costo_unitario: float = Field(..., ge=0)
    stock_actual: int = Field(..., ge=0)
    laboratorio_fabricante: Optional[str] = None
    forma_farmaceutica: Optional[str] = None
    dosificacion: Optional[str] = None
    dosis_valor: Optional[str] = None
    dosis_unidad: Optional[str] = None
    fecha_ingreso: Optional[date] = None
    activo: bool = True


class LoteCreate(LoteBase):
    producto_id: int


class LoteOut(LoteBase):
    id: int
    producto_id: int
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)


class LoteCaducidadAlertaOut(BaseModel):
    lote_id: int
    numero_lote: str
    fecha_caducidad: date
    dias_restantes: int
    urgencia: str  # CRITICA, PREVENTIVA, CADUCADO
    stock_actual: int
    costo_unitario: float
    laboratorio_fabricante: Optional[str] = None
    forma_farmaceutica: Optional[str] = None
    dosificacion: Optional[str] = None
    fecha_ingreso: Optional[date] = None
    producto_id: int
    nombre_comercial: str
    sustancia_activa: str
    presentacion: str
    laboratorio_producto: str
    precio_venta: float
    codigo_barras: str
    grupo_farmacopea: str
    requiere_receta: bool



class LoteAjusteInput(BaseModel):
    nuevo_stock: int = Field(..., ge=0)
    motivo: str = Field(..., min_length=3)
    usuario: str = Field(default="Administrador")
    rol_usuario: str = Field(default="ADMINISTRADOR")


class LoteBajaInput(BaseModel):
    motivo: str = Field(..., min_length=3)
    usuario: str = Field(default="Administrador")
    rol_usuario: str = Field(default="ADMINISTRADOR")


# ============================================================================
# PRODUCTOS
# ============================================================================
class ProductoBase(BaseModel):
    codigo_barras: str = Field(..., min_length=3, max_length=50)
    nombre_comercial: str = Field(..., min_length=2, max_length=150)
    sustancia_activa: str = Field(..., min_length=2, max_length=200)
    presentacion: str = Field(..., min_length=2, max_length=100)
    laboratorio: str = Field(..., min_length=2, max_length=100)
    grupo_farmacopea: str = Field(default="GRUPO_VI", max_length=20)
    requiere_receta: bool = False
    precio_venta: float = Field(..., ge=0)
    activo: bool = True


class ProductoCreate(ProductoBase):
    pass


class ProductoOut(ProductoBase):
    id: int
    created_at: datetime
    stock_total: int = 0
    lotes: List[LoteOut] = []
    model_config = ConfigDict(from_attributes=True)


# ============================================================================
# VENTAS Y DESPACHO FEFO
# ============================================================================
class VentaItemInput(BaseModel):
    producto_id: int
    cantidad: int = Field(..., gt=0)


class VentaCreate(BaseModel):
    cliente_id: Optional[int] = None
    comprador_nombre: Optional[str] = "Público General"
    comprador_identificacion: Optional[str] = None
    medico_id: Optional[int] = None
    descuento: float = Field(default=0.0, ge=0)
    metodo_pago: str = Field(default="EFECTIVO")  # EFECTIVO, TARJETA, TRANSFERENCIA
    monto_recibido: float = Field(default=0.0, ge=0)
    turno_id: Optional[int] = None
    cajero_nombre: Optional[str] = "Cajero Principal"
    items: List[VentaItemInput] = Field(..., min_length=1)


class VentaDetalleLoteOut(BaseModel):
    id: int
    lote_id: int
    cantidad_despachada: int
    costo_unitario: float
    model_config = ConfigDict(from_attributes=True)


class VentaDetalleOut(BaseModel):
    id: int
    producto_id: int
    producto_nombre: Optional[str] = None
    sustancia_activa: Optional[str] = None
    cantidad: int
    precio_unitario: float
    subtotal: float
    despachos_lotes: List[VentaDetalleLoteOut] = []
    model_config = ConfigDict(from_attributes=True)


class DevolucionDetalleOut(BaseModel):
    id: int
    producto_id: int
    lote_id: int
    cantidad: int
    estado_producto: str
    monto_reembolsado: float
    model_config = ConfigDict(from_attributes=True)


class DevolucionOut(BaseModel):
    id: int
    folio_devolucion: str
    venta_id: int
    fecha_devolucion: datetime
    motivo: str
    total_reembolsado: float
    metodo_reembolso: str
    cajero_nombre: str
    notas: Optional[str] = None
    detalles: List[DevolucionDetalleOut] = []
    model_config = ConfigDict(from_attributes=True)


class VentaOut(BaseModel):
    id: int
    folio_ticket: str
    fecha_venta: datetime
    cliente_id: Optional[int] = None
    cliente: Optional[ClienteOut] = None
    comprador_nombre: Optional[str]
    comprador_identificacion: Optional[str]
    medico_id: Optional[int]
    subtotal: float
    descuento: float
    total: float
    metodo_pago: str = "EFECTIVO"
    monto_recibido: float = 0.0
    cambio: float = 0.0
    turno_id: Optional[int] = None
    cajero_nombre: str = "Cajero Principal"
    estado: str
    facturada: bool = False
    folio_factura: Optional[str] = None
    rfc_receptor: Optional[str] = None
    razon_social_receptor: Optional[str] = None
    regimen_fiscal_receptor: Optional[str] = None
    codigo_postal_receptor: Optional[str] = None
    uso_cfdi: Optional[str] = None
    correo_factura: Optional[str] = None
    fecha_factura: Optional[datetime] = None
    uuid_fiscal: Optional[str] = None
    detalles: List[VentaDetalleOut] = []
    devoluciones: List[DevolucionOut] = []
    model_config = ConfigDict(from_attributes=True)


# ============================================================================
# FACTURACIÓN ELECTRÓNICA (CFDI 4.0)
# ============================================================================
class FacturaCreate(BaseModel):
    rfc_receptor: str = Field(..., min_length=12, max_length=15)
    razon_social_receptor: str = Field(..., min_length=2, max_length=200)
    regimen_fiscal_receptor: str = Field(..., min_length=3, max_length=100)
    codigo_postal_receptor: str = Field(..., min_length=5, max_length=10)
    uso_cfdi: str = Field(default="G03", max_length=50)
    correo_factura: Optional[str] = Field(None, max_length=150)

    @field_validator("rfc_receptor", mode="before")
    @classmethod
    def limpiar_rfc(cls, v: str) -> str:
        if isinstance(v, str):
            return v.replace("-", "").replace(" ", "").strip().upper()
        return v


class FacturaOut(BaseModel):
    venta_id: int
    folio_ticket: str
    folio_factura: str
    uuid_fiscal: str
    fecha_factura: datetime
    rfc_emisor: str = "FCM-241026-9Z1"
    razon_social_emisor: str = "FARMACONTROL MÉXICO S.A. DE C.V."
    regimen_fiscal_emisor: str = "601 - General de Ley Personas Morales"
    lugar_expedicion: str = "44100"
    rfc_receptor: str
    razon_social_receptor: str
    regimen_fiscal_receptor: str
    codigo_postal_receptor: str
    uso_cfdi: str
    correo_factura: Optional[str] = None
    subtotal: float
    descuento: float
    iva_trasladado: float
    total: float
    metodo_pago: str
    forma_pago_sat: str
    sello_digital_emisor: str
    sello_digital_sat: str
    no_certificado_sat: str
    cadena_original: str
    xml_cfdi: Optional[str] = None
    detalles: List[VentaDetalleOut] = []
    model_config = ConfigDict(from_attributes=True)


# ============================================================================
# DEVOLUCIONES Y MERMAS
# ============================================================================
class DevolucionItemInput(BaseModel):
    producto_id: int
    lote_id: int
    cantidad: int = Field(..., gt=0)
    estado_producto: str = Field(default="BUEN_ESTADO")  # BUEN_ESTADO, DANADO


class DevolucionCreate(BaseModel):
    venta_id: int
    motivo: str = Field(..., min_length=3)
    metodo_reembolso: str = Field(default="EFECTIVO")
    cajero_nombre: Optional[str] = "Cajero Principal"
    notas: Optional[str] = None
    items: List[DevolucionItemInput] = Field(..., min_length=1)


class MermaSanitariaOut(BaseModel):
    id: int
    devolucion_id: int
    folio_devolucion: str
    fecha_merma: datetime
    producto_nombre: str
    producto_codigo: str
    numero_lote: str
    cantidad: int
    monto_merma: float
    motivo: str
    cajero_nombre: str


MermaOut = MermaSanitariaOut


# ============================================================================
# CORTES DE CAJA Y TURNOS
# ============================================================================
class TurnoAperturaInput(BaseModel):
    cajero_nombre: str = Field(..., min_length=2, max_length=150)
    monto_apertura: float = Field(..., ge=0)
    usuario_id: Optional[int] = None
    notas: Optional[str] = None


class TurnoCierreInput(BaseModel):
    monto_cierre_efectivo: float = Field(..., ge=0)
    notas: Optional[str] = None


TurnoCajaApertura = TurnoAperturaInput
TurnoCajaCierre = TurnoCierreInput


class TurnoCajaOut(BaseModel):
    id: int
    usuario_id: Optional[int]
    cajero_nombre: str
    monto_apertura: float
    fecha_apertura: datetime
    fecha_cierre: Optional[datetime]
    ventas_efectivo: float
    ventas_tarjeta: float
    ventas_transferencia: float
    total_ventas: float
    monto_cierre_efectivo: Optional[float]
    diferencia_efectivo: Optional[float]
    estado: str
    notas: Optional[str]
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)


class TurnoResumenOut(BaseModel):
    turno: TurnoCajaOut
    total_tickets: int
    efectivo_esperado_en_caja: float  # monto_apertura + ventas_efectivo
    ventas_por_metodo: dict


# ============================================================================
# KARDEX
# ============================================================================
class KardexObservacionInput(BaseModel):
    observaciones: str = Field(..., min_length=3)
    es_irregular: bool = False
    usuario_auditor: Optional[str] = "Auditor"


class KardexMovimientoOut(BaseModel):
    id: int
    lote_id: int
    tipo_movimiento: str
    cantidad: int
    stock_anterior: int
    stock_posterior: int
    costo_unitario: float
    referencia_tipo: str
    referencia_id: str
    motivo: Optional[str]
    observaciones_auditoria: Optional[str] = None
    es_irregular: bool = False
    usuario_auditor: Optional[str] = None
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)


# ============================================================================
# REPORTES DE VENTAS ANUALES / MENSUALES
# ============================================================================
class MesVentaOut(BaseModel):
    mes: int
    nombre_mes: str
    total_ventas: float
    total_tickets: int
    descuentos_otorgados: float
    subtotal: float


class ReporteVentasMensualOut(BaseModel):
    anio: int
    total_anual: float
    total_tickets_anual: int
    promedio_mensual: float
    mes_pico: str
    meses: List[MesVentaOut]


# ============================================================================
# CONSULTA DE MEDICAMENTOS Y SUSTITUTOS CON IA
# ============================================================================
class IaConsultaInput(BaseModel):
    consulta: str = Field(..., min_length=2, max_length=500)
    historial: Optional[List[dict]] = None


class SustitutoSugeridoOut(BaseModel):
    producto_id: int
    codigo_barras: str
    nombre_comercial: str
    sustancia_activa: str
    presentacion: str
    laboratorio: str
    precio_venta: float
    stock_disponible: int
    tipo_sustitucion: str  # BIOEQUIVALENTE_DIRECTO, MISMA_FAMILIA_TERAPEUTICA, ALTERNATIVA_CLINICA
    motivo_sugerencia: str
    requiere_receta: bool
    grupo_farmacopea: str


class IaConsultaOut(BaseModel):
    pregunta: str
    respuesta_ia: str
    producto_consultado: Optional[str] = None
    disponible_en_stock: bool
    sustitutos_en_stock: List[SustitutoSugeridoOut] = []
    aviso_sanitario: str

