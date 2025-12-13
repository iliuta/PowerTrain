import 'expanded_unit_training_interval.dart';
import 'package:ftms/core/models/device_types.dart';
import '../../settings/model/user_settings.dart';
import '../../../core/config/live_data_display_config.dart';

abstract class TrainingInterval {
  int? get repeat;

  List<ExpandedUnitTrainingInterval> expand({
    required DeviceType machineType,
    UserSettings? userSettings,
    LiveDataDisplayConfig? config,
    required bool isDistanceBased,
  });
  TrainingInterval copy();
  Map<String, dynamic> toJson();
}