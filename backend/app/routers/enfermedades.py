from typing import Any, Dict, List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from ..catalogo_cie import buscar_en_catalogo_cie_local, consultar_api_cie_externa
from ..database import get_db
from ..models import Enfermedad
from ..schemas import EnfermedadCreate, EnfermedadOut, EnfermedadUpdate

router = APIRouter(prefix="/api/enfermedades", tags=["Enfermedades (CIE)"])


@router.get("/catalogo-cie/buscar", response_model=List[Dict[str, Any]])
def buscar_catalogo_cie(
    q: str = Query(..., min_length=1, description="Código CIE o nombre de la patología a consultar"),
    limit: int = Query(30, ge=1, le=100),
    db: Session = Depends(get_db)
):
    """
    Busca diagnósticos en el Catálogo Oficial CIE-10 (híbrido local + API externa NIH/WHO).
    Verifica automáticamente contra la base de datos de la farmacia para indicar
    si el diagnóstico ya se encuentra registrado o está listo para incorporarse.
    """
    resultados_locales = buscar_en_catalogo_cie_local(q, limit=limit)
    
    # Si pocos resultados o búsqueda específica de código raro, complementar con API externa
    if len(resultados_locales) < 5 and len(q.strip()) >= 3:
        externos = consultar_api_cie_externa(q, limit=10)
        codigos_existentes = {r["codigo"].upper() for r in resultados_locales}
        for ext in externos:
            if ext["codigo"].upper() not in codigos_existentes:
                resultados_locales.append(ext)
                codigos_existentes.add(ext["codigo"].upper())

    # Cruzar con diagnósticos ya registrados en la base de datos local
    codigos_lista = [r["codigo"].strip().upper() for r in resultados_locales]
    db_enfermedades = db.query(Enfermedad).filter(Enfermedad.codigo_cie.in_(codigos_lista)).all()
    mapa_db = {enf.codigo_cie.upper(): enf for enf in db_enfermedades}

    enriquecidos = []
    for r in resultados_locales[:limit]:
        cod = r["codigo"].strip().upper()
        enf_db = mapa_db.get(cod)
        enriquecidos.append({
            "codigo_cie": cod,
            "descripcion": r.get("descripcion", ""),
            "categoria": r.get("categoria", "General"),
            "comentarios_especiales": r.get("nota", ""),
            "ya_registrado": enf_db is not None,
            "enfermedad_id": enf_db.id if enf_db else None,
            "activo": enf_db.activo if enf_db else True
        })

    return enriquecidos


@router.post("/catalogo-cie/importar", response_model=EnfermedadOut, status_code=status.HTTP_201_CREATED)
def importar_desde_catalogo_cie(enf_in: EnfermedadCreate, db: Session = Depends(get_db)):
    """
    Importa un diagnóstico desde el Catálogo CIE a la base de datos de la farmacia con 1 clic.
    Si ya existe, retorna el registro existente sin duplicar ni arrojar error.
    """
    codigo_limpio = enf_in.codigo_cie.strip().upper()
    existente = db.query(Enfermedad).filter(Enfermedad.codigo_cie == codigo_limpio).first()
    if existente:
        if not existente.activo:
            existente.activo = True
            db.commit()
            db.refresh(existente)
        return existente

    datos = enf_in.model_dump()
    datos["codigo_cie"] = codigo_limpio
    nueva_enf = Enfermedad(**datos)
    db.add(nueva_enf)
    db.commit()
    db.refresh(nueva_enf)
    return nueva_enf


@router.post("/auto-registrar", response_model=EnfermedadOut)
def auto_registrar_enfermedad(enf_in: EnfermedadCreate, db: Session = Depends(get_db)):
    """
    Permite el registro dinámico de enfermedades conforme se van registrando recetas o ventas.
    """
    codigo_limpio = enf_in.codigo_cie.strip().upper()
    existente = db.query(Enfermedad).filter(Enfermedad.codigo_cie == codigo_limpio).first()
    if existente:
        return existente

    datos = enf_in.model_dump()
    datos["codigo_cie"] = codigo_limpio
    nueva = Enfermedad(**datos)
    db.add(nueva)
    db.commit()
    db.refresh(nueva)
    return nueva


