import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ftms/flutter_ftms.dart';
import 'package:ftms/core/models/device_types.dart';
import 'package:ftms/features/training/model/expanded_training_session_definition.dart';
import 'package:ftms/features/training/model/expanded_unit_training_interval.dart';
import 'package:ftms/features/training/model/session_state.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/bloc/ftms_bloc.dart';
import '../../core/config/live_data_display_config.dart';
import '../../core/services/fit/training_data_recorder.dart';
import '../../core/services/ftms_data_processor.dart';
import '../../core/services/ftms_service.dart';
import '../../core/services/strava/strava_activity_types.dart';
import '../../core/services/strava/strava_service.dart';
import '../../core/utils/logger.dart';

class TrainingSessionController extends ChangeNotifier {
  final ExpandedTrainingSessionDefinition session;
  final BluetoothDevice ftmsDevice;
  late final FTMSService _ftmsService;
  late final Stream<DeviceData?> _ftmsStream;
  late final StreamSubscription<DeviceData?> _ftmsSub;
  late final StreamSubscription<BluetoothConnectionState> _connectionStateSub;
  Timer? _timer;

  // FIT file recording
  TrainingDataRecorder? _dataRecorder;
  final FtmsDataProcessor _dataProcessor = FtmsDataProcessor();
  bool _isRecordingConfigured = false;
  final bool _enableFitFileGeneration;
  late final StravaService _stravaService;

  // Audio player for warning sounds
  AudioPlayer? _audioPlayer;

  // Session state machine
  late TrainingSessionState _state;

  // For detecting data changes
  List<dynamic>? _lastFtmsParams;

  // Strava upload tracking
  String? lastGeneratedFitFile;
  bool stravaUploadAttempted = false;
  bool stravaUploadSuccessful = false;
  String? stravaActivityId;

  // Allow injection of dependencies for testing
  TrainingSessionController({
    required this.session,
    required this.ftmsDevice,
    FTMSService? ftmsService,
    StravaService? stravaService,
    TrainingDataRecorder? dataRecorder,
    bool enableFitFileGeneration = true, // Allow disabling for tests
    AudioPlayer? audioPlayer, // Allow injection for testing
  }) : _enableFitFileGeneration = enableFitFileGeneration {
    _ftmsService = ftmsService ?? FTMSService(ftmsDevice);
    _stravaService = stravaService ?? StravaService();

    // Initialize session state
    _state = TrainingSessionState.initial(session);

    // Initialize audio player with error handling for tests
    _initAudioPlayer(audioPlayer);
    _dataRecorder = dataRecorder;

    // Ensure wakelock stays enabled during training sessions
    _enableWakeLock();

    _ftmsStream = ftmsBloc.ftmsDeviceDataControllerStream;
    _ftmsSub = _ftmsStream.listen(_onFtmsData);
    _connectionStateSub =
        ftmsDevice.connectionState.listen(_onConnectionStateChanged);
    _initFTMS();
    _initDataRecording();
  }

  void _enableWakeLock() {
    // Ensure wakelock stays enabled during training sessions
    WakelockPlus.enable().catchError((e) {
      debugPrint('Failed to enable wakelock during training: $e');
    });
  }

  void _initAudioPlayer(AudioPlayer? audioPlayer) {
    // Initialize audio player with error handling for tests
    if (audioPlayer != null) {
      _audioPlayer = audioPlayer;
    } else {
      try {
        _audioPlayer = AudioPlayer();
      } catch (e) {
        debugPrint(
            'Failed to initialize AudioPlayer (likely in test environment): $e');
        _audioPlayer = null;
      }
    }
  }

  // ============ Public getters (delegating to state) ============

  /// The current session state - consumers should access state properties directly
  /// e.g., controller.state.isPaused, controller.state.elapsedSeconds, etc.
  TrainingSessionState get state => _state;

  // ============ Initialization ============

