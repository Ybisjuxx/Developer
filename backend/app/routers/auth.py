from typing import List
from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import Usuario
from ..schemas import LoginRequest, LoginResponse, UsuarioCreate, UsuarioOut, UsuarioUpdate
from ..security import (
    _bearer,
    create_token,
    hash_password,
    needs_rehash,
    rate_limiter,
    require_roles,
    revoke_token,
    verify_password,
)

router = APIRouter(prefix="/api/auth", tags=["Autenticación y Roles"])


@router.post("/login", response_model=LoginResponse)
def login(creds: LoginRequest, request: Request, db: Session = Depends(get_db)):
    """Inicia sesión validando credenciales, aplica rate-limit y retorna el token firmado."""
    client_ip = request.client.host if request.client else "unknown"
    rate_limiter.check_login(client_ip, creds.username)

    usuario = db.query(Usuario).filter(Usuario.username == creds.username).first()
    if not usuario or not usuario.activo:
        rate_limiter.record_login_failure(client_ip, creds.username)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Usuario o contraseña incorrectos",
        )

    if not verify_password(creds.password, usuario.password_hash):
        rate_limiter.record_login_failure(client_ip, creds.username)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Usuario o contraseña incorrectos",
        )

    rate_limiter.clear_login_failures(client_ip, creds.username)

    # Migración transparente de hashes heredados (SHA-256 sin sal) a PBKDF2
    if needs_rehash(usuario.password_hash):
        usuario.password_hash = hash_password(creds.password)
        db.commit()
        db.refresh(usuario)

    token = create_token(usuario)
    return LoginResponse(
        access_token=token,
        token_type="bearer",
        usuario=UsuarioOut.model_validate(usuario),
    )


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
def logout(request: Request):
    """Revoca el token Bearer activo para invalidar la sesión."""
    revoke_token(_bearer(request))
    return None


@router.get("/usuarios", response_model=List[UsuarioOut])
def listar_usuarios(solo_activos: bool = False, _admin=Depends(require_roles("ADMINISTRADOR")), db: Session = Depends(get_db)):
    """Lista los usuarios registrados en el sistema de farmacia."""
    query = db.query(Usuario)
    if solo_activos:
        query = query.filter(Usuario.activo == True)
    return query.order_by(Usuario.id.asc()).all()


@router.post("/usuarios", response_model=UsuarioOut, status_code=status.HTTP_201_CREATED)
def crear_usuario(usuario_in: UsuarioCreate, _admin=Depends(require_roles("ADMINISTRADOR")), db: Session = Depends(get_db)):
    """Registra un nuevo usuario con rol específico."""
    existente = db.query(Usuario).filter(Usuario.username == usuario_in.username).first()
    if existente:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"El nombre de usuario '{usuario_in.username}' ya está registrado",
        )

    nuevo = Usuario(
        username=usuario_in.username,
        password_hash=hash_password(usuario_in.password),
        nombre_completo=usuario_in.nombre_completo,
        rol=usuario_in.rol,
        activo=usuario_in.activo,
    )
    db.add(nuevo)
    db.commit()
    db.refresh(nuevo)
    return nuevo


@router.put("/usuarios/{usuario_id}", response_model=UsuarioOut)
def actualizar_usuario(usuario_id: int, user_in: UsuarioUpdate, _admin=Depends(require_roles("ADMINISTRADOR")), db: Session = Depends(get_db)):
    """Actualiza datos del usuario (nombre, contraseña, rol o estado activo)."""
    usuario = db.query(Usuario).filter(Usuario.id == usuario_id).first()
    if not usuario:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Usuario no encontrado")

    if user_in.nombre_completo is not None:
        usuario.nombre_completo = user_in.nombre_completo.strip()
    if user_in.rol is not None:
        usuario.rol = user_in.rol.strip()
    if user_in.activo is not None:
        usuario.activo = user_in.activo
    if user_in.password and user_in.password.strip():
        usuario.password_hash = hash_password(user_in.password.strip())

    db.commit()
    db.refresh(usuario)
    return usuario


@router.delete("/usuarios/{usuario_id}", status_code=status.HTTP_204_NO_CONTENT)
def desactivar_usuario(usuario_id: int, _admin=Depends(require_roles("ADMINISTRADOR")), db: Session = Depends(get_db)):
    """Desactiva un usuario del sistema (soft delete)."""
    usuario = db.query(Usuario).filter(Usuario.id == usuario_id).first()
    if not usuario:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Usuario no encontrado")
    usuario.activo = False
    db.commit()
    return None


@router.get("/roles")
def obtener_roles():
    """Retorna los roles disponibles y sus descripciones operativas."""
    return [
        {
            "id": "CAJERO",
            "nombre": "Cajero de Mostrador",
            "permisos": ["Cobro en POS", "Consulta de stock", "Apertura y corte de caja personal"],
        },
        {
            "id": "ADMINISTRADOR",
            "nombre": "Administrador General",
            "permisos": ["Acceso total", "Arqueo de turnos", "Autorización de mermas", "Reportes financieros"],
        },
        {
            "id": "RESPONSABLE_SANITARIO",
            "nombre": "Responsable Sanitario (QFB/Médico)",
            "permisos": ["Validación de cédulas de médicos", "Autorización de controlados", "Auditoría de recetas y FEFO"],
        },
    ]
