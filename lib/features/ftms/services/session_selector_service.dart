import 'dart:async';
import 'package:flutter/foundation.dart' show visibleForTesting;
import '../../../core/models/device_types.dart';
import '../../../core/services/devices/ftms.dart';
import '../../../core/services/analytics/analytics_service.dart';
import '../../../core/services/user_settings_service.dart';
import '../../../core/services/gpx/gpx_file_provider.dart';
import '../../../core/services/gpx/gpx_data.dart';
import '../../../core/config/live_data_display_config.dart';
import '../../../core/models/supported_resistance_level_range.dart';
import '../../settings/model/user_settings.dart';
import '../../training/services/training_session_storage_service.dart';
import '../../training/model/training_session.dart';
import '../../training/model/rower_workout_type.dart';
import '../../training/model/rower_training_session_generator.dart';
import '../models/session_selector_state.dart';
import '../../../l10n/app_localizations.dart';

/// Callback for state changes
typedef StateCallback = void Function(SessionSelectorState state);

/// Abstract interface for FTMS device operations (for testability)
abstract class FtmsDeviceOperations {
  DeviceType? getDeviceType();
  Stream<DeviceType> get deviceTypeStream;
  String getDeviceName();
  Future<bool> supportsResistanceControl();
  Future<SupportedResistanceLevelRange?> readSupportedResistanceLevelRange();
}

/// Default implementation using real FTMS service via Ftms singleton
class DefaultFtmsDeviceOperations implements FtmsDeviceOperations {
  final Ftms _ftms = Ftms();
  
  @override
  DeviceType? getDeviceType() => _ftms.deviceType;

  @override
  Stream<DeviceType> get deviceTypeStream => _ftms.deviceTypeStream;

  @override
  String getDeviceName() => _ftms.name;

  @override
  Future<bool> supportsResistanceControl() async {
    return await _ftms.supportsResistanceControl();
  }

  @override
  Future<SupportedResistanceLevelRange?> readSupportedResistanceLevelRange() async {
    return await _ftms.readSupportedResistanceLevelRange();
  }
}

/// Abstract interface for settings operations (for testability)
abstract class SettingsOperations {
  Future<UserSettings> loadSettings();
  Future<LiveDataDisplayConfig?> loadConfigForDeviceType(DeviceType deviceType);
}

/// Default implementation using real services
class DefaultSettingsOperations implements SettingsOperations {
  @override
  Future<UserSettings> loadSettings() async {
    return await UserSettingsService.instance.loadSettings();
  }

  @override
  Future<LiveDataDisplayConfig?> loadConfigForDeviceType(DeviceType deviceType) async {
    return await LiveDataDisplayConfig.loadForFtmsMachineType(deviceType);
  }
}

/// Abstract interface for training session storage (for testability)
abstract class TrainingSessionOperations {
  Future<List<TrainingSessionDefinition>> loadTrainingSessions(DeviceType deviceType);
}

/// Default implementation using TrainingSessionStorageService
class DefaultTrainingSessionOperations implements TrainingSessionOperations {
  @override
  Future<List<TrainingSessionDefinition>> loadTrainingSessions(DeviceType deviceType) async {
    final storageService = TrainingSessionStorageService();
    return await storageService.loadTrainingSessions(deviceType);
  }
}

/// Abstract interface for GPX file operations (for testability)
abstract class GpxOperations {
  Future<List<GpxData>> getSortedGpxData(DeviceType deviceType);
}

/// Default implementation using GpxFileProvider
class DefaultGpxOperations implements GpxOperations {
  @override
  Future<List<GpxData>> getSortedGpxData(DeviceType deviceType) async {
    return await GpxFileProvider.getSortedGpxData(deviceType);
  }
}

/// Service that manages the business logic for session selector
class SessionSelectorService {
  final FtmsDeviceOperations _ftmsOperations;
  final SettingsOperations _settingsOperations;
  final TrainingSessionOperations _trainingSessionOperations;
  final GpxOperations _gpxOperations;
  final AnalyticsService _analyticsService;
  final Duration deviceTypeTimeout;

  SessionSelectorState _state = const SessionSelectorState();
  StreamSubscription<DeviceType>? _deviceTypeSubscription;
  bool _ftmsDataEventLogged = false;
  final List<StateCallback> _listeners = [];

