import 'package:flutter/material.dart';
import '../training/training_sessions_page.dart';
import '../settings/settings_page.dart';
import '../fit_files/fit_file_manager_page.dart';
import 'package:flutter_ftms/flutter_ftms.dart';
import 'help_page.dart';
import '../../l10n/app_localizations.dart';

/// A burger menu widget with navigation options and device status
class BurgerMenu extends StatelessWidget {
  final BluetoothDevice? connectedDevice;

  const BurgerMenu({
    super.key,
    this.connectedDevice,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.menu),
      tooltip: 'Menu',
      onSelected: (String value) {
        _handleMenuSelection(context, value);
      },
      itemBuilder: (BuildContext context) => [
        // Navigation options
        PopupMenuItem<String>(
          value: 'training_sessions',
          child: ListTile(
            leading: const Icon(Icons.fitness_center),
            title: Text(AppLocalizations.of(context)!.trainingSessions),
            dense: true,
          ),
        ),
        PopupMenuItem<String>(
          value: 'fit_files',
          child: ListTile(
            leading: const Icon(Icons.folder),
            title: Text(AppLocalizations.of(context)!.unsynchronizedActivities),
            dense: true,
          ),
        ),
        PopupMenuItem<String>(
          value: 'settings',
          child: ListTile(
            leading: const Icon(Icons.settings),
            title: Text(AppLocalizations.of(context)!.settings),
            dense: true,
          ),
        ),
        PopupMenuItem<String>(
          value: 'help',
          child: ListTile(
            leading: const Icon(Icons.help),
            title: Text(AppLocalizations.of(context)!.help),
            dense: true,
          ),
        ),
      ],
    );
  }

  void _handleMenuSelection(BuildContext context, String value) {
    switch (value) {
      case 'training_sessions':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => TrainingSessionsPage(
              connectedDevice: connectedDevice,
            ),
          ),
        );
        break;
      case 'fit_files':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const FitFileManagerPage(),
          ),
        );
        break;
      case 'settings':
        _showSettingsDialog(context);
        break;
      case 'help':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const HelpPage(),
          ),
        );
        break;
      case 'disconnect':
        _disconnectDevice(context);
        break;
    }
  }

  void _showSettingsDialog(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SettingsPage(),
      ),
    );
  }

  void _disconnectDevice(BuildContext context) async {
    if (connectedDevice == null) return;
    
    try {
      await connectedDevice!.disconnect();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.disconnectedFromDevice(connectedDevice!.platformName)),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.failedToDisconnect(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
