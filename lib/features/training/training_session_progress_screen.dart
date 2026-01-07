import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_ftms/flutter_ftms.dart';
import 'package:ftms/l10n/app_localizations.dart';
import '../../core/config/live_data_display_config.dart';
import '../../core/services/analytics/analytics_service.dart';
import '../../core/services/gpx/gpx_file_provider.dart';
import '../settings/model/user_settings.dart';
import '../../core/services/user_settings_service.dart';
import 'model/training_session.dart';
import 'model/expanded_training_session_definition.dart';
import 'training_session_controller.dart';
import 'widgets/training_session_scaffold.dart';

/// Main screen for displaying training session progress
class TrainingSessionProgressScreen extends StatefulWidget {
  final TrainingSessionDefinition session;
  final BluetoothDevice ftmsDevice;
  final String? gpxAssetPath;

  const TrainingSessionProgressScreen({
    super.key,
    required this.session,
    required this.ftmsDevice,
    this.gpxAssetPath,
  });

  @override
  State<TrainingSessionProgressScreen> createState() => _TrainingSessionProgressScreenState();
}

class _TrainingSessionProgressScreenState extends State<TrainingSessionProgressScreen> {
  UserSettings? _userSettings;
  String? _gpxFilePath;

  @override
  void initState() {
    super.initState();
    // Force landscape orientation for this screen
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    AnalyticsService().logScreenView(
      screenName: 'training_session_progress',
      screenClass: 'TrainingSessionProgressScreen',
    );
    _loadUserSettings();
    _loadGpxFile();
  }

  Future<void> _loadUserSettings() async {
    final settings = await UserSettingsService.instance.loadSettings();
    setState(() {
      _userSettings = settings;
    });
  }

  Future<void> _loadGpxFile() async {
    final gpxFile = widget.gpxAssetPath ?? await GpxFileProvider.getRandomGpxFile(widget.session.ftmsMachineType);
    setState(() {
      _gpxFilePath = gpxFile;
    });
  }

  @override
  void dispose() {
    // Allow all orientations when leaving this screen
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_userSettings == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return FutureBuilder<LiveDataDisplayConfig?>(
      future: _loadConfig(),
      builder: (context, snapshot) {
        return FutureBuilder<ExpandedTrainingSessionDefinition>(
          future: _expandSession(),
          builder: (context, sessionSnapshot) {
            if (sessionSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            
            final expandedSession = sessionSnapshot.data;
            if (expandedSession == null) {
              return Scaffold(
                body: Center(child: Text(AppLocalizations.of(context)!.failedToLoadSession)),
              );
            }
            
            return ChangeNotifierProvider(
              create: (_) => TrainingSessionController(
                session: expandedSession,
                ftmsDevice: widget.ftmsDevice,
                gpxFilePath: _gpxFilePath,
              ),
              child: Consumer<TrainingSessionController>(
                builder: (context, controller, _) {
                  return TrainingSessionScaffold(
                    session: expandedSession,
                    controller: controller,
                    config: snapshot.data,
                    ftmsDevice: widget.ftmsDevice,
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Future<ExpandedTrainingSessionDefinition> _expandSession() async {
    try {
      final config = await LiveDataDisplayConfig.loadForFtmsMachineType(widget.session.ftmsMachineType);
      return widget.session.expand(
        userSettings: _userSettings!,
        config: config,
      );
    } catch (e) {
      // If expansion fails, create a minimal expanded session from the original
      debugPrint('Failed to expand session: $e');
      return widget.session.expand(
        userSettings: _userSettings!,
        config: null,
      );
    }
  }

  Future<LiveDataDisplayConfig?> _loadConfig() {
    return LiveDataDisplayConfig.loadForFtmsMachineType(widget.session.ftmsMachineType);
  }
}
