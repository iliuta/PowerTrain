import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:flutter_ftms/flutter_ftms.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:ftms/core/models/device_types.dart';
import 'package:ftms/core/models/supported_resistance_level_range.dart';
import 'package:ftms/core/config/live_data_display_config.dart';
import 'package:ftms/core/services/gpx/gpx_data.dart';
import 'package:ftms/core/services/analytics/analytics_service.dart';
import 'package:ftms/features/settings/model/user_settings.dart';
import 'package:ftms/features/training/model/training_session.dart';
import 'package:ftms/features/training/model/rower_workout_type.dart';
import 'package:ftms/features/ftms/models/session_selector_state.dart';
import 'package:ftms/features/ftms/services/session_selector_service.dart';

@GenerateMocks([
  BluetoothDevice,
  AnalyticsService,
])
import 'session_selector_service_test.mocks.dart';

// Mock implementations for testing
class MockFtmsDeviceOperations implements FtmsDeviceOperations {
  DeviceType? deviceTypeToReturn;
  final StreamController<DeviceType> _deviceTypeController = StreamController<DeviceType>.broadcast();
  bool supportsResistanceResult = true;
  SupportedResistanceLevelRange? resistanceRangeResult;
  
  @override
  DeviceType? getDeviceType() => deviceTypeToReturn;
  
  @override
  Stream<DeviceType> get deviceTypeStream => _deviceTypeController.stream;
  
  void emitDeviceType(DeviceType type) {
    _deviceTypeController.add(type);
  }
  
  @override
  Future<bool> supportsResistanceControl(BluetoothDevice device) async {
    return supportsResistanceResult;
  }
  
  @override
  Future<SupportedResistanceLevelRange?> readSupportedResistanceLevelRange(BluetoothDevice device) async {
    return resistanceRangeResult;
  }
  
  void dispose() {
    _deviceTypeController.close();
  }
}

class MockSettingsOperations implements SettingsOperations {
  UserSettings settingsToReturn = const UserSettings(
    cyclingFtp: 200,
    rowingFtp: '2:00',
    developerMode: false,
    soundEnabled: true,
  );
  Map<DeviceType, LiveDataDisplayConfig?> configsToReturn = {};
  
  @override
  Future<UserSettings> loadSettings() async {
    return settingsToReturn;
  }
  
  @override
  Future<LiveDataDisplayConfig?> loadConfigForDeviceType(DeviceType deviceType) async {
    return configsToReturn[deviceType];
  }
}

class MockTrainingSessionOperations implements TrainingSessionOperations {
  List<TrainingSessionDefinition> sessionsToReturn = [];
  bool shouldThrow = false;
  
  @override
  Future<List<TrainingSessionDefinition>> loadTrainingSessions(DeviceType deviceType) async {
    if (shouldThrow) {
      throw Exception('Failed to load sessions');
    }
    return sessionsToReturn;
  }
}

class MockGpxOperations implements GpxOperations {
  List<GpxData> gpxDataToReturn = [];
  
  @override
  Future<List<GpxData>> getSortedGpxData(DeviceType deviceType) async {
    return gpxDataToReturn;
  }
}

