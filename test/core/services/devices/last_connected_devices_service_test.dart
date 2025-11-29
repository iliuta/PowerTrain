import 'package:flutter_test/flutter_test.dart';
import 'package:ftms/core/services/devices/last_connected_devices_service.dart';
import 'package:ftms/core/models/bt_device_service_type.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:ftms/core/services/devices/bt_device_manager.dart';
import 'package:ftms/core/services/devices/bt_device.dart';
import 'package:ftms/core/services/devices/flutter_blue_plus_facade.dart';
import 'package:ftms/core/services/devices/ftms_facade.dart';
import 'package:flutter/material.dart';
import 'dart:async';

void main() {
  group('LastConnectedDevicesService', () {
    late LastConnectedDevicesService service;

    setUp(() async {
      // Clear all SharedPreferences before each test
      SharedPreferences.setMockInitialValues({});
      service = LastConnectedDevicesService();
      // Reset the singleton for testing
      SupportedBTDeviceManager.resetInstance();
    });

    test('should save device information for a specific device type', () async {
      await service.saveLastConnectedDevice(
        deviceType: BTDeviceServiceType.hrm,
        deviceId: '00:11:22:33:44:55',
        deviceName: 'Test HRM',
      );

      final savedDevice = await service.getLastConnectedDevice(BTDeviceServiceType.hrm);
      
      expect(savedDevice, isNotNull);
      expect(savedDevice!['deviceId'], equals('00:11:22:33:44:55'));
      expect(savedDevice['deviceName'], equals('Test HRM'));
      expect(savedDevice['timestamp'], isNotNull);
    });

    test('should return null when no device is saved for a type', () async {
      final result = await service.getLastConnectedDevice(BTDeviceServiceType.ftms);
      expect(result, isNull);
    });

    test('should overwrite previous device when saving same type', () async {
      // Save first device
      await service.saveLastConnectedDevice(
        deviceType: BTDeviceServiceType.cadence,
        deviceId: '11:22:33:44:55:66',
        deviceName: 'First Cadence',
      );

      // Save second device of the same type
      await service.saveLastConnectedDevice(
        deviceType: BTDeviceServiceType.cadence,
        deviceId: '77:88:99:AA:BB:CC',
        deviceName: 'Second Cadence',
      );

      final savedDevice = await service.getLastConnectedDevice(BTDeviceServiceType.cadence);
      
      expect(savedDevice, isNotNull);
      expect(savedDevice!['deviceId'], equals('77:88:99:AA:BB:CC'));
      expect(savedDevice['deviceName'], equals('Second Cadence'));
    });

    test('should save different devices for different types', () async {
      // Save HRM device
      await service.saveLastConnectedDevice(
        deviceType: BTDeviceServiceType.hrm,
        deviceId: 'AA:BB:CC:DD:EE:FF',
        deviceName: 'My HRM',
      );

      // Save FTMS device
      await service.saveLastConnectedDevice(
        deviceType: BTDeviceServiceType.ftms,
        deviceId: '11:22:33:44:55:66',
        deviceName: 'My FTMS',
      );

      // Save Cadence device
      await service.saveLastConnectedDevice(
        deviceType: BTDeviceServiceType.cadence,
        deviceId: '77:88:99:AA:BB:CC',
        deviceName: 'My Cadence',
      );

      final hrmDevice = await service.getLastConnectedDevice(BTDeviceServiceType.hrm);
      final ftmsDevice = await service.getLastConnectedDevice(BTDeviceServiceType.ftms);
      final cadenceDevice = await service.getLastConnectedDevice(BTDeviceServiceType.cadence);

      expect(hrmDevice!['deviceName'], equals('My HRM'));
      expect(ftmsDevice!['deviceName'], equals('My FTMS'));
      expect(cadenceDevice!['deviceName'], equals('My Cadence'));
    });

    test('should get all last connected devices', () async {
      // Save devices for all types
      await service.saveLastConnectedDevice(
        deviceType: BTDeviceServiceType.hrm,
        deviceId: 'HRM-ID',
        deviceName: 'HRM Device',
      );

      await service.saveLastConnectedDevice(
        deviceType: BTDeviceServiceType.ftms,
        deviceId: 'FTMS-ID',
        deviceName: 'FTMS Device',
      );

      final allDevices = await service.getAllLastConnectedDevices();

      expect(allDevices.length, equals(2));
      expect(allDevices[BTDeviceServiceType.hrm], isNotNull);
      expect(allDevices[BTDeviceServiceType.ftms], isNotNull);
      expect(allDevices[BTDeviceServiceType.cadence], isNull);
      expect(allDevices[BTDeviceServiceType.hrm]!['deviceName'], equals('HRM Device'));
      expect(allDevices[BTDeviceServiceType.ftms]!['deviceName'], equals('FTMS Device'));
    });

    test('should return empty map when no devices are saved', () async {
      final allDevices = await service.getAllLastConnectedDevices();
      expect(allDevices, isEmpty);
    });

    test('should clear last connected device for a specific type', () async {
      // Save devices for multiple types
      await service.saveLastConnectedDevice(
        deviceType: BTDeviceServiceType.hrm,
        deviceId: 'HRM-ID',
        deviceName: 'HRM Device',
      );

      await service.saveLastConnectedDevice(
        deviceType: BTDeviceServiceType.cadence,
        deviceId: 'CADENCE-ID',
        deviceName: 'Cadence Device',
      );

      // Clear HRM device
      await service.clearLastConnectedDevice(BTDeviceServiceType.hrm);

      final hrmDevice = await service.getLastConnectedDevice(BTDeviceServiceType.hrm);
      final cadenceDevice = await service.getLastConnectedDevice(BTDeviceServiceType.cadence);

      expect(hrmDevice, isNull);
      expect(cadenceDevice, isNotNull);
      expect(cadenceDevice!['deviceName'], equals('Cadence Device'));
    });

    test('should clear all last connected devices', () async {
      // Save devices for all types
      await service.saveLastConnectedDevice(
        deviceType: BTDeviceServiceType.hrm,
        deviceId: 'HRM-ID',
        deviceName: 'HRM Device',
      );

      await service.saveLastConnectedDevice(
        deviceType: BTDeviceServiceType.ftms,
        deviceId: 'FTMS-ID',
        deviceName: 'FTMS Device',
      );

      await service.saveLastConnectedDevice(
        deviceType: BTDeviceServiceType.cadence,
        deviceId: 'CADENCE-ID',
        deviceName: 'Cadence Device',
      );

      // Clear all
      await service.clearAllLastConnectedDevices();

      final allDevices = await service.getAllLastConnectedDevices();
      expect(allDevices, isEmpty);
    });

    test('should preserve timestamp when saving device', () async {
      final beforeSave = DateTime.now();
      
      await service.saveLastConnectedDevice(
        deviceType: BTDeviceServiceType.hrm,
        deviceId: 'HRM-ID',
        deviceName: 'HRM Device',
      );

      final afterSave = DateTime.now();
      final savedDevice = await service.getLastConnectedDevice(BTDeviceServiceType.hrm);

      expect(savedDevice, isNotNull);
      final timestamp = DateTime.parse(savedDevice!['timestamp']!);
      
      // Timestamp should be between beforeSave and afterSave
      expect(timestamp.isAfter(beforeSave.subtract(const Duration(seconds: 1))), isTrue);
      expect(timestamp.isBefore(afterSave.add(const Duration(seconds: 1))), isTrue);
    });

    test('should handle device with empty name', () async {
      await service.saveLastConnectedDevice(
        deviceType: BTDeviceServiceType.ftms,
        deviceId: 'DEVICE-ID',
        deviceName: '',
      );

      final savedDevice = await service.getLastConnectedDevice(BTDeviceServiceType.ftms);
      
      expect(savedDevice, isNotNull);
      expect(savedDevice!['deviceName'], equals(''));
    });

    test('should handle device with special characters in name', () async {
      await service.saveLastConnectedDevice(
        deviceType: BTDeviceServiceType.hrm,
        deviceId: 'DEVICE-ID',
        deviceName: 'Device™ with "quotes" & símb©ls',
      );

      final savedDevice = await service.getLastConnectedDevice(BTDeviceServiceType.hrm);
      
      expect(savedDevice, isNotNull);
      expect(savedDevice!['deviceName'], equals('Device™ with "quotes" & símb©ls'));
    });

    test('should handle clearing device that does not exist', () async {
      // Should not throw an error
      await service.clearLastConnectedDevice(BTDeviceServiceType.hrm);
      
      final device = await service.getLastConnectedDevice(BTDeviceServiceType.hrm);
      expect(device, isNull);
    });

    test('should reset reconnection tracking', () {
      service.resetReconnectionTracking();
      // No exception should be thrown
    });

    group('attemptAutoReconnections', () {
      late SupportedBTDeviceManager mockDeviceManager;
      late MockBTDevice mockHrmDevice;
      late MockBTDevice mockCadenceDevice;
      late MockBTDevice mockFtmsDevice;
      late LastConnectedDevicesService serviceWithMocks;
      
      setUp(() {
        // Create mock devices
        mockHrmDevice = MockBTDevice('HRM');
        mockCadenceDevice = MockBTDevice('Cadence');
        mockFtmsDevice = MockBTDevice('FTMS');
        
        // Create mock device manager with test devices
        mockDeviceManager = SupportedBTDeviceManager.forTesting(
          flutterBluePlusFacade: MockFlutterBluePlusFacade(),
          ftmsFacade: MockFtmsFacade(),
          supportedDevices: [
            mockHrmDevice,
            mockCadenceDevice,
            mockFtmsDevice,
          ],
        );
        
        // Create service with mocked device manager
        serviceWithMocks = LastConnectedDevicesService.forTesting(deviceManager: mockDeviceManager);
      });

      test('should return empty list when no devices are saved', () async {
        final scanResults = <ScanResult>[];
        final results = await serviceWithMocks.attemptAutoReconnections(scanResults);
        
        expect(results, isEmpty);
      });

      test('should return empty list when scan results are empty', () async {
        // Save a device
        await serviceWithMocks.saveLastConnectedDevice(
          deviceType: BTDeviceServiceType.hrm,
          deviceId: '00:11:22:33:44:55',
          deviceName: 'Test HRM',
        );

        final scanResults = <ScanResult>[];
        final results = await serviceWithMocks.attemptAutoReconnections(scanResults);
        
        expect(results, isEmpty);
      });

      test('should skip devices not found in scan results', () async {
        // Save HRM device
        await serviceWithMocks.saveLastConnectedDevice(
          deviceType: BTDeviceServiceType.hrm,
          deviceId: '00:11:22:33:44:55',
          deviceName: 'Test HRM',
        );

        // Create scan result with different device ID (not matching saved device)
        final differentDevice = MockBluetoothDevice('99:99:99:99:99:99');
        final scanResults = [MockScanResult(differentDevice)];
        
        final results = await serviceWithMocks.attemptAutoReconnections(scanResults);
        
        // Should not attempt reconnection since device ID doesn't match
        expect(results, isEmpty);
      });

      test('should handle empty saved device map gracefully', () async {
        // Don't save any devices
        final mockDevice = MockBluetoothDevice('00:11:22:33:44:55');
        final scanResults = [MockScanResult(mockDevice)];
        
        final results = await serviceWithMocks.attemptAutoReconnections(scanResults);
        
        // Should return empty since no devices were saved
        expect(results, isEmpty);
      });

      test('should attempt reconnection when matching device is found and succeed', () async {
        // Save HRM device
        await serviceWithMocks.saveLastConnectedDevice(
          deviceType: BTDeviceServiceType.hrm,
          deviceId: '00:11:22:33:44:55',
          deviceName: 'Test HRM',
        );

        // Create scan result with matching device
        final mockDevice = MockBluetoothDevice('00:11:22:33:44:55');
        final scanResults = [MockScanResult(mockDevice)];

        // Configure mock to succeed
        mockHrmDevice.shouldConnectSuccessfully = true;
        
        final results = await serviceWithMocks.attemptAutoReconnections(scanResults);
        
        expect(results, hasLength(1));
        expect(results[0].deviceType, equals(BTDeviceServiceType.hrm));
        expect(results[0].deviceName, equals('Test HRM'));
        expect(results[0].success, isTrue);
        expect(mockHrmDevice.connectionAttempts, equals(1));
      });

      test('should attempt reconnection when matching device is found and fail', () async {
        // Save HRM device
        await serviceWithMocks.saveLastConnectedDevice(
          deviceType: BTDeviceServiceType.hrm,
          deviceId: '00:11:22:33:44:55',
          deviceName: 'Test HRM',
        );

        // Create scan result with matching device
        final mockDevice = MockBluetoothDevice('00:11:22:33:44:55');
        final scanResults = [MockScanResult(mockDevice)];

        // Configure mock to fail connection
        mockHrmDevice.shouldConnectSuccessfully = false;
        
        final results = await serviceWithMocks.attemptAutoReconnections(scanResults);
        
        expect(results, hasLength(1));
        expect(results[0].deviceType, equals(BTDeviceServiceType.hrm));
        expect(results[0].deviceName, equals('Test HRM'));
        expect(results[0].success, isFalse);
        expect(mockHrmDevice.connectionAttempts, equals(1));
      });

      test('should not attempt reconnection twice for same device', () async {
        // Save HRM device
        await serviceWithMocks.saveLastConnectedDevice(
          deviceType: BTDeviceServiceType.hrm,
          deviceId: '00:11:22:33:44:55',
          deviceName: 'Test HRM',
        );

        final mockDevice = MockBluetoothDevice('00:11:22:33:44:55');
        final scanResults = [MockScanResult(mockDevice)];

        mockHrmDevice.shouldConnectSuccessfully = true;
        
        // First attempt
        final results1 = await serviceWithMocks.attemptAutoReconnections(scanResults);
        expect(results1, hasLength(1));
        expect(mockHrmDevice.connectionAttempts, equals(1));
        
        // Second attempt should skip the device (already attempted)
        final results2 = await serviceWithMocks.attemptAutoReconnections(scanResults);
        expect(results2, isEmpty);
        expect(mockHrmDevice.connectionAttempts, equals(1)); // No additional attempt
      });

      test('should allow reconnection after reset tracking', () async {
        // Save HRM device
        await serviceWithMocks.saveLastConnectedDevice(
          deviceType: BTDeviceServiceType.hrm,
          deviceId: '00:11:22:33:44:55',
          deviceName: 'Test HRM',
        );

        final mockDevice = MockBluetoothDevice('00:11:22:33:44:55');
        final scanResults = [MockScanResult(mockDevice)];

        mockHrmDevice.shouldConnectSuccessfully = true;
        
        // First attempt
        final results1 = await serviceWithMocks.attemptAutoReconnections(scanResults);
        expect(results1, hasLength(1));
        expect(mockHrmDevice.connectionAttempts, equals(1));
        
        // Reset tracking
        serviceWithMocks.resetReconnectionTracking();
        
        // Should attempt again after reset
        final results2 = await serviceWithMocks.attemptAutoReconnections(scanResults);
        expect(results2, hasLength(1));
        expect(mockHrmDevice.connectionAttempts, equals(2)); // Second attempt
      });

      test('should handle multiple devices of different types', () async {
        // Save HRM and Cadence devices
        await serviceWithMocks.saveLastConnectedDevice(
          deviceType: BTDeviceServiceType.hrm,
          deviceId: '00:11:22:33:44:55',
          deviceName: 'Test HRM',
        );
        
        await serviceWithMocks.saveLastConnectedDevice(
          deviceType: BTDeviceServiceType.cadence,
          deviceId: 'AA:BB:CC:DD:EE:FF',
          deviceName: 'Test Cadence',
        );

        // Create scan results with both devices
        final hrmDevice = MockBluetoothDevice('00:11:22:33:44:55');
        final cadenceDevice = MockBluetoothDevice('AA:BB:CC:DD:EE:FF');
        final scanResults = [
          MockScanResult(hrmDevice),
          MockScanResult(cadenceDevice),
        ];

        mockHrmDevice.shouldConnectSuccessfully = true;
        mockCadenceDevice.shouldConnectSuccessfully = true;
        
        final results = await serviceWithMocks.attemptAutoReconnections(scanResults);
        
        expect(results, hasLength(2));
        expect(mockHrmDevice.connectionAttempts, equals(1));
        expect(mockCadenceDevice.connectionAttempts, equals(1));
        
        // Verify HRM result
        final hrmResult = results.firstWhere((r) => r.deviceType == BTDeviceServiceType.hrm);
        expect(hrmResult.deviceName, equals('Test HRM'));
        expect(hrmResult.success, isTrue);
        
        // Verify Cadence result
        final cadenceResult = results.firstWhere((r) => r.deviceType == BTDeviceServiceType.cadence);
        expect(cadenceResult.deviceName, equals('Test Cadence'));
        expect(cadenceResult.success, isTrue);
      });

      test('should handle mixed success and failure for multiple devices', () async {
        // Save HRM and Cadence devices
        await serviceWithMocks.saveLastConnectedDevice(
          deviceType: BTDeviceServiceType.hrm,
          deviceId: '00:11:22:33:44:55',
          deviceName: 'Test HRM',
        );
        
        await serviceWithMocks.saveLastConnectedDevice(
          deviceType: BTDeviceServiceType.cadence,
          deviceId: 'AA:BB:CC:DD:EE:FF',
          deviceName: 'Test Cadence',
        );

        final hrmDevice = MockBluetoothDevice('00:11:22:33:44:55');
        final cadenceDevice = MockBluetoothDevice('AA:BB:CC:DD:EE:FF');
        final scanResults = [
          MockScanResult(hrmDevice),
          MockScanResult(cadenceDevice),
        ];

        // HRM succeeds, Cadence fails
        mockHrmDevice.shouldConnectSuccessfully = true;
        mockCadenceDevice.shouldConnectSuccessfully = false;
        
        final results = await serviceWithMocks.attemptAutoReconnections(scanResults);
        
        expect(results, hasLength(2));
        
        final hrmResult = results.firstWhere((r) => r.deviceType == BTDeviceServiceType.hrm);
        expect(hrmResult.success, isTrue);
        
        final cadenceResult = results.firstWhere((r) => r.deviceType == BTDeviceServiceType.cadence);
        expect(cadenceResult.success, isFalse);
      });
    });
  });
}

