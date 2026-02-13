/// KozAlma AI — TTS Service.
///
/// Uses flutter_tts for local speech synthesis (RU/KZ) and
/// audioplayers for server-generated base64 audio playback.
library;

import 'dart:convert';
import 'dart:io';
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

  /// Current speech rate (0.0 – 1.0 for flutter_tts scale).
  double _rate = 0.5;
  double get rate => _rate;

  TtsService() {
    _init();
  }

  Future<void> _init() async {
    if (_isInitialized) return;
    await _flutterTts.setVolume(_volume);
    await _flutterTts.setSpeechRate(_rate);
    await _flutterTts.setPitch(1.0);
    _isInitialized = true;
  }

  /// Map app language code to TTS locale.
  String _locale(String lang) => lang == 'kz' ? 'kk-KZ' : 'ru-RU';

  /// Speak text locally via flutter_tts.
  Future<void> speak(String text, {String lang = 'ru'}) async {
    await _init();
    await _flutterTts.setLanguage(_locale(lang));
    await _flutterTts.setVolume(_volume);
    await _flutterTts.setSpeechRate(_rate);
    await _flutterTts.speak(text);
  }

  /// Stop any ongoing speech.
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

  /// Set speech rate (0.0 – 1.0).
  Future<void> setRate(double r) async {
    _rate = r.clamp(0.0, 1.0);
    await _flutterTts.setSpeechRate(_rate);
  }

  /// Play base64-encoded MP3 audio from the backend.
  Future<void> playBase64Audio(String base64Audio) async {
    try {
      final bytes = base64Decode(base64Audio);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/tts_output.mp3');
      await file.writeAsBytes(bytes);
      await _player.setVolume(_volume);
      await _player.play(DeviceFileSource(file.path));
    } catch (_) {
      // Silently fail
    }
  }

  void dispose() {
    _flutterTts.stop();
    _player.dispose();
  }
}
