import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_ftms/flutter_ftms.dart';
import 'package:ftms/core/models/device_types.dart';
import 'package:ftms/core/utils/logger.dart';
import 'bt_device.dart';
import 'bt_device_navigation_registry.dart';
import '../../bloc/ftms_bloc.dart';

/// Service for FTMS (Fitness Machine Service) devices
class Ftms extends BTDevice {
  static final Ftms _instance = Ftms._internal();
  factory Ftms() => _instance;
  Ftms._internal();

  @override
  String get deviceTypeName => 'FTMS';

  @override
  int get listPriority => 5; // Medium priority - show after HRM devices

  @override
  Widget? getDeviceIcon(BuildContext context) {
    return const Icon(
      Icons.fitness_center,
      color: Colors.blue,
      size: 16,
    );
  }

  // This is an approximation since the actual check is async
  // We'll use this for synchronous operations like sorting
  @override
  bool isDeviceOfThisType(BluetoothDevice device, List<ScanResult> scanResults) {
    // Look for common FTMS service UUIDs in advertisement data
    final scanResult = scanResults.firstWhere(
      (result) => result.device.remoteId == device.remoteId,
      orElse: () => ScanResult(
        device: device,
        advertisementData: AdvertisementData(
          advName: '',
          connectable: false,
          manufacturerData: {},
          serviceData: {},
          serviceUuids: [],
          txPowerLevel: null,
          appearance: null,
        ),
        rssi: 0,
        timeStamp: DateTime.now(),
      ),
    );

    // Check for common FTMS service UUIDs
    const shortFtmsServiceUuid = "1826";

    // Check in service UUIDs if available
    final serviceUuids = scanResult.advertisementData.serviceUuids;
    for (final uuid in serviceUuids) {
      final uuidString = uuid.toString().toUpperCase();
      if (uuidString.contains(shortFtmsServiceUuid)) {
        return true;
      }
    }

    return false;
  }

  /// Asynchronous check if a device is an FTMS device
  /// This is more accurate but can't be used for sorting
  Future<bool> isFtmsDevice(BluetoothDevice device) {
    return FTMS.isBluetoothDeviceFTMSDevice(device);
  }

  @override
  Future<bool> performConnection(BluetoothDevice device) async {
    try {
      logger.i('🔧 FTMS: Connecting to device: ${device.platformName}');
      
      // Use direct device.connect with autoConnect instead of FTMS.connectToFTMSDevice
      // to enable automatic reconnection. This ensures the device will automatically
      // reconnect when it becomes available after any disconnection
      // Note: mtu must be null when using autoConnect
      await device.connect(autoConnect: true, mtu: null, license: License.free);
      
      // Wait for the device to be actually connected before proceeding
      if (!device.isConnected) {
        // Wait for connection state to become connected
        await device.connectionState
            .where((state) => state == BluetoothConnectionState.connected)
            .first
            .timeout(Duration(seconds: 10));
      }
      
      logger.i('🔧 FTMS: Successfully connected to device');
      
      // Start listening to device data to detect machine type
      // Use a delay to ensure the connection is stable
      await Future.delayed(const Duration(milliseconds: 1000));
      
      // Check if device is still connected before starting machine type detection
      if (device.isConnected) {
        logger.i('🔧 FTMS: Starting machine type detection');
        startMachineTypeDetection(device);
        
        // Listen for connection state changes to handle both disconnection and reconnection
        device.connectionState.listen((state) {
          if (state == BluetoothConnectionState.disconnected) {
            logger.i('FTMS device disconnected - waiting for autoConnect reconnection');
          } else if (state == BluetoothConnectionState.connected) {
            logger.i('FTMS device reconnected - re-establishing data stream');
            _handleReconnection(device);
          }
        });
      } else {
        logger.i('❌ FTMS: Device disconnected before machine type detection');
        return false;
      }
      
      return true;
    } catch (e) {
      logger.i('❌ FTMS: Connection failed: $e');
      return false;
    }
  }

  /// Start listening to FTMS device data to detect and store machine type
  void startMachineTypeDetection(BluetoothDevice device) {
    try {
      logger.i('🔧 FTMS: Starting machine type detection for ${device.platformName}');
      
      // Listen to FTMS data stream to detect machine type
      FTMS.useDeviceDataCharacteristic(
        device,
        (DeviceData data) {
          // Extract machine type from device data
          final machineType = DeviceType.fromFtms(data.deviceDataType);
          
          logger.i('🔧 FTMS: Detected machine type: $machineType');
          
          // Update this device's machine type
          updateDeviceType(machineType);
          
          // Also forward to the global FTMS bloc for other consumers
          ftmsBloc.ftmsDeviceDataControllerSink.add(data);
        },
      );
    } catch (e) {
      logger.i('❌ FTMS: Machine type detection failed: $e');
      // Continue without machine type detection
    }
  }
  
  /// Handle device reconnection by re-establishing data streams
  Future<void> _handleReconnection(BluetoothDevice device) async {
    try {
      // Wait a moment for the connection to stabilize
      await Future.delayed(Duration(milliseconds: 500));
      
      logger.i('🔧 FTMS: Re-establishing data stream after reconnection');
      
      // Re-establish the FTMS data stream
      startMachineTypeDetection(device);
      
      logger.i('🔧 FTMS: Data stream re-established after reconnection');
    } catch (e) {
      logger.e('❌ FTMS: Failed to re-establish data stream after reconnection: $e');
    }
  }

  @override
  Future<void> performDisconnection(BluetoothDevice device) async {
    await FTMS.disconnectFromFTMSDevice(device);
  }

  @override
  Widget? getDevicePage(BluetoothDevice device) {
    // Return null since we use navigation callback instead to avoid circular dependencies
    return null;
  }

  @override
  void Function(BuildContext context, BluetoothDevice device)? getNavigationCallback() {
    return BTDeviceNavigationRegistry().getNavigationCallback('FTMS');
  }

  @override
  List<Widget> getConnectedActions(BluetoothDevice device, BuildContext context) {
    // Use the parent class implementation which will check for navigation callback
    final page = getDevicePage(device);
    final navigationCallback = getNavigationCallback();
    final actions = <Widget>[];
    
    if (page != null) {
      actions.add(
        ElevatedButton(
          child: const Text("Open"),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => page),
            );
          },
        ),
      );
    } else if (navigationCallback != null) {
      actions.add(
        ElevatedButton(
          child: const Text("Open"),
          onPressed: () => navigationCallback(context, device),
        ),
      );
    }
    
    return actions;
  }
}
