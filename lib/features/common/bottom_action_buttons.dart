import 'package:flutter/material.dart';
import '../training/training_sessions_page.dart';
import '../settings/settings_page.dart';
import '../fit_files/fit_file_manager_page.dart';
import 'package:flutter_ftms/flutter_ftms.dart';
import 'help_page.dart';

/// A bottom widget with action buttons for navigation and device control
class BottomActionButtons extends StatelessWidget {
  final BluetoothDevice? connectedDevice;

  const BottomActionButtons({
    super.key,
    this.connectedDevice,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(4.0),
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: _buildButtons(context),
        ),
      ),
    );
  }

  List<Widget> _buildButtons(BuildContext context) {
    return [
      _buildButton(
        context,
        icon: Icons.fitness_center,
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => TrainingSessionsPage(
                connectedDevice: connectedDevice,
              ),
            ),
          );
        },
      ),
      _buildButton(
        context,
        icon: Icons.folder,
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const FitFileManagerPage(),
            ),
          );
        },
      ),
      _buildButton(
        context,
        icon: Icons.settings,
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const SettingsPage(),
            ),
          );
        },
      ),
      _buildButton(
        context,
        icon: Icons.help,
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const HelpPage(),
            ),
          );
        },
      ),
    ];
  }

  Widget _buildButton(BuildContext context,
      {required IconData icon, required VoidCallback onPressed}) {
    return Flexible(
      child: IconButton(
        icon: Icon(icon, size: 20.0),
        onPressed: onPressed,
        style: IconButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        ),
      ),
    );
  }


}