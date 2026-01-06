import 'rower_workout_strategy.dart';

enum RowerWorkoutType {
  BASE_ENDURANCE,
  VO2_MAX,
  SPRINT,
  TECHNIQUE,
  STRENGTH,
  PYRAMID,
  RACE_SIM,
}

extension RowerWorkoutTypeExtension on RowerWorkoutType {
  RowerWorkoutStrategy get strategy {
    switch (this) {
      case RowerWorkoutType.BASE_ENDURANCE:
        return RowerBaseEnduranceStrategy();
      case RowerWorkoutType.VO2_MAX:
        return RowerVo2MaxStrategy();
      case RowerWorkoutType.SPRINT:
        return RowerSprintStrategy();
      case RowerWorkoutType.TECHNIQUE:
        return RowerTechniqueStrategy();
      case RowerWorkoutType.STRENGTH:
        return RowerStrengthStrategy();
      case RowerWorkoutType.PYRAMID:
        return RowerPyramidStrategy();
      case RowerWorkoutType.RACE_SIM:
        return RowerRaceSimStrategy();
    }
  }
}