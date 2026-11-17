"""
Seguridad: hash de contraseñas, tokens firmados y dependencia de autenticación.

- Contraseñas: PBKDF2-HMAC-SHA256 con sal aleatoria (stdlib, sin dependencias nuevas).
  Los hashes SHA-256 heredados (sin sal) se aceptan una vez y se re-hashean al iniciar sesión.
- Tokens: HMAC-SHA256 firmados con FARMACONTROL_SECRET_KEY, con expiración.
- Aplicación: si AUTH_REQUIRED=1, todas las rutas (excepto login/health/docs) exigen
  `Authorization: Bearer <token>`. Con AUTH_REQUIRED=0 (predeterminado mientras el
  frontend se migra) el token es opcional pero, si llega, se valida y su rol prevalece
  sobre cualquier rol declarado en el cuerpo de la petición.
"""
import base64
import hashlib
import hmac
import json
import os
import secrets
import threading
import time
from collections import defaultdict, deque
from typing import Deque, Dict, Optional, Set, Tuple

from cryptography.fernet import Fernet, InvalidToken
from fastapi import Depends, HTTPException, Request, status
from sqlalchemy.orm import Session

from .database import get_db
from .models import Usuario

PBKDF2_ITERATIONS = 310_000
TOKEN_TTL_SECONDS = int(os.getenv("TOKEN_TTL_SECONDS", str(12 * 3600)))
AUTH_REQUIRED = os.getenv("AUTH_REQUIRED", "1").strip().lower() in {"1", "true", "yes", "si"}
ENV_MODE = os.getenv("ENV", "development").strip().lower()

_SECRET = os.getenv("FARMACONTROL_SECRET_KEY")
if not _SECRET:
    # Sin clave configurada se genera una efímera: los tokens caducan al reiniciar el servidor.
    _SECRET = secrets.token_urlsafe(48)
    if AUTH_REQUIRED:
        print("AVISO: FARMACONTROL_SECRET_KEY no definida; se usa una clave efímera.")
_SECRET_BYTES = _SECRET.encode("utf-8")

# Clave Fernet derivada para cifrado simétrico de PII en reposo
_PII_RAW = os.getenv("FARMACONTROL_PII_KEY")
if _PII_RAW:
    _FERNET_KEY = base64.urlsafe_b64encode(hashlib.sha256(_PII_RAW.encode("utf-8")).digest())
else:
    _FERNET_KEY = base64.urlsafe_b64encode(hashlib.sha256(_SECRET_BYTES).digest())
_FERNET = Fernet(_FERNET_KEY)
_PII_PREFIX = "enc::"


def encrypt_pii(value: Optional[str]) -> Optional[str]:
    """Cifra datos personales sensibles (PII) en reposo con Fernet."""
    if value is None:
        return None
    text = str(value).strip()
    if not text or text.startswith(_PII_PREFIX):
        return text
    token = _FERNET.encrypt(text.encode("utf-8")).decode("ascii")
    return f"{_PII_PREFIX}{token}"


def decrypt_pii(value: Optional[str]) -> Optional[str]:
    """Descifra datos PII cifrados; mantiene retrocompatibilidad con texto plano."""
    if value is None:
        return None
    text = str(value)
    if not text.startswith(_PII_PREFIX):
        return text
    try:
        raw = _FERNET.decrypt(text[len(_PII_PREFIX):].encode("ascii"))
        return raw.decode("utf-8")
    except InvalidToken:
        return "[DATO PROTEGIDO]"


# ---------------------------------------------------------------------------
# Rate Limiting & Anti-Bots en memoria
# ---------------------------------------------------------------------------
class _InMemoryRateLimiter:
    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._login_failures: Dict[Tuple[str, str], Deque[float]] = defaultdict(deque)
        self._login_locked_until: Dict[Tuple[str, str], float] = {}
        self._endpoint_hits: Dict[str, Deque[float]] = defaultdict(deque)

    def check_login(self, ip: str, username: str) -> None:
        key = (ip or "unknown", (username or "").lower().strip())
        now = time.time()
        with self._lock:
            locked_until = self._login_locked_until.get(key, 0.0)
            if locked_until > now:
                retry_after = int(max(1, locked_until - now))
                raise HTTPException(
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                    detail=f"Demasiados intentos fallidos. Intenta de nuevo en {retry_after}s.",
                    headers={"Retry-After": str(retry_after)},
                )

    def record_login_failure(self, ip: str, username: str, max_attempts: int = 5, window_sec: int = 60) -> None:
        key = (ip or "unknown", (username or "").lower().strip())
        now = time.time()
        with self._lock:
            q = self._login_failures[key]
            while q and now - q[0] > window_sec:
                q.popleft()
            q.append(now)
            if len(q) >= max_attempts:
                # Bloqueo progresivo de 60 segundos
                self._login_locked_until[key] = now + window_sec
                q.clear()

    def clear_login_failures(self, ip: str, username: str) -> None:
        key = (ip or "unknown", (username or "").lower().strip())
        with self._lock:
            self._login_failures.pop(key, None)
            self._login_locked_until.pop(key, None)

    def check_endpoint(self, key: str, max_requests: int = 30, window_sec: int = 60) -> None:
        now = time.time()
        with self._lock:
            q = self._endpoint_hits[key]
            while q and now - q[0] > window_sec:
                q.popleft()
            if len(q) >= max_requests:
                retry_after = int(max(1, window_sec - (now - q[0])))
                raise HTTPException(
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                    detail="Límite de solicitudes excedido. Espera un momento.",
                    headers={"Retry-After": str(retry_after)},
                )
            q.append(now)


rate_limiter = _InMemoryRateLimiter()
_REVOKED_TOKENS: Dict[str, float] = {}
_REVOKED_LOCK = threading.Lock()


def _purge_expired_revocations(now: float) -> None:
    expired = [k for k, exp in _REVOKED_TOKENS.items() if exp <= now]
    for k in expired:
        _REVOKED_TOKENS.pop(k, None)


# ---------------------------------------------------------------------------
# Contraseñas
# ---------------------------------------------------------------------------
def hash_password(password: str) -> str:
    salt = secrets.token_bytes(16)
    dk = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, PBKDF2_ITERATIONS)
    return f"pbkdf2_sha256${PBKDF2_ITERATIONS}${salt.hex()}${dk.hex()}"


def _is_legacy_sha256(stored: str) -> bool:
    return len(stored) == 64 and all(c in "0123456789abcdef" for c in stored.lower())


def verify_password(password: str, stored: str) -> bool:
    if not stored:
        return False
    if stored.startswith("pbkdf2_sha256$"):
        try:
            _, iters, salt_hex, dk_hex = stored.split("$")
            dk = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), bytes.fromhex(salt_hex), int(iters))
            return hmac.compare_digest(dk.hex(), dk_hex)
        except (ValueError, TypeError):
            return False
    if _is_legacy_sha256(stored):
        legacy = hashlib.sha256(password.encode("utf-8")).hexdigest()
        return hmac.compare_digest(legacy, stored.lower())
    # Nunca se acepta texto plano ni el hash como contraseña.
    return False


def needs_rehash(stored: str) -> bool:
    return not stored.startswith(f"pbkdf2_sha256${PBKDF2_ITERATIONS}$")


# ---------------------------------------------------------------------------
# Tokens firmados
# ---------------------------------------------------------------------------
def _b64(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def _unb64(data: str) -> bytes:
    return base64.urlsafe_b64decode(data + "=" * (-len(data) % 4))


def create_token(usuario: Usuario) -> str:
    payload = {
        "sub": usuario.id,
        "rol": usuario.rol,
        "jti": secrets.token_hex(12),
        "exp": int(time.time()) + TOKEN_TTL_SECONDS,
    }
    body = _b64(json.dumps(payload, separators=(",", ":")).encode("utf-8"))
    sig = _b64(hmac.new(_SECRET_BYTES, body.encode("ascii"), hashlib.sha256).digest())
    return f"{body}.{sig}"


def revoke_token(token: Optional[str]) -> None:
    if not token:
        return
    payload = decode_token(token)
    if payload and payload.get("jti"):
        now = time.time()
        exp = float(payload.get("exp") or (now + TOKEN_TTL_SECONDS))
        with _REVOKED_LOCK:
            _purge_expired_revocations(now)
            _REVOKED_TOKENS[str(payload["jti"])] = exp


def decode_token(token: str) -> Optional[dict]:
    try:
        body, sig = token.split(".", 1)
        expected = _b64(hmac.new(_SECRET_BYTES, body.encode("ascii"), hashlib.sha256).digest())
        if not hmac.compare_digest(sig, expected):
            return None
        payload = json.loads(_unb64(body))
        now = time.time()
        if int(payload.get("exp", 0)) < now:
            return None
        jti = payload.get("jti")
        if jti:
            with _REVOKED_LOCK:
                _purge_expired_revocations(now)
                if str(jti) in _REVOKED_TOKENS:
                    return None
        return payload
    except Exception:
        return None


# ---------------------------------------------------------------------------
# Dependencias FastAPI
# ---------------------------------------------------------------------------
_PUBLIC_PATHS = {"/", "/api/health", "/api/auth/login", "/api/auth/roles"}
if ENV_MODE != "production":
    _PUBLIC_PATHS.update({"/docs", "/redoc", "/openapi.json"})


def _bearer(request: Request) -> Optional[str]:
    auth = request.headers.get("Authorization", "")
    if auth.lower().startswith("bearer "):
        return auth[7:].strip()
    return None


def get_current_user_optional(request: Request, db: Session = Depends(get_db)) -> Optional[Usuario]:
    token = _bearer(request)
    if not token:
        return None
    payload = decode_token(token)
    if not payload:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token inválido o expirado")
    usuario = db.query(Usuario).filter(Usuario.id == payload.get("sub"), Usuario.activo == True).first()
    if not usuario:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Usuario inactivo o inexistente")
    return usuario


def auth_guard(request: Request, usuario: Optional[Usuario] = Depends(get_current_user_optional)) -> Optional[Usuario]:
    """Dependencia global: exige sesión cuando AUTH_REQUIRED está activo."""
    if AUTH_REQUIRED and usuario is None and request.url.path not in _PUBLIC_PATHS:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Autenticación requerida",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return usuario


def require_roles(*roles: str):
    """Restringe un endpoint a ciertos roles (solo efectivo cuando hay sesión o AUTH_REQUIRED)."""
    roles_set = {r.upper() for r in roles}

    def _dep(usuario: Optional[Usuario] = Depends(get_current_user_optional)) -> Optional[Usuario]:
        if usuario is None:
            if AUTH_REQUIRED:
                raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Autenticación requerida")
            return None
        if (usuario.rol or "").upper() not in roles_set:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Permiso denegado para el rol '{usuario.rol}'",
            )
        return usuario

    return _dep
