import 'package:flutter/foundation.dart';
import '../../../core/models/device_types.dart';
import '../../../core/models/supported_resistance_level_range.dart';
import '../../../core/config/live_data_display_config.dart';
import '../../../core/services/gpx/gpx_data.dart';
import '../../settings/model/user_settings.dart';
import '../../training/model/training_session.dart';
import '../../training/model/rower_workout_type.dart';

/// Represents the loading status of the session selector
enum SessionSelectorLoadingStatus {
  initial,
  loading,
  loaded,
  error,
}

/// Represents the state of a free ride session configuration
@immutable
class FreeRideConfig {
  final int durationMinutes;
  final bool isDistanceBased;
  final int distanceMeters;
  final Map<String, dynamic> targets;
  final int? resistanceLevel;
  final int? userResistanceLevel;
  final bool isResistanceLevelValid;
  final bool hasWarmup;
  final bool hasCooldown;

  const FreeRideConfig({
    this.durationMinutes = 20,
    this.isDistanceBased = false,
    this.distanceMeters = 5000,
    this.targets = const {},
    this.resistanceLevel,
    this.userResistanceLevel,
    this.isResistanceLevelValid = true,
    this.hasWarmup = true,
    this.hasCooldown = true,
  });

  FreeRideConfig copyWith({
    int? durationMinutes,
    bool? isDistanceBased,
    int? distanceMeters,
    Map<String, dynamic>? targets,
    int? resistanceLevel,
    int? userResistanceLevel,
    bool? isResistanceLevelValid,
    bool? hasWarmup,
    bool? hasCooldown,
    bool clearResistanceLevel = false,
    bool clearUserResistanceLevel = false,
  }) {
    return FreeRideConfig(
      durationMinutes: durationMinutes ?? this.durationMinutes,
      isDistanceBased: isDistanceBased ?? this.isDistanceBased,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      targets: targets ?? this.targets,
      resistanceLevel: clearResistanceLevel ? null : resistanceLevel ?? this.resistanceLevel,
      userResistanceLevel: clearUserResistanceLevel ? null : userResistanceLevel ?? this.userResistanceLevel,
      isResistanceLevelValid: isResistanceLevelValid ?? this.isResistanceLevelValid,
      hasWarmup: hasWarmup ?? this.hasWarmup,
      hasCooldown: hasCooldown ?? this.hasCooldown,
    );
  }

  /// Get the distance increment based on device type
  static int getDistanceIncrement(DeviceType? deviceType) {
    if (deviceType == null) return 1000;
    return deviceType == DeviceType.rower ? 250 : 1000;
  }

  /// Get the workout value for creating a training session
  int get workoutValue => isDistanceBased ? distanceMeters : durationMinutes * 60;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FreeRideConfig &&
        other.durationMinutes == durationMinutes &&
        other.isDistanceBased == isDistanceBased &&
        other.distanceMeters == distanceMeters &&
        mapEquals(other.targets, targets) &&
        other.resistanceLevel == resistanceLevel &&
        other.userResistanceLevel == userResistanceLevel &&
        other.isResistanceLevelValid == isResistanceLevelValid &&
        other.hasWarmup == hasWarmup &&
        other.hasCooldown == hasCooldown;
  }

  @override
  int get hashCode => Object.hash(
        durationMinutes,
        isDistanceBased,
        distanceMeters,
        targets,
        resistanceLevel,
        userResistanceLevel,
        isResistanceLevelValid,
        hasWarmup,
        hasCooldown,
      );
}

/// Represents the state of a training session generator configuration
@immutable
class TrainingGeneratorConfig {
  final int durationMinutes;
  final RowerWorkoutType workoutType;
  final int? resistanceLevel;
  final int? userResistanceLevel;
  final bool isResistanceLevelValid;

  const TrainingGeneratorConfig({
    this.durationMinutes = 30,
    this.workoutType = RowerWorkoutType.BASE_ENDURANCE,
    this.resistanceLevel,
    this.userResistanceLevel,
    this.isResistanceLevelValid = true,
  });

