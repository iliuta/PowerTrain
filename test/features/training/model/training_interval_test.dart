import 'package:flutter_test/flutter_test.dart';
import 'package:ftms/core/models/device_types.dart';
import 'package:ftms/features/training/model/expanded_unit_training_interval.dart';
import 'package:ftms/features/training/model/unit_training_interval.dart';
import 'package:ftms/features/training/model/group_training_interval.dart';
import 'package:ftms/features/training/model/training_session.dart';

void main() {
  group('TrainingInterval Factory', () {
    test('creates UnitTrainingInterval from JSON without intervals key', () {
      final json = {
        'title': 'Test Interval',
        'duration': 60,
        'targets': {'Instantaneous Power': '120%'},
      };
      
      final interval = TrainingIntervalFactory.fromJsonPolymorphic(json);
      
      expect(interval, isA<UnitTrainingInterval>());
      expect(interval.repeat, isNull);
    });

    test('creates GroupTrainingInterval from JSON with intervals key', () {
      final json = {
        'repeat': 3,
        'intervals': [
          {
            'title': 'Test Interval',
            'duration': 60,
            'targets': {'Instantaneous Power': '120%'},
          }
        ],
      };
      
      final interval = TrainingIntervalFactory.fromJsonPolymorphic(json);
      
      expect(interval, isA<GroupTrainingInterval>());
      expect(interval.repeat, equals(3));
    });
  });

  group('TrainingInterval abstract methods', () {
    test('UnitTrainingInterval implements all abstract methods', () {
      final interval = UnitTrainingInterval(
        title: 'Test',
        duration: 60,
        targets: {'power': '100W'},
        repeat: 1,
      );
      
      expect(interval.repeat, equals(1));
      expect(interval.expand(machineType: DeviceType.indoorBike, isDistanceBased: false), isA<List<ExpandedUnitTrainingInterval>>());
      expect(interval.copy(), isA<UnitTrainingInterval>());
      expect(interval.toJson(), isA<Map<String, dynamic>>());
    });

    test('GroupTrainingInterval implements all abstract methods', () {
      final interval = GroupTrainingInterval(
        repeat: 2,
        intervals: [
          UnitTrainingInterval(
            title: 'Test',
            duration: 60,
            targets: {'power': '100W'},
          ),
        ],
      );
      
      expect(interval.repeat, equals(2));
      expect(interval.expand(machineType: DeviceType.indoorBike, isDistanceBased: false), isA<List<ExpandedUnitTrainingInterval>>());
      expect(interval.copy(), isA<GroupTrainingInterval>());
      expect(interval.toJson(), isA<Map<String, dynamic>>());
    });
  });
}
