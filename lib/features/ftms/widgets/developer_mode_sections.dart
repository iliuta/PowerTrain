import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../ftms_machine_features_tab.dart';
import '../ftms_device_data_features_tab.dart';
import 'package:flutter_ftms/flutter_ftms.dart';
import 'expandable_card_section.dart';

/// Widget for developer mode sections (Machine Features and Device Data Features)
class DeveloperModeSections extends StatefulWidget {
  final BluetoothDevice ftmsDevice;
  final Future<void> Function(MachineControlPointOpcodeType) writeCommand;
  final bool isMachineFeaturesExpanded;
  final bool isDeviceDataFeaturesExpanded;
  final VoidCallback onMachineFeaturesExpandChanged;
  final VoidCallback onDeviceDataFeaturesExpandChanged;

  const DeveloperModeSections({
    super.key,
    required this.ftmsDevice,
    required this.writeCommand,
    required this.isMachineFeaturesExpanded,
    required this.isDeviceDataFeaturesExpanded,
    required this.onMachineFeaturesExpandChanged,
    required this.onDeviceDataFeaturesExpandChanged,
  });

  @override
  State<DeveloperModeSections> createState() => _DeveloperModeSectionsState();
}

class _DeveloperModeSectionsState extends State<DeveloperModeSections> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Device Data Features Section
        ExpandableCardSection(
          title: AppLocalizations.of(context)!.deviceDataFeatures,
          isExpanded: widget.isDeviceDataFeaturesExpanded,
          onExpandChanged: widget.onDeviceDataFeaturesExpandChanged,
          content: _buildDeviceDataFeaturesContent(),
        ),
        const SizedBox(height: 16),
        // Machine Features Section
        ExpandableCardSection(
          title: AppLocalizations.of(context)!.machineFeatures,
          isExpanded: widget.isMachineFeaturesExpanded,
          onExpandChanged: widget.onMachineFeaturesExpandChanged,
          content: _buildMachineFeaturesContent(),
        ),
      ],
    );
  }

  Widget _buildDeviceDataFeaturesContent() {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.5,
      child: FTMSDeviceDataFeaturesTab(
        ftmsDevice: widget.ftmsDevice,
      ),
    );
  }

  Widget _buildMachineFeaturesContent() {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: FTMSMachineFeaturesTab(
        ftmsDevice: widget.ftmsDevice,
        writeCommand: widget.writeCommand,
      ),
    );
  }
}
