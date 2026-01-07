import 'package:flutter_test/flutter_test.dart';
import 'package:ftms/features/training/model/rower_workout_type.dart';
import 'package:ftms/features/training/model/rower_training_session_generator.dart';
import 'package:ftms/features/training/model/group_training_interval.dart';
import 'package:ftms/core/models/device_types.dart';

void main() {
  group('RowerTrainingSessionGenerator', () {
    test('generates BASE_ENDURANCE session correctly', () {
      final session = RowerTrainingSessionGenerator.generateTrainingSession(30, RowerWorkoutType.BASE_ENDURANCE);

      expect(session.title, 'BASE_ENDURANCE - 30m');
      expect(session.ftmsMachineType, DeviceType.rower);
      expect(session.isCustom, true);
      expect(session.isDistanceBased, false);
      expect(session.intervals.length, 3); // warmup, main, cooldown

      // Check warmup
      final warmup = session.intervals[0] as GroupTrainingInterval;
      expect(warmup.repeat, 1);
      expect(warmup.intervals.length, 1);
      expect((warmup.intervals[0]).title, 'Warmup');
      expect((warmup.intervals[0]).duration, 300); // 5*60

      // Check main set
      final mainSet = session.intervals[1] as GroupTrainingInterval;
      expect(mainSet.repeat, 1); // 20/12 = 1
      expect(mainSet.intervals.length, 1); // only steady state, since numCycles=1
      expect((mainSet.intervals[0]).title, 'Steady State');
      expect((mainSet.intervals[0]).duration, 1080); // (10+8)*60

      // Check cooldown
      final cooldown = session.intervals[2] as GroupTrainingInterval;
      expect(cooldown.repeat, 1);
      expect((cooldown.intervals[0]).title, 'Cooldown');
    });

    test('generates VO2_MAX session with remainder', () {
      final session = RowerTrainingSessionGenerator.generateTrainingSession(25, RowerWorkoutType.VO2_MAX);

      expect(session.intervals.length, 3); // warmup, main, cooldown

      final mainSet = session.intervals[1] as GroupTrainingInterval;
      expect(mainSet.repeat, 3); // 15/5 = 3
    });

    test('generates SPRINT session', () {
      final session = RowerTrainingSessionGenerator.generateTrainingSession(20, RowerWorkoutType.SPRINT);

      final mainSet = session.intervals[1] as GroupTrainingInterval;
      expect(mainSet.repeat, 3); // 10/3 = 3
      expect(mainSet.intervals.length, 2);
      expect((mainSet.intervals[0]).title, 'Sprint');
      expect((mainSet.intervals[1]).title, 'Rest');
    });

    test('generates TECHNIQUE session', () {
      final session = RowerTrainingSessionGenerator.generateTrainingSession(20, RowerWorkoutType.TECHNIQUE);

      final mainSet = session.intervals[1] as GroupTrainingInterval;
      expect(mainSet.repeat, 2); // 10/4 = 2
      expect(mainSet.intervals.length, 4);
      expect((mainSet.intervals[0]).title, 'Focus: Catch');
      expect((mainSet.intervals[3]).title, 'Recovery');
    });

    test('generates STRENGTH session', () {
      final session = RowerTrainingSessionGenerator.generateTrainingSession(20, RowerWorkoutType.STRENGTH);

      final mainSet = session.intervals[1] as GroupTrainingInterval;
      expect(mainSet.repeat, 3); // 10/3 = 3
      expect((mainSet.intervals[0]).title, 'Power Drive');
    });

    test('generates PYRAMID session', () {
      final session = RowerTrainingSessionGenerator.generateTrainingSession(30, RowerWorkoutType.PYRAMID);

      expect(session.intervals.length, 11); // warmup + 5 work + 4 rest + cooldown

      // Check pyramid steps
      expect((session.intervals[1] as GroupTrainingInterval).intervals[0].title, 'Pyramid Step');
      expect(((session.intervals[1] as GroupTrainingInterval).intervals[0]).duration, 60); // 1*60
      expect(((session.intervals[1] as GroupTrainingInterval).intervals[0]).targets!['Stroke Rate'], 25); // 24+1

      expect((session.intervals[3] as GroupTrainingInterval).intervals[0].title, 'Pyramid Step');
      expect(((session.intervals[3] as GroupTrainingInterval).intervals[0]).duration, 120); // 2*60
    });

    test('generates RACE_SIM session', () {
      final session = RowerTrainingSessionGenerator.generateTrainingSession(20, RowerWorkoutType.RACE_SIM);

      final mainSet = session.intervals[1] as GroupTrainingInterval;
      expect(mainSet.repeat, 1);
      expect(mainSet.intervals.length, 4);
      expect((mainSet.intervals[0]).title, 'Start/High 20');
      expect((mainSet.intervals[0]).duration, 120); // 2*60

      // mainTime=10, q=10~/4=2, duration=2*60=120
    });

    test('handles remainder correctly for VO2_MAX', () {
      final session = RowerTrainingSessionGenerator.generateTrainingSession(27, RowerWorkoutType.VO2_MAX); // 17 main, 17/5=3*5=15, remainder=2

      expect(session.intervals.length, 4); // warmup, main, remainder, cooldown

      final remainder = session.intervals[2] as GroupTrainingInterval;
      expect((remainder.intervals[0]).duration, 120); // 2*60
    });

    test('includes resistance level in all intervals when provided', () {
      const resistanceLevel = 5;
      final session = RowerTrainingSessionGenerator.generateTrainingSession(30, RowerWorkoutType.BASE_ENDURANCE, resistanceLevel);

      expect(session.title, 'BASE_ENDURANCE - 30m');
      expect(session.intervals.length, 3); // warmup, main, cooldown

      // Check warmup includes resistance level
      final warmup = session.intervals[0] as GroupTrainingInterval;
      expect(warmup.intervals[0].targets?['Resistance Level'], resistanceLevel);

      // Check main intervals include resistance level
      final mainSet = session.intervals[1] as GroupTrainingInterval;
      for (final interval in mainSet.intervals) {
        expect(interval.targets?['Resistance Level'], resistanceLevel);
      }

      // Check cooldown includes resistance level
      final cooldown = session.intervals[2] as GroupTrainingInterval;
      expect(cooldown.intervals[0].targets?['Resistance Level'], resistanceLevel);
    });

    test('does not include resistance level when not provided', () {
      final session = RowerTrainingSessionGenerator.generateTrainingSession(30, RowerWorkoutType.BASE_ENDURANCE);

      // Check warmup does not include resistance level
      final warmup = session.intervals[0] as GroupTrainingInterval;
      expect(warmup.intervals[0].targets?.containsKey('Resistance Level'), false);

      // Check main intervals do not include resistance level
      final mainSet = session.intervals[1] as GroupTrainingInterval;
      for (final interval in mainSet.intervals) {
        expect(interval.targets?.containsKey('Resistance Level'), false);
      }

      // Check cooldown does not include resistance level
      final cooldown = session.intervals[2] as GroupTrainingInterval;
      expect(cooldown.intervals[0].targets?.containsKey('Resistance Level'), false);
    });
  });
}