  SessionSelectorService({
    FtmsDeviceOperations? ftmsOperations,
    SettingsOperations? settingsOperations,
    TrainingSessionOperations? trainingSessionOperations,
    GpxOperations? gpxOperations,
    AnalyticsService? analyticsService,
    this.deviceTypeTimeout = const Duration(seconds: 15),
  })  : _ftmsOperations = ftmsOperations ?? DefaultFtmsDeviceOperations(),
        _settingsOperations = settingsOperations ?? DefaultSettingsOperations(),
        _trainingSessionOperations = trainingSessionOperations ?? DefaultTrainingSessionOperations(),
        _gpxOperations = gpxOperations ?? DefaultGpxOperations(),
        _analyticsService = analyticsService ?? AnalyticsService();

  /// Current state
  SessionSelectorState get state => _state;

  /// For testing: access the listeners
  @visibleForTesting
  List<StateCallback> get testListeners => _listeners;

  /// Add a listener for state changes
  void addListener(StateCallback callback) {
    _listeners.add(callback);
  }

  /// Remove a listener
  void removeListener(StateCallback callback) {
    _listeners.remove(callback);
  }

  void _notifyListeners() {
    for (final listener in _listeners) {
      listener(_state);
    }
  }

  void _updateState(SessionSelectorState newState) {
    _state = newState;
    _notifyListeners();
  }

  /// Initialize the service and load initial data
  Future<void> initialize() async {
    _analyticsService.logScreenView(
      screenName: 'session_selector',
      screenClass: 'FTMSessionSelectorTab',
    );

    _updateState(_state.copyWith(status: SessionSelectorLoadingStatus.loading));

    await _loadUserSettings();
    _loadDeviceType();
    if (_state.deviceType == null) {
      _startDeviceTypeSubscription();
    }
  }

  /// Dispose resources
  void dispose() {
    _deviceTypeSubscription?.cancel();
    _listeners.clear();
  }

  Future<void> _loadUserSettings() async {
    final settings = await _settingsOperations.loadSettings();
    final configs = <DeviceType, LiveDataDisplayConfig?>{};
    
    for (final deviceType in [DeviceType.rower, DeviceType.indoorBike]) {
      configs[deviceType] = await _settingsOperations.loadConfigForDeviceType(deviceType);
    }
    
    _updateState(_state.copyWith(
      userSettings: settings,
      configs: configs,
      status: SessionSelectorLoadingStatus.loaded,
    ));
  }

  void _loadDeviceType() {
    final deviceType = _ftmsOperations.getDeviceType();
    if (deviceType != null) {
      _updateState(_state.copyWith(deviceType: deviceType));
      _loadConfigForDeviceType(deviceType);
    }
  }

  void _startDeviceTypeSubscription({void Function(String)? onError}) {
    bool hasReceivedValue = false;
    _deviceTypeSubscription = _ftmsOperations.deviceTypeStream.listen((deviceType) {
      hasReceivedValue = true;
      _updateState(_state.copyWith(deviceType: deviceType));
      _loadConfigForDeviceType(deviceType);
      _deviceTypeSubscription?.cancel();
      _deviceTypeSubscription = null;
    });

    Future.delayed(deviceTypeTimeout, () {
      if (!hasReceivedValue && _deviceTypeSubscription != null) {
        _deviceTypeSubscription?.cancel();
        _deviceTypeSubscription = null;
        if (_state.deviceType == null) {
          _updateState(_state.copyWith(
            status: SessionSelectorLoadingStatus.error,
            errorMessage: 'Could not retrieve device information',
          ));
          onError?.call('Could not retrieve device information');
        }
      }
    });
  }

  Future<void> _loadConfigForDeviceType(DeviceType deviceType) async {
    final config = await _settingsOperations.loadConfigForDeviceType(deviceType);
    _checkDeviceAvailability(config);
    await _loadSupportedResistanceLevelRange();
    await _loadGpxFiles();
  }

  void _checkDeviceAvailability(LiveDataDisplayConfig? config) {
    if (config != null && _state.userSettings != null) {
      final isAvailable = _state.userSettings!.developerMode || !config.availableInDeveloperModeOnly;
      _updateState(_state.copyWith(isDeviceAvailable: isAvailable));
    }
  }

