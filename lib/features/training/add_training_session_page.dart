import 'dart:collection';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ftms/core/models/device_types.dart';
import 'package:ftms/core/config/live_data_display_config.dart';
import 'package:ftms/core/services/analytics/analytics_service.dart';
import 'package:ftms/features/training/model/expanded_unit_training_interval.dart';
import 'package:ftms/l10n/app_localizations.dart';
import 'package:ftms/core/models/supported_resistance_level_range.dart';
import '../../features/training/services/training_session_storage_service.dart';
import 'widgets/training_session_chart.dart';
import 'widgets/edit_target_fields_widget.dart';
import 'model/unit_training_interval.dart';
import 'model/group_training_interval.dart';
import 'model/training_interval.dart';
import 'model/training_session.dart';
import '../../features/settings/model/user_settings.dart';
import '../../core/services/user_settings_service.dart';

/// A page for creating new training sessions or editing existing ones
class AddTrainingSessionPage extends StatefulWidget {
  final DeviceType machineType;
  final TrainingSessionDefinition? existingSession;
  
  // Optional parameters for testing - allow dependency injection
  final LiveDataDisplayConfig? config;
  final UserSettings? userSettings;
  final TrainingSessionStorageService? storageService;

  const AddTrainingSessionPage({
    super.key,
    required this.machineType,
    this.existingSession,
    this.config,
    this.userSettings,
    this.storageService,
  });

  @override
  State<AddTrainingSessionPage> createState() => _AddTrainingSessionPageState();
}

class _AddTrainingSessionPageState extends State<AddTrainingSessionPage> {
  final TextEditingController _titleController = TextEditingController();
  final LinkedHashMap<String, TrainingInterval> _intervals = LinkedHashMap<String, TrainingInterval>();
  LiveDataDisplayConfig? _config;
  UserSettings? _userSettings;
  bool _isLoading = true;
  bool _isDistanceBased = false;

  // Check if we're in edit mode
  bool get _isEditMode => widget.existingSession != null;

  List<TrainingInterval> get _intervalsList => _intervals.values.toList();

  @override
  void initState() {
    super.initState();
    AnalyticsService().logScreenView(
      screenName: _isEditMode ? 'edit_training_session' : 'add_training_session',
      screenClass: 'AddTrainingSessionPage',
    );
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    _loadConfiguration();
  }

