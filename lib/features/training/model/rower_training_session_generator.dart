import 'training_session.dart';
import 'rower_workout_type.dart';
import 'group_training_interval.dart';
import 'unit_training_interval.dart';
import '../../../core/models/device_types.dart';

class RowerTrainingSessionGenerator {
  static TrainingSessionDefinition generateTrainingSession(int totalMin, RowerWorkoutType type, [int? resistanceLevel]) {
    final groups = <GroupTrainingInterval>[];
    final mainTime = totalMin - 10; // Excluding 5m Warmup and 5m Cooldown

    // --- 1. FIXED WARMUP ---
    groups.add(GroupTrainingInterval(
      intervals: [
        UnitTrainingInterval(
          title: 'Warmup',
          duration: 5 * 60, // to seconds
          targets: _buildTargets({'Instantaneous Pace': '84%', 'Stroke Rate': 20}),
          resistanceLevel: resistanceLevel,
        )
      ],
      repeat: 1,
    ));

    // --- 2. MAIN SET LOGIC ---
    final strategy = type.strategy;
    final mainIntervals = strategy.generateMainIntervals(mainTime, resistanceLevel);
    groups.addAll(mainIntervals);
    if (!strategy.handlesRemainderInternally()) {
      final remainder = mainTime % strategy.getCycleTime();
      _handleRemainder(remainder, groups, resistanceLevel);
    }

    // --- 3. FIXED COOLDOWN ---
    groups.add(GroupTrainingInterval(
      intervals: [
        UnitTrainingInterval(
          title: 'Cooldown',
          duration: 5 * 60,
          targets: _buildTargets({'Instantaneous Pace': '84%', 'Stroke Rate': 18}),
          resistanceLevel: resistanceLevel,
        ),
      ],
      repeat: 1,
    ));

    return TrainingSessionDefinition(
      title: '${type.name} - ${totalMin}m',
      ftmsMachineType: DeviceType.rower,
      intervals: groups,
      isCustom: true,
      isDistanceBased: false,
    );
  }

  static Map<String, dynamic> _buildTargets(Map<String, dynamic> baseTargets) {
    final targets = Map<String, dynamic>.from(baseTargets);
    return targets;
  }

  static void _handleRemainder(int remainder, List<GroupTrainingInterval> groups, [int? resistanceLevel]) {
    if (remainder <= 0) return;
    groups.add(GroupTrainingInterval(
      intervals: [
        UnitTrainingInterval(
          title: 'Transition',
          duration: remainder * 60,
          targets: _buildTargets({'Instantaneous Pace': '87%', 'Stroke Rate': 18}),
          resistanceLevel: resistanceLevel,
        ),
      ],
      repeat: 1,
    ));
  }
}