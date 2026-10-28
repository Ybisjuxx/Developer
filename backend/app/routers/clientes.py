from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import Cliente, Enfermedad
from ..schemas import ClienteCreate, ClienteOut, ClienteUpdate

router = APIRouter(prefix="/api/clientes", tags=["Clientes e Historial Clínico"])


@router.post("/", response_model=ClienteOut, status_code=status.HTTP_201_CREATED)
def crear_cliente(cli_in: ClienteCreate, db: Session = Depends(get_db)):
    """Registra un nuevo cliente con historial clínico opcional (diagnósticos CIE-10)."""
    datos = cli_in.model_dump(exclude={"enfermedades_ids"})
    nuevo_cliente = Cliente(**datos)

    if cli_in.enfermedades_ids:
        enfermedades = db.query(Enfermedad).filter(Enfermedad.id.in_(cli_in.enfermedades_ids)).all()
        nuevo_cliente.enfermedades = enfermedades

    db.add(nuevo_cliente)
    db.commit()
    db.refresh(nuevo_cliente)
    return nuevo_cliente


@router.get("/", response_model=List[ClienteOut])
def listar_clientes(
    buscar: Optional[str] = Query(None, description="Búsqueda por nombre, apellido, teléfono o correo"),
    solo_activos: bool = True,
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
):
    """Lista clientes registrados en la farmacia con filtros."""
    query = db.query(Cliente)
    if solo_activos:
        query = query.filter(Cliente.activo == True)
    if buscar:
        termino = f"%{buscar.strip()}%"
        query = query.filter(
            (Cliente.nombre.ilike(termino)) |
            (Cliente.apellido.ilike(termino)) |
            (Cliente.telefono.ilike(termino)) |
            (Cliente.correo_electronico.ilike(termino))
        )
    return query.order_by(Cliente.nombre.asc()).offset(skip).limit(limit).all()


@router.get("/{cliente_id}", response_model=ClienteOut)
def obtener_cliente(cliente_id: int, db: Session = Depends(get_db)):
    """Obtiene los detalles de un cliente y su historial clínico."""
    cliente = db.query(Cliente).filter(Cliente.id == cliente_id).first()
    if not cliente:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Cliente no encontrado")
    return cliente


@router.put("/{cliente_id}", response_model=ClienteOut)
def actualizar_cliente(cliente_id: int, cli_in: ClienteUpdate, db: Session = Depends(get_db)):
    """Actualiza datos personales, porcentaje de descuento o historial clínico del cliente."""
    cliente = db.query(Cliente).filter(Cliente.id == cliente_id).first()
    if not cliente:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Cliente no encontrado")

    update_data = cli_in.model_dump(exclude_unset=True, exclude={"enfermedades_ids"})
    for field, value in update_data.items():
        setattr(cliente, field, value)

    if cli_in.enfermedades_ids is not None:
        enfermedades = db.query(Enfermedad).filter(Enfermedad.id.in_(cli_in.enfermedades_ids)).all()
        cliente.enfermedades = enfermedades

    db.commit()
    db.refresh(cliente)
    return cliente


@router.delete("/{cliente_id}", status_code=status.HTTP_204_NO_CONTENT)
def desactivar_cliente(cliente_id: int, db: Session = Depends(get_db)):
    """Desactiva un cliente (soft delete)."""
    cliente = db.query(Cliente).filter(Cliente.id == cliente_id).first()
    if not cliente:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Cliente no encontrado")
    cliente.activo = False
    db.commit()
    return None
