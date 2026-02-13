"""
KozAlma AI — MiDaS Depth Estimation.

Uses Intel MiDaS for monocular depth estimation and converts
relative depth to approximate metric distance via calibration.
"""

from __future__ import annotations

import logging
from typing import Optional, Tuple

import cv2
import numpy as np
import torch
from PIL import Image

logger = logging.getLogger(__name__)

# ── Calibration constants (tune for your camera / use-case) ──
# Formula: distance_meters ≈ SCALE_FACTOR / (depth_value + EPSILON)
SCALE_FACTOR = 3.0
EPSILON = 1e-6


class DepthEstimator:
    """MiDaS-based monocular depth estimator."""

    def __init__(self, model_type: str = "MiDaS_small") -> None:
        self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        self.model_type = model_type
        self._model: Optional[torch.nn.Module] = None
        self._transform = None
        self._load_model()

    def _load_model(self) -> None:
        """Load MiDaS model and transforms from torch hub."""
        try:
            self._model = torch.hub.load(
                "intel-isl/MiDaS",
                self.model_type,
                trust_repo=True,
            )
            self._model.to(self.device).eval()

            midas_transforms = torch.hub.load(
                "intel-isl/MiDaS",
                "transforms",
                trust_repo=True,
            )
            if "Small" in self.model_type or "small" in self.model_type:
                self._transform = midas_transforms.small_transform
            else:
                self._transform = midas_transforms.dpt_transform

            logger.info("MiDaS loaded (%s) on %s", self.model_type, self.device)
        except Exception as exc:
            logger.error("Failed to load MiDaS: %s", exc)
            self._model = None

    @property
    def is_available(self) -> bool:
        return self._model is not None

    def estimate_depth_map(self, image: Image.Image) -> Optional[np.ndarray]:
        """Return a normalized depth map (H×W float32, 0..1) or None on failure."""
        if not self.is_available:
            return None

        img_np = np.array(image)
        if img_np.ndim == 2:
            img_np = cv2.cvtColor(img_np, cv2.COLOR_GRAY2RGB)
        elif img_np.shape[2] == 4:
            img_np = cv2.cvtColor(img_np, cv2.COLOR_RGBA2RGB)

        input_batch = self._transform(img_np).to(self.device)  # type: ignore[union-attr]

        with torch.no_grad():
            prediction = self._model(input_batch)  # type: ignore[misc]
            prediction = torch.nn.functional.interpolate(
                prediction.unsqueeze(1),
                size=img_np.shape[:2],
                mode="bicubic",
                align_corners=False,
            ).squeeze()

        depth_map = prediction.cpu().numpy()
        # Normalize to [0, 1]
        d_min, d_max = depth_map.min(), depth_map.max()
        if d_max - d_min > EPSILON:
            depth_map = (depth_map - d_min) / (d_max - d_min)
        else:
            depth_map = np.zeros_like(depth_map)

        return depth_map.astype(np.float32)

    def estimate_distance(
        self,
        depth_map: np.ndarray,
        bbox: list[float],
    ) -> float:
        """
        Approximate distance in meters for a bounding-box region.

        Args:
            depth_map: normalized depth map (H×W).
            bbox: [x1, y1, x2, y2] in pixel coords.

        Returns:
            Estimated distance in meters (rough).
        """
        h, w = depth_map.shape[:2]
        x1 = max(0, int(bbox[0]))
        y1 = max(0, int(bbox[1]))
        x2 = min(w, int(bbox[2]))
        y2 = min(h, int(bbox[3]))

        roi = depth_map[y1:y2, x1:x2]
        if roi.size == 0:
            return -1.0

        avg_depth = float(np.median(roi))
        distance = SCALE_FACTOR / (avg_depth + EPSILON)
        return round(distance, 2)
