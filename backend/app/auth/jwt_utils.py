"""
KozAlma AI — JWT Utilities.

Token creation, verification, and FastAPI dependencies for
access & refresh tokens.  Uses python-jose (HS256).
"""

from __future__ import annotations

import logging
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, Optional

from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt

from app.config import get_settings

logger = logging.getLogger(__name__)

_bearer_scheme = HTTPBearer(auto_error=False)


# ────────────────────────────────────────────────────────────────────
# Token creation
# ────────────────────────────────────────────────────────────────────

def create_access_token(user_id: str, role: str) -> str:
    """Create a short-lived access token."""
    settings = get_settings()
    expires = datetime.now(timezone.utc) + timedelta(minutes=settings.access_token_expires_min)
    payload = {
        "sub": user_id,
        "role": role,
        "type": "access",
        "exp": expires,
        "iat": datetime.now(timezone.utc),
    }
    return jwt.encode(payload, settings.jwt_secret_key, algorithm=settings.jwt_alg)


def create_refresh_token(user_id: str) -> str:
    """Create a long-lived refresh token."""
    settings = get_settings()
    expires = datetime.now(timezone.utc) + timedelta(days=settings.refresh_token_expires_days)
    payload = {
        "sub": user_id,
        "type": "refresh",
        "exp": expires,
        "iat": datetime.now(timezone.utc),
    }
    return jwt.encode(payload, settings.jwt_secret_key, algorithm=settings.jwt_alg)


# ────────────────────────────────────────────────────────────────────
# Token verification
# ────────────────────────────────────────────────────────────────────

def verify_token(token: str, expected_type: str = "access") -> Dict[str, Any]:
    """Decode and validate a JWT.  Raises HTTPException on failure."""
    settings = get_settings()
    try:
        payload = jwt.decode(token, settings.jwt_secret_key, algorithms=[settings.jwt_alg])
    except JWTError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid token: {exc}",
        )

    if payload.get("type") != expected_type:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Expected {expected_type} token",
        )

    return payload


# ────────────────────────────────────────────────────────────────────
# FastAPI dependencies
# ────────────────────────────────────────────────────────────────────

async def get_current_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(_bearer_scheme),
) -> Dict[str, Any]:
    """Extract and validate user from Bearer token.  Returns payload dict.

    Raises 401 if token is missing or invalid.
    """
    if credentials is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authorization header required",
        )
    payload = verify_token(credentials.credentials, expected_type="access")
    return payload


async def get_optional_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(_bearer_scheme),
) -> Optional[Dict[str, Any]]:
    """Like get_current_user but returns None if no token is provided."""
    if credentials is None:
        return None
    try:
        return verify_token(credentials.credentials, expected_type="access")
    except HTTPException:
        return None


async def require_admin(
    user: Dict[str, Any] = Depends(get_current_user),
) -> Dict[str, Any]:
    """Enforce admin role.  Raises 403 if not admin."""
    if user.get("role") != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin access required",
        )
    return user
