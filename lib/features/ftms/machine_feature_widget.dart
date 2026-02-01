// This file was moved from lib/machine_feature_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ftms/flutter_ftms.dart';

import '../../core/bloc/ftms_bloc.dart';
import '../../core/models/supported_resistance_level_range.dart';
import '../../core/models/supported_power_range.dart';
import '../../core/services/devices/ftms.dart';
import '../../l10n/app_localizations.dart';
import '../../core/utils/logger.dart';

class MachineFeatureWidget extends StatefulWidget {
  const MachineFeatureWidget({super.key});

  @override
  State<MachineFeatureWidget> createState() => _MachineFeatureWidgetState();
}

class _MachineFeatureWidgetState extends State<MachineFeatureWidget> {
  final Ftms _ftms = Ftms();
  final Map<String, TextEditingController> _controllers = {};
  String? _lastError;
  bool _isLoading = false;
  SupportedResistanceLevelRange? _resistanceLevelRange;
  SupportedPowerRange? _powerRange;
  
  @override
  void initState() {
    super.initState();
    // Auto-load machine features when widget is displayed
    _loadMachineFeatures();
  }
  
  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
  
  Future<void> _loadMachineFeatures() async {
    setState(() => _isLoading = true);
    try {
      final device = _ftms.connectedDevice;
      if (device == null) {
        setState(() => _lastError = 'No device connected');
        return;
      }
      final machineFeature = await FTMS.readMachineFeatureCharacteristic(device);
      ftmsBloc.ftmsMachineFeaturesControllerSink.add(machineFeature);
      
      // Also try to load supported resistance level range and power range
      _loadSupportedResistanceLevelRange();
      _loadSupportedPowerRange();
    } catch (e) {
      setState(() => _lastError = 'Failed to load features: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _loadSupportedResistanceLevelRange() async {
    try {
      final range = await _ftms.readSupportedResistanceLevelRange();
      setState(() => _resistanceLevelRange = range);
    } catch (e) {
      // Not all devices support this characteristic, so we silently fail
      logger.d('Supported Resistance Level Range not available: $e');
    }
  }
  
  Future<void> _loadSupportedPowerRange() async {
    try {
      final range = await _ftms.readSupportedPowerRange();
      setState(() => _powerRange = range);
    } catch (e) {
      // Not all devices support this characteristic, so we silently fail
      logger.d('Supported Power Range not available: $e');
    }
  }
  
  TextEditingController _getController(String key, String defaultValue) {
    if (!_controllers.containsKey(key)) {
      _controllers[key] = TextEditingController(text: defaultValue);
    }
    return _controllers[key]!;
  }
  
  Future<void> _executeCommand(MachineControlPointOpcodeType opcode, {int? value}) async {
    setState(() => _lastError = null);
    
    try {
      switch (opcode) {
        case MachineControlPointOpcodeType.setTargetResistanceLevel:
          await _ftms.writeCommand(opcode, resistanceLevel: value);
          break;
        case MachineControlPointOpcodeType.setTargetPower:
          await _ftms.writeCommand(opcode, power: value);
          break;
        default:
          await _ftms.writeCommand(opcode);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.commandSent(opcode.name)), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      setState(() => _lastError = e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.commandFailed(e.toString())), backgroundColor: Colors.red, duration: const Duration(seconds: 5)),
        );
      }
    }
  }
  

  Widget _buildFeatureControl(String featureName, bool isSupported, {
    MachineControlPointOpcodeType? relatedCommand,
    bool needsInput = false,
    String inputLabel = 'Value',
    String defaultValue = '0',
    int minValue = 0,
    int maxValue = 1000,
  }) {
    final controller = needsInput ? _getController(featureName, defaultValue) : null;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: isSupported ? null : Colors.grey[300],
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            // Feature indicator
            Icon(
              isSupported ? Icons.check_circle : Icons.cancel,
              color: isSupported ? Colors.green : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 8),
            
            // Feature name
            Expanded(
              flex: 2,
              child: Text(
                featureName,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: isSupported ? Colors.black : Colors.grey[600],
                ),
              ),
            ),
            
            // Input field if needed
            if (isSupported && needsInput && controller != null) ...[
              SizedBox(
                width: 80,
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: inputLabel,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            
            // Action button
            if (isSupported && relatedCommand != null)
              ElevatedButton.icon(
                onPressed: () async {
                  int? value;
                  if (needsInput && controller != null) {
                    value = int.tryParse(controller.text);
                    if (value == null || value < minValue || value > maxValue) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(AppLocalizations.of(context)!.invalidValueRange(minValue.toString(), maxValue.toString()))),
                      );
                      return;
                    }
                  }
                  await _executeCommand(relatedCommand, value: value);
                },
                icon: const Icon(Icons.send, size: 16),
                label: Text(AppLocalizations.of(context)!.test),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: const Size(80, 36),
                ),
              )
            else if (!isSupported)
              Text(
                AppLocalizations.of(context)!.notAvailable,
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MachineFeature?>(
      stream: ftmsBloc.ftmsMachineFeaturesControllerStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: _isLoading
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(AppLocalizations.of(context)!.loadingMachineFeatures),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(AppLocalizations.of(context)!.noMachineFeaturesFound),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadMachineFeatures,
                        icon: const Icon(Icons.refresh),
                        label: Text(AppLocalizations.of(context)!.retry),
                      ),
                    ],
                  ),
          );
        }
        
        final features = snapshot.data!.getFeatureFlags();
        final deviceName = _ftms.name;

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Device info
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.blue[50],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Device: $deviceName',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Raw Data: ${snapshot.data!.data}',
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
              
              // Error display
              if (_lastError != null)
                Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    border: Border.all(color: Colors.red),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Last Error: $_lastError',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () => setState(() => _lastError = null),
                      ),
                    ],
                  ),
                ),
              
              const Divider(),
              
              // Control features section
              Padding(
                padding: EdgeInsets.all(12.0),
                child: Text(
                  AppLocalizations.of(context)!.controlFeatures,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              
              _buildFeatureControl(
                AppLocalizations.of(context)!.resistanceLevel,
                (features[MachineFeatureFlag.resistanceLevelFlag] ?? false) && _resistanceLevelRange != null,
                relatedCommand: MachineControlPointOpcodeType.setTargetResistanceLevel,
                needsInput: true,
                inputLabel: 'Level (Ω)',
                defaultValue: '50',
                minValue: _resistanceLevelRange?.minControlValue ?? 0,
                maxValue: _resistanceLevelRange?.maxControlValue ?? 200,
              ),
              
              // Display supported resistance level range if available
              if (_resistanceLevelRange != null)
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  color: Colors.blue[50],
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Device Supported Range:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Min',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                Text(
                                  '${_resistanceLevelRange!.minResistanceLevel} Ω',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Max',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                Text(
                                  '${_resistanceLevelRange!.maxResistanceLevel} Ω',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Step',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                Text(
                                  '${_resistanceLevelRange!.minIncrement} Ω',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              
              _buildFeatureControl(
                AppLocalizations.of(context)!.powerTargetErgMode,
                (features[MachineFeatureFlag.powerMeasurementFlag] ?? false) && _powerRange != null,
                relatedCommand: MachineControlPointOpcodeType.setTargetPower,
                needsInput: true,
                inputLabel: 'Watts',
                defaultValue: '150',
                minValue: 0,
                maxValue: 1000,
              ),
              
              // Display supported power range if available
              if (_powerRange != null)
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  color: Colors.blue[50],
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                            const SizedBox(width: 8),
                            Text(
                              AppLocalizations.of(context)!.supportedRange,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Min',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                Text(
                                  '${_powerRange!.minPower.toStringAsFixed(0)} W',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Max',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                Text(
                                  '${_powerRange!.maxPower.toStringAsFixed(0)} W',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Increment',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                Text(
                                  '${_powerRange!.minIncrement.toStringAsFixed(0)} W',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              
              _buildFeatureControl(
                AppLocalizations.of(context)!.inclination,
                features[MachineFeatureFlag.inclinationFlag] ?? false,
                relatedCommand: MachineControlPointOpcodeType.setTargetInclination,
              ),
              
              const Divider(),
              
              // General commands
              Padding(
                padding: EdgeInsets.all(12.0),
                child: Text(
                  AppLocalizations.of(context)!.generalCommands,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              
              _buildFeatureControl(
                AppLocalizations.of(context)!.requestControl,
                true,
                relatedCommand: MachineControlPointOpcodeType.requestControl,
              ),
              
              _buildFeatureControl(
                AppLocalizations.of(context)!.startOrResume,
                true,
                relatedCommand: MachineControlPointOpcodeType.startOrResume,
              ),
              
              _buildFeatureControl(
                AppLocalizations.of(context)!.stopOrPause,
                true,
                relatedCommand: MachineControlPointOpcodeType.stopOrPause,
              ),
              
              _buildFeatureControl(
                AppLocalizations.of(context)!.resetCommand,
                true,
                relatedCommand: MachineControlPointOpcodeType.reset,
              ),
              
              const Divider(),
              
              // Read-only features
              Padding(
                padding: EdgeInsets.all(12.0),
                child: Text(
                  AppLocalizations.of(context)!.readOnlyFeatures,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              
              _buildFeatureControl(
                AppLocalizations.of(context)!.averageSpeed,
                features[MachineFeatureFlag.averageSpeedFlag] ?? false,
              ),
              
              _buildFeatureControl(
                AppLocalizations.of(context)!.cadence,
                features[MachineFeatureFlag.cadenceFlag] ?? false,
              ),
              
              _buildFeatureControl(
                AppLocalizations.of(context)!.totalDistance,
                features[MachineFeatureFlag.totalDistanceFlag] ?? false,
              ),
              
              _buildFeatureControl(
                AppLocalizations.of(context)!.heartRate,
                features[MachineFeatureFlag.heartRateFlag] ?? false,
              ),
              
              _buildFeatureControl(
                AppLocalizations.of(context)!.powerMeasurement,
                features[MachineFeatureFlag.powerMeasurementFlag] ?? false,
              ),
              
              _buildFeatureControl(
                AppLocalizations.of(context)!.elapsedTime,
                features[MachineFeatureFlag.elapsedTimeFlag] ?? false,
              ),
              
              _buildFeatureControl(
                AppLocalizations.of(context)!.expendedEnergy,
                features[MachineFeatureFlag.expendedEnergyFlag] ?? false,
              ),
              
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}

