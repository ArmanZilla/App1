/// KozAlma AI — Enter Identifier Screen.
///
/// First step of OTP auth: user enters email or phone number.
/// Channel selector (email / phone) + accessible UI.
library;

import 'package:flutter/material.dart';
import '../../services/auth_api_service.dart';
import '../../services/tts_service.dart';
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
  String _channel = 'email';
  bool _loading = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tts.speak('Введите ваш email или номер телефона для входа', lang: 'ru');
    });
  }

  Future<void> _submit() async {
    final identifier = _identifierCtrl.text.trim();
    if (identifier.isEmpty) {
      setState(() => _error = 'Введите email или номер телефона');
      _tts.speak('Поле ввода пустое', lang: 'ru');
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final cooldown = await _authApi.requestCode(
        channel: _channel,
        identifier: identifier,
      );
      _tts.speak('Код отправлен', lang: 'ru');

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EnterCodeScreen(
            channel: _channel,
            identifier: identifier,
            cooldownSeconds: cooldown,
          ),
        ),
      );
    } on AuthException catch (e) {
      setState(() => _error = e.message);
      _tts.speak(e.message, lang: 'ru');
    } catch (e) {
      setState(() => _error = 'Ошибка сети');
      _tts.speak('Ошибка сети, попробуйте позже', lang: 'ru');
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
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 60),

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
                'Вход в аккаунт',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 48),

              // Channel selector
              Row(
                children: [
                  _channelChip('email', 'Email', Icons.email_outlined),
                  const SizedBox(width: 12),
                  _channelChip('phone', 'Телефон', Icons.phone_outlined),
                ],
              ),
              const SizedBox(height: 20),

              // Input field
              TextField(
                controller: _identifierCtrl,
                autofocus: true,
                keyboardType: _channel == 'email'
                    ? TextInputType.emailAddress
                    : TextInputType.phone,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                decoration: InputDecoration(
                  hintText: _channel == 'email'
                      ? 'example@mail.com'
                      : '+7 701 234 5678',
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
                  prefixIcon: Icon(
                    _channel == 'email' ? Icons.email : Icons.phone,
                    color: const Color(0xFF6C63FF),
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

              // Submit button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Получить код'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _channelChip(String value, String label, IconData icon) {
    final selected = _channel == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _channel = value);
          _tts.speak(label, lang: 'ru');
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF6C63FF).withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? const Color(0xFF6C63FF)
                  : Colors.white.withValues(alpha: 0.1),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 20,
                  color: selected ? const Color(0xFF6C63FF) : Colors.white54),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: selected ? const Color(0xFF6C63FF) : Colors.white54,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
