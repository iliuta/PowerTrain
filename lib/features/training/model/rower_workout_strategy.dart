import 'group_training_interval.dart';
import 'unit_training_interval.dart';

abstract class RowerWorkoutStrategy {
  List<GroupTrainingInterval> generateMainIntervals(int mainTime, [int? resistanceLevel]);
  int getCycleTime();
  bool handlesRemainderInternally();
}

Map<String, dynamic> _buildTargets(Map<String, dynamic> baseTargets, [int? resistanceLevel]) {
  final targets = Map<String, dynamic>.from(baseTargets);
  if (resistanceLevel != null) {
    targets['Resistance Level'] = resistanceLevel;
  }
  return targets;
}

class RowerBaseEnduranceStrategy implements RowerWorkoutStrategy {
  const RowerBaseEnduranceStrategy();
  @override
  List<GroupTrainingInterval> generateMainIntervals(int mainTime, [int? resistanceLevel]) {
    final cycleTime = 12;
    final numCycles = mainTime ~/ cycleTime;
    final remainder = mainTime % cycleTime;
    final set = <UnitTrainingInterval>[];
    set.add(UnitTrainingInterval(
      title: 'Steady State',
      duration: (10 + remainder) * 60,
      targets: _buildTargets({'Instantaneous Pace': '93%', 'Stroke Rate': 20}, resistanceLevel),
    ));
    if (numCycles > 1) {
      set.add(UnitTrainingInterval(
        title: 'Paddle',
        duration: 2 * 60,
        targets: _buildTargets({'Instantaneous Pace': '85%', 'Stroke Rate': 18}, resistanceLevel),
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
  const RowerVo2MaxStrategy();
  @override
  List<GroupTrainingInterval> generateMainIntervals(int mainTime, [int? resistanceLevel]) {
    final cycleTime = 5;
    final numCycles = mainTime ~/ cycleTime;
    return [GroupTrainingInterval(
      intervals: [
        UnitTrainingInterval(
          title: 'VO2 Interval',
          duration: 3 * 60,
          targets: _buildTargets({'Instantaneous Pace': '105%', 'Stroke Rate': 30}, resistanceLevel),
        ),
        UnitTrainingInterval(
          title: 'Rest',
          duration: 2 * 60,
          targets: _buildTargets({'Instantaneous Pace': '88%', 'Stroke Rate': 18}, resistanceLevel),
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
  const RowerSprintStrategy();
  @override
  List<GroupTrainingInterval> generateMainIntervals(int mainTime, [int? resistanceLevel]) {
    final cycleTime = 3;
    final numCycles = mainTime ~/ cycleTime;
    return [GroupTrainingInterval(
      intervals: [
        UnitTrainingInterval(
          title: 'Sprint',
          duration: 1 * 60,
          targets: _buildTargets({'Instantaneous Pace': '115%', 'Stroke Rate': 36}, resistanceLevel),
        ),
        UnitTrainingInterval(
          title: 'Rest',
          duration: 2 * 60,
          targets: _buildTargets({'Instantaneous Pace': '85%', 'Stroke Rate': 18}, resistanceLevel),
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
  const RowerTechniqueStrategy();
  @override
  List<GroupTrainingInterval> generateMainIntervals(int mainTime, [int? resistanceLevel]) {
    final numCycles = mainTime ~/ 4;
    return [GroupTrainingInterval(
      intervals: [
        UnitTrainingInterval(
          title: 'Focus: Catch',
          duration: 1 * 60,
          targets: _buildTargets({'Instantaneous Pace': '87%', 'Stroke Rate': 18}, resistanceLevel),
        ),
        UnitTrainingInterval(
          title: 'Focus: Finish',
          duration: 1 * 60,
          targets: _buildTargets({'Instantaneous Pace': '93%', 'Stroke Rate': 22}, resistanceLevel),
        ),
        UnitTrainingInterval(
          title: 'Focus: Flow',
          duration: 1 * 60,
          targets: _buildTargets({'Instantaneous Pace': '98%', 'Stroke Rate': 24}, resistanceLevel),
        ),
        UnitTrainingInterval(
          title: 'Recovery',
          duration: 1 * 60,
          targets: _buildTargets({'Instantaneous Pace': '85%', 'Stroke Rate': 18}, resistanceLevel),
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
  const RowerStrengthStrategy();
  @override
  List<GroupTrainingInterval> generateMainIntervals(int mainTime, [int? resistanceLevel]) {
    final cycleTime = 3;
    final numCycles = mainTime ~/ cycleTime;
    return [GroupTrainingInterval(
      intervals: [
        UnitTrainingInterval(
          title: 'Power Drive',
          duration: 2 * 60,
          targets: _buildTargets({'Instantaneous Pace': '100%', 'Stroke Rate': 16}, resistanceLevel),
        ),
        UnitTrainingInterval(
          title: 'Rest',
          duration: 1 * 60,
          targets: _buildTargets({'Instantaneous Pace': '85%', 'Stroke Rate': 18}, resistanceLevel),
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
  const RowerPyramidStrategy();
  @override
  List<GroupTrainingInterval> generateMainIntervals(int mainTime, [int? resistanceLevel]) {
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
            targets: _buildTargets({'Instantaneous Pace': '${93 + (time * 3)}%', 'Stroke Rate': 24 + time}, resistanceLevel),
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
              targets: _buildTargets({'Instantaneous Pace': '83%', 'Stroke Rate': 18}, resistanceLevel),
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
  const RowerRaceSimStrategy();
  @override
  List<GroupTrainingInterval> generateMainIntervals(int mainTime, [int? resistanceLevel]) {
    final q = mainTime ~/ 4;
    return [GroupTrainingInterval(
      intervals: [
        UnitTrainingInterval(
          title: 'Start/High 20',
          duration: q * 60,
          targets: _buildTargets({'Instantaneous Pace': '110%', 'Stroke Rate': 34}, resistanceLevel),
        ),
        UnitTrainingInterval(
          title: 'Settle/Rhythm',
          duration: q * 60,
          targets: _buildTargets({'Instantaneous Pace': '100%', 'Stroke Rate': 28}, resistanceLevel),
        ),
        UnitTrainingInterval(
          title: 'Third 500m',
          duration: q * 60,
          targets: _buildTargets({'Instantaneous Pace': '102%', 'Stroke Rate': 30}, resistanceLevel),
        ),
        UnitTrainingInterval(
          title: 'Sprint Finish',
          duration: q * 60,
          targets: _buildTargets({'Instantaneous Pace': '112%', 'Stroke Rate': 36}, resistanceLevel),
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