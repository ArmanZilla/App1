/// KozAlma AI — Audio player stub (non-web platforms).
///
/// This is the default implementation used on mobile/desktop.
/// Uses path_provider + audioplayers for file-based playback.
library;

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

/// Play base64-encoded audio on mobile/desktop platforms.
///
/// Writes decoded bytes to a temp file, then plays via audioplayers.
/// Supports both MP3 and WAV formats.
Future<void> playBase64AudioPlatform(
  String base64Audio,
  AudioPlayer player,
  double volume,
) async {
  try {
    final bytes = base64Decode(base64Audio);
    final dir = await getTemporaryDirectory();

    // Detect format from magic bytes: WAV starts with "RIFF"
    final ext = _detectAudioExtension(bytes);
    final file = File('${dir.path}/tts_output.$ext');
    await file.writeAsBytes(bytes);

    await player.setVolume(volume);
    await player.play(DeviceFileSource(file.path));
  } catch (e) {
    debugPrint('TTS: playBase64Audio (mobile) error: $e');
  }
}

/// Detect audio format from magic bytes.
String _detectAudioExtension(List<int> bytes) {
  if (bytes.length >= 4 &&
      bytes[0] == 0x52 && // R
      bytes[1] == 0x49 && // I
      bytes[2] == 0x46 && // F
      bytes[3] == 0x46) { // F
    return 'wav';
  }
  return 'mp3';
}

/// Stop web audio playback — no-op on mobile.
void stopWebAudio() {}

/// Dispose web audio resources — no-op on mobile.
void disposeWebAudio() {}

/// Speak text via browser speechSynthesis — no-op on mobile
/// (flutter_tts is used instead).
Future<void> speakTextWeb(
  String text,
  String lang,
  double volume,
  double rate,
) async {}

/// Stop browser speech synthesis — no-op on mobile.
void stopSpeechWeb() {}

/// Speak via backend TTS — no-op on mobile (flutter_tts handles it).
Future<void> speakTextViaBackend(
  String text,
  String lang,
  double volume,
  double rate,
  String apiBaseUrl,
) async {}
