// This file was moved from lib/ftms_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_ftms/flutter_ftms.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../core/services/ftms_service.dart';
import '../settings/model/user_settings.dart';
import 'ftms_machine_features_tab.dart';
import 'ftms_device_data_features_tab.dart';
import 'ftms_session_selector_tab.dart';

class FTMSPage extends StatefulWidget {
  final BluetoothDevice ftmsDevice;

  const FTMSPage({super.key, required this.ftmsDevice});

  @override
  State<FTMSPage> createState() => _FTMSPageState();
}

class _FTMSPageState extends State<FTMSPage> {
  late final FTMSService _ftmsService;
  UserSettings? _userSettings;
  bool _isLoadingSettings = true;

  @override
  void initState() {
    super.initState();
    _ftmsService = FTMSService(widget.ftmsDevice);
    _loadUserSettings();
  }

  Future<void> _loadUserSettings() async {
    final settings = await UserSettings.loadDefault();
    setState(() {
      _userSettings = settings;
      _isLoadingSettings = false;
    });
  }

  @override
  void dispose() {
    // Disable wakelock when leaving the FTMS device screen
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> writeCommand(MachineControlPointOpcodeType opcodeType) async {
    await _ftmsService.writeCommand(opcodeType);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.ftmsDevice.platformName),
        toolbarHeight: 40,
      ),
      body: Column(
        children: [
          // Main content: Session selector tab always visible
          Expanded(
            child: FTMSessionSelectorTab(ftmsDevice: widget.ftmsDevice),
          ),
          // Bottom navigation for the two remaining tabs - only show if developer mode is enabled
          if (_isLoadingSettings)
            Container(
              color: Theme.of(context).bottomAppBarTheme.color ??
                  Theme.of(context).colorScheme.surface,
              child: const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              ),
            )
          else if (_userSettings?.developerMode == true)
            Container(
              color: Theme.of(context).bottomAppBarTheme.color ??
                  Theme.of(context).colorScheme.surface,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Device Data Features button
                  TextButton.icon(
                    icon: const Icon(Icons.featured_play_list_outlined),
                    label: const Text('Device Data Features'),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        builder: (context) => SizedBox(
                          height: MediaQuery.of(context).size.height * 0.6,
                          child: FTMSDeviceDataFeaturesTab(
                              ftmsDevice: widget.ftmsDevice),
                        ),
                      );
                    },
                  ),
                  // Machine Features button
                  TextButton.icon(
                    icon: const Icon(Icons.settings),
                    label: const Text('Machine Features'),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (context) => DraggableScrollableSheet(
                          expand: false,
                          initialChildSize: 0.7,
                          minChildSize: 0.4,
                          maxChildSize: 0.95,
                          builder: (context, scrollController) =>
                              SingleChildScrollView(
                            controller: scrollController,
                            child: FTMSMachineFeaturesTab(
                              ftmsDevice: widget.ftmsDevice,
                              writeCommand: writeCommand,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
