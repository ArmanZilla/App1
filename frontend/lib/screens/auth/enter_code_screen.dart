/// KozAlma AI — Enter Code Screen.
///
/// Second step of OTP auth: user enters the 6-digit code.
/// Includes countdown timer and resend button.
///
/// Accessibility: EdgeVolumeController for volume gestures,
/// AccessibleTapHandler for 1-tap speak / 2-tap action pattern.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/accessibility.dart';
import '../../core/app_state.dart';
import '../../services/auth_api_service.dart';
import '../../services/tts_service.dart';
import '../../widgets/edge_volume_controller.dart';
import '../welcome_screen.dart';

class EnterCodeScreen extends StatefulWidget {
  final String channel;
  final String identifier;
  final int cooldownSeconds;

  const EnterCodeScreen({
    super.key,
    required this.channel,
    required this.identifier,
    required this.cooldownSeconds,
  });

  @override
  State<EnterCodeScreen> createState() => _EnterCodeScreenState();
}

class _EnterCodeScreenState extends State<EnterCodeScreen> {
  final _codeCtrl = TextEditingController();
  final _authApi = AuthApiService();
  final _tts = TtsService();
  bool _loading = false;
  String _error = '';
  late int _countdown;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _countdown = widget.cooldownSeconds;
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final lang = context.read<AppState>().language;
      _tts.stop();
      _tts.speak(
        lang == 'kz'
            ? '${widget.identifier} адресіне жіберілген алты санды кодты енгізіңіз'
            : 'Введите шестизначный код, отправленный на ${widget.identifier}',
        lang: lang,
      );
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown <= 0) {
        t.cancel();
      } else {
        setState(() => _countdown--);
      }
    });
  }

  Future<void> _verify() async {
    final lang = context.read<AppState>().language;
    final code = _codeCtrl.text.trim();
    if (code.length != 6) {
      final msg = lang == 'kz'
          ? 'Код 6 саннан тұруы керек'
          : 'Код должен содержать 6 цифр';
      setState(() => _error = msg);
      _tts.stop();
      _tts.speak(msg, lang: lang);
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      await _authApi.verifyCode(
        channel: widget.channel,
        identifier: widget.identifier,
        code: code,
      );
      _tts.stop();
      _tts.speak(
        lang == 'kz' ? 'Кіру сәтті орындалды' : 'Вход выполнен успешно',
        lang: lang,
      );

      if (!mounted) return;
      // Navigate to main app, clearing auth stack
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (route) => false,
      );
    } on AuthException catch (e) {
      setState(() => _error = e.message);
      _tts.stop();
      _tts.speak(e.message, lang: lang);
    } catch (e) {
      final msg = lang == 'kz' ? 'Желі қатесі' : 'Ошибка сети';
      setState(() => _error = msg);
      _tts.stop();
      _tts.speak(msg, lang: lang);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    if (_countdown > 0) return;

    final lang = context.read<AppState>().language;

    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final cooldown = await _authApi.requestCode(
        channel: widget.channel,
        identifier: widget.identifier,
      );
      setState(() => _countdown = cooldown);
      _startTimer();
      _tts.stop();
      _tts.speak(
        lang == 'kz' ? 'Код қайта жіберілді' : 'Код отправлен повторно',
        lang: lang,
      );
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = lang == 'kz' ? 'Желі қатесі' : 'Ошибка сети');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeCtrl.dispose();
    _tts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final lang = state.language;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      // EdgeVolumeController: enables left/right edge double-tap for volume
      // headerExcludeHeight: 80 to exclude Back button area
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

                // Back button — AccessibleTapHandler:
                // 1-tap: speaks "Назад" / "Артқа"
                // 2-tap: navigates back
                Align(
                  alignment: Alignment.centerLeft,
                  child: AccessibleTapHandler(
                    label: lang == 'kz' ? 'Артқа' : 'Назад',
                    hint: lang == 'kz'
                        ? 'Оралу үшін екі рет басыңыз'
                        : 'Нажмите дважды чтобы вернуться',
                    onSpeak: (text) {
                      _tts.stop();
                      _tts.speak(text, lang: lang);
                    },
                    onAction: () => Navigator.pop(context),
                    child: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(Icons.arrow_back, color: Colors.white, size: 28),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Title
                Text(
                  lang == 'kz' ? 'Кодты енгізіңіз' : 'Введите код',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  lang == 'kz'
                      ? 'Код жіберілді\n${widget.identifier}'
                      : 'Код отправлен на\n${widget.identifier}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 15,
                  ),
                ),

                const SizedBox(height: 40),

                // Code input
                TextField(
                  controller: _codeCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 16,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '• • • • • •',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.2),
                      fontSize: 32,
                      letterSpacing: 16,
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.08),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 20,
                    ),
                  ),
                  onSubmitted: (_) => _verify(),
                ),

                if (_error.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _error,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),

                const SizedBox(height: 24),

                // Verify button
                AccessibleTapHandler(
                  label: lang == 'kz' ? 'Растау' : 'Подтвердить',
                  hint: lang == 'kz'
                      ? 'Кодты растау үшін екі рет басыңыз'
                      : 'Нажмите дважды чтобы подтвердить код',
                  onSpeak: (text) {
                    _tts.stop();
                    _tts.speak(text, lang: lang);
                  },
                  onAction: _loading ? () {} : _verify,
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
                            lang == 'kz' ? 'Растау' : 'Подтвердить',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 20),

                // Resend button
                Center(
                  child: AccessibleTapHandler(
                    label: _countdown > 0
                        ? (lang == 'kz'
                            ? '$_countdown секундтан кейін қайта жіберу'
                            : 'Отправить повторно через $_countdown секунд')
                        : (lang == 'kz'
                            ? 'Қайта жіберу'
                            : 'Отправить повторно'),
                    hint: _countdown > 0
                        ? (lang == 'kz'
                            ? '$_countdown секунд күтіңіз'
                            : 'Подождите $_countdown секунд')
                        : (lang == 'kz'
                            ? 'Кодты қайта жіберу үшін екі рет басыңыз'
                            : 'Нажмите дважды чтобы отправить код повторно'),
                    onSpeak: (text) {
                      _tts.stop();
                      _tts.speak(text, lang: lang);
                    },
                    onAction: _countdown > 0 ? () {} : _resend,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      child: Text(
                        _countdown > 0
                            ? (lang == 'kz'
                                ? '$_countdown с кейін қайта жіберу'
                                : 'Отправить повторно через $_countdown с')
                            : (lang == 'kz'
                                ? 'Қайта жіберу'
                                : 'Отправить повторно'),
                        style: TextStyle(
                          color: _countdown > 0
                              ? Colors.white.withValues(alpha: 0.3)
                              : const Color(0xFF6C63FF),
                          fontSize: 15,
                        ),
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