  void _initFTMS() {
    // Request control after a short delay, then start session and set initial resistance if needed
    Future.delayed(const Duration(seconds: 2), () async {
      if (_disposed) return;
      await startOrResumeWithControl();
      final firstInterval =
          _state.intervals.isNotEmpty ? _state.intervals[0] : null;
      if (firstInterval != null) {
        final firstResistance = firstInterval.resistanceLevel;
        if (firstResistance != null) {
          await setResistanceWithControl(firstResistance);
        }
        final firstPower = firstInterval.targets?['Instantaneous Power'];
        if (firstPower != null) {
          await setPowerWithControl(firstPower);
        }
      }
    });
  }

  Future<void> _initDataRecording() async {
    try {
      // Get device type from the machine type string
      final deviceType = session.ftmsMachineType;

      // Load config for data processor
      final config =
          await LiveDataDisplayConfig.loadForFtmsMachineType(deviceType);
      if (config != null) {
        _dataProcessor.configure(config);
        _isRecordingConfigured = true;
      }

      // Initialize data recorder only if not injected for testing
      _dataRecorder ??= TrainingDataRecorder(
        sessionName: session.title,
        deviceType: deviceType,
      );
      _dataRecorder!.startRecording();
    } catch (e) {
      debugPrint('Failed to initialize data recording: $e');
    }
  }

  // ============ Event handlers ============

  void _onFtmsData(DeviceData? data) {
    if (data == null) return;

    // Record data if session is running
    if (_state.isRunning) {
      _recordDataPoint(data);
      return;
    }

    // If paused, still record but don't check for changes
    if (_state.isPaused) {
      return;
    }

    // Check if data changed to trigger session start
    final params = data.getDeviceDataParameterValues();
    if (_lastFtmsParams != null && _state.status == SessionStatus.created) {
      bool changed = false;
      for (int i = 0; i < params.length; i++) {
        final prev = _lastFtmsParams![i];
        final curr = params[i].value;
        if (prev != curr) {
          changed = true;
          break;
        }
      }
      if (changed) {
        _processEvent(SessionEvent.dataChanged);
        _recordDataPoint(data);
      }
    }
    // Store current values for next comparison
    _lastFtmsParams = params.map((p) => p.value).toList();
  }

  void _recordDataPoint(DeviceData data) {
    if (_dataRecorder == null || !_isRecordingConfigured || !_state.isRunning) {
      return;
    }
    try {
      final paramValueMap = _dataProcessor.processDeviceData(data);
      _dataRecorder!.recordDataPoint(ftmsParams: paramValueMap);
    } catch (e) {
      debugPrint('Failed to record data point: $e');
    }
  }

  void _onConnectionStateChanged(BluetoothConnectionState connectionState) {
    final wasConnected = _state.isDeviceConnected;
    final isNowConnected =
        connectionState == BluetoothConnectionState.connected;

    logger.i(
        '🔗 FTMS device connection state changed: $connectionState (was connected: $wasConnected, now connected: $isNowConnected)');

    if (wasConnected && !isNowConnected) {
      // Device disconnected
      logger.w('📱 FTMS device disconnected during training');
      _processEvent(SessionEvent.deviceDisconnected);
    } else if (!wasConnected && isNowConnected) {
      // Device reconnected
      logger.i('📱 FTMS device reconnected');
      _processEvent(SessionEvent.deviceReconnected);
    }
  }

  // ============ Timer management ============

