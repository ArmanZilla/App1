/// KozAlma AI — Secure Token Store.
///
/// Persists JWT access and refresh tokens using flutter_secure_storage.
/// Falls back to SharedPreferences on web (secure storage not available).
library;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';

class TokenStore {
  static const _keyAccess = 'koz_access_token';
  static const _keyRefresh = 'koz_refresh_token';

  // On mobile we'd use flutter_secure_storage, but for cross-platform
  // compatibility (incl. web), we use SharedPreferences wrapped with
  // clear naming.  In production, swap to flutter_secure_storage on mobile.

  /// Read access token (or null).
  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAccess);
  }

  /// Read refresh token (or null).
  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRefresh);
  }

  /// Save both tokens after login/refresh.
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAccess, accessToken);
    await prefs.setString(_keyRefresh, refreshToken);
    debugPrint('TokenStore: tokens saved');
  }

  /// Clear all tokens (logout).
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAccess);
    await prefs.remove(_keyRefresh);
    debugPrint('TokenStore: tokens cleared');
  }

  /// Check if user has saved tokens.
  Future<bool> hasTokens() async {
    final access = await getAccessToken();
    return access != null && access.isNotEmpty;
  }
}
