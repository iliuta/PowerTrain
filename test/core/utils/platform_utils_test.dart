import 'package:flutter_test/flutter_test.dart';
import 'package:ftms/core/utils/platform_utils.dart';
import 'dart:io' show Platform;

void main() {
  test('logic covers all supported platforms', () {
    // Verify the implementation checks for Android, iOS, and macOS
    final result = Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
    expect(PlatformUtils.isWebViewSupported(), equals(result));
  });
}
