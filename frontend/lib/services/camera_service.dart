/// KozAlma AI — Camera Service.
///
/// Handles camera initialization, light level monitoring,
/// and automatic flashlight control.
library;

import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import '../core/constants.dart';

class CameraService {
  CameraController? controller;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;
  bool _flashlightOn = false;

  bool get isInitialized => _isInitialized;
  bool get flashlightOn => _flashlightOn;

  /// Initialize the camera.
  Future<void> initialize() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;

      // Use back camera
      final backCamera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      controller = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller!.initialize();
      _isInitialized = true;
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  /// Capture an image and return bytes.
  Future<Uint8List?> captureImage() async {
    if (controller == null || !_isInitialized) return null;

    try {
      final file = await controller!.takePicture();
      return await file.readAsBytes();
    } catch (e) {
      debugPrint('Capture error: $e');
      return null;
    }
  }

  /// Toggle flashlight on/off.
  Future<void> toggleFlashlight() async {
    if (controller == null) return;
    try {
      _flashlightOn = !_flashlightOn;
      await controller!.setFlashMode(
        _flashlightOn ? FlashMode.torch : FlashMode.off,
      );
    } catch (e) {
      debugPrint('Flashlight error: $e');
    }
  }

  /// Enable flashlight if ambient light is low.
  /// Called with a lux value from the light sensor.
  Future<void> autoFlashlight(double luxValue) async {
    if (controller == null) return;

    if (luxValue < AppConstants.lowLightThreshold && !_flashlightOn) {
      _flashlightOn = true;
      try {
        await controller!.setFlashMode(FlashMode.torch);
      } catch (e) {
        debugPrint('Auto flashlight error: $e');
      }
    }
  }

  /// Dispose camera resources.
  Future<void> dispose() async {
    await controller?.dispose();
    _isInitialized = false;
  }
}
