// This file was moved from lib/ftms_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_ftms/flutter_ftms.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../core/services/ftms_service.dart';
import 'ftms_session_selector_tab.dart';

class FTMSPage extends StatefulWidget {
  final BluetoothDevice ftmsDevice;

  const FTMSPage({super.key, required this.ftmsDevice});

  @override
  State<FTMSPage> createState() => _FTMSPageState();
}

class _FTMSPageState extends State<FTMSPage> {
  late final FTMSService _ftmsService;

  @override
  void initState() {
    super.initState();
    _ftmsService = FTMSService(widget.ftmsDevice);
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
      body: FTMSessionSelectorTab(
        ftmsDevice: widget.ftmsDevice,
        writeCommand: writeCommand,
      ),
    );
  }
}
