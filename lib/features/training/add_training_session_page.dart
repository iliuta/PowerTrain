import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:ftms/core/models/device_types.dart';
import 'package:ftms/core/config/live_data_display_config.dart';
import 'package:ftms/core/config/live_data_field_config.dart';
import 'package:ftms/core/config/live_data_field_format_strategy.dart';
import '../../core/services/training_session_storage_service.dart';
import 'widgets/training_session_chart.dart';
import 'model/unit_training_interval.dart';
import 'model/group_training_interval.dart';
import 'model/training_interval.dart';
import 'model/training_session.dart';
import 'model/target_power_strategy.dart';
import '../../features/settings/model/user_settings.dart';

/// A page for creating new training sessions or editing existing ones
class AddTrainingSessionPage extends StatefulWidget {
  final DeviceType machineType;
  final TrainingSessionDefinition? existingSession;

  const AddTrainingSessionPage({
    super.key,
    required this.machineType,
    this.existingSession,
  });

  @override
  State<AddTrainingSessionPage> createState() => _AddTrainingSessionPageState();
}

class _AddTrainingSessionPageState extends State<AddTrainingSessionPage> {
  final TextEditingController _titleController = TextEditingController();
  final List<TrainingInterval> _intervals = [];
  LiveDataDisplayConfig? _config;
  UserSettings? _userSettings;
  bool _isLoading = true;

  // Check if we're in edit mode
  bool get _isEditMode => widget.existingSession != null;

  @override
  void initState() {
    super.initState();
    _loadConfiguration();
  }

