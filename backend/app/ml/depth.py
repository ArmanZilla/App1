from __future__ import annotations

import json
import logging
from pathlib import Path
from typing import Optional

import cv2
import numpy as np
import torch
from PIL import Image

logger = logging.getLogger(__name__)

EPSILON = 1e-6


class DepthEstimator:
    """MiDaS-based monocular depth estimator with linear calibration."""

    def __init__(self, model_type: str = "MiDaS_small") -> None:
        self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        self.model_type = model_type
        self._model: Optional[torch.nn.Module] = None
        self._transform = None

        self.calibration_method = "linear"
        self.scale = 1.0
        self.shift = 0.0

        self._load_model()
        self._load_calibration()

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

    def _load_calibration(self) -> None:
        """Load calibration coefficients from JSON."""
        try:
            base_dir = Path(__file__).resolve().parents[1]   # app/
            calib_path = base_dir / "assets" / "calibration.json"

            if not calib_path.exists():
                logger.warning("Calibration file not found: %s", calib_path)
                return

            data = json.loads(calib_path.read_text(encoding="utf-8"))
            self.calibration_method = data.get("method", "linear")
            self.scale = float(data.get("scale", 1.0))
            self.shift = float(data.get("shift", 0.0))

            logger.info(
                "Calibration loaded: method=%s, scale=%s, shift=%s",
                self.calibration_method,
                self.scale,
                self.shift,
            )
        except Exception as exc:
            logger.error("Failed to load calibration.json: %s", exc)

    @property
    def is_available(self) -> bool:
        return self._model is not None

    def estimate_depth_map(self, image: Image.Image) -> Optional[np.ndarray]:
        """Return raw MiDaS depth map (H×W float32) or None on failure."""
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

        depth_map = prediction.cpu().numpy().astype(np.float32)
        return depth_map

    def estimate_distance(
        self,
        depth_map: np.ndarray,
        bbox: list[float],
    ) -> float:
        """
        Estimate distance in meters for a bounding-box region.

        Args:
            depth_map: raw MiDaS depth map (H×W).
            bbox: [x1, y1, x2, y2] in pixel coords.

        Returns:
            Estimated distance in meters.
        """
        h, w = depth_map.shape[:2]
        x1 = max(0, int(bbox[0]))
        y1 = max(0, int(bbox[1]))
        x2 = min(w, int(bbox[2]))
        y2 = min(h, int(bbox[3]))

        roi = depth_map[y1:y2, x1:x2]
        if roi.size == 0:
            return -1.0

        depth_value = float(np.median(roi))

        if self.calibration_method == "linear":
            distance = depth_value * self.scale + self.shift
        else:
            logger.warning("Unknown calibration method: %s", self.calibration_method)
            distance = -1.0

        if distance < 0:
            distance = 0.0

        return round(float(distance), 2)