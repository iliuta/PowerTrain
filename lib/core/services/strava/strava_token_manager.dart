// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../utils/logger.dart';
import '../http/network_client.dart';
import 'strava_config.dart';

/// Manages Strava authentication tokens and their lifecycle
class StravaTokenManager {
  final FlutterSecureStorage _storage;
  
  StravaTokenManager({FlutterSecureStorage? storage}) 
      : _storage = storage ?? const FlutterSecureStorage(
          aOptions: AndroidOptions(
            sharedPreferencesName: 'FlutterSecureStorageShared',
            preferencesKeyPrefix: 'VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIHNlY3VyZSBzdG9yYWdlCg',
          ),
        );
  
  // Storage keys
  static const String _accessTokenKey = 'strava_access_token';
  static const String _refreshTokenKey = 'strava_refresh_token';
  static const String _expiresAtKey = 'strava_expires_at';
  static const String _athleteNameKey = 'strava_athlete_name';
  static const String _athleteIdKey = 'strava_athlete_id';

  /// Gets a Turnstile token by loading the verification page in a WebView
  Future<String?> getTurnstileToken(BuildContext context) async {
    final completer = Completer<String?>();
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse('https://iliuta.github.io/powertrain-training-sessions/turnstile.html'))
      ..addJavaScriptChannel(
        'turnstileCallback',
        onMessageReceived: (JavaScriptMessage message) {
          logger.i('✅ Turnstile token received');
          completer.complete(message.message);
          Navigator.of(context).pop();
        },
      );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Verifying...'),
        content: SizedBox(
          height: 400,
          width: 300,
          child: WebViewWidget(controller: controller),
        ),
      ),
    );

    return completer.future.timeout(
      const Duration(seconds: 60),
      onTimeout: () {
        logger.e('⏱️ Turnstile token timeout');
        return null;
      },
    );
  }

  /// Safely writes a value to secure storage with fallback to SharedPreferences
  Future<void> _safeWrite(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
      logger.d('✅ Secure storage write successful for key: $key');
    } catch (e) {
      logger.w('⚠️ Secure storage failed, using SharedPreferences fallback: $e');
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fallback_$key', value);
        logger.d('✅ SharedPreferences fallback write successful for key: $key');
      } catch (fallbackError) {
        logger.e('❌ Both secure storage and SharedPreferences failed: $fallbackError');
        rethrow;
      }
    }
  }

  /// Safely reads a value from secure storage with fallback to SharedPreferences
  Future<String?> _safeRead(String key) async {
    try {
      final value = await _storage.read(key: key);
      if (value != null) {
        logger.d('✅ Secure storage read successful for key: $key');
        return value;
      }
    } catch (e) {
      logger.w('⚠️ Secure storage read failed, trying SharedPreferences fallback: $e');
    }

    // Try fallback
    try {
      final prefs = await SharedPreferences.getInstance();
      final fallbackValue = prefs.getString('fallback_$key');
      if (fallbackValue != null) {
        logger.d('✅ SharedPreferences fallback read successful for key: $key');
      }
      return fallbackValue;
    } catch (fallbackError) {
      logger.e('❌ Both secure storage and SharedPreferences read failed: $fallbackError');
      return null;
    }
  }

  /// Safely deletes a value from both storages
  Future<void> _safeDelete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      logger.w('⚠️ Secure storage delete failed: $e');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('fallback_$key');
    } catch (e) {
      logger.w('⚠️ SharedPreferences delete failed: $e');
    }
  }

  /// Checks if user has a valid access token
  Future<bool> isAuthenticated() async {
    try {
      final accessToken = await _safeRead(_accessTokenKey);
      final isAuth = accessToken != null;
      logger.i('🔍 Authentication check: $isAuth');
      return isAuth;
    } catch (e) {
      logger.e('❌ Error checking authentication: $e');
      return false;
    }
  }
  
  /// Gets current authentication status with user info
  Future<Map<String, dynamic>?> getAuthStatus() async {
    try {
      final accessToken = await _safeRead(_accessTokenKey);
      final athleteName = await _safeRead(_athleteNameKey);
      
      if (accessToken != null) {
        logger.i('✅ User is authenticated: ${athleteName ?? 'Unknown'}');
        return {
          'isAuthenticated': true,
          'athleteName': athleteName ?? 'Unknown',
        };
      }
      logger.i('❌ User is not authenticated');
      return null;
    } catch (e) {
      logger.e('❌ Error getting auth status: $e');
      return null;
    }
  }
  
  /// Stores authentication tokens securely
  Future<void> storeTokens({
    required String accessToken,
    required String refreshToken,
    required int expiresAt,
    Map<String, dynamic>? athleteInfo,
  }) async {
    try {
      logger.i('🔒 Attempting to store tokens securely...');
      
      await _safeWrite(_accessTokenKey, accessToken);
      logger.i('✅ Access token stored successfully');
      
      await _safeWrite(_refreshTokenKey, refreshToken);
      logger.i('✅ Refresh token stored successfully');
      
      await _safeWrite(_expiresAtKey, expiresAt.toString());
      logger.i('✅ Expires at stored successfully');
      
      if (athleteInfo != null) {
        final fullName = '${athleteInfo['firstname']} ${athleteInfo['lastname']}';
        await _safeWrite(_athleteNameKey, fullName);
        logger.i('✅ Athlete name stored successfully');
        
        await _safeWrite(_athleteIdKey, athleteInfo['id'].toString());
        logger.i('✅ Athlete ID stored successfully');
      }
      
      logger.i('🎉 All tokens stored successfully in secure storage');
    } catch (e, stackTrace) {
      logger.e('❌ Error storing tokens in secure storage: $e');
      logger.e('Stack trace: $stackTrace');
      rethrow;
    }
  }
  
  /// Gets the current access token, refreshing if necessary
  Future<String?> getValidAccessToken(BuildContext? context) async {
    final tokenRefreshed = await _refreshTokenIfNeeded(context);
    if (!tokenRefreshed) return null;
    
    return await _safeRead(_accessTokenKey);
  }
  

  /// Refreshes access token if needed
  Future<bool> _refreshTokenIfNeeded(BuildContext? context) async {
    try {
      final expiresAtStr = await _safeRead(_expiresAtKey);
      if (expiresAtStr == null) return false;
      
      final expiresAt = int.parse(expiresAtStr);
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      
      // If token is valid for at least the buffer time, no need to refresh
      if (expiresAt > (now + StravaConfig.tokenRefreshBufferSeconds)) return true;
      
      final refreshToken = await _safeRead(_refreshTokenKey);
      if (refreshToken == null) return false;
      
      logger.i('🔄 Refreshing Strava access token...');

      String? turnstileToken;
      if (context != null) {
        // Get Turnstile token for verification
        turnstileToken = await getTurnstileToken(context);
        if (turnstileToken == null) {
          logger.e('❌ Failed to obtain Turnstile token for refresh');
          return false;
        }
        logger.i('✅ Turnstile token obtained for refresh');
      }

      final client = NetworkClient.client;
      final body = {
        'refresh_token': refreshToken,
        'grant_type': 'refresh_token',
      };
      if (turnstileToken != null) {
        body['turnstile_token'] = turnstileToken;
      }
      final response = await client.post(
        Uri.parse(StravaConfig.tokenExchangeUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      
      if (response.statusCode != 200) {
        logger.e('❌ Failed to refresh token: ${response.statusCode}');
        return false;
      }
      
      final tokenData = jsonDecode(response.body);
      
      await _safeWrite(_accessTokenKey, tokenData['access_token']);
      await _safeWrite(_refreshTokenKey, tokenData['refresh_token']);
      await _safeWrite(_expiresAtKey, tokenData['expires_at'].toString());
      
      logger.i('✅ Token refreshed successfully');
      return true;
    } catch (e) {
      logger.e('❌ Error refreshing token: $e');
      return false;
    }
  }
  
  /// Exchanges authorization code for access tokens
  Future<bool> exchangeCodeForTokens(String code, BuildContext? context) async {
    try {
      logger.i('🔄 Exchanging authorization code for tokens...');

      String? turnstileToken;
      if (context != null) {
        // Get Turnstile token for verification
        turnstileToken = await getTurnstileToken(context);
        if (turnstileToken == null) {
          logger.e('❌ Failed to obtain Turnstile token');
          return false;
        }
        logger.i('✅ Turnstile token obtained');
      }

      // Exchange code for tokens
      final client = NetworkClient.client;
      final body = {'code': code};
      if (turnstileToken != null) {
        body['turnstile_token'] = turnstileToken;
      }
      final response = await client.post(
        Uri.parse(StravaConfig.tokenExchangeUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      
      if (response.statusCode != 200) {
        logger.e('❌ Failed to exchange code for token: ${response.statusCode}');
        logger.e('Response: ${response.body}');
        return false;
      }
      
      // Parse and store tokens
      final tokenData = jsonDecode(response.body);
      
      await storeTokens(
        accessToken: tokenData['access_token'],
        refreshToken: tokenData['refresh_token'],
        expiresAt: tokenData['expires_at'],
        athleteInfo: tokenData['athlete'],
      );
      
      final athleteName = tokenData['athlete'] != null 
          ? '${tokenData['athlete']['firstname']} ${tokenData['athlete']['lastname']}'
          : 'Unknown';
          
      logger.i('✅ Authentication successful for athlete: $athleteName');
      return true;
      
    } catch (e) {
      logger.e('❌ Error exchanging code for tokens: $e');
      return false;
    }
  }

  /// Clears all stored authentication data
  Future<void> clearTokens() async {
    logger.i('🚪 Clearing Strava tokens');
    await _safeDelete(_accessTokenKey);
    await _safeDelete(_refreshTokenKey);
    await _safeDelete(_expiresAtKey);
    await _safeDelete(_athleteNameKey);
    await _safeDelete(_athleteIdKey);
  }

  /// Test method to verify secure storage functionality
  /// This should be removed in production
  Future<bool> testSecureStorage() async {
    try {
      logger.i('🧪 Testing secure storage functionality...');
      
      const testKey = 'test_key';
      const testValue = 'test_value_12345';
      
      // Test write
      await _safeWrite(testKey, testValue);
      logger.i('✅ Test write completed');
      
      // Test read
      final readValue = await _safeRead(testKey);
      logger.i('✅ Test read completed: $readValue');
      
      // Test delete
      await _safeDelete(testKey);
      logger.i('✅ Test delete completed');
      
      // Verify deletion
      final deletedValue = await _safeRead(testKey);
      final isDeleted = deletedValue == null;
      logger.i('✅ Test verification completed - deleted: $isDeleted');
      
      final testPassed = readValue == testValue && isDeleted;
      
      if (testPassed) {
        logger.i('🎉 Secure storage test PASSED');
      } else {
        logger.e('❌ Secure storage test FAILED');
      }
      
      return testPassed;
    } catch (e, stackTrace) {
      logger.e('❌ Secure storage test ERROR: $e');
      logger.e('Stack trace: $stackTrace');
      return false;
    }
  }
}