import 'rower_workout_strategy.dart';
import 'package:ftms/l10n/app_localizations.dart';

enum RowerWorkoutType {
  BASE_ENDURANCE(RowerBaseEnduranceStrategy()),
  VO2_MAX(RowerVo2MaxStrategy()),
  SPRINT(RowerSprintStrategy()),
  TECHNIQUE(RowerTechniqueStrategy()),
  STRENGTH(RowerStrengthStrategy()),
  PYRAMID(RowerPyramidStrategy()),
  RACE_SIM(RowerRaceSimStrategy()),
  ;

  const RowerWorkoutType(this.strategy);

  final RowerWorkoutStrategy strategy;
}

extension RowerWorkoutTypeExtension on RowerWorkoutType {
  static String getLabel(RowerWorkoutType type, AppLocalizations localizations) {
    switch (type) {
      case RowerWorkoutType.BASE_ENDURANCE:
        return localizations.workoutTypeBaseEndurance;
      case RowerWorkoutType.VO2_MAX:
        return localizations.workoutTypeVo2Max;
      case RowerWorkoutType.SPRINT:
        return localizations.workoutTypeSprint;
      case RowerWorkoutType.TECHNIQUE:
        return localizations.workoutTypeTechnique;
      case RowerWorkoutType.STRENGTH:
        return localizations.workoutTypeStrength;
      case RowerWorkoutType.PYRAMID:
        return localizations.workoutTypePyramid;
      case RowerWorkoutType.RACE_SIM:
        return localizations.workoutTypeRaceSim;
    }
  }

  static RowerWorkoutStrategy getStrategy(String key) {
    return RowerWorkoutType.values.firstWhere((e) => e.name == key).strategy;
  }
}