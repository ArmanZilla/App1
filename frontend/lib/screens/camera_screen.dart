/// KozAlma AI — Camera / Scan Screen.
///
/// Live camera preview with:
/// - Large circular capture button at the bottom (150px)
/// - Accessible back button with voice feedback
/// - Language toggle in header
/// - Edge volume controller zones
/// - Auto-speaks scan result immediately after scan completes
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import '../core/accessibility.dart';
import '../core/app_state.dart';
import '../services/api_service.dart';
import '../services/camera_service.dart';
import '../services/tts_service.dart';
import '../widgets/language_toggle.dart';
import '../widgets/edge_volume_controller.dart';
import 'result_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final CameraService _cameraService = CameraService();
  final TtsService _tts = TtsService();
  final ApiService _api = ApiService();
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    await _cameraService.initialize();
    if (mounted) setState(() {});
    final lang = context.read<AppState>().language;
    await _tts.speak(
      lang == 'ru' ? 'Камера готова' : 'Камера дайын',
      lang: lang,
    );
  }

  Future<void> _scan() async {
    if (_scanning) return;
    setState(() => _scanning = true);

    final state = context.read<AppState>();
    final lang = state.language;

    await _tts.speak(
      lang == 'ru' ? 'Сканирование...' : 'Сканерлеу...',
      lang: lang,
    );

    final imageBytes = await _cameraService.captureImage();
    if (imageBytes == null) {
      await _tts.speak(
        lang == 'ru' ? 'Ошибка камеры' : 'Камера қатесі',
        lang: lang,
      );
      setState(() => _scanning = false);
      return;
    }

    try {
      final result = await _api.scan(
        imageBytes: imageBytes,
        lang: lang,
        ttsSpeed: state.ttsSpeed,
        sendUnknown: state.sendUnknown,
      );

      state.setLastScanResult(result);

      // ── Auto-speak scan result immediately ──
      await _speakScanResult(result, lang);

      // Haptic feedback on scan complete
      HapticFeedback.mediumImpact();

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ResultScreen()),
        );
      }
    } catch (e) {
      await _tts.speak(
        lang == 'ru' ? 'Ошибка соединения с сервером' : 'Сервермен байланыс қатесі',
        lang: lang,
      );
    }

    setState(() => _scanning = false);
  }

  /// Speak the scan result text — uses backend audio if available,
  /// otherwise speaks the localized text.
  Future<void> _speakScanResult(Map<String, dynamic> result, String lang) async {
    final isUnknown = result['is_unknown'] == true;
    final detections = (result['detections'] as List?) ?? [];
    final text = result['text']?.toString() ?? '';

    if (detections.isEmpty && isUnknown) {
      // No detections at all
      await _tts.speak(
        lang == 'ru' ? 'Объекты не обнаружены' : 'Нысандар табылмады',
        lang: lang,
      );
      return;
    }

    if (isUnknown && detections.isNotEmpty) {
      // Some detections but has unknowns
      final prefix = lang == 'ru'
          ? 'Обнаружены неизвестные объекты. '
          : 'Белгісіз нысандар анықталды. ';
      if (text.isNotEmpty) {
        await _tts.speak('$prefix$text', lang: lang);
      } else {
        await _tts.speak(prefix, lang: lang);
      }
      return;
    }

    // Normal result — play backend audio or speak text
    final audio = result['audio_base64'];
    if (audio != null && audio.toString().isNotEmpty) {
      await _tts.playBase64Audio(audio.toString());
    } else if (text.isNotEmpty) {
      await _tts.speak(text, lang: lang);
    }
  }

  @override
  void dispose() {
    _cameraService.dispose();
    _tts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final lang = state.language;

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
                    // Back button — large accessible
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
                    const Spacer(),
                    LanguageToggle(ttsService: _tts),
                  ],
                ),
              ),

              // ── Camera preview ──
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: _cameraService.isInitialized && _cameraService.controller != null
                      ? CameraPreview(_cameraService.controller!)
                      : const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF7C4DFF),
                            strokeWidth: 3,
                          ),
                        ),
                ),
              ),

              // ── Capture button ──
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: AccessibleTapHandler(
                  label: lang == 'ru' ? 'Сканировать' : 'Сканерлеу',
                  hint: lang == 'ru'
                      ? 'Нажмите дважды чтобы сканировать'
                      : 'Сканерлеу үшін екі рет басыңыз',
                  onSpeak: (text) => _tts.speak(text, lang: lang),
                  onAction: _scan,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF7C4DFF), Color(0xFF536DFE)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7C4DFF).withValues(alpha: 0.5),
                          blurRadius: 30,
                          spreadRadius: 4,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: _scanning
                        ? const Padding(
                            padding: EdgeInsets.all(40),
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 4,
                            ),
                          )
                        : const Icon(
                            Icons.camera_alt_rounded,
                            color: Colors.white,
                            size: 56,
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
