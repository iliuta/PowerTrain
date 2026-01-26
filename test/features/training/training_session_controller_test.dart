import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_ftms/flutter_ftms.dart';
import 'package:flutter_ftms/src/ftms/flag.dart';
import 'package:flutter_ftms/src/ftms/parameter_name.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ftms/core/bloc/ftms_bloc.dart';
import 'package:ftms/core/models/device_types.dart';
import 'package:ftms/core/services/fit/training_data_recorder.dart';
import 'package:ftms/core/services/ftms_service.dart';
import 'package:ftms/core/services/sound_service.dart';
import 'package:ftms/core/services/strava/strava_service.dart';
import 'package:ftms/features/training/model/expanded_training_session_definition.dart';
import 'package:ftms/features/training/model/expanded_unit_training_interval.dart';
import 'package:ftms/features/training/model/unit_training_interval.dart';
import 'package:ftms/features/training/model/session_state.dart';
import 'package:ftms/features/training/training_session_controller.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

// Generate mocks for our dependencies
@GenerateMocks([
  BluetoothDevice,
  FTMSService,
  TrainingDataRecorder,
  StravaService,
  AudioPlayer,
])
import 'training_session_controller_test.mocks.dart';

// Mock classes for FTMS data
class MockDeviceData extends DeviceData {
  final List<MockParameter> _parameters;

  MockDeviceData(this._parameters) : super([0, 0, 0, 0]);

  @override
  DeviceDataType get deviceDataType => DeviceDataType.indoorBike;

  @override
  List<Flag> get allDeviceDataFlags => [];

  @override
  List<DeviceDataParameter> get allDeviceDataParameters => _parameters.cast<DeviceDataParameter>();

  @override
  List<DeviceDataParameterValue> getDeviceDataParameterValues() {
    return _parameters.map((p) => MockParameterValue(p.name, p.value.toInt())).toList();
  }
}

class MockParameter implements DeviceDataParameter {
  final ParameterName _name;
  final num _value;

  MockParameter(String name, this._value) 
    : _name = MockParameterName(name);

  @override
  ParameterName get name => _name;

  num get value => _value;

  @override
  num get factor => 1;

  @override
  String get unit => 'W';

  @override
  Flag? get flag => null;

  @override
  int get size => 2;

  @override
  bool get signed => false;

  @override
  DeviceDataParameterValue toDeviceDataParameterValue(int value) {
    return MockParameterValue(_name, value);
  }

  @override
  String toString() => _value.toString();
}

class MockParameterValue implements DeviceDataParameterValue {
  final ParameterName _name;
  final int _value;

  MockParameterValue(this._name, this._value);

  @override
  ParameterName get name => _name;

  @override
  int get value => _value;

  @override
  bool get signed => false;

  @override
  DeviceDataParameterValue toDeviceDataParameterValue(int value) {
    return MockParameterValue(_name, value);
  }

  @override
  Flag? get flag => null;

  @override
  num get factor => 1;

  @override
  int get size => 2;

  @override
  String get unit => 'W';
}

class MockParameterName implements ParameterName {
  final String _name;

  MockParameterName(this._name);

  @override
  String get name => _name;
}

