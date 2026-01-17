// This file contains the session selector tab for FTMS devices
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_ftms/flutter_ftms.dart';
import '../../core/models/device_types.dart';
import '../../core/services/devices/ftms.dart';
import '../../core/services/analytics/analytics_service.dart';
import '../../features/training/services/training_session_storage_service.dart';
import '../training/training_session_expansion_panel.dart';
import '../training/training_session_progress_screen.dart';
import '../../core/config/live_data_display_config.dart';
import '../settings/model/user_settings.dart';
import '../../core/services/user_settings_service.dart';
import '../../core/services/training_session_preferences_service.dart';
import '../training/model/training_session.dart';
import '../training/model/rower_workout_type.dart';
import '../training/model/rower_training_session_generator.dart';
import '../../core/models/supported_resistance_level_range.dart';
import '../../core/services/ftms_service.dart';
import 'widgets/gpx_map_preview_widget.dart';
import '../../core/services/gpx/gpx_file_provider.dart';
import '../../core/services/gpx/gpx_data.dart';
import '../../l10n/app_localizations.dart';
import 'widgets/free_ride_section.dart';
import 'widgets/training_session_generator_section.dart';
import 'widgets/developer_mode_sections.dart';

class FTMSessionSelectorTab extends StatefulWidget {
  final BluetoothDevice ftmsDevice;
  final Future<void> Function(MachineControlPointOpcodeType) writeCommand;

  const FTMSessionSelectorTab({
    super.key,
    required this.ftmsDevice,
    required this.writeCommand,
  });

  @override
  State<FTMSessionSelectorTab> createState() => _FTMSessionSelectorTabState();
}

class _FTMSessionSelectorTabState extends State<FTMSessionSelectorTab> {
  bool _isFreeRideExpanded = false;
  bool _isTrainingSessionExpanded = false;
  bool _isTrainingSessionGeneratorExpanded = false;
  bool _isMachineFeaturesExpanded = false;
  bool _isDeviceDataFeaturesExpanded = false;
  int _freeRideDurationMinutes = 20;
  bool _isFreeRideDistanceBased = false;
  int _freeRideDistanceMeters = 5000; // 5km default
  final Map<String, dynamic> _freeRideTargets = {};
  int? _freeRideResistanceLevel;
  TextEditingController? _resistanceController;
  bool _isResistanceLevelValid = true;
  bool _hasWarmup = true; // Default to true for rowers
  bool _hasCooldown = true; // Default to true for rowers
  int _trainingSessionGeneratorDurationMinutes = 30; // Default 30 minutes, minimum 15
  RowerWorkoutType _selectedWorkoutType = RowerWorkoutType.BASE_ENDURANCE;
  int? _trainingSessionGeneratorResistanceLevel;
  TextEditingController? _trainingSessionGeneratorResistanceController;
  bool _isTrainingSessionGeneratorResistanceLevelValid = true;
  UserSettings? _userSettings;
  Map<DeviceType, LiveDataDisplayConfig?> _configs = {};
  bool _isLoadingSettings = true;
  bool _isDeviceAvailable = true;
  DeviceType? _deviceType;
  List<TrainingSessionDefinition>? _trainingSessions;
  bool _isLoadingTrainingSessions = false;
  SupportedResistanceLevelRange? _supportedResistanceLevelRange;
  List<GpxData>? _gpxFiles;
  String? _selectedGpxAssetPath;
  StreamSubscription<DeviceType>? _deviceTypeSubscription;
  String? _errorMessage;

  int get _freeRideDistanceIncrement {
    if (_deviceType == null) return 1000; // default to 1km
    final deviceType = _deviceType!;
    return deviceType == DeviceType.rower ? 250 : 1000; // 250m for rowers, 1km for bikes
  }

  void _updateResistanceController() {
    if (_resistanceController != null) {
      _resistanceController!.text = _freeRideResistanceLevel?.toString() ?? '';
    }
  }