  TrainingGeneratorConfig copyWith({
    int? durationMinutes,
    RowerWorkoutType? workoutType,
    int? resistanceLevel,
    int? userResistanceLevel,
    bool? isResistanceLevelValid,
    bool clearResistanceLevel = false,
    bool clearUserResistanceLevel = false,
  }) {
    return TrainingGeneratorConfig(
      durationMinutes: durationMinutes ?? this.durationMinutes,
      workoutType: workoutType ?? this.workoutType,
      resistanceLevel: clearResistanceLevel ? null : resistanceLevel ?? this.resistanceLevel,
      userResistanceLevel: clearUserResistanceLevel ? null : userResistanceLevel ?? this.userResistanceLevel,
      isResistanceLevelValid: isResistanceLevelValid ?? this.isResistanceLevelValid,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TrainingGeneratorConfig &&
        other.durationMinutes == durationMinutes &&
        other.workoutType == workoutType &&
        other.resistanceLevel == resistanceLevel &&
        other.userResistanceLevel == userResistanceLevel &&
        other.isResistanceLevelValid == isResistanceLevelValid;
  }

  @override
  int get hashCode => Object.hash(
        durationMinutes,
        workoutType,
        resistanceLevel,
        userResistanceLevel,
        isResistanceLevelValid,
      );
}

/// Represents the expansion state of different sections
@immutable
class ExpansionState {
  final bool isFreeRideExpanded;
  final bool isTrainingSessionExpanded;
  final bool isTrainingSessionGeneratorExpanded;
  final bool isMachineFeaturesExpanded;
  final bool isDeviceDataFeaturesExpanded;

  const ExpansionState({
    this.isFreeRideExpanded = false,
    this.isTrainingSessionExpanded = false,
    this.isTrainingSessionGeneratorExpanded = false,
    this.isMachineFeaturesExpanded = false,
    this.isDeviceDataFeaturesExpanded = false,
  });

  ExpansionState copyWith({
    bool? isFreeRideExpanded,
    bool? isTrainingSessionExpanded,
    bool? isTrainingSessionGeneratorExpanded,
    bool? isMachineFeaturesExpanded,
    bool? isDeviceDataFeaturesExpanded,
  }) {
    return ExpansionState(
      isFreeRideExpanded: isFreeRideExpanded ?? this.isFreeRideExpanded,
      isTrainingSessionExpanded: isTrainingSessionExpanded ?? this.isTrainingSessionExpanded,
      isTrainingSessionGeneratorExpanded: isTrainingSessionGeneratorExpanded ?? this.isTrainingSessionGeneratorExpanded,
      isMachineFeaturesExpanded: isMachineFeaturesExpanded ?? this.isMachineFeaturesExpanded,
      isDeviceDataFeaturesExpanded: isDeviceDataFeaturesExpanded ?? this.isDeviceDataFeaturesExpanded,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ExpansionState &&
        other.isFreeRideExpanded == isFreeRideExpanded &&
        other.isTrainingSessionExpanded == isTrainingSessionExpanded &&
        other.isTrainingSessionGeneratorExpanded == isTrainingSessionGeneratorExpanded &&
        other.isMachineFeaturesExpanded == isMachineFeaturesExpanded &&
        other.isDeviceDataFeaturesExpanded == isDeviceDataFeaturesExpanded;
  }

  @override
  int get hashCode => Object.hash(
        isFreeRideExpanded,
        isTrainingSessionExpanded,
        isTrainingSessionGeneratorExpanded,
        isMachineFeaturesExpanded,
        isDeviceDataFeaturesExpanded,
      );
}

/// Represents the resistance control capabilities of a device
@immutable
class ResistanceCapabilities {
  final bool supportsResistanceControl;
  final SupportedResistanceLevelRange? supportedRange;

  const ResistanceCapabilities({
    this.supportsResistanceControl = false,
    this.supportedRange,
  });

  /// Whether resistance control is available and valid
  bool get isAvailable => supportsResistanceControl && supportedRange != null && supportedRange!.isRangeValid();

  /// Get max resistance user input (1-based)
  int get maxUserInput => supportedRange?.maxUserInput ?? 100;

  /// Convert user input (1-based) to machine value
  int convertUserInputToMachine(int userInput) {
    if (supportedRange != null) {
      return supportedRange!.convertUserInputToMachine(userInput);
    }
    return userInput;
  }

  /// Convert machine value to user input (1-based)
  int? convertMachineToUserInput(int machineInput) {
    if (supportedRange != null) {
      return supportedRange!.convertMachineToUserInput(machineInput);
    }
    return machineInput;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ResistanceCapabilities &&
        other.supportsResistanceControl == supportsResistanceControl &&
        other.supportedRange == supportedRange;
  }

