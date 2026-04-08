/// KozAlma AI — Application State.
///
/// Central state management using ChangeNotifier.
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';

class AppState extends ChangeNotifier {
  static const _keyLang = 'koz_language';

  // ── Language ──
  String _language = AppConstants.defaultLang;
  String get language => _language;

  /// Load saved language from SharedPreferences.
  /// Call once at app startup before runApp().
  Future<void> loadSavedLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_keyLang);
      if (saved != null && AppConstants.languages.contains(saved)) {
        _language = saved;
      }
    } catch (e) {
      debugPrint('AppState: failed to load saved language: $e');
    }
  }

  void setLanguage(String lang) {
    if (AppConstants.languages.contains(lang) && _language != lang) {
      _language = lang;
      notifyListeners();
      _persistLanguage(lang);
    }
  }

  Future<void> _persistLanguage(String lang) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLang, lang);
    } catch (e) {
      debugPrint('AppState: failed to persist language: $e');
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
    setTtsSpeed(_ttsSpeed + 0.1);
  }

  void decreaseSpeed() {
    setTtsSpeed(_ttsSpeed - 0.1);
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