  Future<void> _loadSupportedResistanceLevelRange() async {
    if (_state.deviceType == null) return;

    try {
      final supportsResistance = await _ftmsOperations.supportsResistanceControl();
      final range = await _ftmsOperations.readSupportedResistanceLevelRange();

      await _logFtmsDeviceDataOnce(supportsResistance, range);

      final capabilities = ResistanceCapabilities(
        supportsResistanceControl: supportsResistance,
        supportedRange: range,
      );

      // Update resistance levels in configs if range is available
      var freeRideConfig = _state.freeRideConfig;
      var generatorConfig = _state.trainingGeneratorConfig;

      if (range != null) {
        if (freeRideConfig.resistanceLevel != null) {
          final userLevel = capabilities.convertMachineToUserInput(freeRideConfig.resistanceLevel!);
          freeRideConfig = freeRideConfig.copyWith(
            userResistanceLevel: userLevel,
            isResistanceLevelValid: true,
          );
        }
        if (generatorConfig.resistanceLevel != null) {
          final userLevel = capabilities.convertMachineToUserInput(generatorConfig.resistanceLevel!);
          generatorConfig = generatorConfig.copyWith(
            userResistanceLevel: userLevel,
            isResistanceLevelValid: true,
          );
        }
      }

      _updateState(_state.copyWith(
        resistanceCapabilities: capabilities,
        freeRideConfig: freeRideConfig,
        trainingGeneratorConfig: generatorConfig,
      ));
    } catch (e) {
      _updateState(_state.copyWith(
        resistanceCapabilities: const ResistanceCapabilities(),
        freeRideConfig: _state.freeRideConfig.copyWith(
          clearResistanceLevel: true,
          clearUserResistanceLevel: true,
          isResistanceLevelValid: true,
        ),
        trainingGeneratorConfig: _state.trainingGeneratorConfig.copyWith(
          clearResistanceLevel: true,
          clearUserResistanceLevel: true,
          isResistanceLevelValid: true,
        ),
      ));
    }
  }

  Future<void> _logFtmsDeviceDataOnce(
    bool supportsResistance,
    SupportedResistanceLevelRange? range,
  ) async {
    if (_ftmsDataEventLogged) return;

    final deviceName = _ftmsOperations.getDeviceName();
    final resistanceRangeStr = range != null
        ? '${range.minResistanceLevel}-${range.maxResistanceLevel}'
        : 'none';
    final resistanceIncrementStr = range?.minIncrement.toString() ?? 'none';
    final ftmsDeviceData = '$deviceName,$supportsResistance,$resistanceRangeStr,$resistanceIncrementStr';

    await _analyticsService.logFtmsDeviceDataRead(ftmsDeviceData: ftmsDeviceData);
    _ftmsDataEventLogged = true;
  }

  Future<void> _loadGpxFiles() async {
    if (_state.deviceType == null) return;

    final files = await _gpxOperations.getSortedGpxData(_state.deviceType!);
    _updateState(_state.copyWith(gpxFiles: files));
  }

  /// Load training sessions (called when expanding the training session panel)
  Future<void> loadTrainingSessions() async {
    if (_state.deviceType == null || _state.trainingSessions != null) return;

    _updateState(_state.copyWith(isLoadingTrainingSessions: true));

    try {
      final sessions = await _trainingSessionOperations.loadTrainingSessions(_state.deviceType!);
      _updateState(_state.copyWith(
        trainingSessions: sessions,
        isLoadingTrainingSessions: false,
      ));
    } catch (e) {
      _updateState(_state.copyWith(isLoadingTrainingSessions: false));
    }
  }

  // ============ Expansion State Updates ============

  void toggleFreeRideExpanded() {
    _updateState(_state.copyWith(
      expansionState: _state.expansionState.copyWith(
        isFreeRideExpanded: !_state.expansionState.isFreeRideExpanded,
      ),
    ));
  }

  void toggleTrainingSessionExpanded() {
    final newExpanded = !_state.expansionState.isTrainingSessionExpanded;
    _updateState(_state.copyWith(
      expansionState: _state.expansionState.copyWith(
        isTrainingSessionExpanded: newExpanded,
      ),
    ));
    
    // Load training sessions when expanding for the first time
    if (newExpanded && _state.trainingSessions == null && !_state.isLoadingTrainingSessions) {
      loadTrainingSessions();
    }
  }

