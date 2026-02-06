import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../model/user_settings.dart';
import 'settings_section.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/config/live_data_display_config.dart';
import '../../../core/models/device_types.dart';

/// Widget for editing user fitness preferences
class UserPreferencesSection extends StatefulWidget {
  final UserSettings userSettings;
  final ValueChanged<UserSettings> onChanged;

  const UserPreferencesSection({
    super.key,
    required this.userSettings,
    required this.onChanged,
  });

  @override
  State<UserPreferencesSection> createState() => _UserPreferencesSectionState();
}

class _UserPreferencesSectionState extends State<UserPreferencesSection> {
  String? _editingField;
  late TextEditingController _cyclingFtpController;
  late TextEditingController _rowingFtpController;
  LiveDataDisplayConfig? _indoorBikeConfig;
  LiveDataDisplayConfig? _rowerConfig;

  @override
  void initState() {
    super.initState();
    _cyclingFtpController =
        TextEditingController(text: widget.userSettings.cyclingFtp.toString());
    _rowingFtpController =
        TextEditingController(text: widget.userSettings.rowingFtp);
    _loadConfigs();
  }

  Future<void> _loadConfigs() async {
    final indoorBikeConfig = await LiveDataDisplayConfig.loadForFtmsMachineType(DeviceType.indoorBike);
    final rowerConfig = await LiveDataDisplayConfig.loadForFtmsMachineType(DeviceType.rower);
    if (mounted) {
      setState(() {
        _indoorBikeConfig = indoorBikeConfig;
        _rowerConfig = rowerConfig;
      });
    }
  }

