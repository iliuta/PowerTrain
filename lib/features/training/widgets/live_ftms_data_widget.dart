import 'package:flutter/material.dart';
import 'package:ftms/core/models/device_types.dart';
import 'package:ftms/core/models/processed_ftms_data.dart';
import 'package:ftms/l10n/app_localizations.dart';
import '../../../core/bloc/ftms_bloc.dart';
import '../../../core/config/live_data_display_config.dart';
import '../../../core/widgets/ftms_live_data_display_widget.dart';

/// Widget for displaying live FTMS data during training
class LiveFTMSDataWidget extends StatefulWidget {
  final Map<String, dynamic>? targets;
  final DeviceType machineType;

  const LiveFTMSDataWidget({
    super.key,
    this.targets,
    required this.machineType,
  });

  @override
  State<LiveFTMSDataWidget> createState() => _LiveFTMSDataWidgetState();
}

class _LiveFTMSDataWidgetState extends State<LiveFTMSDataWidget> {
  LiveDataDisplayConfig? _config;
  String? _configError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    // Load config based on the widget's machine type
    final config = await LiveDataDisplayConfig.loadForFtmsMachineType(widget.machineType);
    setState(() {
      _config = config;
      _configError = config == null ? AppLocalizations.of(context)!.noConfigForMachineType : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_configError != null) {
      return Text(_configError!, style: const TextStyle(color: Colors.red));
    }
    if (_config == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: SizedBox.expand(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: StreamBuilder<ProcessedFtmsData?>(
                  stream: ftmsBloc.ftmsDeviceDataControllerStream,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(AppLocalizations.of(context)!.noFtmsData),
                      );
                    }
                    final processedData = snapshot.data!;

                    // Use already processed data directly
                    return FtmsLiveDataDisplayWidget(
                      config: _config!,
                      paramValueMap: processedData.paramValueMap,
                      targets: widget.targets,
                      machineType: widget.machineType,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
