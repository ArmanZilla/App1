"""
KozAlma AI — /unknown Endpoints.

List unknown image groups, view images, download as ZIP.
"""

from __future__ import annotations

import logging
from typing import List

from fastapi import APIRouter, Request
from fastapi.responses import Response

from app.api.schemas import UnknownGroupItem, UnknownImageItem

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/unknown", tags=["unknown"])


@router.get("/groups", response_model=List[UnknownGroupItem])
async def list_groups(request: Request) -> List[UnknownGroupItem]:
    """List all unknown image groups."""
    mgr = request.app.state.unknown_manager
    if mgr is None:
        return []
    groups = mgr.list_groups()
    return [
        UnknownGroupItem(
            group_id=g["group_id"],
            date=g["date"],
            image_count=g["image_count"],
        )
        for g in groups
    ]


@router.get("/groups/{group_id:path}/images", response_model=List[UnknownImageItem])
async def list_images(group_id: str, request: Request) -> List[UnknownImageItem]:
    """List images in a specific group."""
    mgr = request.app.state.unknown_manager
    if mgr is None:
        return []
    images = mgr.list_images(group_id)
    return [UnknownImageItem(**img) for img in images]


@router.get("/groups/{group_id:path}/download")
async def download_group(group_id: str, request: Request) -> Response:
    """Download all images in a group as a ZIP file."""
    mgr = request.app.state.unknown_manager
    if mgr is None:
        return Response(content=b"", status_code=404)

    zip_bytes = mgr.download_group_zip(group_id)
    if zip_bytes is None:
        return Response(content=b"Group not found or empty", status_code=404)

    filename = f"{group_id.replace('/', '_')}.zip"
    return Response(
        content=zip_bytes,
        media_type="application/zip",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )
