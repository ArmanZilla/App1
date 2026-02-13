/// KozAlma AI — Settings Screen.
///
/// Accessible settings with:
/// - Language selection (RU/KZ)
/// - Speech rate slider
/// - Volume slider
/// - Send-unknown toggle
/// All with 1-tap (speak) / 2-tap (action) accessibility.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/accessibility.dart';
import '../core/app_state.dart';
import '../services/tts_service.dart';
import '../widgets/edge_volume_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TtsService _tts = TtsService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final lang = context.read<AppState>().language;
      _tts.speak(
        lang == 'ru' ? 'Настройки' : 'Баптаулар',
        lang: lang,
      );
    });
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
                      lang == 'ru' ? 'Настройки' : 'Баптаулар',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── Settings list ──
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    // ── Language ──
                    _SettingCard(
                      title: lang == 'ru' ? 'Язык' : 'Тіл',
                      child: Row(
                        children: [
                          _LangButton(
                            label: 'Русский',
                            code: 'ru',
                            isActive: lang == 'ru',
                            tts: _tts,
                            onSelect: () {
                              state.setLanguage('ru');
                              _tts.speak('Язык изменён на Русский', lang: 'ru');
                            },
                          ),
                          const SizedBox(width: 12),
                          _LangButton(
                            label: 'Қазақша',
                            code: 'kz',
                            isActive: lang == 'kz',
                            tts: _tts,
                            onSelect: () {
                              state.setLanguage('kz');
                              _tts.speak('Тіл Қазақшаға ауыстырылды', lang: 'kz');
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Speech rate ──
                    _SettingCard(
                      title: lang == 'ru' ? 'Скорость речи' : 'Сөйлеу жылдамдығы',
                      child: AccessibleTapHandler(
                        label: lang == 'ru'
                            ? 'Скорость речи ${(state.ttsSpeed * 100).round()} процентов'
                            : 'Сөйлеу жылдамдығы ${(state.ttsSpeed * 100).round()} пайыз',
                        hint: lang == 'ru'
                            ? 'Используйте ползунок для изменения'
                            : 'Өзгерту үшін жүгірткіні пайдаланыңыз',
                        onSpeak: (text) => _tts.speak(text, lang: lang),
                        onAction: () {},
                        child: Column(
                          children: [
                            SliderTheme(
                              data: SliderThemeData(
                                activeTrackColor: const Color(0xFF7C4DFF),
                                inactiveTrackColor: const Color(0xFF2A2A3E),
                                thumbColor: Colors.white,
                                thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 14),
                                trackHeight: 8,
                                overlayColor:
                                    const Color(0xFF7C4DFF).withValues(alpha: 0.2),
                              ),
                              child: Slider(
                                value: state.ttsSpeed,
                                min: 0.2,
                                max: 1.0,
                                divisions: 8,
                                onChanged: (v) {
                                  state.setTtsSpeed(v);
                                  _tts.setRate(v);
                                },
                                onChangeEnd: (v) {
                                  final pct = (v * 100).round();
                                  _tts.speak(
                                    lang == 'ru'
                                        ? 'Скорость $pct процентов'
                                        : 'Жылдамдық $pct пайыз',
                                    lang: lang,
                                  );
                                },
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(lang == 'ru' ? 'Медленно' : 'Баяу',
                                    style: _dimTextStyle()),
                                Text('${(state.ttsSpeed * 100).round()}%',
                                    style: _valueTextStyle()),
                                Text(lang == 'ru' ? 'Быстро' : 'Жылдам',
                                    style: _dimTextStyle()),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Volume ──
                    _SettingCard(
                      title: lang == 'ru' ? 'Громкость' : 'Дыбыс деңгейі',
                      child: AccessibleTapHandler(
                        label: lang == 'ru'
                            ? 'Громкость ${(_tts.volume * 100).round()} процентов'
                            : 'Дыбыс деңгейі ${(_tts.volume * 100).round()} пайыз',
                        hint: lang == 'ru'
                            ? 'Используйте ползунок для изменения'
                            : 'Өзгерту үшін жүгірткіні пайдаланыңыз',
                        onSpeak: (text) => _tts.speak(text, lang: lang),
                        onAction: () {},
                        child: Column(
                          children: [
                            SliderTheme(
                              data: SliderThemeData(
                                activeTrackColor: const Color(0xFF7C4DFF),
                                inactiveTrackColor: const Color(0xFF2A2A3E),
                                thumbColor: Colors.white,
                                thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 14),
                                trackHeight: 8,
                                overlayColor:
                                    const Color(0xFF7C4DFF).withValues(alpha: 0.2),
                              ),
                              child: Slider(
                                value: _tts.volume,
                                min: 0.0,
                                max: 1.0,
                                divisions: 10,
                                onChanged: (v) {
                                  _tts.setVolume(v);
                                  setState(() {});
                                },
                                onChangeEnd: (v) {
                                  final pct = (v * 100).round();
                                  _tts.speak(
                                    lang == 'ru'
                                        ? 'Громкость $pct процентов'
                                        : 'Дыбыс деңгейі $pct пайыз',
                                    lang: lang,
                                  );
                                },
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Icon(Icons.volume_off_rounded,
                                    color: Color(0xFF666680), size: 20),
                                Text('${(_tts.volume * 100).round()}%',
                                    style: _valueTextStyle()),
                                const Icon(Icons.volume_up_rounded,
                                    color: Color(0xFF666680), size: 20),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Send unknown toggle ──
                    AccessibleTapHandler(
                      label: lang == 'ru'
                          ? 'Отправлять неизвестные изображения: ${state.sendUnknown ? "включено" : "выключено"}'
                          : 'Белгісіз суреттерді жіберу: ${state.sendUnknown ? "қосулы" : "өшірулі"}',
                      hint: lang == 'ru'
                          ? 'Нажмите дважды чтобы переключить'
                          : 'Ауыстыру үшін екі рет басыңыз',
                      onSpeak: (text) => _tts.speak(text, lang: lang),
                      onAction: () {
                        state.toggleSendUnknown();
                        final on = state.sendUnknown;
                        _tts.speak(
                          lang == 'ru'
                              ? 'Отправка неизвестных ${on ? "включена" : "выключена"}'
                              : 'Белгісіз суреттерді жіберу ${on ? "қосылды" : "өшірілді"}',
                          lang: lang,
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A2E),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFF2A2A3E),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              state.sendUnknown
                                  ? Icons.cloud_upload_rounded
                                  : Icons.cloud_off_rounded,
                              color: state.sendUnknown
                                  ? const Color(0xFF7C4DFF)
                                  : const Color(0xFF666680),
                              size: 28,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                lang == 'ru'
                                    ? 'Отправлять неизвестные'
                                    : 'Белгісіздерді жіберу',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Container(
                              width: 56,
                              height: 32,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                color: state.sendUnknown
                                    ? const Color(0xFF7C4DFF)
                                    : const Color(0xFF2A2A3E),
                              ),
                              child: AnimatedAlign(
                                duration: const Duration(milliseconds: 200),
                                alignment: state.sendUnknown
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  width: 26,
                                  height: 26,
                                  margin: const EdgeInsets.symmetric(horizontal: 3),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle _dimTextStyle() =>
      const TextStyle(color: Color(0xFF666680), fontSize: 14);

  TextStyle _valueTextStyle() => const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      );
}

// ── Setting Card wrapper ──
class _SettingCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SettingCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2A2A3E), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF9999B3),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

// ── Language selection button ──
class _LangButton extends StatelessWidget {
  final String label;
  final String code;
  final bool isActive;
  final TtsService tts;
  final VoidCallback onSelect;

  const _LangButton({
    required this.label,
    required this.code,
    required this.isActive,
    required this.tts,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AccessibleTapHandler(
        label: label,
        hint: isActive
            ? (code == 'ru' ? 'Текущий язык' : 'Ағымдағы тіл')
            : (code == 'ru' ? 'Нажмите дважды чтобы выбрать' : 'Таңдау үшін екі рет басыңыз'),
        onSpeak: (text) => tts.speak(text, lang: code),
        onAction: onSelect,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF7C4DFF) : const Color(0xFF2A2A3E),
            borderRadius: BorderRadius.circular(14),
            border: isActive
                ? null
                : Border.all(color: const Color(0xFF3A3A4E), width: 1.5),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : const Color(0xFF9999B3),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
