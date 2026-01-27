import 'package:ftms/core/models/device_types.dart';

import 'training_interval.dart';
import 'expanded_unit_training_interval.dart';
import '../../settings/model/user_settings.dart';
import '../../../core/config/live_data_display_config.dart';
import 'target_power_strategy.dart';

class UnitTrainingInterval extends TrainingInterval {
  final String? title;
  final int? duration;
  final int? distance;
  final Map<String, dynamic>? targets;
  final int? resistanceLevel;
  /// Whether the resistance level needs to be converted from the default offline range
  /// to the actual machine's range when running the session.
  /// - `true`: Created offline (e.g., in training session editor), stored in default range (10-150)
  /// - `false`: Created online (e.g., free ride, training generator), stored in actual machine values
  final bool resistanceNeedsConversion;
  @override
  final int? repeat;

  UnitTrainingInterval(
      {this.title,
      this.duration,
      this.distance,
      this.targets,
      this.resistanceLevel,
      this.resistanceNeedsConversion = false,
      this.repeat});

  factory UnitTrainingInterval.fromJson(Map<String, dynamic> json) {
    return UnitTrainingInterval(
      title: json['title'],
      duration: json['duration'],
      distance: json['distance'],
      targets: json['targets'] != null
          ? Map<String, dynamic>.from(json['targets'])
          : null,
      resistanceLevel: json['resistanceLevel'],
      resistanceNeedsConversion: json['resistanceNeedsConversion'] ?? true, // Default to true for backward compatibility with existing sessions
      repeat: json['repeat'],
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'duration': duration,
      'distance': distance,
      'targets': targets,
      'resistanceLevel': resistanceLevel,
      'resistanceNeedsConversion': resistanceNeedsConversion,
      'repeat': repeat,
    };
  }

  ExpandedUnitTrainingInterval _expand({
    required DeviceType machineType,
    UserSettings? userSettings,
    LiveDataDisplayConfig? config,
    required bool isDistanceBased,
  }) {
    Map<String, dynamic>? expandedTargets;
    if (targets != null) {
      expandedTargets = Map<String, dynamic>.from(targets!);
      // Use targetPowerStrategy pattern for power target resolution
      final targetPowerStrategy =
          TargetPowerStrategyFactory.getStrategy(machineType);

      // Apply power strategy to fields that need percentage-based calculation
      // based on userSetting configuration from LiveDataDisplayConfig
      for (final fieldName in expandedTargets.keys.toList()) {
        if (_shouldApplyPowerStrategy(fieldName, config)) {
          expandedTargets[fieldName] = targetPowerStrategy.resolvePower(
              expandedTargets[fieldName], userSettings);
        }
      }
    }
    return ExpandedUnitTrainingInterval(
      title: title,
      duration: isDistanceBased ? null : duration,
      distance: isDistanceBased ? distance : null,
      targets: expandedTargets,
      resistanceLevel: resistanceLevel,
      resistanceNeedsConversion: resistanceNeedsConversion,
      originalInterval: this,
    );
  }

  @override
  List<ExpandedUnitTrainingInterval> expand({
    required DeviceType machineType,
    UserSettings? userSettings,
    LiveDataDisplayConfig? config,
    required bool isDistanceBased,
  }) {
    final r = repeat ?? 1;
    return List.generate(
        r > 0 ? r : 1,
        (_) => _expand(
            machineType: machineType,
            userSettings: userSettings,
            config: config,
            isDistanceBased: isDistanceBased));
  }

  @override
  UnitTrainingInterval copy() {
    return UnitTrainingInterval(
      title: title,
      duration: duration,
      distance: distance,
      targets: targets != null ? Map<String, dynamic>.from(targets!) : null,
      resistanceLevel: resistanceLevel,
      resistanceNeedsConversion: resistanceNeedsConversion,
      repeat: repeat,
    );
  }

  /// Helper method to determine if a field should apply power strategy
  /// based on the field's userSetting configuration in LiveDataDisplayConfig.
  /// This replaces explicit checks for 'Instantaneous Power' and 'Instantaneous Pace'
  /// with logic that checks the userSetting property from the configuration.
  bool _shouldApplyPowerStrategy(
      String fieldName, LiveDataDisplayConfig? config) {
    if (config == null) return false;

    // Find the field configuration for this field name
    try {
      final fieldConfig =
          config.fields.firstWhere((field) => field.name == fieldName);
      // Apply power strategy if the field has a userSetting configured
      return fieldConfig.userSetting != null;
    } catch (e) {
      // Field not found in configuration, don't apply power strategy
      return false;
    }
  }
}