void main() {
  late MockBluetoothDevice mockDevice;
  late MockFtmsDeviceOperations mockFtmsOperations;
  late MockSettingsOperations mockSettingsOperations;
  late MockTrainingSessionOperations mockTrainingSessionOperations;
  late MockGpxOperations mockGpxOperations;
  late MockAnalyticsService mockAnalyticsService;
  late SessionSelectorService service;

  setUp(() {
    mockDevice = MockBluetoothDevice();
    mockFtmsOperations = MockFtmsDeviceOperations();
    mockSettingsOperations = MockSettingsOperations();
    mockTrainingSessionOperations = MockTrainingSessionOperations();
    mockGpxOperations = MockGpxOperations();
    mockAnalyticsService = MockAnalyticsService();
    
    when(mockDevice.platformName).thenReturn('Test Device');
    when(mockAnalyticsService.logScreenView(
      screenName: anyNamed('screenName'),
      screenClass: anyNamed('screenClass'),
    )).thenAnswer((_) async {});
    when(mockAnalyticsService.logFtmsDeviceDataRead(
      ftmsDeviceData: anyNamed('ftmsDeviceData'),
    )).thenAnswer((_) async {});
    when(mockAnalyticsService.logFreeRideStarted(
      machineType: anyNamed('machineType'),
      isDistanceBased: anyNamed('isDistanceBased'),
      targetValue: anyNamed('targetValue'),
      hasWarmup: anyNamed('hasWarmup'),
      hasCooldown: anyNamed('hasCooldown'),
      resistanceLevel: anyNamed('resistanceLevel'),
      hasGpxRoute: anyNamed('hasGpxRoute'),
    )).thenAnswer((_) async {});
    when(mockAnalyticsService.logTrainingSessionGenerated(
      workoutType: anyNamed('workoutType'),
      duration: anyNamed('duration'),
      resistanceLevel: anyNamed('resistanceLevel'),
    )).thenAnswer((_) async {});
    when(mockAnalyticsService.logTrainingSessionSelected(
      machineType: anyNamed('machineType'),
      sessionTitle: anyNamed('sessionTitle'),
      isCustom: anyNamed('isCustom'),
      isDistanceBased: anyNamed('isDistanceBased'),
    )).thenAnswer((_) async {});
    
    service = SessionSelectorService(
      ftmsDevice: mockDevice,
      ftmsOperations: mockFtmsOperations,
      settingsOperations: mockSettingsOperations,
      trainingSessionOperations: mockTrainingSessionOperations,
      gpxOperations: mockGpxOperations,
      analyticsService: mockAnalyticsService,
      deviceTypeTimeout: const Duration(milliseconds: 100),
    );
  });

  tearDown(() {
    mockFtmsOperations.dispose();
    service.dispose();
  });

  group('SessionSelectorState', () {
    test('initial state has correct defaults', () {
      const state = SessionSelectorState();
      
      expect(state.status, SessionSelectorLoadingStatus.initial);
      expect(state.deviceType, isNull);
      expect(state.userSettings, isNull);
      expect(state.isDeviceAvailable, true);
      expect(state.freeRideConfig.durationMinutes, 20);
      expect(state.freeRideConfig.isDistanceBased, false);
      expect(state.freeRideConfig.distanceMeters, 5000);
      expect(state.trainingGeneratorConfig.durationMinutes, 30);
      expect(state.trainingGeneratorConfig.workoutType, RowerWorkoutType.BASE_ENDURANCE);
    });

    test('copyWith correctly updates fields', () {
      const state = SessionSelectorState();
      final newState = state.copyWith(
        status: SessionSelectorLoadingStatus.loaded,
        deviceType: DeviceType.rower,
      );
      
      expect(newState.status, SessionSelectorLoadingStatus.loaded);
      expect(newState.deviceType, DeviceType.rower);
      expect(newState.freeRideConfig.durationMinutes, 20); // unchanged
    });

    test('copyWith with clear flags sets values to null', () {
      final state = SessionSelectorState(
        errorMessage: 'test error',
        selectedGpxAssetPath: 'test/path.gpx',
      );
      final newState = state.copyWith(
        clearErrorMessage: true,
        clearSelectedGpxAssetPath: true,
      );
      
      expect(newState.errorMessage, isNull);
      expect(newState.selectedGpxAssetPath, isNull);
    });
  });

  group('FreeRideConfig', () {
    test('initial config has correct defaults', () {
      const config = FreeRideConfig();
      
      expect(config.durationMinutes, 20);
      expect(config.isDistanceBased, false);
      expect(config.distanceMeters, 5000);
      expect(config.targets, isEmpty);
      expect(config.resistanceLevel, isNull);
      expect(config.isResistanceLevelValid, true);
      expect(config.hasWarmup, true);
      expect(config.hasCooldown, true);
    });

    test('workoutValue returns seconds for time-based', () {
      const config = FreeRideConfig(durationMinutes: 30, isDistanceBased: false);
      expect(config.workoutValue, 30 * 60);
    });

    test('workoutValue returns meters for distance-based', () {
      const config = FreeRideConfig(distanceMeters: 10000, isDistanceBased: true);
      expect(config.workoutValue, 10000);
    });

    test('getDistanceIncrement returns 250 for rower', () {
      expect(FreeRideConfig.getDistanceIncrement(DeviceType.rower), 250);
    });

    test('getDistanceIncrement returns 1000 for indoor bike', () {
      expect(FreeRideConfig.getDistanceIncrement(DeviceType.indoorBike), 1000);
    });
  });

  group('TrainingGeneratorConfig', () {
    test('initial config has correct defaults', () {
      const config = TrainingGeneratorConfig();
      
      expect(config.durationMinutes, 30);
      expect(config.workoutType, RowerWorkoutType.BASE_ENDURANCE);
      expect(config.resistanceLevel, isNull);
      expect(config.isResistanceLevelValid, true);
    });

    test('copyWith correctly updates fields', () {
      const config = TrainingGeneratorConfig();
      final newConfig = config.copyWith(
        durationMinutes: 45,
        workoutType: RowerWorkoutType.VO2_MAX,
      );
      
      expect(newConfig.durationMinutes, 45);
      expect(newConfig.workoutType, RowerWorkoutType.VO2_MAX);
    });
  });

  group('ResistanceCapabilities', () {
    test('isAvailable is false when no support', () {
      const caps = ResistanceCapabilities(supportsResistanceControl: false);
      expect(caps.isAvailable, false);
    });

    test('isAvailable is false when no range', () {
      const caps = ResistanceCapabilities(supportsResistanceControl: true);
      expect(caps.isAvailable, false);
    });

    test('maxUserInput defaults to 100 when no range', () {
      const caps = ResistanceCapabilities();
      expect(caps.maxUserInput, 100);
    });
  });

  group('ExpansionState', () {
    test('initial state has all panels collapsed', () {
      const state = ExpansionState();
      
      expect(state.isFreeRideExpanded, false);
      expect(state.isTrainingSessionExpanded, false);
      expect(state.isTrainingSessionGeneratorExpanded, false);
      expect(state.isMachineFeaturesExpanded, false);
      expect(state.isDeviceDataFeaturesExpanded, false);
    });

    test('copyWith correctly toggles expansion', () {
      const state = ExpansionState();
      final newState = state.copyWith(isFreeRideExpanded: true);
      
      expect(newState.isFreeRideExpanded, true);
      expect(newState.isTrainingSessionExpanded, false);
    });
  });

  group('SessionSelectorService', () {
    test('initial state is correct', () {
      expect(service.state.status, SessionSelectorLoadingStatus.initial);
    });

    group('initialization', () {
      test('loads user settings on initialize', () async {
        mockFtmsOperations.deviceTypeToReturn = DeviceType.rower;
        mockSettingsOperations.settingsToReturn = const UserSettings(
          cyclingFtp: 200,
          rowingFtp: '2:00',
          developerMode: true,
          soundEnabled: true,
        );
        
        await service.initialize();
        
        expect(service.state.userSettings?.developerMode, true);
        expect(service.state.status, SessionSelectorLoadingStatus.loaded);
      });

      test('uses device type from ftms operations', () async {
        mockFtmsOperations.deviceTypeToReturn = DeviceType.indoorBike;
        mockSettingsOperations.settingsToReturn = const UserSettings(
          cyclingFtp: 200,
          rowingFtp: '2:00',
          developerMode: false,
          soundEnabled: true,
        );
        
        await service.initialize();
        
        expect(service.state.deviceType, DeviceType.indoorBike);
      });

      test('subscribes to device type stream when no initial type', () async {
        mockFtmsOperations.deviceTypeToReturn = null;
        mockSettingsOperations.settingsToReturn = const UserSettings(
          cyclingFtp: 200,
          rowingFtp: '2:00',
          developerMode: false,
          soundEnabled: true,
        );
        
        await service.initialize();
        
        // Emit device type from stream
        mockFtmsOperations.emitDeviceType(DeviceType.rower);
        
        // Allow async processing
        await Future.delayed(const Duration(milliseconds: 50));
        
        expect(service.state.deviceType, DeviceType.rower);
      });
    });

    group('expansion state', () {
      test('toggleFreeRideExpanded toggles the state', () {
        expect(service.state.expansionState.isFreeRideExpanded, false);
        
        service.toggleFreeRideExpanded();
        expect(service.state.expansionState.isFreeRideExpanded, true);
        
        service.toggleFreeRideExpanded();
        expect(service.state.expansionState.isFreeRideExpanded, false);
      });

      test('toggleTrainingSessionGeneratorExpanded toggles the state', () {
        expect(service.state.expansionState.isTrainingSessionGeneratorExpanded, false);
        
        service.toggleTrainingSessionGeneratorExpanded();
        expect(service.state.expansionState.isTrainingSessionGeneratorExpanded, true);
      });

      test('toggleMachineFeaturesExpanded toggles the state', () {
        expect(service.state.expansionState.isMachineFeaturesExpanded, false);
        
        service.toggleMachineFeaturesExpanded();
        expect(service.state.expansionState.isMachineFeaturesExpanded, true);
      });

      test('toggleDeviceDataFeaturesExpanded toggles the state', () {
        expect(service.state.expansionState.isDeviceDataFeaturesExpanded, false);
        
        service.toggleDeviceDataFeaturesExpanded();
        expect(service.state.expansionState.isDeviceDataFeaturesExpanded, true);
      });
    });

    group('free ride configuration', () {
      test('updateFreeRideDuration updates duration', () {
        service.updateFreeRideDuration(45);
        expect(service.state.freeRideConfig.durationMinutes, 45);
      });

      test('updateFreeRideDistance updates distance', () {
        service.updateFreeRideDistance(10000);
        expect(service.state.freeRideConfig.distanceMeters, 10000);
      });

      test('updateFreeRideDistanceBased toggles mode', () {
        expect(service.state.freeRideConfig.isDistanceBased, false);
        
        service.updateFreeRideDistanceBased(true);
        expect(service.state.freeRideConfig.isDistanceBased, true);
      });

      test('updateFreeRideTarget adds target', () {
        service.updateFreeRideTarget('cadence', 80);
        expect(service.state.freeRideConfig.targets['cadence'], 80);
      });

      test('updateFreeRideTarget removes target when null', () {
        service.updateFreeRideTarget('cadence', 80);
        service.updateFreeRideTarget('cadence', null);
        expect(service.state.freeRideConfig.targets.containsKey('cadence'), false);
      });

      test('updateFreeRideWarmup updates warmup flag', () {
        service.updateFreeRideWarmup(false);
        expect(service.state.freeRideConfig.hasWarmup, false);
      });

      test('updateFreeRideCooldown updates cooldown flag', () {
        service.updateFreeRideCooldown(false);
        expect(service.state.freeRideConfig.hasCooldown, false);
      });
    });

    group('training generator configuration', () {
      test('updateTrainingGeneratorDuration updates duration', () {
        service.updateTrainingGeneratorDuration(60);
        expect(service.state.trainingGeneratorConfig.durationMinutes, 60);
      });

      test('updateTrainingGeneratorWorkoutType updates workout type', () {
        service.updateTrainingGeneratorWorkoutType(RowerWorkoutType.VO2_MAX);
        expect(service.state.trainingGeneratorConfig.workoutType, RowerWorkoutType.VO2_MAX);
      });
    });

    group('GPX selection', () {
      test('selectGpxRoute selects a route', () {
        service.selectGpxRoute('test/path.gpx');
        expect(service.state.selectedGpxAssetPath, 'test/path.gpx');
      });

      test('selectGpxRoute deselects when same route selected', () {
        service.selectGpxRoute('test/path.gpx');
        service.selectGpxRoute('test/path.gpx');
        expect(service.state.selectedGpxAssetPath, isNull);
      });
    });

    group('state listeners', () {
      test('listeners are notified on state changes', () {
        var notificationCount = 0;
        service.addListener((_) => notificationCount++);
        
        service.toggleFreeRideExpanded();
        service.updateFreeRideDuration(30);
        
        expect(notificationCount, 2);
      });

      test('removed listeners are not notified', () {
        var notificationCount = 0;
        void listener(SessionSelectorState state) => notificationCount++;
        
        service.addListener(listener);
        service.toggleFreeRideExpanded();
        expect(notificationCount, 1);
        
        service.removeListener(listener);
        service.toggleFreeRideExpanded();
        expect(notificationCount, 1);
      });
    });

    group('training sessions loading', () {
      setUp(() async {
        mockFtmsOperations.deviceTypeToReturn = DeviceType.rower;
        mockSettingsOperations.settingsToReturn = const UserSettings(
          cyclingFtp: 200,
          rowingFtp: '2:00',
          developerMode: false,
          soundEnabled: true,
        );
        await service.initialize();
      });

      test('loadTrainingSessions sets loading state', () async {
        final sessions = <TrainingSessionDefinition>[];
        mockTrainingSessionOperations.sessionsToReturn = sessions;
        
        // Start loading but don't await
        final future = service.loadTrainingSessions();
        expect(service.state.isLoadingTrainingSessions, true);
        
        await future;
        expect(service.state.isLoadingTrainingSessions, false);
      });

      test('loadTrainingSessions stores loaded sessions', () async {
        final sessions = [
          TrainingSessionDefinition(
            title: 'Test Session',
            ftmsMachineType: DeviceType.rower,
            intervals: [],
          ),
        ];
        mockTrainingSessionOperations.sessionsToReturn = sessions;
        
        await service.loadTrainingSessions();
        
        expect(service.state.trainingSessions, isNotNull);
        expect(service.state.trainingSessions!.length, 1);
        expect(service.state.trainingSessions![0].title, 'Test Session');
      });

      test('loadTrainingSessions handles errors gracefully', () async {
        mockTrainingSessionOperations.shouldThrow = true;
        
        await service.loadTrainingSessions();
        
        expect(service.state.isLoadingTrainingSessions, false);
        expect(service.state.trainingSessions, isNull);
      });

      test('loadTrainingSessions does not reload if sessions exist', () async {
        mockTrainingSessionOperations.sessionsToReturn = [];
        await service.loadTrainingSessions();
        
        // Try to load again
        mockTrainingSessionOperations.sessionsToReturn = [
          TrainingSessionDefinition(
            title: 'New Session',
            ftmsMachineType: DeviceType.rower,
            intervals: [],
          ),
        ];
        await service.loadTrainingSessions();
        
        // Should still be empty list from first load
        expect(service.state.trainingSessions!.isEmpty, true);
      });
    });
  });
}
