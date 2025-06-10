import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:app_links/app_links.dart';
import '../../utils/logger.dart';
import 'strava_config.dart';
import 'pkce_generator.dart';
import 'strava_token_manager.dart';

/// Handles the OAuth2 authentication flow with Strava
class StravaOAuthHandler {
  final PkceGenerator _pkceGenerator;
  final StravaTokenManager _tokenManager;
  
  StravaOAuthHandler({
    PkceGenerator? pkceGenerator,
    StravaTokenManager? tokenManager,
  }) : _pkceGenerator = pkceGenerator ?? PkceGenerator(),
       _tokenManager = tokenManager ?? StravaTokenManager();
  
  /// Initiates the OAuth2 authentication flow
  Future<bool> authenticate() async {
    logger.i('🔎 Starting Strava OAuth authentication');
    
    try {
      // Generate PKCE parameters
      final pkceParams = _pkceGenerator.generatePkceParams();
      
      // Store code verifier for later use
      await _tokenManager.storeCodeVerifier(pkceParams.verifier);
      
      // Construct authorization URL
      final authUrl = _buildAuthUrl(pkceParams.challenge);
      
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
      return await _exchangeCodeForTokens(authCode);
      
    } catch (e) {
      logger.e('❌ Error during authentication: $e');
      await _tokenManager.getAndRemoveCodeVerifier(); // Cleanup
      return false;
    }
  }
  
  /// Builds the authorization URL with PKCE parameters
  Uri _buildAuthUrl(String codeChallenge) {
    return Uri.parse('${StravaConfig.authUrl}'
        '?client_id=${StravaConfig.clientId}'
        '&response_type=code'
        '&redirect_uri=${StravaConfig.redirectUri}'
        '&approval_prompt=force'
        '&scope=${StravaConfig.authScope}'
        '&code_challenge=$codeChallenge'
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
        if (uri != null && uri.toString().startsWith(StravaConfig.redirectUri)) {
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
          logger.e('⏱️ Authentication timeout after ${StravaConfig.authTimeout.inMinutes} minutes');
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
  
  /// Exchanges authorization code for access tokens
  Future<bool> _exchangeCodeForTokens(String code) async {
    try {
      // Get stored code verifier
      final codeVerifier = await _tokenManager.getAndRemoveCodeVerifier();
      if (codeVerifier == null) {
        logger.e('❌ Code verifier not found in storage');
        return false;
      }
      
      // Exchange code for tokens
      final response = await http.post(
        Uri.parse(StravaConfig.tokenExchangeUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'code': code}),
      );
      
      if (response.statusCode != 200) {
        logger.e('❌ Failed to exchange code for token: ${response.statusCode}');
        logger.e('Response: ${response.body}');
        return false;
      }
      
      // Parse and store tokens
      final tokenData = jsonDecode(response.body);
      
      await _tokenManager.storeTokens(
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
}
