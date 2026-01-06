import 'group_training_interval.dart';
import 'unit_training_interval.dart';

abstract class RowerWorkoutStrategy {
  List<GroupTrainingInterval> generateMainIntervals(int mainTime);
  int getCycleTime();
  bool handlesRemainderInternally();
}

class RowerBaseEnduranceStrategy implements RowerWorkoutStrategy {
  @override
  List<GroupTrainingInterval> generateMainIntervals(int mainTime) {
    final cycleTime = 12;
    final numCycles = mainTime ~/ cycleTime;
    final remainder = mainTime % cycleTime;
    final set = <UnitTrainingInterval>[];
    set.add(UnitTrainingInterval(
      title: 'Steady State',
      duration: (10 + remainder) * 60,
      targets: {'Instantaneous Pace': '85%', 'Stroke Rate': 20},
    ));
    if (numCycles > 1) {
      set.add(UnitTrainingInterval(
        title: 'Paddle',
        duration: 2 * 60,
        targets: {'Instantaneous Pace': '70%', 'Stroke Rate': 18},
      ));
    }
    return [GroupTrainingInterval(intervals: set, repeat: numCycles)];
  }

  @override
  int getCycleTime() => 12;

  @override
  bool handlesRemainderInternally() => true;
}

class RowerVo2MaxStrategy implements RowerWorkoutStrategy {
  @override
  List<GroupTrainingInterval> generateMainIntervals(int mainTime) {
    final cycleTime = 5;
    final numCycles = mainTime ~/ cycleTime;
    return [GroupTrainingInterval(
      intervals: [
        UnitTrainingInterval(
          title: 'VO2 Interval',
          duration: 3 * 60,
          targets: {'Instantaneous Pace': '105%', 'Stroke Rate': 30},
        ),
        UnitTrainingInterval(
          title: 'Rest',
          duration: 2 * 60,
          targets: {'Instantaneous Pace': '70%', 'Stroke Rate': 18},
        ),
      ],
      repeat: numCycles,
    )];
  }

  @override
  int getCycleTime() => 5;

  @override
  bool handlesRemainderInternally() => false;
}

class RowerSprintStrategy implements RowerWorkoutStrategy {
  @override
  List<GroupTrainingInterval> generateMainIntervals(int mainTime) {
    final cycleTime = 3;
    final numCycles = mainTime ~/ cycleTime;
    return [GroupTrainingInterval(
      intervals: [
        UnitTrainingInterval(
          title: 'Sprint',
          duration: 1 * 60,
          targets: {'Instantaneous Pace': '115%', 'Stroke Rate': 36},
        ),
        UnitTrainingInterval(
          title: 'Rest',
          duration: 2 * 60,
          targets: {'Instantaneous Pace': '65%', 'Stroke Rate': 18},
        ),
      ],
      repeat: numCycles,
    )];
  }

  @override
  int getCycleTime() => 3;

  @override
  bool handlesRemainderInternally() => false;
}

class RowerTechniqueStrategy implements RowerWorkoutStrategy {
  @override
  List<GroupTrainingInterval> generateMainIntervals(int mainTime) {
    final numCycles = mainTime ~/ 4;
    return [GroupTrainingInterval(
      intervals: [
        UnitTrainingInterval(
          title: 'Focus: Catch',
          duration: 1 * 60,
          targets: {'Instantaneous Pace': '80%', 'Stroke Rate': 18},
        ),
        UnitTrainingInterval(
          title: 'Focus: Finish',
          duration: 1 * 60,
          targets: {'Instantaneous Pace': '85%', 'Stroke Rate': 22},
        ),
        UnitTrainingInterval(
          title: 'Focus: Flow',
          duration: 1 * 60,
          targets: {'Instantaneous Pace': '90%', 'Stroke Rate': 24},
        ),
        UnitTrainingInterval(
          title: 'Recovery',
          duration: 1 * 60,
          targets: {'Instantaneous Pace': '70%', 'Stroke Rate': 18},
        ),
      ],
      repeat: numCycles,
    )];
  }

  @override
  int getCycleTime() => 4;

  @override
  bool handlesRemainderInternally() => false;
}

class RowerStrengthStrategy implements RowerWorkoutStrategy {
  @override
  List<GroupTrainingInterval> generateMainIntervals(int mainTime) {
    final cycleTime = 3;
    final numCycles = mainTime ~/ cycleTime;
    return [GroupTrainingInterval(
      intervals: [
        UnitTrainingInterval(
          title: 'Power Drive',
          duration: 2 * 60,
          targets: {'Instantaneous Pace': '100%', 'Stroke Rate': 16},
        ),
        UnitTrainingInterval(
          title: 'Rest',
          duration: 1 * 60,
          targets: {'Instantaneous Pace': '70%', 'Stroke Rate': 18},
        ),
      ],
      repeat: numCycles,
    )];
  }

  @override
  int getCycleTime() => 3;

  @override
  bool handlesRemainderInternally() => false;
}

class RowerPyramidStrategy implements RowerWorkoutStrategy {
  @override
  List<GroupTrainingInterval> generateMainIntervals(int mainTime) {
    final workTimes = [1, 2, 3, 2, 1];
    final totalWork = 9;
    final restTime = (mainTime - totalWork) ~/ 4;
    final groups = <GroupTrainingInterval>[];
    for (int i = 0; i < workTimes.length; i++) {
      final time = workTimes[i];
      groups.add(GroupTrainingInterval(
        intervals: [
          UnitTrainingInterval(
            title: 'Pyramid Step',
            duration: time * 60,
            targets: {'Instantaneous Pace': '${90 + (time * 3)}%', 'Stroke Rate': 24 + time},
          ),
        ],
        repeat: 1,
      ));
      if (i < workTimes.length - 1) {
        groups.add(GroupTrainingInterval(
          intervals: [
            UnitTrainingInterval(
              title: 'Rest',
              duration: restTime * 60,
              targets: {'Instantaneous Pace': '70%', 'Stroke Rate': 18},
            ),
          ],
          repeat: 1,
        ));
      }
    }
    return groups;
  }

  @override
  int getCycleTime() => 0; // Not used

  @override
  bool handlesRemainderInternally() => true;
}

class RowerRaceSimStrategy implements RowerWorkoutStrategy {
  @override
  List<GroupTrainingInterval> generateMainIntervals(int mainTime) {
    final q = mainTime ~/ 4;
    return [GroupTrainingInterval(
      intervals: [
        UnitTrainingInterval(
          title: 'Start/High 20',
          duration: q * 60,
          targets: {'Instantaneous Pace': '110%', 'Stroke Rate': 34},
        ),
        UnitTrainingInterval(
          title: 'Settle/Rhythm',
          duration: q * 60,
          targets: {'Instantaneous Pace': '100%', 'Stroke Rate': 28},
        ),
        UnitTrainingInterval(
          title: 'Third 500m',
          duration: q * 60,
          targets: {'Instantaneous Pace': '102%', 'Stroke Rate': 30},
        ),
        UnitTrainingInterval(
          title: 'Sprint Finish',
          duration: q * 60,
          targets: {'Instantaneous Pace': '112%', 'Stroke Rate': 36},
        ),
      ],
      repeat: 1,
    )];
  }

  @override
  int getCycleTime() => 0; // Not used

  @override
  bool handlesRemainderInternally() => true;
}