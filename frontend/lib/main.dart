import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/app_state.dart';
import 'screens/welcome_screen.dart';
import 'screens/camera_screen.dart';
import 'screens/result_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/auth/enter_identifier_screen.dart';
import 'services/token_store.dart';
import 'services/auth_api_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const KozAlmaApp(),
    ),
  );
}

class KozAlmaApp extends StatelessWidget {
  const KozAlmaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KozAlma AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF6C63FF),
        brightness: Brightness.dark,
        fontFamily: 'Roboto',
      ),
      home: const AuthGate(),
      routes: {
        '/camera': (context) => const CameraScreen(),
        '/result': (context) => const ResultScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/login': (context) => const EnterIdentifierScreen(),
      },
    );
  }
}

/// Auth gate — checks for saved tokens on startup.
/// If valid → WelcomeScreen, if not → EnterIdentifierScreen.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _checking = true;
  bool _authenticated = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final tokenStore = TokenStore();
    final hasTokens = await tokenStore.hasTokens();

    if (hasTokens) {
      // Try to validate token via /auth/me
      final authApi = AuthApiService(tokenStore: tokenStore);
      final profile = await authApi.me();
      if (profile != null) {
        setState(() {
          _authenticated = true;
          _checking = false;
        });
        return;
      }

      // Token expired — try refresh
      final refreshed = await authApi.refresh();
      if (refreshed) {
        final retryProfile = await authApi.me();
        if (retryProfile != null) {
          setState(() {
            _authenticated = true;
            _checking = false;
          });
          return;
        }
      }
    }

    setState(() {
      _authenticated = false;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D0D1A),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF6C63FF),
          ),
        ),
      );
    }

    return _authenticated
        ? const WelcomeScreen()
        : const EnterIdentifierScreen();
  }
}
