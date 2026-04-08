/// KozAlma AI — Enter Identifier Screen.
///
/// First step of OTP auth: user enters email address.
/// Email-only authentication with language toggle.
///
/// Accessibility: EdgeVolumeController for volume gestures,
/// AccessibleTapHandler for 1-tap speak / 2-tap action pattern.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/accessibility.dart';
import '../../core/app_state.dart';
import '../../services/auth_api_service.dart';
import '../../services/tts_service.dart';
import '../../widgets/edge_volume_controller.dart';
import '../../widgets/language_toggle.dart';
import 'enter_code_screen.dart';

class EnterIdentifierScreen extends StatefulWidget {
  const EnterIdentifierScreen({super.key});

  @override
  State<EnterIdentifierScreen> createState() => _EnterIdentifierScreenState();
}

class _EnterIdentifierScreenState extends State<EnterIdentifierScreen> {
  final _identifierCtrl = TextEditingController();
  final _authApi = AuthApiService();
  final _tts = TtsService();
  bool _loading = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final lang = context.read<AppState>().language;
      _tts.stop();
      _tts.speak(
        lang == 'kz'
            ? 'Кіру үшін электрондық поштаңызды енгізіңіз'
            : 'Введите ваш email для входа',
        lang: lang,
      );
    });
  }

  Future<void> _submit() async {
    final lang = context.read<AppState>().language;
    final identifier = _identifierCtrl.text.trim();
    if (identifier.isEmpty) {
      setState(() => _error = lang == 'kz'
          ? 'Электрондық поштаны енгізіңіз'
          : 'Введите email');
      _tts.stop();
      _tts.speak(
        lang == 'kz' ? 'Енгізу өрісі бос' : 'Поле ввода пустое',
        lang: lang,
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final cooldown = await _authApi.requestCode(
        channel: 'email',
        identifier: identifier,
      );
      _tts.stop();
      _tts.speak(
        lang == 'kz' ? 'Код жіберілді' : 'Код отправлен',
        lang: lang,
      );

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EnterCodeScreen(
            channel: 'email',
            identifier: identifier,
            cooldownSeconds: cooldown,
          ),
        ),
      );
    } on AuthException catch (e) {
      setState(() => _error = e.message);
      _tts.stop();
      _tts.speak(e.message, lang: lang);
    } catch (e) {
      final msg = lang == 'kz' ? 'Желі қатесі' : 'Ошибка сети';
      setState(() => _error = msg);
      _tts.stop();
      _tts.speak(
        lang == 'kz'
            ? 'Желі қатесі, кейінірек көріңіз'
            : 'Ошибка сети, попробуйте позже',
        lang: lang,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _identifierCtrl.dispose();
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
        headerExcludeHeight: 80,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),

                // ── Header with Language Toggle ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    LanguageToggle(ttsService: _tts),
                  ],
                ),

                const SizedBox(height: 32),

                // Logo / Title
                const Text(
                  'KozAlma AI',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  lang == 'kz' ? 'Аккаунтқа кіру' : 'Вход в аккаунт',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 48),

                // Email input field
                TextField(
                  controller: _identifierCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                  decoration: InputDecoration(
                    hintText: 'example@mail.com',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.08),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
                    prefixIcon: const Icon(
                      Icons.email,
                      color: Color(0xFF6C63FF),
                    ),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 8),

                // Error message
                if (_error.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _error,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),

                const SizedBox(height: 24),

                // Submit button — AccessibleTapHandler:
                // 1-tap: speaks button label
                // 2-tap: executes _submit()
                AccessibleTapHandler(
                  label: lang == 'kz' ? 'Код алу' : 'Получить код',
                  hint: lang == 'kz'
                      ? 'Кодты жіберу үшін екі рет басыңыз'
                      : 'Нажмите дважды чтобы отправить код',
                  onSpeak: (text) {
                    _tts.stop();
                    _tts.speak(text, lang: lang);
                  },
                  onAction: _loading ? () {} : _submit,
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: _loading
                          ? const Color(0xFF6C63FF).withValues(alpha: 0.5)
                          : const Color(0xFF6C63FF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: _loading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            lang == 'kz' ? 'Код алу' : 'Получить код',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
