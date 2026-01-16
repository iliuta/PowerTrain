import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ftms/core/models/device_types.dart';
import 'package:ftms/core/services/training_session_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('TrainingSessionPreferencesService', () {
    setUp(() {
      // Reset SharedPreferences mock before each test
      SharedPreferences.setMockInitialValues({});
    });

    group('saveFreeRidePreferences', () {
      test('saves free ride preferences for rower', () async {
        final prefs = TrainingSessionPreferences(
          deviceType: DeviceType.rower,
          targets: {'Power': '80%', 'Cadence': 24},
          resistanceLevel: 5,
        );

        await TrainingSessionPreferencesService.saveFreeRidePreferences(
          DeviceType.rower,
          prefs,
        );

        final sharedPrefs = await SharedPreferences.getInstance();
        final saved = sharedPrefs.getString('training_session_free_ride_rower');
        expect(saved, isNotNull);

        final decoded = jsonDecode(saved!) as Map<String, dynamic>;
        expect(decoded['targets']['Power'], equals('80%'));
        expect(decoded['targets']['Cadence'], equals(24));
        expect(decoded['resistanceLevel'], equals(5));
      });

      test('saves free ride preferences for indoor bike', () async {
        final prefs = TrainingSessionPreferences(
          deviceType: DeviceType.indoorBike,
          targets: {'Power': '75%'},
          resistanceLevel: 8,
        );

        await TrainingSessionPreferencesService.saveFreeRidePreferences(
          DeviceType.indoorBike,
          prefs,
        );

        final sharedPrefs = await SharedPreferences.getInstance();
        final saved = sharedPrefs.getString('training_session_free_ride_indoorBike');
        expect(saved, isNotNull);

        final decoded = jsonDecode(saved!) as Map<String, dynamic>;
        expect(decoded['targets']['Power'], equals('75%'));
        expect(decoded['resistanceLevel'], equals(8));
      });

      test('saves preferences with null resistance level', () async {
        final prefs = TrainingSessionPreferences(
          deviceType: DeviceType.rower,
          targets: {'Power': '80%'},
          resistanceLevel: null,
        );

        await TrainingSessionPreferencesService.saveFreeRidePreferences(
          DeviceType.rower,
          prefs,
        );

        final sharedPrefs = await SharedPreferences.getInstance();
        final saved = sharedPrefs.getString('training_session_free_ride_rower');
        expect(saved, isNotNull);

        final decoded = jsonDecode(saved!) as Map<String, dynamic>;
        expect(decoded['resistanceLevel'], isNull);
      });

      test('saves preferences with empty targets', () async {
        final prefs = TrainingSessionPreferences(
          deviceType: DeviceType.rower,
          targets: {},
          resistanceLevel: 5,
        );

        await TrainingSessionPreferencesService.saveFreeRidePreferences(
          DeviceType.rower,
          prefs,
        );

        final sharedPrefs = await SharedPreferences.getInstance();
        final saved = sharedPrefs.getString('training_session_free_ride_rower');
        expect(saved, isNotNull);

        final decoded = jsonDecode(saved!) as Map<String, dynamic>;
        expect(decoded['targets'], isEmpty);
        expect(decoded['resistanceLevel'], equals(5));
      });
    });

    group('loadFreeRidePreferences', () {
      test('loads free ride preferences for rower', () async {
        final prefsJson = jsonEncode({
          'deviceType': 'rower',
          'targets': {'Power': '80%', 'Cadence': 24},
          'resistanceLevel': 5,
        });

        SharedPreferences.setMockInitialValues({
          'training_session_free_ride_rower': prefsJson,
        });

        final loaded =
            await TrainingSessionPreferencesService.loadFreeRidePreferences(
          DeviceType.rower,
        );

        expect(loaded.targets['Power'], equals('80%'));
        expect(loaded.targets['Cadence'], equals(24));
        expect(loaded.resistanceLevel, equals(5));
      });

      test('returns empty preferences when key not found', () async {
        final loaded =
            await TrainingSessionPreferencesService.loadFreeRidePreferences(
          DeviceType.rower,
        );

        expect(loaded.targets, isEmpty);
        expect(loaded.resistanceLevel, isNull);
      });

      test('returns empty preferences when JSON is invalid', () async {
        SharedPreferences.setMockInitialValues({
          'training_session_free_ride_rower': 'invalid json',
        });

        final loaded =
            await TrainingSessionPreferencesService.loadFreeRidePreferences(
          DeviceType.rower,
        );

        expect(loaded.targets, isEmpty);
        expect(loaded.resistanceLevel, isNull);
      });

      test('loads preferences with null resistance level', () async {
        final prefsJson = jsonEncode({
          'deviceType': 'rower',
          'targets': {'Power': '80%'},
          'resistanceLevel': null,
        });

        SharedPreferences.setMockInitialValues({
          'training_session_free_ride_rower': prefsJson,
        });

        final loaded =
            await TrainingSessionPreferencesService.loadFreeRidePreferences(
          DeviceType.rower,
        );

        expect(loaded.targets['Power'], equals('80%'));
        expect(loaded.resistanceLevel, isNull);
      });
    });

    group('saveTrainingGeneratorPreferences', () {
      test('saves training generator preferences for rower', () async {
        final prefs = TrainingSessionPreferences(
          deviceType: DeviceType.rower,
          targets: {},
          resistanceLevel: 7,
        );

        await TrainingSessionPreferencesService.saveTrainingGeneratorPreferences(
          DeviceType.rower,
          prefs,
        );

        final sharedPrefs = await SharedPreferences.getInstance();
        final saved =
            sharedPrefs.getString('training_session_generator_rower');
        expect(saved, isNotNull);

        final decoded = jsonDecode(saved!) as Map<String, dynamic>;
        expect(decoded['resistanceLevel'], equals(7));
      });
    });

    group('loadTrainingGeneratorPreferences', () {
      test('loads training generator preferences for rower', () async {
        final prefsJson = jsonEncode({
          'deviceType': 'rower',
          'targets': {},
          'resistanceLevel': 7,
        });

        SharedPreferences.setMockInitialValues({
          'training_session_generator_rower': prefsJson,
        });

        final loaded =
            await TrainingSessionPreferencesService
                .loadTrainingGeneratorPreferences(
          DeviceType.rower,
        );

        expect(loaded.resistanceLevel, equals(7));
      });

      test('returns empty preferences when key not found', () async {
        final loaded =
            await TrainingSessionPreferencesService
                .loadTrainingGeneratorPreferences(
          DeviceType.rower,
        );

        expect(loaded.targets, isEmpty);
        expect(loaded.resistanceLevel, isNull);
      });
    });

    group('clearPreferences', () {
      test('clears all preferences for a device type', () async {
        // Set up initial preferences
        final prefsJson = jsonEncode({
          'targets': {'Power': '80%'},
          'resistanceLevel': 5,
        });

        SharedPreferences.setMockInitialValues({
          'training_session_free_ride_rower': prefsJson,
          'training_session_generator_rower': prefsJson,
        });

        // Clear preferences
        await TrainingSessionPreferencesService.clearPreferences(
          DeviceType.rower,
        );

        final sharedPrefs = await SharedPreferences.getInstance();
        expect(
          sharedPrefs.getString('training_session_free_ride_rower'),
          isNull,
        );
        expect(
          sharedPrefs.getString('training_session_generator_rower'),
          isNull,
        );
      });

      test('does not affect other device types', () async {
        final prefsJson = jsonEncode({
          'targets': {'Power': '80%'},
          'resistanceLevel': 5,
        });

        SharedPreferences.setMockInitialValues({
          'training_session_free_ride_rower': prefsJson,
          'training_session_free_ride_indoorBike': prefsJson,
        });

        // Clear only rower preferences
        await TrainingSessionPreferencesService.clearPreferences(
          DeviceType.rower,
        );

        final sharedPrefs = await SharedPreferences.getInstance();
        expect(
          sharedPrefs.getString('training_session_free_ride_rower'),
          isNull,
        );
        expect(
          sharedPrefs.getString('training_session_free_ride_indoorBike'),
          isNotNull,
        );
      });
    });

    group('TrainingSessionPreferences', () {
      test('toJson converts preferences correctly', () {
        final prefs = TrainingSessionPreferences(
          deviceType: DeviceType.rower,
          targets: {'Power': '80%', 'Cadence': 24},
          resistanceLevel: 5,
        );

        final json = prefs.toJson();

        expect(json['deviceType'], equals('rower'));
        expect(json['targets'], equals({'Power': '80%', 'Cadence': 24}));
        expect(json['resistanceLevel'], equals(5));
      });

      test('fromJson creates preferences from JSON', () {
        final json = {
          'deviceType': 'rower',
          'targets': {'Power': '80%', 'Cadence': 24},
          'resistanceLevel': 5,
        };

        final prefs = TrainingSessionPreferences.fromJson(json);

        expect(prefs.targets, equals({'Power': '80%', 'Cadence': 24}));
        expect(prefs.resistanceLevel, equals(5));
      });

      test('fromJson handles missing resistanceLevel', () {
        final json = {
          'deviceType': 'rower',
          'targets': {'Power': '80%'},
        };

        final prefs = TrainingSessionPreferences.fromJson(json);

        expect(prefs.targets, equals({'Power': '80%'}));
        expect(prefs.resistanceLevel, isNull);
      });

      test('fromJson handles missing targets', () {
        final json = {
          'deviceType': 'rower',
          'resistanceLevel': 5,
        };

        final prefs = TrainingSessionPreferences.fromJson(json);

        expect(prefs.targets, isEmpty);
        expect(prefs.resistanceLevel, equals(5));
      });
    });

    group('Device Type Separation', () {
      test('free ride and training generator preferences are separate for same device',
          () async {
        final freeRidePrefs = TrainingSessionPreferences(
          deviceType: DeviceType.rower,
          targets: {'Power': '80%'},
          resistanceLevel: 5,
        );

        final generatorPrefs = TrainingSessionPreferences(
          deviceType: DeviceType.rower,
          targets: {},
          resistanceLevel: 8,
        );

        await TrainingSessionPreferencesService.saveFreeRidePreferences(
          DeviceType.rower,
          freeRidePrefs,
        );

        await TrainingSessionPreferencesService.saveTrainingGeneratorPreferences(
          DeviceType.rower,
          generatorPrefs,
        );

        final loadedFreeRide =
            await TrainingSessionPreferencesService.loadFreeRidePreferences(
          DeviceType.rower,
        );

        final loadedGenerator =
            await TrainingSessionPreferencesService
                .loadTrainingGeneratorPreferences(
          DeviceType.rower,
        );

        expect(loadedFreeRide.resistanceLevel, equals(5));
        expect(loadedGenerator.resistanceLevel, equals(8));
      });

      test('preferences are independent across device types', () async {
        final rowerPrefs = TrainingSessionPreferences(
          deviceType: DeviceType.rower,
          targets: {'Power': '80%'},
          resistanceLevel: 5,
        );

        final bikePrefs = TrainingSessionPreferences(
          deviceType: DeviceType.indoorBike,
          targets: {'Power': '75%'},
          resistanceLevel: 8,
        );

        await TrainingSessionPreferencesService.saveFreeRidePreferences(
          DeviceType.rower,
          rowerPrefs,
        );

        await TrainingSessionPreferencesService.saveFreeRidePreferences(
          DeviceType.indoorBike,
          bikePrefs,
        );

        final loadedRower =
            await TrainingSessionPreferencesService.loadFreeRidePreferences(
          DeviceType.rower,
        );

        final loadedBike =
            await TrainingSessionPreferencesService.loadFreeRidePreferences(
          DeviceType.indoorBike,
        );

        expect(loadedRower.targets['Power'], equals('80%'));
        expect(loadedRower.resistanceLevel, equals(5));

        expect(loadedBike.targets['Power'], equals('75%'));
        expect(loadedBike.resistanceLevel, equals(8));
      });
    });

    group('Device Type Validation', () {
      test('isCompatibleWith returns true for matching device type', () {
        final prefs = TrainingSessionPreferences(
          deviceType: DeviceType.rower,
          targets: {},
          resistanceLevel: 5,
        );

        expect(prefs.isCompatibleWith(DeviceType.rower), isTrue);
      });

      test('isCompatibleWith returns false for different device type', () {
        final prefs = TrainingSessionPreferences(
          deviceType: DeviceType.rower,
          targets: {},
          resistanceLevel: 5,
        );

        expect(prefs.isCompatibleWith(DeviceType.indoorBike), isFalse);
      });

      test('loads preferences only if device type matches', () async {
        final prefsJson = jsonEncode({
          'deviceType': 'rower',
          'targets': {'Power': '80%'},
          'resistanceLevel': 5,
        });

        SharedPreferences.setMockInitialValues({
          'training_session_free_ride_rower': prefsJson,
        });

        // Load with correct device type
        final loadedCorrect =
            await TrainingSessionPreferencesService.loadFreeRidePreferences(
          DeviceType.rower,
        );
        expect(loadedCorrect.targets['Power'], equals('80%'));
        expect(loadedCorrect.resistanceLevel, equals(5));

        // Try to load from rower storage but with bike device type
        // This should return empty preferences
        final loaded =
            await TrainingSessionPreferencesService.loadFreeRidePreferences(
          DeviceType.indoorBike,
        );
        expect(loaded.targets, isEmpty);
        expect(loaded.resistanceLevel, isNull);
      });

      test('toJson includes device type', () {
        final prefs = TrainingSessionPreferences(
          deviceType: DeviceType.indoorBike,
          targets: {'Power': '80%'},
          resistanceLevel: 5,
        );

        final json = prefs.toJson();
        expect(json['deviceType'], equals('indoorBike'));
        expect(json['targets']['Power'], equals('80%'));
        expect(json['resistanceLevel'], equals(5));
      });

      test('fromJson preserves device type', () {
        final json = {
          'deviceType': 'indoorBike',
          'targets': {'Power': '75%'},
          'resistanceLevel': 8,
        };

        final prefs = TrainingSessionPreferences.fromJson(json);
        expect(prefs.deviceType, equals(DeviceType.indoorBike));
        expect(prefs.targets['Power'], equals('75%'));
        expect(prefs.resistanceLevel, equals(8));
      });
    });
  });
}
