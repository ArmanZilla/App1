/// KozAlma AI — Welcome Screen.
///
/// Clean, accessible home screen with:
/// - Header with title + language toggle
/// - Large circular "Start Scanning" button centered on screen
/// - Smaller circular "Settings" button below
/// - Edge volume zones
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import '../services/tts_service.dart';
import '../widgets/accessible_button.dart';
import '../widgets/language_toggle.dart';
import '../widgets/edge_volume_controller.dart';
import 'camera_screen.dart';
import 'settings_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final TtsService _tts = TtsService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _greet());
  }

  Future<void> _greet() async {
    final lang = context.read<AppState>().language;
    final msg = lang == 'ru'
        ? 'Добро пожаловать в Көз Алма. Нажмите один раз чтобы услышать название кнопки. Нажмите дважды для действия.'
        : 'Көз Алмаға қош келдіңіз. Түйме атауын есту үшін бір рет басыңыз. Әрекет үшін екі рет басыңыз.';
    await _tts.speak(msg, lang: lang);
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'KozAlma AI',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    LanguageToggle(ttsService: _tts),
                  ],
                ),
              ),

              // ── Center content ──
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Start Scanning — large circle
                      AccessibleButton(
                        label: lang == 'ru' ? 'Начать сканирование' : 'Сканерлеуді бастау',
                        hint: lang == 'ru'
                            ? 'Нажмите дважды чтобы открыть камеру'
                            : 'Камераны ашу үшін екі рет басыңыз',
                        icon: Icons.camera_alt_rounded,
                        circular: true,
                        diameter: 200,
                        iconSize: 64,
                        subtitle: lang == 'ru' ? 'Сканировать' : 'Сканерлеу',
                        ttsService: _tts,
                        lang: lang,
                        onAction: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const CameraScreen()),
                          );
                        },
                      ),

                      const SizedBox(height: 48),

                      // Settings — smaller circle
                      AccessibleButton(
                        label: lang == 'ru' ? 'Настройки' : 'Баптаулар',
                        hint: lang == 'ru'
                            ? 'Нажмите дважды чтобы открыть настройки'
                            : 'Баптауларды ашу үшін екі рет басыңыз',
                        icon: Icons.settings_rounded,
                        circular: true,
                        diameter: 120,
                        iconSize: 40,
                        isPrimary: false,
                        subtitle: lang == 'ru' ? 'Настройки' : 'Баптаулар',
                        ttsService: _tts,
                        lang: lang,
                        onAction: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SettingsScreen()),
                          );
                        },
                      ),
                    ],
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