// Mock classes for testing auto-reconnection

class MockBluetoothDevice extends BluetoothDevice {
  final String deviceId;
  
  MockBluetoothDevice(this.deviceId) 
      : super(remoteId: DeviceIdentifier(deviceId));
  
  @override
  String get platformName => 'Mock Device $deviceId';
}

class MockScanResult extends ScanResult {
  MockScanResult(BluetoothDevice device) : super(
    device: device,
    advertisementData: AdvertisementData(
      advName: 'Mock Device',
      connectable: true,
      manufacturerData: {},
      serviceData: {},
      serviceUuids: [],
      txPowerLevel: null,
      appearance: null,
    ),
    rssi: -50,
    timeStamp: DateTime.now(),
  );
}

class MockBTDevice extends BTDevice {
  final String typeName;
  bool shouldConnectSuccessfully = true;
  int connectionAttempts = 0;

  MockBTDevice(this.typeName);

  @override
  String get deviceTypeName => typeName;

  @override
  int get listPriority => 1;

  @override
  Widget? getDeviceIcon(BuildContext context) => const Icon(Icons.device_unknown);

  @override
  bool isDeviceOfThisType(BluetoothDevice device, List<ScanResult> scanResults) {
    // Match based on device type name and device ID pattern
    if (typeName == 'HRM') {
      return device.remoteId.str.startsWith('00:11:22');
    } else if (typeName == 'Cadence') {
      return device.remoteId.str.startsWith('AA:BB:CC');
    } else if (typeName == 'FTMS') {
      return device.remoteId.str.startsWith('FF:EE:DD');
    }
    return false;
  }

  @override
  Future<bool> performConnection(BluetoothDevice device) async {
    connectionAttempts++;
    return shouldConnectSuccessfully;
  }

  @override
  Future<bool> connectToDevice(BluetoothDevice device) async {
    // Override to avoid base class _setConnected logic that tries to save to SharedPreferences
    connectionAttempts++;
    return shouldConnectSuccessfully;
  }

  @override
  Future<void> performDisconnection(BluetoothDevice device) async {
    // No-op for testing
  }

  @override
  Widget? getDevicePage(BluetoothDevice device) => null;

  @override
  void Function(BuildContext context, BluetoothDevice device)? getNavigationCallback() => null;
}

class MockFlutterBluePlusFacade implements FlutterBluePlusFacade {
  final StreamController<BluetoothAdapterState> _adapterStateController = 
      StreamController<BluetoothAdapterState>.broadcast();
  
  @override
  Stream<BluetoothAdapterState> get adapterState => _adapterStateController.stream;
  
  @override
  List<BluetoothDevice> get connectedDevices => [];
}

class MockFtmsFacade implements FtmsFacade {
  @override
  Future<bool> isBluetoothDeviceFTMSDevice(BluetoothDevice device) async => false;
}
