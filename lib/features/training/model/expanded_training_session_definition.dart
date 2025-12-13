import 'package:ftms/core/models/device_types.dart';

import 'expanded_unit_training_interval.dart';

/// Expanded training session definition with ExpandedTrainingInterval list
class ExpandedTrainingSessionDefinition {
  final String title;
  final DeviceType ftmsMachineType;
  final List<ExpandedUnitTrainingInterval> intervals;
  final bool isCustom;
  final bool isDistanceBased;

  ExpandedTrainingSessionDefinition({
    required this.title,
    required this.ftmsMachineType,
    required this.intervals,
    this.isCustom = false,
    this.isDistanceBased = false,
  });

}
