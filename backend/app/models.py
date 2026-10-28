import datetime
from sqlalchemy import (
    Boolean,
    Column,
    Date,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    Table,
    Text,
)
from sqlalchemy.orm import relationship
from .database import Base


# Tabla pivote para historial clínico del cliente (Diagnósticos CIE-10 asociados)
cliente_enfermedades = Table(
    "cliente_enfermedades",
    Base.metadata,
    Column("cliente_id", Integer, ForeignKey("clientes.id", ondelete="CASCADE"), primary_key=True),
    Column("enfermedad_id", Integer, ForeignKey("enfermedades.id", ondelete="CASCADE"), primary_key=True),
)


class Cliente(Base):
    __tablename__ = "clientes"

    id = Column(Integer, primary_key=True, index=True)
    nombre = Column(String(100), nullable=False)
    apellido = Column(String(100), nullable=False)  # Mantenido para retrocompatibilidad
    apellido_paterno = Column(String(100), nullable=True)
    apellido_materno = Column(String(100), nullable=True)
    correo_electronico = Column(String(150), nullable=True)
    telefono = Column(String(30), nullable=True, index=True)
    direccion = Column(String(255), nullable=True)
    descuento_porcentaje = Column(Float, default=5.0, nullable=False)  # 5% por defecto para fidelización
    fecha_nacimiento = Column(Date, nullable=True)
    sexo = Column(String(20), nullable=True)  # MASCULINO, FEMENINO, OTRO
    notas_clinicas = Column(Text, nullable=True)
    activo = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime, default=datetime.datetime.utcnow, nullable=False)

    enfermedades = relationship("Enfermedad", secondary=cliente_enfermedades, backref="clientes")
    ventas = relationship("Venta", back_populates="cliente")

    @property
    def nombre_completo(self) -> str:
        apellidos = f"{self.apellido_paterno or ''} {self.apellido_materno or ''}".strip()
        if not apellidos:
            apellidos = self.apellido or ""
        return f"{self.nombre} {apellidos}".strip()


class Usuario(Base):
    __tablename__ = "usuarios"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String(50), unique=True, index=True, nullable=False)
    password_hash = Column(String(100), nullable=False)
    nombre_completo = Column(String(150), nullable=False)
    rol = Column(String(30), default="CAJERO", nullable=False)  # CAJERO, ADMINISTRADOR, RESPONSABLE_SANITARIO
    activo = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime, default=datetime.datetime.utcnow, nullable=False)

    turnos = relationship("TurnoCaja", back_populates="usuario")


class Medico(Base):
    __tablename__ = "medicos"

    id = Column(Integer, primary_key=True, index=True)
    nombres = Column(String(100), nullable=False)
    apellidos = Column(String(100), nullable=False)
    cedula_profesional = Column(String(30), unique=True, index=True, nullable=False)
    especialidad = Column(String(100), nullable=True)
    institucion_emisora = Column(String(150), nullable=True)
    telefono = Column(String(20), nullable=True)
    correo = Column(String(100), nullable=True)
    vigente = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime, default=datetime.datetime.utcnow, nullable=False)

    ventas = relationship("Venta", back_populates="medico")


class Enfermedad(Base):
    __tablename__ = "enfermedades"

    id = Column(Integer, primary_key=True, index=True)
    codigo_cie = Column(String(15), unique=True, index=True, nullable=False)
    descripcion = Column(String(255), nullable=False)
    categoria = Column(String(100), nullable=True)
    comentarios_especiales = Column(Text, nullable=True)
    activo = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime, default=datetime.datetime.utcnow, nullable=False)



class Producto(Base):
    __tablename__ = "productos"

    id = Column(Integer, primary_key=True, index=True)
    codigo_barras = Column(String(50), unique=True, index=True, nullable=False)
    nombre_comercial = Column(String(150), nullable=False)
    sustancia_activa = Column(String(200), nullable=False)
    presentacion = Column(String(100), nullable=False)
    laboratorio = Column(String(100), nullable=False)
    grupo_farmacopea = Column(String(20), nullable=False, default="GRUPO_VI")
    requiere_receta = Column(Boolean, default=False, nullable=False)
    precio_venta = Column(Float, nullable=False)
    activo = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime, default=datetime.datetime.utcnow, nullable=False)

    lotes = relationship("Lote", back_populates="producto", cascade="all, delete-orphan")
    detalles_venta = relationship("VentaDetalle", back_populates="producto")


