/// KozAlma AI — Auth API Service.
///
/// Communicates with backend /auth endpoints:
///   POST /auth/request-code
///   POST /auth/verify-code
///   POST /auth/refresh
///   GET  /auth/me
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import 'token_store.dart';

class AuthApiService {
  final String baseUrl;
  final TokenStore tokenStore;

  AuthApiService({
    String? baseUrl,
    TokenStore? tokenStore,
  })  : baseUrl = baseUrl ?? AppConstants.apiBaseUrl,
        tokenStore = tokenStore ?? TokenStore();

  /// Request OTP code.
  /// Returns [cooldown_seconds] on success, throws on network error.
  Future<int> requestCode({
    required String channel,
    required String identifier,
  }) async {
    final url = '$baseUrl/auth/request-code';
    debugPrint('Auth: POST $url (channel=$channel)');

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'channel': channel,
        'identifier': identifier.trim(),
      }),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['cooldown_seconds'] as int? ?? 60;
    } else if (response.statusCode == 503) {
      throw AuthException('Сервис аутентификации недоступен');
    } else {
      throw AuthException(
        'Request code failed: ${response.statusCode}',
      );
    }
  }

  /// Verify OTP code and obtain tokens.
  /// Stores tokens automatically on success.
  Future<void> verifyCode({
    required String channel,
    required String identifier,
    required String code,
  }) async {
    final url = '$baseUrl/auth/verify-code';
    debugPrint('Auth: POST $url');

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'channel': channel,
        'identifier': identifier.trim(),
        'code': code.trim(),
      }),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await tokenStore.saveTokens(
        accessToken: data['access_token'],
        refreshToken: data['refresh_token'],
      );
      debugPrint('Auth: tokens obtained and saved');
    } else if (response.statusCode == 401) {
      throw AuthException('Неверный или просроченный код');
    } else {
      throw AuthException(
        'Verify failed: ${response.statusCode}',
      );
    }
  }

  /// Refresh tokens using the stored refresh token.
  /// Returns true on success, false if refresh fails (user should re-login).
  Future<bool> refresh() async {
    final refreshToken = await tokenStore.getRefreshToken();
    if (refreshToken == null) return false;

    final url = '$baseUrl/auth/refresh';
    debugPrint('Auth: POST $url (refresh)');

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await tokenStore.saveTokens(
          accessToken: data['access_token'],
          refreshToken: data['refresh_token'],
        );
        debugPrint('Auth: tokens refreshed');
        return true;
      }
    } catch (e) {
      debugPrint('Auth: refresh error: $e');
    }

    return false;
  }

  /// Get current user profile.
  Future<Map<String, dynamic>?> me() async {
    final token = await tokenStore.getAccessToken();
    if (token == null) return null;

    final url = '$baseUrl/auth/me';
    debugPrint('Auth: GET $url');

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Auth: /me error: $e');
    }
    return null;
  }

  /// Logout — clear stored tokens.
  Future<void> logout() async {
    await tokenStore.clear();
    debugPrint('Auth: logged out');
  }
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => 'AuthException: $message';
}
