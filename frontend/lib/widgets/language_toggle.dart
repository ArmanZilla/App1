/// KozAlma AI — Language Toggle Widget.
///
/// Header widget that toggles between RU and KZ.
/// - 1 tap: speaks current language + hint
/// - 2 taps: switches language and speaks confirmation
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/accessibility.dart';
import '../core/app_state.dart';
import '../core/constants.dart';
import '../services/tts_service.dart';

class LanguageToggle extends StatelessWidget {
  final TtsService ttsService;

  const LanguageToggle({super.key, required this.ttsService});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final currentLang = state.language;
    final langName = AppConstants.languageNames[currentLang] ?? currentLang;

    return AccessibleTapHandler(
      label: currentLang == 'ru'
          ? 'Язык: $langName'
          : 'Тіл: $langName',
      hint: currentLang == 'ru'
          ? 'Нажмите дважды для переключения'
          : 'Ауыстыру үшін екі рет басыңыз',
      onSpeak: (text) => ttsService.speak(text, lang: currentLang),
      onAction: () {
        state.toggleLanguage();
        final newLang = state.language;
        final newName = AppConstants.languageNames[newLang] ?? newLang;
        final msg = newLang == 'ru'
            ? 'Язык изменён на $newName'
            : 'Тіл $newName тіліне ауыстырыл';
        ttsService.speak(msg, lang: newLang);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF6c63ff).withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF6c63ff).withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language, color: Color(0xFF8b83ff), size: 18),
            const SizedBox(width: 6),
            Text(
              currentLang.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF8b83ff),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
