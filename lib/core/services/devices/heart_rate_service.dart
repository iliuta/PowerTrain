import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../utils/logger.dart';

/// Service for managing Heart Rate Monitor (HRM) devices
class HeartRateService {
  static final HeartRateService _instance = HeartRateService._internal();
  factory HeartRateService() => _instance;
  HeartRateService._internal();

  /// only one HRM device can be connected at a time
  BluetoothDevice? _connectedHrmDevice;
  BluetoothCharacteristic? _heartRateCharacteristic;
  StreamSubscription<List<int>>? _heartRateSubscription;
  
  final StreamController<int?> _heartRateController = StreamController<int?>.broadcast();
  
  /// Stream of heart rate values from connected HRM device
  Stream<int?> get heartRateStream => _heartRateController.stream;
  
  /// Current heart rate value from HRM device
  int? get currentHeartRate => _currentHeartRate;
  int? _currentHeartRate;
  
  /// Whether an HRM device is currently connected
  bool get isHrmConnected => _connectedHrmDevice != null && _heartRateCharacteristic != null;
  
  /// Connected HRM device name
  String? get connectedDeviceName => _connectedHrmDevice?.platformName;

  static const String heartRateServiceUuid = "0000180D";
  static const String heartRateServiceUuidShort = "180D";
  static const String heartRateMeasurementCharacteristicUuid = "00002A37";
  static const String heartRateMeasurementCharacteristicUuidShort = "2A37";

