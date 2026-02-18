/// KozAlma AI — API Service.
///
/// HTTP client for communicating with the FastAPI backend.
/// Includes debug logging, platform-aware URL selection,
/// and JWT auth header attachment with auto-refresh on 401.
library;

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import 'token_store.dart';
import 'auth_api_service.dart';

class ApiService {
  final String baseUrl;
  final TokenStore _tokenStore;
  final AuthApiService _authApi;

  ApiService({String? baseUrl})
      : baseUrl = baseUrl ?? AppConstants.apiBaseUrl,
        _tokenStore = TokenStore(),
        _authApi = AuthApiService();

  /// Send image to /scan and return parsed response.
  /// Attaches JWT auth header if available.
  Future<Map<String, dynamic>> scan({
    required Uint8List imageBytes,
    required String lang,
    double ttsSpeed = 1.0,
    bool sendUnknown = false,
    String? sessionId,
  }) async {
    return _withAuth(() => _doScan(
          imageBytes: imageBytes,
          lang: lang,
          ttsSpeed: ttsSpeed,
          sendUnknown: sendUnknown,
          sessionId: sessionId,
        ));
  }

  Future<Map<String, dynamic>> _doScan({
    required Uint8List imageBytes,
    required String lang,
    double ttsSpeed = 1.0,
    bool sendUnknown = false,
    String? sessionId,
  }) async {
    final url = '$baseUrl/scan';
    debugPrint('API: POST $url (lang=$lang, ttsSpeed=$ttsSpeed, sendUnknown=$sendUnknown)');

    final uri = Uri.parse(url);

    final request = http.MultipartRequest('POST', uri)
      ..fields['lang'] = lang
      ..fields['tts_speed'] = ttsSpeed.toString()
      ..fields['send_unknown'] = sendUnknown.toString()
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: 'scan.jpg',
      ));

    if (sessionId != null) {
      request.fields['session_id'] = sessionId;
    }

    // Attach auth header if available
    final token = await _tokenStore.getAccessToken();
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 30),
    );
    final response = await http.Response.fromStream(streamedResponse);

    debugPrint('API: Response status=${response.statusCode}, '
        'body=${response.body.length > 200 ? "${response.body.substring(0, 200)}..." : response.body}');

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw ApiException(
        'Scan failed: status=${response.statusCode}, body=${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  /// Check backend health.
  Future<bool> healthCheck() async {
    final url = '$baseUrl/health';
    debugPrint('API: GET $url');
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 5));
      debugPrint('API: Health status=${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('API: Health check failed: $e');
      return false;
    }
  }

  /// Execute an API call with auto-refresh on 401.
  /// Tries once, if 401 → refreshes tokens → retries once.
  Future<T> _withAuth<T>(Future<T> Function() apiCall) async {
    try {
      return await apiCall();
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        debugPrint('API: 401 received, attempting token refresh...');
        final refreshed = await _authApi.refresh();
        if (refreshed) {
          debugPrint('API: Token refreshed, retrying request...');
          return await apiCall();
        } else {
          debugPrint('API: Refresh failed, user needs to re-login');
          await _tokenStore.clear();
          rethrow;
        }
      }
      rethrow;
    }
  }
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException: $message (status=$statusCode)';
}