  void toggleTrainingSessionGeneratorExpanded() {
    _updateState(_state.copyWith(
      expansionState: _state.expansionState.copyWith(
        isTrainingSessionGeneratorExpanded: !_state.expansionState.isTrainingSessionGeneratorExpanded,
      ),
    ));
  }

  void toggleMachineFeaturesExpanded() {
    _updateState(_state.copyWith(
      expansionState: _state.expansionState.copyWith(
        isMachineFeaturesExpanded: !_state.expansionState.isMachineFeaturesExpanded,
      ),
    ));
  }

  void toggleDeviceDataFeaturesExpanded() {
    _updateState(_state.copyWith(
      expansionState: _state.expansionState.copyWith(
        isDeviceDataFeaturesExpanded: !_state.expansionState.isDeviceDataFeaturesExpanded,
      ),
    ));
  }

  // ============ Free Ride Configuration ============

  void updateFreeRideDuration(int minutes) {
    _updateState(_state.copyWith(
      freeRideConfig: _state.freeRideConfig.copyWith(durationMinutes: minutes),
    ));
  }

  void updateFreeRideDistance(int meters) {
    _updateState(_state.copyWith(
      freeRideConfig: _state.freeRideConfig.copyWith(distanceMeters: meters),
    ));
  }

  void updateFreeRideDistanceBased(bool isDistanceBased, {GpxData? selectedGpxData}) {
    var distanceMeters = _state.freeRideConfig.distanceMeters;
    if (isDistanceBased && selectedGpxData != null) {
      distanceMeters = selectedGpxData.totalDistance.round();
    }
    _updateState(_state.copyWith(
      freeRideConfig: _state.freeRideConfig.copyWith(
        isDistanceBased: isDistanceBased,
        distanceMeters: distanceMeters,
      ),
    ));
  }

  void updateFreeRideTarget(String name, dynamic value) {
    final newTargets = Map<String, dynamic>.from(_state.freeRideConfig.targets);
    if (value == null) {
      newTargets.remove(name);
    } else {
      newTargets[name] = value;
    }
    _updateState(_state.copyWith(
      freeRideConfig: _state.freeRideConfig.copyWith(targets: newTargets),
    ));
  }

  void updateFreeRideResistance({int? userLevel, bool validateOnly = false}) {
    if (userLevel == null) {
      _updateState(_state.copyWith(
        freeRideConfig: _state.freeRideConfig.copyWith(
          clearResistanceLevel: true,
          clearUserResistanceLevel: true,
          isResistanceLevelValid: true,
        ),
      ));
      return;
    }

    final maxInput = _state.resistanceCapabilities.maxUserInput;
    final isValid = userLevel >= 1 && userLevel <= maxInput;
    
    if (isValid) {
      final machineLevel = _state.resistanceCapabilities.convertUserInputToMachine(userLevel);
      _updateState(_state.copyWith(
        freeRideConfig: _state.freeRideConfig.copyWith(
          userResistanceLevel: userLevel,
          resistanceLevel: machineLevel,
          isResistanceLevelValid: true,
        ),
      ));
    } else {
      _updateState(_state.copyWith(
        freeRideConfig: _state.freeRideConfig.copyWith(
          isResistanceLevelValid: false,
        ),
      ));
    }
  }

  void updateFreeRideWarmup(bool hasWarmup) {
    _updateState(_state.copyWith(
      freeRideConfig: _state.freeRideConfig.copyWith(hasWarmup: hasWarmup),
    ));
  }

  void updateFreeRideCooldown(bool hasCooldown) {
    _updateState(_state.copyWith(
      freeRideConfig: _state.freeRideConfig.copyWith(hasCooldown: hasCooldown),
    ));
  }

  // ============ Training Generator Configuration ============

  void updateTrainingGeneratorDuration(int minutes) {
    _updateState(_state.copyWith(
      trainingGeneratorConfig: _state.trainingGeneratorConfig.copyWith(durationMinutes: minutes),
    ));
  }

  void updateTrainingGeneratorWorkoutType(RowerWorkoutType workoutType) {
    _updateState(_state.copyWith(
      trainingGeneratorConfig: _state.trainingGeneratorConfig.copyWith(workoutType: workoutType),
    ));
  }