  /// Connect to an HRM device and start receiving heart rate data
  Future<bool> connectToHrmDevice(BluetoothDevice device) async {
    try {
      logger.i('Connecting to HRM device: ${device.platformName}');
      
      // Disconnect any existing HRM device first
      await disconnectHrmDevice();
      
      // Connect to the device with autoConnect for automatic reconnection
      // This ensures the device will automatically reconnect when it becomes available
      // after any disconnection (e.g., during training sessions)
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
      
      // Discover services
      final services = await device.discoverServices();
      
      // Find heart rate service
      BluetoothService? heartRateService = _findHeartRateService(services);
      
      if (heartRateService == null) {
        logger.w('Heart rate service not found on device ${device.platformName}');
        await device.disconnect();
        return false;
      }
      
      // Find heart rate measurement characteristic
      BluetoothCharacteristic? heartRateCharacteristic = _findHeartRateCharacteristic(heartRateService);
      
      if (heartRateCharacteristic == null) {
        logger.w('Heart rate measurement characteristic not found on device ${device.platformName}');
        await device.disconnect();
        return false;
      }
      
      // Enable notifications
      await heartRateCharacteristic.setNotifyValue(true);
      
      // Subscribe to heart rate data
      _heartRateSubscription = _listenToHeartRateCharacteristic(heartRateCharacteristic);
      
      // Store connection details
      _connectedHrmDevice = device;
      _heartRateCharacteristic = heartRateCharacteristic;
      
      // Listen for connection state changes to handle both disconnection and reconnection
      device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          logger.i('HRM device disconnected - waiting for autoConnect reconnection');
          _handleDisconnection();
        } else if (state == BluetoothConnectionState.connected) {
          logger.i('HRM device reconnected - re-establishing data stream');
          _handleReconnection(device);
        }
      });
      
      logger.i('Successfully connected to HRM device: ${device.platformName}');
      return true;
      
    } catch (e) {
      logger.e('Failed to connect to HRM device: $e');
      await device.disconnect().catchError((_) {});
      return false;
    }
  }

  StreamSubscription<List<int>> _listenToHeartRateCharacteristic(BluetoothCharacteristic heartRateCharacteristic) {
    return heartRateCharacteristic.lastValueStream.listen(
      _parseHeartRateData,
      onError: (error) {
        logger.e('Error receiving heart rate data: $error');
      },
    );
  }

  BluetoothCharacteristic? _findHeartRateCharacteristic(BluetoothService heartRateService) {
     BluetoothCharacteristic? heartRateCharacteristic;
    for (final characteristic in heartRateService.characteristics) {
      final characteristicUuidString = characteristic.uuid.toString().toUpperCase();
      if (characteristicUuidString == heartRateMeasurementCharacteristicUuid.toUpperCase() ||
          characteristicUuidString == heartRateMeasurementCharacteristicUuidShort.toUpperCase()) {
        heartRateCharacteristic = characteristic;
        break;
      }
    }
    return heartRateCharacteristic;
  }

  BluetoothService? _findHeartRateService(List<BluetoothService> services) {
    BluetoothService? heartRateService;
    for (final service in services) {
      final serviceUuidString = service.uuid.toString().toUpperCase();
      if (serviceUuidString == heartRateServiceUuid.toUpperCase() ||
          serviceUuidString == heartRateServiceUuidShort.toUpperCase()) {
        heartRateService = service;
        break;
      }
    }
    return heartRateService;
  }
  
  /// Disconnect from the current HRM device
  Future<void> disconnectHrmDevice() async {
    if (_connectedHrmDevice != null) {
      try {
        logger.i('Disconnecting from HRM device: ${_connectedHrmDevice!.platformName}');
        await _heartRateSubscription?.cancel();
        await _connectedHrmDevice!.disconnect();
      } catch (e) {
        logger.e('Error disconnecting from HRM device: $e');
      }
    }
    _handleDisconnection();
  }
  
  void _handleDisconnection() {
    _heartRateSubscription?.cancel();
    _heartRateSubscription = null;
    _connectedHrmDevice = null;
    _heartRateCharacteristic = null;
    _currentHeartRate = null;
    _heartRateController.add(null);
    logger.i('HRM device disconnected');
  }
  
  /// Handle device reconnection by re-establishing data streams
  Future<void> _handleReconnection(BluetoothDevice device) async {
    try {
      // Clear any existing subscriptions first
      _heartRateSubscription?.cancel();
      _heartRateSubscription = null;
      
      // Wait a moment for the connection to stabilize
      await Future.delayed(Duration(milliseconds: 500));
      
      // Rediscover services to get fresh service references
      final services = await device.discoverServices();
      final heartRateService = _findHeartRateService(services);
      
      if (heartRateService == null) {
        logger.w('Heart rate service not found after reconnection');
        return;
      }
      
      final heartRateCharacteristic = _findHeartRateCharacteristic(heartRateService);
      if (heartRateCharacteristic == null) {
        logger.w('Heart rate characteristic not found after reconnection');
        return;
      }
      
      // Re-enable notifications
      await heartRateCharacteristic.setNotifyValue(true);
      
      // Re-subscribe to heart rate data
      _heartRateSubscription = _listenToHeartRateCharacteristic(heartRateCharacteristic);
      
      // Update stored references
      _connectedHrmDevice = device;
      _heartRateCharacteristic = heartRateCharacteristic;
      
      logger.i('HRM data stream re-established after reconnection');
    } catch (e) {
      logger.e('Failed to re-establish HRM data stream after reconnection: $e');
    }
  }
  
  /// Parse heart rate data from BLE characteristic
  void _parseHeartRateData(List<int> data) {
    if (data.isEmpty) return;
    
    try {
      int heartRate;
      
      // Parse according to Heart Rate Measurement format
      // First byte contains flags
      final flags = data[0];
      
      // Check if heart rate is in 16-bit format (bit 0 of flags)
      if ((flags & 0x01) == 0) {
        // 8-bit heart rate value
        heartRate = data[1];
      } else {
        // 16-bit heart rate value (little endian)
        if (data.length < 3) return;
        heartRate = data[1] + (data[2] << 8);
      }
      
      // Validate heart rate value
      if (heartRate > 0 && heartRate <= 250) {
        _currentHeartRate = heartRate;
        _heartRateController.add(heartRate);
        logger.d('Received heart rate from HRM: $heartRate bpm');
      } else {
        logger.w('Invalid heart rate value received: $heartRate');
      }
      
    } catch (e) {
      logger.e('Error parsing heart rate data: $e');
    }
  }
  
  /// Check if a device is a Heart Rate Monitor device
  static bool isHeartRateDevice(BluetoothDevice device, List<ScanResult> scanResults) {
    try {
      // Check if the device advertises Heart Rate Service in scan results
      final scanResult = scanResults.firstWhere(
        (result) => result.device.remoteId == device.remoteId,
        orElse: () => ScanResult(
          device: device,
          advertisementData: AdvertisementData(
            advName: '',
            txPowerLevel: null,
            appearance: null,
            connectable: false,
            manufacturerData: {},
            serviceData: {},
            serviceUuids: [],
          ),
          rssi: 0,
          timeStamp: DateTime.now(),
        ),
      );
      
      // Check if Heart Rate Service UUID is advertised
      final advertisedServices = scanResult.advertisementData.serviceUuids
          .map((uuid) => uuid.toString().toUpperCase())
          .toList();
      
      // Check for both full UUID and short UUID
      return advertisedServices.contains(heartRateServiceUuid.toUpperCase()) || 
             advertisedServices.contains(heartRateServiceUuidShort.toUpperCase());
    } catch (e) {
      return false;
    }
  }
}
