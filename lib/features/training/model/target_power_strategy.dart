import 'package:ftms/core/models/device_types.dart';

import '../../settings/model/user_settings.dart';

abstract class TargetPowerStrategy {
  /// Returns the resolved power value for the given [rawValue] and [userSettings].
  /// If the strategy does not apply, returns the original [rawValue].
  dynamic resolvePower(dynamic rawValue, UserSettings? userSettings);
}

class IndoorBikeTargetPowerStrategy implements TargetPowerStrategy {
  @override
  dynamic resolvePower(dynamic rawValue, UserSettings? userSettings) {
    if (rawValue is String && rawValue.endsWith('%') && userSettings != null) {
      final percent = int.tryParse(rawValue.replaceAll('%', ''));
      if (percent != null) {
        return ((userSettings.cyclingFtp * percent) / 100).round();
      }
    }
    return rawValue;
  }

}

class RowerTargetPowerStrategy implements TargetPowerStrategy {
  @override
  dynamic resolvePower(dynamic rawValue, UserSettings? userSettings) {
    // If value is a percentage string and userSettings is provided, convert to seconds/500m pace
    // Example: '50%' means 50% effort (easier = slower pace), '150%' means 150% effort (harder = faster pace)
    if (rawValue is String && rawValue.endsWith('%') && userSettings != null) {
      final percent = int.tryParse(rawValue.replaceAll('%', ''));
      if (percent != null) {
        // Parse user's rowing FTP (e.g., '2:00' -> 120 seconds)
        final ftpParts = userSettings.rowingFtp.split(':');
        if (ftpParts.length == 2) {
          final minutes = int.tryParse(ftpParts[0]);
          final seconds = int.tryParse(ftpParts[1]);
          if (minutes != null && seconds != null) {
            final ftpSeconds = minutes * 60 + seconds;
            // Lower percentage means easier effort = slower pace (more time)
            // Formula: paceSeconds = ftpSeconds * 100 / percent
            // Example: 50% of 2:20 = 140 * 100 / 50 = 280 seconds = 4:40
            final paceSeconds = (ftpSeconds * 100 / percent).round();
            return paceSeconds;
          }
        }
      }
    }
    return rawValue;
  }

}

class DefaultTargetPowerStrategy implements TargetPowerStrategy {
  @override
  dynamic resolvePower(dynamic rawValue, UserSettings? userSettings) => rawValue;
}

class TargetPowerStrategyFactory {
  static TargetPowerStrategy getStrategy(DeviceType machineType) {
    switch (machineType) {
      case DeviceType.indoorBike:
        return IndoorBikeTargetPowerStrategy();
      case DeviceType.rower:
        return RowerTargetPowerStrategy();
    }
  }
}