  void _updateTrainingSessionGeneratorResistanceController() {
    if (_trainingSessionGeneratorResistanceController != null) {
      _trainingSessionGeneratorResistanceController!.text = _trainingSessionGeneratorResistanceLevel?.toString() ?? '';
    }
  }

  @override
  void initState() {
    super.initState();
    AnalyticsService().logScreenView(
      screenName: 'session_selector',
      screenClass: 'FTMSessionSelectorTab',
    );
    _loadUserSettings();
    _loadDeviceType();
    if (_deviceType == null) {
      _startDeviceTypeSubscription();
    }
    _resistanceController = TextEditingController();
    _trainingSessionGeneratorResistanceController = TextEditingController();
  }

  @override
  void dispose() {
    _resistanceController?.dispose();
    _trainingSessionGeneratorResistanceController?.dispose();
    _deviceTypeSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadUserSettings() async {
    final settings = await UserSettingsService.instance.loadSettings();
    final configs = <DeviceType, LiveDataDisplayConfig?>{};
    for (final deviceType in [DeviceType.rower, DeviceType.indoorBike]) {
      configs[deviceType] = await LiveDataDisplayConfig.loadForFtmsMachineType(deviceType);
    }
    setState(() {
      _userSettings = settings;
      _configs = configs;
      _isLoadingSettings = false;
    });
  }

  Future<void> _loadConfigForDeviceType(DeviceType deviceType) async {
    final config = await LiveDataDisplayConfig.loadForFtmsMachineType(deviceType);
    setState(() {
      _deviceType = deviceType;
    });
    _checkDeviceAvailability(config);
    _loadSupportedResistanceLevelRange();
    _loadGpxFiles();
    _loadFreeRidePreferences();
    _loadTrainingGeneratorPreferences();
  }

  Future<void> _loadFreeRidePreferences() async {
    if (_deviceType == null) return;

    try {
      final prefs = await TrainingSessionPreferencesService.loadFreeRidePreferences(_deviceType!);
      setState(() {
        _freeRideTargets.clear();
        _freeRideTargets.addAll(prefs.targets);
        if (prefs.resistanceLevel != null) {
          _freeRideResistanceLevel = prefs.resistanceLevel;
          _updateResistanceController();
        }
      });
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _loadTrainingGeneratorPreferences() async {
    if (_deviceType == null) return;

    try {
      final prefs = await TrainingSessionPreferencesService.loadTrainingGeneratorPreferences(_deviceType!);
      setState(() {
        if (prefs.resistanceLevel != null) {
          _trainingSessionGeneratorResistanceLevel = prefs.resistanceLevel;
          _updateTrainingSessionGeneratorResistanceController();
        }
      });
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _loadSupportedResistanceLevelRange() async {
    if (_deviceType == null) return;

    try {
      final ftmsService = FTMSService(widget.ftmsDevice);
      final range = await ftmsService.readSupportedResistanceLevelRange();
      setState(() {
        _supportedResistanceLevelRange = range;
        _isResistanceLevelValid = true;
        _updateResistanceController();
        _isTrainingSessionGeneratorResistanceLevelValid = true;
        _updateTrainingSessionGeneratorResistanceController();
      });
    } catch (e) {
      setState(() {
        _supportedResistanceLevelRange = null;
        _isResistanceLevelValid = true;
        _updateResistanceController();
        _isTrainingSessionGeneratorResistanceLevelValid = true;
        _updateTrainingSessionGeneratorResistanceController();
      });
    }
  }

  Future<void> _loadGpxFiles() async {
    if (_deviceType == null) return;

    final files = await GpxFileProvider.getSortedGpxData(_deviceType!);
    setState(() {
      _gpxFiles = files;
    });
  }

  void _checkDeviceAvailability(LiveDataDisplayConfig? config) {
    if (config != null && _userSettings != null) {
      final isAvailable =
          _userSettings!.developerMode || !config.availableInDeveloperModeOnly;
      setState(() {
        _isDeviceAvailable = isAvailable;
      });
    }
  }

  void _loadDeviceType() {
    final deviceType = Ftms().deviceType;
    if (deviceType != null) {
      _deviceType = deviceType;
      _loadConfigForDeviceType(_deviceType!);
    }
  }

  void _startDeviceTypeSubscription() {
    bool hasReceivedValue = false;
    _deviceTypeSubscription = Ftms().deviceTypeStream.listen((deviceType) {
      hasReceivedValue = true;
      setState(() {
        _deviceType = deviceType;
        _loadConfigForDeviceType(_deviceType!);
      });
      _deviceTypeSubscription?.cancel();
      _deviceTypeSubscription = null;
    });

    // Timeout after 5 seconds if no device type is received
    Future.delayed(const Duration(seconds: 15), () {
      if (!hasReceivedValue && _deviceTypeSubscription != null) {
        _deviceTypeSubscription?.cancel();
        _deviceTypeSubscription = null;
        // Handle timeout: display error message
        if (_deviceType == null) {
          setState(() {
            _errorMessage = AppLocalizations.of(context)!.couldNotRetrieveDeviceInformation;
          });
        }
      }
    });
  }

  Future<void> _loadTrainingSessions() async {
    if (_deviceType == null || _trainingSessions != null) return;

    setState(() {
      _isLoadingTrainingSessions = true;
    });

    try {
      final storageService = TrainingSessionStorageService();
      final sessions = await storageService.loadTrainingSessions(_deviceType!);
      setState(() {
        _trainingSessions = sessions;
        _isLoadingTrainingSessions = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingTrainingSessions = false;
      });
      // Handle error if needed
    }
  }

  Widget _buildTrainingSessionsContent() {
    if (_isLoadingTrainingSessions) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_trainingSessions == null) {
      return Center(child: Text(AppLocalizations.of(context)!.failedLoadTrainingSessions));
    }

    if (_trainingSessions!.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context)!.noTrainingSessionsFound));
    }

    return TrainingSessionExpansionPanelList(
      sessions: _trainingSessions!,
      scrollController: ScrollController(),
      userSettings: _userSettings,
      configs: _configs,
      onSessionSelected: (session) {
        // Log analytics event for session selection
        AnalyticsService().logTrainingSessionSelected(
          machineType: session.ftmsMachineType,
          sessionTitle: session.title,
          isCustom: session.isCustom,
          isDistanceBased: session.isDistanceBased,
        );
        
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => TrainingSessionProgressScreen(
              session: session,
              ftmsDevice: widget.ftmsDevice,
              gpxAssetPath: _selectedGpxAssetPath,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: _errorMessage != null
            ? Center(child: Text(_errorMessage!))
            : _deviceType == null
                ? const Center(child: CircularProgressIndicator())
                : _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    // Show loading while user settings are being loaded
    if (_isLoadingSettings) {
      return const Center(child: CircularProgressIndicator());
    }

    // Show developer mode required message if device is not available
    if (!_isDeviceAvailable) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.developer_mode,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Developer Mode Required',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'This device requires developer mode to be enabled. Please enable developer mode in the settings to view device data and features.',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop(); // Go back to previous screen
                },
                icon: const Icon(Icons.arrow_back),
                label: Text(AppLocalizations.of(context)!.goBack),
              ),
            ],
          ),
        ),
      );
    }

    // Show normal session selector content
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // GPX Route Selection Row
          if (_gpxFiles != null && _gpxFiles!.isNotEmpty)
            SizedBox(
              height: 85,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _gpxFiles!.map((data) => GpxMapPreviewWidget(
                    info: data,
                    isSelected: _selectedGpxAssetPath == data.assetPath,
                    onTap: () {
                      setState(() {
                        if (_selectedGpxAssetPath == data.assetPath) {
                          _selectedGpxAssetPath = null;
                          if (_isFreeRideDistanceBased) {
                            _freeRideDistanceMeters = 5000; // reset to default
                          }
                        } else {
                          _selectedGpxAssetPath = data.assetPath;
                          if (_isFreeRideDistanceBased) {
                            _freeRideDistanceMeters = data.totalDistance.round();
                          }
                        }
                      });
                    },
                  )).toList(),
                ),
              ),
            ),
          if (_gpxFiles != null && _gpxFiles!.isNotEmpty)
            const SizedBox(height: 16),
          // Free Ride Section
          FreeRideSection(
            isExpanded: _isFreeRideExpanded,
            onExpandChanged: () {
              setState(() {
                _isFreeRideExpanded = !_isFreeRideExpanded;
              });
            },
            deviceType: _deviceType,
            durationMinutes: _freeRideDurationMinutes,
            isDistanceBased: _isFreeRideDistanceBased,
            distanceMeters: _freeRideDistanceMeters,
            distanceIncrement: _freeRideDistanceIncrement,
            targets: _freeRideTargets,
            resistanceLevel: _freeRideResistanceLevel,
            isResistanceValid: _isResistanceLevelValid,
            resistanceController: _resistanceController!,
            supportedResistanceRange: _supportedResistanceLevelRange,
            hasWarmup: _hasWarmup,
            hasCooldown: _hasCooldown,
            userSettings: _userSettings,
            configs: _configs,
            selectedGpxAssetPath: _selectedGpxAssetPath,
            onDurationChanged: (minutes) {
              setState(() {
                _freeRideDurationMinutes = minutes;
              });
            },
            onDistanceChanged: (meters) {
              setState(() {
                _freeRideDistanceMeters = meters;
              });
            },
            onModeChanged: (isDistanceBased) {
              setState(() {
                _isFreeRideDistanceBased = isDistanceBased;
                if (isDistanceBased && _selectedGpxAssetPath != null) {
                  final selectedData = _gpxFiles!.firstWhere((data) => data.assetPath == _selectedGpxAssetPath);
                  _freeRideDistanceMeters = selectedData.totalDistance.round();
                }
              });
            },
            onTargetsChanged: (targets) {
              setState(() {
                _freeRideTargets.clear();
                _freeRideTargets.addAll(targets);
              });
            },
            onResistanceChanged: (value) {
              setState(() {
                _freeRideResistanceLevel = value;
                _isResistanceLevelValid = true;
                _updateResistanceController();
              });
            },
            onWarmupChanged: (value) {
              setState(() {
                _hasWarmup = value;
              });
            },
            onCooldownChanged: (value) {
              setState(() {
                _hasCooldown = value;
              });
            },
            onStartPressed: () {
              if (_deviceType != null) {
                final workoutValue = _isFreeRideDistanceBased
                    ? _freeRideDistanceMeters
                    : _freeRideDurationMinutes * 60;
                final session = TrainingSessionDefinition.createTemplate(
                  _deviceType!,
                  isDistanceBased: _isFreeRideDistanceBased,
                  workoutValue: workoutValue,
                  targets: _freeRideTargets,
                  resistanceLevel: _freeRideResistanceLevel,
                  hasWarmup: _hasWarmup,
                  hasCooldown: _hasCooldown,
                );
                
                // Save preferences
                TrainingSessionPreferencesService.saveFreeRidePreferences(
                  _deviceType!,
                  TrainingSessionPreferences(
                    deviceType: _deviceType!,
                    targets: _freeRideTargets,
                    resistanceLevel: _freeRideResistanceLevel,
                  ),
                );
                
                // Log free ride analytics
                AnalyticsService().logFreeRideStarted(
                  machineType: _deviceType!,
                  isDistanceBased: _isFreeRideDistanceBased,
                  targetValue: workoutValue,
                  hasWarmup: _hasWarmup,
                  hasCooldown: _hasCooldown,
                  resistanceLevel: _freeRideResistanceLevel,
                  hasGpxRoute: _selectedGpxAssetPath != null,
                );
                
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => TrainingSessionProgressScreen(
                      session: session,
                      ftmsDevice: widget.ftmsDevice,
                      gpxAssetPath: _selectedGpxAssetPath,
                    ),
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 16),
        // Training Session Generator Section (only for rowing machines)
        if (_deviceType != null && _deviceType! == DeviceType.rower)
          TrainingSessionGeneratorSection(
            isExpanded: _isTrainingSessionGeneratorExpanded,
            onExpandChanged: () {
              setState(() {
                _isTrainingSessionGeneratorExpanded = !_isTrainingSessionGeneratorExpanded;
              });
            },
            durationMinutes: _trainingSessionGeneratorDurationMinutes,
            selectedWorkoutType: _selectedWorkoutType,
            resistanceLevel: _trainingSessionGeneratorResistanceLevel,
            isResistanceValid: _isTrainingSessionGeneratorResistanceLevelValid,
            resistanceController: _trainingSessionGeneratorResistanceController!,
            supportedResistanceRange: _supportedResistanceLevelRange,
            selectedGpxAssetPath: _selectedGpxAssetPath,
            onDurationChanged: (minutes) {
              setState(() {
                _trainingSessionGeneratorDurationMinutes = minutes;
              });
            },
            onWorkoutTypeChanged: (workoutType) {
              setState(() {
                _selectedWorkoutType = workoutType;
              });
            },
            onResistanceChanged: (value) {
              setState(() {
                _trainingSessionGeneratorResistanceLevel = value;
                _isTrainingSessionGeneratorResistanceLevelValid = true;
                _updateTrainingSessionGeneratorResistanceController();
              });
            },
            onStartPressed: () {
              final session = RowerTrainingSessionGenerator.generateTrainingSession(
                _trainingSessionGeneratorDurationMinutes,
                _selectedWorkoutType,
                AppLocalizations.of(context)!,
                _trainingSessionGeneratorResistanceLevel,
              );
              
              // Save preferences
              TrainingSessionPreferencesService.saveTrainingGeneratorPreferences(
                _deviceType!,
                TrainingSessionPreferences(
                  deviceType: _deviceType!,
                  targets: {},
                  resistanceLevel: _trainingSessionGeneratorResistanceLevel,
                ),
              );
              
              // Log analytics event for training session generator
              AnalyticsService().logTrainingSessionGenerated(
                workoutType: _selectedWorkoutType.name,
                duration: _trainingSessionGeneratorDurationMinutes,
                resistanceLevel: _trainingSessionGeneratorResistanceLevel,
              );
              
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => TrainingSessionProgressScreen(
                    session: session,
                    ftmsDevice: widget.ftmsDevice,
                    gpxAssetPath: _selectedGpxAssetPath,
                  ),
                ),
              );
            },
          ),
        if (_deviceType != null && _deviceType! == DeviceType.rower)
          const SizedBox(height: 16),
        // Load Training Session Section
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        title: Text(AppLocalizations.of(context)!.loadTrainingSession),
                        trailing: Icon(
                          _isTrainingSessionExpanded ? Icons.expand_less : Icons.expand_more,
                        ),
                        onTap: () {
                          setState(() {
                            _isTrainingSessionExpanded = !_isTrainingSessionExpanded;
                            // Load training sessions when expanding for the first time
                            if (_isTrainingSessionExpanded && _trainingSessions == null && !_isLoadingTrainingSessions) {
                              _loadTrainingSessions();
                            }
                          });
                        },
                      ),
                      if (_isTrainingSessionExpanded)
                        _buildTrainingSessionsContent(),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
        // Developer Mode Sections (only show if developer mode is enabled)
        if (_userSettings?.developerMode == true)
          DeveloperModeSections(
            ftmsDevice: widget.ftmsDevice,
            writeCommand: widget.writeCommand,
            isMachineFeaturesExpanded: _isMachineFeaturesExpanded,
            isDeviceDataFeaturesExpanded: _isDeviceDataFeaturesExpanded,
            onMachineFeaturesExpandChanged: () {
              setState(() {
                _isMachineFeaturesExpanded = !_isMachineFeaturesExpanded;
              });
            },
            onDeviceDataFeaturesExpandChanged: () {
              setState(() {
                _isDeviceDataFeaturesExpanded = !_isDeviceDataFeaturesExpanded;
              });
            },
          ),
        ],
      ),
    );
  }
}