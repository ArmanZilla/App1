/// KozAlma AI — TTS Service.
///
/// Uses flutter_tts for local speech synthesis (RU/KZ) and
/// audioplayers for server-generated base64 audio playback.
///
/// Platform behavior:
///   - Mobile: flutter_tts for speak(), audioplayers for base64 audio
///   - Web: browser speechSynthesis for speak(),
///          browser AudioElement for base64 audio playback
///
/// Features:
///   - Interrupt mode: new speak() call cancels current speech
///   - Platform-aware speed normalization (user range 0.7–3.0)
///   - Supports both WAV (Piper/Kazakh) and MP3 (gTTS/Russian)
library;

import 'dart:convert';
import 'dart:typed_data';
import '../core/constants.dart';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';

// Conditional import: loads browser-native audio on web,
// no-op stubs on mobile/desktop.
import 'audio_player_stub.dart'
    if (dart.library.html) 'audio_player_web.dart' as platform_audio;

class TtsService {
  /// flutter_tts instance — only created on mobile/desktop.
  /// Null on web to avoid Web Speech API crashes.
  FlutterTts? _flutterTts;

  final AudioPlayer _player = AudioPlayer();
  bool _isInitialized = false;

  /// Whether flutter_tts (local speech) is available on this platform.
  /// Set to false on Web or if initialization fails.
  bool _localTtsAvailable = !kIsWeb;

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
    _isInitialized = true;

    // On Web, skip flutter_tts initialization entirely — it uses
    // the Web Speech API which throws SpeechSynthesisErrorEvent
    // and can white-screen the app.
    if (!_localTtsAvailable) {
      debugPrint('TTS: skipping flutter_tts init (web platform)');
      return;
    }

    try {
      _flutterTts = FlutterTts();
      await _flutterTts!.setVolume(_volume);
      await _flutterTts!.setSpeechRate(_normalizeRate(_userRate));
      await _flutterTts!.setPitch(1.0);
    } catch (e) {
      debugPrint('TTS: flutter_tts init failed, disabling local TTS: $e');
      _localTtsAvailable = false;
      _flutterTts = null;
    }
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

  /// Speak text locally via flutter_tts (mobile) or browser
  /// speechSynthesis (web).
  ///
  /// If [interrupt] is true (default), cancels any current speech first.
  Future<void> speak(String text, {String lang = 'kz', bool interrupt = true}) async {
    await _init();

    if (!_localTtsAvailable) {
      // Web: route Kazakh through backend Piper for correct pronunciation.
      // Russian uses browser speechSynthesis (works fine).
      try {
        if (interrupt) {
          await stop();
        }
        if (lang == 'kz') {
          await platform_audio.speakTextViaBackend(
            text, lang, _volume, _userRate, AppConstants.apiBaseUrl,
          );
        } else {
          await platform_audio.speakTextWeb(
            text, _locale(lang), _volume, _userRate,
          );
        }
      } catch (e) {
        debugPrint('TTS: web speak error: $e');
      }
      return;
    }

    try {
      if (interrupt) {
        await stop();
      }
      await _flutterTts!.setLanguage(_locale(lang));
      await _flutterTts!.setVolume(_volume);
      await _flutterTts!.setSpeechRate(_normalizeRate(_userRate));
      await _flutterTts!.speak(text);
    } catch (e) {
      debugPrint('TTS: speak() error: $e');
    }
  }

  /// Stop any ongoing speech and audio playback.
  Future<void> stop() async {
    // Stop browser speech + audio (no-ops on mobile)
    try {
      platform_audio.stopSpeechWeb();
    } catch (e) {
      debugPrint('TTS: web speech stop error: $e');
    }
    try {
      platform_audio.stopWebAudio();
    } catch (e) {
      debugPrint('TTS: web audio stop error: $e');
    }
    // Stop flutter_tts (mobile only)
    try {
      if (_localTtsAvailable && _flutterTts != null) {
        await _flutterTts!.stop();
      }
    } catch (e) {
      debugPrint('TTS: flutter_tts stop error: $e');
    }
    // Stop audioplayer
    try {
      await _player.stop();
    } catch (e) {
      debugPrint('TTS: audioplayer stop error: $e');
    }
  }

  /// Set volume (0.0 – 1.0).
  Future<void> setVolume(double vol) async {
    _volume = vol.clamp(0.0, 1.0);
    if (_localTtsAvailable && _flutterTts != null) {
      try {
        await _flutterTts!.setVolume(_volume);
      } catch (e) {
        debugPrint('TTS: setVolume error: $e');
      }
    }
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
    if (_localTtsAvailable && _flutterTts != null) {
      try {
        await _flutterTts!.setSpeechRate(_normalizeRate(_userRate));
      } catch (e) {
        debugPrint('TTS: setRate error: $e');
      }
    }
    debugPrint('TTS: setRate user=$_userRate engine=${_normalizeRate(_userRate)}');
  }

  /// Play base64-encoded audio from the backend (MP3 or WAV).
  ///
  /// On Web: uses browser-native AudioElement (Blob + ObjectURL)
  ///         for reliable cross-browser playback.
  /// On Mobile: uses audioplayers BytesSource directly.
  ///
  /// Supports both WAV (Piper/Kazakh) and MP3 (gTTS/Russian) — the
  /// player and browser auto-detect the format from headers.
  ///
  /// Interrupts current speech before playing.
  Future<void> playBase64Audio(String base64Audio) async {
    try {
      await stop();

      if (kIsWeb) {
        // Web: use browser-native AudioElement for reliable playback
        await platform_audio.playBase64AudioPlatform(
          base64Audio, _player, _volume,
        );
      } else {
        // Mobile: use audioplayers BytesSource
        final bytes = base64Decode(base64Audio);
        debugPrint('TTS: playBase64Audio — ${bytes.length} bytes decoded');
        await _player.setVolume(_volume);
        await _player.play(BytesSource(Uint8List.fromList(bytes)));
        debugPrint('TTS: playBase64Audio — playback started');
      }
    } catch (e) {
      debugPrint('TTS: playBase64Audio error: $e');
    }
  }

  void dispose() {
    try {
      platform_audio.disposeWebAudio();
    } catch (_) {}
    try {
      _flutterTts?.stop();
    } catch (_) {}
    _player.dispose();
  }
}
