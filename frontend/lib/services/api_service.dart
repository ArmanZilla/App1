/// KozAlma AI — API Service.
///
/// HTTP client for communicating with the FastAPI backend.
/// Includes debug logging and platform-aware URL selection.
library;

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/constants.dart';

class ApiService {
  final String baseUrl;

  ApiService({String? baseUrl}) : baseUrl = baseUrl ?? AppConstants.apiBaseUrl;

  /// Send image to /scan and return parsed response.
  Future<Map<String, dynamic>> scan({
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

    try {
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
    } catch (e) {
      if (e is ApiException) rethrow;
      debugPrint('API: Network error: $e');
      throw ApiException('Network error: $e');
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
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException: $message (status=$statusCode)';
}