  Future<void> _loadConfiguration() async {
    try {
      final config = await LiveDataDisplayConfig.loadForFtmsMachineType(widget.machineType);
      final userSettings = await UserSettings.loadDefault();

      setState(() {
        _config = config;
        _userSettings = userSettings;
        _isLoading = false;
      });

      // Initialize form with existing session data if in edit mode
      if (_isEditMode) {
        _initializeFromExistingSession();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load configuration: $e')),
        );
      }
    }
  }

  void _initializeFromExistingSession() {
    final session = widget.existingSession!;
    
    // Set the title
    _titleController.text = session.title;
    
    // Clear and populate intervals
    _intervals.clear();
    _intervals.addAll(session.intervals);
    
    setState(() {
      // Trigger rebuild to show the loaded data
    });
  }

  List<LiveDataFieldConfig> get _availableTargetFields {
    if (_config == null) return [];
    return _config!.fields.where((field) => field.availableAsTarget).toList();
  }

  List<UnitTrainingInterval> get _expandedIntervals {
    if (_userSettings == null) return [];
    
    final List<UnitTrainingInterval> expanded = [];
    for (final interval in _intervals) {
      // First expand targets (convert percentages to absolute values), then expand repetitions
      final expandedTargetsInterval = interval.expandTargets(
        machineType: widget.machineType,
        userSettings: _userSettings,
        config: _config,
      );
      expanded.addAll(expandedTargetsInterval.expand());
    }
    return expanded;
  }

  void _addUnitInterval() {
    setState(() {
      _intervals.add(UnitTrainingInterval(
        title: 'Interval ${_intervals.length + 1}',
        duration: 300, // 5 minutes default
        targets: {},
        resistanceLevel: null,
        repeat: 1,
      ));
    });
  }

  void _addGroupInterval() {
    setState(() {
      _intervals.add(GroupTrainingInterval(
        intervals: [
          UnitTrainingInterval(
            title: 'Interval 1',
            duration: 240, // 4 minutes
            targets: {},
            resistanceLevel: null,
          ),
        ],
        repeat: 3,
      ));
    });
  }

  void _removeInterval(int index) {
    setState(() {
      _intervals.removeAt(index);
    });
  }

  void _reorderIntervals(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final TrainingInterval item = _intervals.removeAt(oldIndex);
      _intervals.insert(newIndex, item);
    });
  }

  double _calculatePercentageFromValue(dynamic currentValue) {
    // Use the existing target power strategy for consistent calculations
    final strategy = TargetPowerStrategyFactory.getStrategy(widget.machineType);
    return strategy.calculatePercentageFromValue(currentValue, _userSettings) ?? 0.0;
  }

  double _calculateValueFromPercentage(double percentage) {
    // Use the existing target power strategy
    final strategy = TargetPowerStrategyFactory.getStrategy(widget.machineType);
    
    // Create a percentage string and let the strategy resolve it
    final percentageString = '${percentage.round()}%';
    final resolvedValue = strategy.resolvePower(percentageString, _userSettings);
    
    // If the strategy resolved it to a number, use that; otherwise return 0
    if (resolvedValue is num) {
      return resolvedValue.toDouble();
    }
    
    // Return 0 if strategy couldn't resolve the percentage
    return 0.0;
  }



  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Add Training Session')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_config == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Add Training Session')),
        body: const Center(
          child: Text('Unable to load configuration for this machine type'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Training Session' : 'Add Training Session'),
        actions: [
          ElevatedButton(
            onPressed: _intervals.isNotEmpty ? _saveSession : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Text(
              _isEditMode ? 'Update' : 'Save',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Session Title
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Session Title',
                hintText: 'Enter session name',
                border: OutlineInputBorder(),
              ),
            ),
          ),

          // Training Chart
          if (_expandedIntervals.isNotEmpty)
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Training Preview',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    TrainingSessionChart(
                      intervals: _expandedIntervals,
                      machineType: widget.machineType,
                      height: 120,
                      config: _config,
                    ),
                  ],
                ),
              ),
            ),

          // Intervals List
          Expanded(
            child: _intervals.isEmpty
                ? const Center(
                    child: Text(
                      'No intervals added yet.\nTap the + button to add intervals.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: _intervals.length,
                    onReorder: _reorderIntervals,
                    itemBuilder: (context, index) {
                      return _buildIntervalCard(index, _intervals[index]);
                    },
                    proxyDecorator: (child, index, animation) {
                      return AnimatedBuilder(
                        animation: animation,
                        builder: (context, child) {
                          final double animValue = Curves.easeInOut.transform(animation.value);
                          final double elevation = lerpDouble(0, 6, animValue)!;
                          return Material(
                            elevation: elevation,
                            shadowColor: Colors.black.withValues(alpha: 0.3),
                            child: child,
                          );
                        },
                        child: child,
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'add_group',
            onPressed: _addGroupInterval,
            tooltip: 'Add Group Interval',
            child: const Icon(Icons.repeat),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'add_unit',
            onPressed: _addUnitInterval,
            tooltip: 'Add Unit Interval',
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  Widget _buildIntervalCard(int index, TrainingInterval interval) {
    return Card(
      key: Key('interval_$index'),
      child: ExpansionTile(
        title: Row(
          children: [
            const Icon(Icons.drag_handle, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(
              child: Text(interval is GroupTrainingInterval
                  ? 'Group ${index + 1} (${interval.repeat ?? 1}x)'
                  : (interval is UnitTrainingInterval ? (interval.title ?? 'Interval ${index + 1}') : 'Interval ${index + 1}')),
            ),
          ],
        ),
        subtitle: Text(_getIntervalSubtitle(interval)),
        trailing: IconButton(
          icon: const Icon(Icons.delete),
          onPressed: () => _removeInterval(index),
          tooltip: 'Delete',
        ),
        children: [
          if (interval is UnitTrainingInterval)
            _buildUnitIntervalEditor(
              interval: interval,
              isEditing: true, // Always in edit mode
              onUpdate: (updatedInterval) => _updateUnitInterval(index, updatedInterval),
            )
          else if (interval is GroupTrainingInterval)
            _buildGroupIntervalEditor(interval),
        ],
      ),
    );
  }

  String _getIntervalSubtitle(TrainingInterval interval) {
    if (interval is UnitTrainingInterval) {
      final duration = Duration(seconds: interval.duration);
      return '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
    } else if (interval is GroupTrainingInterval) {
      final totalDuration = interval.intervals.fold<int>(0, (sum, i) => sum + i.duration);
      final repeatCount = interval.repeat ?? 1;
      final duration = Duration(seconds: totalDuration * repeatCount);
      return '${interval.intervals.length} intervals, ${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')} total';
    }
    return '';
  }

  Widget _buildUnitIntervalEditor({
    required UnitTrainingInterval interval,
    required bool isEditing,
    required Function(UnitTrainingInterval) onUpdate,
    String? labelPrefix,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title - always shown
          TextFormField(
            initialValue: interval.title ?? '',
            decoration: InputDecoration(
              labelText: '${labelPrefix ?? "Interval"} Title',
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (value) {
              onUpdate(UnitTrainingInterval(
                title: value.isEmpty ? null : value,
                duration: interval.duration,
                targets: interval.targets,
                resistanceLevel: interval.resistanceLevel,
                repeat: interval.repeat,
              ));
            },
          ),
          const SizedBox(height: 16),

          // Duration
          Row(
            children: [
              const Text('Duration: '),
              Expanded(
                child: Slider(
                  value: interval.duration.toDouble(),
                  min: 30,
                  max: 3600,
                  divisions: (3600 - 30) ~/ 30,
                  label: '${Duration(seconds: interval.duration).inMinutes}:${(interval.duration % 60).toString().padLeft(2, '0')}',
                  onChanged: (value) {
                    onUpdate(UnitTrainingInterval(
                      title: interval.title,
                      duration: value.round(),
                      targets: interval.targets,
                      resistanceLevel: interval.resistanceLevel,
                      repeat: interval.repeat,
                    ));
                  },
                ),
              ),
            ],
          ),

          // Targets
          const SizedBox(height: 16),
          const Text('Targets:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ..._availableTargetFields.map((field) => _buildTargetField(
            interval: interval,
            field: field,
            onUpdate: onUpdate,
          )),
          // Resistance Level
          const SizedBox(height: 16),
          Row(
            children: [
              const SizedBox(width: 100, child: Text('Resistance:')),
              Expanded(
                child: TextFormField(
                  initialValue: interval.resistanceLevel?.toString() ?? '',
                  decoration: const InputDecoration(
                    hintText: 'Resistance level',
                    suffixText: 'level',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    final intValue = int.tryParse(value);
                    onUpdate(UnitTrainingInterval(
                      title: interval.title,
                      duration: interval.duration,
                      targets: interval.targets,
                      resistanceLevel: intValue,
                      repeat: interval.repeat,
                    ));
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTargetField({
    required UnitTrainingInterval interval,
    required LiveDataFieldConfig field,
    required Function(UnitTrainingInterval) onUpdate,
  }) {
    final currentValue = interval.targets?[field.name];

    // Fields with userSetting always use percentage input
    final bool canShowPercentage = field.userSetting != null;
    
    String initialPercentage = '';
    if (canShowPercentage && currentValue != null) {
      // For percentage-capable fields, extract percentage from current value
      if (currentValue is String && currentValue.endsWith('%')) {
        final percentageString = currentValue.replaceAll('%', '');
        final percentage = double.tryParse(percentageString);
        if (percentage != null) {
          initialPercentage = percentage.round().toString();
        }
      } else {
        // Try to convert absolute value back to percentage
        final percentage = _calculatePercentageFromValue(currentValue);
        if (percentage > 0) {
          initialPercentage = percentage.round().toString();
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text('${field.label}:'),
          ),
          Expanded(
            child: canShowPercentage ?
              // Percentage input for fields that support percentage calculation
              TextFormField(
                initialValue: initialPercentage,
                decoration: InputDecoration(
                  hintText: 'Target %',
                  suffixText: '% FTP',
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  final percentage = double.tryParse(value);
                  final newTargets = Map<String, dynamic>.from(interval.targets ?? {});
                  if (percentage != null) {
                    // Store percentage string (e.g., "85%") for serialization
                    newTargets[field.name] = '${percentage.round()}%';
                  } else {
                    newTargets.remove(field.name);
                  }

                  onUpdate(UnitTrainingInterval(
                    title: interval.title,
                    duration: interval.duration,
                    targets: newTargets,
                    resistanceLevel: interval.resistanceLevel,
                    repeat: interval.repeat,
                  ));
                },
              ) :
              // Absolute value input for fields that don't support percentage calculation
              TextFormField(
                initialValue: currentValue?.toString() ?? '',
                decoration: InputDecoration(
                  hintText: 'Target ${field.label.toLowerCase()}',
                  suffixText: field.unit,
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  final numValue = double.tryParse(value);
                  final newTargets = Map<String, dynamic>.from(interval.targets ?? {});
                  if (numValue != null) {
                    newTargets[field.name] = numValue;
                  } else {
                    newTargets.remove(field.name);
                  }

                  onUpdate(UnitTrainingInterval(
                    title: interval.title,
                    duration: interval.duration,
                    targets: newTargets,
                    resistanceLevel: interval.resistanceLevel,
                    repeat: interval.repeat,
                  ));
                },
              ),
          ),
          // Show calculated absolute value for percentage inputs
          if (canShowPercentage && currentValue != null)
            SizedBox(
              width: 120,
              child: Text(
                _formatAbsoluteValueFromPercentage(field, currentValue),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGroupIntervalEditor(GroupTrainingInterval interval) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Repeat count
          Row(
            children: [
              const Text('Repeat: '),
              Expanded(
                child: Slider(
                  value: (interval.repeat ?? 1).toDouble(),
                  min: 1,
                  max: 20,
                  divisions: 19,
                  label: '${interval.repeat ?? 1}x',
                  onChanged: (value) {
                    setState(() {
                      final index = _intervals.indexOf(interval);
                      if (index >= 0) {
                        _intervals[index] = GroupTrainingInterval(
                          intervals: interval.intervals,
                          repeat: value.round(),
                        );
                      }
                    });
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Sub-intervals header with add button
          Row(
            children: [
              const Text('Sub-intervals:', style: TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add, size: 20),
                onPressed: () => _addSubInterval(interval),
                tooltip: 'Add Sub-interval',
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Sub-intervals
          // Sub-intervals - always in edit mode
          ...interval.intervals.asMap().entries.map((entry) {
            final subIndex = entry.key;
            final subInterval = entry.value;

            return Card(
              color: Colors.blue[50],
              child: Column(
                children: [
                  // Header with title and delete button
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            subInterval.title ?? 'Sub-interval ${subIndex + 1}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 16),
                          onPressed: () => _removeSubInterval(interval, subIndex),
                          tooltip: 'Remove Sub-interval',
                        ),
                      ],
                    ),
                  ),
                  // Use the unified editor - always in edit mode
                  _buildUnitIntervalEditor(
                    interval: subInterval,
                    isEditing: true,
                    onUpdate: (updatedInterval) => _updateSubInterval(interval, subIndex, updatedInterval),
                    labelPrefix: 'Sub-interval',
                  ),
                ],
              ),
            );
          }),

          // Show message if no sub-intervals
          if (interval.intervals.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'No sub-intervals. Add one using the + button above.',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  void _addSubInterval(GroupTrainingInterval groupInterval) {
    setState(() {
      final index = _intervals.indexOf(groupInterval);
      if (index >= 0) {
        final newSubInterval = UnitTrainingInterval(
          title: 'Interval ${groupInterval.intervals.length + 1}',
          duration: 120, // 2 minutes default
          targets: {},
          resistanceLevel: null,
        );

        final updatedIntervals = List<UnitTrainingInterval>.from(groupInterval.intervals)
          ..add(newSubInterval);

        _intervals[index] = GroupTrainingInterval(
          intervals: updatedIntervals,
          repeat: groupInterval.repeat,
        );
      }
    });
  }

  void _removeSubInterval(GroupTrainingInterval groupInterval, int subIndex) {
    setState(() {
      final index = _intervals.indexOf(groupInterval);
      if (index >= 0 && subIndex >= 0 && subIndex < groupInterval.intervals.length) {
        final updatedIntervals = List<UnitTrainingInterval>.from(groupInterval.intervals)
          ..removeAt(subIndex);

        _intervals[index] = GroupTrainingInterval(
          intervals: updatedIntervals,
          repeat: groupInterval.repeat,
        );
      }
    });
  }

  Future<void> _saveSession() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a session title')),
      );
      return;
    }

    if (_intervals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one interval')),
      );
      return;
    }

    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 16),
            Text(_isEditMode ? 'Updating session...' : 'Saving session...'),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      final storageService = TrainingSessionStorageService();
      
      // If in edit mode, delete the original session first
      if (_isEditMode) {
        final originalSession = widget.existingSession!;
        await storageService.deleteSession(
          originalSession.title, 
          originalSession.ftmsMachineType.name,
        );
      }

      // Create the new training session
      final session = TrainingSessionDefinition(
        title: _titleController.text.trim(),
        ftmsMachineType: widget.machineType,
        intervals: List<TrainingInterval>.from(_intervals),
        isCustom: true,
      );

      // Save the session
      await storageService.saveSession(session);

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Session "${_titleController.text}" ${_isEditMode ? 'updated' : 'saved'} successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save session: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _updateSubInterval(GroupTrainingInterval groupInterval, int subIndex, UnitTrainingInterval newSubInterval) {
    setState(() {
      final groupIndex = _intervals.indexOf(groupInterval);
      if (groupIndex >= 0 && subIndex >= 0 && subIndex < groupInterval.intervals.length) {
        final updatedIntervals = List<UnitTrainingInterval>.from(groupInterval.intervals);
        updatedIntervals[subIndex] = newSubInterval;

        _intervals[groupIndex] = GroupTrainingInterval(
          intervals: updatedIntervals,
          repeat: groupInterval.repeat,
        );
      }
    });
  }

  void _updateUnitInterval(int index, UnitTrainingInterval updatedInterval) {
    setState(() {
      if (index >= 0 && index < _intervals.length) {
        _intervals[index] = updatedInterval;
      }
    });
  }

  String _formatAbsoluteValueFromPercentage(LiveDataFieldConfig field, dynamic value) {
    if (value == null) return '';
    
    // Extract percentage from string (e.g., "85%" -> 85)
    double percentage = 0;
    if (value is String && value.endsWith('%')) {
      final percentageString = value.replaceAll('%', '');
      percentage = double.tryParse(percentageString) ?? 0;
    } else if (value is num) {
      // If it's already a number, treat it as a percentage
      percentage = value.toDouble();
    }
    
    if (percentage <= 0) return '';
    
    // Calculate absolute value using the strategy
    final absoluteValue = _calculateValueFromPercentage(percentage);
    
    // Apply formatter if available
    if (field.formatter != null) {
      final strategy = LiveDataFieldFormatter.getStrategy(field.formatter!);
      if (strategy != null) {
        final formattedValue = strategy.format(field: field, paramValue: absoluteValue);
        return '≈ $formattedValue';
      }
    }
    
    // Default formatting with unit
    return '≈ ${absoluteValue.round()} ${field.unit}';
  }
}
