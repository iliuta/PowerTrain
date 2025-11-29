// This file was moved from lib/scan_widgets.dart
import 'package:flutter/material.dart';
import 'package:flutter_ftms/flutter_ftms.dart';
import 'package:ftms/core/utils/logger.dart';
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
  logger.i('🔧 scanResultsToWidget: Found ${connectedDevices.length} connected devices');

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

  // Create a combined list: connected devices first, then available devices
  final List<Widget> deviceWidgets = [];

  // Add connected devices first
  for (final connectedDevice in connectedDevices) {
    deviceWidgets.add(
      Card(
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
                      connectedDevice.name,
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
                    child: const Text(
                      'Connected',
                      style: TextStyle(
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
      ),
    );
  }

  // Add available devices
  for (final scanResult in sortedAvailableDevices) {
    final deviceService =
        supportedBTDeviceManager.getBTDevice(scanResult.device, data);
    deviceWidgets.add(
      Card(
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
                          ? "(unknown device)"
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
      ),
    );
  }

  return ListView(children: deviceWidgets);
}

/// Button for connecting/disconnecting to a Bluetooth device
Widget getButtonForBluetoothDevice(BluetoothDevice device, BuildContext context,
    List<ScanResult> scanResults) {
  final deviceTypeManager = SupportedBTDeviceManager();

  return StreamBuilder<BluetoothConnectionState>(
      stream: device.connectionState,
      builder: (c, snapshot) {
        if (!snapshot.hasData) {
          return const Text("...");
        }
        var deviceState = snapshot.data!;
        switch (deviceState) {
          case BluetoothConnectionState.disconnected:
            return ElevatedButton(
              child: const Text("Connect"),
              onPressed: () async {
                final snackBar = SnackBar(
                  content: Text('Connecting to ${device.platformName}...'),
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
                          content: Text(
                              'Connected to ${btDevice.deviceTypeName}: ${device.platformName}'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } else if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text('Failed to connect to ${device.platformName}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text('Unsupported device ${device.platformName}'),
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
                      child: const Text("Disconnect"),
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
            child: const Text("Disconnect"),
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
            content: Text('Auto-reconnected to ${result.deviceType.name}: ${result.deviceName}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}
