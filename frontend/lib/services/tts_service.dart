/// KozAlma AI — TTS Service.
///
/// Uses flutter_tts for local speech synthesis (Russian only) and
/// backend Piper for Kazakh speech on ALL platforms (Web + Mobile).
///
/// Platform behavior:
///   - Mobile RU: flutter_tts (fast, good quality)
///   - Mobile KZ: backend Piper via /tts/speak → audioplayers
///   - Web RU: browser speechSynthesis (instant, good quality)
///   - Web KZ: backend Piper via /tts/speak → AudioElement
///   - Scan results: playBase64Audio() (unchanged, separate path)
///
/// Features:
///   - Interrupt mode: new speak() always calls stop() first
///   - Only one audio plays at a time
///   - In-flight deduplication for Kazakh backend requests
///   - Platform-aware speed normalization (user range 0.7–3.0)
///   - Supports both WAV (Piper/Kazakh) and MP3 (gTTS/Russian)
///   - Fallback to flutter_tts if backend unreachable (last resort)
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
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

  /// ── In-flight deduplication for Kazakh backend requests ──
  /// Tracks the text currently being synthesized via backend,
  /// so we don't fire duplicate HTTP requests for the same phrase.
  String? _pendingKzText;

  /// Simple client-side cache for recently played Kazakh phrases.
  /// Key = "text|speed", Value = base64 audio.
  /// Avoids redundant HTTP calls for phrases spoken multiple times.
  final Map<String, String> _kzAudioCache = {};
  static const int _kzCacheMax = 32;

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

  /// Speak text with proper TTS routing:
  ///   - Kazakh → backend Piper on ALL platforms
  ///   - Russian → local/browser TTS (fast path)
  ///
  /// Always stops current speech before starting new speech.
  /// Deduplicates in-flight Kazakh backend requests.
  Future<void> speak(String text, {String lang = 'kz', bool interrupt = true}) async {
    await _init();

    // ── Always stop current playback to prevent overlap ──
    if (interrupt) {
      await stop();
    }

    if (text.trim().isEmpty) return;

    // ── Kazakh → backend Piper on ALL platforms ──
    if (lang == 'kz') {
      await _speakKzViaBackend(text);
      return;
    }

    // ── Russian → platform-native fast path ──
    if (!_localTtsAvailable) {
      // Web: browser speechSynthesis for Russian
      try {
        await platform_audio.speakTextWeb(
          text, _locale(lang), _volume, _userRate,
        );
      } catch (e) {
        debugPrint('TTS: web speak error: $e');
      }
      return;
    }

    // Mobile: flutter_tts for Russian
    try {
      await _flutterTts!.setLanguage(_locale(lang));
      await _flutterTts!.setVolume(_volume);
      await _flutterTts!.setSpeechRate(_normalizeRate(_userRate));
      await _flutterTts!.speak(text);
    } catch (e) {
      debugPrint('TTS: speak() error: $e');
    }
  }

  /// ── Kazakh speech via backend Piper ──
  ///
  /// Used on BOTH Web and Mobile for consistent Piper voice.
  /// Includes:
  ///   - Client-side cache for repeated short phrases
  ///   - In-flight deduplication (won't fire duplicate HTTP calls)
  ///   - Network timeout (4 seconds)
  ///   - Fallback to flutter_tts as last resort
  Future<void> _speakKzViaBackend(String text) async {
    // ── Dedup: skip if same text is already in-flight ──
    if (_pendingKzText == text) {
      debugPrint('TTS: skipping duplicate in-flight request: ${text.substring(0, text.length.clamp(0, 30))}');
      return;
    }

    final cacheKey = '$text|${_userRate.toStringAsFixed(2)}';

    // ── Client-side cache check ──
    if (_kzAudioCache.containsKey(cacheKey)) {
      debugPrint('TTS: client cache hit for KZ phrase');
      try {
        await _playAudioBytes(_kzAudioCache[cacheKey]!);
        return;
      } catch (e) {
        debugPrint('TTS: cached audio playback failed: $e');
        _kzAudioCache.remove(cacheKey);
      }
    }

    _pendingKzText = text;

    try {
      // ── Web platform: use platform_audio (dart:html HttpRequest) ──
      if (kIsWeb) {
        try {
          await platform_audio.speakTextViaBackend(
            text, 'kz', _volume, _userRate, AppConstants.apiBaseUrl,
          );
          _pendingKzText = null;
          return;
        } catch (e) {
          debugPrint('TTS: web backend speak failed: $e');
          // Fall through to fallback
        }
        _pendingKzText = null;
        return;
      }

      // ── Mobile platform: HTTP call via http package ──
      final url = '${AppConstants.apiBaseUrl}/tts/speak';
      final body = jsonEncode({
        'text': text,
        'lang': 'kz',
        'speed': _userRate,
      });

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final audioB64 = data['audio_base64'] as String?;

        if (audioB64 != null && audioB64.isNotEmpty) {
          // Cache the result for future use
          if (text.length < 200) {
            if (_kzAudioCache.length >= _kzCacheMax) {
              // Remove oldest entry (FIFO)
              _kzAudioCache.remove(_kzAudioCache.keys.first);
            }
            _kzAudioCache[cacheKey] = audioB64;
          }

          await _playAudioBytes(audioB64);
          _pendingKzText = null;
          return;
        }
      }

      debugPrint('TTS: backend /tts/speak returned no audio (status=${response.statusCode})');
      // Fall through to fallback
    } catch (e) {
      debugPrint('TTS: backend KZ speak failed: $e');
      // Fall through to fallback
    }

    _pendingKzText = null;

    // ── Last-resort fallback: flutter_tts ──
    // Only on mobile where flutter_tts is available.
    // Quality will be poor but at least the user hears something.
    if (_localTtsAvailable && _flutterTts != null) {
      try {
        debugPrint('TTS: falling back to flutter_tts for KZ (last resort)');
        await _flutterTts!.setLanguage('kk-KZ');
        await _flutterTts!.setVolume(_volume);
        await _flutterTts!.setSpeechRate(_normalizeRate(_userRate));
        await _flutterTts!.speak(text);
      } catch (e) {
        debugPrint('TTS: flutter_tts fallback also failed: $e');
      }
    }
  }

  /// Play base64-encoded audio bytes via audioplayers (mobile)
  /// or browser AudioElement (web).
  Future<void> _playAudioBytes(String base64Audio) async {
    if (kIsWeb) {
      await platform_audio.playBase64AudioPlatform(
        base64Audio, _player, _volume,
      );
    } else {
      final bytes = base64Decode(base64Audio);
      debugPrint('TTS: playing ${bytes.length} bytes via audioplayers');
      await _player.setVolume(_volume);
      await _player.play(BytesSource(Uint8List.fromList(bytes)));
    }
  }

  /// Stop any ongoing speech and audio playback.
  Future<void> stop() async {
    _pendingKzText = null;

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
    _kzAudioCache.clear();
    _pendingKzText = null;
  }
}
