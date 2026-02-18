"""
KozAlma AI — Admin Web Panel.

Cookie-session-based admin for viewing/downloading unknown image groups.
Login + Password authentication.
"""

from __future__ import annotations

import logging
from pathlib import Path
from typing import Any, Dict, List

from fastapi import APIRouter, Depends, Form, Request
from fastapi.responses import HTMLResponse, JSONResponse, RedirectResponse, Response
from fastapi.templating import Jinja2Templates
from itsdangerous import URLSafeTimedSerializer

from app.admin_web.auth import verify_credentials
from app.auth.jwt_utils import require_admin
from app.config import get_settings

logger = logging.getLogger(__name__)

_TEMPLATE_DIR = Path(__file__).parent / "templates"
templates = Jinja2Templates(directory=str(_TEMPLATE_DIR))

router = APIRouter(prefix="/admin", tags=["admin"])

SESSION_COOKIE = "koz_admin_session"
MAX_AGE = 3600 * 8  # 8 hours


def _get_serializer() -> URLSafeTimedSerializer:
    return URLSafeTimedSerializer(get_settings().admin_session_secret)


def _is_authenticated(request: Request) -> bool:
    token = request.cookies.get(SESSION_COOKIE)
    if not token:
        return False
    try:
        _get_serializer().loads(token, max_age=MAX_AGE)
        return True
    except Exception:
        return False


@router.get("/login", response_class=HTMLResponse)
async def login_page(request: Request) -> HTMLResponse:
    """Render login form."""
    return templates.TemplateResponse("login.html", {"request": request, "error": ""})


@router.post("/login")
async def login_submit(
    request: Request,
    username: str = Form(...),
    password: str = Form(...),
) -> Response:
    """Validate login + password and set session cookie."""
    if not verify_credentials(username, password):
        return templates.TemplateResponse(
            "login.html",
            {"request": request, "error": "Неверный логин или пароль"},
            status_code=401,
        )

    token = _get_serializer().dumps({"admin": True, "user": username})
    response = RedirectResponse(url="/admin", status_code=303)
    response.set_cookie(SESSION_COOKIE, token, max_age=MAX_AGE, httponly=True)
    return response


@router.get("", response_class=HTMLResponse)
async def dashboard(request: Request) -> HTMLResponse:
    """Admin dashboard — list unknown image groups."""
    if not _is_authenticated(request):
        return RedirectResponse(url="/admin/login", status_code=303)

    mgr = request.app.state.unknown_manager
    groups: List[Dict[str, Any]] = []
    error_msg = ""

    if mgr is None:
        error_msg = "S3 storage not configured"
    else:
        try:
            groups = mgr.list_groups()
        except Exception as exc:
            logger.error("Admin dashboard — failed to list groups: %s", exc)
            error_msg = "Ошибка подключения к хранилищу"

    return templates.TemplateResponse(
        "dashboard.html",
        {"request": request, "groups": groups, "error_msg": error_msg},
    )


@router.get("/download/{group_id:path}")
async def download_group(group_id: str, request: Request) -> Response:
    """Download a group as ZIP."""
    if not _is_authenticated(request):
        return RedirectResponse(url="/admin/login", status_code=303)

    mgr = request.app.state.unknown_manager
    if mgr is None:
        return Response(content=b"S3 not configured", status_code=500)

    try:
        zip_bytes = mgr.download_group_zip(group_id)
    except Exception as exc:
        logger.error("Admin download failed for '%s': %s", group_id, exc)
        return Response(content=b"Storage error", status_code=500)

    if zip_bytes is None:
        return Response(content=b"Not found", status_code=404)

    filename = f"{group_id.replace('/', '_')}.zip"
    return Response(
        content=zip_bytes,
        media_type="application/zip",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


@router.get("/logout")
async def logout(request: Request) -> Response:
    """Clear session and redirect to login."""
    response = RedirectResponse(url="/admin/login", status_code=303)
    response.delete_cookie(SESSION_COOKIE)
    return response


# ────────────────────────────────────────────────────────────────────
# Admin API (JWT-protected, for future mobile/programmatic use)
# ────────────────────────────────────────────────────────────────────

@router.get("/api/groups")
async def api_groups(
    request: Request,
    _admin: Dict[str, Any] = Depends(require_admin),
) -> JSONResponse:
    """List groups via JWT Bearer (admin role required)."""
    mgr = request.app.state.unknown_manager
    if mgr is None:
        return JSONResponse({"groups": [], "error": "Storage not configured"})
    try:
        groups = mgr.list_groups()
    except Exception as exc:
        logger.error("Admin API groups failed: %s", exc)
        return JSONResponse({"groups": [], "error": "Storage error"})
    return JSONResponse({"groups": groups, "error": None})
