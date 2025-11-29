import 'package:flutter/material.dart';
import 'package:flutter_ftms/flutter_ftms.dart';
import 'machine_feature_widget.dart';

class FTMSMachineFeaturesTab extends StatelessWidget {
  final BluetoothDevice ftmsDevice;
  final void Function(MachineControlPointOpcodeType) writeCommand;
  const FTMSMachineFeaturesTab({super.key, required this.ftmsDevice, required this.writeCommand});

  @override
  Widget build(BuildContext context) {
    return MachineFeatureWidget(ftmsDevice: ftmsDevice);
  }
}

