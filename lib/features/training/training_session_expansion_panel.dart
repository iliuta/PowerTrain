import 'package:flutter/material.dart';
import 'package:ftms/core/models/device_types.dart';
import 'package:ftms/features/settings/model/user_settings.dart';
import 'package:ftms/features/training/model/expanded_training_session_definition.dart';
import 'package:ftms/l10n/app_localizations.dart';
import 'model/training_session.dart';
import '../../core/config/live_data_display_config.dart';
import '../../core/services/devices/bt_device.dart';
import '../../core/services/devices/bt_device_manager.dart';
import '../../features/training/services/training_session_storage_service.dart';
import 'widgets/training_session_chart.dart';

class TrainingSessionExpansionPanelList extends StatefulWidget {
  final List<TrainingSessionDefinition> sessions;
  final ScrollController scrollController;
  final UserSettings? userSettings;
  final Map<DeviceType, LiveDataDisplayConfig?>? configs;
  final Function(TrainingSessionDefinition)? onSessionSelected;
  final Function(TrainingSessionDefinition)? onSessionEdit;
  final Function(TrainingSessionDefinition)? onSessionDelete;
  final Function(TrainingSessionDefinition)? onSessionDuplicate;

  const TrainingSessionExpansionPanelList({
    super.key,
    required this.sessions,
    required this.scrollController,
    this.userSettings,
    this.configs,
    this.onSessionSelected,
    this.onSessionEdit,
    this.onSessionDelete,
    this.onSessionDuplicate,
  });

  @override
  State<TrainingSessionExpansionPanelList> createState() =>
      _TrainingSessionExpansionPanelListState();
}

