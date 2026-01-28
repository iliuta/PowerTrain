// This file contains the refactored session selector tab for FTMS devices
// Business logic has been moved to SessionSelectorService
// UI has been split into reusable widgets
import 'package:flutter/material.dart';
import 'package:flutter_ftms/flutter_ftms.dart';
import '../../core/models/device_types.dart';
import '../../core/services/gpx/gpx_data.dart';
import '../training/model/training_session.dart';
import '../training/training_session_expansion_panel.dart';
import '../training/training_session_progress_screen.dart';
import 'ftms_machine_features_tab.dart';
import 'ftms_device_data_features_tab.dart';
import 'models/session_selector_state.dart';
import 'services/session_selector_service.dart';
import 'widgets/widgets.dart';
import '../../l10n/app_localizations.dart';

class FTMSessionSelectorTab extends StatefulWidget {
  final Future<void> Function(MachineControlPointOpcodeType) writeCommand;
  final SessionSelectorService? service; // For testing injection

  const FTMSessionSelectorTab({
    super.key,
    required this.writeCommand,
    this.service,
  });

  @override
  State<FTMSessionSelectorTab> createState() => _FTMSessionSelectorTabState();
}

class _FTMSessionSelectorTabState extends State<FTMSessionSelectorTab> {
  late SessionSelectorService _service;
  SessionSelectorState _state = const SessionSelectorState();
  TextEditingController? _resistanceController;
  TextEditingController? _trainingSessionGeneratorResistanceController;

  @override
  void initState() {
    super.initState();
    _resistanceController = TextEditingController();
    _trainingSessionGeneratorResistanceController = TextEditingController();
    
    _service = widget.service ?? SessionSelectorService();
    _service.addListener(_onStateChanged);
    _service.initialize();
  }

  @override
  void dispose() {
    _resistanceController?.dispose();
    _trainingSessionGeneratorResistanceController?.dispose();
    _service.removeListener(_onStateChanged);
    if (widget.service == null) {
      _service.dispose();
    }
    super.dispose();
  }

  void _onStateChanged(SessionSelectorState newState) {
    setState(() {
      _state = newState;
      _syncResistanceControllers();
    });
  }

  void _syncResistanceControllers() {
    final freeRideLevel = _state.freeRideConfig.userResistanceLevel;
    if (_resistanceController != null && _resistanceController!.text != (freeRideLevel?.toString() ?? '')) {
      _resistanceController!.text = freeRideLevel?.toString() ?? '';
    }
    
    final generatorLevel = _state.trainingGeneratorConfig.userResistanceLevel;
    if (_trainingSessionGeneratorResistanceController != null && 
        _trainingSessionGeneratorResistanceController!.text != (generatorLevel?.toString() ?? '')) {
      _trainingSessionGeneratorResistanceController!.text = generatorLevel?.toString() ?? '';
    }
  }

  GpxData? get _selectedGpxData {
    if (_state.selectedGpxAssetPath == null || _state.gpxFiles == null) return null;
    try {
      return _state.gpxFiles!.firstWhere((data) => data.assetPath == _state.selectedGpxAssetPath);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_state.hasError && _state.errorMessage != null) {
      return Center(child: Text(_state.errorMessage!));
    }

    if (_state.deviceType == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_state.isDeviceAvailable) {
      return _buildDeveloperModeRequired(context);
    }

    return _buildContent(context);
  }

