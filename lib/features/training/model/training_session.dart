import 'package:ftms/core/models/device_types.dart';

import 'unit_training_interval.dart';
import 'training_interval.dart';
import 'group_training_interval.dart';
import 'expanded_training_session_definition.dart';
import 'expanded_unit_training_interval.dart';
import '../../settings/model/user_settings.dart';
import '../../../core/config/live_data_display_config.dart';

class TrainingSessionDefinition {
  final String title;
  final DeviceType ftmsMachineType;
  final List<TrainingInterval> intervals;
  final bool isCustom;
  final bool isDistanceBased;
  /// The original non-expanded session definition for editing purposes
  final TrainingSessionDefinition? originalSession;

  TrainingSessionDefinition({
    required this.title, 
    required this.ftmsMachineType, 
    required this.intervals,
    this.isCustom = false,
    this.isDistanceBased = false,
    this.originalSession,
  });

  factory TrainingSessionDefinition.fromJson(Map<String, dynamic> json, {bool isCustom = false}) {
    final List intervalsRaw = json['intervals'] as List;
    final List<TrainingInterval> intervals = intervalsRaw
        .map((e) => TrainingIntervalFactory.fromJsonPolymorphic(e))
        .toList();
    
    return TrainingSessionDefinition(
      title: json['title'],
      ftmsMachineType: DeviceType.fromString(json['ftmsMachineType']),
      intervals: intervals,
      isCustom: isCustom,
      isDistanceBased: json['isDistanceBased'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'ftmsMachineType': ftmsMachineType.name,
      'intervals': intervals.map((interval) => interval.toJson()).toList(),
      'isDistanceBased': isDistanceBased,
    };
  }

  /// Creates a copy of this training session with all fields copied field by field.
  /// No expansion is performed - the intervals are copied in their original form.
  TrainingSessionDefinition copy() {
    return TrainingSessionDefinition(
      title: title,
      ftmsMachineType: ftmsMachineType,
      intervals: intervals.map((interval) => interval.copy()).toList(),
      isCustom: isCustom,
      isDistanceBased: isDistanceBased,
      originalSession: originalSession?.copy(),
    );
  }

  /// Creates a new instance with expanded intervals and target values.
  /// This expands group intervals into their constituent unit intervals
  /// and resolves percentage-based targets using the provided user settings.
  ExpandedTrainingSessionDefinition expand({
    required UserSettings userSettings,
    LiveDataDisplayConfig? config,
  }) {
    final List<ExpandedUnitTrainingInterval> expandedIntervals = [];
    
    for (final interval in intervals) {
      final expandedTargetsInterval = interval.expand(
        machineType: ftmsMachineType,
        userSettings: userSettings,
        config: config,
        isDistanceBased: isDistanceBased,
      );
      expandedIntervals.addAll(expandedTargetsInterval);
    }
    
    return ExpandedTrainingSessionDefinition(
      title: title,
      ftmsMachineType: ftmsMachineType,
      intervals: expandedIntervals,
      isCustom: isCustom,
      isDistanceBased: isDistanceBased,
    );
  }

  /// Creates a templated training session based on machine type
  static TrainingSessionDefinition createTemplate(DeviceType machineType, {bool isDistanceBased = false, int? workoutValue, Map<String, dynamic>? targets, int? resistanceLevel, bool hasWarmup = true, bool hasCooldown = true}) {
    final defaultWorkoutValue = isDistanceBased ? 5000 : 1200; // 5km for distance, 20min for time
    final actualWorkoutValue = workoutValue ?? defaultWorkoutValue;
    final String machineName = machineType == DeviceType.rower ? 'Rowing' : 'Cycling';
    final String sessionType = isDistanceBased ? 'Distance' : 'Time';
    final String title = 'New $machineName $sessionType Training Session';

    final intervals = machineType == DeviceType.indoorBike
        ? _createBikeTemplate(actualWorkoutValue, isDistanceBased: isDistanceBased, targets: targets, resistanceLevel: resistanceLevel, hasWarmup: hasWarmup, hasCooldown: hasCooldown)
        : _createRowerTemplate(actualWorkoutValue, isDistanceBased: isDistanceBased, targets: targets, resistanceLevel: resistanceLevel, hasWarmup: hasWarmup, hasCooldown: hasCooldown);

    return TrainingSessionDefinition(
      title: title,
      ftmsMachineType: machineType,
      intervals: intervals,
      isCustom: true,
      isDistanceBased: isDistanceBased,
    );
  }

  static List<TrainingInterval> _createBikeTemplate(int workoutValue, {bool isDistanceBased = false, Map<String, dynamic>? targets, int? resistanceLevel, bool hasWarmup = true, bool hasCooldown = true}) {
    // Bike template always has just the workout interval
    return [
      UnitTrainingInterval(
        title: 'Workout',
        duration: isDistanceBased ? null : workoutValue,
        distance: isDistanceBased ? workoutValue : null,
        targets: targets ?? {},
        resistanceLevel: resistanceLevel,
      ),
    ];
  }

  static List<TrainingInterval> _createRowerTemplate(int workoutValue, {bool isDistanceBased = false, Map<String, dynamic>? targets, int? resistanceLevel, bool hasWarmup = true, bool hasCooldown = true}) {
    if (isDistanceBased) {
      // Distance-based rowing template
      final warmupDistance = 200; // 200m per interval
      final cooldownDistance = 200; // 200m per interval
      final int totalWarmupDistance = hasWarmup ? 5 * warmupDistance : 0;
      final int totalCooldownDistance = hasCooldown ? 5 * cooldownDistance : 0;
      final workoutDistanceAdjusted = workoutValue - totalWarmupDistance - totalCooldownDistance;

      final List<TrainingInterval> intervals = [];

      if (hasWarmup) {
        final warmUpIntervals = List.generate(5, (i) => UnitTrainingInterval(
          title: 'Warm Up ${i + 1}',
          distance: warmupDistance,
          targets: {'Instantaneous Pace': '${84 + i * 3}%', 'Stroke Rate': 20},
          resistanceLevel: 20 + i * 10,
        ));
        final warmUpGroup = GroupTrainingInterval(intervals: warmUpIntervals, repeat: 1);
        intervals.add(warmUpGroup);
      }

      final workoutInterval = UnitTrainingInterval(
        title: 'Workout',
        distance: workoutDistanceAdjusted > 0 ? workoutDistanceAdjusted : workoutValue,
        targets: targets ?? {'Instantaneous Pace': '96%', 'Stroke Rate': 22},
        resistanceLevel: resistanceLevel ?? 60,
      );
      intervals.add(workoutInterval);

      if (hasCooldown) {
        final coolDownIntervals = List.generate(5, (i) => UnitTrainingInterval(
          title: 'Cool down ${i + 1}',
          distance: cooldownDistance,
          targets: {'Instantaneous Pace': '${84 + (4 - i) * 3}%', 'Stroke Rate': 20},
          resistanceLevel: 20 + (4 - i) * 10,
        ));
        final coolDownGroup = GroupTrainingInterval(intervals: coolDownIntervals, repeat: 1);
        intervals.add(coolDownGroup);
      }

      return intervals;
    } else {
      // Time-based rowing template (existing logic)
      final warmupDuration = 5 * 60;
      final cooldownDuration = 5 * 60;
      final int totalWarmupDuration = hasWarmup ? warmupDuration : 0;
      final int totalCooldownDuration = hasCooldown ? cooldownDuration : 0;
      final workoutDurationAdjusted = workoutValue - totalWarmupDuration - totalCooldownDuration;

      final List<TrainingInterval> intervals = [];

      if (hasWarmup) {
        final warmUpIntervals = List.generate(5, (i) => UnitTrainingInterval(
          title: 'Warm Up ${i + 1}',
          duration: 60,
          targets: {'Instantaneous Pace': '${84 + i * 3}%', 'Stroke Rate': 20},
          resistanceLevel: 20 + i * 10,
        ));
        final warmUpGroup = GroupTrainingInterval(intervals: warmUpIntervals, repeat: 1);
        intervals.add(warmUpGroup);
      }

      final workoutInterval = UnitTrainingInterval(
        title: 'Workout',
        duration: workoutDurationAdjusted,
        targets: targets ?? {'Instantaneous Pace': '96%', 'Stroke Rate': 22},
        resistanceLevel: resistanceLevel ?? 60,
      );
      intervals.add(workoutInterval);

      if (hasCooldown) {
        final coolDownIntervals = List.generate(5, (i) => UnitTrainingInterval(
          title: 'Cool down ${i + 1}',
          duration: 60,
          targets: {'Instantaneous Pace': '${84 + (4 - i) * 3}%', 'Stroke Rate': 20},
          resistanceLevel: 20 + (4 - i) * 10,
        ));
        final coolDownGroup = GroupTrainingInterval(intervals: coolDownIntervals, repeat: 1);
        intervals.add(coolDownGroup);
      }

      return intervals;
    }
  }
}

extension TrainingIntervalFactory on TrainingInterval {
  /// Only first-level can be group, second-level must be unit
  static TrainingInterval fromJsonPolymorphic(Map<String, dynamic> json) {
    if (json.containsKey('intervals')) {
      return GroupTrainingInterval.fromJson(json);
    } else {
      return UnitTrainingInterval.fromJson(json);
    }
  }
}