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
  /// The original non-expanded session definition for editing purposes
  final TrainingSessionDefinition? originalSession;

  TrainingSessionDefinition({
    required this.title, 
    required this.ftmsMachineType, 
    required this.intervals,
    this.isCustom = false,
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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'ftmsMachineType': ftmsMachineType.name,
      'intervals': intervals.map((interval) => interval.toJson()).toList(),
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
      );
      expandedIntervals.addAll(expandedTargetsInterval);
    }
    
    return ExpandedTrainingSessionDefinition(
      title: title,
      ftmsMachineType: ftmsMachineType,
      intervals: expandedIntervals,
      isCustom: isCustom,
    );
  }

  /// Creates a templated training session based on machine type
  static TrainingSessionDefinition createTemplate(DeviceType machineType, int workoutDuration) {
    final String machineName = machineType == DeviceType.rower ? 'Rowing' : 'Cycling';
    final String title = 'New $machineName Training Session';

    final intervals = machineType == DeviceType.indoorBike
        ? _createBikeTemplate(workoutDuration)
        : _createRowerTemplate(workoutDuration);

    return TrainingSessionDefinition(
      title: title,
      ftmsMachineType: machineType,
      intervals: intervals,
      isCustom: true,
    );
  }

  static List<TrainingInterval> _createBikeTemplate(int workoutDuration) {
    final workoutInterval = UnitTrainingInterval(
      title: 'Workout',
      duration: workoutDuration,
      targets: {},
    );
    return [workoutInterval];
  }

  static List<TrainingInterval> _createRowerTemplate(int workoutDuration) {
    final warmUpIntervals = List.generate(5, (i) => UnitTrainingInterval(
      title: 'Warm Up ${i + 1}',
      duration: 60,
      targets: {'Instantaneous Pace': '${84 + i * 3}%', 'Stroke Rate': 20},
      resistanceLevel: 20 + i * 10,
    ));

    final warmUpGroup = GroupTrainingInterval(intervals: warmUpIntervals, repeat: 1);

    final workoutInterval = UnitTrainingInterval(
      title: 'Workout',
      duration: workoutDuration,
      targets: {'Instantaneous Pace': '96%', 'Stroke Rate': 22},
      resistanceLevel: 60,
    );

    final coolDownIntervals = warmUpIntervals.reversed.toList().asMap().entries.map((entry) {
      final index = entry.key;
      final interval = entry.value;
      return UnitTrainingInterval(
        title: 'Cool down ${index + 1}',
        duration: interval.duration,
        targets: interval.targets,
        resistanceLevel: interval.resistanceLevel,
      );
    }).toList();
    final coolDownGroup = GroupTrainingInterval(intervals: coolDownIntervals, repeat: 1);

    return [warmUpGroup, workoutInterval, coolDownGroup];
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