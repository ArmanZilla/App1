"""
KozAlma AI — Admin Authentication.

Handles credential verification and session management.
Uses constant-time comparison for secure password checking.
"""

from __future__ import annotations

import hmac
import logging

from app.config import get_settings

logger = logging.getLogger(__name__)


def verify_credentials(username: str, password: str) -> bool:
    """Validate admin username and password.

    Uses hmac.compare_digest for constant-time comparison
    to prevent timing attacks.
    """
    settings = get_settings()

    username_ok = hmac.compare_digest(
        username.encode("utf-8"),
        settings.admin_username.encode("utf-8"),
    )
    password_ok = hmac.compare_digest(
        password.encode("utf-8"),
        settings.admin_password.encode("utf-8"),
    )

    if not (username_ok and password_ok):
        logger.warning("Failed admin login attempt: user='%s'", username)
        return False

    logger.info("Admin login successful: user='%s'", username)
    return True
