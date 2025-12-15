// This file contains the session selector tab for FTMS devices
import 'package:flutter/material.dart';
import 'package:flutter_ftms/flutter_ftms.dart';
import '../../core/models/device_types.dart';
import '../../core/bloc/ftms_bloc.dart';
import '../../features/training/services/training_session_storage_service.dart';
import '../training/training_session_expansion_panel.dart';
import '../training/training_session_progress_screen.dart';
import '../../core/config/live_data_display_config.dart';
import '../settings/model/user_settings.dart';
import '../training/model/training_session.dart';
import '../training/widgets/edit_target_fields_widget.dart';
import 'ftms_machine_features_tab.dart';
import 'ftms_device_data_features_tab.dart';

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
  bool _isMachineFeaturesExpanded = false;
  bool _isDeviceDataFeaturesExpanded = false;
  int _freeRideDurationMinutes = 20;
  bool _isFreeRideDistanceBased = false;
  int _freeRideDistanceMeters = 5000; // 5km default
  final Map<String, dynamic> _freeRideTargets = {};
  UserSettings? _userSettings;
  Map<DeviceType, LiveDataDisplayConfig?> _configs = {};
  bool _isLoadingSettings = true;
  bool _isDeviceAvailable = true;
  DeviceDataType? _deviceDataType;
  List<TrainingSessionDefinition>? _trainingSessions;
  bool _isLoadingTrainingSessions = false;

  int get _freeRideDistanceIncrement {
    if (_deviceDataType == null) return 1000; // default to 1km
    final deviceType = DeviceType.fromFtms(_deviceDataType!);
    return deviceType == DeviceType.rower ? 250 : 1000; // 250m for rowers, 1km for bikes
  }

  @override
  void initState() {
    super.initState();
    _loadUserSettings();
    _startFTMS();
  }

  Future<void> _loadUserSettings() async {
    final settings = await UserSettings.loadDefault();
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

  Future<void> _loadConfigForFtmsDeviceType(DeviceDataType ftmsMachineType) async {
    final config = await LiveDataDisplayConfig.loadForFtmsMachineType(
        DeviceType.fromFtms(ftmsMachineType));
    setState(() {
      _deviceDataType = ftmsMachineType;
    });
    _checkDeviceAvailability(config);
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

  void _startFTMS() async {
    await FTMS.useDeviceDataCharacteristic(
      widget.ftmsDevice,
      (DeviceData data) {
        ftmsBloc.ftmsDeviceDataControllerSink.add(data);
        // Load config when we get the first data
        if (_deviceDataType == null) {
          _loadConfigForFtmsDeviceType(data.deviceDataType);
        }
      },
    );
  }

  Future<void> _loadTrainingSessions() async {
    if (_deviceDataType == null || _trainingSessions != null) return;

    setState(() {
      _isLoadingTrainingSessions = true;
    });

    try {
      final storageService = TrainingSessionStorageService();
      final sessions = await storageService.loadTrainingSessions(DeviceType.fromFtms(_deviceDataType!));
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
      return const Center(child: Text('Failed to load training sessions.'));
    }

    if (_trainingSessions!.isEmpty) {
      return const Center(child: Text('No training sessions found for this machine type.'));
    }

    return TrainingSessionExpansionPanelList(
      sessions: _trainingSessions!,
      scrollController: ScrollController(),
      userSettings: _userSettings,
      configs: _configs,
      onSessionSelected: (session) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => TrainingSessionProgressScreen(
              session: session,
              ftmsDevice: widget.ftmsDevice,
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
      child: StreamBuilder<DeviceData?>(
        stream: ftmsBloc.ftmsDeviceDataControllerStream,
        builder: (c, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: Text("No FTMSData found!"));
          }
          final deviceData = snapshot.data!;

          // Load config if not loaded or if type changed
          if (_deviceDataType == null) {
            _loadConfigForFtmsDeviceType(deviceData.deviceDataType);
            return const Center(child: CircularProgressIndicator());
          }

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
                      label: const Text('Go Back'),
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
                // Free Ride Section
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        title: const Text('Free Ride'),
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
                                  const Text('Time'),
                                  Switch(
                                    value: _isFreeRideDistanceBased,
                                    onChanged: (value) {
                                      setState(() {
                                        _isFreeRideDistanceBased = value;
                                      });
                                    },
                                  ),
                                  const Text('Distance'),
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
                              const Text('Targets:', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              if (_deviceDataType != null && _userSettings != null && _configs[DeviceType.fromFtms(_deviceDataType!)] != null)
                                EditTargetFieldsWidget(
                                  machineType: DeviceType.fromFtms(_deviceDataType!),
                                  userSettings: _userSettings!,
                                  config: _configs[DeviceType.fromFtms(_deviceDataType!)]!,
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
                              ElevatedButton(
                                onPressed: () {
                                  if (_deviceDataType != null) {
                                    final workoutValue = _isFreeRideDistanceBased
                                        ? _freeRideDistanceMeters
                                        : _freeRideDurationMinutes * 60;
                                    final session = TrainingSessionDefinition.createTemplate(
                                      DeviceType.fromFtms(_deviceDataType!),
                                      isDistanceBased: _isFreeRideDistanceBased,
                                      workoutValue: workoutValue,
                                      targets: _freeRideTargets,
                                    );
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) => TrainingSessionProgressScreen(
                                          session: session,
                                          ftmsDevice: widget.ftmsDevice,
                                        ),
                                      ),
                                    );
                                  }
                                },
                                child: const Text('Start'),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Load Training Session Section
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        title: const Text('Load Training Session'),
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
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.5,
                          child: _buildTrainingSessionsContent(),
                        ),
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
                          title: const Text('Device Data Features'),
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
                          title: const Text('Machine Features'),
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
        },
      ),
    ),
    );
  }
}