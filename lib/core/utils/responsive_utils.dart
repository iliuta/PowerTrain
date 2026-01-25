import 'package:flutter/widgets.dart';

/// Utility class for responsive sizing across different device form factors.
class ResponsiveUtils {
  /// Width threshold to consider a device as a tablet.
  static const double tabletWidthThreshold = 600.0;
  
  /// Both dimensions must exceed this for tablet classification.
  static const double tabletMinDimension = 700.0;

  /// Returns true if the device is considered a tablet based on screen dimensions.
  /// Requires both width and height to be adequate tablet-like dimensions.
  static bool isBigScreen(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final shortestSide = size.shortestSide;
    final longestSide = size.longestSide;

    // Both dimensions must be sufficiently large to qualify as a tablet
    return shortestSide >= tabletWidthThreshold && longestSide >= tabletMinDimension;
  }

  /// Returns a dynamic scale factor based on screen size.
  /// Scales smoothly from 1.0 (small phones) to 3.0 (large tablets).
  static double scaleFactor(BuildContext context) {

    final size = MediaQuery.of(context).size;
    final shortestSide = size.shortestSide;

    // Start scaling up from 500px, reach max at 1000px
    if (shortestSide < 500) {
      return 1.0;
    } else if (shortestSide > 1000) {
      return 3.0;
    } else {
      // Linear interpolation between 1.0 and 2.2
      return 1.0 + ((shortestSide - 500) / 500) * 3.0;
    }
  }


  /// 4 columns for normal phones in landscape because the scaleFactor is smaller
  static int getOptimalColumnCount(BuildContext context) {
    final orientation = MediaQuery.of(context).orientation;
    return (orientation == Orientation.portrait ||
        ResponsiveUtils.isBigScreen(context))
        ? 3 : 4;
  }
}
