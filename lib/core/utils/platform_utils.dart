import 'dart:io' show Platform;

/// Utility class for platform-specific operations
class PlatformUtils {
  /// Checks if WebView is supported on the current platform
  /// WebView is supported on Android, iOS, and macOS
  static bool isWebViewSupported() {
    return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
  }
}