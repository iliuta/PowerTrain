import 'package:flutter/material.dart';
import '../../core/services/ftms_service.dart';
import '../trainer_monitor/trainer_monitor_widget.dart';

/// Demo page showing how to monitor and control a Zwift trainer
/// 
/// This demonstrates:
/// 1. Starting monitoring to read trainer data (0x03 messages)
/// 2. Viewing current trainer control settings (0x04 messages)
/// 3. Sending control commands (power target, simulation mode)
/// 
/// Usage:
/// 1. Connect to your trainer first
/// 2. Press "Start" to begin monitoring
/// 3. Observe riding metrics and control settings
/// 4. Use control buttons to send commands
class TrainerControlDemo extends StatefulWidget {
  final FTMSService ftmsService;
  
  const TrainerControlDemo({
    super.key,
    required this.ftmsService,
  });
  
  @override
  State<TrainerControlDemo> createState() => _TrainerControlDemoState();
}

class _TrainerControlDemoState extends State<TrainerControlDemo> {
  final _powerController = TextEditingController(text: '150');
  final _gradeController = TextEditingController(text: '2.5');
  final _bikeWeightController = TextEditingController(text: '8.0');
  final _riderWeightController = TextEditingController(text: '75.0');
  bool _showDebug = false;
  
  @override
  void dispose() {
    _powerController.dispose();
    _gradeController.dispose();
    _bikeWeightController.dispose();
    _riderWeightController.dispose();
    super.dispose();
  }
  
  Future<void> _setTargetPower() async {
    try {
      final watts = int.parse(_powerController.text);
      await widget.ftmsService.setZwiftPower(watts);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Target power set to $watts W')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
  
  Future<void> _setSimulationGrade() async {
    try {
      final grade = double.parse(_gradeController.text);
      final gradeX100 = (grade * 100).round();
      
      await widget.ftmsService.setZwiftSimulation(
        windSpeedX100: 0,
        inclineX100: gradeX100,
        cwaX10000: 5100,  // Zwift default
        crrX100000: 400,  // Zwift default
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Grade set to $grade%')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
  
  Future<void> _setPowerViaSlope() async {
    try {
      final watts = int.parse(_powerController.text);
      final riderKg = double.parse(_riderWeightController.text);
      
      await widget.ftmsService.setZwiftPowerViaSlope(
        watts,
        riderMassKg: riderKg,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Power simulation set to $watts W')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
  
  Future<void> _setPhysicalParams() async {
    try {
      final bikeKg = double.parse(_bikeWeightController.text);
      final riderKg = double.parse(_riderWeightController.text);
      
      await widget.ftmsService.initializeZwiftSession(
        bikeWeightKg: bikeKg,
        riderWeightKg: riderKg,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Weights set: Bike $bikeKg kg, Rider $riderKg kg')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zwift Trainer Control'),
        actions: [
          IconButton(
            icon: Icon(_showDebug ? Icons.bug_report : Icons.bug_report_outlined),
            onPressed: () {
              setState(() {
                _showDebug = !_showDebug;
              });
            },
            tooltip: 'Toggle Debug',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info Card
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          'How to Use',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[900],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '1. Press "Start" in the monitor to begin receiving data\n'
                      '2. Observe real-time power, cadence, speed, and HR\n'
                      '3. Use controls below to set target power or grade\n'
                      '4. Watch the trainer respond to your commands',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Trainer Monitor
            TrainerMonitorWidget(
              ftmsService: widget.ftmsService,
              showDebugInfo: _showDebug,
            ),
            const SizedBox(height: 24),
            
            // Control Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trainer Controls',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Divider(),
                    
                    // ERG Mode Control
                    const Text(
                      'ERG Mode (Direct Power Target)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _powerController,
                            decoration: const InputDecoration(
                              labelText: 'Target Power (W)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _setTargetPower,
                          child: const Text('Set Power'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Note: Direct power target may not work on all trainers',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.orange,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Simulation Mode Control
                    const Text(
                      'Simulation Mode (Slope-based)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _gradeController,
                            decoration: const InputDecoration(
                              labelText: 'Grade (%)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _setSimulationGrade,
                          child: const Text('Set Grade'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Power via Slope
                    const Text(
                      'ERG Simulation (Power → Slope)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _setPowerViaSlope,
                      icon: const Icon(Icons.trending_up),
                      label: Text('Simulate ${_powerController.text}W via Slope'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Converts power target to equivalent slope (more compatible)',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.green,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Physical Parameters
                    const Divider(),
                    const Text(
                      'Physical Parameters',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _bikeWeightController,
                            decoration: const InputDecoration(
                              labelText: 'Bike Weight (kg)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _riderWeightController,
                            decoration: const InputDecoration(
                              labelText: 'Rider Weight (kg)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _setPhysicalParams,
                      child: const Text('Update Weights'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Protocol Info
            Card(
              color: Colors.grey[100],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Zwift Protocol Information',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Message Types:\n'
                      '• 0x03: Riding Data (power, cadence, speed, HR)\n'
                      '• 0x04: Trainer Control (power target, simulation params)\n'
                      '• 0x00: Info Request/Response\n\n'
                      'Based on reverse-engineered protocol:\n'
                      'https://www.makinolo.com/blog/2024/10/20/zwift-trainer-protocol/',
                      style: TextStyle(fontSize: 12, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