  void _startTimer() {
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _onTick() {
    if (!_state.isRunning) return;
    _processEvent(SessionEvent.timerTick);
    debugPrint(
        '🕐 Timer tick: elapsed=${_state.elapsedSeconds}, status=${_state.status}');
  }

  // ============ State transition and effect handling ============

  void _processEvent(SessionEvent event) {
    final result = _state.processEventWithEffects(event);
    if (result.state != _state) {
      _state = result.state;
    }
    _executeEffects(result.effects);
  }

  void _executeEffects(List<SessionEffect> effects) {
    for (final effect in effects) {
      _executeEffect(effect);
    }
  }

  void _executeEffect(SessionEffect effect) {
    switch (effect) {
      case StartTimer():
        _startTimer();
      case StopTimer():
        _stopTimer();
      case PlayWarningSound():
        _playWarningSound();
      case IntervalChanged(newInterval: final interval):
        _handleIntervalChanged(interval);
      case SessionCompleted():
        _handleSessionCompleted();
      case SendFtmsPause():
        _sendFtmsPause();
      case SendFtmsResume():
        _sendFtmsResume();
      case SendFtmsStopAndReset():
        _sendFtmsStopAndReset();
      case NotifyListeners():
        if (!_disposed) notifyListeners();
    }
  }

  // ============ Effect handlers (unitary operations) ============

  void _handleIntervalChanged(ExpandedUnitTrainingInterval interval) {
    final resistance = interval.resistanceLevel;
    if (resistance != null) {
      setResistanceWithControl(resistance);
    }
    final power = interval.targets?['Instantaneous Power'];
    if (power != null) {
      setPowerWithControl(power);
    }
  }

  void _handleSessionCompleted() {
    Future.microtask(() async {
      if (_disposed) return;
      await stopOrPauseWithControl();
      await resetWithControl();
    });

    _finishRecording().then((_) {
      if (!_disposed) notifyListeners();
    });
  }

  void _sendFtmsPause() {
    Future.microtask(() async {
      if (_disposed) return;
      await stopOrPauseWithControl();
    });
  }

  void _sendFtmsResume() {
    Future.microtask(() async {
      if (_disposed) return;
      await startOrResumeWithControl();
    });
  }

  void _sendFtmsStopAndReset() {
    Future.microtask(() async {
      if (_disposed) return;
      await stopOrPauseWithControl();
      await resetWithControl();
    });
  }

  // ============ Audio ============

  Future<void> _playWarningSound() async {
    if (_audioPlayer == null) {
      debugPrint('🔔 AudioPlayer not available, skipping sound playback');
      return;
    }

    try {
      await _audioPlayer!.play(AssetSource('sounds/beep.wav'));
      debugPrint('🔔 Played custom beep sound');
    } catch (e) {
      debugPrint('🔔 Failed to play warning sound: $e');
    }
  }

  // ============ Recording and Strava ============

  Future<void> _finishRecording() async {
    if (_dataRecorder != null) {
      try {
        _dataRecorder!.stopRecording();

        if (_enableFitFileGeneration) {
          final fitFilePath = await _dataRecorder!.generateFitFile();
          lastGeneratedFitFile = fitFilePath;
          logger.i(
              '***************** Training session completed successfully. FIT file saved to: $fitFilePath');
          debugPrint('FIT file generated: $fitFilePath');

          if (fitFilePath != null) {
            await _attemptStravaUpload(fitFilePath);
            await _deleteFitFile(fitFilePath);
          }
        } else {
          logger.i(
              '***************** Training session completed successfully. FIT file generation disabled.');
        }
      } catch (e) {
        logger.e('**************** Failed to generate FIT file: $e');
        debugPrint('***************** Failed to generate FIT file: $e');
      }
    }
  }

  Future<void> _deleteFitFile(String fitFilePath) async {
    if (stravaUploadSuccessful) {
      try {
        final file = File(fitFilePath);
        if (await file.exists()) {
          await file.delete();
          logger.i(
              '🗑️ FIT file deleted after successful Strava upload: $fitFilePath');
          debugPrint('FIT file deleted: $fitFilePath');
        }
      } catch (e) {
        logger.w('Failed to delete FIT file after Strava upload: $e');
        debugPrint('Failed to delete FIT file: $e');
      }
    }
  }

  Future<void> _attemptStravaUpload(String fitFilePath) async {
    stravaUploadAttempted = true;

    try {
      final isAuthenticated = await _stravaService.isAuthenticated();
      if (!isAuthenticated) {
        logger.i('Strava upload skipped: User not authenticated');
        if (!_disposed) notifyListeners();
        return;
      }

      logger.i('Attempting automatic Strava upload...');

      final activityName = '${session.title} - FTMS Training';
      final deviceType = session.ftmsMachineType;
      final activityType = StravaActivityTypes.fromFtmsMachineType(deviceType);

      final uploadResult = await _stravaService.uploadActivity(
        fitFilePath,
        activityName,
        activityType: activityType,
      );

      if (uploadResult != null) {
        stravaUploadSuccessful = true;
        stravaActivityId = uploadResult['id']?.toString();
        logger.i(
            '✅ Successfully uploaded activity to Strava: ${uploadResult['id']}');
      } else {
        stravaUploadSuccessful = false;
        logger.w('❌ Failed to upload activity to Strava');
      }
    } catch (e) {
      stravaUploadSuccessful = false;
      logger.e('Error during Strava upload: $e');
    }

    if (!_disposed) notifyListeners();
  }

  // ============ Public session control methods ============

  /// Pause the current training session
  void pauseSession() {
    if (!_state.canProcessEvent(SessionEvent.userPaused)) return;
    logger.i('⏸️ Manually pausing training session');
    _processEvent(SessionEvent.userPaused);
  }

  /// Resume the paused training session
  void resumeSession() {
    if (!_state.canProcessEvent(SessionEvent.userResumed)) return;
    logger.i('▶️ Manually resuming training session');
    _processEvent(SessionEvent.userResumed);
  }

  /// Stop the training session completely and save data
  void stopSession() {
    if (_state.hasEnded) return;
    _processEvent(SessionEvent.userStopped);
    _finishRecording().then((_) {
      if (!_disposed) notifyListeners();
    });
  }

  /// Discard the session without saving
  void discardSession() {
    if (_state.hasEnded) return;
    _processEvent(SessionEvent.userStopped);
  }

  // ============ Lifecycle ============

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _ftmsSub.cancel();
    _connectionStateSub.cancel();
    _stopTimer();
    _audioPlayer?.dispose();

    if (!_state.hasEnded) {
      Future.microtask(() async {
        await stopOrPauseWithControl();
      });
    }

    if (_dataRecorder != null && !_state.hasEnded) {
      _finishRecording();
    }

    super.dispose();
  }

