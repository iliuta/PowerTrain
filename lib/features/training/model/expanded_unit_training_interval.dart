
import 'unit_training_interval.dart';

class ExpandedUnitTrainingInterval {
  final String? title;
  final int? duration;
  final int? distance;
  final Map<String, dynamic>? targets;
  final int? resistanceLevel;
  final UnitTrainingInterval originalInterval;

  ExpandedUnitTrainingInterval({
    this.title,
    this.duration,
    this.distance,
    this.targets,
    this.resistanceLevel,
    required this.originalInterval,
  });
}
