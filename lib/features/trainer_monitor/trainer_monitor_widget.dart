import 'package:flutter/material.dart';
import '../../core/models/zwift_trainer_data.dart';
import '../../core/services/ftms_service.dart';

/// Widget to display and monitor Zwift trainer data in real-time
/// 
/// Shows:
/// - Current riding metrics (power, cadence, speed, HR)
/// - Trainer control settings (target power, simulation params)
/// - Raw protocol messages for debugging
class TrainerMonitorWidget extends StatefulWidget {
  final FTMSService ftmsService;
  final bool showDebugInfo;
  
  const TrainerMonitorWidget({
    super.key,
    required this.ftmsService,
    this.showDebugInfo = false,
  });
  
  @override
  State<TrainerMonitorWidget> createState() => _TrainerMonitorWidgetState();
}

class _TrainerMonitorWidgetState extends State<TrainerMonitorWidget> {
  ZwiftTrainerStatus? _status;
  final List<Map<String, dynamic>> _recentMessages = [];
  bool _isMonitoring = false;
  
  @override
  void initState() {
    super.initState();
    _setupListeners();
  }
  
  void _setupListeners() {
    // Listen to trainer status updates
    widget.ftmsService.trainerStatusStream.listen((status) {
      if (mounted) {
        setState(() {
          _status = status;
        });
      }
    });
    
    // Listen to raw messages for debugging
    if (widget.showDebugInfo) {
      widget.ftmsService.rawMessageStream.listen((message) {
        if (mounted) {
          setState(() {
            _recentMessages.insert(0, message);
            if (_recentMessages.length > 10) {
              _recentMessages.removeLast();
            }
          });
        }
      });
    }
  }
  
  Future<void> _toggleMonitoring() async {
    try {
      if (_isMonitoring) {
        await widget.ftmsService.stopMonitoring();
      } else {
        await widget.ftmsService.startMonitoring();
      }
      setState(() {
        _isMonitoring = !_isMonitoring;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
  
  Future<void> _requestInfo() async {
    try {
      await widget.ftmsService.requestTrainerInfo(0);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Info request sent')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.bluetooth_connected, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Trainer Monitor',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _toggleMonitoring,
                  icon: Icon(_isMonitoring ? Icons.stop : Icons.play_arrow),
                  label: Text(_isMonitoring ? 'Stop' : 'Start'),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _requestInfo,
                  icon: const Icon(Icons.info_outline),
                  tooltip: 'Request Info',
                ),
              ],
            ),
            const Divider(),
            
            // Riding Data Section
            _buildRidingDataSection(),
            const SizedBox(height: 16),
            
            // Control Settings Section
            _buildControlSection(),
            
            // Debug Section
            if (widget.showDebugInfo) ...[
              const SizedBox(height: 16),
              _buildDebugSection(),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildRidingDataSection() {
    final ridingData = _status?.ridingData;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Riding Metrics',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            _buildMetric(
              'Power',
              ridingData?.power?.toString() ?? '--',
              'W',
              Icons.flash_on,
              Colors.orange,
            ),
            _buildMetric(
              'Cadence',
              ridingData?.cadence?.toString() ?? '--',
              'RPM',
              Icons.sync,
              Colors.blue,
            ),
            _buildMetric(
              'Speed',
              ridingData?.speedKmh?.toStringAsFixed(1) ?? '--',
              'km/h',
              Icons.speed,
              Colors.green,
            ),
            _buildMetric(
              'Heart Rate',
              ridingData?.heartRate?.toString() ?? '--',
              'BPM',
              Icons.favorite,
              Colors.red,
            ),
          ],
        ),
        if (ridingData != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'Updated: ${_formatTime(ridingData.timestamp)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
  
  Widget _buildControlSection() {
    final control = _status?.control;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Trainer Control',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        if (control == null)
          const Text('No control data yet', style: TextStyle(fontStyle: FontStyle.italic))
        else ...[
          if (control.powerTarget != null)
            _buildControlRow('Target Power', '${control.powerTarget} W'),
          if (control.resistancePercent != null)
            _buildControlRow('Resistance', '${control.resistancePercent}%'),
          if (control.simulation != null) ...[
            const SizedBox(height: 4),
            const Text('Simulation Mode:', style: TextStyle(fontWeight: FontWeight.bold)),
            if (control.simulation!.inclinePercent != null)
              _buildControlRow('  Grade', '${control.simulation!.inclinePercent!.toStringAsFixed(2)}%'),
            if (control.simulation!.windMps != null)
              _buildControlRow('  Wind', '${control.simulation!.windMps!.toStringAsFixed(1)} m/s'),
            if (control.simulation!.cwa != null)
              _buildControlRow('  CWa', control.simulation!.cwa!.toStringAsFixed(4)),
            if (control.simulation!.crr != null)
              _buildControlRow('  Crr', control.simulation!.crr!.toStringAsFixed(5)),
          ],
          if (control.physical != null) ...[
            const SizedBox(height: 4),
            const Text('Physical:', style: TextStyle(fontWeight: FontWeight.bold)),
            if (control.physical!.bikeWeightKg != null)
              _buildControlRow('  Bike', '${control.physical!.bikeWeightKg!.toStringAsFixed(1)} kg'),
            if (control.physical!.riderWeightKg != null)
              _buildControlRow('  Rider', '${control.physical!.riderWeightKg!.toStringAsFixed(1)} kg'),
            if (control.physical!.gearRatio != null)
              _buildControlRow('  Gear Ratio', control.physical!.gearRatio!.toStringAsFixed(2)),
          ],
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'Updated: ${_formatTime(control.timestamp)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ],
    );
  }
  
  Widget _buildDebugSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        Text(
          'Debug: Recent Messages',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 200,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(4),
          ),
          child: ListView.builder(
            itemCount: _recentMessages.length,
            itemBuilder: (context, index) {
              final msg = _recentMessages[index];
              return Text(
                '${msg['type']}: ${msg['data']}',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: Colors.greenAccent,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildMetric(String label, String value, String unit, IconData icon, Color color) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildControlRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
  
  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inSeconds < 5) return 'just now';
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }
}
