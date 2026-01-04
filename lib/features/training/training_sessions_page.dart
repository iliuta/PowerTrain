import 'package:flutter/material.dart';
import 'package:flutter_ftms/flutter_ftms.dart';
import 'package:ftms/core/models/device_types.dart';
import 'package:ftms/core/services/analytics/analytics_service.dart';
import 'package:ftms/features/training/services/training_session_storage_service.dart';
import 'package:ftms/core/config/live_data_display_config.dart';
import 'package:ftms/features/settings/model/user_settings.dart';
import 'package:ftms/l10n/app_localizations.dart';
import 'training_session_expansion_panel.dart';
import 'training_session_progress_screen.dart';
import 'add_training_session_page.dart';
import 'model/training_session.dart';

/// A dedicated page for browsing and selecting training sessions
class TrainingSessionsPage extends StatefulWidget {
  final BluetoothDevice? connectedDevice;

  const TrainingSessionsPage({
    super.key,
    this.connectedDevice,
  });

  @override
  State<TrainingSessionsPage> createState() => _TrainingSessionsPageState();
}

class _TrainingSessionsPageState extends State<TrainingSessionsPage> {
  List<TrainingSessionDefinition>? _sessions;
  bool _isLoading = true;
  String? _error;
  DeviceType _selectedMachineType = DeviceType.rower;
  UserSettings? _userSettings;
  Map<DeviceType, LiveDataDisplayConfig?>? _configs;
  List<DeviceType> _availableDeviceTypes = [DeviceType.rower, DeviceType.indoorBike];

  @override
  void initState() {
    super.initState();
    AnalyticsService().logScreenView(
      screenName: 'training_sessions',
      screenClass: 'TrainingSessionsPage',
    );
    _loadUserSettings();
  }

