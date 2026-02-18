"""
KozAlma AI — User Model.

SQLAlchemy model for user accounts.  Login == signup — users are
auto-created on first successful OTP verification.
"""

from __future__ import annotations

import logging
import uuid
from datetime import datetime, timezone

from sqlalchemy import Column, DateTime, String, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import Base

logger = logging.getLogger(__name__)


class User(Base):
    __tablename__ = "users"

    id = Column(String, primary_key=True, default=lambda: uuid.uuid4().hex)
    channel = Column(String, nullable=False)          # "email" | "phone"
    identifier = Column(String, nullable=False, index=True)  # email or phone
    role = Column(String, nullable=False, default="user")     # "user" | "admin"
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    last_login = Column(DateTime, nullable=True)


async def get_or_create_user(
    session: AsyncSession,
    channel: str,
    identifier: str,
    admin_identifiers: list[str] | None = None,
) -> User:
    """Find existing user by (channel, identifier) or create a new one.

    If the identifier is in admin_identifiers, role is set to 'admin'.
    """
    stmt = select(User).where(
        User.channel == channel,
        User.identifier == identifier,
    )
    result = await session.execute(stmt)
    user = result.scalar_one_or_none()

    if user is not None:
        user.last_login = datetime.now(timezone.utc)
        await session.commit()
        logger.info("User login: %s (%s)", identifier, user.id[:8])
        return user

    # Auto-admin check
    role = "user"
    if admin_identifiers and identifier in admin_identifiers:
        role = "admin"
        logger.info("Auto-assigning admin role to %s", identifier)

    user = User(
        channel=channel,
        identifier=identifier,
        role=role,
        last_login=datetime.now(timezone.utc),
    )
    session.add(user)
    await session.commit()
    await session.refresh(user)
    logger.info("New user created: %s (%s) role=%s", identifier, user.id[:8], role)
    return user
