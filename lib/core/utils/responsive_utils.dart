import 'package:flutter/widgets.dart';

/// Utility class for responsive sizing across different device form factors.
class ResponsiveUtils {
  /// Width threshold to consider a device as a tablet.
  static const double tabletWidthThreshold = 600.0;

  /// Returns true if the device is considered a tablet based on screen width.
  static bool isTablet(BuildContext context) {
    final shortestSide = MediaQuery.of(context).size.shortestSide;
    return shortestSide >= tabletWidthThreshold;
  }

  /// Returns a scale factor for font sizes and widgets.
  /// Returns 1.0 for phones and a larger factor for tablets.
  static double scaleFactor(BuildContext context) {
    return isTablet(context) ? 2.5 : 1.0;
  }

  /// Scales a value based on device type.
  static double scale(BuildContext context, double value) {
    return value * scaleFactor(context);
  }
}