  Future<void> _loadUserSettings() async {
    try {
      final userSettings = await UserSettings.loadDefault();
      final configs = <DeviceType, LiveDataDisplayConfig?>{};
      for (final deviceType in [DeviceType.rower, DeviceType.indoorBike]) {
        configs[deviceType] = await LiveDataDisplayConfig.loadForFtmsMachineType(deviceType);
      }
      setState(() {
        _userSettings = userSettings;
        _configs = configs;
      });
      await _filterAvailableDeviceTypes();
      _loadSessions();
    } catch (e) {
      setState(() {
        _error = 'Failed to load user settings: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _filterAvailableDeviceTypes() async {
    List<DeviceType> filteredTypes = [];
    
    for (DeviceType deviceType in [DeviceType.rower, DeviceType.indoorBike]) {
      try {
        final config = await LiveDataDisplayConfig.loadForFtmsMachineType(deviceType);
        if (config != null) {
          // If developer mode is enabled, show all devices
          // If developer mode is disabled, only show devices that are NOT developer-only
          if (_userSettings?.developerMode == true || !config.availableInDeveloperModeOnly) {
            filteredTypes.add(deviceType);
          }
        }
      } catch (e) {
        // If we can't load config, assume it's available for non-developer mode
        filteredTypes.add(deviceType);
      }
    }
    
    setState(() {
      _availableDeviceTypes = filteredTypes;
      // If the currently selected machine type is not available, switch to the first available one
      if (!_availableDeviceTypes.contains(_selectedMachineType) && _availableDeviceTypes.isNotEmpty) {
        _selectedMachineType = _availableDeviceTypes.first;
      }
    });
  }

  Future<void> _loadSessions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final storageService = TrainingSessionStorageService();
      final sessions = await storageService.loadTrainingSessions(_selectedMachineType);
      setState(() {
        _sessions = sessions;
        _isLoading = false;
      });
      
      // Log analytics event for viewing training sessions
      AnalyticsService().logTrainingSessionsViewed(
        machineType: _selectedMachineType,
        sessionCount: sessions.length,
      );
    } catch (e) {
      setState(() {
        _error = 'Failed to load training sessions: $e';
        _isLoading = false;
      });
    }
  }

  void _onMachineTypeChanged(DeviceType? newType) {
    if (newType != null && newType != _selectedMachineType && _availableDeviceTypes.contains(newType)) {
      setState(() {
        _selectedMachineType = newType;
      });
      _loadSessions();
    }
  }

  void _onSessionSelected(TrainingSessionDefinition session) {
    if (widget.connectedDevice == null) {
      // Show helpful dialog about connecting a device
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(AppLocalizations.of(context)!.noDeviceConnected),
          content: Text(AppLocalizations.of(context)!.noDeviceConnectedMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(AppLocalizations.of(context)!.ok),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Navigate back to main page for device scanning
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: Text(AppLocalizations.of(context)!.scanForDevices),
            ),
          ],
        ),
      );
      return;
    }

    // Navigate to training session progress screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TrainingSessionProgressScreen(
          session: session,
          ftmsDevice: widget.connectedDevice!,
          gpxAssetPath: null,
        ),
      ),
    );
  }

  void _onSessionEdit(TrainingSessionDefinition session) {
    // Use the original non-expanded session for editing if available
    final sessionToEdit = session.originalSession ?? session;
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddTrainingSessionPage(
          machineType: _selectedMachineType,
          existingSession: sessionToEdit,
        ),
      ),
    ).then((_) {
      // Reload sessions after editing
      _loadSessions();
    });
  }

  Future<void> _onSessionDelete(TrainingSessionDefinition session) async {
    // Only custom sessions can be deleted
    if (!session.isCustom) {
      return;
    }

    if (!mounted) return;

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final storageService = TrainingSessionStorageService();
      final sessionToDelete = session.originalSession ?? session;
      final success = await storageService.deleteSession(
        sessionToDelete.title,
        sessionToDelete.ftmsMachineType.name,
      );

      if (!mounted) return;

      // Close loading dialog
      Navigator.of(context).pop();

      if (success) {
        // Log analytics event
        AnalyticsService().logTrainingSessionDeleted(
          machineType: session.ftmsMachineType,
        );
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.trainingSessionDeleted(session.title)),
            backgroundColor: Colors.green,
          ),
        );
        // Reload sessions to reflect the deletion
        _loadSessions();
      } else {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.failedToDeleteTrainingSession),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      
      // Close loading dialog if it's still open
      Navigator.of(context).pop();
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.errorDeletingTrainingSession(e)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _onSessionDuplicate(TrainingSessionDefinition session) {
    // Reload sessions after duplication (this will be called from the expansion panel)
    _loadSessions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.trainingSessions),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Text(AppLocalizations.of(context)!.machineType, style: const TextStyle(fontWeight: FontWeight.bold)),
                Expanded(
                  child: DropdownButton<DeviceType>(
                    value: _selectedMachineType,
                    isExpanded: true,
                    items: _availableDeviceTypes.map((DeviceType deviceType) {
                      return DropdownMenuItem<DeviceType>(
                        value: deviceType,
                        child: Text(deviceType == DeviceType.indoorBike ? AppLocalizations.of(context)!.indoorBike : AppLocalizations.of(context)!.rowingMachine),
                      );
                    }).toList(),
                    onChanged: _onMachineTypeChanged,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AddTrainingSessionPage(
                machineType: _selectedMachineType,
              ),
            ),
          ).then((_) {
            // Reload sessions after adding a new one
            _loadSessions();
          });
        },
        tooltip: 'Add Training Session',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadSessions,
                child: Text(AppLocalizations.of(context)!.retry),
              ),
            ],
          ),
        ),
      );
    }

    if (_sessions == null || _sessions!.isEmpty) {
      return SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.fitness_center,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No training sessions found',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'No training sessions available for $_selectedMachineType',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try selecting a different machine type above',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      child: TrainingSessionExpansionPanelList(
        sessions: _sessions!,
        scrollController: ScrollController(),
        userSettings: _userSettings,
        configs: _configs,
        onSessionSelected: _onSessionSelected,
        onSessionEdit: _onSessionEdit,
        onSessionDelete: _onSessionDelete,
        onSessionDuplicate: _onSessionDuplicate,
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
