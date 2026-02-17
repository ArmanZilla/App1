"""
KozAlma AI — Unknown Image Manager.

Stores low-confidence / undetected images grouped by day+session for
future labeling (active learning).

All S3 calls are wrapped so the admin dashboard never crashes, even if
the bucket is empty or S3 is misconfigured.
"""

from __future__ import annotations

import json
import logging
import uuid
import zipfile
from datetime import datetime, timezone
from io import BytesIO
from typing import Any, Dict, List, Optional

from app.storage.s3_client import S3Client

logger = logging.getLogger(__name__)

_PREFIX = "unknown/"


class UnknownManager:
    """Manage unknown/low-confidence image groups in S3 (Yandex Object Storage)."""

    def __init__(self, s3: S3Client) -> None:
        self.s3 = s3

    # ────────────────────────────────────────────────────────────────────
    # Store
    # ────────────────────────────────────────────────────────────────────

    def store_image(
        self,
        image_bytes: bytes,
        metadata: Dict[str, Any],
        session_id: Optional[str] = None,
    ) -> Optional[str]:
        """Store an unknown image + metadata JSON in S3.

        Group key layout:  unknown/<YYYY-MM-DD>/<session_id>/

        Returns the S3 key of the stored image, or None on failure.
        """
        try:
            now = datetime.now(timezone.utc)
            day = now.strftime("%Y-%m-%d")
            sid = session_id or uuid.uuid4().hex[:8]
            img_id = uuid.uuid4().hex[:12]

            group_prefix = f"{_PREFIX}{day}/{sid}/"
            img_key = f"{group_prefix}{img_id}.jpg"
            meta_key = f"{group_prefix}{img_id}_meta.json"

            metadata.update({"timestamp": now.isoformat(), "image_key": img_key})

            ok_img = self.s3.upload_bytes(img_key, image_bytes, content_type="image/jpeg")
            ok_meta = self.s3.upload_json(meta_key, json.dumps(metadata, ensure_ascii=False))

            if not ok_img or not ok_meta:
                logger.error("store_image: partial upload failure (img=%s, meta=%s)", ok_img, ok_meta)
                return None

            logger.info("Stored unknown image %s", img_key)
            return img_key
        except Exception as exc:
            logger.error("store_image unexpected error: %s", exc)
            return None

    # ────────────────────────────────────────────────────────────────────
    # List groups  (admin dashboard — MUST NEVER CRASH)
    # ────────────────────────────────────────────────────────────────────

    def list_groups(self) -> List[Dict[str, Any]]:
        """List all day/session groups.

        Returns an empty list if the bucket is empty or S3 is unreachable,
        so the admin panel always renders.
        """
        try:
            days = self.s3.list_prefixes(prefix=_PREFIX)
            if not days:
                logger.debug("list_groups: no day prefixes found (bucket may be empty)")
                return []

            groups: List[Dict[str, Any]] = []
            for day_prefix in days:
                sessions = self.s3.list_prefixes(prefix=day_prefix)
                for sess_prefix in sessions:
                    objs = self.s3.list_objects(prefix=sess_prefix)
                    image_count = sum(1 for o in objs if o.get("Key", "").endswith(".jpg"))
                    groups.append({
                        "group_id": sess_prefix.rstrip("/").replace(_PREFIX, ""),
                        "prefix": sess_prefix,
                        "image_count": image_count,
                        "date": day_prefix.replace(_PREFIX, "").rstrip("/"),
                    })
            return groups
        except Exception as exc:
            logger.error("list_groups failed: %s", exc)
            return []

    # ────────────────────────────────────────────────────────────────────
    # List images in a group
    # ────────────────────────────────────────────────────────────────────

    def list_images(self, group_id: str) -> List[Dict[str, Any]]:
        """List images in a specific group.  Returns [] on error."""
        try:
            prefix = f"{_PREFIX}{group_id}/"
            objs = self.s3.list_objects(prefix=prefix)
            images: List[Dict[str, Any]] = []
            for obj in objs:
                key = obj.get("Key", "")
                if key.endswith(".jpg"):
                    images.append({
                        "key": key,
                        "name": key.split("/")[-1],
                        "size": obj.get("Size", 0),
                    })
            return images
        except Exception as exc:
            logger.error("list_images failed for group '%s': %s", group_id, exc)
            return []

    # ────────────────────────────────────────────────────────────────────
    # Download group as ZIP
    # ────────────────────────────────────────────────────────────────────

    def download_group_zip(self, group_id: str) -> Optional[bytes]:
        """Download all files in a group as a ZIP archive.  Returns None on error."""
        try:
            prefix = f"{_PREFIX}{group_id}/"
            objs = self.s3.list_objects(prefix=prefix)
            if not objs:
                return None

            buf = BytesIO()
            with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as zf:
                for obj in objs:
                    key = obj.get("Key", "")
                    data = self.s3.get_object(key)
                    if data:
                        filename = key.split("/")[-1]
                        zf.writestr(filename, data)

            buf.seek(0)
            return buf.read()
        except Exception as exc:
            logger.error("download_group_zip failed for group '%s': %s", group_id, exc)
            return None
