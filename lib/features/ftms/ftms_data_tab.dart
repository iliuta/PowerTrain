// This file was moved from lib/ftms_data_tab.dart
import 'package:flutter/material.dart';
import 'package:ftms/core/models/device_types.dart';
import '../../core/utils/logger.dart';
import 'package:flutter_ftms/flutter_ftms.dart';

// import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../core/bloc/ftms_bloc.dart';
import '../../features/training/services/training_session_storage_service.dart';
import '../training/training_session_expansion_panel.dart';
import '../../l10n/app_localizations.dart';
import '../training/training_session_progress_screen.dart';
import '../../core/utils/ftms_debug_utils.dart';
import '../../core/config/live_data_display_config.dart';
import '../../core/widgets/ftms_live_data_display_widget.dart';
import '../../core/services/ftms_data_processor.dart';
import '../settings/model/user_settings.dart';

class FTMSDataTab extends StatefulWidget {
  final BluetoothDevice ftmsDevice;

  const FTMSDataTab({super.key, required this.ftmsDevice});

  @override
  State<FTMSDataTab> createState() => FTMSDataTabState();
}

class FTMSDataTabState extends State<FTMSDataTab> {
  bool _started = false;
  LiveDataDisplayConfig? _config;
  String? _configError;
  final FtmsDataProcessor _dataProcessor = FtmsDataProcessor();
  UserSettings? _userSettings;
  Map<DeviceType, LiveDataDisplayConfig?>? _configs;
  bool _isLoadingSettings = true;
  bool _isDeviceAvailable = true;

  @override
  void initState() {
    super.initState();
    _startFTMS();
    _loadUserSettings();
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

  Future<void> _loadConfigForFtmsDeviceType(
      DeviceDataType ftmsMachineType) async {
    final config = await LiveDataDisplayConfig.loadForFtmsMachineType(
        DeviceType.fromFtms(ftmsMachineType));
    setState(() {
      _config = config;
      _configError = config == null ? 'No config for this machine type' : null;
    });

    // Configure data processor for averaging
    if (config != null) {
      _dataProcessor.configure(config);
    }

    // Check if device is available based on developer mode
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
    if (!_started) {
      _started = true;
      await FTMS.useDeviceDataCharacteristic(
        widget.ftmsDevice,
        (DeviceData data) {
          ftmsBloc.ftmsDeviceDataControllerSink.add(data);
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: StreamBuilder<DeviceData?>(
        stream: ftmsBloc.ftmsDeviceDataControllerStream,
        builder: (c, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: Text(AppLocalizations.of(context)!.noFtmsDataFound));
          }
          final deviceData = snapshot.data!;
          // Load config if not loaded or if type changed
          if (_config == null || _configError != null) {
            _loadConfigForFtmsDeviceType(deviceData.deviceDataType);
            if (_configError != null) {
              return Center(child: Text(_configError!));
            }
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
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
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
                        Navigator.of(context)
                            .pop(); // Go back to previous screen
                      },
                      icon: const Icon(Icons.arrow_back),
                      label: Text(AppLocalizations.of(context)!.goBack),
                    ),
                  ],
                ),
              ),
            );
          }

          // Show normal device data content
          final parameterValues = deviceData.getDeviceDataParameterValues();
          logFtmsParameterAttributes(parameterValues);

          // Process device data with averaging
          final paramValueMap = _dataProcessor.processDeviceData(deviceData);

          return Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                Text(
                  FTMS.convertDeviceDataTypeToString(deviceData.deviceDataType),
                  textScaler: const TextScaler.linear(4),
                  style: TextStyle(color: Theme.of(context).primaryColor),
                ),
                FtmsLiveDataDisplayWidget(
                  config: _config!,
                  paramValueMap: paramValueMap,
                  defaultColor: Colors.blue,
                  machineType: DeviceType.fromFtms(deviceData.deviceDataType),
                ),
                const SizedBox(height: 24),
                // Start Training Button
                Align(
                  alignment: Alignment.bottomCenter,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow),
                    label: Text(AppLocalizations.of(context)!.loadTrainingSessionButton),
                    onPressed: () async {
                      logger.i(
                          'Start Training pressed. deviceData.deviceDataType: '
                          '${deviceData.deviceDataType}');
                      // Load training sessions (default user settings are now loaded inside the loader)
                      final storageService = TrainingSessionStorageService();
                      final sessions = await storageService.loadTrainingSessions(
                          DeviceType.fromFtms(deviceData.deviceDataType));
                      if (sessions.isEmpty) {
                        if (!context.mounted) return;
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(AppLocalizations.of(context)!.noTrainingSessions),
                            content: Text(
                                'No training sessions found for this machine type.'),
                          ),
                        );
                        return;
                      }
                      if (!context.mounted) return;
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (context) => DraggableScrollableSheet(
                          expand: false,
                          initialChildSize: 0.7,
                          minChildSize: 0.4,
                          maxChildSize: 0.95,
                          builder: (context, scrollController) {
                            return TrainingSessionExpansionPanelList(
                              sessions: sessions,
                              scrollController: scrollController,
                              userSettings: _userSettings,
                              configs: _configs,
                            );
                          },
                        ),
                      ).then((selectedSession) {
                        if (selectedSession != null && context.mounted) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  TrainingSessionProgressScreen(
                                session: selectedSession,
                                ftmsDevice: widget.ftmsDevice,
                                gpxAssetPath: null,
                              ),
                            ),
                          );
                        }
                      });
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
