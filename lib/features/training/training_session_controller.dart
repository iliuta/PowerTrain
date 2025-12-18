import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ftms/flutter_ftms.dart';
import 'package:ftms/core/models/device_types.dart';
import 'package:ftms/core/models/live_data_field_value.dart';
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

class TrainingSessionController extends ChangeNotifier
    implements SessionEffectHandler {
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

  // For detecting activity to trigger session auto-start
  double? _lastActivityValue;

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

    // Initialize session state with this controller as the effect handler
    _state = TrainingSessionState.initial(session, handler: this);

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

    final paramValueMap = _dataProcessor.processDeviceData(data);
    // For distance-based sessions, update distance from FTMS data
    if (session.isDistanceBased && _state.isRunning) {
      final totalDistanceParam = paramValueMap['Total Distance'];
      if (totalDistanceParam != null) {
        final distance = totalDistanceParam.getScaledValue().toDouble();
        _state.onDistanceUpdate(distance);
      }
    }

    // Record data if session is running
    if (_state.isRunning) {
      _recordDataPoint(paramValueMap);
      return;
    }

    // If paused, still record but don't check for changes
    if (_state.isPaused) {
      return;
    }

    // Check if user started exercising to trigger session auto-start
    _checkForActivityStart(paramValueMap);
  }

  /// Returns the list of parameter names used to detect user activity, in priority order.
  /// Primary indicators are device-specific, with "Instantaneous Power" as universal fallback.
  /// - Rower: "Instantaneous Pace" (seconds/500m - lower is faster)
  /// - Indoor Bike: "Instantaneous Speed" (km/h - higher is faster)
  List<String> get _activityIndicatorParamNames {
    return switch (session.ftmsMachineType) {
      DeviceType.rower => ['Instantaneous Pace', 'Instantaneous Power'],
      DeviceType.indoorBike => ['Instantaneous Speed', 'Instantaneous Power'],
    };
  }

  /// Checks if the user has started exercising by monitoring meaningful activity data.
  /// This uses processed data (speed/pace/power) rather than raw params to reliably detect
  /// when the user starts moving on both rowers and indoor bikes.
  void _checkForActivityStart(Map<String, LiveDataFieldValue> data) {
    if (_state.status != SessionStatus.created) return;

    // Find the first available activity indicator
    LiveDataFieldValue? activityParam;
    String? usedParamName;
    for (final paramName in _activityIndicatorParamNames) {
      if (data.containsKey(paramName)) {
        activityParam = data[paramName];
        usedParamName = paramName;
        break;
      }
    }

    if (activityParam == null) {
      debugPrint('⚠️ No activity indicator found in data. Tried: $_activityIndicatorParamNames');
      return;
    }

    final currentValue = activityParam.getScaledValue().toDouble();

    // First reading: store the baseline
    if (_lastActivityValue == null) {
      _lastActivityValue = currentValue;
      return;
    }

    // Detect if user started exercising based on the parameter type
    final bool activityDetected = _detectActivity(currentValue, usedParamName!);

    if (activityDetected) {
      debugPrint('🚀 Activity detected! Starting session ($usedParamName: $currentValue)');
      _state.onDataChanged();
      _recordDataPoint(data);
    }

    _lastActivityValue = currentValue;
  }

  /// Detects if the user has started exercising based on the activity value.
  /// Detection logic varies by parameter type:
  /// - Pace: value decreases when moving faster (rowing)
  /// - Speed/Power: value increases when moving/pedaling
  bool _detectActivity(double currentValue, String paramName) {
    final lastValue = _lastActivityValue!;

    // Pace-based detection (rower): pace decreases when rowing faster
    if (paramName == 'Instantaneous Pace') {
      return currentValue < lastValue * 0.9 ||
             (lastValue > 200 && currentValue < 200);
    }

    // Speed-based detection: speed increases above threshold
    if (paramName == 'Instantaneous Speed') {
      return currentValue > 5.0 && currentValue > lastValue;
    }

    // Power-based detection (universal fallback): power increases above threshold
    if (paramName == 'Instantaneous Power') {
      return currentValue > 10.0 && currentValue > lastValue;
    }

    // Unknown parameter - use simple change detection
    return currentValue != lastValue;
  }

  void _recordDataPoint(Map<String, LiveDataFieldValue> data) {
    if (_dataRecorder == null || !_isRecordingConfigured || !_state.isRunning) {
      return;
    }
    try {
      _dataRecorder!.recordDataPoint(ftmsParams: data);
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
      _state.onDeviceDisconnected();
    } else if (!wasConnected && isNowConnected) {
      // Device reconnected
      logger.i('📱 FTMS device reconnected');
      _state.onDeviceReconnected();
    }
  }

  // ============ Timer tick handler ============

  void _onTick() {
    if (!_state.isRunning) return;
    _state.onTimerTick();
    debugPrint(
        '🕐 Timer tick: elapsed=${_state.elapsedSeconds}, status=${_state.status}');
  }

  // ============ SessionEffectHandler implementation ============

  @override
  void onStartTimer() {
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  @override
  void onStopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void onPlayWarningSound() {
    _playWarningSound();
  }

  @override
  void onIntervalChanged(ExpandedUnitTrainingInterval newInterval) {
    final resistance = newInterval.resistanceLevel;
    if (resistance != null) {
      setResistanceWithControl(resistance);
    }
    final power = newInterval.targets?['Instantaneous Power'];
    if (power != null) {
      setPowerWithControl(power);
    }
  }

  @override
  void onSessionCompleted() {
    Future.microtask(() async {
      if (_disposed) return;
      await stopOrPauseWithControl();
      await resetWithControl();
    });
    // Recording will be handled by the completion dialog
  }

  @override
  void onSendFtmsPause() {
    Future.microtask(() async {
      if (_disposed) return;
      await stopOrPauseWithControl();
    });
  }

  @override
  void onSendFtmsResume() {
    Future.microtask(() async {
      if (_disposed) return;
      await startOrResumeWithControl();
    });
  }

  @override
  void onSendFtmsStopAndReset() {
    Future.microtask(() async {
      if (_disposed) return;
      await stopOrPauseWithControl();
      await resetWithControl();
    });
  }

  @override
  void onNotifyListeners() {
    if (!_disposed) notifyListeners();
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

  /// Save the workout recording and upload to Strava if connected
  Future<void> saveRecording() async {
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
    if (_state.status != SessionStatus.running) return;
    logger.i('⏸️ Manually pausing training session');
    _state.onUserPaused();
  }

  /// Resume the paused training session
  void resumeSession() {
    if (!_state.isPaused) return;
    logger.i('▶️ Manually resuming training session');
    _state.onUserResumed();
  }

  /// Stop the training session completely
  void stopSession() {
    if (_state.hasEnded) return;
    _state.onUserStopped();
    // Recording will be handled by the completion dialog
  }

  /// Discard the session without saving
  void discardSession() {
    if (_state.hasEnded) return;
    _state.onUserStopped();
  }

  // ============ Lifecycle ============

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _ftmsSub.cancel();
    _connectionStateSub.cancel();
    onStopTimer();
    _audioPlayer?.dispose();

    if (!_state.hasEnded) {
      Future.microtask(() async {
        await stopOrPauseWithControl();
      });
    }

    if (_dataRecorder != null && !_state.hasEnded) {
      saveRecording();
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
