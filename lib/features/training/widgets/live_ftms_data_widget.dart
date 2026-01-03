import 'package:flutter/material.dart';
import 'package:flutter_ftms/flutter_ftms.dart';
import 'package:ftms/core/models/device_types.dart';
import 'package:ftms/l10n/app_localizations.dart';
import '../../../core/bloc/ftms_bloc.dart';
import '../../../core/config/live_data_display_config.dart';
import '../../../core/widgets/ftms_live_data_display_widget.dart';
import '../../../core/services/ftms_data_processor.dart';

/// Widget for displaying live FTMS data during training
class LiveFTMSDataWidget extends StatefulWidget {
  final BluetoothDevice ftmsDevice;
  final Map<String, dynamic>? targets;
  final DeviceType machineType;

  const LiveFTMSDataWidget({
    super.key,
    required this.ftmsDevice,
    this.targets,
    required this.machineType,
  });

  @override
  State<LiveFTMSDataWidget> createState() => _LiveFTMSDataWidgetState();
}

class _LiveFTMSDataWidgetState extends State<LiveFTMSDataWidget> {
  LiveDataDisplayConfig? _config;
  String? _configError;
  final FtmsDataProcessor _dataProcessor = FtmsDataProcessor();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final deviceDataType = await _getDeviceType();
    if (deviceDataType == null) {
      setState(() {
        _config = null;
        _configError = AppLocalizations.of(context)!.deviceTypeNotDetected;
      });
      return;
    }
    final deviceType = DeviceType.fromFtms(deviceDataType);
    final config = await LiveDataDisplayConfig.loadForFtmsMachineType(deviceType);
    setState(() {
      _config = config;
      _configError = config == null ? AppLocalizations.of(context)!.noConfigForMachineType : null;
    });

    if (config != null) {
      _dataProcessor.configure(config);
    }
  }

  Future<DeviceDataType?> _getDeviceType() async {
    // Try to get the latest device data from the stream
    final snapshot = await ftmsBloc.ftmsDeviceDataControllerStream
        .firstWhere((d) => d != null);
    return snapshot?.deviceDataType;
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
                child: StreamBuilder<DeviceData?>(
                  stream: ftmsBloc.ftmsDeviceDataControllerStream,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(AppLocalizations.of(context)!.noFtmsData),
                      );
                    }
                    final deviceData = snapshot.data!;

                    // Process device data with averaging
                    final paramValueMap =
                        _dataProcessor.processDeviceData(deviceData);

                    return FtmsLiveDataDisplayWidget(
                      config: _config!,
                      paramValueMap: paramValueMap,
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
