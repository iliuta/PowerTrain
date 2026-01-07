import 'rower_workout_strategy.dart';

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
  static RowerWorkoutStrategy getStrategy(String key) {
    return RowerWorkoutType.values.firstWhere((e) => e.name == key).strategy;
  }
}