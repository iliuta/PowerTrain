import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_ftms/flutter_ftms.dart';
import 'package:ftms/core/models/device_types.dart';
import 'package:ftms/core/models/live_data_field_value.dart';
import 'package:ftms/core/services/analytics/analytics_service.dart';
import 'package:ftms/features/training/model/expanded_training_session_definition.dart';
import 'package:ftms/features/training/model/expanded_unit_training_interval.dart';
import 'package:ftms/features/training/model/unit_training_interval.dart';
import 'package:ftms/features/training/model/session_state.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/bloc/ftms_bloc.dart';
import '../../core/config/live_data_display_config.dart';
import '../../core/services/fit/training_data_recorder.dart';
import '../../core/services/ftms_data_processor.dart';
import '../../core/services/ftms_service.dart';
import '../../core/services/gpx/gpx_route_tracker.dart';
import '../../core/services/strava/strava_activity_types.dart';
import '../../core/services/strava/strava_service.dart';
import '../../core/services/sound_service.dart';
import '../../core/utils/logger.dart';

class TrainingSessionController extends ChangeNotifier
    implements SessionEffectHandler {
  ExpandedTrainingSessionDefinition session;
  final BluetoothDevice ftmsDevice;
  late final FTMSService _ftmsService;
  late final Stream<DeviceData?> _ftmsStream;
  StreamSubscription<DeviceData?>? _ftmsSub;
  late final StreamSubscription<BluetoothConnectionState> _connectionStateSub;
  Timer? _timer;

  // FIT file recording
  TrainingDataRecorder? _dataRecorder;
  final FtmsDataProcessor _dataProcessor = FtmsDataProcessor();
  bool _isRecordingConfigured = false;
  final bool _enableFitFileGeneration;
  late final StravaService _stravaService;

  // Audio player for warning sounds
  SoundService? _soundService;

  // Session state machine
  late TrainingSessionState _state;

  // GPX route tracker for map display
  GpxRouteTracker? _gpxRouteTracker;
  final String? _gpxFilePath;

  // Initialization completion tracking
  late Future<void> _initialized;
  late Completer<void> _initializationCompleter;

  // Metronome for target cadence/stroke rate
  late LiveDataDisplayConfig? _displayConfig;
  Timer? _metronomeTimer;
  double? _currentMetronomeTarget;
  int _metronomeTickCount = 0; // Counter for alternating high/low sounds
  bool _isPullPhase = true; // Track if we're in pull (true) or recovery (false) phase

  // Public getters for metronome state (used by UI to show visual metronome)
  double? get currentMetronomeTarget => _currentMetronomeTarget;
  int get metronomeTickCount => _metronomeTickCount;
  bool get isPullPhase => _isPullPhase;

  // For detecting activity to trigger session auto-start and auto-pause
  double? _lastActivityValue;
  double? _lastResumeCheckValue; // Separate tracking for resume detection
  int _inactivityCounter = 0;
  static const int _inactivityThresholdSeconds = 5; // seconds of inactivity before auto-pause
  int _activityResumeCounter = 0; // Counter for detecting consistent activity before resume
  static const int _activityResumeThresholdSeconds = 2; // seconds of activity before auto-resume
  bool _isAttemptingResume = false; // Flag to track if we're in the middle of a resume attempt

  // Strava upload tracking
  String? lastGeneratedFitFile;
  bool stravaUploadAttempted = false;
  bool stravaUploadSuccessful = false;
  String? stravaActivityId;

  // Analytics
  final AnalyticsService _analytics = AnalyticsService();
  bool _sessionStartedEventLogged = false;

  // Allow injection of dependencies for testing
  TrainingSessionController({
    required this.session,
    required this.ftmsDevice,
    FTMSService? ftmsService,
    StravaService? stravaService,
    TrainingDataRecorder? dataRecorder,
    bool enableFitFileGeneration = true, // Allow disabling for tests
    String? gpxFilePath, // Optional GPX file path for route display
  })  : _enableFitFileGeneration = enableFitFileGeneration,
        _gpxFilePath = gpxFilePath {
    _ftmsService = ftmsService ?? FTMSService(ftmsDevice);
    _stravaService = stravaService ?? StravaService();

    // Initialize session state with this controller as the effect handler
    _state = TrainingSessionState.initial(session, handler: this);

    // Initialize sound service (singleton)
    _soundService = SoundService.instance;
    _dataRecorder = dataRecorder;

    // Set up initialization tracking
    _initializationCompleter = Completer<void>();
    _initialized = _initializationCompleter.future;

    // Load display config for metronome
    _displayConfig = null;
    LiveDataDisplayConfig.loadForFtmsMachineType(session.ftmsMachineType).then((config) => _displayConfig = config);

    // Ensure wakelock stays enabled during training sessions
    _enableWakeLock();

    _connectionStateSub =
        ftmsDevice.connectionState.listen(_onConnectionStateChanged);
    _performInitialization();
  }

  /// Performs async initialization and completes the initialized future when done
  Future<void> _performInitialization() async {
    try {
      await Future.wait([
        _initFTMS(),
        _initDataRecording(),
      ]);
      if (!_initializationCompleter.isCompleted) {
        _initializationCompleter.complete();
      }
    } catch (e) {
      if (!_initializationCompleter.isCompleted) {
        _initializationCompleter.completeError(e);
      }
      debugPrint('Initialization error: $e');
    }
  }

  void _enableWakeLock() {
    // Ensure wakelock stays enabled during training sessions
    WakelockPlus.enable().catchError((e) {
      debugPrint('Failed to enable wakelock during training: $e');
    });
  }

  // ============ Public getters (delegating to state) ============

  /// The current session state - consumers should access state properties directly
  /// e.g., controller.state.isPaused, controller.state.elapsedSeconds, etc.
  TrainingSessionState get state => _state;

  /// GPX route tracker for displaying current position on map
  GpxRouteTracker? get gpxRouteTracker => _gpxRouteTracker;

  /// Future that completes when FTMS and data recording initialization is complete
  /// Tests should await this to ensure the controller is fully initialized
  Future<void> get initialized => _initialized;

  // ============ Initialization ============

  Future<void> _initFTMS() async {
    _dataProcessor.reset();

    if (_disposed) return;

    // Execute operations concurrently where possible
    await Future.wait([
      _ftmsService.resetWithControl(),
      _ftmsService.startOrResumeWithControl(),
    ]);

    // Some FTMS devices need a brief pause/resume cycle to properly start calculating averages
    // This ensures Average Speed, Average Power, and Total Distance start working correctly
    await Future.delayed(const Duration(milliseconds: 200));
    await _ftmsService.stopOrPauseWithControl();
    await Future.delayed(const Duration(milliseconds: 200));
    await _ftmsService.startOrResumeWithControl();

    // Handle conditional operations that depend on the above
    final firstInterval = _state.intervals.isNotEmpty ? _state.intervals[0] : null;
    if (firstInterval != null) {
      final operations = <Future<void>>[];

      final firstResistance = firstInterval.resistanceLevel;
      if (firstResistance != null) {
        operations.add(_ftmsService.setResistanceWithControl(firstResistance));
      }

      final firstPower = firstInterval.targets?['Instantaneous Power'];
      if (firstPower != null) {
        await _ftmsService.setPowerWithControl(firstPower);
      }

      if (operations.isNotEmpty) {
        await Future.wait(operations);
      }
    }

    // Always set up FTMS data stream subscription after device initialization
    _ftmsStream = ftmsBloc.ftmsDeviceDataControllerStream;
    _ftmsSub = _ftmsStream.listen(_onFtmsData);
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

      // Initialize GPX route tracker for GPS coordinates
      if (_gpxFilePath != null) {
        try {
          _gpxRouteTracker = GpxRouteTracker();
          await _gpxRouteTracker!.loadFromAsset(_gpxFilePath);
          if (!_gpxRouteTracker!.isLoaded) {
            _gpxRouteTracker = null;
            debugPrint('GPX route not available - recording without GPS coordinates');
          } else {
            debugPrint('GPX route loaded from $_gpxFilePath: ${_gpxRouteTracker!.pointCount} points, ${_gpxRouteTracker!.totalRouteDistance.toStringAsFixed(0)}m');
          }
        } catch (e) {
          debugPrint('Failed to load GPX route from $_gpxFilePath: $e');
          _gpxRouteTracker = null;
        }
      } else {
        debugPrint('No GPX file path provided - skipping route display');
      }

      // Initialize data recorder only if not injected for testing
      _dataRecorder ??= TrainingDataRecorder(
        sessionName: session.title,
        deviceType: deviceType,
        gpxRouteTracker: _gpxRouteTracker,
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
    
    // Create raw param value map for activity detection (no averaging)
    // This ensures immediate response to activity/inactivity changes
    final rawParamValueMap = _createRawParamValueMap(data);
    
    // For distance-based sessions, update distance from FTMS data
    if (session.isDistanceBased && _state.isRunning) {
      final totalDistanceParam = paramValueMap['Total Distance'];
      if (totalDistanceParam != null) {
        final distance = totalDistanceParam.getScaledValue().toDouble();
        _state.onDistanceUpdate(distance);
      }
    }

    // Record data if session is running and check for inactivity
    if (_state.isRunning) {
      _recordDataPoint(paramValueMap);
      _checkForInactivity(rawParamValueMap);
      return;
    }

    // If paused by inactivity, check if activity resumed
    if (_state.wasInactivityPaused) {
      _checkForActivityResume(rawParamValueMap);
      return;
    }

    // If paused by user or disconnection, don't check for activity changes
    if (_state.isPaused) {
      return;
    }

    // Check if user started exercising to trigger session auto-start
    _checkForActivityStart(rawParamValueMap);
  }
  
  /// Creates a raw param value map from device data without any averaging.
  /// Used for activity detection where immediate response is needed.
  Map<String, LiveDataFieldValue> _createRawParamValueMap(DeviceData deviceData) {
    final parameterValues = deviceData.getDeviceDataParameterValues();
    return {
      for (final p in parameterValues)
        p.name.name: LiveDataFieldValue.fromDeviceDataParameterValue(p)
    };
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
      _logSessionStarted();
      _recordDataPoint(data);
    }

    _lastActivityValue = currentValue;
  }

  /// Detects if the user has started exercising based on the activity value.
  /// Detection logic varies by parameter type:
  /// - Pace: value is in active range (non-zero and below threshold)
  /// - Speed/Power: value increases above threshold
  bool _detectActivity(double currentValue, String paramName) {
    final lastValue = _lastActivityValue!;

    // Pace-based detection (rower): pace is in active range
    // When inactive, pace is 0 or very high (>300 = 5:00/500m)
    // When active, pace is between ~60 (1:00/500m) and 300 (5:00/500m)
    if (paramName == 'Instantaneous Pace') {
      final wasInactive = lastValue == 0 || lastValue > 300;
      final isNowActive = currentValue > 0 && currentValue <= 300;
      // Activity detected if:
      // - Was inactive (0 or high pace) and now in active range, OR
      // - Pace decreased significantly while already in active range
      return (wasInactive && isNowActive) ||
             (lastValue > 0 && currentValue < lastValue * 0.9 && isNowActive);
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

  /// Detects if the user has stopped exercising based on the activity value.
  /// This is used to trigger auto-pause when running.
  bool _detectInactivity(double currentValue, String paramName) {
    // Pace-based detection (rower): very high pace value means not rowing
    // When stopped, pace typically goes to max value (e.g., 999 or very high)
    // Using 350 (5:50/500m) as threshold with hysteresis
    if (paramName == 'Instantaneous Pace') {
      return currentValue == 0 || currentValue > 350; // More than 5:50/500m is considered stopped
    }

    // Speed-based detection: speed below threshold means not moving
    if (paramName == 'Instantaneous Speed') {
      return currentValue < 3.0; // Less than 3 km/h is considered stopped
    }

    // Power-based detection: power below threshold means not exercising
    if (paramName == 'Instantaneous Power') {
      return currentValue < 5.0; // Less than 5W is considered stopped
    }

    // Unknown parameter - assume active
    return false;
  }

  /// Detects if the user has resumed exercising after a pause.
  /// Uses transition logic similar to _detectActivity for reliable resume detection.
  /// Requires the last value to avoid false positives on first reading.
  bool _detectActivityResume(double currentValue, double? lastValue, String paramName) {
    // If no last value, can't detect transition yet
    if (lastValue == null) return false;

    // Pace-based detection (rower): transition from inactive to active range
    // When resuming, pace should move from 0/high to normal rowing range
    // Using 280 (4:40/500m) as active threshold with hysteresis (lower than pause threshold of 350)
    if (paramName == 'Instantaneous Pace') {
      final wasInactive = lastValue == 0 || lastValue > 350;
      final isNowActive = currentValue > 0 && currentValue <= 280;
      // Also detect significant pace improvement while already in borderline range
      final isImproving = lastValue > 280 && lastValue <= 350 && currentValue <= 280;
      debugPrint('🔍 Pace resume check: last=$lastValue, current=$currentValue, wasInactive=$wasInactive, isNowActive=$isNowActive, isImproving=$isImproving');
      return (wasInactive && isNowActive) || isImproving;
    }

    // Speed-based detection: speed increases above threshold
    if (paramName == 'Instantaneous Speed') {
      final wasInactive = lastValue < 3.0;
      final isNowActive = currentValue >= 4.0; // Hysteresis: resume at 4.0, pause at 3.0
      debugPrint('🔍 Speed resume check: last=$lastValue, current=$currentValue, wasInactive=$wasInactive, isNowActive=$isNowActive');
      return wasInactive && isNowActive;
    }

    // Power-based detection: power increases above threshold
    if (paramName == 'Instantaneous Power') {
      final wasInactive = lastValue < 5.0;
      final isNowActive = currentValue >= 8.0; // Hysteresis: resume at 8.0, pause at 5.0
      debugPrint('🔍 Power resume check: last=$lastValue, current=$currentValue, wasInactive=$wasInactive, isNowActive=$isNowActive');
      return wasInactive && isNowActive;
    }

    // Unknown parameter - use simple change detection
    return currentValue > lastValue;
  }

  /// Checks if user has become inactive while session is running
  void _checkForInactivity(Map<String, LiveDataFieldValue> data) {
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
      debugPrint('⚠️ No activity indicator found for inactivity check');
      return;
    }

    final currentValue = activityParam.getScaledValue().toDouble();
    final isInactive = _detectInactivity(currentValue, usedParamName!);

    if (isInactive) {
      _inactivityCounter++;
      if (_inactivityCounter >= _inactivityThresholdSeconds) {
        debugPrint('⏸️ Inactivity detected! Auto-pausing session ($usedParamName: $currentValue, counter: $_inactivityCounter/$_inactivityThresholdSeconds)');
        _state.onInactivityDetected();
        _inactivityCounter = 0;
        _lastResumeCheckValue = currentValue; // Initialize with current inactive value for transition detection
      } else {
        debugPrint('⏱️ Inactivity counter: $_inactivityCounter/$_inactivityThresholdSeconds ($usedParamName: $currentValue)');
      }
    } else {
      // Reset counter when activity is detected
      if (_inactivityCounter > 0) {
        debugPrint('✅ Activity detected, resetting inactivity counter (was $_inactivityCounter)');
      }
      _inactivityCounter = 0;
    }

    _lastActivityValue = currentValue;
  }

  /// Checks if user has resumed activity while paused by inactivity
  void _checkForActivityResume(Map<String, LiveDataFieldValue> data) {
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
      debugPrint('⚠️ No activity indicator found for resume check');
      return;
    }

    final currentValue = activityParam.getScaledValue().toDouble();
    
    // Check if currently active based on parameter type
    bool isCurrentlyActive;
    if (usedParamName == 'Instantaneous Pace') {
      isCurrentlyActive = currentValue > 0 && currentValue <= 350; // Use pause threshold for active check
    } else if (usedParamName == 'Instantaneous Speed') {
      isCurrentlyActive = currentValue >= 3.0; // Use pause threshold
    } else if (usedParamName == 'Instantaneous Power') {
      isCurrentlyActive = currentValue >= 5.0; // Use pause threshold
    } else {
      isCurrentlyActive = currentValue > 0;
    }

    // Detect transition from inactive to active
    final activityTransitionDetected = _detectActivityResume(currentValue, _lastResumeCheckValue, usedParamName!);

    if (activityTransitionDetected) {
      // Start or reset resume attempt
      _isAttemptingResume = true;
      _activityResumeCounter = 1;
      debugPrint('⏱️ Activity resume started: $_activityResumeCounter/$_activityResumeThresholdSeconds ($usedParamName: $currentValue)');
    } else if (_isAttemptingResume && isCurrentlyActive) {
      // Continue counting sustained activity
      _activityResumeCounter++;
      debugPrint('⏱️ Activity resume counter: $_activityResumeCounter/$_activityResumeThresholdSeconds ($usedParamName: $currentValue)');
    } else if (_isAttemptingResume && !isCurrentlyActive) {
      // Activity not sustained
      debugPrint('❌ Activity not sustained, resetting resume counter (was $_activityResumeCounter)');
      _isAttemptingResume = false;
      _activityResumeCounter = 0;
    }

    // Check if resume threshold reached
    if (_activityResumeCounter >= _activityResumeThresholdSeconds) {
      debugPrint('▶️ Activity resumed! Auto-resuming session ($usedParamName: last=$_lastResumeCheckValue, current=$currentValue)');
      _inactivityCounter = 0;
      _activityResumeCounter = 0;
      _isAttemptingResume = false;
      _state.onActivityResumed();
    }

    _lastResumeCheckValue = currentValue;
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
    if (_currentMetronomeTarget != null) {
      _startMetronome(_currentMetronomeTarget!);
    }
  }

  @override
  void onStopTimer() {
    _timer?.cancel();
    _timer = null;
    _stopMetronome();
  }

  @override
  void onPlayWarningSound() {
    _playWarningSound();
  }

  @override
  void onIntervalChanged(ExpandedUnitTrainingInterval newInterval) {
    final resistance = newInterval.resistanceLevel;
    if (resistance != null) {
      _ftmsService.setResistanceWithControl(resistance);
    }
    final power = newInterval.targets?['Instantaneous Power'];
    if (power != null) {
      _ftmsService.setPowerWithControl(power);
    }

    // Update metronome
    _stopMetronome(); // Always stop the old metronome first
    if (_displayConfig != null) {
      final metronomeFields = _displayConfig!.fields.where((f) => f.metronome && f.availableAsTarget);
      if (metronomeFields.isNotEmpty) {
        final metronomeField = metronomeFields.first;
        final target = newInterval.targets?[metronomeField.name];
        _currentMetronomeTarget = target?.toDouble();
        if (_currentMetronomeTarget != null) {
          _startMetronome(_currentMetronomeTarget!);
        }
      } else {
        _currentMetronomeTarget = null;
      }
    } else {
      _currentMetronomeTarget = null;
    }
  }

  @override
  void onSessionCompleted() {
    Future.microtask(() async {
      if (_disposed) return;
      await _ftmsService.stopOrPauseWithControl();
      await _ftmsService.resetWithControl();
    });
    // Recording will be handled by the completion dialog
  }

  @override
  void onSessionCompletedAwaitingConfirmation() {
    _logSessionCompleted();
    Future.microtask(() async {
      if (_disposed) return;
      await _ftmsService.stopOrPauseWithControl();
    });
    // Recording will be handled by the completion dialog
  }

  @override
  void onSendFtmsPause() {
    Future.microtask(() async {
      if (_disposed) return;
      await _ftmsService.stopOrPauseWithControl();
    });
  }

  @override
  void onSendFtmsResume() {
    Future.microtask(() async {
      if (_disposed) return;
      await _ftmsService.startOrResumeWithControl();
    });
  }

  @override
  void onSendFtmsStopAndReset() {
    Future.microtask(() async {
      if (_disposed) return;
      await _ftmsService.stopOrPauseWithControl();
      await _ftmsService.resetWithControl();
    });
  }

  @override
  void onNotifyListeners() {
    if (!_disposed) notifyListeners();
  }

  // ============ Audio ============

  Future<void> _playWarningSound() async {
    if (_soundService == null) {
      debugPrint('🔔 SoundService not available, skipping sound playback');
      return;
    }

    try {
      await _soundService!.playBeep();
    } catch (e) {
      debugPrint('🔔 Failed to play warning sound: $e');
    }
  }

  void _startMetronome(double target) {
    _stopMetronome();
    if (!_state.isRunning) return;

    _currentMetronomeTarget = target; // Store the target for UI
    _metronomeTickCount = 0; // Reset counter
    _isPullPhase = true; // Start with pull phase
    _scheduleNextMetronomeTick(target);
    if (!_disposed) notifyListeners(); // Notify UI that metronome started
  }

  void _scheduleNextMetronomeTick(double target) {
    if (_disposed || !_state.isRunning) return;

    // Calculate timing: pull is 1/3 of cycle, recovery is 2/3 of cycle
    final cycleSeconds = 60 / target;
    final pullSeconds = cycleSeconds / 3; // Pull phase
    final recoverySeconds = cycleSeconds * 2 / 3; // Recovery phase
    
    final nextDuration = _isPullPhase ? pullSeconds : recoverySeconds;
    
    _metronomeTimer = Timer(Duration(milliseconds: (nextDuration * 1000).round()), () {
      if (_disposed || !_state.isRunning) return;
      
      _metronomeTickCount++;
      // Play high tick for pull (start), low tick for recovery (finish)
      _isPullPhase ? _soundService?.playTickHigh() : _soundService?.playTickLow();
      
      // Toggle phase for next iteration
      _isPullPhase = !_isPullPhase;
      
      if (!_disposed) notifyListeners(); // Notify UI of tick count change
      
      // Schedule next tick
      _scheduleNextMetronomeTick(target);
    });
  }

  void _stopMetronome() {
    _metronomeTimer?.cancel();
    _metronomeTimer = null;
    if (!_state.isPaused) {
      _currentMetronomeTarget = null; // Clear the target only if not paused
    }
    _metronomeTickCount = 0; // Reset counter
    _isPullPhase = true; // Reset to pull phase
    if (!_disposed) notifyListeners(); // Notify UI that metronome stopped
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
            // Log analytics event for FIT file saved
            final stats = _dataRecorder!.getStatistics();
            _analytics.logFitFileSaved(
              machineType: session.ftmsMachineType,
              durationSeconds: _state.elapsedSeconds,
              distanceMeters: (stats['totalDistance'] as double?)?.round(),
            );
            
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

      final activityName = '${session.title} - PowerTrain';
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
      
      // Log analytics event for Strava upload
      _analytics.logStravaUpload(
        machineType: session.ftmsMachineType,
        success: stravaUploadSuccessful,
        durationSeconds: _state.elapsedSeconds,
      );
    } catch (e) {
      stravaUploadSuccessful = false;
      logger.e('Error during Strava upload: $e');
      
      // Log analytics event for failed Strava upload
      _analytics.logStravaUpload(
        machineType: session.ftmsMachineType,
        success: false,
        durationSeconds: _state.elapsedSeconds,
      );
    }

    if (!_disposed) notifyListeners();
  }

  // ============ Public session control methods ============

  /// Manually start the session (when user doesn't want to wait for auto-start)
  void startSession() {
    if (_state.status != SessionStatus.created) return;
    logger.i('▶️ Manually starting training session');
    _state.onDataChanged(); // This transitions from created to running
    _logSessionStarted();
  }

  /// Pause the current training session
  void pauseSession() {
    if (_state.status != SessionStatus.running) return;
    logger.i('⏸️ Manually pausing training session');
    _state.onUserPaused();
    _analytics.logTrainingSessionPaused(
      machineType: session.ftmsMachineType,
      isFreeRide: _isFreeRide,
      elapsedTimeSeconds: _state.elapsedSeconds,
    );
  }

  /// Resume the paused training session
  void resumeSession() {
    if (!_state.isPaused) return;
    logger.i('▶️ Manually resuming training session');
    _state.onUserResumed();
    _analytics.logTrainingSessionResumed(
      machineType: session.ftmsMachineType,
      isFreeRide: _isFreeRide,
      elapsedTimeSeconds: _state.elapsedSeconds,
    );
  }

  /// Stop the training session completely
  void stopSession() {
    if (_state.hasEnded) return;
    _logSessionCancelled();
    _state.onUserStopped();
    // Recording will be handled by the completion dialog
  }

  /// Discard the session without saving
  void discardSession() {
    if (_state.hasEnded) return;
    _logSessionCancelled();
    _state.onUserStopped();
  }

  /// Complete the session (stop and reset FTMS machine) after user confirmation
  void completeSessionAfterConfirmation() {
    onSessionCompleted();
  }

  /// Extend the session with a new interval and continue
  void extendSessionAndContinue() {
    _analytics.logTrainingSessionExtended(
      machineType: session.ftmsMachineType,
      isFreeRide: _isFreeRide,
      elapsedTimeSeconds: _state.elapsedSeconds,
    );
    
    // Calculate total duration/distance of original session
    final totalDuration = session.isDistanceBased ? null : session.intervals.fold<int>(0, (sum, interval) => sum + (interval.duration ?? 0));
    final totalDistance = session.isDistanceBased ? session.intervals.fold<double>(0.0, (sum, interval) => sum + (interval.distance ?? 0.0)) : null;

    // Create a new interval with the same duration/distance as the original session
    final newInterval = ExpandedUnitTrainingInterval(
      title: 'Extended',
      duration: totalDuration,
      distance: totalDistance?.toInt(),
      originalInterval: UnitTrainingInterval(
        title: 'Extended',
        duration: totalDuration,
        distance: totalDistance?.toInt(),
      ),
    );

    // Create new session with the additional interval
    final extendedIntervals = [...session.intervals, newInterval];
    final extendedSession = ExpandedTrainingSessionDefinition(
      title: session.title,
      ftmsMachineType: session.ftmsMachineType,
      intervals: extendedIntervals,
      isCustom: session.isCustom,
      isDistanceBased: session.isDistanceBased,
    );

    // Update the session
    session = extendedSession;

    // Update the state to continue from completed state
    _state = _state.copyWith(
      status: SessionStatus.running,
      timing: _state.timing.extendWithNewInterval(extendedSession),
      session: extendedSession,
    );

    // Resume the session (send startOrResume to FTMS, no reset)
    onSendFtmsResume();
    notifyListeners();
  }

  // ============ Lifecycle ============

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _ftmsSub?.cancel();
    _connectionStateSub.cancel();
    onStopTimer();
    _stopMetronome();

    if (!_state.hasEnded) {
      Future.microtask(() async {
        await _ftmsService.stopOrPauseWithControl();
      });
    }

    if (_dataRecorder != null && !_state.hasEnded) {
      saveRecording();
    }

    super.dispose();
  }

  // ============ FTMS commands ============



  // ============ Analytics Helpers ============

  /// Determines if this is a free ride session (template-based with generic title)
  bool get _isFreeRide {
    final title = session.title.toLowerCase();
    return title.contains('new') && 
           (title.contains('rowing') || title.contains('cycling')) && 
           title.contains('training session');
  }

  /// Log session started event (called when session first starts running)
  void _logSessionStarted() {
    if (_sessionStartedEventLogged) return;
    _sessionStartedEventLogged = true;
    
    final totalDuration = session.intervals.fold<int>(
      0, (sum, interval) => sum + (interval.duration ?? 0));
    final totalDistance = session.isDistanceBased 
        ? session.intervals.fold<int>(
            0, (sum, interval) => sum + (interval.distance ?? 0))
        : null;
    
    _analytics.logTrainingSessionStarted(
      machineType: session.ftmsMachineType,
      isDistanceBased: session.isDistanceBased,
      isFreeRide: _isFreeRide,
      totalDurationSeconds: totalDuration,
      totalDistanceMeters: totalDistance,
      intervalCount: session.intervals.length,
    );
  }

  /// Log session cancelled event (called when user stops before completion)
  void _logSessionCancelled() {
    final totalDuration = session.intervals.fold<int>(
      0, (sum, interval) => sum + (interval.duration ?? 0));
    final completionPercentage = totalDuration > 0 
        ? (_state.elapsedSeconds / totalDuration) * 100 
        : 0.0;
    
    _analytics.logTrainingSessionCancelled(
      machineType: session.ftmsMachineType,
      isDistanceBased: session.isDistanceBased,
      isFreeRide: _isFreeRide,
      elapsedTimeSeconds: _state.elapsedSeconds,
      totalDurationSeconds: totalDuration,
      completionPercentage: completionPercentage,
    );
  }

  /// Log session completed event (called when session finishes naturally)
  void _logSessionCompleted() {
    _analytics.logTrainingSessionCompleted(
      machineType: session.ftmsMachineType,
      isDistanceBased: session.isDistanceBased,
      isFreeRide: _isFreeRide,
      elapsedTimeSeconds: _state.elapsedSeconds,
    );
  }
}
