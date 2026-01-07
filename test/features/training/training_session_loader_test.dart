import 'package:flutter_test/flutter_test.dart';
import 'package:ftms/core/config/live_data_display_config.dart';
import 'package:ftms/core/config/live_data_field_config.dart';
import 'package:ftms/core/models/device_types.dart';
import 'package:ftms/features/settings/model/user_settings.dart';
import 'package:ftms/features/training/model/training_session.dart';

dynamic _enduranceRideJson = {
  "title": "Endurance Ride",
  "ftmsMachineType": "DeviceDataType.indoorBike",
  "intervals": [
    {
      "title": "Warm Up",
      "duration": 30,
      "targets": {"Instantaneous Power": 100, "Instantaneous Cadence": 80},
      "repeat": 10
    },
    {
      "title": "Main Set",
      "duration": 30,
      "targets": {"Instantaneous Power": 180, "Instantaneous Cadence": 90}
    },
    {
      "title": "Cool Down",
      "duration": 30,
      "targets": {"Instantaneous Power": 80, "Instantaneous Cadence": 70}
    }
  ]
};

// Helper function to create a mock config for testing
LiveDataDisplayConfig _createMockConfig() {
  return LiveDataDisplayConfig(
    deviceType: DeviceType.indoorBike,
    availableInDeveloperModeOnly: false,
    fields: [
      LiveDataFieldConfig(
        name: 'Instantaneous Power',
        label: 'Power',
        display: 'number',
        unit: 'W',
        userSetting: 'cyclingFtp', // Has user setting - should apply power strategy
      ),
      LiveDataFieldConfig(
        name: 'Instantaneous Pace',
        label: 'Pace',
        display: 'number',
        unit: '/500m',
        userSetting: 'rowingFtp', // Has user setting - should apply power strategy
      ),
      LiveDataFieldConfig(
        name: 'Instantaneous Cadence',
        label: 'Cadence',
        display: 'number',
        unit: 'rpm',
        userSetting: null, // No user setting - should not apply power strategy
      ),
      LiveDataFieldConfig(
        name: 'Heart Rate',
        label: 'Heart Rate',
        display: 'number',
        unit: 'bpm',
      ),
      LiveDataFieldConfig(
        name: 'Stroke Rate',
        label: 'Stroke Rate',
        display: 'number',
        unit: 'spm',
        userSetting: null, // No user setting - should not apply power strategy
      ),
    ],
  );
}

void main() {
  final userSettings = UserSettings(cyclingFtp: 250, rowingFtp: '2:00', developerMode: false, soundEnabled: true);
  final config = _createMockConfig();

  test('TrainingSession.fromJson expands intervals with repeat field', () {
    final session = TrainingSessionDefinition.fromJson(_enduranceRideJson)
        .expand(userSettings: userSettings, config: config);
    // Warm Up should be repeated 10 times, plus 2 more intervals
    expect(session.intervals.length, 12);
    for (int i = 0; i < 10; i++) {
      expect(session.intervals[i].title, 'Warm Up');
      expect(session.intervals[i].duration, 30);
      expect(session.intervals[i].targets, containsPair('Instantaneous Power', 100));
      expect(session.intervals[i].targets, containsPair('Instantaneous Cadence', 80));
    }
    expect(session.intervals[10].title, 'Main Set');
    expect(session.intervals[10].duration, 30);
    expect(session.intervals[10].targets, containsPair('Instantaneous Power', 180));
    expect(session.intervals[10].targets, containsPair('Instantaneous Cadence', 90));
    expect(session.intervals[11].title, 'Cool Down');
    expect(session.intervals[11].duration, 30);
    expect(session.intervals[11].targets, containsPair('Instantaneous Power', 80));
    expect(session.intervals[11].targets, containsPair('Instantaneous Cadence', 70));
  });

  test('TrainingSession.fromJson expands group intervals with repeat and nested units', () {
    final complexJson = {
      "title": "Complex Session",
      "ftmsMachineType": "DeviceType.rower",
      "intervals": [
        {
          "title": "Warm Up",
          "duration": 60,
          "targets": {"Stroke Rate": 22},
        },
        {
          "repeat": 2,
          "intervals": [
            {
              "title": "Work",
              "duration": 30,
              "targets": {"Stroke Rate": 28, "Heart Rate": 150}
            },
            {
              "title": "Rest",
              "duration": 15,
              "targets": {"Stroke Rate": 20, "Heart Rate": 120}
            }
          ]
        },
        {
          "title": "Cool Down",
          "duration": 45,
          "targets": {"Stroke Rate": 18}
        }
      ]
    };

    final session = TrainingSessionDefinition.fromJson(complexJson)
        .expand(userSettings: userSettings, config: config);
    // Should expand to: Warm Up, Work, Rest, Work, Rest, Cool Down
    expect(session.intervals.length, 6);
    expect(session.intervals[0].title, 'Warm Up');
    expect(session.intervals[0].duration, 60);
    expect(session.intervals[1].title, 'Work');
    expect(session.intervals[1].duration, 30);
    expect(session.intervals[1].targets, containsPair('Stroke Rate', 28));
    expect(session.intervals[1].targets, containsPair('Heart Rate', 150));
    expect(session.intervals[2].title, 'Rest');
    expect(session.intervals[2].duration, 15);
    expect(session.intervals[2].targets, containsPair('Stroke Rate', 20));
    expect(session.intervals[2].targets, containsPair('Heart Rate', 120));
    expect(session.intervals[3].title, 'Work');
    expect(session.intervals[3].duration, 30);
    expect(session.intervals[3].targets, containsPair('Stroke Rate', 28));
    expect(session.intervals[3].targets, containsPair('Heart Rate', 150));
    expect(session.intervals[4].title, 'Rest');
    expect(session.intervals[4].duration, 15);
    expect(session.intervals[4].targets, containsPair('Stroke Rate', 20));
    expect(session.intervals[4].targets, containsPair('Heart Rate', 120));
    expect(session.intervals[5].title, 'Cool Down');
    expect(session.intervals[5].duration, 45);
    expect(session.intervals[5].targets, containsPair('Stroke Rate', 18));
  });
}
