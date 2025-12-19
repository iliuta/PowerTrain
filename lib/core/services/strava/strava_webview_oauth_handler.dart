import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../utils/logger.dart';
import 'strava_config.dart';
import 'strava_token_manager.dart';

/// Handles OAuth2 authentication flow with Strava using an in-app WebView
class StravaWebViewOAuthHandler {
  final StravaTokenManager _tokenManager;
  final BuildContext? context;

  StravaWebViewOAuthHandler({
    StravaTokenManager? tokenManager,
    this.context,
  }) : _tokenManager = tokenManager ?? StravaTokenManager();

  /// Initiates the OAuth2 authentication flow using WebView
  Future<bool> authenticate() async {
    logger.i('🔎 Starting Strava OAuth authentication with WebView');

    if (context == null) {
      logger.e('❌ BuildContext required for WebView authentication');
      return false;
    }

    try {
      // Construct authorization URL
      final authUrl = _buildAuthUrl();
      logger.i('🌐 Loading Strava OAuth URL in WebView');

      // Show WebView dialog and wait for result
      logger.i('📱 Displaying WebView authentication dialog...');
      final authCode = await showDialog<String?>(
        context: context!,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (BuildContext dialogContext) => StravaWebViewDialog(
          authUrl: authUrl.toString(),
          onAuthCodeReceived: (code) {
            logger.i('📤 Auth code received, closing dialog: ${code.substring(0, 5)}...');
            if (Navigator.canPop(dialogContext)) {
              Navigator.of(dialogContext).pop(code);
            }
          },
          onError: (error) {
            logger.e('❌ WebView error: $error');
            if (Navigator.canPop(dialogContext)) {
              Navigator.of(dialogContext).pop(null);
            }
          },
        ),
      );

      logger.i('✅ Dialog closed. Auth code result: ${authCode != null ? 'received' : 'null'}');

      if (authCode == null) {
        logger.e('❌ No authorization code received from WebView');
        return false;
      }

      logger.i('✅ Authorization code received: ${authCode.substring(0, 5)}...');

      // Exchange code for tokens
      logger.i('🔄 Starting token exchange...');
      final success = await _tokenManager.exchangeCodeForTokens(authCode);
      logger.i('🔄 Token exchange completed: $success');
      return success;
    } catch (e) {
      logger.e('❌ Error during WebView authentication: $e');
      return false;
    }
  }

  /// Builds the authorization URL with OAuth parameters
  Uri _buildAuthUrl() {
    return Uri.parse('${StravaConfig.authUrl}'
        '?client_id=${StravaConfig.clientId}'
        '&response_type=code'
        '&redirect_uri=${StravaConfig.redirectUri}'
        '&approval_prompt=force'
        '&scope=${StravaConfig.authScope}'
        '&code_challenge_method=S256');
  }
}

/// WebView dialog for Strava OAuth authentication
class StravaWebViewDialog extends StatefulWidget {
  final String authUrl;
  final Function(String code) onAuthCodeReceived;
  final Function(String error) onError;

  const StravaWebViewDialog({
    required this.authUrl,
    required this.onAuthCodeReceived,
    required this.onError,
    super.key,
  });

  @override
  State<StravaWebViewDialog> createState() => _StravaWebViewDialogState();
}

class _StravaWebViewDialogState extends State<StravaWebViewDialog> {
  late WebViewController _webViewController;
  bool _isLoading = true;
  String? _error;
  Timer? _authTimeoutTimer;
  bool _isDialogClosing = false;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
    _startAuthTimeout();
  }

  @override
  void dispose() {
    _authTimeoutTimer?.cancel();
    _isDialogClosing = true;
    super.dispose();
  }

  void _initializeWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            logger.i('🔄 WebView page started: $url');
            setState(() {
              _isLoading = true;
              _error = null;
            });
            _checkForRedirect(url);
          },
          onPageFinished: (String url) {
            logger.i('✅ WebView page finished: $url');
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            logger.e('❌ WebView error: ${error.description}');
            setState(() {
              _error = 'Failed to load authentication page';
              _isLoading = false;
            });
            widget.onError(error.description);
          },
          onNavigationRequest: (NavigationRequest request) {
            logger.i('🔗 Navigation requested: ${request.url}');
            _checkForRedirect(request.url);
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.authUrl));
  }

  void _checkForRedirect(String url) {
    // Prevent multiple callbacks if dialog is already closing
    if (_isDialogClosing) {
      logger.i('⏭️ Dialog already closing, ignoring redirect check');
      return;
    }

    // Check if the URL matches the redirect URI
    if (url.startsWith(StravaConfig.redirectUri)) {
      logger.i('✅ Detected redirect URL: $url');

      final uri = Uri.parse(url);
      final code = uri.queryParameters['code'];
      final error = uri.queryParameters['error'];

      if (error != null) {
        logger.e('❌ OAuth error: $error');
        _isDialogClosing = true;
        widget.onError(error);
        return;
      }

      if (code != null) {
        logger.i('🎉 Authorization code extracted: ${code.substring(0, 5)}...');
        _authTimeoutTimer?.cancel();
        _isDialogClosing = true;
        widget.onAuthCodeReceived(code);
      } else {
        logger.e('❌ No authorization code in redirect URL');
        _isDialogClosing = true;
        widget.onError('No authorization code received');
      }
    }
  }

  void _startAuthTimeout() {
    _authTimeoutTimer = Timer(StravaConfig.authTimeout, () {
      if (mounted && !_isDialogClosing) {
        logger.e(
            '⏱️ Authentication timeout after ${StravaConfig.authTimeout.inMinutes} minutes');
        _isDialogClosing = true;
        widget.onError('Authentication timeout');
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop(null);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = screenSize.width;
    final dialogHeight = screenSize.height;

    return Dialog(
      insetPadding: const EdgeInsets.all(5),
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border(
                  bottom: BorderSide(color: Colors.blue.shade200),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock, color: Colors.blue, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Strava Authentication',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Sign in with your Strava account',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // WebView or Error - takes all available space
            Expanded(
              child: _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.red.shade300,
                          ),
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              _error ?? 'An error occurred',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.red,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => Navigator.of(context).pop(null),
                            icon: const Icon(Icons.close),
                            label: const Text('Close'),
                          ),
                        ],
                      ),
                    )
                  : Stack(
                      children: [
                        WebViewWidget(controller: _webViewController),
                        if (_isLoading)
                          Container(
                            color: Colors.white.withValues(alpha: 0.7),
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                      ],
                    ),
            ),
            // Footer with cancel button
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).pop(null),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
