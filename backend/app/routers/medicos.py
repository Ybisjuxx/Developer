from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import Medico, Venta
from ..schemas import MedicoCreate, MedicoOut, MedicoUpdate

router = APIRouter(prefix="/api/medicos", tags=["Médicos"])


@router.post("/", response_model=MedicoOut, status_code=status.HTTP_201_CREATED)
def crear_medico(medico_in: MedicoCreate, db: Session = Depends(get_db)):
    """Registra un nuevo médico con cédula profesional única y soporte de apellidos separados."""
    cedula_limpia = medico_in.cedula_profesional.strip().upper()
    existente = db.query(Medico).filter(Medico.cedula_profesional == cedula_limpia).first()
    if existente:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Ya existe un médico registrado con la cédula profesional '{cedula_limpia}'"
        )

    datos = medico_in.model_dump()
    datos["cedula_profesional"] = cedula_limpia

    # Desglose y consolidación de apellidos
    paterno = (datos.get("apellido_paterno") or "").strip()
    materno = (datos.get("apellido_materno") or "").strip()
    apellidos_unificados = f"{paterno} {materno}".strip()
    if not apellidos_unificados:
        apellidos_unificados = (datos.get("apellidos") or "").strip()
    if not apellidos_unificados:
        apellidos_unificados = "Sin Apellido"

    datos["apellidos"] = apellidos_unificados
    if not datos.get("apellido_paterno") and apellidos_unificados:
        datos["apellido_paterno"] = apellidos_unificados

    nuevo_medico = Medico(**datos)
    db.add(nuevo_medico)
    db.commit()
    db.refresh(nuevo_medico)
    return nuevo_medico


@router.get("/", response_model=List[MedicoOut])
def listar_medicos(
    solo_vigentes: bool = False,
    buscar: Optional[str] = Query(None, description="Búsqueda por nombre, apellido o cédula"),
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db)
):
    """Lista los médicos registrados con filtros opcionales."""
    query = db.query(Medico)
    if solo_vigentes:
        query = query.filter(Medico.vigente == True)
    if buscar:
        termino = f"%{buscar.strip()}%"
        query = query.filter(
            (Medico.nombres.ilike(termino)) |
            (Medico.apellidos.ilike(termino)) |
            (Medico.apellido_paterno.ilike(termino)) |
            (Medico.apellido_materno.ilike(termino)) |
            (Medico.cedula_profesional.ilike(termino)) |
            (Medico.especialidad.ilike(termino))
        )
    return query.order_by(Medico.vigente.desc(), Medico.nombres.asc()).offset(skip).limit(limit).all()


@router.get("/{medico_id}", response_model=MedicoOut)
def obtener_medico(medico_id: int, db: Session = Depends(get_db)):
    """Obtiene el detalle de un médico por su ID."""
    medico = db.query(Medico).filter(Medico.id == medico_id).first()
    if not medico:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Médico no encontrado")
    return medico


@router.put("/{medico_id}", response_model=MedicoOut)
def actualizar_medico(medico_id: int, medico_in: MedicoUpdate, db: Session = Depends(get_db)):
    """Actualiza datos de un médico."""
    medico = db.query(Medico).filter(Medico.id == medico_id).first()
    if not medico:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Médico no encontrado")

    update_data = medico_in.model_dump(exclude_unset=True)
    if "cedula_profesional" in update_data:
        cedula_nueva = update_data["cedula_profesional"].strip().upper()
        if cedula_nueva != medico.cedula_profesional:
            existente = db.query(Medico).filter(
                Medico.cedula_profesional == cedula_nueva,
                Medico.id != medico_id
            ).first()
            if existente:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="La cédula profesional ya está asignada a otro médico"
                )
            update_data["cedula_profesional"] = cedula_nueva

    # Sincronización de apellidos al actualizar
    if "apellido_paterno" in update_data or "apellido_materno" in update_data:
        paterno = update_data.get("apellido_paterno", medico.apellido_paterno or "")
        materno = update_data.get("apellido_materno", medico.apellido_materno or "")
        update_data["apellidos"] = f"{paterno or ''} {materno or ''}".strip() or medico.apellidos

    for field, value in update_data.items():
        setattr(medico, field, value)

    db.commit()
    db.refresh(medico)
    return medico


@router.delete("/{medico_id}")
def eliminar_medico(
    medico_id: int,
    permanente: bool = Query(False, description="Si es True y no tiene ventas, lo borra físicamente"),
    db: Session = Depends(get_db)
):
    """Elimina o da de baja a un médico de la farmacia."""
    medico = db.query(Medico).filter(Medico.id == medico_id).first()
    if not medico:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Médico no encontrado")

    tiene_ventas = db.query(Venta).filter(Venta.medico_id == medico_id).first() is not None
    if permanente and not tiene_ventas:
        nombre = medico.nombre_completo
        db.delete(medico)
        db.commit()
        return {"mensaje": f"Médico '{nombre}' eliminado permanentemente.", "eliminado_permanente": True}
    else:
        medico.vigente = False
        db.commit()
        return {
            "mensaje": f"Médico '{medico.nombre_completo}' dado de baja exitosamente.",
            "eliminado_permanente": False,
            "vigente": False
        }
