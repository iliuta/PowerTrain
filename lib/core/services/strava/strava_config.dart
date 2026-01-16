/// Configuration constants for Strava integration
class StravaConfig {
  static const String clientId = '3929';
  static const String redirectUri = 'ftmsapp://strava/callback';
  static const String authUrl = 'https://www.strava.com/oauth/authorize';
  static const String tokenExchangeUrl = 'https://strava-token-exchange-staging.iliuta.workers.dev';
  static const String uploadUrl = 'https://www.strava.com/api/v3/uploads';

  // Authentication timeouts and scopes
  static const Duration authTimeout = Duration(minutes: 3);
  static const String authScope = 'activity:write,read';
  static const int tokenRefreshBufferSeconds = 300; // 5 minutes
}