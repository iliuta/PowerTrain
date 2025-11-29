import 'package:flutter/material.dart';
import '../training/training_sessions_page.dart';
import '../settings/settings_page.dart';
import '../fit_files/fit_file_manager_page.dart';
import 'package:flutter_ftms/flutter_ftms.dart';

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
        const PopupMenuItem<String>(
          value: 'training_sessions',
          child: ListTile(
            leading: Icon(Icons.fitness_center),
            title: Text('Training Sessions'),
            dense: true,
          ),
        ),
        const PopupMenuItem<String>(
          value: 'fit_files',
          child: ListTile(
            leading: Icon(Icons.folder),
            title: Text('FIT Files'),
            dense: true,
          ),
        ),
        const PopupMenuItem<String>(
          value: 'settings',
          child: ListTile(
            leading: Icon(Icons.settings),
            title: Text('Settings'),
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
            content: Text('Disconnected from ${connectedDevice!.platformName}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to disconnect: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
