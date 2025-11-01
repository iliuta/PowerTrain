import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ftms/flutter_ftms.dart';
import 'package:ftms/core/models/live_data_field_value.dart';
import 'package:ftms/features/training/model/expanded_training_session_definition.dart';
import 'package:ftms/features/training/model/expanded_unit_training_interval.dart';
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
  late final List<ExpandedUnitTrainingInterval> _intervals;
  late final List<int> _intervalStartTimes;
  late final int _totalDuration;
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

  bool hasControl = false;
  bool sessionCompleted = false;
  bool sessionPaused = false; // Add pause state
  bool isDeviceConnected = true; // Track device connection state
  bool wasAutoPaused = false; // Track if session was auto-paused due to disconnection
  int elapsed = 0;
  int intervalElapsed = 0;
  int currentIntervalIndex = 0;
  bool timerActive = false;
  Map<String, LiveDataFieldValue>? _lastFtmsParams;
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
    
    // Initialize audio player with error handling for tests
    if (audioPlayer != null) {
      _audioPlayer = audioPlayer;
    } else {
      try {
        _audioPlayer = AudioPlayer();
      } catch (e) {
        debugPrint('Failed to initialize AudioPlayer (likely in test environment): $e');
        _audioPlayer = null;
      }
    }
    _dataRecorder =
        dataRecorder; // Can be null, will be created in _initDataRecording if needed
    _intervals = session.intervals;
    _intervalStartTimes = [];
    int acc = 0;
    for (final interval in _intervals) {
      _intervalStartTimes.add(acc);
      acc += interval.duration;
    }
    _totalDuration = acc;

    // Ensure wakelock stays enabled during training sessions
    WakelockPlus.enable().catchError((e) {
      debugPrint('Failed to enable wakelock during training: $e');
    });

    _ftmsStream = ftmsBloc.ftmsDeviceDataControllerStream;
    _ftmsSub = _ftmsStream.listen(_onFtmsData);
    _connectionStateSub = ftmsDevice.connectionState.listen(_onConnectionStateChanged);
    _initFTMS();
    _initDataRecording();
  }

  int get totalDuration => _totalDuration;

  List<ExpandedUnitTrainingInterval> get intervals => _intervals;

  List<int> get intervalStartTimes => _intervalStartTimes;

  ExpandedUnitTrainingInterval get current => _intervals[currentIntervalIndex];

  List<ExpandedUnitTrainingInterval> get remainingIntervals =>
      _intervals.sublist(currentIntervalIndex);

  int get mainTimeLeft => _totalDuration - elapsed;

  int get intervalTimeLeft => current.duration - intervalElapsed;

  bool get deviceConnected => isDeviceConnected;

  bool get wasSessionAutoPaused => wasAutoPaused;

  void _initFTMS() {
    // Request control after a short delay, then start session and set initial resistance if needed
    Future.delayed(const Duration(seconds: 2), () async {
      try {
        await _requestMachineControl();
        notifyListeners();
        await Future.delayed(const Duration(milliseconds: 200));
        await _startOrResumeOnMachine();
        final firstResistance =
            _intervals.isNotEmpty ? _intervals[0].resistanceLevel : null;
        if (firstResistance != null) {
          await Future.delayed(const Duration(milliseconds: 200));
          await _setResistanceWithControl(firstResistance);
        }
      } catch (e) {
        debugPrint('Failed to request control/start: $e');
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

  Future<void> _setResistanceWithControl(int resistance) async {
    try {
      if (!hasControl) {
        debugPrint('Not in control, skipping resistance set');
        return;
      }
      await _ftmsService.writeCommand(
          MachineControlPointOpcodeType.setTargetResistanceLevel,
          resistanceLevel: resistance);
    } catch (e) {
      debugPrint('Failed to set resistance: $e');
    }
  }

  void _onFtmsData(DeviceData? data) {
    if (data == null) return;

    final paramValueMap = _dataProcessor.processDeviceData(data);

    if (timerActive || sessionPaused) {
      // Record training data if recording is active and configured
      _recordDataPoint(paramValueMap);
      return;
    }

    // Only start timer if at least one value has changed since last update
    if (_lastFtmsParams != null) {
      if (_hasDeviceDataChangedValues(paramValueMap)) {
        _startTimer();
        // Record the data point that triggered the timer start
        _recordDataPoint(paramValueMap);
      }
    }
    // Store current values for next comparison
    _lastFtmsParams = paramValueMap;
  }

  void _recordDataPoint(Map<String, LiveDataFieldValue> paramValueMap) {
    if (_dataRecorder != null && _isRecordingConfigured && timerActive) {
      try {
        _dataRecorder!.recordDataPoint(ftmsParams: paramValueMap);
      } catch (e) {
        debugPrint('Failed to record data point: $e');
      }
    }
  }

  bool _hasDeviceDataChangedValues(Map<String, LiveDataFieldValue> params) {
    if (_lastFtmsParams == null) return true;
    for (final key in params.keys) {
      final prevValue = _lastFtmsParams![key]?.value;
      final currValue = params[key]?.value;
      debugPrint('Comparing $key: prev=$prevValue, curr=$currValue, equal=${prevValue == currValue}');
      if (prevValue != currValue) {
        debugPrint('Value changed for $key');
        return true;
      }
    }
    debugPrint('No values changed');
    return false;
  }

  void _onConnectionStateChanged(BluetoothConnectionState state) {
    final wasConnected = isDeviceConnected;
    isDeviceConnected = state == BluetoothConnectionState.connected;
    
    logger.i('🔗 FTMS device connection state changed: $state (was connected: $wasConnected, now connected: $isDeviceConnected)');
    
    // Handle disconnection - auto-pause the session
    if (wasConnected && !isDeviceConnected && !sessionCompleted && !sessionPaused) {
      logger.w('📱 FTMS device disconnected during training - auto-pausing session');
      wasAutoPaused = true;
      _autoPauseSession();
    }
    
    // Handle reconnection - auto-resume if it was auto-paused
    if (!wasConnected && isDeviceConnected && wasAutoPaused && sessionPaused && !sessionCompleted) {
      logger.i('📱 FTMS device reconnected - auto-resuming session');
      wasAutoPaused = false;
      _autoResumeSession();
    }
    
    notifyListeners();
  }

  void _autoPauseSession() {
    if (sessionCompleted || sessionPaused) return;

    logger.i('⏸️ Auto-pausing training session due to device disconnection');
    sessionPaused = true;
    timerActive = false;
    _timer?.cancel();

    // Don't send FTMS commands when device is disconnected
    notifyListeners();
  }

  void _autoResumeSession() {
    if (sessionCompleted || !sessionPaused) return;

    logger.i('▶️ Auto-resuming training session after device reconnection');
    sessionPaused = false;

    // Request control first, then send resume command to FTMS device after reconnection
    Future.delayed(const Duration(milliseconds: 500), () async {
      try {
        await _requestMachineControl();
        await Future.delayed(const Duration(milliseconds: 200));
        await _startOrResumeOnMachine();
        logger.i('📤 Requested control and sent startOrResume command after reconnection');
      } catch (e) {
        logger.e('Failed to request control/send resume command after reconnection: $e');
      }
    });

    // Timer will restart automatically when FTMS data changes
    notifyListeners();
  }

  void _startTimer() {
    if (timerActive || sessionPaused) return;
    timerActive = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  void _onTick() {
    if (sessionCompleted || sessionPaused) return;
    elapsed++;
    debugPrint(
        '🕐 Timer tick: elapsed=$elapsed, sessionCompleted=$sessionCompleted, sessionPaused=$sessionPaused, timerActive=$timerActive');
    if (elapsed >= _totalDuration) {
      stopSession();
    } else {
      // Update current interval first
      int previousIntervalIndex = currentIntervalIndex;
      while (currentIntervalIndex < _intervals.length - 1 &&
          elapsed >= _intervalStartTimes[currentIntervalIndex + 1]) {
        currentIntervalIndex++;
      }

      // Calculate current interval timing using the correct current interval
      intervalElapsed = elapsed - _intervalStartTimes[currentIntervalIndex];

      // Play warning sound when interval is about to finish (5 seconds or less remaining)
      final remainingTime = current.duration - intervalElapsed;
      if (remainingTime <= 4 || remainingTime == current.duration) {
        _playWarningSound();
      }

      // If interval changed and resistanceLevel is set, send command
      if (currentIntervalIndex != previousIntervalIndex) {
        final resistance = _intervals[currentIntervalIndex].resistanceLevel;
        if (resistance != null) {
          _setResistanceWithControl(resistance);
        }
      }
      notifyListeners();
    }
  }

  Future<void> _playWarningSound() async {
    if (_audioPlayer == null) {
      debugPrint('🔔 AudioPlayer not available, skipping sound playback');
      return;
    }
    
    try {
      // Play custom beep sound from assets
      await _audioPlayer!.play(AssetSource('sounds/beep.wav'));
      debugPrint('🔔 Played custom beep sound');
    } catch (e) {
      debugPrint('🔔 Failed to play warning sound: $e');
    }
  }

  Future<void> _finishRecording() async {
    if (_dataRecorder != null) {
      try {
        _dataRecorder!.stopRecording();

        // Only generate FIT file if enabled (disabled for tests to avoid path_provider dependency)
        if (_enableFitFileGeneration) {
          final fitFilePath = await _dataRecorder!.generateFitFile();
          lastGeneratedFitFile = fitFilePath;
          logger.i(
              '***************** Training session completed successfully. FIT file saved to: $fitFilePath');
          debugPrint('FIT file generated: $fitFilePath');

          // Attempt automatic Strava upload if user is authenticated
          if (fitFilePath != null) {
            await _attemptStravaUpload(fitFilePath);
            
            // Delete the FIT file after successful Strava upload
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
          logger.i('🗑️ FIT file deleted after successful Strava upload: $fitFilePath');
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
      // Check if user is authenticated with Strava
      final isAuthenticated = await _stravaService.isAuthenticated();
      if (!isAuthenticated) {
        logger.i('Strava upload skipped: User not authenticated');
        notifyListeners();
        return;
      }

      logger.i('Attempting automatic Strava upload...');

      // Create activity name based on session
      final activityName = '${session.title} - FTMS Training';

      // Determine the appropriate activity type based on the device type
      final deviceType = session.ftmsMachineType;
      final activityType = StravaActivityTypes.fromFtmsMachineType(deviceType);

      // Upload to Strava with the correct activity type
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

    notifyListeners();
  }

  /// Pause the current training session
  void pauseSession() {
    if (sessionCompleted || sessionPaused) return;

    logger.i('⏸️ Manually pausing training session');
    sessionPaused = true;
    timerActive = false;
    wasAutoPaused = false; // Clear auto-pause flag when manually paused
    _timer?.cancel();

    // Request control first, then send pause command to FTMS device
    Future.microtask(() async {
      if (_disposed) return;
      try {
        await _requestMachineControl();
        await Future.delayed(const Duration(milliseconds: 200));
        await _ftmsService.writeCommand(MachineControlPointOpcodeType.stopOrPause);
        logger.i('📤 Requested control and sent pause command');
      } catch (e) {
        logger.e('Failed to request control/send pause command: $e');
      }
    });

    notifyListeners();
  }

  /// Resume the paused training session
  void resumeSession() {
    if (sessionCompleted || !sessionPaused) return;

    logger.i('▶️ Manually resuming training session');
    sessionPaused = false;
    wasAutoPaused = false; // Clear auto-pause flag when manually resumed

    // Request control first, then send resume command to FTMS device
    Future.microtask(() async {
      try {
        await _requestMachineControl();
        await Future.delayed(const Duration(milliseconds: 200));
        await _startOrResumeOnMachine();
        logger.i('📤 Requested control and sent startOrResume command for manual resume');
      } catch (e) {
        logger.e('Failed to request control/send resume command: $e');
      }
    });

    // Restart timer - it will start automatically when FTMS data changes
    notifyListeners();
  }

  Future<void> _startOrResumeOnMachine() async {
    await _ftmsService.writeCommand(MachineControlPointOpcodeType.startOrResume);
  }

  Future<void> _requestMachineControl() async {
    await _ftmsService.writeCommand(MachineControlPointOpcodeType.requestControl);
    hasControl = true;
  }

  /// Stop the training session completely
  void stopSession() {
    if (sessionCompleted) return;

    sessionCompleted = true;
    sessionPaused = false;
    timerActive = false;
    _timer?.cancel();

    // Request control first, then send stop + reset commands to FTMS device
    Future.microtask(() async {
      try {
        await _requestMachineControl();
        await Future.delayed(const Duration(milliseconds: 200));
        await _ftmsService.writeCommand(MachineControlPointOpcodeType.stopOrPause);
        await Future.delayed(const Duration(milliseconds: 200));
        await _ftmsService.writeCommand(MachineControlPointOpcodeType.reset);
        logger.i('📤 Requested control and sent stop/reset commands');
      } catch (e) {
        logger.e('Failed to request control/send stop command: $e');
      }
    });

    // Finish recording and generate FIT file (async)
    _finishRecording().then((_) {
      // Only notify listeners if not disposed
      if (!_disposed) {
        notifyListeners();
      }
    });
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _ftmsSub.cancel();
    _connectionStateSub.cancel();
    _timer?.cancel();
    _audioPlayer?.dispose();

    // Request control and send stop command to FTMS device if session wasn't completed normally
    if (!sessionCompleted) {
      Future.microtask(() async {
        try {
          await _ftmsService.writeCommand(MachineControlPointOpcodeType.requestControl);
          await Future.delayed(const Duration(milliseconds: 200));
          await _ftmsService.writeCommand(MachineControlPointOpcodeType.stopOrPause);
        } catch (e) {
          debugPrint('Failed to request control/send stop command during dispose: $e');
        }
      });
    }

    // Clean up data recorder if session wasn't completed normally
    if (_dataRecorder != null && !sessionCompleted) {
      _finishRecording();
    }

    super.dispose();
  }
}
