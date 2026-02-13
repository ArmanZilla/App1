/// KozAlma AI — Application State.
///
/// Central state management using ChangeNotifier.
library;

import 'package:flutter/foundation.dart';
import 'constants.dart';

class AppState extends ChangeNotifier {
  // ── Language ──
  String _language = AppConstants.defaultLang;
  String get language => _language;

  void setLanguage(String lang) {
    if (AppConstants.languages.contains(lang) && _language != lang) {
      _language = lang;
      notifyListeners();
    }
  }

  void toggleLanguage() {
    final idx = AppConstants.languages.indexOf(_language);
    final next = (idx + 1) % AppConstants.languages.length;
    setLanguage(AppConstants.languages[next]);
  }

  // ── TTS Speed ──
  double _ttsSpeed = AppConstants.defaultSpeed;
  double get ttsSpeed => _ttsSpeed;

  void setTtsSpeed(double speed) {
    _ttsSpeed = speed.clamp(AppConstants.minSpeed, AppConstants.maxSpeed);
    notifyListeners();
  }

  void increaseSpeed() {
    setTtsSpeed(_ttsSpeed + 0.25);
  }

  void decreaseSpeed() {
    setTtsSpeed(_ttsSpeed - 0.25);
  }

  // ── Send Unknown ──
  bool _sendUnknown = true;
  bool get sendUnknown => _sendUnknown;

  void setSendUnknown(bool value) {
    _sendUnknown = value;
    notifyListeners();
  }

  void toggleSendUnknown() {
    _sendUnknown = !_sendUnknown;
    notifyListeners();
  }

  // ── Flashlight ──
  bool _flashlightOn = false;
  bool get flashlightOn => _flashlightOn;

  void setFlashlight(bool on) {
    _flashlightOn = on;
    notifyListeners();
  }

  // ── Last Scan Result (for result screen) ──
  Map<String, dynamic>? _lastScanResult;
  Map<String, dynamic>? get lastScanResult => _lastScanResult;

  void setLastScanResult(Map<String, dynamic>? result) {
    _lastScanResult = result;
    notifyListeners();
  }
}