  void updateTrainingGeneratorResistance({int? userLevel}) {
    if (userLevel == null) {
      _updateState(_state.copyWith(
        trainingGeneratorConfig: _state.trainingGeneratorConfig.copyWith(
          clearResistanceLevel: true,
          clearUserResistanceLevel: true,
          isResistanceLevelValid: true,
        ),
      ));
      return;
    }

    final maxInput = _state.resistanceCapabilities.maxUserInput;
    final isValid = userLevel >= 1 && userLevel <= maxInput;
    
    if (isValid) {
      final machineLevel = _state.resistanceCapabilities.convertUserInputToMachine(userLevel);
      _updateState(_state.copyWith(
        trainingGeneratorConfig: _state.trainingGeneratorConfig.copyWith(
          userResistanceLevel: userLevel,
          resistanceLevel: machineLevel,
          isResistanceLevelValid: true,
        ),
      ));
    } else {
      _updateState(_state.copyWith(
        trainingGeneratorConfig: _state.trainingGeneratorConfig.copyWith(
          isResistanceLevelValid: false,
        ),
      ));
    }
  }

  // ============ GPX Selection ============

  void selectGpxRoute(String? assetPath, {GpxData? gpxData}) {
    if (_state.selectedGpxAssetPath == assetPath) {
      // Deselect
      var freeRideConfig = _state.freeRideConfig;
      if (freeRideConfig.isDistanceBased) {
        freeRideConfig = freeRideConfig.copyWith(distanceMeters: 5000);
      }
      _updateState(_state.copyWith(
        clearSelectedGpxAssetPath: true,
        freeRideConfig: freeRideConfig,
      ));
    } else {
      // Select
      var freeRideConfig = _state.freeRideConfig;
      if (freeRideConfig.isDistanceBased && gpxData != null) {
        freeRideConfig = freeRideConfig.copyWith(distanceMeters: gpxData.totalDistance.round());
      }
      _updateState(_state.copyWith(
        selectedGpxAssetPath: assetPath,
        freeRideConfig: freeRideConfig,
      ));
    }
  }

  // ============ Session Creation & Analytics ============

  /// Create a free ride session
  TrainingSessionDefinition createFreeRideSession() {
    final deviceType = _state.deviceType!;
    final config = _state.freeRideConfig;
    
    return TrainingSessionDefinition.createTemplate(
      deviceType,
      isDistanceBased: config.isDistanceBased,
      workoutValue: config.workoutValue,
      targets: config.targets,
      resistanceLevel: config.resistanceLevel,
      hasWarmup: config.hasWarmup,
      hasCooldown: config.hasCooldown,
    );
  }

  /// Log free ride start analytics
  Future<void> logFreeRideStarted() async {
    final deviceType = _state.deviceType!;
    final config = _state.freeRideConfig;
    
    await _analyticsService.logFreeRideStarted(
      machineType: deviceType,
      isDistanceBased: config.isDistanceBased,
      targetValue: config.workoutValue,
      hasWarmup: config.hasWarmup,
      hasCooldown: config.hasCooldown,
      resistanceLevel: config.resistanceLevel,
      hasGpxRoute: _state.selectedGpxAssetPath != null,
    );
  }

  /// Create a generated training session
  TrainingSessionDefinition createGeneratedSession(AppLocalizations localizations) {
    final config = _state.trainingGeneratorConfig;
    
    return RowerTrainingSessionGenerator.generateTrainingSession(
      config.durationMinutes,
      config.workoutType,
      localizations,
      config.resistanceLevel,
    );
  }

  /// Log training session generator analytics
  Future<void> logTrainingSessionGenerated() async {
    final config = _state.trainingGeneratorConfig;
    
    await _analyticsService.logTrainingSessionGenerated(
      workoutType: config.workoutType.name,
      duration: config.durationMinutes,
      resistanceLevel: config.resistanceLevel,
    );
  }

  /// Log training session selected analytics
  Future<void> logTrainingSessionSelected(TrainingSessionDefinition session) async {
    await _analyticsService.logTrainingSessionSelected(
      machineType: session.ftmsMachineType,
      sessionTitle: session.title,
      isCustom: session.isCustom,
      isDistanceBased: session.isDistanceBased,
    );
  }
}
