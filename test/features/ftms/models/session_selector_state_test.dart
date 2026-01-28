import 'package:flutter_test/flutter_test.dart';
import 'package:ftms/core/models/device_types.dart';
import 'package:ftms/core/models/supported_resistance_level_range.dart';
import 'package:ftms/features/training/model/rower_workout_type.dart';
import 'package:ftms/features/ftms/models/session_selector_state.dart';

void main() {
  group('FreeRideConfig', () {
    test('has correct default values', () {
      const config = FreeRideConfig();
      
      expect(config.durationMinutes, 20);
      expect(config.isDistanceBased, false);
      expect(config.distanceMeters, 5000);
      expect(config.targets, isEmpty);
      expect(config.resistanceLevel, isNull);
      expect(config.userResistanceLevel, isNull);
      expect(config.isResistanceLevelValid, true);
      expect(config.hasWarmup, true);
      expect(config.hasCooldown, true);
    });

    test('copyWith updates specified fields only', () {
      const original = FreeRideConfig(durationMinutes: 20, distanceMeters: 5000);
      final updated = original.copyWith(durationMinutes: 30);
      
      expect(updated.durationMinutes, 30);
      expect(updated.distanceMeters, 5000); // unchanged
    });

    test('copyWith with clearResistanceLevel sets to null', () {
      const config = FreeRideConfig(resistanceLevel: 5, userResistanceLevel: 3);
      final cleared = config.copyWith(clearResistanceLevel: true, clearUserResistanceLevel: true);
      
      expect(cleared.resistanceLevel, isNull);
      expect(cleared.userResistanceLevel, isNull);
    });

    test('copyWith preserves existing value when new value is null', () {
      const config = FreeRideConfig(durationMinutes: 45);
      final updated = config.copyWith();
      
      expect(updated.durationMinutes, 45);
    });

    test('copyWith with targets creates new map', () {
      const config = FreeRideConfig(targets: {'power': 150});
      final updated = config.copyWith(targets: {'cadence': 80});
      
      expect(updated.targets, {'cadence': 80});
      expect(config.targets, {'power': 150}); // original unchanged
    });

    group('getDistanceIncrement', () {
      test('returns 1000 for null device type', () {
        expect(FreeRideConfig.getDistanceIncrement(null), 1000);
      });

      test('returns 250 for rower', () {
        expect(FreeRideConfig.getDistanceIncrement(DeviceType.rower), 250);
      });

      test('returns 1000 for indoor bike', () {
        expect(FreeRideConfig.getDistanceIncrement(DeviceType.indoorBike), 1000);
      });
    });

    group('workoutValue', () {
      test('returns seconds for time-based', () {
        const config = FreeRideConfig(durationMinutes: 30, isDistanceBased: false);
        expect(config.workoutValue, 30 * 60);
      });

      test('returns meters for distance-based', () {
        const config = FreeRideConfig(distanceMeters: 10000, isDistanceBased: true);
        expect(config.workoutValue, 10000);
      });
    });

    group('equality', () {
      test('two configs with same values are equal', () {
        const config1 = FreeRideConfig(durationMinutes: 30, hasWarmup: true);
        const config2 = FreeRideConfig(durationMinutes: 30, hasWarmup: true);
        
        expect(config1, equals(config2));
        expect(config1.hashCode, equals(config2.hashCode));
      });

      test('two configs with different values are not equal', () {
        const config1 = FreeRideConfig(durationMinutes: 30);
        const config2 = FreeRideConfig(durationMinutes: 45);
        
        expect(config1, isNot(equals(config2)));
      });

      test('identical configs are equal', () {
        const config = FreeRideConfig();
        expect(config == config, isTrue);
      });
    });
  });

  group('TrainingGeneratorConfig', () {
    test('has correct default values', () {
      const config = TrainingGeneratorConfig();
      
      expect(config.durationMinutes, 30);
      expect(config.workoutType, RowerWorkoutType.BASE_ENDURANCE);
      expect(config.resistanceLevel, isNull);
      expect(config.userResistanceLevel, isNull);
      expect(config.isResistanceLevelValid, true);
    });

    test('copyWith updates specified fields only', () {
      const original = TrainingGeneratorConfig(durationMinutes: 30);
      final updated = original.copyWith(durationMinutes: 60);
      
      expect(updated.durationMinutes, 60);
      expect(updated.workoutType, RowerWorkoutType.BASE_ENDURANCE); // unchanged
    });

    test('copyWith with clearResistanceLevel sets to null', () {
      const config = TrainingGeneratorConfig(resistanceLevel: 5, userResistanceLevel: 3);
      final cleared = config.copyWith(clearResistanceLevel: true, clearUserResistanceLevel: true);
      
      expect(cleared.resistanceLevel, isNull);
      expect(cleared.userResistanceLevel, isNull);
    });

    test('copyWith updates workout type', () {
      const config = TrainingGeneratorConfig(workoutType: RowerWorkoutType.BASE_ENDURANCE);
      final updated = config.copyWith(workoutType: RowerWorkoutType.VO2_MAX);
      
      expect(updated.workoutType, RowerWorkoutType.VO2_MAX);
    });

    group('equality', () {
      test('two configs with same values are equal', () {
        const config1 = TrainingGeneratorConfig(durationMinutes: 45, workoutType: RowerWorkoutType.SPRINT);
        const config2 = TrainingGeneratorConfig(durationMinutes: 45, workoutType: RowerWorkoutType.SPRINT);
        
        expect(config1, equals(config2));
        expect(config1.hashCode, equals(config2.hashCode));
      });

      test('two configs with different values are not equal', () {
        const config1 = TrainingGeneratorConfig(durationMinutes: 30);
        const config2 = TrainingGeneratorConfig(durationMinutes: 60);
        
        expect(config1, isNot(equals(config2)));
      });
    });
  });

  group('ExpansionState', () {
    test('has all panels collapsed by default', () {
      const state = ExpansionState();
      
      expect(state.isFreeRideExpanded, false);
      expect(state.isTrainingSessionExpanded, false);
      expect(state.isTrainingSessionGeneratorExpanded, false);
      expect(state.isMachineFeaturesExpanded, false);
      expect(state.isDeviceDataFeaturesExpanded, false);
    });

    test('copyWith updates specified panel only', () {
      const original = ExpansionState();
      final updated = original.copyWith(isFreeRideExpanded: true);
      
      expect(updated.isFreeRideExpanded, true);
      expect(updated.isTrainingSessionExpanded, false);
      expect(updated.isTrainingSessionGeneratorExpanded, false);
    });

    test('copyWith can update multiple panels', () {
      const original = ExpansionState();
      final updated = original.copyWith(
        isFreeRideExpanded: true,
        isMachineFeaturesExpanded: true,
      );
      
      expect(updated.isFreeRideExpanded, true);
      expect(updated.isMachineFeaturesExpanded, true);
      expect(updated.isTrainingSessionExpanded, false);
    });

    group('equality', () {
      test('two states with same values are equal', () {
        const state1 = ExpansionState(isFreeRideExpanded: true);
        const state2 = ExpansionState(isFreeRideExpanded: true);
        
        expect(state1, equals(state2));
        expect(state1.hashCode, equals(state2.hashCode));
      });

      test('two states with different values are not equal', () {
        const state1 = ExpansionState(isFreeRideExpanded: true);
        const state2 = ExpansionState(isFreeRideExpanded: false);
        
        expect(state1, isNot(equals(state2)));
      });
    });
  });

  group('ResistanceCapabilities', () {
    test('has correct default values', () {
      const caps = ResistanceCapabilities();
      
      expect(caps.supportsResistanceControl, false);
      expect(caps.supportedRange, isNull);
    });

    group('isAvailable', () {
      test('returns false when supportsResistanceControl is false', () {
        const caps = ResistanceCapabilities(supportsResistanceControl: false);
        expect(caps.isAvailable, false);
      });

      test('returns false when supportedRange is null', () {
        const caps = ResistanceCapabilities(supportsResistanceControl: true);
        expect(caps.isAvailable, false);
      });

      test('returns true when support and valid range exist', () {
        final range = SupportedResistanceLevelRange(
          minResistanceLevel: 1,
          maxResistanceLevel: 10,
          minIncrement: 1,
        );
        final caps = ResistanceCapabilities(
          supportsResistanceControl: true,
          supportedRange: range,
        );
        expect(caps.isAvailable, true);
      });
    });

    group('maxUserInput', () {
      test('returns 100 when no range', () {
        const caps = ResistanceCapabilities();
        expect(caps.maxUserInput, 100);
      });

      test('returns maxUserInput from range when available', () {
        final range = SupportedResistanceLevelRange(
          minResistanceLevel: 0,
          maxResistanceLevel: 20,
          minIncrement: 1,
        );
        final caps = ResistanceCapabilities(supportedRange: range);
        expect(caps.maxUserInput, range.maxUserInput);
      });
    });

    group('convertUserInputToMachine', () {
      test('returns input as-is when no range', () {
        const caps = ResistanceCapabilities();
        expect(caps.convertUserInputToMachine(5), 5);
      });

      test('uses range conversion when available', () {
        final range = SupportedResistanceLevelRange(
          minResistanceLevel: 0,
          maxResistanceLevel: 100,
          minIncrement: 10,
        );
        final caps = ResistanceCapabilities(supportedRange: range);
        final result = caps.convertUserInputToMachine(5);
        expect(result, range.convertUserInputToMachine(5));
      });
    });

    group('convertMachineToUserInput', () {
      test('returns input as-is when no range', () {
        const caps = ResistanceCapabilities();
        expect(caps.convertMachineToUserInput(50), 50);
      });

      test('uses range conversion when available', () {
        final range = SupportedResistanceLevelRange(
          minResistanceLevel: 0,
          maxResistanceLevel: 100,
          minIncrement: 10,
        );
        final caps = ResistanceCapabilities(supportedRange: range);
        final result = caps.convertMachineToUserInput(50);
        expect(result, range.convertMachineToUserInput(50));
      });
    });

    group('equality', () {
      test('two capabilities with same values are equal', () {
        const caps1 = ResistanceCapabilities(supportsResistanceControl: true);
        const caps2 = ResistanceCapabilities(supportsResistanceControl: true);
        
        expect(caps1, equals(caps2));
        expect(caps1.hashCode, equals(caps2.hashCode));
      });

      test('two capabilities with different values are not equal', () {
        const caps1 = ResistanceCapabilities(supportsResistanceControl: true);
        const caps2 = ResistanceCapabilities(supportsResistanceControl: false);
        
        expect(caps1, isNot(equals(caps2)));
      });
    });
  });

  group('SessionSelectorLoadingStatus', () {
    test('has all expected values', () {
      expect(SessionSelectorLoadingStatus.values, containsAll([
        SessionSelectorLoadingStatus.initial,
        SessionSelectorLoadingStatus.loading,
        SessionSelectorLoadingStatus.loaded,
        SessionSelectorLoadingStatus.error,
      ]));
    });
  });

  group('SessionSelectorState', () {
    test('has correct default values', () {
      const state = SessionSelectorState();
      
      expect(state.status, SessionSelectorLoadingStatus.initial);
      expect(state.errorMessage, isNull);
      expect(state.deviceType, isNull);
      expect(state.userSettings, isNull);
      expect(state.configs, isEmpty);
      expect(state.isDeviceAvailable, true);
      expect(state.resistanceCapabilities, const ResistanceCapabilities());
      expect(state.gpxFiles, isNull);
      expect(state.selectedGpxAssetPath, isNull);
      expect(state.trainingSessions, isNull);
      expect(state.isLoadingTrainingSessions, false);
      expect(state.expansionState, const ExpansionState());
      expect(state.freeRideConfig, const FreeRideConfig());
      expect(state.trainingGeneratorConfig, const TrainingGeneratorConfig());
    });

    group('computed properties', () {
      test('isLoading returns true only when status is loading', () {
        const loadingState = SessionSelectorState(status: SessionSelectorLoadingStatus.loading);
        const loadedState = SessionSelectorState(status: SessionSelectorLoadingStatus.loaded);
        
        expect(loadingState.isLoading, true);
        expect(loadedState.isLoading, false);
      });

      test('isLoaded returns true only when status is loaded', () {
        const loadedState = SessionSelectorState(status: SessionSelectorLoadingStatus.loaded);
        const loadingState = SessionSelectorState(status: SessionSelectorLoadingStatus.loading);
        
        expect(loadedState.isLoaded, true);
        expect(loadingState.isLoaded, false);
      });

      test('hasError returns true only when status is error', () {
        const errorState = SessionSelectorState(status: SessionSelectorLoadingStatus.error);
        const loadedState = SessionSelectorState(status: SessionSelectorLoadingStatus.loaded);
        
        expect(errorState.hasError, true);
        expect(loadedState.hasError, false);
      });
    });

    group('copyWith', () {
      test('updates specified fields only', () {
        const original = SessionSelectorState(status: SessionSelectorLoadingStatus.initial);
        final updated = original.copyWith(status: SessionSelectorLoadingStatus.loaded);
        
        expect(updated.status, SessionSelectorLoadingStatus.loaded);
        expect(updated.deviceType, isNull); // unchanged
      });

      test('clearErrorMessage sets errorMessage to null', () {
        const state = SessionSelectorState(errorMessage: 'Error occurred');
        final cleared = state.copyWith(clearErrorMessage: true);
        
        expect(cleared.errorMessage, isNull);
      });

      test('clearDeviceType sets deviceType to null', () {
        const state = SessionSelectorState(deviceType: DeviceType.rower);
        final cleared = state.copyWith(clearDeviceType: true);
        
        expect(cleared.deviceType, isNull);
      });

      test('clearSelectedGpxAssetPath sets path to null', () {
        const state = SessionSelectorState(selectedGpxAssetPath: 'test/path.gpx');
        final cleared = state.copyWith(clearSelectedGpxAssetPath: true);
        
        expect(cleared.selectedGpxAssetPath, isNull);
      });

      test('clearTrainingSessions sets trainingSessions to null', () {
        final state = SessionSelectorState(trainingSessions: []);
        final cleared = state.copyWith(clearTrainingSessions: true);
        
        expect(cleared.trainingSessions, isNull);
      });

      test('updates nested config objects', () {
        const original = SessionSelectorState();
        final updated = original.copyWith(
          freeRideConfig: const FreeRideConfig(durationMinutes: 45),
          expansionState: const ExpansionState(isFreeRideExpanded: true),
        );
        
        expect(updated.freeRideConfig.durationMinutes, 45);
        expect(updated.expansionState.isFreeRideExpanded, true);
      });
    });

    group('equality', () {
      test('two states with same values are equal', () {
        const state1 = SessionSelectorState(
          status: SessionSelectorLoadingStatus.loaded,
          deviceType: DeviceType.rower,
        );
        const state2 = SessionSelectorState(
          status: SessionSelectorLoadingStatus.loaded,
          deviceType: DeviceType.rower,
        );
        
        expect(state1, equals(state2));
        expect(state1.hashCode, equals(state2.hashCode));
      });

      test('two states with different status are not equal', () {
        const state1 = SessionSelectorState(status: SessionSelectorLoadingStatus.loading);
        const state2 = SessionSelectorState(status: SessionSelectorLoadingStatus.loaded);
        
        expect(state1, isNot(equals(state2)));
      });

      test('two states with different device types are not equal', () {
        const state1 = SessionSelectorState(deviceType: DeviceType.rower);
        const state2 = SessionSelectorState(deviceType: DeviceType.indoorBike);
        
        expect(state1, isNot(equals(state2)));
      });

      test('identical state is equal to itself', () {
        const state = SessionSelectorState();
        expect(state == state, isTrue);
      });
    });
  });
}
