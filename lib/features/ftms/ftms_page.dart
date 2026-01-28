// This file was moved from lib/ftms_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_ftms/flutter_ftms.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../core/services/devices/ftms.dart';
import 'ftms_session_selector_tab.dart';

class FTMSPage extends StatefulWidget {
  const FTMSPage({super.key});

  @override
  State<FTMSPage> createState() => _FTMSPageState();
}

class _FTMSPageState extends State<FTMSPage> {
  final Ftms _ftms = Ftms();

  @override
  void dispose() {
    // Disable wakelock when leaving the FTMS device screen
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> writeCommand(MachineControlPointOpcodeType opcodeType) async {
    await _ftms.writeCommand(opcodeType);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_ftms.name),
        toolbarHeight: 40,
      ),
      body: FTMSessionSelectorTab(
        writeCommand: writeCommand,
      ),
    );
  }
}