  @override
  int get hashCode => Object.hash(supportsResistanceControl, supportedRange);
}

/// Complete state of the session selector tab
@immutable
class SessionSelectorState {
  final SessionSelectorLoadingStatus status;
  final String? errorMessage;
  final DeviceType? deviceType;
  final UserSettings? userSettings;
  final Map<DeviceType, LiveDataDisplayConfig?> configs;
  final bool isDeviceAvailable;
  final ResistanceCapabilities resistanceCapabilities;
  final List<GpxData>? gpxFiles;
  final String? selectedGpxAssetPath;
  final List<TrainingSessionDefinition>? trainingSessions;
  final bool isLoadingTrainingSessions;
  final ExpansionState expansionState;
  final FreeRideConfig freeRideConfig;
  final TrainingGeneratorConfig trainingGeneratorConfig;

  const SessionSelectorState({
    this.status = SessionSelectorLoadingStatus.initial,
    this.errorMessage,
    this.deviceType,
    this.userSettings,
    this.configs = const {},
    this.isDeviceAvailable = true,
    this.resistanceCapabilities = const ResistanceCapabilities(),
    this.gpxFiles,
    this.selectedGpxAssetPath,
    this.trainingSessions,
    this.isLoadingTrainingSessions = false,
    this.expansionState = const ExpansionState(),
    this.freeRideConfig = const FreeRideConfig(),
    this.trainingGeneratorConfig = const TrainingGeneratorConfig(),
  });

  bool get isLoading => status == SessionSelectorLoadingStatus.loading;
  bool get isLoaded => status == SessionSelectorLoadingStatus.loaded;
  bool get hasError => status == SessionSelectorLoadingStatus.error;

  SessionSelectorState copyWith({
    SessionSelectorLoadingStatus? status,
    String? errorMessage,
    DeviceType? deviceType,
    UserSettings? userSettings,
    Map<DeviceType, LiveDataDisplayConfig?>? configs,
    bool? isDeviceAvailable,
    ResistanceCapabilities? resistanceCapabilities,
    List<GpxData>? gpxFiles,
    String? selectedGpxAssetPath,
    List<TrainingSessionDefinition>? trainingSessions,
    bool? isLoadingTrainingSessions,
    ExpansionState? expansionState,
    FreeRideConfig? freeRideConfig,
    TrainingGeneratorConfig? trainingGeneratorConfig,
    bool clearErrorMessage = false,
    bool clearDeviceType = false,
    bool clearSelectedGpxAssetPath = false,
    bool clearTrainingSessions = false,
  }) {
    return SessionSelectorState(
      status: status ?? this.status,
      errorMessage: clearErrorMessage ? null : errorMessage ?? this.errorMessage,
      deviceType: clearDeviceType ? null : deviceType ?? this.deviceType,
      userSettings: userSettings ?? this.userSettings,
      configs: configs ?? this.configs,
      isDeviceAvailable: isDeviceAvailable ?? this.isDeviceAvailable,
      resistanceCapabilities: resistanceCapabilities ?? this.resistanceCapabilities,
      gpxFiles: gpxFiles ?? this.gpxFiles,
      selectedGpxAssetPath: clearSelectedGpxAssetPath ? null : selectedGpxAssetPath ?? this.selectedGpxAssetPath,
      trainingSessions: clearTrainingSessions ? null : trainingSessions ?? this.trainingSessions,
      isLoadingTrainingSessions: isLoadingTrainingSessions ?? this.isLoadingTrainingSessions,
      expansionState: expansionState ?? this.expansionState,
      freeRideConfig: freeRideConfig ?? this.freeRideConfig,
      trainingGeneratorConfig: trainingGeneratorConfig ?? this.trainingGeneratorConfig,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SessionSelectorState &&
        other.status == status &&
        other.errorMessage == errorMessage &&
        other.deviceType == deviceType &&
        other.userSettings == userSettings &&
        mapEquals(other.configs, configs) &&
        other.isDeviceAvailable == isDeviceAvailable &&
        other.resistanceCapabilities == resistanceCapabilities &&
        listEquals(other.gpxFiles, gpxFiles) &&
        other.selectedGpxAssetPath == selectedGpxAssetPath &&
        listEquals(other.trainingSessions, trainingSessions) &&
        other.isLoadingTrainingSessions == isLoadingTrainingSessions &&
        other.expansionState == expansionState &&
        other.freeRideConfig == freeRideConfig &&
        other.trainingGeneratorConfig == trainingGeneratorConfig;
  }

  @override
  int get hashCode => Object.hash(
        status,
        errorMessage,
        deviceType,
        userSettings,
        configs,
        isDeviceAvailable,
        resistanceCapabilities,
        gpxFiles,
        selectedGpxAssetPath,
        trainingSessions,
        isLoadingTrainingSessions,
        expansionState,
        freeRideConfig,
        trainingGeneratorConfig,
      );
}
