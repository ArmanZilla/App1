/// KozAlma AI — Audio player for Flutter Web.
///
/// Uses dart:html AudioElement + Blob + ObjectURL to play
/// base64-encoded audio (MP3 or WAV) without path_provider.
///
/// This implementation is more robust for Chrome:
/// - creates Blob with correct MIME type
/// - creates ObjectURL
/// - attaches hidden AudioElement to DOM
/// - waits for metadata/canplay
/// - plays audio
/// - revokes URL and removes element after playback
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
// ignore: deprecated_member_use
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';

html.AudioElement? _currentAudioElement;
String? _currentObjectUrl;

Future<void> playBase64AudioPlatform(
  String base64Audio,
  AudioPlayer player, // unused on web, kept for shared API
  double volume,
) async {
  try {
    stopWebAudio();

    final bytes = base64Decode(base64Audio);
    final uint8 = Uint8List.fromList(bytes);
    final mimeType = _detectMimeType(uint8);

    debugPrint(
      'TTS Web: decoded audio bytes=${bytes.length}, mime=$mimeType, volume=$volume',
    );

    // Create blob + object URL
    final blob = html.Blob([uint8], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    _currentObjectUrl = url;

    // Create hidden audio element
    final audio = html.AudioElement()
      ..src = url
      ..preload = 'auto'
      ..autoplay = false
      ..controls = false
      ..volume = volume.clamp(0.0, 1.0);

    _currentAudioElement = audio;

    // Add to DOM so browser handles it more reliably
    html.document.body?.append(audio);

    // Better diagnostics
    audio.onError.listen((event) {
      debugPrint('TTS Web: AudioElement error event: $event');
    });

    audio.onEnded.listen((_) {
      debugPrint('TTS Web: playback finished');
      _cleanup();
    });

    // Explicitly load
    audio.load();

    // Wait until browser says audio is playable
    try {
      await audio.onCanPlayThrough.first.timeout(
        const Duration(seconds: 5),
      );
      debugPrint('TTS Web: audio ready to play');
    } catch (_) {
      debugPrint('TTS Web: onCanPlayThrough timeout, trying play anyway');
    }

    // Try playback
    await audio.play();
    debugPrint('TTS Web: playback started successfully');
  } catch (e) {
    debugPrint('TTS: playBase64Audio (web) error: $e');
    _cleanup();
  }
}

String _detectMimeType(Uint8List bytes) {
  if (bytes.length >= 4 &&
      bytes[0] == 0x52 && // R
      bytes[1] == 0x49 && // I
      bytes[2] == 0x46 && // F
      bytes[3] == 0x46) { // F
    return 'audio/wav';
  }
  return 'audio/mpeg';
}

void stopWebAudio() {
  try {
    if (_currentAudioElement != null) {
      _currentAudioElement!.pause();
      _currentAudioElement!.currentTime = 0;
    }
  } catch (e) {
    debugPrint('TTS Web: stop error: $e');
  }
  _cleanup();
}

void disposeWebAudio() {
  stopWebAudio();
  stopSpeechWeb();
}

void _cleanup() {
  try {
    if (_currentAudioElement != null) {
      _currentAudioElement!.remove();
    }
  } catch (_) {}

  if (_currentObjectUrl != null) {
    try {
      html.Url.revokeObjectUrl(_currentObjectUrl!);
    } catch (_) {}
    _currentObjectUrl = null;
  }

  _currentAudioElement = null;
}

/// Speak text using browser's Web Speech API (speechSynthesis).
///
/// Maps lang codes to BCP-47 tags and uses the browser's built-in
/// speech synthesis. Safe try/catch — will never crash the app.
Future<void> speakTextWeb(
  String text,
  String lang,
  double volume,
  double rate,
) async {
  try {
    stopSpeechWeb();
    final synth = html.window.speechSynthesis;
    if (synth == null) {
      debugPrint('TTS Web: speechSynthesis not available in this browser');
      return;
    }
    final utterance = html.SpeechSynthesisUtterance(text)
      ..lang = lang
      ..volume = volume.clamp(0.0, 1.0)
      ..rate = rate.clamp(0.1, 10.0)
      ..pitch = 1.0;
    synth.speak(utterance);
    debugPrint('TTS Web: speaking text, lang=$lang vol=$volume rate=$rate');
  } catch (e) {
    debugPrint('TTS Web: speakTextWeb error: $e');
  }
}

/// Stop any ongoing browser speech synthesis.
void stopSpeechWeb() {
  try {
    html.window.speechSynthesis?.cancel();
  } catch (e) {
    debugPrint('TTS Web: stopSpeechWeb error: $e');
  }
}

/// Speak text via backend TTS endpoint (/tts/speak).
///
/// Used for Kazakh UI speech on web — browser speechSynthesis lacks
/// quality kk-KZ voices, so we use the backend Piper engine instead.
/// Falls back to browser speechSynthesis if the request fails.
Future<void> speakTextViaBackend(
  String text,
  String lang,
  double volume,
  double rate,
  String apiBaseUrl,
) async {
  try {
    stopSpeechWeb();

    // Call backend /tts/speak
    final url = '$apiBaseUrl/tts/speak';
    final body = '{"text":"${text.replaceAll('"', '\\"')}","lang":"$lang","speed":$rate}';

    final request = await html.HttpRequest.request(
      url,
      method: 'POST',
      sendData: body,
      requestHeaders: {'Content-Type': 'application/json'},
    );

    if (request.status == 200) {
      // Parse response
      final responseText = request.responseText ?? '';
      // Simple JSON parse for audio_base64 field
      final match = RegExp(r'"audio_base64"\s*:\s*"([^"]+)"').firstMatch(responseText);
      if (match != null) {
        final audioB64 = match.group(1)!;
        // Decode and play
        final bytes = base64Decode(audioB64);
        final uint8 = Uint8List.fromList(bytes);
        final mimeType = _detectMimeType(uint8);

        stopWebAudio();

        final blob = html.Blob([uint8], mimeType);
        final objUrl = html.Url.createObjectUrlFromBlob(blob);
        _currentObjectUrl = objUrl;

        final audio = html.AudioElement()
          ..src = objUrl
          ..preload = 'auto'
          ..volume = volume.clamp(0.0, 1.0);

        _currentAudioElement = audio;
        html.document.body?.append(audio);

        audio.onEnded.listen((_) => _cleanup());
        audio.load();

        try {
          await audio.onCanPlayThrough.first.timeout(
            const Duration(seconds: 5),
          );
        } catch (_) {}

        await audio.play();
        debugPrint('TTS Web: backend speak OK, lang=$lang');
        return;
      }
    }

    // Fallback to browser speechSynthesis
    debugPrint('TTS Web: backend /tts/speak failed, falling back to speechSynthesis');
    await speakTextWeb(text, lang, volume, rate);
  } catch (e) {
    debugPrint('TTS Web: speakTextViaBackend error: $e — falling back');
    try {
      await speakTextWeb(text, lang, volume, rate);
    } catch (_) {}
  }
}