  Widget _buildDeveloperModeRequired(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.developer_mode,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Developer Mode Required',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'This device requires developer mode to be enabled. Please enable developer mode in the settings to view device data and features.',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: Text(AppLocalizations.of(context)!.goBack),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final deviceType = _state.deviceType!;
    final userSettings = _state.userSettings;
    final displayConfig = _state.configs[deviceType];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // GPX Route Selection Row
          if (_state.gpxFiles != null && _state.gpxFiles!.isNotEmpty)
            _buildGpxRouteSelector(),
          if (_state.gpxFiles != null && _state.gpxFiles!.isNotEmpty)
            const SizedBox(height: 16),
          
          // Free Ride Section
          _buildExpandableCard(
            title: AppLocalizations.of(context)!.freeRide,
            isExpanded: _state.expansionState.isFreeRideExpanded,
            onTap: _service.toggleFreeRideExpanded,
            child: userSettings != null && displayConfig != null
                ? FreeRideConfigPanel(
                    config: _state.freeRideConfig,
                    deviceType: deviceType,
                    userSettings: userSettings,
                    displayConfig: displayConfig,
                    resistanceCapabilities: _state.resistanceCapabilities,
                    resistanceController: _resistanceController,
                    selectedGpxDistance: _selectedGpxData?.totalDistance,
                    onDurationChanged: (minutes) => _service.updateFreeRideDuration(minutes),
                    onDistanceChanged: (meters) => _service.updateFreeRideDistance(meters),
                    onModeChanged: (isDistanceBased) => _service.updateFreeRideDistanceBased(
                      isDistanceBased,
                      selectedGpxData: _selectedGpxData,
                    ),
                    onTargetChanged: (name, value) => _service.updateFreeRideTarget(name, value),
                    onResistanceChanged: (userLevel) => _service.updateFreeRideResistance(userLevel: userLevel),
                    onWarmupChanged: (hasWarmup) => _service.updateFreeRideWarmup(hasWarmup),
                    onCooldownChanged: (hasCooldown) => _service.updateFreeRideCooldown(hasCooldown),
                    onStart: _startFreeRide,
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),
          
          // Training Session Generator Section (only for rowing machines)
          if (deviceType == DeviceType.rower) ...[
            _buildExpandableCard(
              title: AppLocalizations.of(context)!.trainingSessionGenerator,
              isExpanded: _state.expansionState.isTrainingSessionGeneratorExpanded,
              onTap: _service.toggleTrainingSessionGeneratorExpanded,
              child: TrainingGeneratorConfigPanel(
                config: _state.trainingGeneratorConfig,
                resistanceCapabilities: _state.resistanceCapabilities,
                resistanceController: _trainingSessionGeneratorResistanceController,
                onDurationChanged: (minutes) => _service.updateTrainingGeneratorDuration(minutes),
                onWorkoutTypeChanged: (workoutType) => _service.updateTrainingGeneratorWorkoutType(workoutType),
                onResistanceChanged: (userLevel) => _service.updateTrainingGeneratorResistance(userLevel: userLevel),
                onStart: _startGeneratedSession,
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // Load Training Session Section
          _buildExpandableCard(
            title: AppLocalizations.of(context)!.loadTrainingSession,
            isExpanded: _state.expansionState.isTrainingSessionExpanded,
            onTap: _service.toggleTrainingSessionExpanded,
            child: _buildTrainingSessionsContent(),
          ),
          const SizedBox(height: 16),
          
          // Device Data Features Section (only show if developer mode is enabled)
          if (_state.userSettings?.developerMode == true) ...[
            _buildExpandableCard(
              title: AppLocalizations.of(context)!.deviceDataFeatures,
              isExpanded: _state.expansionState.isDeviceDataFeaturesExpanded,
              onTap: _service.toggleDeviceDataFeaturesExpanded,
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.5,
                child: const FTMSDeviceDataFeaturesTab(),
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // Machine Features Section (only show if developer mode is enabled)
          if (_state.userSettings?.developerMode == true)
            _buildExpandableCard(
              title: AppLocalizations.of(context)!.machineFeatures,
              isExpanded: _state.expansionState.isMachineFeaturesExpanded,
              onTap: _service.toggleMachineFeaturesExpanded,
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
                child: FTMSMachineFeaturesTab(
                  writeCommand: widget.writeCommand,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGpxRouteSelector() {
    return SizedBox(
      height: 85,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _state.gpxFiles!.map((data) => GpxMapPreviewWidget(
            info: data,
            isSelected: _state.selectedGpxAssetPath == data.assetPath,
            onTap: () => _service.selectGpxRoute(data.assetPath, gpxData: data),
          )).toList(),
        ),
      ),
    );
  }

  Widget _buildExpandableCard({
    required String title,
    required bool isExpanded,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return Card(
      child: Column(
        children: [
          ListTile(
            title: Text(title),
            trailing: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
            onTap: onTap,
          ),
          if (isExpanded) child,
        ],
      ),
    );
  }

  Widget _buildTrainingSessionsContent() {
    if (_state.isLoadingTrainingSessions) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_state.trainingSessions == null) {
      return Center(child: Text(AppLocalizations.of(context)!.failedLoadTrainingSessions));
    }

    if (_state.trainingSessions!.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context)!.noTrainingSessionsFound));
    }

    return TrainingSessionExpansionPanelList(
      sessions: _state.trainingSessions!,
      scrollController: ScrollController(),
      userSettings: _state.userSettings,
      configs: _state.configs,
      onSessionSelected: _onTrainingSessionSelected,
    );
  }

  void _startFreeRide() async {
    final session = _service.createFreeRideSession();
    await _service.logFreeRideStarted();
    
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => TrainingSessionProgressScreen(
            session: session,
            gpxAssetPath: _state.selectedGpxAssetPath,
          ),
        ),
      );
    }
  }

  void _startGeneratedSession() async {
    final session = _service.createGeneratedSession(AppLocalizations.of(context)!);
    await _service.logTrainingSessionGenerated();
    
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => TrainingSessionProgressScreen(
            session: session,
            gpxAssetPath: _state.selectedGpxAssetPath,
          ),
        ),
      );
    }
  }

  void _onTrainingSessionSelected(TrainingSessionDefinition session) async {
    await _service.logTrainingSessionSelected(session);
    
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => TrainingSessionProgressScreen(
            session: session,
            gpxAssetPath: _state.selectedGpxAssetPath,
          ),
        ),
      );
    }
  }
}
