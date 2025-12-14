import 'package:flutter_test/flutter_test.dart';
import 'package:ftms/core/models/device_types.dart';
import 'package:ftms/features/settings/model/user_settings.dart';
import 'package:ftms/features/training/model/expanded_unit_training_interval.dart';
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

  group('GroupTrainingInterval', () {
    test('constructor creates instance with required fields', () {
      final unitInterval = UnitTrainingInterval(
        title: 'Test',
        duration: 60,
        targets: {'power': '100W'},
      );
      
      final groupInterval = GroupTrainingInterval(
        intervals: [unitInterval],
        repeat: 3,
      );
      
      expect(groupInterval.intervals, hasLength(1));
      expect(groupInterval.repeat, equals(3));
      expect(groupInterval.intervals.first, equals(unitInterval));
    });

    test('constructor creates instance with default repeat', () {
      final unitInterval = UnitTrainingInterval(
        title: 'Test',
        duration: 60,
      );
      
      final groupInterval = GroupTrainingInterval(
        intervals: [unitInterval],
      );
      
      expect(groupInterval.repeat, isNull);
    });

    test('fromJson creates instance from JSON', () {
      final json = {
        'repeat': 2,
        'intervals': [
          {
            'title': 'Test Interval',
            'duration': 60,
            'targets': {'Instantaneous Power': '120W'},
            'resistanceLevel': 5,
          }
        ],
      };
      
      final groupInterval = GroupTrainingInterval.fromJson(json);
      
      expect(groupInterval.repeat, equals(2));
      expect(groupInterval.intervals, hasLength(1));
      expect(groupInterval.intervals.first.title, equals('Test Interval'));
      expect(groupInterval.intervals.first.duration, equals(60));
      expect(groupInterval.intervals.first.targets!['Instantaneous Power'], equals('120W'));
      expect(groupInterval.intervals.first.resistanceLevel, equals(5));
    });

    test('toJson returns correct JSON representation', () {
      final unitInterval = UnitTrainingInterval(
        title: 'Test',
        duration: 60,
        targets: {'power': '100W'},
        resistanceLevel: 3,
      );
      
      final groupInterval = GroupTrainingInterval(
        intervals: [unitInterval],
        repeat: 2,
      );
      
      final json = groupInterval.toJson();
      
      expect(json['repeat'], equals(2));
      expect(json['intervals'], hasLength(1));
      expect(json['intervals'][0]['title'], equals('Test'));
      expect(json['intervals'][0]['duration'], equals(60));
      expect(json['intervals'][0]['targets']['power'], equals('100W'));
      expect(json['intervals'][0]['resistanceLevel'], equals(3));
    });

    test('expandTargets creates new instance with expanded targets', () {
      final userSettings = UserSettings(cyclingFtp: 250, rowingFtp: '2:00', developerMode: false);
      final config = createIndoorBikeConfig();
      
      final unitInterval = UnitTrainingInterval(
        title: 'Test',
        duration: 60,
        targets: {'Instantaneous Power': '120%'},
      );
      
      final groupInterval = GroupTrainingInterval(
        intervals: [unitInterval],
        repeat: 2,
      );
      
      final List<ExpandedUnitTrainingInterval> expanded = groupInterval.expand(
        machineType: DeviceType.indoorBike,
        userSettings: userSettings,
        config: config,
        isDistanceBased: false,
      );
      
      expect(expanded, hasLength(2));
      expect(expanded.first.targets!['Instantaneous Power'], equals(300)); // 120% of 250
      expect(expanded.first.originalInterval, equals(unitInterval));
      expect(expanded.last.originalInterval, equals(unitInterval));
    });

    test('expand returns flattened list of UnitTrainingInterval', () {
      final unitInterval1 = UnitTrainingInterval(
        title: 'Test1',
        duration: 30,
        repeat: 2,
      );
      
      final unitInterval2 = UnitTrainingInterval(
        title: 'Test2',
        duration: 45,
        repeat: 1,
      );
      
      final groupInterval = GroupTrainingInterval(
        intervals: [unitInterval1, unitInterval2],
        repeat: 3,
      );
      
      final expanded = groupInterval.expand(machineType: DeviceType.indoorBike, isDistanceBased: false);
      
      // Group repeats 3 times, unitInterval1 repeats 2 times each, unitInterval2 repeats 1 time each
      // Total: 3 * (2 + 1) = 9 intervals
      expect(expanded, hasLength(9));
      
      // Check the pattern: 2 x Test1, 1 x Test2, repeated 3 times
      expect(expanded[0].title, equals('Test1'));
      expect(expanded[1].title, equals('Test1'));
      expect(expanded[2].title, equals('Test2'));
      expect(expanded[3].title, equals('Test1'));
      expect(expanded[4].title, equals('Test1'));
      expect(expanded[5].title, equals('Test2'));
      expect(expanded[6].title, equals('Test1'));
      expect(expanded[7].title, equals('Test1'));
      expect(expanded[8].title, equals('Test2'));
      // Check original intervals
      for (int i = 0; i < 9; i++) {
        if (i % 3 == 0 || i % 3 == 1) {
          expect(expanded[i].originalInterval, equals(unitInterval1));
        } else {
          expect(expanded[i].originalInterval, equals(unitInterval2));
        }
      }
    });

    test('expand handles null repeat as 1', () {
      final unitInterval = UnitTrainingInterval(
        title: 'Test',
        duration: 60,
      );
      
      final groupInterval = GroupTrainingInterval(
        intervals: [unitInterval],
        repeat: null,
      );
      
      final expanded = groupInterval.expand(machineType: DeviceType.indoorBike, isDistanceBased: false);
      
      expect(expanded, hasLength(1));
      expect(expanded.first.title, equals('Test'));
      expect(expanded.first.originalInterval, equals(unitInterval));
    });

    test('expand handles zero repeat as 1', () {
      final unitInterval = UnitTrainingInterval(
        title: 'Test',
        duration: 60,
      );
      
      final groupInterval = GroupTrainingInterval(
        intervals: [unitInterval],
        repeat: 0,
      );
      
      final expanded = groupInterval.expand(machineType: DeviceType.indoorBike, isDistanceBased: false);
      
      expect(expanded, hasLength(1));
      expect(expanded.first.title, equals('Test'));
      expect(expanded.first.originalInterval, equals(unitInterval));
    });

    test('copy creates deep copy with same values', () {
      final unitInterval = UnitTrainingInterval(
        title: 'Test',
        duration: 60,
        targets: {'power': '100W'},
        resistanceLevel: 3,
      );
      
      final groupInterval = GroupTrainingInterval(
        intervals: [unitInterval],
        repeat: 2,
      );
      
      final copied = groupInterval.copy();
      
      expect(copied.repeat, equals(groupInterval.repeat));
      expect(copied.intervals, hasLength(groupInterval.intervals.length));
      expect(copied.intervals.first.title, equals(groupInterval.intervals.first.title));
      expect(copied.intervals.first.duration, equals(groupInterval.intervals.first.duration));
      expect(copied.intervals.first.targets!['power'], equals(groupInterval.intervals.first.targets!['power']));
      expect(copied.intervals.first.resistanceLevel, equals(groupInterval.intervals.first.resistanceLevel));
      
      // Verify it's a deep copy (different object references)
      expect(copied, isNot(same(groupInterval)));
      expect(copied.intervals, isNot(same(groupInterval.intervals)));
      expect(copied.intervals.first, isNot(same(groupInterval.intervals.first)));
      expect(copied.intervals.first.targets, isNot(same(groupInterval.intervals.first.targets)));
    });

    test('copy creates independent copy that can be modified', () {
      final unitInterval = UnitTrainingInterval(
        title: 'Original',
        duration: 60,
        targets: {'power': '100W'},
      );
      
      final groupInterval = GroupTrainingInterval(
        intervals: [unitInterval],
        repeat: 2,
      );
      
      final copied = groupInterval.copy();
      
      // Modify the original targets
      groupInterval.intervals.first.targets!['power'] = '200W';
      
      // The copy should remain unchanged
      expect(copied.intervals.first.targets!['power'], equals('100W'));
      expect(groupInterval.intervals.first.targets!['power'], equals('200W'));
    });

    test('copy handles empty intervals list', () {
      final groupInterval = GroupTrainingInterval(
        intervals: [],
        repeat: 1,
      );
      
      final copied = groupInterval.copy();
      
      expect(copied.intervals, isEmpty);
      expect(copied.repeat, equals(1));
    });

    test('copy handles null repeat', () {
      final unitInterval = UnitTrainingInterval(
        title: 'Test',
        duration: 60,
      );
      
      final groupInterval = GroupTrainingInterval(
        intervals: [unitInterval],
        repeat: null,
      );
      
      final copied = groupInterval.copy();
      
      expect(copied.repeat, isNull);
      expect(copied.intervals, hasLength(1));
    });
  });
}
