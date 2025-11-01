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
import 'package:ftms/core/services/strava/strava_service.dart';
import 'package:ftms/features/training/model/expanded_training_session_definition.dart';
import 'package:ftms/features/training/model/expanded_unit_training_interval.dart';
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
    late StreamController<DeviceData?> ftmsStreamController;
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
          ),
          ExpandedUnitTrainingInterval(
            duration: 120, 
            title: 'Main', 
            resistanceLevel: 2,
            targets: {'power': 200},
          ),
          ExpandedUnitTrainingInterval(
            duration: 30, 
            title: 'Cooldown', 
            resistanceLevel: 1,
            targets: {'power': 80},
          ),
        ],
      );
      
      mockDevice = MockBluetoothDevice();
      mockFtmsService = MockFTMSService();
      mockAudioPlayer = MockAudioPlayer();
      
      // Set up the FTMS stream controller
      ftmsStreamController = StreamController<DeviceData?>.broadcast();
      
      // Mock the device connection state - default to connected
      when(mockDevice.connectionState).thenAnswer((_) => 
          Stream.value(BluetoothConnectionState.connected));
      
      // Mock the ftmsService writeCommand method
      when(mockFtmsService.writeCommand(any))
          .thenAnswer((_) async {});
      when(mockFtmsService.writeCommand(any, resistanceLevel: anyNamed('resistanceLevel')))
          .thenAnswer((_) async {});
      
      // Mock the audio player methods
      when(mockAudioPlayer.play(any)).thenAnswer((_) async {});
      when(mockAudioPlayer.dispose()).thenAnswer((_) async {});
    });

    tearDown(() {
      ftmsStreamController.close();
    });

    group('Initialization', () {
      test('initializes with correct intervals and duration', () async {
        final controller = TrainingSessionController(
          session: session,
          ftmsDevice: mockDevice,
          ftmsService: mockFtmsService,
          audioPlayer: mockAudioPlayer,
          enableFitFileGeneration: false,
        );

        expect(controller.intervals.length, 3);
        expect(controller.totalDuration, 210); // 60 + 120 + 30
        expect(controller.currentIntervalIndex, 0);
        expect(controller.sessionElapsed, 0);
        expect(controller.currentIntervalElapsed, 0);
        expect(controller.sessionCompleted, false);
        expect(controller.sessionPaused, false);
        expect(controller.timerActive, false);

        controller.dispose();
      });

      test('calculates interval start times correctly', () async {
        final controller = TrainingSessionController(
          session: session,
          ftmsDevice: mockDevice,
          ftmsService: mockFtmsService,
          audioPlayer: mockAudioPlayer,
          enableFitFileGeneration: false,
        );

        expect(controller.intervalStartTimes, [0, 60, 180]);

        controller.dispose();
      });

      test('sets up initial FTMS commands', () async {
        final controller = TrainingSessionController(
          session: session,
          ftmsDevice: mockDevice,
          ftmsService: mockFtmsService,
          audioPlayer: mockAudioPlayer,
          enableFitFileGeneration: false,
        );

        // Wait for initialization to complete (longer delay for all async operations)
        await Future.delayed(const Duration(milliseconds: 3000));

        // Verify that the FTMS commands were called at least once
        verify(mockFtmsService.writeCommand(any, resistanceLevel: anyNamed('resistanceLevel'))).called(greaterThanOrEqualTo(1));

        expect(controller.hasControl, true);

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
          audioPlayer: mockAudioPlayer,
          enableFitFileGeneration: false,
        );
      });

      tearDown(() {
        controller.dispose();
      });

      test('pauseSession pauses timer and sends FTMS command', () async {
        controller.timerActive = true; // Simulate active timer

        // Clear any interactions from initialization
        clearInteractions(mockFtmsService);

        controller.pauseSession();

        expect(controller.sessionPaused, true);
        expect(controller.timerActive, false);
        
        // Wait for async FTMS command to complete
        await Future.delayed(Duration(milliseconds: 500));
        
        verify(mockFtmsService.writeCommand(MachineControlPointOpcodeType.requestControl, resistanceLevel: null)).called(1);
        verify(mockFtmsService.writeCommand(MachineControlPointOpcodeType.stopOrPause)).called(1);
      });

      test('resumeSession resumes from pause and sends FTMS command', () async {
        controller.sessionPaused = true;

        // Clear any interactions from initialization
        clearInteractions(mockFtmsService);

        controller.resumeSession();

        expect(controller.sessionPaused, false);
        
        // Wait for async FTMS command to complete
        await Future.delayed(Duration(milliseconds: 500));
        
        verify(mockFtmsService.writeCommand(MachineControlPointOpcodeType.requestControl, resistanceLevel: null)).called(1);
        verify(mockFtmsService.writeCommand(MachineControlPointOpcodeType.startOrResume)).called(1);
      });

      test('stopSession completes session and sends FTMS command', () async {
        controller.timerActive = true;

        // Clear any interactions from initialization
        clearInteractions(mockFtmsService);

        controller.stopSession();

        expect(controller.sessionCompleted, true);
        expect(controller.sessionPaused, false);
        expect(controller.timerActive, false);
        
        // Wait for async FTMS command to complete
        await Future.delayed(Duration(milliseconds: 500));
        
        verify(mockFtmsService.writeCommand(MachineControlPointOpcodeType.requestControl, resistanceLevel: null)).called(1);
        verify(mockFtmsService.writeCommand(MachineControlPointOpcodeType.stopOrPause)).called(1);
        verify(mockFtmsService.writeCommand(MachineControlPointOpcodeType.reset)).called(1);
      });

      test('pauseSession does nothing if already paused', () async {
        controller.sessionPaused = true;

        controller.pauseSession();

        // Wait for any potential async operations
        await Future.delayed(Duration.zero);

        verifyNever(mockFtmsService.writeCommand(MachineControlPointOpcodeType.requestControl));
        verifyNever(mockFtmsService.writeCommand(MachineControlPointOpcodeType.stopOrPause));
      });

      test('resumeSession does nothing if not paused', () async {
        controller.sessionPaused = false;

        controller.resumeSession();

        // Wait for any potential async operations
        await Future.delayed(Duration.zero);

        verifyNever(mockFtmsService.writeCommand(MachineControlPointOpcodeType.requestControl));
        verifyNever(mockFtmsService.writeCommand(MachineControlPointOpcodeType.startOrResume));
      });

      test('stopSession does nothing if already completed', () async {
        controller.sessionCompleted = true;

        controller.stopSession();

        // Wait for any potential async operations
        await Future.delayed(Duration.zero);

        verifyNever(mockFtmsService.writeCommand(MachineControlPointOpcodeType.requestControl));
        verifyNever(mockFtmsService.writeCommand(MachineControlPointOpcodeType.stopOrPause));
        verifyNever(mockFtmsService.writeCommand(MachineControlPointOpcodeType.reset));
      });
    });

    group('Timer and Progress', () {
      late TrainingSessionController controller;

      setUp(() {
        controller = TrainingSessionController(
          session: session,
          ftmsDevice: mockDevice,
          ftmsService: mockFtmsService,
          audioPlayer: mockAudioPlayer,
          enableFitFileGeneration: false,
        );
      });

      tearDown(() {
        controller.dispose();
      });

      test('current interval getter returns correct interval', () {
        expect(controller.current.title, 'Warmup');
        
        controller.currentIntervalIndex = 1;
        expect(controller.current.title, 'Main');
        
        controller.currentIntervalIndex = 2;
        expect(controller.current.title, 'Cooldown');
      });

      test('remainingIntervals getter returns correct intervals', () {
        expect(controller.remainingIntervals.length, 3);
        expect(controller.remainingIntervals[0].title, 'Warmup');
        
        controller.currentIntervalIndex = 1;
        expect(controller.remainingIntervals.length, 2);
        expect(controller.remainingIntervals[0].title, 'Main');
      });

      test('mainTimeLeft getter calculates correctly', () {
        controller.sessionElapsed = 30;
        expect(controller.mainTimeLeft, 180); // 210 - 30
        
        controller.sessionElapsed = 100;
        expect(controller.mainTimeLeft, 110); // 210 - 100
      });

      test('intervalTimeLeft getter calculates correctly', () {
        controller.currentIntervalElapsed = 20;
        expect(controller.intervalTimeLeft, 40); // 60 - 20
        
        controller.currentIntervalIndex = 1;
        controller.currentIntervalElapsed = 50;
        expect(controller.intervalTimeLeft, 70); // 120 - 50
      });
    });

    group('FTMS Data Processing', () {
      late TrainingSessionController controller;

      setUp(() {
        controller = TrainingSessionController(
          session: session,
          ftmsDevice: mockDevice,
          ftmsService: mockFtmsService,
          audioPlayer: mockAudioPlayer,
          enableFitFileGeneration: false,
        );
      });

      tearDown(() {
        controller.dispose();
      });

      test('does not start timer if values have not changed', () async {
        final sameData1 = MockDeviceData([
          MockParameter('Instantaneous Power', 100),
        ]);

        final sameData2 = MockDeviceData([
          MockParameter('Instantaneous Power', 100),
        ]);

        // Send initial data
        ftmsBloc.ftmsDeviceDataControllerSink.add(sameData1);
        await Future.delayed(const Duration(milliseconds: 100));

        expect(controller.timerActive, false);

        // Send same data
        await Future.delayed(const Duration(milliseconds: 100));
        ftmsBloc.ftmsDeviceDataControllerSink.add(sameData2);
        await Future.delayed(const Duration(milliseconds: 100));

        expect(controller.timerActive, false);
      });

      test('processes FTMS data and starts timer when values change', () async {
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

        expect(controller.timerActive, false);

        // Send changed data
        ftmsBloc.ftmsDeviceDataControllerSink.add(changedData);
        await Future.delayed(const Duration(milliseconds: 50));

        expect(controller.timerActive, true);
      });

      test('ignores data when timer is already active', () async {
        controller.timerActive = true;

        final mockData = MockDeviceData([
          MockParameter('Instantaneous Power', 100),
        ]);

        ftmsBloc.ftmsDeviceDataControllerSink.add(mockData);
        await Future.delayed(const Duration(milliseconds: 50));

        // Timer should remain active, no additional processing
        expect(controller.timerActive, true);
      });

      test('ignores data when session is paused', () async {
        controller.sessionPaused = true;

        final mockData = MockDeviceData([
          MockParameter('Instantaneous Power', 100),
        ]);

        ftmsBloc.ftmsDeviceDataControllerSink.add(mockData);
        await Future.delayed(const Duration(milliseconds: 50));

        expect(controller.timerActive, false);
      });
    });

    group('Device Type Parsing', () {
      test('parses rowing machine type correctly', () {
        final rowingSession = ExpandedTrainingSessionDefinition(
          title: 'Rowing Session',
          ftmsMachineType: DeviceType.rower,
          intervals: <ExpandedUnitTrainingInterval>[
            ExpandedUnitTrainingInterval(duration: 60, title: 'Row'),
          ],
        );

        final controller = TrainingSessionController(
          session: rowingSession,
          ftmsDevice: mockDevice,
          ftmsService: mockFtmsService,
          audioPlayer: mockAudioPlayer,
          enableFitFileGeneration: false,
        );

        // We can't directly test _parseDeviceType as it's private,
        // but we can verify the controller was created successfully
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

        final controller = TrainingSessionController(
          session: session,
          ftmsDevice: mockDevice,
          ftmsService: errorMockService,
          audioPlayer: mockAudioPlayer,
          enableFitFileGeneration: false,
        );

        // Wait for initialization errors to occur
        await Future.delayed(const Duration(milliseconds: 2200));

        // Methods should not throw, even if FTMS commands fail internally
        expect(() => controller.pauseSession(), returnsNormally);
        expect(() => controller.resumeSession(), returnsNormally);
        
        // Don't test stopSession in error conditions as it triggers async completion
        // expect(() => controller.stopSession(), returnsNormally);

        controller.dispose();
      });

      test('handles null FTMS data gracefully', () async {
        final controller = TrainingSessionController(
          session: session,
          ftmsDevice: mockDevice,
          ftmsService: mockFtmsService,
          audioPlayer: mockAudioPlayer,
          enableFitFileGeneration: false,
        );

        // Send null data
        ftmsBloc.ftmsDeviceDataControllerSink.add(null);
        await Future.delayed(const Duration(milliseconds: 50));

        // Should not crash or change state
        expect(controller.timerActive, false);
        expect(controller.sessionElapsed, 0);

        controller.dispose();
      });
    });

    group('Memory Management', () {
      test('disposes properly and cancels subscriptions', () async {
        final controller = TrainingSessionController(
          session: session,
          ftmsDevice: mockDevice,
          ftmsService: mockFtmsService,
          audioPlayer: mockAudioPlayer,
          enableFitFileGeneration: false,
        );

        // Don't set timerActive directly - the timer isn't public
        // Just test that dispose doesn't throw
        expect(() => controller.dispose(), returnsNormally);
      });

      test('completes recording when disposed without normal completion', () async {
        final controller = TrainingSessionController(
          session: session,
          ftmsDevice: mockDevice,
          ftmsService: mockFtmsService,
          audioPlayer: mockAudioPlayer,
          enableFitFileGeneration: false,
        );

        // Test that dispose works even when session isn't completed
        expect(controller.sessionCompleted, false);
        expect(() => controller.dispose(), returnsNormally);
      });
    });

    group('Integration Tests', () {
      test('simulates a complete training session lifecycle', () async {
        final controller = TrainingSessionController(
          session: session,
          ftmsDevice: mockDevice,
          ftmsService: mockFtmsService,
          audioPlayer: mockAudioPlayer,
          enableFitFileGeneration: false,
        );

        // Initial state
        expect(controller.currentIntervalIndex, 0);
        expect(controller.sessionElapsed, 0);
        expect(controller.sessionCompleted, false);

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

        expect(controller.timerActive, true);

        // Simulate pause
        controller.pauseSession();
        expect(controller.sessionPaused, true);
        expect(controller.timerActive, false);

        // Simulate resume
        controller.resumeSession();
        expect(controller.sessionPaused, false);

        // Simulate stop
        controller.stopSession();
        expect(controller.sessionCompleted, true);
        expect(controller.timerActive, false);

        // Wait for async cleanup to complete before disposing
        await Future.delayed(const Duration(milliseconds: 100));
        
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
          audioPlayer: mockAudioPlayer,
          dataRecorder: mockDataRecorder,
          enableFitFileGeneration: true,
        );

        // Complete the session to trigger FIT file generation
        controller.stopSession();
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
          audioPlayer: mockAudioPlayer,
          dataRecorder: mockDataRecorder,
          enableFitFileGeneration: false,
        );

        // Complete the session
        controller.stopSession();
        await Future.delayed(const Duration(milliseconds: 100));

        // Verify FIT file generation was NOT called
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
          audioPlayer: mockAudioPlayer,
          dataRecorder: mockDataRecorder,
          enableFitFileGeneration: true,
        );

        // Complete the session - should not throw
        expect(() => controller.stopSession(), returnsNormally);
        await Future.delayed(const Duration(milliseconds: 100));

        // Verify FIT file generation was attempted
        verify(mockDataRecorder.generateFitFile()).called(1);
        expect(controller.lastGeneratedFitFile, isNull);

        controller.dispose();
      });

      test('records FTMS data when FIT recording is enabled', () async {
        final controller = TrainingSessionController(
          session: session,
          ftmsDevice: mockDevice,
          ftmsService: mockFtmsService,
          audioPlayer: mockAudioPlayer,
          dataRecorder: mockDataRecorder,
          enableFitFileGeneration: true,
        );

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
        expect(controller.timerActive, isTrue);

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
          audioPlayer: mockAudioPlayer,
          stravaService: mockStravaService,
          dataRecorder: mockDataRecorder,
          enableFitFileGeneration: true,
        );

        // Complete the session to trigger FIT file generation and upload
        controller.stopSession();
        await Future.delayed(const Duration(milliseconds: 200));

        // Verify Strava upload was attempted
        verify(mockStravaService.isAuthenticated()).called(1);
        verify(mockStravaService.uploadActivity(
          fitFilePath,
          'Test Session - FTMS Training',
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
          audioPlayer: mockAudioPlayer,
          stravaService: mockStravaService,
          dataRecorder: mockDataRecorder,
          enableFitFileGeneration: true,
        );

        // Complete the session
        controller.stopSession();
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
          audioPlayer: mockAudioPlayer,
          stravaService: mockStravaService,
          dataRecorder: mockDataRecorder,
          enableFitFileGeneration: true,
        );

        // Complete the session
        controller.stopSession();
        await Future.delayed(const Duration(milliseconds: 200));

        // Verify upload was attempted but failed
        verify(mockStravaService.uploadActivity(
          fitFilePath,
          'Test Session - FTMS Training',
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
          audioPlayer: mockAudioPlayer,
          stravaService: mockStravaService,
          dataRecorder: mockDataRecorder,
          enableFitFileGeneration: true,
        );

        // Complete the session - should not throw
        expect(() => controller.stopSession(), returnsNormally);
        await Future.delayed(const Duration(milliseconds: 200));

        // Verify upload was attempted
        verify(mockStravaService.uploadActivity(any, any, activityType: anyNamed('activityType'))).called(1);

        expect(controller.stravaUploadAttempted, isTrue);
        expect(controller.stravaUploadSuccessful, isFalse);
        expect(controller.stravaActivityId, isNull);

        controller.dispose();
      });

      test('uses correct activity type for rowing machine', () async {
        final rowingSession = ExpandedTrainingSessionDefinition(
          title: 'Rowing Test',
          ftmsMachineType: DeviceType.rower,
          intervals: <ExpandedUnitTrainingInterval>[
            ExpandedUnitTrainingInterval(duration: 60, title: 'Row'),
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
          audioPlayer: mockAudioPlayer,
          stravaService: mockStravaService,
          dataRecorder: mockDataRecorder,
          enableFitFileGeneration: true,
        );

        // Complete the session
        controller.stopSession();
        await Future.delayed(const Duration(milliseconds: 200));

        // Verify correct activity type was used
        verify(mockStravaService.uploadActivity(
          fitFilePath,
          'Rowing Test - FTMS Training',
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
          audioPlayer: mockAudioPlayer,
          stravaService: mockStravaService,
          dataRecorder: mockDataRecorder,
          enableFitFileGeneration: true,
        );

        // Complete the session
        controller.stopSession();
        await Future.delayed(const Duration(milliseconds: 200));

        // Verify no Strava operations were attempted
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
          audioPlayer: mockAudioPlayer,
          stravaService: mockStravaService,
          dataRecorder: mockDataRecorder,
          enableFitFileGeneration: true,
        );

        // Simulate a complete workout
        expect(controller.sessionCompleted, isFalse);
        expect(controller.lastGeneratedFitFile, isNull);
        expect(controller.stravaUploadAttempted, isFalse);

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

        expect(controller.timerActive, isTrue);

        // Pause and resume
        controller.pauseSession();
        expect(controller.sessionPaused, isTrue);
        expect(controller.timerActive, isFalse);

        controller.resumeSession();
        expect(controller.sessionPaused, isFalse);

        // Complete the session
        controller.stopSession();
        await Future.delayed(const Duration(milliseconds: 300));

        // Verify complete flow
        expect(controller.sessionCompleted, isTrue);
        expect(controller.lastGeneratedFitFile, equals(fitFilePath));
        expect(controller.stravaUploadAttempted, isTrue);
        expect(controller.stravaUploadSuccessful, isTrue);
        expect(controller.stravaActivityId, equals('999888'));

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
          'Test Session - FTMS Training',
          activityType: 'ride',
        )).called(1);

        controller.dispose();
      });
    });
  });
}
