import 'package:flutter_test/flutter_test.dart';
import 'package:ftms/core/models/device_types.dart';
import 'package:ftms/features/settings/model/user_settings.dart';
import 'package:ftms/features/training/model/training_session.dart';
import 'package:ftms/features/training/model/unit_training_interval.dart';
import 'package:ftms/features/training/model/group_training_interval.dart';
import 'package:ftms/core/config/live_data_display_config.dart';
import 'package:ftms/core/config/live_data_field_config.dart';

void main() {
  // Helper method to create a mock indoor bike config
  LiveDataDisplayConfig createIndoorBikeConfig() {
    return LiveDataDisplayConfig(
      deviceType: DeviceType.indoorBike,
      availableInDeveloperModeOnly: false,
      fields: [
        LiveDataFieldConfig(
          name: 'Instantaneous Power',
          label: 'Power',
          display: 'number',
          unit: 'W',
          userSetting: 'cyclingFtp',
        ),
        LiveDataFieldConfig(
          name: 'Instantaneous Cadence',
          label: 'Cadence',
          display: 'number',
          unit: 'rpm',
        ),
      ],
    );
  }

  group('TrainingSessionDefinition', () {
    test('constructor creates instance with required fields', () {
      final unitInterval = UnitTrainingInterval(
        title: 'Test Interval',
        duration: 60,
        targets: {'power': '100W'},
      );
      
      final session = TrainingSessionDefinition(
        title: 'Test Session',
        ftmsMachineType: DeviceType.indoorBike,
        intervals: [unitInterval],
      );
      
      expect(session.title, equals('Test Session'));
      expect(session.ftmsMachineType, equals(DeviceType.indoorBike));
      expect(session.intervals, hasLength(1));
      expect(session.isCustom, isFalse);
      expect(session.originalSession, isNull);
    });

    test('constructor creates instance with optional fields', () {
      final unitInterval = UnitTrainingInterval(
        title: 'Test Interval',
        duration: 60,
      );
      
      final originalSession = TrainingSessionDefinition(
        title: 'Original',
        ftmsMachineType: DeviceType.indoorBike,
        intervals: [unitInterval],
      );
      
      final session = TrainingSessionDefinition(
        title: 'Test Session',
        ftmsMachineType: DeviceType.indoorBike,
        intervals: [unitInterval],
        isCustom: true,
        originalSession: originalSession,
      );
      
      expect(session.isCustom, isTrue);
      expect(session.originalSession, equals(originalSession));
    });

    test('fromJson creates instance from JSON', () {
      final json = {
        'title': 'Test Session',
        'ftmsMachineType': 'indoorBike',
        'intervals': [
          {
            'title': 'Test Interval',
            'duration': 60,
            'targets': {'Instantaneous Power': '120W'},
          }
        ],
      };
      
      final session = TrainingSessionDefinition.fromJson(json);
      
      expect(session.title, equals('Test Session'));
      expect(session.ftmsMachineType, equals(DeviceType.indoorBike));
      expect(session.intervals, hasLength(1));
      expect(session.intervals.first, isA<UnitTrainingInterval>());
      expect(session.isCustom, isFalse);
    });

    test('fromJson creates instance with custom flag', () {
      final json = {
        'title': 'Custom Session',
        'ftmsMachineType': 'rower',
        'intervals': [
          {
            'title': 'Test Interval',
            'duration': 60,
          }
        ],
      };
      
      final session = TrainingSessionDefinition.fromJson(json, isCustom: true);
      
      expect(session.title, equals('Custom Session'));
      expect(session.ftmsMachineType, equals(DeviceType.rower));
      expect(session.isCustom, isTrue);
    });

    test('fromJson handles GroupTrainingInterval', () {
      final json = {
        'title': 'Group Session',
        'ftmsMachineType': 'indoorBike',
        'intervals': [
          {
            'repeat': 3,
            'intervals': [
              {
                'title': 'Test Interval',
                'duration': 60,
                'targets': {'power': '100W'},
              }
            ],
          }
        ],
      };
      
      final session = TrainingSessionDefinition.fromJson(json);
      
      expect(session.intervals, hasLength(1));
      expect(session.intervals.first, isA<GroupTrainingInterval>());
      final groupInterval = session.intervals.first as GroupTrainingInterval;
      expect(groupInterval.repeat, equals(3));
      expect(groupInterval.intervals, hasLength(1));
    });

    test('toJson returns correct JSON representation', () {
      final unitInterval = UnitTrainingInterval(
        title: 'Test Interval',
        duration: 60,
        targets: {'power': '100W'},
      );
      
      final session = TrainingSessionDefinition(
        title: 'Test Session',
        ftmsMachineType: DeviceType.indoorBike,
        intervals: [unitInterval],
      );
      
      final json = session.toJson();
      
      expect(json['title'], equals('Test Session'));
      expect(json['ftmsMachineType'], equals('indoorBike'));
      expect(json['intervals'], hasLength(1));
      expect(json['intervals'][0]['title'], equals('Test Interval'));
      expect(json['intervals'][0]['duration'], equals(60));
      expect(json['intervals'][0]['targets']['power'], equals('100W'));
    });

    test('expand creates new instance with expanded intervals', () {
      final userSettings = UserSettings(cyclingFtp: 250, rowingFtp: '2:00', developerMode: false);
      final config = createIndoorBikeConfig();
      
      final unitInterval = UnitTrainingInterval(
        title: 'Test Interval',
        duration: 60,
        targets: {'Instantaneous Power': '120%'},
        repeat: 2,
      );
      
      final session = TrainingSessionDefinition(
        title: 'Test Session',
        ftmsMachineType: DeviceType.indoorBike,
        intervals: [unitInterval],
        isCustom: true,
      );
      
      final expanded = session.expand(
        userSettings: userSettings,
        config: config,
      );
      
      expect(expanded.title, equals('Test Session'));
      expect(expanded.ftmsMachineType, equals(DeviceType.indoorBike));
      expect(expanded.isCustom, isTrue);

      // Should have 2 expanded intervals (repeat: 2)
      expect(expanded.intervals, hasLength(2));
      expect(expanded.intervals.first.targets!['Instantaneous Power'], equals(300)); // 120% of 250
      expect(expanded.intervals.first.originalInterval, equals(unitInterval));
      expect(expanded.intervals.last.originalInterval, equals(unitInterval));
    });

    test('expand handles GroupTrainingInterval', () {
      final userSettings = UserSettings(cyclingFtp: 250, rowingFtp: '2:00', developerMode: false);
      final config = createIndoorBikeConfig();
      
      final unitInterval = UnitTrainingInterval(
        title: 'Test Interval',
        duration: 60,
        targets: {'Instantaneous Power': '120%'},
      );
      
      final groupInterval = GroupTrainingInterval(
        intervals: [unitInterval],
        repeat: 3,
      );
      
      final session = TrainingSessionDefinition(
        title: 'Test Session',
        ftmsMachineType: DeviceType.indoorBike,
        intervals: [groupInterval],
      );
      
      final expanded = session.expand(
        userSettings: userSettings,
        config: config,
      );
      
      // Should have 3 expanded intervals (group repeat: 3)
      expect(expanded.intervals, hasLength(3));
      expect(expanded.intervals.first.targets!['Instantaneous Power'], equals(300)); // 120% of 250
      for (final interval in expanded.intervals) {
        expect(interval.originalInterval, equals(unitInterval));
      }
    });

    test('unitIntervals returns intervals cast to UnitTrainingInterval', () {
      final unitInterval1 = UnitTrainingInterval(
        title: 'Test 1',
        duration: 60,
      );
      
      final unitInterval2 = UnitTrainingInterval(
        title: 'Test 2',
        duration: 90,
      );
      
      final userSettings = UserSettings(cyclingFtp: 250, rowingFtp: '2:00', developerMode: false);
      
      // Create a session and expand it to get UnitTrainingInterval list
      final session = TrainingSessionDefinition(
        title: 'Test Session',
        ftmsMachineType: DeviceType.indoorBike,
        intervals: [unitInterval1, unitInterval2],
      );
      
      final expandedSession = session.expand(userSettings: userSettings);
      final intervals = expandedSession.intervals;
      
      expect(intervals, hasLength(2));
      expect(intervals[0].title, equals('Test 1'));
      expect(intervals[1].title, equals('Test 2'));
      expect(intervals[0].originalInterval, equals(unitInterval1));
      expect(intervals[1].originalInterval, equals(unitInterval2));
    });

    test('copy creates deep copy with same values', () {
      final unitInterval = UnitTrainingInterval(
        title: 'Test Interval',
        duration: 60,
        targets: {'power': '100W'},
      );

      
      final session = TrainingSessionDefinition(
        title: 'Test Session',
        ftmsMachineType: DeviceType.indoorBike,
        intervals: [unitInterval],
        isCustom: true,
      );
      
      final copied = session.copy();
      
      expect(copied.title, equals(session.title));
      expect(copied.ftmsMachineType, equals(session.ftmsMachineType));
      expect(copied.isCustom, equals(session.isCustom));
      expect(copied.intervals, hasLength(session.intervals.length));
      expect((copied.intervals.first as UnitTrainingInterval).title, equals((session.intervals.first as UnitTrainingInterval).title));

      // Verify it's a deep copy (different object references)
      expect(copied, isNot(same(session)));
      expect(copied.intervals, isNot(same(session.intervals)));
      expect(copied.intervals.first, isNot(same(session.intervals.first)));
    });

    test('copy creates independent copy that can be modified', () {
      final unitInterval = UnitTrainingInterval(
        title: 'Original Interval',
        duration: 60,
        targets: {'power': '100W'},
      );
      
      final session = TrainingSessionDefinition(
        title: 'Original Session',
        ftmsMachineType: DeviceType.indoorBike,
        intervals: [unitInterval],
      );
      
      final copied = session.copy();
      
      // Modify the original interval targets
      (session.intervals.first as UnitTrainingInterval).targets!['power'] = '200W';
      
      // The copy should remain unchanged
      expect((copied.intervals.first as UnitTrainingInterval).targets!['power'], equals('100W'));
      expect((session.intervals.first as UnitTrainingInterval).targets!['power'], equals('200W'));
    });

    test('copy handles null originalSession', () {
      final unitInterval = UnitTrainingInterval(
        title: 'Test Interval',
        duration: 60,
      );
      
      final session = TrainingSessionDefinition(
        title: 'Test Session',
        ftmsMachineType: DeviceType.indoorBike,
        intervals: [unitInterval],
        originalSession: null,
      );
      
      final copied = session.copy();
      
      expect(copied.originalSession, isNull);
      expect(copied.title, equals('Test Session'));
      expect(copied.intervals, hasLength(1));
    });

    test('copy handles empty intervals list', () {
      final session = TrainingSessionDefinition(
        title: 'Empty Session',
        ftmsMachineType: DeviceType.indoorBike,
        intervals: [],
      );
      
      final copied = session.copy();
      
      expect(copied.intervals, isEmpty);
      expect(copied.title, equals('Empty Session'));
      expect(copied.ftmsMachineType, equals(DeviceType.indoorBike));
    });

    test('copy handles mixed interval types', () {
      final unitInterval = UnitTrainingInterval(
        title: 'Unit',
        duration: 60,
        targets: {'power': '100W'},
      );
      
      final groupInterval = GroupTrainingInterval(
        intervals: [unitInterval],
        repeat: 2,
      );
      
      final session = TrainingSessionDefinition(
        title: 'Mixed Session',
        ftmsMachineType: DeviceType.indoorBike,
        intervals: [unitInterval, groupInterval],
      );
      
      final copied = session.copy();
      
      expect(copied.intervals, hasLength(2));
      expect(copied.intervals[0], isA<UnitTrainingInterval>());
      expect(copied.intervals[1], isA<GroupTrainingInterval>());
      
      // Verify deep copy
      expect(copied.intervals[0], isNot(same(session.intervals[0])));
      expect(copied.intervals[1], isNot(same(session.intervals[1])));
    });

    test('createTemplate creates bike template with correct structure', () {
      final session = TrainingSessionDefinition.createTemplate(DeviceType.indoorBike, workoutValue: 600);

      expect(session.title, equals('New Cycling Time Training Session'));
      expect(session.ftmsMachineType, equals(DeviceType.indoorBike));
      expect(session.isCustom, isTrue);
      expect(session.intervals, hasLength(1));

      final workoutInterval = session.intervals.first as UnitTrainingInterval;
      expect(workoutInterval.title, equals('Workout'));
      expect(workoutInterval.duration, equals(600));
      expect(workoutInterval.targets, isEmpty);
      expect(workoutInterval.resistanceLevel, isNull);
    });

    test('createTemplate creates rower template with correct structure', () {
      final session = TrainingSessionDefinition.createTemplate(DeviceType.rower, workoutValue: 600);

      expect(session.title, equals('New Rowing Time Training Session'));
      expect(session.ftmsMachineType, equals(DeviceType.rower));
      expect(session.isCustom, isTrue);
      expect(session.intervals, hasLength(3));

      // Warm up group
      final warmUpGroup = session.intervals[0] as GroupTrainingInterval;
      expect(warmUpGroup.repeat, equals(1));
      expect(warmUpGroup.intervals, hasLength(5));
      for (int i = 0; i < 5; i++) {
        final interval = warmUpGroup.intervals[i];
        expect(interval.title, equals('Warm Up ${i + 1}'));
        expect(interval.duration, equals(60));
        expect(interval.targets!['Instantaneous Pace'], equals('${84 + i * 3}%'));
        expect(interval.targets!['Stroke Rate'], equals(20));
        expect(interval.resistanceLevel, equals(20 + i * 10));
      }

      // Workout interval
      final workoutInterval = session.intervals[1] as UnitTrainingInterval;
      expect(workoutInterval.title, equals('Workout'));
      expect(workoutInterval.duration, equals(0));
      expect(workoutInterval.targets!['Instantaneous Pace'], equals('96%'));
      expect(workoutInterval.targets!['Stroke Rate'], equals(22));
      expect(workoutInterval.resistanceLevel, equals(60));

      // Cool down group
      final coolDownGroup = session.intervals[2] as GroupTrainingInterval;
      expect(coolDownGroup.repeat, equals(1));
      expect(coolDownGroup.intervals, hasLength(5));
      final expectedCoolDownPowers = ['96%', '93%', '90%', '87%', '84%'];
      for (int i = 0; i < 5; i++) {
        final interval = coolDownGroup.intervals[i];
        expect(interval.title, equals('Cool down ${i + 1}'));
        expect(interval.duration, equals(60));
        expect(interval.targets!['Instantaneous Pace'], equals(expectedCoolDownPowers[i]));
        expect(interval.targets!['Stroke Rate'], equals(20));
        expect(interval.resistanceLevel, equals(60 - i * 10));
      }
    });
  });
}
