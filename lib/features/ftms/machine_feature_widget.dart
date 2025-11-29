// This file was moved from lib/machine_feature_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ftms/flutter_ftms.dart';

import '../../core/bloc/ftms_bloc.dart';
import '../../core/services/ftms_service.dart';

class MachineFeatureWidget extends StatefulWidget {
  final BluetoothDevice ftmsDevice;

  const MachineFeatureWidget({super.key, required this.ftmsDevice});

  @override
  State<MachineFeatureWidget> createState() => _MachineFeatureWidgetState();
}

class _MachineFeatureWidgetState extends State<MachineFeatureWidget> {
  final Map<String, TextEditingController> _controllers = {};
  String? _lastError;
  bool _isLoading = false;
  
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
      final machineFeature = await FTMS.readMachineFeatureCharacteristic(widget.ftmsDevice);
      ftmsBloc.ftmsMachineFeaturesControllerSink.add(machineFeature);
    } catch (e) {
      setState(() => _lastError = 'Failed to load features: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  TextEditingController _getController(String key, String defaultValue) {
    if (!_controllers.containsKey(key)) {
      _controllers[key] = TextEditingController(text: defaultValue);
    }
    return _controllers[key]!;
  }
  
  Future<void> _executeCommand(MachineControlPointOpcodeType opcode, {int? value}) async {
    final ftmsService = FTMSService(widget.ftmsDevice);
    setState(() => _lastError = null);
    
    try {
      switch (opcode) {
        case MachineControlPointOpcodeType.setTargetResistanceLevel:
          await ftmsService.writeCommand(opcode, resistanceLevel: value);
          break;
        case MachineControlPointOpcodeType.setTargetPower:
          await ftmsService.writeCommand(opcode, power: value);
          break;
        default:
          await ftmsService.writeCommand(opcode);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Command ${opcode.name} sent successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      setState(() => _lastError = e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Failed: $e'), backgroundColor: Colors.red, duration: const Duration(seconds: 5)),
        );
      }
    }
  }
  
  Future<void> _executeZwiftPower(int watts) async {
    final ftmsService = FTMSService(widget.ftmsDevice);
    setState(() => _lastError = null);
    
    try {
      // Use slope-based ERG simulation (Zwift doesn't support PowerTarget with trainers)
      await ftmsService.setZwiftPowerViaSlope(watts);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Zwift ERG (slope-based) set to ${watts}W'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() => _lastError = e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Zwift command failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
  
  Future<void> _executeZwiftResistance(int percent) async {
    final ftmsService = FTMSService(widget.ftmsDevice);
    setState(() => _lastError = null);
    
    try {
      await ftmsService.setZwiftResistance(percent);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Zwift resistance set to ${percent}%'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _lastError = e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Zwift command failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
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
                        SnackBar(content: Text('Invalid value. Range: $minValue-$maxValue')),
                      );
                      return;
                    }
                  }
                  await _executeCommand(relatedCommand, value: value);
                },
                icon: const Icon(Icons.send, size: 16),
                label: const Text('Test'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: const Size(80, 36),
                ),
              )
            else if (!isSupported)
              const Text(
                'Not available',
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
                ? const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Loading machine features...'),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("No Machine Features found!"),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadMachineFeatures,
                        icon: const Icon(Icons.refresh),
                        label: const Text("Retry"),
                      ),
                    ],
                  ),
          );
        }
        
        final features = snapshot.data!.getFeatureFlags();
        final deviceName = widget.ftmsDevice.platformName;
        final isZwiftHub = deviceName.toLowerCase().contains('zwift');
        
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
              
              // Zwift Hub proprietary controls
              if (isZwiftHub)
                Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple[50],
                    border: Border.all(color: Colors.purple, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.science, color: Colors.purple),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Zwift Proprietary Controls',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Using reverse-engineered Zwift protocol (bypasses FTMS)',
                        style: TextStyle(fontSize: 11, color: Colors.black54),
                      ),
                      const SizedBox(height: 12),
                      
                      // ERG Power Control (via slope simulation)
                      Row(
                        children: [
                          const Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('ERG Power', style: TextStyle(fontWeight: FontWeight.w500)),
                                Text('(slope-based)', style: TextStyle(fontSize: 10, color: Colors.black45)),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 80,
                            child: TextField(
                              controller: _getController('zwift_power', '150'),
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: const InputDecoration(
                                labelText: 'Watts',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final watts = int.tryParse(_getController('zwift_power', '150').text);
                              if (watts == null || watts < 0 || watts > 2000) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Invalid power. Range: 0-2000W')),
                                );
                                return;
                              }
                              await _executeZwiftPower(watts);
                            },
                            icon: const Icon(Icons.bolt, size: 16),
                            label: const Text('Set'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // Resistance Control
                      Row(
                        children: [
                          const Expanded(
                            flex: 2,
                            child: Text('Resistance', style: TextStyle(fontWeight: FontWeight.w500)),
                          ),
                          SizedBox(
                            width: 80,
                            child: TextField(
                              controller: _getController('zwift_resistance', '50'),
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: const InputDecoration(
                                labelText: '%',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final percent = int.tryParse(_getController('zwift_resistance', '50').text);
                              if (percent == null || percent < 0 || percent > 100) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Invalid resistance. Range: 0-100%')),
                                );
                                return;
                              }
                              await _executeZwiftResistance(percent);
                            },
                            icon: const Icon(Icons.fitness_center, size: 16),
                            label: const Text('Set'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ],
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
              const Padding(
                padding: EdgeInsets.all(12.0),
                child: Text(
                  'Control Features (Interactive):',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              
              _buildFeatureControl(
                'Resistance Level',
                features[MachineFeatureFlag.resistanceLevelFlag] ?? false,
                relatedCommand: MachineControlPointOpcodeType.setTargetResistanceLevel,
                needsInput: true,
                inputLabel: 'Level',
                defaultValue: '50',
                minValue: 0,
                maxValue: 200,
              ),
              
              _buildFeatureControl(
                'Power Target (ERG Mode)',
                features[MachineFeatureFlag.powerMeasurementFlag] ?? false,
                relatedCommand: MachineControlPointOpcodeType.setTargetPower,
                needsInput: true,
                inputLabel: 'Watts',
                defaultValue: '150',
                minValue: 0,
                maxValue: 1000,
              ),
              
              _buildFeatureControl(
                'Inclination',
                features[MachineFeatureFlag.inclinationFlag] ?? false,
                relatedCommand: MachineControlPointOpcodeType.setTargetInclination,
              ),
              
              const Divider(),
              
              // General commands
              const Padding(
                padding: EdgeInsets.all(12.0),
                child: Text(
                  'General Commands:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              
              _buildFeatureControl(
                'Request Control',
                true,
                relatedCommand: MachineControlPointOpcodeType.requestControl,
              ),
              
              _buildFeatureControl(
                'Start/Resume',
                true,
                relatedCommand: MachineControlPointOpcodeType.startOrResume,
              ),
              
              _buildFeatureControl(
                'Stop/Pause',
                true,
                relatedCommand: MachineControlPointOpcodeType.stopOrPause,
              ),
              
              _buildFeatureControl(
                'Reset',
                true,
                relatedCommand: MachineControlPointOpcodeType.reset,
              ),
              
              const Divider(),
              
              // Read-only features
              const Padding(
                padding: EdgeInsets.all(12.0),
                child: Text(
                  'Data Features (Read-only):',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              
              _buildFeatureControl(
                'Average Speed',
                features[MachineFeatureFlag.averageSpeedFlag] ?? false,
              ),
              
              _buildFeatureControl(
                'Cadence',
                features[MachineFeatureFlag.cadenceFlag] ?? false,
              ),
              
              _buildFeatureControl(
                'Total Distance',
                features[MachineFeatureFlag.totalDistanceFlag] ?? false,
              ),
              
              _buildFeatureControl(
                'Heart Rate',
                features[MachineFeatureFlag.heartRateFlag] ?? false,
              ),
              
              _buildFeatureControl(
                'Power Measurement',
                features[MachineFeatureFlag.powerMeasurementFlag] ?? false,
              ),
              
              _buildFeatureControl(
                'Elapsed Time',
                features[MachineFeatureFlag.elapsedTimeFlag] ?? false,
              ),
              
              _buildFeatureControl(
                'Expended Energy',
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