  // ============ FTMS commands ============

  Future<void> setPowerWithControl(dynamic power) async {
    try {
      await _ftmsService
          .writeCommand(MachineControlPointOpcodeType.requestControl);
      await Future.delayed(const Duration(milliseconds: 100));
      await _ftmsService.writeCommand(
          MachineControlPointOpcodeType.setTargetPower,
          power: power);
    } catch (e) {
      debugPrint('Failed to set power: $e');
    }
  }

  Future<void> stopOrPauseWithControl() async {
    try {
      await _ftmsService
          .writeCommand(MachineControlPointOpcodeType.requestControl);
      await Future.delayed(const Duration(milliseconds: 100));
      await _ftmsService
          .writeCommand(MachineControlPointOpcodeType.stopOrPause);
    } catch (e) {
      debugPrint('Failed to stop/pause: $e');
    }
  }

  Future<void> setResistanceWithControl(int resistance) async {
    try {
      await _ftmsService
          .writeCommand(MachineControlPointOpcodeType.requestControl);
      await Future.delayed(const Duration(milliseconds: 100));
      await _ftmsService.writeCommand(
          MachineControlPointOpcodeType.setTargetResistanceLevel,
          resistanceLevel: resistance);
    } catch (e) {
      debugPrint('Failed to set resistance: $e');
    }
  }

  Future<void> startOrResumeWithControl() async {
    try {
      await _ftmsService
          .writeCommand(MachineControlPointOpcodeType.requestControl);
      await Future.delayed(const Duration(milliseconds: 100));
      await _ftmsService
          .writeCommand(MachineControlPointOpcodeType.startOrResume);
      logger.i('📤 Requested control and sent startOrResume command');
    } catch (e) {
      logger.e('Failed to request control/send resume command: $e');
    }
  }

  Future<void> resetWithControl() async {
    try {
      await _ftmsService
          .writeCommand(MachineControlPointOpcodeType.requestControl);
      await Future.delayed(const Duration(milliseconds: 100));
      if (session.ftmsMachineType == DeviceType.indoorBike) {
        await _ftmsService.writeCommand(
            MachineControlPointOpcodeType.setTargetPower,
            power: 0);
        await Future.delayed(const Duration(milliseconds: 100));
      }
      await _ftmsService.writeCommand(MachineControlPointOpcodeType.reset);
    } catch (e) {
      debugPrint('Failed to reset: $e');
    }
  }
}
