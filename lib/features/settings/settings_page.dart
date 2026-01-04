import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'model/user_settings.dart';
import '../../core/utils/logger.dart';
import '../../l10n/app_localizations.dart';
import 'widgets/settings_section.dart';
import 'widgets/user_preferences_section.dart';

/// Comprehensive settings page for the FTMS application
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  UserSettings? _userSettings;
  bool _isLoading = true;
  bool _hasChanges = false;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = packageInfo.version;
      });
    } catch (e) {
      logger.e('Failed to load app version: $e');
    }
  }

  Future<void> _loadSettings() async {
    try {
      final userSettings = await UserSettings.loadDefault();

      setState(() {
        _userSettings = userSettings;
        _isLoading = false;
      });
    } catch (e) {
      logger.e('Failed to load settings: $e');
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.failedToLoadSettings),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveSettings() async {
    if (_userSettings == null) return;

    try {
      await _userSettings!.save();

      setState(() {
        _hasChanges = false;
      });

      if (mounted) {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.settingsSavedSuccessfully),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      logger.e('Failed to save settings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.failedToSaveSettings(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onUserSettingsChanged(UserSettings newSettings) {
    setState(() {
      _userSettings = newSettings;
      _hasChanges = true;
    });
  }

  Future<bool> _onWillPop() async {
    if (_hasChanges) {
      await _saveSettings();
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          if (await _onWillPop()) {
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.settingsPageTitle),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              if (await _onWillPop()) {
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              }
            },
          ),
        ),
      body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_userSettings == null) {
      return SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              const Text(
                'Failed to load settings',
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadSettings,
                child: Text(AppLocalizations.of(context)!.retry),
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UserPreferencesSection(
              userSettings: _userSettings!,
              onChanged: _onUserSettingsChanged,
            ),
            const SizedBox(height: 24),
            SettingsSection(
              title: AppLocalizations.of(context)!.aboutSectionTitle,
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(_appVersion.isNotEmpty ? '${AppLocalizations.of(context)!.appName} $_appVersion' : AppLocalizations.of(context)!.appName),
                  subtitle: Text(AppLocalizations.of(context)!.appDescription),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