class Lote(Base):
    __tablename__ = "lotes"

    id = Column(Integer, primary_key=True, index=True)
    producto_id = Column(Integer, ForeignKey("productos.id"), nullable=False)
    numero_lote = Column(String(50), nullable=False)
    fecha_fabricacion = Column(Date, nullable=True)
    fecha_caducidad = Column(Date, nullable=False, index=True)
    costo_unitario = Column(Float, nullable=False, default=0.0)
    stock_actual = Column(Integer, nullable=False, default=0)
    laboratorio_fabricante = Column(String(100), nullable=True)
    forma_farmaceutica = Column(String(100), nullable=True)  # Tabletas, Jarabe, Cápsulas, Solución, etc.
    dosificacion = Column(String(100), nullable=True)  # 500mg, 10mg/5ml, etc.
    fecha_ingreso = Column(Date, default=datetime.date.today, nullable=True)
    activo = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime, default=datetime.datetime.utcnow, nullable=False)

    producto = relationship("Producto", back_populates="lotes")
    despachos = relationship("VentaDetalleLote", back_populates="lote")
    movimientos_kardex = relationship("KardexMovimiento", back_populates="lote")


class KardexMovimiento(Base):
    __tablename__ = "kardex_movimientos"

    id = Column(Integer, primary_key=True, index=True)
    lote_id = Column(Integer, ForeignKey("lotes.id"), nullable=False)
    tipo_movimiento = Column(String(40), nullable=False)  # ENTRADA_COMPRA, SALIDA_VENTA, ENTRADA_DEVOLUCION, SALIDA_MERMA, SALIDA_AJUSTE, BAJA_LOTE
    cantidad = Column(Integer, nullable=False)
    stock_anterior = Column(Integer, nullable=False)
    stock_posterior = Column(Integer, nullable=False)
    costo_unitario = Column(Float, nullable=False)
    referencia_tipo = Column(String(40), nullable=False)
    referencia_id = Column(String(50), nullable=False)
    motivo = Column(Text, nullable=True)
    observaciones_auditoria = Column(Text, nullable=True)
    es_irregular = Column(Boolean, default=False, nullable=False)
    usuario_auditor = Column(String(150), nullable=True)
    created_at = Column(DateTime, default=datetime.datetime.utcnow, nullable=False)

    lote = relationship("Lote", back_populates="movimientos_kardex")


class TurnoCaja(Base):
    __tablename__ = "turnos_caja"

    id = Column(Integer, primary_key=True, index=True)
    usuario_id = Column(Integer, ForeignKey("usuarios.id"), nullable=True)
    cajero_nombre = Column(String(150), nullable=False)
    monto_apertura = Column(Float, nullable=False, default=0.0)
    fecha_apertura = Column(DateTime, default=datetime.datetime.utcnow, nullable=False)
    fecha_cierre = Column(DateTime, nullable=True)
    ventas_efectivo = Column(Float, nullable=False, default=0.0)
    ventas_tarjeta = Column(Float, nullable=False, default=0.0)
    ventas_transferencia = Column(Float, nullable=False, default=0.0)
    total_ventas = Column(Float, nullable=False, default=0.0)
    monto_cierre_efectivo = Column(Float, nullable=True)
    diferencia_efectivo = Column(Float, nullable=True)  # Positivo = Sobrante, Negativo = Faltante
    estado = Column(String(20), default="ABIERTO", nullable=False)  # ABIERTO, CERRADO
    notas = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.datetime.utcnow, nullable=False)

    usuario = relationship("Usuario", back_populates="turnos")
    ventas = relationship("Venta", back_populates="turno")


