
import 'unit_training_interval.dart';

class ExpandedUnitTrainingInterval {
  final String? title;
  final int? duration;
  final int? distance;
  final Map<String, dynamic>? targets;
  final int? resistanceLevel;
  /// Whether the resistance level needs to be converted from the default offline range
  /// to the actual machine's range when running the session.
  final bool resistanceNeedsConversion;
  final UnitTrainingInterval originalInterval;

  ExpandedUnitTrainingInterval({
    this.title,
    this.duration,
    this.distance,
    this.targets,
    this.resistanceLevel,
    this.resistanceNeedsConversion = false,
    required this.originalInterval,
  });
}
