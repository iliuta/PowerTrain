
/// Expanded training interval with same fields as UnitTrainingInterval
class ExpandedUnitTrainingInterval {
  final String? title;
  final int? duration;
  final int? distance;
  final Map<String, dynamic>? targets;
  final int? resistanceLevel;

  ExpandedUnitTrainingInterval({
    this.title,
    this.duration,
    this.distance,
    this.targets,
    this.resistanceLevel,
  });
}
