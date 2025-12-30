// This file was moved from lib/scan_widgets.dart
import 'package:flutter/material.dart';
import 'package:flutter_ftms/flutter_ftms.dart';
import 'package:ftms/core/utils/logger.dart';
import 'package:ftms/l10n/app_localizations.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../ftms/ftms_page.dart';
import '../../core/services/devices/bt_device_manager.dart';
import '../../core/services/devices/bt_device_navigation_registry.dart';
import '../../core/services/devices/bt_device.dart';
import '../../core/services/devices/last_connected_devices_service.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Button for scanning Bluetooth devices
Widget scanBluetoothButton(bool? isScanning) {
  if (isScanning == null) {
    return Container();
  }
  return ElevatedButton(
    onPressed: isScanning ? null : () async {
    },
    child:
        isScanning ? const Text("Scanning...") : const Text("Scan for devices"),
  );
}

/// Widget to display scan results as a list of FTMS devices
Widget scanResultsToWidget(List<ScanResult> data, BuildContext context) {
  final supportedBTDeviceManager = SupportedBTDeviceManager();

  // Get connected devices
  final connectedDevices = SupportedBTDeviceManager().allConnectedDevices;

  // Create a set of connected device IDs for quick lookup
  final connectedDeviceIds =
      connectedDevices.map((d) => d.id).toSet();

  // Filter out scan results that are already connected to avoid duplicates
  final availableDevices = data
      .where((scanResult) =>
          !connectedDeviceIds.contains(scanResult.device.remoteId.str))
      .toList();

  // Sort available devices by device type priority
  final sortedAvailableDevices =
      supportedBTDeviceManager.sortBTDevicesByPriority(availableDevices);

  // Auto-reconnect to previously connected devices
  _handleAutoReconnection(sortedAvailableDevices, context);

  // Separate connected devices into FTMS and sensors
  final connectedFtmsDevices = connectedDevices
      .where((d) => d.deviceTypeName == 'FTMS')
      .toList();
  final connectedSensorDevices = connectedDevices
      .where((d) => d.deviceTypeName != 'FTMS')
      .toList();

  // Separate available devices into FTMS and sensors
  final availableFtmsDevices = <ScanResult>[];
  final availableSensorDevices = <ScanResult>[];
  
  for (final scanResult in sortedAvailableDevices) {
    final deviceService =
        supportedBTDeviceManager.getBTDevice(scanResult.device, data);
    if (deviceService != null) {
      if (deviceService.deviceTypeName == 'FTMS') {
        availableFtmsDevices.add(scanResult);
      } else {
        availableSensorDevices.add(scanResult);
      }
    }
  }

  // Build the widget list with sections
  final List<Widget> deviceWidgets = [];

  // FTMS Machines Section
  if (connectedFtmsDevices.isNotEmpty || availableFtmsDevices.isNotEmpty) {
    deviceWidgets.add(
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(
          AppLocalizations.of(context)!.fitnessMachines,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
        ),
      ),
    );

    // Add connected FTMS devices
    for (final connectedDevice in connectedFtmsDevices) {
      deviceWidgets.add(_buildConnectedDeviceCard(connectedDevice, context));
    }

    // Add available FTMS devices
    for (final scanResult in availableFtmsDevices) {
      final deviceService =
          supportedBTDeviceManager.getBTDevice(scanResult.device, data);
      deviceWidgets.add(_buildAvailableDeviceCard(scanResult, deviceService, context, data));
    }
  }

  // Sensors Section
  if (connectedSensorDevices.isNotEmpty || availableSensorDevices.isNotEmpty) {
    deviceWidgets.add(
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(
          AppLocalizations.of(context)!.sensors,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
        ),
      ),
    );

    // Add connected sensor devices
    for (final connectedDevice in connectedSensorDevices) {
      deviceWidgets.add(_buildConnectedDeviceCard(connectedDevice, context));
    }

    // Add available sensor devices
    for (final scanResult in availableSensorDevices) {
      final deviceService =
          supportedBTDeviceManager.getBTDevice(scanResult.device, data);
      deviceWidgets.add(_buildAvailableDeviceCard(scanResult, deviceService, context, data));
    }
  }

  // Show a message if no devices found
  if (deviceWidgets.isEmpty) {
    deviceWidgets.add(
      Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            AppLocalizations.of(context)!.noDevicesFound,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      ),
    );
  }

  return ListView(children: deviceWidgets);
}

/// Build a card widget for a connected device
Widget _buildConnectedDeviceCard(BTDevice connectedDevice, BuildContext context) {
  return Card(
    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    elevation: 2,
    child: ListTile(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              connectedDevice.getDeviceIcon(context) ?? Container(),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _getLocalizedDeviceName(connectedDevice, context),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              // Connected indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  AppLocalizations.of(context)!.connected,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          // Move buttons below the device name for better responsiveness
          const SizedBox(height: 8),
          getButtonForConnectedDevice(connectedDevice, context),
        ],
      ),
      leading: const SizedBox(
        width: 40,
        child: Center(
          child: Icon(Icons.bluetooth_connected, color: Colors.green),
        ),
      ),
    ),
  );
}

/// Build a card widget for an available device
Widget _buildAvailableDeviceCard(ScanResult scanResult, BTDevice? deviceService, 
    BuildContext context, List<ScanResult> data) {
  return Card(
    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    elevation: 2,
    child: ListTile(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (deviceService != null) ...[
                deviceService.getDeviceIcon(context) ?? Container(),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  scanResult.device.platformName.isEmpty
                      ? (scanResult.advertisementData.advName.isEmpty
                          ? AppLocalizations.of(context)!.unknownDevice
                          : scanResult.advertisementData.advName)
                      : scanResult.device.platformName,
                ),
              ),
            ],
          ),
          // Move buttons below the device name for better responsiveness
          const SizedBox(height: 8),
          getButtonForBluetoothDevice(scanResult.device, context, data),
        ],
      ),
    ),
  );
}

