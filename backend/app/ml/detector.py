"""
KozAlma AI — YOLOv8 Object Detector.

Wraps the Ultralytics YOLOv8 model for inference.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass, field
from pathlib import Path
from typing import List

import numpy as np
from PIL import Image

logger = logging.getLogger(__name__)


@dataclass
class Detection:
    """Single object detection result."""

    class_id: int
    class_name: str
    confidence: float
    bbox: list[float]  # [x1, y1, x2, y2] — pixel coords
    position: str = ""  # "left" | "center" | "right"


class YOLODetector:
    """YOLOv8 object detector with configurable confidence threshold."""

    def __init__(self, weights_path: str, confidence: float = 0.35) -> None:
        from ultralytics import YOLO

        self._weights_path = Path(weights_path)
        if not self._weights_path.exists():
            logger.warning("YOLO weights not found at %s — using pretrained yolov8n", weights_path)
            self.model = YOLO("yolov8n.pt")
        else:
            self.model = YOLO(str(self._weights_path))
        self.confidence = confidence
        logger.info("YOLODetector loaded from %s (conf=%.2f)", self._weights_path, confidence)

    def detect(self, image: Image.Image) -> List[Detection]:
        """Run inference on a PIL image and return detections."""
        results = self.model.predict(
            source=np.array(image),
            conf=self.confidence,
            verbose=False,
        )
        detections: List[Detection] = []
        if not results:
            return detections

        result = results[0]
        img_w = image.width

        for box in result.boxes:
            x1, y1, x2, y2 = box.xyxy[0].tolist()
            cls_id = int(box.cls[0])
            cls_name = result.names.get(cls_id, f"class_{cls_id}")
            conf = float(box.conf[0])

            # Determine horizontal position
            cx = (x1 + x2) / 2
            if cx < img_w / 3:
                position = "left"
            elif cx > 2 * img_w / 3:
                position = "right"
            else:
                position = "center"

            detections.append(
                Detection(
                    class_id=cls_id,
                    class_name=cls_name,
                    confidence=conf,
                    bbox=[x1, y1, x2, y2],
                    position=position,
                )
            )

        logger.info("Detected %d objects", len(detections))
        return detections
