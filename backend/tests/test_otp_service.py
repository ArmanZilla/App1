"""
KozAlma AI — OTP Service Tests.

Tests for OTP generation, verification, cooldown, attempt limits, and locking.
Uses fakeredis for an in-memory Redis substitute.
"""

from __future__ import annotations

import os
import pytest
import pytest_asyncio
import fakeredis.aioredis

# Ensure dev settings for tests
os.environ.setdefault("OTP_HMAC_SECRET", "test-hmac-secret")
os.environ.setdefault("OTP_TTL_SECONDS", "300")
os.environ.setdefault("OTP_COOLDOWN_SECONDS", "60")
os.environ.setdefault("OTP_MAX_ATTEMPTS", "3")
os.environ.setdefault("OTP_LOCK_SECONDS", "600")

from app.services import otp_service


@pytest_asyncio.fixture
async def redis():
    """Create a fake Redis instance for each test."""
    r = fakeredis.aioredis.FakeRedis(decode_responses=True)
    yield r
    await r.flushall()
    await r.aclose()


CHANNEL = "email"
IDENT = "test@example.com"


@pytest.mark.asyncio
async def test_generate_and_verify(redis):
    """Generate an OTP and successfully verify it."""
    code = await otp_service.generate_otp(redis, CHANNEL, IDENT)
    assert code is not None
    assert len(code) == 6
    assert code.isdigit()

    # Correct code
    ok = await otp_service.verify_otp(redis, CHANNEL, IDENT, code)
    assert ok is True


@pytest.mark.asyncio
async def test_wrong_code_rejected(redis):
    """Wrong code should be rejected."""
    code = await otp_service.generate_otp(redis, CHANNEL, IDENT)
    assert code is not None

    ok = await otp_service.verify_otp(redis, CHANNEL, IDENT, "000000")
    assert ok is False


@pytest.mark.asyncio
async def test_expired_otp_rejected(redis):
    """Verify should fail if OTP key was deleted (simulating expiry)."""
    code = await otp_service.generate_otp(redis, CHANNEL, IDENT)
    assert code is not None

    # Simulate expiry by deleting the OTP key
    otp_key = otp_service._make_key(otp_service._KEY_OTP, CHANNEL, IDENT)
    await redis.delete(otp_key)

    ok = await otp_service.verify_otp(redis, CHANNEL, IDENT, code)
    assert ok is False


@pytest.mark.asyncio
async def test_cooldown(redis):
    """After generating, a second generate should return None (cooldown)."""
    code1 = await otp_service.generate_otp(redis, CHANNEL, IDENT)
    assert code1 is not None

    # Immediately try again — should be on cooldown
    code2 = await otp_service.generate_otp(redis, CHANNEL, IDENT)
    assert code2 is None


@pytest.mark.asyncio
async def test_max_attempts_lock(redis):
    """After max wrong attempts, identifier should be locked."""
    code = await otp_service.generate_otp(redis, CHANNEL, IDENT)
    assert code is not None

    # Exhaust attempts (OTP_MAX_ATTEMPTS=3 for tests)
    for _ in range(3):
        await otp_service.verify_otp(redis, CHANNEL, IDENT, "000000")

    # Next attempt should trigger lock
    ok = await otp_service.verify_otp(redis, CHANNEL, IDENT, "000000")
    assert ok is False

    # Should be locked
    locked = await otp_service.is_locked(redis, CHANNEL, IDENT)
    assert locked is True

    # Even correct code should fail while locked
    # (need to clear cooldown first to generate new OTP, but lock prevents it)
    code2 = await otp_service.generate_otp(redis, CHANNEL, IDENT)
    assert code2 is None


@pytest.mark.asyncio
async def test_verify_cleans_up(redis):
    """After successful verify, OTP and attempt keys should be deleted."""
    code = await otp_service.generate_otp(redis, CHANNEL, IDENT)
    assert code is not None

    ok = await otp_service.verify_otp(redis, CHANNEL, IDENT, code)
    assert ok is True

    # OTP key should be gone
    otp_key = otp_service._make_key(otp_service._KEY_OTP, CHANNEL, IDENT)
    assert await redis.exists(otp_key) == 0

    # Second verify with same code should fail
    ok2 = await otp_service.verify_otp(redis, CHANNEL, IDENT, code)
    assert ok2 is False