  Future<void> _loadConfiguration() async {
    try {
      // Use injected dependencies if provided (for testing), otherwise load from static methods
      final config = widget.config ?? await LiveDataDisplayConfig.loadForFtmsMachineType(widget.machineType);
      final userSettings = widget.userSettings ?? await UserSettingsService.instance.loadSettings();

      setState(() {
        _config = config;
        _userSettings = userSettings;
        _isLoading = false;
      });

      // Initialize form with existing session data if in edit mode
      if (_isEditMode) {
        _initializeFromExistingSession();
      } else {
        _initializeWithTemplate();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.failedToLoadConfiguration(e))),
        );
      }
    }
  }

  void _initializeFromExistingSession() {
    _initializeSession(widget.existingSession!);
  }

  void _initializeWithTemplate({bool isDistanceBased = false}) {
    // Create templated session
    final templateSession = TrainingSessionDefinition.createTemplate(
      widget.machineType,
      isDistanceBased: isDistanceBased,
    );
    _initializeSession(templateSession);
  }

  void _initializeSession(TrainingSessionDefinition session) {
    // Set the title
    _titleController.text = session.title;
    
    // Set distance based flag
    _isDistanceBased = session.isDistanceBased;
    
    // Clear and populate intervals with generated keys
    _intervals.clear();
    for (int i = 0; i < session.intervals.length; i++) {
      final key = 'interval_${DateTime.now().millisecondsSinceEpoch}_$i';
      _intervals[key] = session.intervals[i];
    }
    
    setState(() {
      // Trigger rebuild to show the loaded data
    });
  }



  List<ExpandedUnitTrainingInterval> get _expandedIntervals {
    if (_userSettings == null) return [];
    
    final List<ExpandedUnitTrainingInterval> expanded = [];
    for (final interval in _intervalsList) {
      // First expand targets (convert percentages to absolute values), then expand repetitions
      final expandedTargetsIntervals = interval.expand(
        machineType: widget.machineType,
        userSettings: _userSettings,
        config: _config,
        isDistanceBased: _isDistanceBased,
      );
      expanded.addAll(expandedTargetsIntervals);
    }
    return expanded;
  }

  int get _distanceIncrement {
    switch (widget.machineType) {
      case DeviceType.rower:
        return 50; // 50m for rowers
      case DeviceType.indoorBike:
        return 1000; // 1000m (1km) for indoor bikes
    }
  }

  int get _minDistance {
    return _distanceIncrement;
  }

  /// The default resistance range used for offline editing.
  /// User inputs values 1-15, which are stored as machine values 10-150.
  SupportedResistanceLevelRange get _defaultResistanceRange =>
      SupportedResistanceLevelRange.defaultOfflineRange;

  /// Maximum user input value for resistance (1-based, user-friendly)
  int get _maxResistanceUserInput => _defaultResistanceRange.maxUserInput;

  /// Converts user-friendly input (1-15) to machine value (10-150) for storage
  int _convertUserInputToMachine(int userInput) {
    return _defaultResistanceRange.convertUserInputToMachine(userInput);
  }

  /// Converts stored machine value (10-150) to user-friendly display (1-15)
  int? _convertMachineToUserInput(int? machineValue) {
    if (machineValue == null) return null;
    try {
      return _defaultResistanceRange.convertMachineToUserInput(machineValue);
    } catch (e) {
      // If the stored value doesn't match the expected range, return null
      return null;
    }
  }

  String _formatDistance(int distance) {
    switch (widget.machineType) {
      case DeviceType.rower:
        return '$distance m';
      case DeviceType.indoorBike:
        return '${(distance / 1000).toStringAsFixed(1)} km';
    }
  }

  void _addUnitInterval() {
    final key = 'interval_${DateTime.now().millisecondsSinceEpoch}';
    setState(() {
      _intervals[key] = UnitTrainingInterval(
        title: '${AppLocalizations.of(context)!.interval} ${_intervals.length + 1}',
        duration: _isDistanceBased ? null : 300, // 5 minutes default for time-based
        distance: _isDistanceBased ? 2000 : null, // 2km default for distance-based
        targets: {},
        resistanceLevel: null,
        resistanceNeedsConversion: true, // Offline mode - needs conversion
        repeat: 1,
      );
    });
  }

  void _addGroupInterval() {
    final key = 'interval_${DateTime.now().millisecondsSinceEpoch}';
    setState(() {
      _intervals[key] = GroupTrainingInterval(
        intervals: [
          UnitTrainingInterval(
            title: '${AppLocalizations.of(context)!.interval} 1',
            duration: _isDistanceBased ? null : 240, // 4 minutes for time-based
            distance: _isDistanceBased ? 1500 : null, // 1.5km for distance-based
            targets: {},
            resistanceLevel: null,
            resistanceNeedsConversion: true, // Offline mode - needs conversion
          ),
        ],
        repeat: 3,
      );
    });
  }

  void _removeInterval(String key) {
    setState(() {
      _intervals.remove(key);
    });
  }

  void _duplicateInterval(String key) {
    final originalInterval = _intervals[key];
    if (originalInterval != null) {
      final newKey = 'interval_${DateTime.now().millisecondsSinceEpoch}_dup';
      setState(() {
        final duplicatedInterval = originalInterval.copy();
        
        // Find the position of the original interval
        final keys = _intervals.keys.toList();
        final values = _intervals.values.toList();
        final originalIndex = keys.indexOf(key);
        
        // Insert the duplicated interval right after the original
        keys.insert(originalIndex + 1, newKey);
        values.insert(originalIndex + 1, duplicatedInterval);
        
        // Rebuild the LinkedHashMap with the new order
        _intervals.clear();
        for (int i = 0; i < keys.length; i++) {
          _intervals[keys[i]] = values[i];
        }
      });
    }
  }

  void _reorderIntervals(int oldIndex, int newIndex) {
    setState(() {
      final keys = _intervals.keys.toList();
      final values = _intervals.values.toList();
      
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      
      // Reorder the keys and values lists
      final keyToMove = keys.removeAt(oldIndex);
      final valueToMove = values.removeAt(oldIndex);
      
      keys.insert(newIndex, keyToMove);
      values.insert(newIndex, valueToMove);
      
      // Rebuild the LinkedHashMap with the new order
      _intervals.clear();
      for (int i = 0; i < keys.length; i++) {
        _intervals[keys[i]] = values[i];
      }
    });
  }





  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(AppLocalizations.of(context)!.addTrainingSession)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_config == null) {
      return Scaffold(
        appBar: AppBar(title: Text(AppLocalizations.of(context)!.addTrainingSession)),
        body: Center(
          child: Text(AppLocalizations.of(context)!.unableToLoadConfiguration),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? AppLocalizations.of(context)!.editTrainingSession : AppLocalizations.of(context)!.addTrainingSession),
        actions: [
          ElevatedButton(
            onPressed: _intervals.isNotEmpty ? _saveSession : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            child: Text(
              _isEditMode ? AppLocalizations.of(context)!.update : AppLocalizations.of(context)!.save,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
        children: [
          // Session Title
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.sessionTitle,
                hintText: AppLocalizations.of(context)!.enterSessionName,
                border: const OutlineInputBorder(),
              ),
            ),
          ),

          // Session Type Toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _isEditMode 
                          ? '${AppLocalizations.of(context)!.sessionType}${_isDistanceBased ? AppLocalizations.of(context)!.distanceBased : AppLocalizations.of(context)!.timeBased}'
                          : AppLocalizations.of(context)!.distanceBasedSession,
                        style: TextStyle(
                          fontSize: 14, 
                          fontWeight: FontWeight.w500,
                          color: _isEditMode ? Colors.grey : null,
                        ),
                      ),
                    ),
                    Switch(
                      value: _isDistanceBased,
                      onChanged: _isEditMode ? null : (value) {
                        setState(() {
                          _isDistanceBased = value;
                          _initializeWithTemplate(isDistanceBased: value);
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Training Chart
          if (_expandedIntervals.isNotEmpty)
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.trainingPreview,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    TrainingSessionChart(
                      intervals: _expandedIntervals,
                      machineType: widget.machineType,
                      height: 90,
                      config: _config,
                      isDistanceBased: _isDistanceBased,
                    ),
                  ],
                ),
              ),
            ),

          // Intervals List
          Expanded(
            child: _intervals.isEmpty
                ? Center(
                    child: Text(
                      AppLocalizations.of(context)!.noIntervalsAdded,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  )
                : ReorderableListView(
                    padding: const EdgeInsets.all(8.0),
                    onReorder: _reorderIntervals,
                    children: _intervals.entries.map((entry) {
                      final key = entry.key;
                      final interval = entry.value;
                      final index = _intervals.keys.toList().indexOf(key);
                      return _buildIntervalCard(key, interval, index);
                    }).toList(),
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
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'add_group',
            onPressed: _addGroupInterval,
            tooltip: AppLocalizations.of(context)!.addGroupInterval,
            child: const Icon(Icons.repeat),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'add_unit',
            onPressed: _addUnitInterval,
            tooltip: AppLocalizations.of(context)!.addUnitInterval,
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  Widget _buildIntervalCard(String key, TrainingInterval interval, int index) {
    return Card(
      key: Key(key),
      child: ExpansionTile(
        title: Row(
          children: [
            const Icon(Icons.drag_handle, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(
              child: Text(interval is GroupTrainingInterval
                  ? '${AppLocalizations.of(context)!.group} ${index + 1} (${interval.repeat ?? 1}x)'
                  : (interval is UnitTrainingInterval ? (interval.title ?? '${AppLocalizations.of(context)!.interval} ${index + 1}') : '${AppLocalizations.of(context)!.interval} ${index + 1}')),
            ),
          ],
        ),
        subtitle: Text(_getIntervalSubtitle(interval)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.copy),
              onPressed: () => _duplicateInterval(key),
              tooltip: AppLocalizations.of(context)!.duplicate,
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _removeInterval(key),
              tooltip: AppLocalizations.of(context)!.delete,
            ),
          ],
        ),
        children: [
          if (interval is UnitTrainingInterval)
            _buildUnitIntervalEditor(
              key: ValueKey('unit_interval_$key'),
              interval: interval,
              isEditing: true, // Always in edit mode
              onUpdate: (updatedInterval) => _updateUnitInterval(key, updatedInterval),
            )
          else if (interval is GroupTrainingInterval)
            _buildGroupIntervalEditor(key, interval),
        ],
      ),
    );
  }

  String _getIntervalSubtitle(TrainingInterval interval) {
    if (interval is UnitTrainingInterval) {
      if (_isDistanceBased) {
        final dist = interval.distance ?? 0;
        return _formatDistance(dist);
      } else {
        final dur = interval.duration ?? 0;
        final duration = Duration(seconds: dur);
        return '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
      }
    } else if (interval is GroupTrainingInterval) {
      if (_isDistanceBased) {
        final totalDistance = interval.intervals.fold<int>(0, (sum, i) => sum + (i.distance ?? 0));
        final repeatCount = interval.repeat ?? 1;
        return '${interval.intervals.length} intervals, ${(totalDistance * repeatCount / 1000).toStringAsFixed(1)} km total';
      } else {
        final totalDuration = interval.intervals.fold<int>(0, (sum, i) => sum + (i.duration ?? 0));
        final repeatCount = interval.repeat ?? 1;
        final duration = Duration(seconds: totalDuration * repeatCount);
        return '${interval.intervals.length} intervals, ${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')} total';
      }
    }
    return '';
  }

  Widget _buildUnitIntervalEditor({
    required UnitTrainingInterval interval,
    required bool isEditing,
    required Function(UnitTrainingInterval) onUpdate,
    String? labelPrefix,
    Key? key,
  }) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
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
                distance: interval.distance,
                targets: interval.targets,
                resistanceLevel: interval.resistanceLevel,
                resistanceNeedsConversion: interval.resistanceNeedsConversion,
                repeat: interval.repeat,
              ));
            },
          ),
          const SizedBox(height: 8),

          // Duration or Distance
          if (_isDistanceBased) ...[
            Row(
              children: [
                SizedBox(width: 80, child: Text(AppLocalizations.of(context)!.distanceLabel)),
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: (interval.distance ?? 0) > _minDistance
                      ? () {
                          final newDistance = ((interval.distance ?? 0) - _distanceIncrement).clamp(_minDistance, 50000);
                          onUpdate(UnitTrainingInterval(
                            title: interval.title,
                            duration: interval.duration,
                            distance: newDistance.toInt(),
                            targets: interval.targets,
                            resistanceLevel: interval.resistanceLevel,
                            resistanceNeedsConversion: interval.resistanceNeedsConversion,
                            repeat: interval.repeat,
                          ));
                        }
                      : null,
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _formatDistance(interval.distance ?? 0),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: (interval.distance ?? 0) < 50000
                      ? () {
                          final newDistance = ((interval.distance ?? 0) + _distanceIncrement).clamp(_minDistance, 50000);
                          onUpdate(UnitTrainingInterval(
                            title: interval.title,
                            duration: interval.duration,
                            distance: newDistance.toInt(),
                            targets: interval.targets,
                            resistanceLevel: interval.resistanceLevel,
                            resistanceNeedsConversion: interval.resistanceNeedsConversion,
                            repeat: interval.repeat,
                          ));
                        }
                      : null,
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                SizedBox(width: 80, child: Text(AppLocalizations.of(context)!.durationLabel)),
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: (interval.duration ?? 0) > 10
                      ? () {
                          final newDuration = ((interval.duration ?? 0) - 10).clamp(10, 3600);
                          onUpdate(UnitTrainingInterval(
                            title: interval.title,
                            duration: newDuration.toInt(),
                            distance: interval.distance,
                            targets: interval.targets,
                            resistanceLevel: interval.resistanceLevel,
                            resistanceNeedsConversion: interval.resistanceNeedsConversion,
                            repeat: interval.repeat,
                          ));
                        }
                      : null,
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${Duration(seconds: interval.duration ?? 0).inMinutes}:${((interval.duration ?? 0) % 60).toString().padLeft(2, '0')}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: (interval.duration ?? 0) < 3600
                      ? () {
                          final newDuration = ((interval.duration ?? 0) + 10).clamp(10, 3600);
                          onUpdate(UnitTrainingInterval(
                            title: interval.title,
                            duration: newDuration.toInt(),
                            distance: interval.distance,
                            targets: interval.targets,
                            resistanceLevel: interval.resistanceLevel,
                            resistanceNeedsConversion: interval.resistanceNeedsConversion,
                            repeat: interval.repeat,
                          ));
                        }
                      : null,
                ),
              ],
            ),
          ],

          // Targets
          const SizedBox(height: 16),
          Text(AppLocalizations.of(context)!.targets, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          EditTargetFieldsWidget(
            machineType: widget.machineType,
            userSettings: _userSettings!,
            config: _config!,
            targets: interval.targets ?? {},
            onTargetChanged: (name, value) {
              final newTargets = Map<String, dynamic>.from(interval.targets ?? {});
              if (value == null) {
                newTargets.remove(name);
              } else {
                newTargets[name] = value;
              }
              onUpdate(UnitTrainingInterval(
                title: interval.title,
                duration: interval.duration,
                distance: interval.distance,
                targets: newTargets,
                resistanceLevel: interval.resistanceLevel,
                resistanceNeedsConversion: interval.resistanceNeedsConversion,
                repeat: interval.repeat,
              ));
            },
          ),
          // Resistance Level - only for non-indoor-bike machines
          // User enters values 1-15, stored as machine values 10-150
          if (widget.machineType != DeviceType.indoorBike) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(AppLocalizations.of(context)!.resistanceLabel),
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: IconButton(
                        icon: const Icon(Icons.help_outline, size: 16),
                        onPressed: () => _showResistanceHelpDialog(context),
                        tooltip: AppLocalizations.of(context)!.resistanceHelp,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    // Display user-friendly value (1-15) converted from stored machine value (10-150)
                    initialValue: _convertMachineToUserInput(interval.resistanceLevel)?.toString() ?? '',
                    decoration: InputDecoration(
                      hintText: '1-$_maxResistanceUserInput',
                      suffixText: AppLocalizations.of(context)!.level,
                      isDense: true,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      // Convert user input (1-15) to machine value (10-150) for storage
                      final userInput = int.tryParse(value);
                      int? machineValue;
                      if (userInput != null && userInput >= 1 && userInput <= _maxResistanceUserInput) {
                        machineValue = _convertUserInputToMachine(userInput);
                      }
                      onUpdate(UnitTrainingInterval(
                        title: interval.title,
                        duration: interval.duration,
                        distance: interval.distance,
                        targets: interval.targets,
                        resistanceLevel: machineValue,
                        resistanceNeedsConversion: true, // Always true when editing in offline mode
                        repeat: interval.repeat,
                      ));
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }



  Widget _buildGroupIntervalEditor(String key, GroupTrainingInterval interval) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Repeat count
          Row(
            children: [
              SizedBox(width: 80, child: Text(AppLocalizations.of(context)!.repeatLabel)),
              IconButton(
                icon: const Icon(Icons.remove),
                onPressed: (interval.repeat ?? 1) > 1
                    ? () {
                        setState(() {
                          _intervals[key] = GroupTrainingInterval(
                            intervals: interval.intervals,
                            repeat: ((interval.repeat ?? 1) - 1).clamp(1, 20),
                          );
                        });
                      }
                    : null,
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${interval.repeat ?? 1}x',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: (interval.repeat ?? 1) < 20
                    ? () {
                        setState(() {
                          _intervals[key] = GroupTrainingInterval(
                            intervals: interval.intervals,
                            repeat: ((interval.repeat ?? 1) + 1).clamp(1, 20),
                          );
                        });
                      }
                    : null,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Sub-intervals header with add button
          Row(
            children: [
              Text(AppLocalizations.of(context)!.subIntervals, style: const TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add, size: 20),
                onPressed: () => _addSubInterval(key, interval),
                tooltip: AppLocalizations.of(context)!.addSubInterval,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Sub-intervals
          // Sub-intervals - always in edit mode
          ...interval.intervals.asMap().entries.map((entry) {
            final subIndex = entry.key;
            final subInterval = entry.value;
            final subKey = '${key}_sub_$subIndex';

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
                            subInterval.title ?? '${AppLocalizations.of(context)!.subInterval} ${subIndex + 1}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 16),
                          onPressed: () => _removeSubInterval(key, interval, subIndex),
                          tooltip: AppLocalizations.of(context)!.removeSubInterval,
                        ),
                      ],
                    ),
                  ),
                  // Use the unified editor - always in edit mode
                  _buildUnitIntervalEditor(
                    key: ValueKey(subKey),
                    interval: subInterval,
                    isEditing: true,
                    onUpdate: (updatedInterval) => _updateSubInterval(key, interval, subIndex, updatedInterval),
                    labelPrefix: AppLocalizations.of(context)!.subInterval,
                  ),
                ],
              ),
            );
          }),

          // Show message if no sub-intervals
          if (interval.intervals.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                AppLocalizations.of(context)!.noSubIntervals,
                style: const TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  void _addSubInterval(String key, GroupTrainingInterval groupInterval) {
    setState(() {
      final newSubInterval = UnitTrainingInterval(
        title: '${AppLocalizations.of(context)!.interval} ${groupInterval.intervals.length + 1}',
        duration: _isDistanceBased ? null : 120, // 2 minutes default for time-based
        distance: _isDistanceBased ? 1000 : null, // 1km default for distance-based
        targets: {},
        resistanceLevel: null,
        resistanceNeedsConversion: true, // Offline mode - needs conversion
      );

      final updatedIntervals = List<UnitTrainingInterval>.from(groupInterval.intervals)
        ..add(newSubInterval);

      _intervals[key] = GroupTrainingInterval(
        intervals: updatedIntervals,
        repeat: groupInterval.repeat,
      );
    });
  }

  void _removeSubInterval(String key, GroupTrainingInterval groupInterval, int subIndex) {
    setState(() {
      if (subIndex >= 0 && subIndex < groupInterval.intervals.length) {
        final updatedIntervals = List<UnitTrainingInterval>.from(groupInterval.intervals)
          ..removeAt(subIndex);

        _intervals[key] = GroupTrainingInterval(
          intervals: updatedIntervals,
          repeat: groupInterval.repeat,
        );
      }
    });
  }

  Future<void> _saveSession() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.enterSessionTitle)),
      );
      return;
    }

    if (_intervals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.addAtLeastOneInterval)),
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
            Text(_isEditMode ? AppLocalizations.of(context)!.updatingSession : AppLocalizations.of(context)!.savingSession),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      final storageService = widget.storageService ?? TrainingSessionStorageService();
      
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
        intervals: _intervalsList,
        isCustom: true,
        isDistanceBased: _isDistanceBased,
      );

      // Save the session
      await storageService.saveSession(session);

      // Log analytics event
      final analytics = AnalyticsService();
      if (_isEditMode) {
        analytics.logTrainingSessionEdited(
          machineType: widget.machineType,
          isDistanceBased: _isDistanceBased,
          intervalCount: _intervalsList.length,
        );
      } else {
        analytics.logTrainingSessionCreated(
          machineType: widget.machineType,
          isDistanceBased: _isDistanceBased,
          intervalCount: _intervalsList.length,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditMode ? AppLocalizations.of(context)!.sessionUpdated(_titleController.text) : AppLocalizations.of(context)!.sessionSaved(_titleController.text)),
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
            content: Text(AppLocalizations.of(context)!.failedToSaveSession(e.toString())),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _titleController.dispose();
    super.dispose();
  }

  void _updateSubInterval(String key, GroupTrainingInterval groupInterval, int subIndex, UnitTrainingInterval newSubInterval) {
    setState(() {
      if (subIndex >= 0 && subIndex < groupInterval.intervals.length) {
        final updatedIntervals = List<UnitTrainingInterval>.from(groupInterval.intervals);
        updatedIntervals[subIndex] = newSubInterval;

        _intervals[key] = GroupTrainingInterval(
          intervals: updatedIntervals,
          repeat: groupInterval.repeat,
        );
      }
    });
  }

  void _updateUnitInterval(String key, UnitTrainingInterval updatedInterval) {
    setState(() {
      _intervals[key] = updatedInterval;
    });
  }

  void _showResistanceHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.resistanceHelp),
          content: Text(
            AppLocalizations.of(context)!
                .resistanceHelpDescription(_maxResistanceUserInput.toString()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(AppLocalizations.of(context)!.ok),
            ),
          ],
        );
      },
    );
  }
}