class Venta(Base):
    __tablename__ = "ventas"

    id = Column(Integer, primary_key=True, index=True)
    folio_ticket = Column(String(40), unique=True, index=True, nullable=False)
    fecha_venta = Column(DateTime, default=datetime.datetime.utcnow, nullable=False)
    cliente_id = Column(Integer, ForeignKey("clientes.id"), nullable=True)
    comprador_nombre = Column(String(150), nullable=True, default="Público General")
    comprador_identificacion = Column(String(50), nullable=True)
    medico_id = Column(Integer, ForeignKey("medicos.id"), nullable=True)
    subtotal = Column(Float, nullable=False, default=0.0)
    descuento = Column(Float, nullable=False, default=0.0)
    total = Column(Float, nullable=False, default=0.0)
    metodo_pago = Column(String(30), default="EFECTIVO", nullable=False)  # EFECTIVO, TARJETA, TRANSFERENCIA
    monto_recibido = Column(Float, nullable=False, default=0.0)
    cambio = Column(Float, nullable=False, default=0.0)
    turno_id = Column(Integer, ForeignKey("turnos_caja.id"), nullable=True)
    cajero_nombre = Column(String(150), default="Cajero Principal", nullable=False)
    estado = Column(String(20), default="COMPLETADA", nullable=False)  # COMPLETADA, DEVOLUCION_PARCIAL, DEVUELTA

    cliente = relationship("Cliente", back_populates="ventas")
    medico = relationship("Medico", back_populates="ventas")
    turno = relationship("TurnoCaja", back_populates="ventas")
    detalles = relationship("VentaDetalle", back_populates="venta", cascade="all, delete-orphan")
    devoluciones = relationship("Devolucion", back_populates="venta")



class VentaDetalle(Base):
    __tablename__ = "ventas_detalle"

    id = Column(Integer, primary_key=True, index=True)
    venta_id = Column(Integer, ForeignKey("ventas.id"), nullable=False)
    producto_id = Column(Integer, ForeignKey("productos.id"), nullable=False)
    cantidad = Column(Integer, nullable=False)
    precio_unitario = Column(Float, nullable=False)
    subtotal = Column(Float, nullable=False)

    venta = relationship("Venta", back_populates="detalles")
    producto = relationship("Producto", back_populates="detalles_venta")
    despachos_lotes = relationship("VentaDetalleLote", back_populates="venta_detalle", cascade="all, delete-orphan")


class VentaDetalleLote(Base):
    __tablename__ = "ventas_detalle_lotes"

    id = Column(Integer, primary_key=True, index=True)
    venta_detalle_id = Column(Integer, ForeignKey("ventas_detalle.id"), nullable=False)
    lote_id = Column(Integer, ForeignKey("lotes.id"), nullable=False)
    cantidad_despachada = Column(Integer, nullable=False)
    costo_unitario = Column(Float, nullable=False)

    venta_detalle = relationship("VentaDetalle", back_populates="despachos_lotes")
    lote = relationship("Lote", back_populates="despachos")


class Devolucion(Base):
    __tablename__ = "devoluciones"

    id = Column(Integer, primary_key=True, index=True)
    folio_devolucion = Column(String(40), unique=True, index=True, nullable=False)
    venta_id = Column(Integer, ForeignKey("ventas.id"), nullable=False)
    fecha_devolucion = Column(DateTime, default=datetime.datetime.utcnow, nullable=False)
    motivo = Column(String(255), nullable=False)
    total_reembolsado = Column(Float, nullable=False, default=0.0)
    metodo_reembolso = Column(String(30), default="EFECTIVO", nullable=False)  # EFECTIVO, TRANSFERENCIA
    cajero_nombre = Column(String(150), default="Cajero Principal", nullable=False)
    notas = Column(Text, nullable=True)

    venta = relationship("Venta", back_populates="devoluciones")
    detalles = relationship("DevolucionDetalle", back_populates="devolucion", cascade="all, delete-orphan")


class DevolucionDetalle(Base):
    __tablename__ = "devoluciones_detalle"

    id = Column(Integer, primary_key=True, index=True)
    devolucion_id = Column(Integer, ForeignKey("devoluciones.id"), nullable=False)
    producto_id = Column(Integer, ForeignKey("productos.id"), nullable=False)
    lote_id = Column(Integer, ForeignKey("lotes.id"), nullable=False)
    cantidad = Column(Integer, nullable=False)
    estado_producto = Column(String(30), nullable=False)  # BUEN_ESTADO, DANADO
    monto_reembolsado = Column(Float, nullable=False)

    devolucion = relationship("Devolucion", back_populates="detalles")
    producto = relationship("Producto")
    lote = relationship("Lote")
