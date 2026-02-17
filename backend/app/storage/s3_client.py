"""
KozAlma AI — S3 Client (Yandex Object Storage compatible).

Production-ready boto3 wrapper with fixes for Yandex-specific quirks:
  • s3v4 signatures  (SignatureDoesNotMatch fix)
  • path-style addressing  (403 Forbidden fix on virtual-hosted buckets)
  • try/except on every call  (admin dashboard crash fix)
  • auto-retry with backoff  (transient failure resilience)
  • pagination on list_objects_v2  (missing objects fix)
  • startup bucket validation via head_bucket()
  • debug logging of connection params
"""

from __future__ import annotations

import logging
from typing import Any, Dict, List, Optional

import boto3
from botocore.config import Config as BotoConfig
from botocore.exceptions import ClientError, BotoCoreError

logger = logging.getLogger(__name__)


class S3Client:
    """Thin, resilient wrapper around boto3 for Yandex Object Storage."""

    def __init__(
        self,
        access_key: str,
        secret_key: str,
        bucket: str,
        endpoint: str,
        region: str = "ru-central1",
    ) -> None:
        # ── Strip whitespace from every credential (common .env pitfall) ──
        access_key = (access_key or "").strip()
        secret_key = (secret_key or "").strip()
        endpoint = (endpoint or "").strip().rstrip("/")
        region = (region or "").strip()
        self.bucket = (bucket or "").strip()

        # ── Validate credentials length ──
        if len(access_key) < 10:
            logger.warning("S3_ACCESS_KEY looks too short (%d chars) — check .env", len(access_key))
        if len(secret_key) < 10:
            logger.warning("S3_SECRET_KEY looks too short (%d chars) — check .env", len(secret_key))

        # ── Debug log (safe: first 4 chars of key only) ──
        logger.info(
            "S3Client init → bucket=%s  endpoint=%s  region=%s  key=%s****",
            self.bucket,
            endpoint,
            region,
            access_key[:4] if access_key else "NONE",
        )

        # ── boto3 config optimized for Yandex Object Storage ──
        #
        # FIX 1: signature_version="s3v4"
        #   Yandex only supports Signature V4.  Without this, boto3 may
        #   fall back to V2 and produce SignatureDoesNotMatch.
        #
        # FIX 2: addressing_style="path"
        #   Yandex does NOT support virtual-hosted bucket addressing
        #   (bucket.storage.yandexcloud.net).  Path-style
        #   (storage.yandexcloud.net/bucket) is required; otherwise
        #   you get 403 Forbidden or DNS resolution errors.
        #
        # FIX 3: retries with standard backoff
        #   Transient 5xx / throttling errors are retried automatically.
        #
        cfg = BotoConfig(
            signature_version="s3v4",
            s3={"addressing_style": "path"},
            retries={"max_attempts": 5, "mode": "standard"},
        )

        self._client = boto3.client(
            "s3",
            aws_access_key_id=access_key,
            aws_secret_access_key=secret_key,
            endpoint_url=endpoint,
            region_name=region,
            config=cfg,
        )
        logger.info("S3Client boto3 session created successfully")

    # ────────────────────────────────────────────────────────────────────
    # Startup validation
    # ────────────────────────────────────────────────────────────────────

    def validate_bucket(self) -> bool:
        """Check that the configured bucket is reachable (head_bucket).

        Returns True if OK, False if not.  Never raises.
        """
        try:
            self._client.head_bucket(Bucket=self.bucket)
            logger.info("✅ Bucket '%s' is accessible", self.bucket)
            return True
        except ClientError as exc:
            code = exc.response.get("Error", {}).get("Code", "?")
            logger.error(
                "❌ Bucket '%s' validation failed (HTTP %s): %s",
                self.bucket, code, exc,
            )
            return False
        except (BotoCoreError, Exception) as exc:
            logger.error("❌ Bucket '%s' validation error: %s", self.bucket, exc)
            return False

    # ────────────────────────────────────────────────────────────────────
    # Upload helpers
    # ────────────────────────────────────────────────────────────────────

    def upload_bytes(
        self,
        key: str,
        data: bytes,
        content_type: str = "image/jpeg",
    ) -> bool:
        """Upload raw bytes.  Returns True on success."""
        try:
            self._client.put_object(
                Bucket=self.bucket,
                Key=key,
                Body=data,
                ContentType=content_type,
            )
            logger.info("Uploaded %s (%d bytes)", key, len(data))
            return True
        except (ClientError, BotoCoreError) as exc:
            logger.error("S3 upload failed for '%s': %s", key, exc)
            return False

    def upload_json(self, key: str, json_str: str) -> bool:
        """Upload a JSON string.  Returns True on success."""
        return self.upload_bytes(
            key,
            json_str.encode("utf-8"),
            content_type="application/json; charset=utf-8",
        )

    # ────────────────────────────────────────────────────────────────────
    # Download helpers
    # ────────────────────────────────────────────────────────────────────

    def get_object(self, key: str) -> Optional[bytes]:
        """Download an object as bytes.  Returns None on failure."""
        try:
            resp = self._client.get_object(Bucket=self.bucket, Key=key)
            return resp["Body"].read()
        except (ClientError, BotoCoreError) as exc:
            logger.error("S3 get_object failed for '%s': %s", key, exc)
            return None

    # ────────────────────────────────────────────────────────────────────
    # Listing helpers (with full pagination)
    # ────────────────────────────────────────────────────────────────────

    def list_objects(self, prefix: str = "") -> List[Dict[str, Any]]:
        """List ALL objects under *prefix* (handles pagination).

        FIX: The old code did a single list_objects_v2 call which returns
        at most 1000 keys.  If the bucket has more, objects were silently
        dropped.  We now paginate using ContinuationToken.

        Returns [] on error instead of crashing.
        """
        all_objects: List[Dict[str, Any]] = []
        try:
            paginator = self._client.get_paginator("list_objects_v2")
            for page in paginator.paginate(Bucket=self.bucket, Prefix=prefix):
                all_objects.extend(page.get("Contents", []))
        except (ClientError, BotoCoreError) as exc:
            logger.error("S3 list_objects failed (prefix='%s'): %s", prefix, exc)
            return []
        return all_objects

    def list_prefixes(
        self,
        prefix: str = "",
        delimiter: str = "/",
    ) -> List[str]:
        """List virtual subdirectories under *prefix*.

        Returns [] on error instead of crashing.
        """
        try:
            paginator = self._client.get_paginator("list_objects_v2")
            prefixes: List[str] = []
            for page in paginator.paginate(
                Bucket=self.bucket,
                Prefix=prefix,
                Delimiter=delimiter,
            ):
                for cp in page.get("CommonPrefixes", []):
                    if "Prefix" in cp:
                        prefixes.append(cp["Prefix"])
            return prefixes
        except (ClientError, BotoCoreError) as exc:
            logger.error("S3 list_prefixes failed (prefix='%s'): %s", prefix, exc)
            return []

    # ────────────────────────────────────────────────────────────────────
    # Delete helper
    # ────────────────────────────────────────────────────────────────────

    def delete_object(self, key: str) -> bool:
        """Delete an object.  Returns True on success."""
        try:
            self._client.delete_object(Bucket=self.bucket, Key=key)
            return True
        except (ClientError, BotoCoreError) as exc:
            logger.error("S3 delete_object failed for '%s': %s", key, exc)
            return False
