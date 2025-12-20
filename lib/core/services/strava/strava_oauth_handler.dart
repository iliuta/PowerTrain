import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:app_links/app_links.dart';
import '../../utils/logger.dart';
import 'strava_config.dart';
import 'strava_token_manager.dart';

/// Handles the OAuth2 authentication flow with Strava
class StravaOAuthHandler {
  final StravaTokenManager _tokenManager;

  StravaOAuthHandler({
    StravaTokenManager? tokenManager,
  }) : _tokenManager = tokenManager ?? StravaTokenManager();

  /// Initiates the OAuth2 authentication flow
  Future<bool> authenticate() async {
    logger.i('🔎 Starting Strava OAuth authentication');

    try {
      // Construct authorization URL
      final authUrl = _buildAuthUrl();

      logger.i('Starting Strava OAuth PKCE flow: $authUrl');

      // Launch browser for authentication
      if (!await _launchBrowser(authUrl)) {
        logger.e("❌ Failed to open browser");
        return false;
      }

      // Wait for callback and process result
      final authCode = await _waitForCallback();
      if (authCode == null) return false;

      // Exchange code for tokens
      return await _tokenManager.exchangeCodeForTokens(authCode, null);
    } catch (e) {
      logger.e('❌ Error during authentication: $e');
      return false;
    }
  }

  /// Builds the authorization URL with PKCE parameters
  Uri _buildAuthUrl() {
    return Uri.parse('${StravaConfig.authUrl}'
        '?client_id=${StravaConfig.clientId}'
        '&response_type=code'
        '&redirect_uri=${StravaConfig.redirectUri}'
        '&approval_prompt=force'
        '&scope=${StravaConfig.authScope}'
        '&code_challenge_method=S256');
  }

  /// Launches the browser with the authorization URL
  Future<bool> _launchBrowser(Uri authUrl) async {
    try {
      return await launchUrl(
        authUrl,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      logger.e('Error launching browser: $e');
      return false;
    }
  }

  /// Waits for the OAuth callback and extracts the authorization code
  Future<String?> _waitForCallback() async {
    logger.i('🌐 Browser opened with authorization URL');
    logger.i('⏳ Waiting for deep link callback...');

    final appLinks = AppLinks();
    final completer = Completer<Uri?>();

    // Listen for deep links
    final subscription = appLinks.uriLinkStream.listen(
      (Uri? uri) {
        if (uri != null &&
            uri.toString().startsWith(StravaConfig.redirectUri)) {
          logger.i('✅ Received callback URI: $uri');
          completer.complete(uri);
        }
      },
      onError: (error) {
        logger.e('❌ Deep link error: $error');
        completer.completeError(error);
      },
    );

    try {
      // Wait for callback or timeout
      final receivedUri = await completer.future.timeout(
        StravaConfig.authTimeout,
        onTimeout: () {
          logger.e(
              '⏱️ Authentication timeout after ${StravaConfig.authTimeout.inMinutes} minutes');
          throw TimeoutException('Authentication timeout');
        },
      );

      if (receivedUri == null) {
        logger.e('❌ No valid URI received');
        return null;
      }

      // Extract authorization code
      final code = receivedUri.queryParameters['code'];
      if (code == null) {
        logger.e('❌ No authorization code in redirect URI');
        logger.e('🔍 URI params: ${receivedUri.queryParameters}');
        return null;
      }

      logger.i('✅ Authorization code received: ${code.substring(0, 5)}...');
      return code;
    } finally {
      subscription.cancel();
    }
  }
}