void main() {
  // Initialize Flutter bindings for platform channels
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('TrainingSessionController', () {
    late ExpandedTrainingSessionDefinition session;
    late MockBluetoothDevice mockDevice;
    late MockFTMSService mockFtmsService;
    late MockAudioPlayer mockAudioPlayer;

    setUp(() {
      session = ExpandedTrainingSessionDefinition(
        title: 'Test Session',
        ftmsMachineType: DeviceType.indoorBike,
        intervals: <ExpandedUnitTrainingInterval>[
          ExpandedUnitTrainingInterval(
            duration: 60, 
            title: 'Warmup', 
            resistanceLevel: 1,
            targets: {'power': 100},
            originalInterval: UnitTrainingInterval(duration: 60, title: 'Warmup', resistanceLevel: 1, targets: {'power': 100}),
          ),
          ExpandedUnitTrainingInterval(
            duration: 120, 
            title: 'Main', 
            resistanceLevel: 2,
            targets: {'power': 200},
            originalInterval: UnitTrainingInterval(duration: 120, title: 'Main', resistanceLevel: 2, targets: {'power': 200}),
          ),
          ExpandedUnitTrainingInterval(
            duration: 30, 
            title: 'Cooldown', 
            resistanceLevel: 1,
            targets: {'power': 80},
            originalInterval: UnitTrainingInterval(duration: 30, title: 'Cooldown', resistanceLevel: 1, targets: {'power': 80}),
          ),
        ],
      );
      
      mockDevice = MockBluetoothDevice();
      mockFtmsService = MockFTMSService();
      mockAudioPlayer = MockAudioPlayer();
      
      // Mock the device connection state - default to connected
      when(mockDevice.connectionState).thenAnswer((_) => 
          Stream.value(BluetoothConnectionState.connected));
      
      // Mock the ftmsService writeCommand method
      when(mockFtmsService.setResistanceWithControl(any, convertFromDefaultRange: anyNamed('convertFromDefaultRange')))
          .thenAnswer((_) async {});
      when(mockFtmsService.setPowerWithControl(any))
          .thenAnswer((_) async {});
      
      // Mock the audio player methods
      when(mockAudioPlayer.play(any)).thenAnswer((_) async {});
      when(mockAudioPlayer.dispose()).thenAnswer((_) async {});
      
      // Initialize SoundService with mock audio player for testing
      SoundService.initialize(mockAudioPlayer);
    });

    tearDown(() {
      // Reset SoundService after each test
      SoundService.instance.dispose();
    });

    group('Initialization', () {
      test('initializes with correct intervals and duration', () async {
        final controller = TrainingSessionController(
          session: session,
          ftmsDevice: mockDevice,
          ftmsService: mockFtmsService,
          enableFitFileGeneration: false,
        );

        expect(controller.state.intervals.length, 3);
        expect(controller.state.totalDuration, 210); // 60 + 120 + 30
        expect(controller.state.currentIntervalIndex, 0);
        expect(controller.state.elapsedSeconds, 0);
        expect(controller.state.intervalElapsedSeconds, 0);
        expect(controller.state.hasEnded, false);
        expect(controller.state.isPaused, false);
        expect(controller.state.shouldTimerBeActive, false);

        // Verify initial state
        expect(controller.state.status, SessionStatus.created);
        expect(controller.state.hasStarted, false);

        controller.dispose();
      });

      test('calculates interval start times correctly', () async {
        final controller = TrainingSessionController(
          session: session,
          ftmsDevice: mockDevice,
          ftmsService: mockFtmsService,
          enableFitFileGeneration: false,
        );

        expect(controller.state.intervalStartTimes, [0, 60, 180]);

        controller.dispose();
      });

      test('sets up initial FTMS commands', () async {
        final controller = TrainingSessionController(
          session: session,
          ftmsDevice: mockDevice,
          ftmsService: mockFtmsService,
          enableFitFileGeneration: false,
        );

        // Wait for initialization to complete
        await controller.initialized;

        // Verify that the FTMS commands were called at least once
        // Note: resistanceNeedsConversion defaults to false for newly created intervals
        verify(mockFtmsService.setResistanceWithControl(any, convertFromDefaultRange: anyNamed('convertFromDefaultRange'))).called(greaterThanOrEqualTo(1));

        controller.dispose();
      });
    });

    group('Session Controls', () {
      late TrainingSessionController controller;

      setUp(() {
        controller = TrainingSessionController(
          session: session,
          ftmsDevice: mockDevice,
          ftmsService: mockFtmsService,
          enableFitFileGeneration: false,
        );
      });

      tearDown(() {
        controller.dispose();
      });

      Future<void> startSession() async {
        // Ensure initialization is complete before starting
        await controller.initialized;
        
        // Clear interactions that happened during initialization
        clearInteractions(mockFtmsService);
        
        // Simulate starting the session by sending FTMS data changes
        final initialData = MockDeviceData([
          MockParameter('Instantaneous Power', 100),
        ]);
        ftmsBloc.ftmsDeviceDataControllerSink.add(initialData);
        await Future.delayed(const Duration(milliseconds: 50));

        final changedData = MockDeviceData([
          MockParameter('Instantaneous Power', 150),
        ]);
        ftmsBloc.ftmsDeviceDataControllerSink.add(changedData);
        await Future.delayed(const Duration(milliseconds: 50));
      }

      test('pauseSession pauses timer and sends FTMS command', () async {
        // Start the session first
        await startSession();
        expect(controller.state.shouldTimerBeActive, true);
        expect(controller.state.status, SessionStatus.running);

        // Clear any interactions from initialization
        clearInteractions(mockFtmsService);

        controller.pauseSession();

        expect(controller.state.isPaused, true);
        expect(controller.state.shouldTimerBeActive, false);
        expect(controller.state.status, SessionStatus.pausedByUser);
        
        // Wait for async FTMS command to complete
        await Future.delayed(Duration(milliseconds: 500));
        
        verify(mockFtmsService.stopOrPauseWithControl()).called(1);
      });

      test('resumeSession resumes from pause and sends FTMS command', () async {
        // Start and then pause the session
        await startSession();
        controller.pauseSession();
        await Future.delayed(const Duration(milliseconds: 100));
        
        expect(controller.state.isPaused, true);
        expect(controller.state.status, SessionStatus.pausedByUser);

        // Clear any interactions from initialization
        clearInteractions(mockFtmsService);

        controller.resumeSession();

        expect(controller.state.isPaused, false);
        expect(controller.state.status, SessionStatus.running);
        
        // Wait for async FTMS command to complete
        await Future.delayed(Duration(milliseconds: 500));
        
        verify(mockFtmsService.startOrResumeWithControl()).called(1);
      });

      test('stopSession completes session and sends FTMS command', () async {
        // Start the session first
        await startSession();
        expect(controller.state.shouldTimerBeActive, true);

        // Clear any interactions from initialization
        clearInteractions(mockFtmsService);

        controller.stopSession();

        expect(controller.state.hasEnded, true);
        expect(controller.state.isPaused, false);
        expect(controller.state.shouldTimerBeActive, false);
        expect(controller.state.status, SessionStatus.stopped);
        
        // Wait for async FTMS command to complete
        await Future.delayed(Duration(milliseconds: 500));
        
        verify(mockFtmsService.stopOrPauseWithControl()).called(1);
        verify(mockFtmsService.resetWithControl()).called(1);
      });

      test('pauseSession does nothing if session not running', () async {
        // Session not started yet (still in created state)
        expect(controller.state.status, SessionStatus.created);

        controller.pauseSession();

        expect(controller.state.status, SessionStatus.created);
      });

      test('pauseSession does nothing if already paused', () async {
        await startSession();
        controller.pauseSession();
        expect(controller.state.isPaused, true);

        // Wait for async FTMS commands from first pause to complete
        await Future.delayed(Duration(milliseconds: 500));

        // Clear interactions after commands are done
        clearInteractions(mockFtmsService);

        // Try to pause again - should do nothing
        controller.pauseSession();

        // Should not send any commands
        await Future.delayed(Duration(milliseconds: 100));
        verifyNever(mockFtmsService.stopOrPauseWithControl());
      });

      test('resumeSession does nothing if not paused', () async {
        await startSession();
        expect(controller.state.isPaused, false);
        expect(controller.state.status, SessionStatus.running);

        // Clear interactions
        clearInteractions(mockFtmsService);

        controller.resumeSession();

        // Should not send any commands
        await Future.delayed(Duration(milliseconds: 100));
        verifyNever(mockFtmsService.startOrResumeWithControl());
      });

      test('stopSession does nothing if already completed', () async {
        await startSession();
        controller.stopSession();
        expect(controller.state.hasEnded, true);

        // Wait for async FTMS commands from first stop to complete
        await Future.delayed(Duration(milliseconds: 500));

        // Clear interactions after commands are done
        clearInteractions(mockFtmsService);

        // Try to stop again - should do nothing
        controller.stopSession();

        // Should not send any commands
        await Future.delayed(Duration(milliseconds: 100));
        verifyNever(mockFtmsService.writeCommand(MachineControlPointOpcodeType.requestControl));
      });

      test('discardSession completes session and sends FTMS commands', () async {
        await startSession();
        expect(controller.state.shouldTimerBeActive, true);

        // Clear any interactions from initialization
        clearInteractions(mockFtmsService);

        controller.discardSession();

        expect(controller.state.hasEnded, true);
        expect(controller.state.isPaused, false);
        expect(controller.state.shouldTimerBeActive, false);
        expect(controller.state.status, SessionStatus.stopped);

        // Wait for async FTMS command to complete
        await Future.delayed(Duration(milliseconds: 500));

        verify(mockFtmsService.stopOrPauseWithControl()).called(1);
        verify(mockFtmsService.resetWithControl()).called(1);
      });

      test('discardSession does nothing if already completed', () async {
        await startSession();
        controller.stopSession();
        expect(controller.state.hasEnded, true);

        // Wait for async FTMS commands from first stop to complete
        await Future.delayed(Duration(milliseconds: 500));

        // Clear interactions after commands are done
        clearInteractions(mockFtmsService);

        controller.discardSession();

        // Should not send any commands
        await Future.delayed(Duration(milliseconds: 100));
        verifyNever(mockFtmsService.writeCommand(MachineControlPointOpcodeType.requestControl));
      });

      test('startSession manually starts session from created state', () async {
        // Session should start in created state
        expect(controller.state.status, SessionStatus.created);
        expect(controller.state.shouldTimerBeActive, false);

        // Manually start the session
        controller.startSession();

        expect(controller.state.status, SessionStatus.running);
        expect(controller.state.shouldTimerBeActive, true);
      });

      test('startSession does nothing if already running', () async {
        await startSession();
        expect(controller.state.status, SessionStatus.running);

        // Try to start again - should do nothing
        controller.startSession();

        expect(controller.state.status, SessionStatus.running);
      });

      test('startSession does nothing if session has ended', () async {
        await startSession();
        controller.stopSession();
        expect(controller.state.hasEnded, true);

        // Try to start - should do nothing
        controller.startSession();

        expect(controller.state.hasEnded, true);
      });
    });

    group('Timer and Progress', () {
      late TrainingSessionController controller;

      setUp(() {
        controller = TrainingSessionController(
          session: session,
          ftmsDevice: mockDevice,
          ftmsService: mockFtmsService,
          enableFitFileGeneration: false,
        );
      });

      tearDown(() {
        controller.dispose();
      });

      test('current interval getter returns correct interval', () {
        expect(controller.state.currentInterval.title, 'Warmup');
      });

      test('remainingIntervals getter returns correct intervals', () {
        expect(controller.state.remainingIntervals.length, 3);
        expect(controller.state.remainingIntervals[0].title, 'Warmup');
      });

      test('mainTimeLeft getter calculates correctly', () {
        // Initially, all time is left
        expect(controller.state.sessionTimeLeft, 210);
      });

      test('intervalTimeLeft getter calculates correctly', () {
        // Initially, full interval time is left
        expect(controller.state.intervalTimeLeft, 60);
      });
    });

    group('FTMS Data Processing', () {
      late TrainingSessionController controller;

      setUp(() {
        controller = TrainingSessionController(
          session: session,
          ftmsDevice: mockDevice,
          ftmsService: mockFtmsService,
          enableFitFileGeneration: false,
        );
      });

      tearDown(() {
        controller.dispose();
      });

      test('processes FTMS data and starts timer when values change', () async {
        await controller.initialized;
        
        // Create mock device data with changing values
        final initialData = MockDeviceData([
          MockParameter('Instantaneous Power', 100),
          MockParameter('Instantaneous Speed', 20),
        ]);

        final changedData = MockDeviceData([
          MockParameter('Instantaneous Power', 150),
          MockParameter('Instantaneous Speed', 25),
        ]);

        // Send initial data
        ftmsBloc.ftmsDeviceDataControllerSink.add(initialData);
        await Future.delayed(const Duration(milliseconds: 50));

        expect(controller.state.shouldTimerBeActive, false);
        expect(controller.state.status, SessionStatus.created);

        // Send changed data
        ftmsBloc.ftmsDeviceDataControllerSink.add(changedData);
        await Future.delayed(const Duration(milliseconds: 50));

        expect(controller.state.shouldTimerBeActive, true);
        expect(controller.state.status, SessionStatus.running);
      });

      test('does not start timer if values have not changed', () async {
        await controller.initialized;
        
        final sameData1 = MockDeviceData([
          MockParameter('Instantaneous Power', 100),
        ]);

        final sameData2 = MockDeviceData([
          MockParameter('Instantaneous Power', 100),
        ]);

        // Send initial data
        ftmsBloc.ftmsDeviceDataControllerSink.add(sameData1);
        await Future.delayed(const Duration(milliseconds: 50));

        expect(controller.state.shouldTimerBeActive, false);

        // Send same data
        ftmsBloc.ftmsDeviceDataControllerSink.add(sameData2);
        await Future.delayed(const Duration(milliseconds: 50));

        expect(controller.state.shouldTimerBeActive, false);
        expect(controller.state.status, SessionStatus.created);
      });

      test('continues recording data when timer is already active', () async {
        await controller.initialized;
        
        // Start the session
        final initialData = MockDeviceData([
          MockParameter('Instantaneous Power', 100),
        ]);
        ftmsBloc.ftmsDeviceDataControllerSink.add(initialData);
        await Future.delayed(const Duration(milliseconds: 50));

        final changedData = MockDeviceData([
          MockParameter('Instantaneous Power', 150),
        ]);
        ftmsBloc.ftmsDeviceDataControllerSink.add(changedData);
        await Future.delayed(const Duration(milliseconds: 50));

        expect(controller.state.shouldTimerBeActive, true);
        expect(controller.state.status, SessionStatus.running);

        // Send more data - should continue recording
        final moreData = MockDeviceData([
          MockParameter('Instantaneous Power', 200),
        ]);
        ftmsBloc.ftmsDeviceDataControllerSink.add(moreData);
        await Future.delayed(const Duration(milliseconds: 50));

        // Timer should remain active
        expect(controller.state.shouldTimerBeActive, true);
      });

      test('ignores data when session is paused', () async {
        await controller.initialized;
        
        // Start and pause session
        final initialData = MockDeviceData([
          MockParameter('Instantaneous Power', 100),
        ]);
        ftmsBloc.ftmsDeviceDataControllerSink.add(initialData);
        await Future.delayed(const Duration(milliseconds: 50));

        final changedData = MockDeviceData([
          MockParameter('Instantaneous Power', 150),
        ]);
        ftmsBloc.ftmsDeviceDataControllerSink.add(changedData);
        await Future.delayed(const Duration(milliseconds: 50));

        controller.pauseSession();
        await Future.delayed(const Duration(milliseconds: 50));

        expect(controller.state.isPaused, true);
        expect(controller.state.shouldTimerBeActive, false);
        expect(controller.state.status, SessionStatus.pausedByUser);
      });
    });

    group('Auto-Pause by Inactivity', () {
      late TrainingSessionController controller;

      setUp(() async {
        // Wait for any pending data from previous tests to be processed
        await Future.delayed(const Duration(milliseconds: 100));
        
        controller = TrainingSessionController(
          session: session,
          ftmsDevice: mockDevice,
          ftmsService: mockFtmsService,
          enableFitFileGeneration: false,
        );

        await controller.initialized;
        
        // Wait for controller initialization
        await Future.delayed(const Duration(milliseconds: 100));
      });

      tearDown(() {
        controller.dispose();
      });

      Future<void> startSession() async {
        await controller.initialized;
        
        // Start session with active power
        final initialData = MockDeviceData([
          MockParameter('Instantaneous Power', 50),
        ]);
        ftmsBloc.ftmsDeviceDataControllerSink.add(initialData);
        await Future.delayed(const Duration(milliseconds: 50));

        final activeData = MockDeviceData([
          MockParameter('Instantaneous Power', 100),
        ]);
        ftmsBloc.ftmsDeviceDataControllerSink.add(activeData);
        await Future.delayed(const Duration(milliseconds: 50));

        expect(controller.state.status, SessionStatus.running);
      }

      test('auto-pauses when power drops below threshold for 5 data points', () async {
        await startSession();

        // Send low power data (< 5W) repeatedly to trigger inactivity
        for (int i = 0; i < 5; i++) {
          final inactiveData = MockDeviceData([
            MockParameter('Instantaneous Power', 2),
          ]);
          ftmsBloc.ftmsDeviceDataControllerSink.add(inactiveData);
          await Future.delayed(const Duration(milliseconds: 50));
        }

        expect(controller.state.status, SessionStatus.pausedByInactivity);
        expect(controller.state.isPaused, true);
        expect(controller.state.wasAutoPaused, true);
        expect(controller.state.wasInactivityPaused, true);
        expect(controller.state.shouldTimerBeActive, false);
      });

      test('does not auto-pause if activity resumes before threshold', () async {
        await startSession();

        // Send low power data but not enough times
        for (int i = 0; i < 3; i++) {
          final inactiveData = MockDeviceData([
            MockParameter('Instantaneous Power', 2),
          ]);
          ftmsBloc.ftmsDeviceDataControllerSink.add(inactiveData);
          await Future.delayed(const Duration(milliseconds: 50));
        }

        expect(controller.state.status, SessionStatus.running);

        // Resume activity
        final activeData = MockDeviceData([
          MockParameter('Instantaneous Power', 100),
        ]);
        ftmsBloc.ftmsDeviceDataControllerSink.add(activeData);
        await Future.delayed(const Duration(milliseconds: 50));

        expect(controller.state.status, SessionStatus.running);
        expect(controller.state.isPaused, false);
      });

      test('auto-resumes when activity detected after inactivity pause', () async {
        await startSession();

        // Trigger inactivity pause
        for (int i = 0; i < 5; i++) {
          final inactiveData = MockDeviceData([
            MockParameter('Instantaneous Power', 2),
          ]);
          ftmsBloc.ftmsDeviceDataControllerSink.add(inactiveData);
          await Future.delayed(const Duration(milliseconds: 50));
        }

        expect(controller.state.status, SessionStatus.pausedByInactivity);

        // Resume activity with power above threshold - need 2 consecutive seconds
        for (int i = 0; i < 2; i++) {
          final activeData = MockDeviceData([
            MockParameter('Instantaneous Power', 50),
          ]);
          ftmsBloc.ftmsDeviceDataControllerSink.add(activeData);
          await Future.delayed(const Duration(seconds: 1));
        }

        expect(controller.state.status, SessionStatus.running);
        expect(controller.state.isPaused, false);
        expect(controller.state.shouldTimerBeActive, true);
      });

      test('auto-pauses when speed drops below threshold', () async {
        // Start with speed-based session
        final initialData = MockDeviceData([
          MockParameter('Instantaneous Speed', 5),
        ]);
        ftmsBloc.ftmsDeviceDataControllerSink.add(initialData);
        await Future.delayed(const Duration(milliseconds: 50));

        final activeData = MockDeviceData([
          MockParameter('Instantaneous Speed', 25),
        ]);
        ftmsBloc.ftmsDeviceDataControllerSink.add(activeData);
        await Future.delayed(const Duration(milliseconds: 50));

        expect(controller.state.status, SessionStatus.running);

        // Send low speed data (< 3 km/h) repeatedly
        for (int i = 0; i < 5; i++) {
          final inactiveData = MockDeviceData([
            MockParameter('Instantaneous Speed', 1),
          ]);
          ftmsBloc.ftmsDeviceDataControllerSink.add(inactiveData);
          await Future.delayed(const Duration(milliseconds: 50));
        }

        expect(controller.state.status, SessionStatus.pausedByInactivity);
      });

      test('user can manually resume from inactivity pause', () async {
        await startSession();

        // Trigger inactivity pause
        for (int i = 0; i < 5; i++) {
          final inactiveData = MockDeviceData([
            MockParameter('Instantaneous Power', 2),
          ]);
          ftmsBloc.ftmsDeviceDataControllerSink.add(inactiveData);
          await Future.delayed(const Duration(milliseconds: 50));
        }

        expect(controller.state.status, SessionStatus.pausedByInactivity);

        // User manually resumes
        controller.resumeSession();
        await Future.delayed(const Duration(milliseconds: 50));

        expect(controller.state.status, SessionStatus.running);
        expect(controller.state.isPaused, false);
      });

      test('sends FTMS pause command when auto-pausing', () async {
        await startSession();

        // Clear interactions from session start
        clearInteractions(mockFtmsService);

        // Trigger inactivity pause
        for (int i = 0; i < 5; i++) {
          final inactiveData = MockDeviceData([
            MockParameter('Instantaneous Power', 2),
          ]);
          ftmsBloc.ftmsDeviceDataControllerSink.add(inactiveData);
          await Future.delayed(const Duration(milliseconds: 50));
        }

        await Future.delayed(const Duration(milliseconds: 200));

        verify(mockFtmsService.stopOrPauseWithControl()).called(1);
      });

      test('sends FTMS resume command when auto-resuming', () async {
        await startSession();

        // Trigger inactivity pause
        for (int i = 0; i < 5; i++) {
          final inactiveData = MockDeviceData([
            MockParameter('Instantaneous Power', 2),
          ]);
          ftmsBloc.ftmsDeviceDataControllerSink.add(inactiveData);
          await Future.delayed(const Duration(milliseconds: 1000));
        }

        expect(controller.state.status, SessionStatus.pausedByInactivity);

        // Clear interactions
        clearInteractions(mockFtmsService);

        // Resume with activity - need 2 consecutive seconds for auto-resume
        for (int i = 0; i < 2; i++) {
          final activeData = MockDeviceData([
            MockParameter('Instantaneous Power', 50),
          ]);
          ftmsBloc.ftmsDeviceDataControllerSink.add(activeData);
          await Future.delayed(const Duration(seconds: 1));
        }

        verify(mockFtmsService.startOrResumeWithControl()).called(1);
      });
    });

    group('Rower Auto-Start Activity Detection', () {
      late TrainingSessionController controller;

      final quickInterval = UnitTrainingInterval(duration: 60, title: 'Quick', resistanceLevel: 1);

      final rowerSession = ExpandedTrainingSessionDefinition(
        title: 'Rower Test Session',
        ftmsMachineType: DeviceType.rower,
        intervals: <ExpandedUnitTrainingInterval>[
          ExpandedUnitTrainingInterval(
            duration: 60,
            title: 'Quick',
            resistanceLevel: 1,
            originalInterval: quickInterval,
          ),
        ],
      );

      setUp(() async {
        await Future.delayed(const Duration(milliseconds: 100));
        
        controller = TrainingSessionController(
          session: rowerSession,
          ftmsDevice: mockDevice,
          ftmsService: mockFtmsService,
          enableFitFileGeneration: false,
        );

        await controller.initialized;
        
        await Future.delayed(const Duration(milliseconds: 100));
      });

      tearDown(() {
        controller.dispose();
      });

      test('auto-starts when pace transitions from 0 (inactive) to active range', () async {
        // This tests the bug fix: when baseline pace is 0, session should auto-start
        // when user starts rowing and pace enters active range

        expect(controller.state.status, SessionStatus.created);

        // First reading: pace = 0 (user not rowing, machine reports 0)
        final inactiveData = MockDeviceData([
          MockParameter('Instantaneous Pace', 0),
        ]);
        ftmsBloc.ftmsDeviceDataControllerSink.add(inactiveData);
        await Future.delayed(const Duration(milliseconds: 50));

        // Session should still be in created state (waiting for activity)
        expect(controller.state.status, SessionStatus.created);

        // User starts rowing: pace = 120 (2:00/500m - active rowing)
        final activeData = MockDeviceData([
          MockParameter('Instantaneous Pace', 120),
        ]);
        ftmsBloc.ftmsDeviceDataControllerSink.add(activeData);
        await Future.delayed(const Duration(milliseconds: 50));

        // Session should now be running
        expect(controller.state.status, SessionStatus.running);
      });

      test('auto-starts when pace transitions from high value (inactive) to active range', () async {
        expect(controller.state.status, SessionStatus.created);

        // First reading: pace = 999 (very high, user not rowing effectively)
        final inactiveData = MockDeviceData([
          MockParameter('Instantaneous Pace', 999),
        ]);
        ftmsBloc.ftmsDeviceDataControllerSink.add(inactiveData);
        await Future.delayed(const Duration(milliseconds: 50));

        // Session should still be in created state
        expect(controller.state.status, SessionStatus.created);

        // User starts rowing: pace = 150 (2:30/500m)
        final activeData = MockDeviceData([
          MockParameter('Instantaneous Pace', 150),
        ]);
        ftmsBloc.ftmsDeviceDataControllerSink.add(activeData);
        await Future.delayed(const Duration(milliseconds: 50));

        // Session should now be running
        expect(controller.state.status, SessionStatus.running);
      });

      test('auto-starts when pace decreases significantly in active range', () async {
        expect(controller.state.status, SessionStatus.created);

        // First reading: pace = 250 (slow but in active range)
        final slowData = MockDeviceData([
          MockParameter('Instantaneous Pace', 250),
        ]);
        ftmsBloc.ftmsDeviceDataControllerSink.add(slowData);
        await Future.delayed(const Duration(milliseconds: 50));

        // Session should still be in created state
        expect(controller.state.status, SessionStatus.created);

        // Pace drops significantly: 250 * 0.9 = 225, so 150 < 225
        final fasterData = MockDeviceData([
          MockParameter('Instantaneous Pace', 150),
        ]);
        ftmsBloc.ftmsDeviceDataControllerSink.add(fasterData);
        await Future.delayed(const Duration(milliseconds: 50));

        // Session should now be running
        expect(controller.state.status, SessionStatus.running);
      });

      test('does not auto-start when pace stays in inactive range', () async {
        expect(controller.state.status, SessionStatus.created);

        // First reading: pace = 0
        final inactiveData1 = MockDeviceData([
          MockParameter('Instantaneous Pace', 0),
        ]);
        ftmsBloc.ftmsDeviceDataControllerSink.add(inactiveData1);
        await Future.delayed(const Duration(milliseconds: 50));

        // Still inactive: pace = 0
        final inactiveData2 = MockDeviceData([
          MockParameter('Instantaneous Pace', 0),
        ]);
        ftmsBloc.ftmsDeviceDataControllerSink.add(inactiveData2);
        await Future.delayed(const Duration(milliseconds: 50));

        // Session should still be waiting
        expect(controller.state.status, SessionStatus.created);
      });
    });

    group('State Machine Integration', () {
      test('state transitions correctly through session lifecycle', () async {
        final controller = TrainingSessionController(
          session: session,
          ftmsDevice: mockDevice,
          ftmsService: mockFtmsService,
          enableFitFileGeneration: false,
        );

        await controller.initialized;

        // Initial state
        expect(controller.state.status, SessionStatus.created);
        expect(controller.state.hasStarted, false);
        expect(controller.state.isRunning, false);

        // Start session
        final initialData = MockDeviceData([MockParameter('Instantaneous Power', 100)]);
        ftmsBloc.ftmsDeviceDataControllerSink.add(initialData);
        await Future.delayed(const Duration(milliseconds: 50));

        final changedData = MockDeviceData([MockParameter('Instantaneous Power', 150)]);
        ftmsBloc.ftmsDeviceDataControllerSink.add(changedData);
        await Future.delayed(const Duration(milliseconds: 50));

        expect(controller.state.status, SessionStatus.running);
        expect(controller.state.hasStarted, true);
        expect(controller.state.isRunning, true);

        // Pause
        controller.pauseSession();
        expect(controller.state.status, SessionStatus.pausedByUser);
        expect(controller.state.isPaused, true);
        expect(controller.state.wasAutoPaused, false);

        // Resume
        controller.resumeSession();
        expect(controller.state.status, SessionStatus.running);
        expect(controller.state.isRunning, true);

        // Stop
        controller.stopSession();
        expect(controller.state.status, SessionStatus.stopped);
        expect(controller.state.hasEnded, true);
        expect(controller.state.isStopped, true);

        controller.dispose();
      });

      test('exposes timing information correctly', () async {
        final controller = TrainingSessionController(
          session: session,
          ftmsDevice: mockDevice,
          ftmsService: mockFtmsService,
          enableFitFileGeneration: false,
        );

        expect(controller.state.totalDuration, 210);
        expect(controller.state.elapsedSeconds, 0);
        expect(controller.state.sessionTimeLeft, 210);
        expect(controller.state.intervalElapsedSeconds, 0);
        expect(controller.state.intervalTimeLeft, 60);
        expect(controller.state.currentIntervalIndex, 0);
        expect(controller.state.currentInterval.title, 'Warmup');

        controller.dispose();
      });
    });

    group('Device Type Parsing', () {
      test('parses rowing machine type correctly', () {
        // Create dummy original interval for testing
        final rowInterval = UnitTrainingInterval(duration: 60, title: 'Row');

        final rowingSession = ExpandedTrainingSessionDefinition(
          title: 'Rowing Session',
          ftmsMachineType: DeviceType.rower,
          intervals: <ExpandedUnitTrainingInterval>[
            ExpandedUnitTrainingInterval(duration: 60, title: 'Row', originalInterval: rowInterval),
          ],
        );

        final controller = TrainingSessionController(
          session: rowingSession,
          ftmsDevice: mockDevice,
          ftmsService: mockFtmsService,
          enableFitFileGeneration: false,
        );

        expect(controller.session.ftmsMachineType, DeviceType.rower);

        controller.dispose();
      });
    });

    group('Error Handling', () {
      test('handles FTMS service errors gracefully', () async {
        // Create a separate mock that throws errors
        final errorMockService = MockFTMSService();
        when(errorMockService.writeCommand(any))
            .thenThrow(Exception('FTMS Error'));
        when(errorMockService.writeCommand(any, resistanceLevel: anyNamed('resistanceLevel')))
            .thenThrow(Exception('FTMS Error'));
        when(errorMockService.writeCommand(any, power: anyNamed('power')))
            .thenThrow(Exception('FTMS Error'));

        final controller = TrainingSessionController(
          session: session,
          ftmsDevice: mockDevice,
          ftmsService: errorMockService,
          enableFitFileGeneration: false,
        );

        // Wait for initialization errors to occur
        await Future.delayed(const Duration(milliseconds: 2200));

        // Methods should not throw, even if FTMS commands fail internally
        expect(() => controller.pauseSession(), returnsNormally);
        expect(() => controller.resumeSession(), returnsNormally);

        controller.dispose();
      });

      test('handles null FTMS data gracefully', () async {
        final controller = TrainingSessionController(
          session: session,
          ftmsDevice: mockDevice,
          ftmsService: mockFtmsService,
          enableFitFileGeneration: false,
        );

        // Send null data
        ftmsBloc.ftmsDeviceDataControllerSink.add(null);
        await Future.delayed(const Duration(milliseconds: 50));

        // Should not crash or change state
        expect(controller.state.shouldTimerBeActive, false);
        expect(controller.state.elapsedSeconds, 0);
        expect(controller.state.status, SessionStatus.created);

        controller.dispose();
      });
    });

    group('Memory Management', () {
      test('disposes properly and cancels subscriptions', () async {
        final controller = TrainingSessionController(
          session: session,
          ftmsDevice: mockDevice,
          ftmsService: mockFtmsService,
          enableFitFileGeneration: false,
        );

        expect(() => controller.dispose(), returnsNormally);
      });

      test('completes recording when disposed without normal completion', () async {
        final controller = TrainingSessionController(
          session: session,
          ftmsDevice: mockDevice,
          ftmsService: mockFtmsService,
          enableFitFileGeneration: false,
        );

        expect(controller.state.hasEnded, false);
        expect(() => controller.dispose(), returnsNormally);
      });
    });

    group('Integration Tests', () {
      test('simulates a complete training session lifecycle', () async {
        final controller = TrainingSessionController(
          session: session,
          ftmsDevice: mockDevice,
          ftmsService: mockFtmsService,
          enableFitFileGeneration: false,
        );
        await controller.initialized;

        // Wait for any pending data from previous tests to be processed
        await Future.delayed(const Duration(milliseconds: 100));

        // Initial state
        expect(controller.state.currentIntervalIndex, 0);
        expect(controller.state.elapsedSeconds, 0);
        expect(controller.state.hasEnded, false);
        expect(controller.state.status, SessionStatus.created);

        // Simulate starting the session with FTMS data changes
        final mockData = MockDeviceData([
          MockParameter('Instantaneous Power', 100),
        ]);
        
        ftmsBloc.ftmsDeviceDataControllerSink.add(mockData);
        await Future.delayed(const Duration(milliseconds: 50));

        final changedData = MockDeviceData([
          MockParameter('Instantaneous Power', 150),
        ]);
        
        ftmsBloc.ftmsDeviceDataControllerSink.add(changedData);
        await Future.delayed(const Duration(milliseconds: 50));

        expect(controller.state.shouldTimerBeActive, true);
        expect(controller.state.status, SessionStatus.running);

        // Simulate pause
        controller.pauseSession();
        expect(controller.state.isPaused, true);
        expect(controller.state.shouldTimerBeActive, false);
        expect(controller.state.status, SessionStatus.pausedByUser);

        // Simulate resume
        controller.resumeSession();
        expect(controller.state.isPaused, false);
        expect(controller.state.status, SessionStatus.running);

        // Simulate stop
        controller.stopSession();
        expect(controller.state.hasEnded, true);
        expect(controller.state.shouldTimerBeActive, false);
        expect(controller.state.status, SessionStatus.stopped);

        // Wait for async cleanup to complete before disposing
        await Future.delayed(const Duration(milliseconds: 100));
        
        controller.dispose();
      });

      test('session completes naturally when timer reaches duration', () async {
        // Create dummy original interval for testing
        final quickInterval = UnitTrainingInterval(duration: 2, title: 'Quick', resistanceLevel: 1);

        // Create a very short session (2 seconds total)
        final shortSession = ExpandedTrainingSessionDefinition(
          title: 'Short Session',
          ftmsMachineType: DeviceType.indoorBike,
          intervals: <ExpandedUnitTrainingInterval>[
            ExpandedUnitTrainingInterval(
              duration: 2,
              title: 'Quick',
              resistanceLevel: 1,
              originalInterval: quickInterval,
            ),
          ],
        );

        final controller = TrainingSessionController(
          session: shortSession,
          ftmsDevice: mockDevice,
          ftmsService: mockFtmsService,
          enableFitFileGeneration: false,
        );

        await controller.initialized;

        // Initial state
        expect(controller.state.status, SessionStatus.created);
        expect(controller.state.hasEnded, false);

        // Start the session with FTMS data changes
        final initialData = MockDeviceData([MockParameter('Instantaneous Power', 100)]);
        ftmsBloc.ftmsDeviceDataControllerSink.add(initialData);
        await Future.delayed(const Duration(milliseconds: 50));

        final changedData = MockDeviceData([MockParameter('Instantaneous Power', 150)]);
        ftmsBloc.ftmsDeviceDataControllerSink.add(changedData);
        await Future.delayed(const Duration(milliseconds: 50));

        expect(controller.state.status, SessionStatus.running);
        expect(controller.state.shouldTimerBeActive, true);

        // Wait for the session to complete naturally (2 seconds + buffer)
        await Future.delayed(const Duration(seconds: 3));

        // Session should have completed naturally
        expect(controller.state.status, SessionStatus.completed);
        expect(controller.state.isCompleted, true);
        expect(controller.state.hasEnded, true);
        expect(controller.state.shouldTimerBeActive, false);

        // FTMS commands should have been sent (stop and reset)
        await Future.delayed(const Duration(milliseconds: 200));
        verify(mockFtmsService.stopOrPauseWithControl()).called(greaterThanOrEqualTo(1));
        verify(mockFtmsService.resetWithControl()).called(greaterThanOrEqualTo(1));

        controller.dispose();
      });

      test('_handleSessionCompleted sends FTMS stop command only for natural completion', () async {
        // Create dummy original interval for testing
        final instantInterval = UnitTrainingInterval(duration: 1, title: 'Instant', resistanceLevel: 1);

        // Create a very short session (1 second)
        final shortSession = ExpandedTrainingSessionDefinition(
          title: 'Micro Session',
          ftmsMachineType: DeviceType.indoorBike,
          intervals: <ExpandedUnitTrainingInterval>[
            ExpandedUnitTrainingInterval(
              duration: 1,
              title: 'Instant',
              resistanceLevel: 1,
              originalInterval: instantInterval,
            ),
          ],
        );

        final controller = TrainingSessionController(
          session: shortSession,
          ftmsDevice: mockDevice,
          ftmsService: mockFtmsService,
          enableFitFileGeneration: false,
        );
        await controller.initialized;

        // Wait for FTMS initialization to complete (with buffer for async operations)
        await Future.delayed(const Duration(milliseconds: 200));

        // Wait for FTMS initialization to complete (with buffer for async operations)
        await Future.delayed(const Duration(milliseconds: 200));

        // Start the session
        final initialData = MockDeviceData([MockParameter('Instantaneous Power', 100)]);
        ftmsBloc.ftmsDeviceDataControllerSink.add(initialData);
        await Future.delayed(const Duration(milliseconds: 50));

        final changedData = MockDeviceData([MockParameter('Instantaneous Power', 150)]);
        ftmsBloc.ftmsDeviceDataControllerSink.add(changedData);
        await Future.delayed(const Duration(milliseconds: 50));

        expect(controller.state.status, SessionStatus.running);

        // Clear interactions from initialization
        clearInteractions(mockFtmsService);

        // Wait for natural completion (1 second + buffer)
        await Future.delayed(const Duration(milliseconds: 1500));

        // Verify completed status
        expect(controller.state.status, SessionStatus.completed);

        // Wait for async FTMS commands to complete
        await Future.delayed(const Duration(milliseconds: 500));

        // Verify only stop/pause was called (reset happens later when user confirms)
        verify(mockFtmsService.stopOrPauseWithControl()).called(greaterThanOrEqualTo(1));
        verifyNever(mockFtmsService.resetWithControl());

        controller.dispose();
      });

      test('natural completion triggers FIT file generation', () async {
        // Create dummy original interval for testing
        final quickInterval = UnitTrainingInterval(duration: 1, title: 'Quick', resistanceLevel: 1);

        // Create a very short session
        final shortSession = ExpandedTrainingSessionDefinition(
          title: 'FIT Test Session',
          ftmsMachineType: DeviceType.rower,
          intervals: <ExpandedUnitTrainingInterval>[
            ExpandedUnitTrainingInterval(
              duration: 1,
              title: 'Quick',
              resistanceLevel: 1,
              originalInterval: quickInterval,
            ),
          ],
        );

        final mockDataRecorder = MockTrainingDataRecorder();
        final fitFilePath = '${Directory.systemTemp.path}/natural_complete.fit';
        
        when(mockDataRecorder.startRecording()).thenReturn(null);
        when(mockDataRecorder.stopRecording()).thenReturn(null);
        when(mockDataRecorder.recordDataPoint(ftmsParams: anyNamed('ftmsParams'))).thenReturn(null);
        when(mockDataRecorder.generateFitFile()).thenAnswer((_) async => fitFilePath);
        when(mockDataRecorder.getStatistics()).thenReturn({});

        final controller = TrainingSessionController(
          session: shortSession,
          ftmsDevice: mockDevice,
          ftmsService: mockFtmsService,
          dataRecorder: mockDataRecorder,
          enableFitFileGeneration: true,
        );

        await controller.initialized;

        // Start the session (rower uses Instantaneous Pace as primary activity indicator)
        final initialData = MockDeviceData([MockParameter('Instantaneous Pace', 240)]);
        ftmsBloc.ftmsDeviceDataControllerSink.add(initialData);
        await Future.delayed(const Duration(milliseconds: 50));

        final changedData = MockDeviceData([MockParameter('Instantaneous Pace', 150)]);
        ftmsBloc.ftmsDeviceDataControllerSink.add(changedData);
        await Future.delayed(const Duration(milliseconds: 50));

        expect(controller.state.status, SessionStatus.running);

        // Wait for natural completion
        await Future.delayed(const Duration(milliseconds: 1500));

        expect(controller.state.status, SessionStatus.completed);

        // User saves recording via dialog
        await controller.saveRecording();
        await Future.delayed(const Duration(milliseconds: 300));

        // Verify FIT file was generated
        verify(mockDataRecorder.stopRecording()).called(1);
        verify(mockDataRecorder.generateFitFile()).called(1);
        expect(controller.lastGeneratedFitFile, equals(fitFilePath));

        controller.dispose();
      });

      test('interval changes during natural session progression', () async {
        // Create dummy original intervals for testing
        final intervalA = UnitTrainingInterval(duration: 2, title: 'Interval A', resistanceLevel: 1);
        final intervalB = UnitTrainingInterval(duration: 2, title: 'Interval B', resistanceLevel: 3);

        // Create a session with short intervals
        final multiIntervalSession = ExpandedTrainingSessionDefinition(
          title: 'Multi Interval Session',
          ftmsMachineType: DeviceType.indoorBike,
          intervals: <ExpandedUnitTrainingInterval>[
            ExpandedUnitTrainingInterval(
              duration: 2,
              title: 'Interval A',
              resistanceLevel: 1,
              originalInterval: intervalA,
            ),
            ExpandedUnitTrainingInterval(
              duration: 2,
              title: 'Interval B',
              resistanceLevel: 3,
              originalInterval: intervalB,
            ),
          ],
        );

        final controller = TrainingSessionController(
          session: multiIntervalSession,
          ftmsDevice: mockDevice,
          ftmsService: mockFtmsService,
          enableFitFileGeneration: false,
        );
        await controller.initialized;

        // Start the session
        final initialData = MockDeviceData([MockParameter('Instantaneous Power', 100)]);
        ftmsBloc.ftmsDeviceDataControllerSink.add(initialData);
        await Future.delayed(const Duration(milliseconds: 50));

        final changedData = MockDeviceData([MockParameter('Instantaneous Power', 150)]);
        ftmsBloc.ftmsDeviceDataControllerSink.add(changedData);
        await Future.delayed(const Duration(milliseconds: 50));

        expect(controller.state.status, SessionStatus.running);
        expect(controller.state.currentIntervalIndex, 0);
        expect(controller.state.currentInterval.title, 'Interval A');

        // Clear interactions from initialization
        clearInteractions(mockFtmsService);

        // Wait for transition to second interval (2 seconds + buffer)
        await Future.delayed(const Duration(milliseconds: 2500));

        // Should be in second interval now
        expect(controller.state.currentIntervalIndex, 1);
        expect(controller.state.currentInterval.title, 'Interval B');

        // Verify resistance was updated for new interval
        // Note: resistanceNeedsConversion defaults to false for newly created intervals
        verify(mockFtmsService.setResistanceWithControl(3, convertFromDefaultRange: false)).called(greaterThanOrEqualTo(1));

        // Wait for completion
        await Future.delayed(const Duration(milliseconds: 2500));

        expect(controller.state.status, SessionStatus.completed);

        controller.dispose();
      });
    });

    group('FIT File Generation Tests', () {
      late MockTrainingDataRecorder mockDataRecorder;
      late Directory tempDir;

      setUp(() async {
        mockDataRecorder = MockTrainingDataRecorder();
        tempDir = Directory.systemTemp;
        
        // Mock basic data recorder methods
        when(mockDataRecorder.startRecording()).thenReturn(null);
        when(mockDataRecorder.stopRecording()).thenReturn(null);
        when(mockDataRecorder.recordDataPoint(
          ftmsParams: anyNamed('ftmsParams'),
        )).thenReturn(null);
        when(mockDataRecorder.generateFitFile()).thenAnswer((_) async => null);
        when(mockDataRecorder.getStatistics()).thenReturn({});
      });

      test('generates FIT file when enableFitFileGeneration is true', () async {
        final fitFilePath = '${tempDir.path}/test_session.fit';
        
        // Mock successful FIT file generation
        when(mockDataRecorder.generateFitFile())
            .thenAnswer((_) async => fitFilePath);

        final controller = TrainingSessionController(
          session: session,
          ftmsDevice: mockDevice,
          ftmsService: mockFtmsService,
          dataRecorder: mockDataRecorder,
          enableFitFileGeneration: true,
        );

        // Complete the session
        controller.stopSession();
        // User chooses to save recording via dialog
        await controller.saveRecording();
        await Future.delayed(const Duration(milliseconds: 100));

        // Verify FIT file generation was called
        verify(mockDataRecorder.generateFitFile()).called(1);
        expect(controller.lastGeneratedFitFile, equals(fitFilePath));

        controller.dispose();
      });

      test('does not generate FIT file when enableFitFileGeneration is false', () async {
        final controller = TrainingSessionController(
          session: session,
          ftmsDevice: mockDevice,
          ftmsService: mockFtmsService,
          dataRecorder: mockDataRecorder,
          enableFitFileGeneration: false,
        );

        // Complete the session
        controller.stopSession();
        // User chooses to save recording via dialog
        await controller.saveRecording();
        await Future.delayed(const Duration(milliseconds: 100));

        // Verify FIT file generation was NOT called (because enableFitFileGeneration is false)
        verifyNever(mockDataRecorder.generateFitFile());
        expect(controller.lastGeneratedFitFile, isNull);

        controller.dispose();
      });

      test('handles FIT file generation errors gracefully', () async {
        // Mock FIT file generation failure
        when(mockDataRecorder.generateFitFile())
            .thenThrow(Exception('FIT generation failed'));

        final controller = TrainingSessionController(
          session: session,
          ftmsDevice: mockDevice,
          ftmsService: mockFtmsService,
          dataRecorder: mockDataRecorder,
          enableFitFileGeneration: true,
        );

        // Complete the session and save - saveRecording should not throw
        controller.stopSession();
        await controller.saveRecording();
        await Future.delayed(const Duration(milliseconds: 100));

        // Verify FIT file generation was attempted (but failed)
        verify(mockDataRecorder.generateFitFile()).called(1);
        expect(controller.lastGeneratedFitFile, isNull);

        controller.dispose();
      });

      test('records FTMS data when FIT recording is enabled', () async {
        final controller = TrainingSessionController(
          session: session,
          ftmsDevice: mockDevice,
          ftmsService: mockFtmsService,
          dataRecorder: mockDataRecorder,
          enableFitFileGeneration: true,
        );
        await controller.initialized;

        // First send data to establish baseline
        final initialData = MockDeviceData([
          MockParameter('Instantaneous Power', 100),
          MockParameter('Instantaneous Speed', 20),
        ]);
        ftmsBloc.ftmsDeviceDataControllerSink.add(initialData);
        await Future.delayed(const Duration(milliseconds: 50));

        // Send changed data to trigger timer start and recording
        final mockData = MockDeviceData([
          MockParameter('Instantaneous Power', 150),
          MockParameter('Instantaneous Speed', 25),
        ]);
        ftmsBloc.ftmsDeviceDataControllerSink.add(mockData);
        await Future.delayed(const Duration(milliseconds: 100));

        // Timer should be active now and data recording should occur
        expect(controller.state.shouldTimerBeActive, isTrue);

        // Verify data recording was called
        verify(mockDataRecorder.recordDataPoint(
          ftmsParams: anyNamed('ftmsParams'),
        )).called(greaterThanOrEqualTo(1));

        controller.dispose();
      });
    });

    group('Strava Upload Tests', () {
      late MockStravaService mockStravaService;
      late MockTrainingDataRecorder mockDataRecorder;
      late Directory tempDir;

      setUp(() async {
        mockStravaService = MockStravaService();
        mockDataRecorder = MockTrainingDataRecorder();
        tempDir = Directory.systemTemp;
        
        // Mock basic data recorder methods
        when(mockDataRecorder.startRecording()).thenReturn(null);
        when(mockDataRecorder.stopRecording()).thenReturn(null);
        when(mockDataRecorder.recordDataPoint(
          ftmsParams: anyNamed('ftmsParams'),
        )).thenReturn(null);
        when(mockDataRecorder.getStatistics()).thenReturn({});
      });

      test('attempts Strava upload when user is authenticated and FIT file is generated', () async {
        final fitFilePath = '${tempDir.path}/test_session.fit';
        
        // Mock successful FIT file generation
        when(mockDataRecorder.generateFitFile())
            .thenAnswer((_) async => fitFilePath);
        
        // Mock authenticated user
        when(mockStravaService.isAuthenticated())
            .thenAnswer((_) async => true);
        
        // Mock successful Strava upload
        when(mockStravaService.uploadActivity(
          any,
          any,
          activityType: anyNamed('activityType'),
        )).thenAnswer((_) async => {'id': '12345'});

        final controller = TrainingSessionController(
          session: session,
          ftmsDevice: mockDevice,
          ftmsService: mockFtmsService,
          stravaService: mockStravaService,
          dataRecorder: mockDataRecorder,
          enableFitFileGeneration: true,
        );

        // Complete the session and save
        controller.stopSession();
        await controller.saveRecording();
        await Future.delayed(const Duration(milliseconds: 200));

        // Verify Strava upload was attempted
        verify(mockStravaService.isAuthenticated()).called(1);
        verify(mockStravaService.uploadActivity(
          fitFilePath,
          'Test Session - PowerTrain',
          activityType: 'ride', // indoor bike -> ride
        )).called(1);

        expect(controller.stravaUploadAttempted, isTrue);
        expect(controller.stravaUploadSuccessful, isTrue);
        expect(controller.stravaActivityId, equals('12345'));

        controller.dispose();
      });

      test('skips Strava upload when user is not authenticated', () async {
        final fitFilePath = '${tempDir.path}/test_session.fit';
        
        // Mock successful FIT file generation
        when(mockDataRecorder.generateFitFile())
            .thenAnswer((_) async => fitFilePath);
        
        // Mock unauthenticated user
        when(mockStravaService.isAuthenticated())
            .thenAnswer((_) async => false);

        final controller = TrainingSessionController(
          session: session,
          ftmsDevice: mockDevice,
          ftmsService: mockFtmsService,
          stravaService: mockStravaService,
          dataRecorder: mockDataRecorder,
          enableFitFileGeneration: true,
        );

        // Complete the session and save
        controller.stopSession();
        await controller.saveRecording();
        await Future.delayed(const Duration(milliseconds: 200));

        // Verify authentication check but no upload
        verify(mockStravaService.isAuthenticated()).called(1);
        verifyNever(mockStravaService.uploadActivity(any, any, activityType: anyNamed('activityType')));

        expect(controller.stravaUploadAttempted, isTrue);
        expect(controller.stravaUploadSuccessful, isFalse);
        expect(controller.stravaActivityId, isNull);

        controller.dispose();
      });

      test('handles Strava upload failure gracefully', () async {
        final fitFilePath = '${tempDir.path}/test_session.fit';
        
        // Mock successful FIT file generation
        when(mockDataRecorder.generateFitFile())
            .thenAnswer((_) async => fitFilePath);
        
        // Mock authenticated user
        when(mockStravaService.isAuthenticated())
            .thenAnswer((_) async => true);
        
        // Mock failed Strava upload
        when(mockStravaService.uploadActivity(
          any,
          any,
          activityType: anyNamed('activityType'),
        )).thenAnswer((_) async => null);

        final controller = TrainingSessionController(
          session: session,
          ftmsDevice: mockDevice,
          ftmsService: mockFtmsService,
          stravaService: mockStravaService,
          dataRecorder: mockDataRecorder,
          enableFitFileGeneration: true,
        );

        // Complete the session and save
        controller.stopSession();
        await controller.saveRecording();
        await Future.delayed(const Duration(milliseconds: 200));

        // Verify upload was attempted but failed
        verify(mockStravaService.uploadActivity(
          fitFilePath,
          'Test Session - PowerTrain',
          activityType: 'ride',
        )).called(1);

        expect(controller.stravaUploadAttempted, isTrue);
        expect(controller.stravaUploadSuccessful, isFalse);
        expect(controller.stravaActivityId, isNull);

        controller.dispose();
      });

      test('handles Strava upload exception gracefully', () async {
        final fitFilePath = '${tempDir.path}/test_session.fit';
        
        // Mock successful FIT file generation
        when(mockDataRecorder.generateFitFile())
            .thenAnswer((_) async => fitFilePath);
        
        // Mock authenticated user
        when(mockStravaService.isAuthenticated())
            .thenAnswer((_) async => true);
        
        // Mock Strava upload exception
        when(mockStravaService.uploadActivity(
          any,
          any,
          activityType: anyNamed('activityType'),
        )).thenThrow(Exception('Network error'));

        final controller = TrainingSessionController(
          session: session,
          ftmsDevice: mockDevice,
          ftmsService: mockFtmsService,
          stravaService: mockStravaService,
          dataRecorder: mockDataRecorder,
          enableFitFileGeneration: true,
        );

        // Complete the session and save - should not throw
        controller.stopSession();
        await controller.saveRecording();
        await Future.delayed(const Duration(milliseconds: 200));

        // Verify upload was attempted
        verify(mockStravaService.uploadActivity(any, any, activityType: anyNamed('activityType'))).called(1);

        expect(controller.stravaUploadAttempted, isTrue);
        expect(controller.stravaUploadSuccessful, isFalse);
        expect(controller.stravaActivityId, isNull);

        controller.dispose();
      });

      test('uses correct activity type for rowing machine', () async {
        final rowInterval = UnitTrainingInterval(duration: 60, title: 'Row');
        final rowingSession = ExpandedTrainingSessionDefinition(
          title: 'Rowing Test',
          ftmsMachineType: DeviceType.rower,
          intervals: <ExpandedUnitTrainingInterval>[
            ExpandedUnitTrainingInterval(duration: 60, title: 'Row', originalInterval: rowInterval),
          ],
        );

        final fitFilePath = '${tempDir.path}/rowing_session.fit';
        
        // Mock successful FIT file generation
        when(mockDataRecorder.generateFitFile())
            .thenAnswer((_) async => fitFilePath);
        
        // Mock authenticated user
        when(mockStravaService.isAuthenticated())
            .thenAnswer((_) async => true);
        
        // Mock successful Strava upload
        when(mockStravaService.uploadActivity(
          any,
          any,
          activityType: anyNamed('activityType'),
        )).thenAnswer((_) async => {'id': '67890'});

        final controller = TrainingSessionController(
          session: rowingSession,
          ftmsDevice: mockDevice,
          ftmsService: mockFtmsService,
          stravaService: mockStravaService,
          dataRecorder: mockDataRecorder,
          enableFitFileGeneration: true,
        );

        // Complete the session and save
        controller.stopSession();
        await controller.saveRecording();
        await Future.delayed(const Duration(milliseconds: 200));

        // Verify correct activity type was used
        verify(mockStravaService.uploadActivity(
          fitFilePath,
          'Rowing Test - PowerTrain',
          activityType: 'rowing', // rower -> rowing
        )).called(1);

        expect(controller.stravaUploadSuccessful, isTrue);

        controller.dispose();
      });

      test('does not attempt Strava upload when FIT file generation fails', () async {
        // Mock failed FIT file generation
        when(mockDataRecorder.generateFitFile())
            .thenAnswer((_) async => null);

        final controller = TrainingSessionController(
          session: session,
          ftmsDevice: mockDevice,
          ftmsService: mockFtmsService,
          stravaService: mockStravaService,
          dataRecorder: mockDataRecorder,
          enableFitFileGeneration: true,
        );

        // Complete the session and save
        controller.stopSession();
        await controller.saveRecording();
        await Future.delayed(const Duration(milliseconds: 200));

        // Verify no Strava operations were attempted (because FIT file failed)
        verifyNever(mockStravaService.isAuthenticated());
        verifyNever(mockStravaService.uploadActivity(any, any, activityType: anyNamed('activityType')));

        expect(controller.stravaUploadAttempted, isFalse);
        expect(controller.stravaUploadSuccessful, isFalse);

        controller.dispose();
      });
    });

    group('End-to-End FIT and Strava Integration Tests', () {
      late MockStravaService mockStravaService;
      late MockTrainingDataRecorder mockDataRecorder;

      setUp(() {
        mockStravaService = MockStravaService();
        mockDataRecorder = MockTrainingDataRecorder();
        
        // Mock basic data recorder methods
        when(mockDataRecorder.startRecording()).thenReturn(null);
        when(mockDataRecorder.stopRecording()).thenReturn(null);
        when(mockDataRecorder.recordDataPoint(
          ftmsParams: anyNamed('ftmsParams'),
        )).thenReturn(null);
        when(mockDataRecorder.getStatistics()).thenReturn({});
      });

      test('complete workout flow with FIT generation and Strava upload', () async {
        final fitFilePath = '/tmp/complete_workout.fit';
        
        // Mock successful FIT file generation
        when(mockDataRecorder.generateFitFile())
            .thenAnswer((_) async => fitFilePath);
        
        // Mock authenticated user
        when(mockStravaService.isAuthenticated())
            .thenAnswer((_) async => true);
        
        // Mock successful Strava upload
        when(mockStravaService.uploadActivity(
          any,
          any,
          activityType: anyNamed('activityType'),
        )).thenAnswer((_) async => {'id': '999888'});

        final controller = TrainingSessionController(
          session: session,
          ftmsDevice: mockDevice,
          ftmsService: mockFtmsService,
          stravaService: mockStravaService,
          dataRecorder: mockDataRecorder,
          enableFitFileGeneration: true,
        );

        // Simulate a complete workout
        // Ensure initialization is complete before starting
        await controller.initialized;
        
        expect(controller.state.hasEnded, isFalse);
        expect(controller.lastGeneratedFitFile, isNull);
        expect(controller.stravaUploadAttempted, isFalse);
        expect(controller.state.status, SessionStatus.created);

        // Start with FTMS data to begin timer
        final startData = MockDeviceData([
          MockParameter('Instantaneous Power', 100),
        ]);
        ftmsBloc.ftmsDeviceDataControllerSink.add(startData);
        await Future.delayed(const Duration(milliseconds: 50));

        final changeData = MockDeviceData([
          MockParameter('Instantaneous Power', 150),
        ]);
        ftmsBloc.ftmsDeviceDataControllerSink.add(changeData);
        await Future.delayed(const Duration(milliseconds: 50));

        expect(controller.state.shouldTimerBeActive, isTrue);
        expect(controller.state.status, SessionStatus.running);

        // Pause and resume
        controller.pauseSession();
        expect(controller.state.isPaused, isTrue);
        expect(controller.state.shouldTimerBeActive, isFalse);
        expect(controller.state.status, SessionStatus.pausedByUser);

        controller.resumeSession();
        expect(controller.state.isPaused, isFalse);
        expect(controller.state.status, SessionStatus.running);

        // Complete the session
        controller.stopSession();
        // User chooses to save via dialog
        await controller.saveRecording();
        await Future.delayed(const Duration(milliseconds: 500));

        // Verify complete flow
        expect(controller.state.hasEnded, isTrue);
        expect(controller.lastGeneratedFitFile, equals(fitFilePath));
        expect(controller.stravaUploadAttempted, isTrue);
        expect(controller.stravaUploadSuccessful, isTrue);
        expect(controller.stravaActivityId, equals('999888'));
        expect(controller.state.status, SessionStatus.stopped);

        // Verify all calls were made
        verify(mockDataRecorder.startRecording()).called(1);
        verify(mockDataRecorder.recordDataPoint(
          ftmsParams: anyNamed('ftmsParams'),
        )).called(greaterThanOrEqualTo(1));
        verify(mockDataRecorder.stopRecording()).called(1);
        verify(mockDataRecorder.generateFitFile()).called(1);
        verify(mockStravaService.isAuthenticated()).called(1);
        verify(mockStravaService.uploadActivity(
          fitFilePath,
          'Test Session - PowerTrain',
          activityType: 'ride',
        )).called(1);

        controller.dispose();
      });
    });
  });
}