/// Button for connecting/disconnecting to a Bluetooth device
Widget getButtonForBluetoothDevice(BluetoothDevice device, BuildContext context,
    List<ScanResult> scanResults) {
  final deviceTypeManager = SupportedBTDeviceManager();

  return StreamBuilder<BluetoothConnectionState>(
      stream: device.connectionState,
      builder: (c, snapshot) {
        if (!snapshot.hasData) {
          return Text(AppLocalizations.of(context)!.loading);
        }
        var deviceState = snapshot.data!;
        switch (deviceState) {
          case BluetoothConnectionState.disconnected:
            return ElevatedButton(
              child: Text(AppLocalizations.of(context)!.connect),
              onPressed: () async {
                final snackBar = SnackBar(
                  content: Text(AppLocalizations.of(context)!.connectingTo(device.platformName)),
                  duration: const Duration(seconds: 2),
                );
                ScaffoldMessenger.of(context).showSnackBar(snackBar);

                // Get the primary device btDevice for this device
                final btDevice =
                    deviceTypeManager.getBTDevice(device, scanResults);

                logger.i(
                    '🔍 Device btDevice for ${device.platformName}: ${btDevice?.deviceTypeName ?? 'null'}');

                if (btDevice != null) {
                  logger.i(
                      '✅ Using primary device btDevice: ${btDevice.deviceTypeName} for ${device.platformName}');
                  // Try to connect using the appropriate device btDevice
                  final success = await btDevice.connectToDevice(device);
                  if (success && context.mounted) {
                    // Device is now automatically tracked in BTDevice system
                    logger.i(
                        '📱 Device connected via new architecture: ${device.platformName}');

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(AppLocalizations.of(context)!.connectedTo(btDevice.deviceTypeName, device.platformName)),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } else if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(AppLocalizations.of(context)!.failedToConnect(device.platformName)),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppLocalizations.of(context)!.unsupportedDevice(device.platformName)),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            );
          case BluetoothConnectionState.connected:
            return LayoutBuilder(
              builder: (context, constraints) {
                return Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  alignment: WrapAlignment.start,
                  children: [
                    // Get actions from device services
                    ...() {
                      final matchingBTDevices = deviceTypeManager
                          .getAllMatchingBTDevices(device, scanResults);
                      final actions = <Widget>[];

                      for (final btDevice in matchingBTDevices) {
                        actions.addAll(
                            btDevice.getConnectedActions(device, context));
                      }
                      return actions;
                    }(),
                    OutlinedButton(
                      child: Text(AppLocalizations.of(context)!.disconnect),
                      onPressed: () async {
                        // Disconnect using all matching services
                        final matchingBTDevices = deviceTypeManager
                            .getAllMatchingBTDevices(device, scanResults);
                        for (final btDevice in matchingBTDevices) {
                          await btDevice.disconnectFromDevice(device);
                        }

                        // Disable wakelock when disconnecting
                        WakelockPlus.disable();
                      },
                    ),
                  ],
                );
              },
            );
          default:
            return Text(deviceState.name);
        }
      });
}

/// Button for actions on already connected devices
Widget getButtonForConnectedDevice(
    BTDevice connectedDevice, BuildContext context) {
  return LayoutBuilder(
    builder: (context, constraints) {
      return Wrap(
        spacing: 4,
        runSpacing: 4,
        alignment: WrapAlignment.start,
        children: [
          // Get actions from the device service
          if (connectedDevice.connectedDevice != null)
            ...connectedDevice.getConnectedActions(connectedDevice.connectedDevice!, context),
          OutlinedButton(
            child: Text(AppLocalizations.of(context)!.disconnect),
            onPressed: () async {
              // Disconnect using the device service
              if (connectedDevice.connectedDevice != null) {
                await connectedDevice.disconnectFromDevice(connectedDevice.connectedDevice!);
              }

              // Disable wakelock when disconnecting
              WakelockPlus.disable();
            },
          ),
        ],
      );
    },
  );
}

/// Initialize device navigation callbacks
/// This should be called once during app initialization to register navigation callbacks
/// and avoid circular dependencies between device services and UI components
void initializeDeviceNavigation() {
  final registry = BTDeviceNavigationRegistry();

  // Register FTMS navigation callback
  registry.registerNavigation('FTMS', (context, device) async {
    // Enable wakelock when device is selected
    try {
      await WakelockPlus.enable();
    } catch (e) {
      // Wakelock not supported on this platform
      logger.i('Wakelock not supported: $e');
    }

    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FTMSPage(ftmsDevice: device),
      ),
    );
  });
}

/// Get localized device name for display
String _getLocalizedDeviceName(BTDevice device, BuildContext context) {
  final name = device.name;
  if (name == '(unknown device)') {
    return AppLocalizations.of(context)!.unknownDevice;
  } else if (name == '(no device)') {
    return AppLocalizations.of(context)!.noDevice;
  }
  return name;
}

/// Handle auto-reconnection and display UI feedback
void _handleAutoReconnection(List<ScanResult> scanResults, BuildContext context) async {
  final lastConnectedService = LastConnectedDevicesService();
  
  // Attempt auto-reconnection via service
  final results = await lastConnectedService.attemptAutoReconnections(scanResults);
  
  // Display UI feedback for successful reconnections
  if (context.mounted) {
    for (final result in results) {
      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.autoReconnected(result.deviceType.name, result.deviceName)),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}
