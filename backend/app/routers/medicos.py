from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import Medico
from ..schemas import MedicoCreate, MedicoOut, MedicoUpdate

router = APIRouter(prefix="/api/medicos", tags=["Médicos"])


@router.post("/", response_model=MedicoOut, status_code=status.HTTP_201_CREATED)
def crear_medico(medico_in: MedicoCreate, db: Session = Depends(get_db)):
    """Registra un nuevo médico con cédula profesional única."""
    existente = db.query(Medico).filter(Medico.cedula_profesional == medico_in.cedula_profesional.strip()).first()
    if existente:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Ya existe un médico registrado con la cédula profesional '{medico_in.cedula_profesional}'"
        )
    
    nuevo_medico = Medico(**medico_in.model_dump())
    db.add(nuevo_medico)
    db.commit()
    db.refresh(nuevo_medico)
    return nuevo_medico


@router.get("/", response_model=List[MedicoOut])
def listar_medicos(
    solo_vigentes: bool = True,
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
            (Medico.cedula_profesional.ilike(termino)) |
            (Medico.especialidad.ilike(termino))
        )
    return query.offset(skip).limit(limit).all()


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
    if "cedula_profesional" in update_data and update_data["cedula_profesional"] != medico.cedula_profesional:
        existente = db.query(Medico).filter(
            Medico.cedula_profesional == update_data["cedula_profesional"],
            Medico.id != medico_id
        ).first()
        if existente:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="La cédula profesional ya está asignada a otro médico"
            )

    for field, value in update_data.items():
        setattr(medico, field, value)

    db.commit()
    db.refresh(medico)
    return medico


@router.delete("/{medico_id}", status_code=status.HTTP_204_NO_CONTENT)
def eliminar_medico(medico_id: int, db: Session = Depends(get_db)):
    """Eliminación lógica (desactiva vigencia) o física de un médico."""
    medico = db.query(Medico).filter(Medico.id == medico_id).first()
    if not medico:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Médico no encontrado")
    
    # Marcamos como no vigente para preservar integridad de recetas/ventas históricas
    medico.vigente = False
    db.commit()
    return None
