/// KozAlma AI — Result Screen.
///
/// Displays scan results with voice feedback.
/// Large, accessible buttons for replay and new scan.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/accessibility.dart';
import '../core/app_state.dart';
import '../services/tts_service.dart';
import '../widgets/accessible_button.dart';
import '../widgets/edge_volume_controller.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final TtsService _tts = TtsService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _playResult());
  }

  Future<void> _playResult() async {
    final state = context.read<AppState>();
    final lang = state.language;
    final result = state.lastScanResult;

    if (result == null) return;

    // Play backend audio if available
    final audio = result['audio_base64'];
    if (audio != null && audio.toString().isNotEmpty) {
      await _tts.playBase64Audio(audio.toString());
    } else {
      // Fallback: speak the text
      final text = result['text'] ?? '';
      if (text.toString().isNotEmpty) {
        await _tts.speak(text.toString(), lang: lang);
      }
    }
  }

  @override
  void dispose() {
    _tts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final lang = state.language;
    final result = state.lastScanResult;
    final detections = (result?['detections'] as List?) ?? [];
    final text = result?['text']?.toString() ?? '';
    final isUnknown = result?['is_unknown'] == true;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: EdgeVolumeController(
        ttsService: _tts,
        lang: lang,
        child: SafeArea(
          child: Column(
            children: [
              // ── Header ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    AccessibleTapHandler(
                      label: lang == 'ru' ? 'Назад' : 'Артқа',
                      hint: lang == 'ru'
                          ? 'Нажмите дважды чтобы вернуться'
                          : 'Оралу үшін екі рет басыңыз',
                      onSpeak: (text) => _tts.speak(text, lang: lang),
                      onAction: () => Navigator.pop(context),
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E2E),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF7C4DFF), width: 2),
                        ),
                        child: const Icon(Icons.arrow_back_rounded,
                            color: Colors.white, size: 28),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      lang == 'ru' ? 'Результат' : 'Нәтиже',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Content ──
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    // Unknown warning
                    if (isUnknown) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3D2200),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: const Color(0xFFFF9800), width: 1.5),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                color: Color(0xFFFF9800), size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                lang == 'ru'
                                    ? 'Обнаружены неизвестные объекты'
                                    : 'Белгісіз нысандар анықталды',
                                style: const TextStyle(
                                  color: Color(0xFFFFCC02),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Result text
                    if (text.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A2E),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: const Color(0xFF2A2A3E), width: 1.5),
                        ),
                        child: Text(
                          text,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                            height: 1.5,
                          ),
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Detection count
                    Text(
                      lang == 'ru'
                          ? 'Найдено объектов: ${detections.length}'
                          : 'Табылған нысандар: ${detections.length}',
                      style: const TextStyle(
                        color: Color(0xFF9999B3),
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),

              // ── Action buttons ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  children: [
                    // Replay
                    AccessibleButton(
                      label: lang == 'ru' ? 'Повторить' : 'Қайталау',
                      hint: lang == 'ru'
                          ? 'Нажмите дважды чтобы повторить озвучку'
                          : 'Дыбыстауды қайталау үшін екі рет басыңыз',
                      icon: Icons.replay_rounded,
                      ttsService: _tts,
                      lang: lang,
                      isPrimary: true,
                      iconSize: 26,
                      onAction: _playResult,
                    ),

                    const SizedBox(height: 14),

                    // New scan
                    AccessibleButton(
                      label: lang == 'ru' ? 'Новое сканирование' : 'Жаңа сканерлеу',
                      hint: lang == 'ru'
                          ? 'Нажмите дважды чтобы вернуться к камере'
                          : 'Камераға оралу үшін екі рет басыңыз',
                      icon: Icons.camera_alt_rounded,
                      ttsService: _tts,
                      lang: lang,
                      isPrimary: false,
                      iconSize: 26,
                      onAction: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
