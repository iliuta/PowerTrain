import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_ftms/flutter_ftms.dart';
import 'package:ftms/core/models/device_types.dart';
import 'package:ftms/core/utils/logger.dart';
import 'package:ftms/l10n/app_localizations.dart';
import 'bt_device.dart';
import 'bt_device_navigation_registry.dart';
import 'last_connected_devices_service.dart';
import '../../models/bt_device_service_type.dart';
import '../../bloc/ftms_bloc.dart';
import '../device_data_merger.dart';
import '../ftms_service.dart';

/// Service for FTMS (Fitness Machine Service) devices
class Ftms extends BTDevice {
  static final Ftms _instance = Ftms._internal();
  factory Ftms() => _instance;
  Ftms._internal();

  DeviceType? _deviceType;
  DeviceDataMerger? _dataMerger;
  final StreamController<DeviceType> _deviceTypeController = StreamController<DeviceType>.broadcast();

  @override
  String get deviceTypeName => 'FTMS';

  @override
  int get listPriority => 5; // Medium priority - show after HRM devices

  /// Device type (for FTMS devices)
  DeviceType? get deviceType => _deviceType;

  /// Stream of device type changes
  Stream<DeviceType> get deviceTypeStream => _deviceTypeController.stream;

  /// Update device type (for FTMS devices)
  void updateDeviceType(DeviceType deviceType) {
    _deviceType = deviceType;
    _deviceTypeController.add(deviceType);
    notifyDevicesChanged();
    
    // Save the machine type to preferences
    _saveDeviceInfo(machineType: deviceType);
  }

  Future<void> _saveDeviceInfo({DeviceType? machineType}) async {
    try {
      final lastConnectedService = LastConnectedDevicesService();
      await lastConnectedService.saveLastConnectedDevice(
        deviceType: BTDeviceServiceType.fromString(deviceTypeName),
        deviceId: id,
        deviceName: name,
        machineType: machineType,
      );
    } catch (e) {
      logger.w('⚠️ Could not save last connected device: $e');
    }
  }

  /// Override to load saved machine type after connection
  @override
  Future<bool> connectToDevice(BluetoothDevice device) async {
    final success = await super.connectToDevice(device);
    if (success) {
      // Try to load saved machine type for this FTMS device
      try {
        final lastConnectedService = LastConnectedDevicesService();
        final savedDevice = await lastConnectedService.getLastConnectedDevice(
          BTDeviceServiceType.fromString(deviceTypeName),
        );
        if (savedDevice != null && savedDevice['machineType'] != null) {
          _deviceType = DeviceType.fromString(savedDevice['machineType'] as String);
        }
      } catch (e) {
        // Ignore errors when loading machine type
        logger.w('⚠️ Could not load saved machine type: $e');
      }
    }
    return success;
  }

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
        _detectFtmsMachineTypeAndConnectToDataStream(device);
        
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
  Future<void> _detectFtmsMachineTypeAndConnectToDataStream(BluetoothDevice device) async {
    try {
      logger.i('🔧 FTMS: Starting machine type detection for ${device.platformName}');
      try {
        var detectedType = await _determineDeviceTypeFromCharacteristics(device);
        if (detectedType != null) {
          logger.i('🔧 FTMS: Detected machine type from characteristics: $detectedType');
          updateDeviceType(detectedType);
        }
      } catch(e) {
        logger.w('⚠️ FTMS: Failed to determine ftms device type: $e');
        // Continue anyway - some devices may not require control request
      }

      await FTMSService(device).requestControlOnly();
      
      // Initialize packet merger for handling split packets (e.g., Yosuda rower)
      _dataMerger = DeviceDataMerger(
        onMergedData: (DeviceData mergedData) {
          // Forward merged data to the global FTMS bloc for other consumers
          ftmsBloc.ftmsDeviceDataControllerSink.add(mergedData);
        },
      );
      
      // Listen to FTMS data stream and process through merger
      FTMS.useDeviceDataCharacteristic(
        device,
        (DeviceData data) {
          // Process packet through merger to handle split packets
          _dataMerger?.processPacket(data);
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
      
      await _detectFtmsMachineTypeAndConnectToDataStream(device);

      logger.i('🔧 FTMS: Data stream re-established after reconnection');
      await FTMSService(device).requestControlOnly();
    } catch (e) {
      logger.e('❌ FTMS: Failed to re-establish data stream after reconnection: $e');
    }
  }

  /// Determine device type by inspecting available FTMS characteristics
  /// According to FTMS spec:
  /// - 0x2AD1: Rower Data
  /// - 0x2AD2: Indoor Bike Data
  Future<DeviceType?> _determineDeviceTypeFromCharacteristics(BluetoothDevice device) async {
    try {
      // Ensure services are discovered
      // ignore: unnecessary_null_comparison
      if (device.servicesList == null || device.servicesList.isEmpty) {
        logger.i('🔧 FTMS: Discovering services for device type detection');
        await device.discoverServices();
      }
      
      // Find FTMS service
      final ftmsServices = device.servicesList
          .where((s) => s.uuid.toString().toLowerCase().contains('1826'));
      
      if (ftmsServices.isEmpty) {
        logger.w('⚠️ FTMS: No FTMS service found on device');
        return null;
      }
      
      final ftmsService = ftmsServices.first;
      final characteristics = ftmsService.characteristics;
      
      // Check for rower data characteristic (0x2AD1)
      final hasRowerData = characteristics
          .any((c) => c.uuid.toString().toLowerCase().contains('2ad1'));
      
      // Check for indoor bike data characteristic (0x2AD2)
      final hasBikeData = characteristics
          .any((c) => c.uuid.toString().toLowerCase().contains('2ad2'));
      
      // Determine device type based on available characteristics
      if (hasRowerData) {
        return DeviceType.rower;
      } else if (hasBikeData) {
        return DeviceType.indoorBike;
      } else {
        logger.w('⚠️ FTMS: Could not determine device type from characteristics');
        return null;
      }
    } catch (e) {
      logger.w('⚠️ FTMS: Failed to determine device type from characteristics: $e');
      return null;
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
          child: Text(AppLocalizations.of(context)!.open),
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
          child: Text(AppLocalizations.of(context)!.open),
          onPressed: () => navigationCallback(context, device),
        ),
      );
    }
    
    return actions;
  }
}
