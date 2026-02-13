"""
KozAlma AI — Unknown Image Manager.

Stores low-confidence / undetected images grouped by day+session for
future labeling (active learning).
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
    """Manage unknown/low-confidence image groups in S3."""

    def __init__(self, s3: S3Client) -> None:
        self.s3 = s3

    def store_image(
        self,
        image_bytes: bytes,
        metadata: Dict[str, Any],
        session_id: Optional[str] = None,
    ) -> str:
        """
        Store an unknown image + metadata JSON in S3.

        Group key: unknown/<YYYY-MM-DD>/<session_id>/

        Returns:
            The S3 key of the stored image.
        """
        now = datetime.now(timezone.utc)
        day = now.strftime("%Y-%m-%d")
        sid = session_id or uuid.uuid4().hex[:8]
        img_id = uuid.uuid4().hex[:12]

        group_prefix = f"{_PREFIX}{day}/{sid}/"
        img_key = f"{group_prefix}{img_id}.jpg"
        meta_key = f"{group_prefix}{img_id}_meta.json"

        metadata.update({"timestamp": now.isoformat(), "image_key": img_key})

        self.s3.upload_bytes(img_key, image_bytes, content_type="image/jpeg")
        self.s3.upload_json(meta_key, json.dumps(metadata, ensure_ascii=False))

        logger.info("Stored unknown image %s", img_key)
        return img_key

    def list_groups(self) -> List[Dict[str, Any]]:
        """List all day/session groups."""
        days = self.s3.list_prefixes(prefix=_PREFIX)
        groups: List[Dict[str, Any]] = []
        for day_prefix in days:
            sessions = self.s3.list_prefixes(prefix=day_prefix)
            for sess_prefix in sessions:
                objs = self.s3.list_objects(prefix=sess_prefix)
                image_count = sum(1 for o in objs if o["Key"].endswith(".jpg"))
                groups.append({
                    "group_id": sess_prefix.rstrip("/").replace(_PREFIX, ""),
                    "prefix": sess_prefix,
                    "image_count": image_count,
                    "date": day_prefix.replace(_PREFIX, "").rstrip("/"),
                })
        return groups

    def list_images(self, group_id: str) -> List[Dict[str, str]]:
        """List images in a specific group."""
        prefix = f"{_PREFIX}{group_id}/"
        objs = self.s3.list_objects(prefix=prefix)
        images = []
        for obj in objs:
            key = obj["Key"]
            if key.endswith(".jpg"):
                images.append({
                    "key": key,
                    "name": key.split("/")[-1],
                    "size": obj.get("Size", 0),
                })
        return images

    def download_group_zip(self, group_id: str) -> Optional[bytes]:
        """Download all images in a group as a ZIP archive."""
        prefix = f"{_PREFIX}{group_id}/"
        objs = self.s3.list_objects(prefix=prefix)
        if not objs:
            return None

        buf = BytesIO()
        with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as zf:
            for obj in objs:
                key = obj["Key"]
                data = self.s3.get_object(key)
                if data:
                    filename = key.split("/")[-1]
                    zf.writestr(filename, data)

        buf.seek(0)
        return buf.read()
