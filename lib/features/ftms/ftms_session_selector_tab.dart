// This file contains the session selector tab for FTMS devices
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../training/widgets/edit_target_fields_widget.dart';
import '../training/model/training_session.dart';
import '../training/model/rower_workout_type.dart';
import '../training/model/rower_training_session_generator.dart';
import 'ftms_machine_features_tab.dart';
import 'ftms_device_data_features_tab.dart';
import '../../core/models/supported_resistance_level_range.dart';
import '../../core/services/ftms_service.dart';
import 'widgets/gpx_map_preview_widget.dart';
import '../../core/services/gpx/gpx_file_provider.dart';
import '../../core/services/gpx/gpx_data.dart';
import '../../l10n/app_localizations.dart';

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
  int? _freeRideUserResistanceLevel;
  TextEditingController? _resistanceController;
  bool _isResistanceLevelValid = true;
  bool _hasWarmup = true; // Default to true for rowers
  bool _hasCooldown = true; // Default to true for rowers
  int _trainingSessionGeneratorDurationMinutes = 30; // Default 30 minutes, minimum 15
  RowerWorkoutType _selectedWorkoutType = RowerWorkoutType.BASE_ENDURANCE;
  int? _trainingSessionGeneratorResistanceLevel;
  int? _trainingSessionGeneratorUserResistanceLevel;
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
  bool _supportsResistanceControl = false;
  List<GpxData>? _gpxFiles;
  String? _selectedGpxAssetPath;
  StreamSubscription<DeviceType>? _deviceTypeSubscription;
  String? _errorMessage;

  int get _freeRideDistanceIncrement {
    if (_deviceType == null) return 1000; // default to 1km
    final deviceType = _deviceType!;
    return deviceType == DeviceType.rower ? 250 : 1000; // 250m for rowers, 1km for bikes
  }

  int get _maxResistanceUserInput {
    return _supportedResistanceLevelRange?.maxUserInput ?? 100; // Default to 100 if no range
  }

  int _convertUserInputToMachine(int userInput) {
    if (_supportedResistanceLevelRange != null) {
      return _supportedResistanceLevelRange!.convertUserInputToMachine(userInput);
    }
    return userInput; // If no range, assume 1:1 mapping
  }

  int? _convertMachineToUserInput(int machineInput) {
    if (_supportedResistanceLevelRange != null) {
      return _supportedResistanceLevelRange!.convertMachineToUserInput(machineInput);
    }
    return machineInput; // If no range, assume 1:1 mapping
  }

  void _updateResistanceController() {
    if (_resistanceController != null) {
      _resistanceController!.text = _freeRideUserResistanceLevel?.toString() ?? '';
    }
  }

  void _updateTrainingSessionGeneratorResistanceController() {
    if (_trainingSessionGeneratorResistanceController != null) {
      _trainingSessionGeneratorResistanceController!.text = _trainingSessionGeneratorUserResistanceLevel?.toString() ?? '';
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
  }

  Future<void> _loadSupportedResistanceLevelRange() async {
    if (_deviceType == null) return;

    try {
      final ftmsService = FTMSService(widget.ftmsDevice);
      final range = await ftmsService.readSupportedResistanceLevelRange();
      final supportsResistance = await ftmsService.supportsResistanceControl();
      setState(() {
        _supportedResistanceLevelRange = range;
        _supportsResistanceControl = supportsResistance;
        if (range != null) {
          if (_freeRideResistanceLevel != null) {
            _freeRideUserResistanceLevel = _convertMachineToUserInput(_freeRideResistanceLevel!);
          }
          if (_trainingSessionGeneratorResistanceLevel != null) {
            _trainingSessionGeneratorUserResistanceLevel = _convertMachineToUserInput(_trainingSessionGeneratorResistanceLevel!);
          }
        }
        _isResistanceLevelValid = true;
        _updateResistanceController();
        _isTrainingSessionGeneratorResistanceLevelValid = true;
        _updateTrainingSessionGeneratorResistanceController();
      });
    } catch (e) {
      setState(() {
        _supportedResistanceLevelRange = null;
        _supportsResistanceControl = false;
        _freeRideUserResistanceLevel = null;
        _trainingSessionGeneratorUserResistanceLevel = null;
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
          Card(
            child: Column(
              children: [
                ListTile(
                  title: Text(AppLocalizations.of(context)!.freeRide),
                  trailing: Icon(
                    _isFreeRideExpanded ? Icons.expand_less : Icons.expand_more,
                  ),
                  onTap: () {
                    setState(() {
                      _isFreeRideExpanded = !_isFreeRideExpanded;
                    });
                  },
                ),
                if (_isFreeRideExpanded)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              // Toggle between Time and Distance
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(AppLocalizations.of(context)!.time),
                                  Switch(
                                    value: _isFreeRideDistanceBased,
                                    onChanged: (value) {
                                      setState(() {
                                        _isFreeRideDistanceBased = value;
                                        if (value && _selectedGpxAssetPath != null) {
                                          final selectedData = _gpxFiles!.firstWhere((data) => data.assetPath == _selectedGpxAssetPath);
                                          _freeRideDistanceMeters = selectedData.totalDistance.round();
                                        }
                                      });
                                    },
                                  ),
                                  Text(AppLocalizations.of(context)!.distance),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(_isFreeRideDistanceBased ? 'Distance:' : 'Duration:'),
                              const SizedBox(height: 8),
                              if (_isFreeRideDistanceBased)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove),
                                      onPressed: _freeRideDistanceMeters > _freeRideDistanceIncrement
                                          ? () {
                                              setState(() {
                                                _freeRideDistanceMeters -= _freeRideDistanceIncrement;
                                              });
                                            }
                                          : null,
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '${(_freeRideDistanceMeters / 1000).toStringAsFixed(1)} km',
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add),
                                      onPressed: _freeRideDistanceMeters < 50000
                                          ? () {
                                              setState(() {
                                                _freeRideDistanceMeters += _freeRideDistanceIncrement;
                                              });
                                            }
                                          : null,
                                    ),
                                  ],
                                )
                              else
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove),
                                      onPressed: _freeRideDurationMinutes > 1
                                          ? () {
                                              setState(() {
                                                _freeRideDurationMinutes--;
                                              });
                                            }
                                          : null,
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '$_freeRideDurationMinutes min',
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add),
                                      onPressed: _freeRideDurationMinutes < 120
                                          ? () {
                                              setState(() {
                                                _freeRideDurationMinutes++;
                                              });
                                            }
                                          : null,
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 16),
                              Text(AppLocalizations.of(context)!.targets, style: const TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              if (_deviceType != null && _userSettings != null && _configs[_deviceType!] != null)
                                EditTargetFieldsWidget(
                                  machineType: _deviceType!,
                                  userSettings: _userSettings!,
                                  config: _configs[_deviceType!]!,
                                  targets: _freeRideTargets,
                                  onTargetChanged: (name, value) {
                                    setState(() {
                                      if (value == null) {
                                        _freeRideTargets.remove(name);
                                      } else {
                                        _freeRideTargets[name] = value;
                                      }
                                    });
                                  },
                                ),
                              const SizedBox(height: 16),
                              // Resistance Level Field (only for rowing and indoor bike if supported)
                              if (_deviceType != null &&
                                  (_deviceType! == DeviceType.rower ||
                                   _deviceType! == DeviceType.indoorBike) &&
                                  (_supportedResistanceLevelRange != null || _supportsResistanceControl))
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 80,
                                        child: Text(AppLocalizations.of(context)!.resistance),
                                      ),
                                      Expanded(
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.remove),
                                              onPressed: () {
                                                setState(() {
                                                  if (_freeRideUserResistanceLevel == null) {
                                                    _freeRideUserResistanceLevel = 1;
                                                  } else if (_freeRideUserResistanceLevel! > 1) {
                                                    _freeRideUserResistanceLevel = _freeRideUserResistanceLevel! - 1;
                                                  }
                                                  _freeRideResistanceLevel = _convertUserInputToMachine(_freeRideUserResistanceLevel!);
                                                  _isResistanceLevelValid = true;
                                                  _updateResistanceController();
                                                });
                                              },
                                            ),
                                            SizedBox(
                                              width: 100,
                                              child: TextFormField(
                                                controller: _resistanceController,
                                                decoration: InputDecoration(
                                                  hintText: '(1-$_maxResistanceUserInput)',
                                                  hintStyle: const TextStyle(fontSize: 12.0),
                                                  border: const OutlineInputBorder(),
                                                  errorBorder: const OutlineInputBorder(
                                                    borderSide: BorderSide(color: Colors.red),
                                                  ),
                                                  focusedErrorBorder: const OutlineInputBorder(
                                                    borderSide: BorderSide(color: Colors.red, width: 2),
                                                  ),
                                                  isDense: true,
                                                  errorText: !_isResistanceLevelValid ? 'Invalid value (1-$_maxResistanceUserInput)' : null,
                                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                ),
                                                keyboardType: TextInputType.number,
                                                inputFormatters: [
                                                  FilteringTextInputFormatter.digitsOnly,
                                                  LengthLimitingTextInputFormatter(4), // Max 4 digits for resistance
                                                ],
                                                onChanged: (value) {
                                                  setState(() {
                                                    if (value.isEmpty) {
                                                      _freeRideUserResistanceLevel = null;
                                                      _freeRideResistanceLevel = null;
                                                      _isResistanceLevelValid = true;
                                                    } else {
                                                      final intValue = int.tryParse(value);
                                                      if (intValue != null && 
                                                          intValue >= 1 && 
                                                          intValue <= _maxResistanceUserInput) {
                                                        _freeRideUserResistanceLevel = intValue;
                                                        _freeRideResistanceLevel = _convertUserInputToMachine(intValue);
                                                        _isResistanceLevelValid = true;
                                                      } else {
                                                        _isResistanceLevelValid = false;
                                                      }
                                                    }
                                                  });
                                                },
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.add),
                                              onPressed: () {
                                                setState(() {
                                                  if (_freeRideUserResistanceLevel == null) {
                                                    _freeRideUserResistanceLevel = 1;
                                                  } else if (_freeRideUserResistanceLevel! < _maxResistanceUserInput) {
                                                    _freeRideUserResistanceLevel = _freeRideUserResistanceLevel! + 1;
                                                  }
                                                  _freeRideResistanceLevel = _convertUserInputToMachine(_freeRideUserResistanceLevel!);
                                                  _isResistanceLevelValid = true;
                                                  _updateResistanceController();
                                                });
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 16),
                              // Warm-up and Cool-down checkboxes (only for rowers)
                              if (_deviceType != null && _deviceType! == DeviceType.rower)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Row(
                                      children: [
                                        Switch(
                                          value: _hasWarmup,
                                          onChanged: (value) {
                                            setState(() {
                                              _hasWarmup = value;
                                            });
                                          },
                                        ),
                                        Text(AppLocalizations.of(context)!.warmUp),
                                      ],
                                    ),
                                    const SizedBox(width: 16),
                                    Row(
                                      children: [
                                        Switch(
                                          value: _hasCooldown,
                                          onChanged: (value) {
                                            setState(() {
                                              _hasCooldown = value;
                                            });
                                          },
                                        ),
                                        Text(AppLocalizations.of(context)!.coolDown),
                                      ],
                                    ),
                                  ],
                                ),
                              ElevatedButton(
                                onPressed: !_isResistanceLevelValid ? null : () {
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
                                child: Text(AppLocalizations.of(context)!.start),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Training Session Generator Section (only for rowing machines)
                if (_deviceType != null && _deviceType! == DeviceType.rower)
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          title: Text(AppLocalizations.of(context)!.trainingSessionGenerator),
                          trailing: Icon(
                            _isTrainingSessionGeneratorExpanded ? Icons.expand_less : Icons.expand_more,
                          ),
                          onTap: () {
                            setState(() {
                              _isTrainingSessionGeneratorExpanded = !_isTrainingSessionGeneratorExpanded;
                            });
                          },
                        ),
                        if (_isTrainingSessionGeneratorExpanded)
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                // Duration Field (time-based only, minimum 15 minutes)
                                Text('Duration:'),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove),
                                      onPressed: _trainingSessionGeneratorDurationMinutes > 15
                                          ? () {
                                              setState(() {
                                                _trainingSessionGeneratorDurationMinutes--;
                                              });
                                            }
                                          : null,
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '$_trainingSessionGeneratorDurationMinutes min',
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add),
                                      onPressed: _trainingSessionGeneratorDurationMinutes < 120
                                          ? () {
                                              setState(() {
                                                _trainingSessionGeneratorDurationMinutes++;
                                              });
                                            }
                                          : null,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                // Workout Type Selector
                                Text('Workout Type:'),
                                const SizedBox(height: 8),
                                DropdownButton<RowerWorkoutType>(
                                  value: _selectedWorkoutType,
                                  onChanged: (RowerWorkoutType? newValue) {
                                    if (newValue != null) {
                                      setState(() {
                                        _selectedWorkoutType = newValue;
                                      });
                                    }
                                  },
                                  items: RowerWorkoutType.values.map<DropdownMenuItem<RowerWorkoutType>>((RowerWorkoutType value) {
                                    return DropdownMenuItem<RowerWorkoutType>(
                                      value: value,
                                      child: Text(value.strategy.getLabel(AppLocalizations.of(context)!)),
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 16),
                                // Resistance Level Field (only if supported)
                                if (_supportedResistanceLevelRange != null || _supportsResistanceControl)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 80,
                                          child: Text(AppLocalizations.of(context)!.resistance),
                                        ),
                                        Expanded(
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.remove),
                                                onPressed: () {
                                                  setState(() {
                                                    if (_trainingSessionGeneratorUserResistanceLevel == null) {
                                                      _trainingSessionGeneratorUserResistanceLevel = 1;
                                                    } else if (_trainingSessionGeneratorUserResistanceLevel! > 1) {
                                                      _trainingSessionGeneratorUserResistanceLevel = _trainingSessionGeneratorUserResistanceLevel! - 1;
                                                    }
                                                    _trainingSessionGeneratorResistanceLevel = _convertUserInputToMachine(_trainingSessionGeneratorUserResistanceLevel!);
                                                    _isTrainingSessionGeneratorResistanceLevelValid = true;
                                                    _updateTrainingSessionGeneratorResistanceController();
                                                  });
                                                },
                                              ),
                                              SizedBox(
                                                width: 100,
                                                child: TextFormField(
                                                  controller: _trainingSessionGeneratorResistanceController,
                                                  decoration: InputDecoration(
                                                    hintText: '(1-$_maxResistanceUserInput)',
                                                    hintStyle: const TextStyle(fontSize: 12.0),
                                                    border: const OutlineInputBorder(),
                                                    errorBorder: const OutlineInputBorder(
                                                      borderSide: BorderSide(color: Colors.red),
                                                    ),
                                                    focusedErrorBorder: const OutlineInputBorder(
                                                      borderSide: BorderSide(color: Colors.red, width: 2),
                                                    ),
                                                    isDense: true,
                                                    errorText: !_isTrainingSessionGeneratorResistanceLevelValid ? 'Invalid value (1-$_maxResistanceUserInput)' : null,
                                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                  ),
                                                  keyboardType: TextInputType.number,
                                                  inputFormatters: [
                                                    FilteringTextInputFormatter.digitsOnly,
                                                    LengthLimitingTextInputFormatter(4),
                                                  ],
                                                  onChanged: (value) {
                                                    setState(() {
                                                      if (value.isEmpty) {
                                                        _trainingSessionGeneratorUserResistanceLevel = null;
                                                        _trainingSessionGeneratorResistanceLevel = null;
                                                        _isTrainingSessionGeneratorResistanceLevelValid = true;
                                                      } else {
                                                        final intValue = int.tryParse(value);
                                                        if (intValue != null && 
                                                            intValue >= 1 && 
                                                            intValue <= _maxResistanceUserInput) {
                                                          _trainingSessionGeneratorUserResistanceLevel = intValue;
                                                          _trainingSessionGeneratorResistanceLevel = _convertUserInputToMachine(intValue);
                                                          _isTrainingSessionGeneratorResistanceLevelValid = true;
                                                        } else {
                                                          _isTrainingSessionGeneratorResistanceLevelValid = false;
                                                        }
                                                      }
                                                    });
                                                  },
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.add),
                                                onPressed: () {
                                                  setState(() {
                                                    if (_trainingSessionGeneratorUserResistanceLevel == null) {
                                                      _trainingSessionGeneratorUserResistanceLevel = 1;
                                                    } else if (_trainingSessionGeneratorUserResistanceLevel! < _maxResistanceUserInput) {
                                                      _trainingSessionGeneratorUserResistanceLevel = _trainingSessionGeneratorUserResistanceLevel! + 1;
                                                    }
                                                    _trainingSessionGeneratorResistanceLevel = _convertUserInputToMachine(_trainingSessionGeneratorUserResistanceLevel!);
                                                    _isTrainingSessionGeneratorResistanceLevelValid = true;
                                                    _updateTrainingSessionGeneratorResistanceController();
                                                  });
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: 16),
                                // Start Button
                                ElevatedButton(
                                  onPressed: !_isTrainingSessionGeneratorResistanceLevelValid ? null : () {
                                    final session = RowerTrainingSessionGenerator.generateTrainingSession(
                                      _trainingSessionGeneratorDurationMinutes,
                                      _selectedWorkoutType,
                                      AppLocalizations.of(context)!,
                                      _trainingSessionGeneratorResistanceLevel,
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
                                  child: Text(AppLocalizations.of(context)!.start),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
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
                // Device Data Features Section (only show if developer mode is enabled)
                if (_userSettings?.developerMode == true)
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          title: Text(AppLocalizations.of(context)!.deviceDataFeatures),
                          trailing: Icon(
                            _isDeviceDataFeaturesExpanded ? Icons.expand_less : Icons.expand_more,
                          ),
                          onTap: () {
                            setState(() {
                              _isDeviceDataFeaturesExpanded = !_isDeviceDataFeaturesExpanded;
                            });
                          },
                        ),
                        if (_isDeviceDataFeaturesExpanded)
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.5,
                            child: FTMSDeviceDataFeaturesTab(
                              ftmsDevice: widget.ftmsDevice,
                            ),
                          ),
                      ],
                    ),
                  ),
                if (_userSettings?.developerMode == true)
                  const SizedBox(height: 16),
                // Machine Features Section (only show if developer mode is enabled)
                if (_userSettings?.developerMode == true)
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          title: Text(AppLocalizations.of(context)!.machineFeatures),
                          trailing: Icon(
                            _isMachineFeaturesExpanded ? Icons.expand_less : Icons.expand_more,
                          ),
                          onTap: () {
                            setState(() {
                              _isMachineFeaturesExpanded = !_isMachineFeaturesExpanded;
                            });
                          },
                        ),
                        if (_isMachineFeaturesExpanded)
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.6,
                            child: FTMSMachineFeaturesTab(
                              ftmsDevice: widget.ftmsDevice,
                              writeCommand: widget.writeCommand,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          );
  }
}