/// KozAlma AI — TTS Service.
///
/// Uses flutter_tts for local speech synthesis (RU/KZ) and
/// audioplayers for server-generated base64 audio playback.
///
/// Features:
///   - Interrupt mode: new speak() call cancels current speech
///   - Platform-aware speed normalization (user range 0.7–3.0)
library;

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';

class TtsService {
  final FlutterTts _flutterTts = FlutterTts();
  final AudioPlayer _player = AudioPlayer();
  bool _isInitialized = false;

  /// Current volume (0.0 – 1.0).
  double _volume = 1.0;
  double get volume => _volume;

  /// User-facing speech rate (0.7 – 3.0).
  double _userRate = 1.0;
  double get rate => _userRate;

  TtsService() {
    _init();
  }

  Future<void> _init() async {
    if (_isInitialized) return;
    await _flutterTts.setVolume(_volume);
    await _flutterTts.setSpeechRate(_normalizeRate(_userRate));
    await _flutterTts.setPitch(1.0);
    _isInitialized = true;
  }

  /// Map app language code to TTS locale.
  String _locale(String lang) => lang == 'kz' ? 'kk-KZ' : 'ru-RU';

  /// Normalize user-visible speed (0.7–3.0) to flutter_tts engine rate.
  ///
  /// flutter_tts on Android typically uses 0.0–1.0 where 0.5 = normal.
  /// On iOS it's 0.0–1.0 where ~0.5 = normal.
  /// We map:
  ///   user 0.7 → engine 0.35
  ///   user 1.0 → engine 0.50
  ///   user 2.0 → engine 0.75
  ///   user 3.0 → engine 1.00
  double _normalizeRate(double userRate) {
    // Linear mapping: user [0.7, 3.0] → engine [0.35, 1.0]
    const userMin = 0.7;
    const userMax = 3.0;
    const engineMin = 0.35;
    const engineMax = 1.0;
    final t = (userRate - userMin) / (userMax - userMin);
    return (engineMin + t * (engineMax - engineMin)).clamp(0.1, 1.0);
  }

  /// Speak text locally via flutter_tts.
  ///
  /// If [interrupt] is true (default), cancels any current speech first.
  Future<void> speak(String text, {String lang = 'ru', bool interrupt = true}) async {
    await _init();
    if (interrupt) {
      await stop();
    }
    await _flutterTts.setLanguage(_locale(lang));
    await _flutterTts.setVolume(_volume);
    await _flutterTts.setSpeechRate(_normalizeRate(_userRate));
    await _flutterTts.speak(text);
  }

  /// Stop any ongoing speech and audio playback.
  Future<void> stop() async {
    await _flutterTts.stop();
    await _player.stop();
  }

  /// Set volume (0.0 – 1.0).
  Future<void> setVolume(double vol) async {
    _volume = vol.clamp(0.0, 1.0);
    await _flutterTts.setVolume(_volume);
  }

  /// Increase volume by step.
  Future<void> increaseVolume({double step = 0.1}) async {
    await setVolume(_volume + step);
  }

  /// Decrease volume by step.
  Future<void> decreaseVolume({double step = 0.1}) async {
    await setVolume(_volume - step);
  }

  /// Set user-facing speech rate (0.7 – 3.0).
  Future<void> setRate(double r) async {
    _userRate = r.clamp(0.7, 3.0);
    await _flutterTts.setSpeechRate(_normalizeRate(_userRate));
    debugPrint('TTS: setRate user=$_userRate engine=${_normalizeRate(_userRate)}');
  }

  /// Play base64-encoded MP3 audio from the backend.
  ///
  /// Interrupts current speech before playing.
  Future<void> playBase64Audio(String base64Audio) async {
    try {
      await stop();
      final bytes = base64Decode(base64Audio);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/tts_output.mp3');
      await file.writeAsBytes(bytes);
      await _player.setVolume(_volume);
      await _player.play(DeviceFileSource(file.path));
    } catch (e) {
      debugPrint('TTS: playBase64Audio error: $e');
    }
  }

  void dispose() {
    _flutterTts.stop();
    _player.dispose();
  }
}
