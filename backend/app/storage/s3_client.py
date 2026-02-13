"""
KozAlma AI — S3-Compatible Storage Client.

Wraps boto3 for Yandex Object Storage (S3-compatible).
"""

from __future__ import annotations

import logging
from io import BytesIO
from typing import List, Optional

import boto3
from botocore.config import Config as BotoConfig

logger = logging.getLogger(__name__)


class S3Client:
    """Thin wrapper around boto3 S3 client for Yandex Object Storage."""

    def __init__(
        self,
        access_key: str,
        secret_key: str,
        bucket: str,
        endpoint: str,
        region: str = "ru-central1",
    ) -> None:
        self.bucket = bucket
        self._client = boto3.client(
            "s3",
            endpoint_url=endpoint,
            aws_access_key_id=access_key,
            aws_secret_access_key=secret_key,
            region_name=region,
            config=BotoConfig(signature_version="s3v4"),
        )
        logger.info("S3Client initialized (bucket=%s, endpoint=%s)", bucket, endpoint)

    def upload_bytes(self, key: str, data: bytes, content_type: str = "image/jpeg") -> bool:
        """Upload raw bytes to S3."""
        try:
            self._client.put_object(
                Bucket=self.bucket,
                Key=key,
                Body=data,
                ContentType=content_type,
            )
            logger.info("Uploaded %s (%d bytes)", key, len(data))
            return True
        except Exception as exc:
            logger.error("S3 upload failed for %s: %s", key, exc)
            return False

    def upload_json(self, key: str, json_str: str) -> bool:
        """Upload JSON string to S3."""
        return self.upload_bytes(key, json_str.encode("utf-8"), "application/json")

    def list_prefixes(self, prefix: str = "", delimiter: str = "/") -> List[str]:
        """List common prefixes (subdirectories) under a prefix."""
        try:
            resp = self._client.list_objects_v2(
                Bucket=self.bucket,
                Prefix=prefix,
                Delimiter=delimiter,
            )
            return [cp["Prefix"] for cp in resp.get("CommonPrefixes", [])]
        except Exception as exc:
            logger.error("S3 list_prefixes failed: %s", exc)
            return []

    def list_objects(self, prefix: str = "") -> List[dict]:
        """List all objects under a prefix."""
        try:
            resp = self._client.list_objects_v2(Bucket=self.bucket, Prefix=prefix)
            return resp.get("Contents", [])
        except Exception as exc:
            logger.error("S3 list_objects failed: %s", exc)
            return []

    def get_object(self, key: str) -> Optional[bytes]:
        """Download object as bytes."""
        try:
            resp = self._client.get_object(Bucket=self.bucket, Key=key)
            return resp["Body"].read()
        except Exception as exc:
            logger.error("S3 get_object failed for %s: %s", key, exc)
            return None

    def delete_object(self, key: str) -> bool:
        """Delete an object from S3."""
        try:
            self._client.delete_object(Bucket=self.bucket, Key=key)
            return True
        except Exception as exc:
            logger.error("S3 delete_object failed for %s: %s", key, exc)
            return False