class _TrainingSessionExpansionPanelListState
    extends State<TrainingSessionExpansionPanelList> {
  late List<bool> _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = List<bool>.filled(widget.sessions.length, false);
  }

  @override
  void didUpdateWidget(covariant TrainingSessionExpansionPanelList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessions.length != widget.sessions.length) {
      _expanded = List<bool>.filled(widget.sessions.length, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: widget.scrollController,
      child: ExpansionPanelList(
        expansionCallback: (int index, bool isExpanded) {
          setState(() {
            _expanded[index] = !_expanded[index];
          });
        },
        children: List.generate(widget.sessions.length, (idx) {
          final session = widget.sessions[idx];
          return ExpansionPanel(
            headerBuilder: (context, isExpanded) => ListTile(
              title: Row(
                children: [
                  Expanded(child: Text(session.title)),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: session.isCustom
                          ? Colors.blue.withValues(alpha: 0.1)
                          : Colors.green.withValues(alpha: 0.1),
                      border: Border.all(
                        color: session.isCustom ? Colors.blue : Colors.green,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      session.isCustom ? AppLocalizations.of(context)!.custom : AppLocalizations.of(context)!.builtIn,
                      style: TextStyle(
                        fontSize: 10,
                        color: session.isCustom ? Colors.blue : Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              subtitle: Text(AppLocalizations.of(context)!.intervalsCount(session.intervals.length)),
              trailing: isExpanded
                  ? const Icon(Icons.expand_less)
                  : const Icon(Icons.expand_more),
            ),
            body: Builder(
              builder: (context) {
                // If we have provided values, use them synchronously
                if (widget.userSettings != null && widget.configs != null) {
                  final config = widget.configs![session.ftmsMachineType];
                  final expandedSession = session.expand(
                    userSettings: widget.userSettings!,
                    config: config,
                  );

                  return _buildExpandedContent(
                      context, session, expandedSession, config);
                }

                // Otherwise, load them asynchronously (backward compatibility)
                return FutureBuilder<LiveDataDisplayConfig?>(
                  future: _getConfig(session.ftmsMachineType),
                  builder: (context, snapshot) {
                    final config = snapshot.data;
                    return FutureBuilder<ExpandedTrainingSessionDefinition>(
                      future: _getExpandedSession(session, config),
                      builder: (context, expandedSnapshot) {
                        final expandedSession = expandedSnapshot.data;
                        if (expandedSession == null) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        return _buildExpandedContent(
                            context, session, expandedSession, config);
                      },
                    );
                  },
                );
              },
            ),
            isExpanded: _expanded[idx],
            canTapOnHeader: true,
          );
        }),
      ),
    );
  }

  Widget _buildExpandedContent(
      BuildContext context,
      TrainingSessionDefinition session,
      ExpandedTrainingSessionDefinition expandedSession,
      LiveDataDisplayConfig? config) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Add the visual chart
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.trainingIntensity,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  TrainingSessionChart(
                    intervals: expandedSession.intervals,
                    machineType: session.ftmsMachineType,
                    height: 120,
                    config: config,
                    isDistanceBased: expandedSession.isDistanceBased,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Add duplicate button for all sessions
              IconButton(
                icon: const Icon(Icons.content_copy, size: 16),
                tooltip: AppLocalizations.of(context)!.duplicate,
                onPressed: () {
                  _showDuplicateConfirmationDialog(context, session);
                },
              ),
              const SizedBox(width: 8),
              // Add edit and delete buttons for custom sessions
              if (session.isCustom) ...[
                IconButton(
                  icon: const Icon(Icons.edit, size: 16),
                  tooltip: AppLocalizations.of(context)!.edit,
                  onPressed: () {
                    if (widget.onSessionEdit != null) {
                      widget.onSessionEdit!(session);
                    }
                  },
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                  tooltip: AppLocalizations.of(context)!.delete,
                  onPressed: () {
                    _showDeleteConfirmationDialog(context, session);
                  },
                ),
                const SizedBox(width: 8),
              ],
              _buildStartSessionButton(context, session),
            ],
          ),
        ],
      ),
    );
  }

  Future<LiveDataDisplayConfig?> _getConfig(DeviceType deviceType) async {
    try {
      return await LiveDataDisplayConfig.loadForFtmsMachineType(deviceType);
    } catch (e) {
      // In test environments, config loading may fail
      // Return null to allow the widget to work without config
      return null;
    }
  }

  Future<ExpandedTrainingSessionDefinition> _getExpandedSession(
      TrainingSessionDefinition session, LiveDataDisplayConfig? config) async {
    final userSettings = await UserSettings.loadDefault();
    return session.expand(userSettings: userSettings, config: config);
  }

  void _showDeleteConfirmationDialog(
      BuildContext context, TrainingSessionDefinition session) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteTrainingSession),
        content: Text(AppLocalizations.of(context)!.deleteConfirmation(session.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              if (widget.onSessionDelete != null) {
                widget.onSessionDelete!(session);
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppLocalizations.of(context)!.delete),
          ),
        ],
      ),
    );
  }

  void _showDuplicateConfirmationDialog(
      BuildContext context, TrainingSessionDefinition session) {
    final TextEditingController titleController = TextEditingController();
    titleController.text = '${session.title}${AppLocalizations.of(context)!.copySuffix}';

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.duplicateTrainingSession),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(AppLocalizations.of(context)!.duplicateConfirmation(session.title)),
            const SizedBox(height: 16),
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.newSessionTitle,
                border: const OutlineInputBorder(),
              ),
              maxLength: 50,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _duplicateSession(context, session, titleController.text.trim());
            },
            child: Text(AppLocalizations.of(context)!.duplicate),
          ),
        ],
      ),
    );
  }

  Future<void> _duplicateSession(BuildContext context,
      TrainingSessionDefinition session, String newTitle) async {
    if (newTitle.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.sessionTitleCannotBeEmpty),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 16),
              Text(AppLocalizations.of(context)!.duplicatingSession),
            ],
          ),
          duration: const Duration(seconds: 2),
        ),
      );

      // Now we have the original non-expanded session directly!
      // No need for complex logic - just copy it
      final duplicatedSession = session.copy();

      // Create a new custom session with the copied data but new title and custom flag
      final customSession = TrainingSessionDefinition(
        title: newTitle,
        ftmsMachineType: duplicatedSession.ftmsMachineType,
        intervals: duplicatedSession.intervals,
        isCustom: true,
        isDistanceBased: duplicatedSession.isDistanceBased,
      );

      // Save the duplicated session
      final storageService = TrainingSessionStorageService();
      await storageService.saveSession(customSession);

      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.sessionDuplicated(newTitle)),
            backgroundColor: Colors.green,
          ),
        );

        // Call the duplicate callback if provided
        if (widget.onSessionDuplicate != null) {
          widget.onSessionDuplicate!(customSession);
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.failedToDuplicateSession(e.toString())),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Widget _buildStartSessionButton(
      BuildContext context, TrainingSessionDefinition session) {
    return StreamBuilder<List<BTDevice>>(
      stream: SupportedBTDeviceManager().connectedDevicesStream,
      initialData: SupportedBTDeviceManager().allConnectedDevices,
      builder: (context, snapshot) {
        final devices = snapshot.data ?? [];
        final ftmsDevices = devices
            .where((d) =>
                d.deviceTypeName == 'FTMS' &&
                session.ftmsMachineType == (d as dynamic).deviceType)
            .toList();

        final hasCompatibleDevice = ftmsDevices.isNotEmpty;

        return ElevatedButton.icon(
          icon: const Icon(Icons.play_arrow, size: 16),
          label: Text(
            hasCompatibleDevice ? AppLocalizations.of(context)!.startSession : AppLocalizations.of(context)!.notConnected,
            style: const TextStyle(fontSize: 13),
          ),
          onPressed: hasCompatibleDevice
              ? () async {
                  if (widget.onSessionSelected != null) {
                    widget.onSessionSelected!(session);
                  } else {
                    Navigator.pop(context, session);
                  }
                }
              : null,
        );
      },
    );
  }
}