@router.post("/", response_model=EnfermedadOut, status_code=status.HTTP_201_CREATED)
def crear_enfermedad(enf_in: EnfermedadCreate, db: Session = Depends(get_db)):
    """Registra una nueva enfermedad o diagnóstico CIE manualmente con comentarios especiales."""
    codigo_limpio = enf_in.codigo_cie.strip().upper()
    existente = db.query(Enfermedad).filter(Enfermedad.codigo_cie == codigo_limpio).first()
    if existente:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Ya existe un diagnóstico registrado con el código CIE '{codigo_limpio}'"
        )
    
    datos = enf_in.model_dump()
    datos["codigo_cie"] = codigo_limpio
    nueva_enf = Enfermedad(**datos)
    db.add(nueva_enf)
    db.commit()
    db.refresh(nueva_enf)
    return nueva_enf


@router.get("/", response_model=List[EnfermedadOut])
def listar_enfermedades(
    solo_activas: bool = True,
    buscar: Optional[str] = Query(None, description="Búsqueda por código CIE, descripción o categoría"),
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db)
):
    """Lista diagnósticos y enfermedades registrados en la farmacia con búsqueda."""
    query = db.query(Enfermedad)
    if solo_activas:
        query = query.filter(Enfermedad.activo == True)
    if buscar:
        termino = f"%{buscar.strip()}%"
        query = query.filter(
            (Enfermedad.codigo_cie.ilike(termino)) |
            (Enfermedad.descripcion.ilike(termino)) |
            (Enfermedad.categoria.ilike(termino)) |
            (Enfermedad.comentarios_especiales.ilike(termino))
        )
    return query.order_by(Enfermedad.codigo_cie.asc()).offset(skip).limit(limit).all()


@router.get("/{enfermedad_id}", response_model=EnfermedadOut)
def obtener_enfermedad(enfermedad_id: int, db: Session = Depends(get_db)):
    """Obtiene una enfermedad por su ID."""
    enf = db.query(Enfermedad).filter(Enfermedad.id == enfermedad_id).first()
    if not enf:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Enfermedad no encontrada")
    return enf


@router.put("/{enfermedad_id}", response_model=EnfermedadOut)
def actualizar_enfermedad(enfermedad_id: int, enf_in: EnfermedadUpdate, db: Session = Depends(get_db)):
    """Actualiza la información de una enfermedad."""
    enf = db.query(Enfermedad).filter(Enfermedad.id == enfermedad_id).first()
    if not enf:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Enfermedad no encontrada")

    update_data = enf_in.model_dump(exclude_unset=True)
    if "codigo_cie" in update_data and update_data["codigo_cie"]:
        codigo_limpio = update_data["codigo_cie"].strip().upper()
        if codigo_limpio != enf.codigo_cie:
            existente = db.query(Enfermedad).filter(
                Enfermedad.codigo_cie == codigo_limpio,
                Enfermedad.id != enfermedad_id
            ).first()
            if existente:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"El código CIE '{codigo_limpio}' ya está registrado"
                )
        update_data["codigo_cie"] = codigo_limpio

    for field, value in update_data.items():
        setattr(enf, field, value)

    db.commit()
    db.refresh(enf)
    return enf


@router.delete("/{enfermedad_id}", status_code=status.HTTP_204_NO_CONTENT)
def eliminar_enfermedad(enfermedad_id: int, db: Session = Depends(get_db)):
    """Desactiva una enfermedad (soft delete)."""
    enf = db.query(Enfermedad).filter(Enfermedad.id == enfermedad_id).first()
    if not enf:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Enfermedad no encontrada")
    enf.activo = False
    db.commit()
    return None
