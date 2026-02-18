"""
KozAlma AI — OTP Service (Redis-backed).

Generates, stores, and verifies 6-digit OTP codes.

Security:
  • OTP is stored as SHA256(code + salt) hash — never plain text.
  • Cooldown prevents spam (1 request per cooldown window).
  • Max attempts + account lock prevent brute-force.
  • OTP is never logged.
"""

from __future__ import annotations

import hashlib
import hmac
import logging
import secrets
from typing import Optional, Tuple

from redis.asyncio import Redis

from app.config import get_settings

logger = logging.getLogger(__name__)

# Redis key patterns
_KEY_OTP = "otp:{channel}:{identifier}"            # stores hashed OTP
_KEY_COOLDOWN = "otp_cd:{channel}:{identifier}"     # cooldown flag
_KEY_ATTEMPTS = "otp_att:{channel}:{identifier}"    # attempt counter
_KEY_LOCK = "otp_lock:{channel}:{identifier}"       # lock after max attempts

# Runtime salt cache (so we warn only once)
_runtime_salt: Optional[str] = None


def _get_salt() -> str:
    """Return OTP salt from settings, or generate a temporary one (with warning)."""
    global _runtime_salt
    settings = get_settings()
    salt = settings.otp_salt.strip()
    if salt:
        return salt
    # Fallback: use otp_hmac_secret as salt
    if settings.otp_hmac_secret and settings.otp_hmac_secret != "change-me-otp-hmac-secret":
        return settings.otp_hmac_secret
    # Last resort: generate temporary salt (lost on restart)
    if _runtime_salt is None:
        _runtime_salt = secrets.token_hex(32)
        logger.warning(
            "⚠️  OTP_SALT is not set! Using temporary salt — "
            "OTPs will be invalidated on server restart. "
            "Set OTP_SALT in .env for production."
        )
    return _runtime_salt


def _hash_otp(code: str) -> str:
    """SHA256(code + salt) — deterministic, one-way hash."""
    salt = _get_salt()
    return hashlib.sha256((code + salt).encode()).hexdigest()


def _make_key(pattern: str, channel: str, identifier: str) -> str:
    return pattern.format(channel=channel, identifier=identifier)


async def is_locked(redis: Redis, channel: str, identifier: str) -> bool:
    """Check if the identifier is locked due to too many failed attempts."""
    key = _make_key(_KEY_LOCK, channel, identifier)
    return await redis.exists(key) > 0


async def is_on_cooldown(redis: Redis, channel: str, identifier: str) -> Tuple[bool, int]:
    """Check cooldown.  Returns (is_on_cooldown, remaining_seconds)."""
    key = _make_key(_KEY_COOLDOWN, channel, identifier)
    ttl = await redis.ttl(key)
    if ttl > 0:
        return True, ttl
    return False, 0


async def generate_otp(redis: Redis, channel: str, identifier: str) -> Optional[str]:
    """Generate a 6-digit OTP and store its hash in Redis.

    Returns the plain OTP code (for sending), or None if on cooldown/locked.
    """
    settings = get_settings()

    # Check lock
    if await is_locked(redis, channel, identifier):
        logger.warning("OTP request for locked identifier: %s", identifier[:4] + "****")
        return None

    # Check cooldown
    on_cd, remaining = await is_on_cooldown(redis, channel, identifier)
    if on_cd:
        logger.info("OTP request on cooldown (%ds remaining) for %s", remaining, identifier[:4] + "****")
        return None

    # Generate 6-digit code
    code = f"{secrets.randbelow(1_000_000):06d}"

    # Store hashed OTP with TTL
    otp_key = _make_key(_KEY_OTP, channel, identifier)
    await redis.setex(otp_key, settings.otp_ttl_seconds, _hash_otp(code))

    # Set cooldown
    cd_key = _make_key(_KEY_COOLDOWN, channel, identifier)
    await redis.setex(cd_key, settings.otp_cooldown_seconds, "1")

    # Reset attempt counter
    att_key = _make_key(_KEY_ATTEMPTS, channel, identifier)
    await redis.delete(att_key)

    logger.info("OTP generated for %s (channel=%s)", identifier[:4] + "****", channel)
    return code


async def verify_otp(redis: Redis, channel: str, identifier: str, code: str) -> bool:
    """Verify an OTP code.

    Returns True if correct, False if wrong/expired/locked.
    Increments attempt counter; locks on max attempts.
    """
    settings = get_settings()

    # Check lock
    if await is_locked(redis, channel, identifier):
        logger.warning("OTP verify attempt on locked identifier: %s", identifier[:4] + "****")
        return False

    # Check stored hash exists
    otp_key = _make_key(_KEY_OTP, channel, identifier)
    stored_hash = await redis.get(otp_key)
    if stored_hash is None:
        logger.info("OTP verify: no OTP found (expired?) for %s", identifier[:4] + "****")
        return False

    # Increment attempt counter
    att_key = _make_key(_KEY_ATTEMPTS, channel, identifier)
    attempts = await redis.incr(att_key)
    await redis.expire(att_key, settings.otp_ttl_seconds)

    if attempts > settings.otp_max_attempts:
        # Lock the identifier
        lock_key = _make_key(_KEY_LOCK, channel, identifier)
        await redis.setex(lock_key, settings.otp_lock_seconds, "1")
        # Clean up OTP and attempts
        await redis.delete(otp_key, att_key)
        logger.warning("OTP max attempts reached — locked %s for %ds",
                        identifier[:4] + "****", settings.otp_lock_seconds)
        return False

    # Compare hashes (constant-time)
    provided_hash = _hash_otp(code)
    stored_hash_str = stored_hash if isinstance(stored_hash, str) else stored_hash.decode()

    if not hmac.compare_digest(provided_hash, stored_hash_str):
        logger.info("OTP verify: wrong code (attempt %d/%d) for %s",
                     attempts, settings.otp_max_attempts, identifier[:4] + "****")
        return False

    # Success — clean up
    await redis.delete(otp_key, att_key)
    logger.info("OTP verified successfully for %s", identifier[:4] + "****")
    return True