  @override
  void didUpdateWidget(UserPreferencesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userSettings != widget.userSettings) {
      _cyclingFtpController.text = widget.userSettings.cyclingFtp.toString();
      _rowingFtpController.text = widget.userSettings.rowingFtp;
    }
  }

  @override
  void dispose() {
    _cyclingFtpController.dispose();
    _rowingFtpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      title: AppLocalizations.of(context)!.fitnessProfileTitle,
      subtitle: AppLocalizations.of(context)!.fitnessProfileSubtitle,
      children: [
        if (_shouldDisplayCyclingFtp())
          _buildCyclingFtpField(),
        if (_shouldDisplayRowingFtp())
          _buildRowingFtpField(),
        const Divider(),
        _buildDeveloperModeField(),
      ],
    );
  }

  bool _shouldDisplayCyclingFtp() {
    if (_indoorBikeConfig == null) return true; // Show while loading (better UX)
    return !_indoorBikeConfig!.availableInDeveloperModeOnly || widget.userSettings.developerMode;
  }

  bool _shouldDisplayRowingFtp() {
    if (_rowerConfig == null) return true; // Show while loading (better UX)
    return !_rowerConfig!.availableInDeveloperModeOnly || widget.userSettings.developerMode;
  }

  Widget _buildCyclingFtpField() {
    final isEditing = _editingField == 'cyclingFtp';

    return ListTile(
      leading: const Icon(Icons.directions_bike, color: Colors.blue),
      title: Text(AppLocalizations.of(context)!.cyclingFtp),
      subtitle: isEditing
          ? Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: TextField(
                controller: _cyclingFtpController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)!.enterFtpHint,
                  suffixText: 'watts',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                autofocus: true,
                onSubmitted: (value) => _saveCyclingFtp(),
              ),
            )
          : Text(AppLocalizations.of(context)!.watts(widget.userSettings.cyclingFtp)),
      trailing: isEditing
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check, color: Colors.green),
                  onPressed: _saveCyclingFtp,
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: _cancelEditing,
                ),
              ],
            )
          : IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _startEditing('cyclingFtp'),
            ),
      onTap: isEditing ? null : () => _startEditing('cyclingFtp'),
    );
  }

  Widget _buildRowingFtpField() {
    final isEditing = _editingField == 'rowingFtp';

    return ListTile(
      leading: const Icon(Icons.rowing, color: Colors.teal),
      title: Text(AppLocalizations.of(context)!.rowingFtp),
      subtitle: isEditing
          ? Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: TextField(
                controller: _rowingFtpController,
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)!.enterTimeHint,
                  suffixText: '/500m',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                autofocus: true,
                onSubmitted: (value) => _saveRowingFtp(),
              ),
            )
          : Text(AppLocalizations.of(context)!.per500m(widget.userSettings.rowingFtp)),
      trailing: isEditing
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check, color: Colors.green),
                  onPressed: _saveRowingFtp,
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: _cancelEditing,
                ),
              ],
            )
          : IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _startEditing('rowingFtp'),
            ),
      onTap: isEditing ? null : () => _startEditing('rowingFtp'),
    );
  }

  Widget _buildDeveloperModeField() {
    return ListTile(
      leading: const Icon(Icons.developer_mode, color: Colors.orange),
      title: Text(AppLocalizations.of(context)!.developerMode),
      subtitle: Text(AppLocalizations.of(context)!.developerModeSubtitle),
      trailing: Switch(
        value: widget.userSettings.developerMode,
        onChanged: (bool value) {
          widget.onChanged(UserSettings(
            cyclingFtp: widget.userSettings.cyclingFtp,
            rowingFtp: widget.userSettings.rowingFtp,
            developerMode: value,
            soundEnabled: widget.userSettings.soundEnabled,
            metronomeSoundEnabled: widget.userSettings.metronomeSoundEnabled,
            demoModeEnabled: widget.userSettings.demoModeEnabled,
          ));
          HapticFeedback.lightImpact();
        },
      ),
      onTap: () {
        final newValue = !widget.userSettings.developerMode;
        widget.onChanged(UserSettings(
          cyclingFtp: widget.userSettings.cyclingFtp,
          rowingFtp: widget.userSettings.rowingFtp,
          developerMode: newValue,
          soundEnabled: widget.userSettings.soundEnabled,
          metronomeSoundEnabled: widget.userSettings.metronomeSoundEnabled,
          demoModeEnabled: widget.userSettings.demoModeEnabled,
        ));
        HapticFeedback.lightImpact();
      },
    );
  }


  void _startEditing(String field) {
    setState(() {
      _editingField = field;
    });
  }

  void _cancelEditing() {
    setState(() {
      _editingField = null;
    });
    // Reset controllers to original values
    _cyclingFtpController.text = widget.userSettings.cyclingFtp.toString();
    _rowingFtpController.text = widget.userSettings.rowingFtp;
  }

  void _saveCyclingFtp() {
    final value = int.tryParse(_cyclingFtpController.text);
    if (value != null && value >= 50 && value <= 1000) {
      widget.onChanged(UserSettings(
        cyclingFtp: value,
        rowingFtp: widget.userSettings.rowingFtp,
        developerMode: widget.userSettings.developerMode,
        soundEnabled: widget.userSettings.soundEnabled,
        metronomeSoundEnabled: widget.userSettings.metronomeSoundEnabled,
        demoModeEnabled: widget.userSettings.demoModeEnabled,
      ));
      HapticFeedback.lightImpact();
      setState(() {
        _editingField = null;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.invalidFtp),
        ),
      );
    }
  }

  void _saveRowingFtp() {
    final value = _rowingFtpController.text.trim();
    if (_isValidRowingTime(value)) {
      widget.onChanged(UserSettings(
        cyclingFtp: widget.userSettings.cyclingFtp,
        rowingFtp: value,
        developerMode: widget.userSettings.developerMode,
        soundEnabled: widget.userSettings.soundEnabled,
        metronomeSoundEnabled: widget.userSettings.metronomeSoundEnabled,
        demoModeEnabled: widget.userSettings.demoModeEnabled,
      ));
      HapticFeedback.lightImpact();
      setState(() {
        _editingField = null;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.invalidTimeFormat),
        ),
      );
    }
  }

  bool _isValidRowingTime(String time) {
    final regex = RegExp(r'^\d+:\d{2}$');
    if (!regex.hasMatch(time)) return false;

    final parts = time.split(':');
    final minutes = int.tryParse(parts[0]);
    final seconds = int.tryParse(parts[1]);

    return minutes != null &&
        seconds != null &&
        minutes >= 0 &&
        minutes <= 10 &&
        seconds >= 0 &&
        seconds < 60;
  }
}
