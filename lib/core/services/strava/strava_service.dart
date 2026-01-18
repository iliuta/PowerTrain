import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'strava_token_manager.dart';
import 'strava_oauth_handler.dart';
import 'strava_webview_oauth_handler.dart';
import 'strava_activity_uploader.dart';

/// Main Strava service that orchestrates the various components
/// This class follows SOLID principles:
/// - SRP: Each component has a single responsibility
/// - OCP: Open for extension, closed for modification
/// - DIP: Depends on abstractions (injected dependencies)
class StravaService {
  final StravaTokenManager _tokenManager;
  final StravaOAuthHandler _oauthHandler;
  final StravaWebViewOAuthHandler? _webViewOAuthHandler;
  final StravaActivityUploader _activityUploader;
  
  StravaService({
    StravaTokenManager? tokenManager,
    StravaOAuthHandler? oauthHandler,
    StravaWebViewOAuthHandler? webViewOAuthHandler,
    StravaActivityUploader? activityUploader,
  }) : _tokenManager = tokenManager ?? StravaTokenManager(),
       _oauthHandler = oauthHandler ?? StravaOAuthHandler(),
       _webViewOAuthHandler = webViewOAuthHandler,
       _activityUploader = activityUploader ?? StravaActivityUploader();
  
  // Authentication methods - delegates to OAuth handler (with WebView support)
  /// Authenticates with Strava using WebView if context is available, otherwise uses external browser
  /// 
  /// [context] - BuildContext required for WebView authentication. If null, falls back to external browser.
  /// 
  /// Returns true if authentication was successful, false otherwise.
  Future<bool> authenticate({BuildContext? context}) async {
    // Try WebView authentication if context is provided
    if (context != null && !Platform.isLinux) {
      final webViewHandler = StravaWebViewOAuthHandler(
        tokenManager: _tokenManager,
        context: context,
      );
      return await webViewHandler.authenticate();
    }
    
    // Fall back to external browser
    return await _oauthHandler.authenticate();
  }
  
  // Token management methods - delegates to token manager
  Future<bool> isAuthenticated() => _tokenManager.isAuthenticated();
  Future<Map<String, dynamic>?> getAuthStatus() => _tokenManager.getAuthStatus();
  Future<void> signOut() => _tokenManager.clearTokens();
  
  // Activity upload methods - delegates to activity uploader
  /// Uploads a FIT file activity to Strava with specified activity type
  /// 
  /// [fitFilePath] - Path to the FIT file
  /// [activityName] - Name of the activity
  /// [activityType] - Type of activity (e.g., 'ride' for cycling, 'rowing' for rowing)
  /// 
  /// Returns the upload response or null if failed
  /// 
  /// Example:
  /// ```dart
  /// // Upload a cycling activity
  /// await stravaService.uploadActivity('/path/to/ride.fit', 'Morning Ride', activityType: 'ride');
  /// 
  /// // Upload a rowing activity
  /// await stravaService.uploadActivity('/path/to/row.fit', 'Evening Row', activityType: 'rowing');
  /// 
  /// // Upload a running activity
  /// await stravaService.uploadActivity('/path/to/run.fit', 'Park Run', activityType: 'run');
  /// ```
  Future<Map<String, dynamic>?> uploadActivity(
    String fitFilePath, 
    String activityName, {
    String activityType = 'workout',
  }) => _activityUploader.uploadActivity(
    fitFilePath, 
    activityName, 
    activityType: activityType,
  );
      
  Future<Map<String, dynamic>?> uploadActivityWithMetadata({
    required String fitFilePath,
    required String name,
    String? description,
    String activityType = 'workout',
    bool isPrivate = false,
    bool hasHeartrate = false,
    bool hasPower = false,
  }) => _activityUploader.uploadActivityWithMetadata(
    fitFilePath: fitFilePath,
    name: name,
    description: description,
    activityType: activityType,
    isPrivate: isPrivate,
    hasHeartrate: hasHeartrate,
    hasPower: hasPower,
  );
  
  // Direct access to specialized components for advanced usage
  StravaTokenManager get tokenManager => _tokenManager;
  StravaOAuthHandler get oauthHandler => _oauthHandler;
  StravaWebViewOAuthHandler? get webViewOAuthHandler => _webViewOAuthHandler;
  StravaActivityUploader get activityUploader => _activityUploader;
}
