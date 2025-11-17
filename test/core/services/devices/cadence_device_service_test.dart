import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:ftms/core/services/devices/cadence.dart';

void main() {
  group('CadenceDeviceService', () {
    late Cadence cadenceBtDevice;
    late MockBluetoothDevice mockDevice;
    late MockBuildContext mockContext;
    late List<ScanResult> mockScanResults;

    setUp(() {
      cadenceBtDevice = Cadence();
      mockDevice = MockBluetoothDevice();
      mockContext = MockBuildContext();
      mockScanResults = <ScanResult>[MockScanResult(mockDevice)];
    });

    test('should be a singleton', () {
      final service1 = Cadence();
      final service2 = Cadence();
      expect(service1, same(service2));
    });

    test('should return correct device type name', () {
      expect(cadenceBtDevice.deviceTypeName, equals('Cadence'));
    });

    test('should return correct list priority', () {
      expect(cadenceBtDevice.listPriority, equals(15));
    });

    test('should return pedal bike icon', () {
      final icon = cadenceBtDevice.getDeviceIcon(mockContext);
      expect(icon, isA<Icon>());
      
      final iconWidget = icon as Icon;
      expect(iconWidget.icon, equals(Icons.pedal_bike));
      expect(iconWidget.color, equals(Colors.orange));
      expect(iconWidget.size, equals(16));
    });

    group('isDeviceOfThisType', () {
      test('should identify cadence device with cadenceBtDevice UUID', () {
        final cadenceScanResults = <ScanResult>[
          MockScanResult(mockDevice, serviceUuids: ['1816']) // Cadence service UUID
        ];
        
        final isCadenceDevice = cadenceBtDevice.isDeviceOfThisType(mockDevice, cadenceScanResults);
        expect(isCadenceDevice, isTrue);
      });

      test('should not identify device without cadence cadenceBtDevice UUID', () {
        final nonCadenceScanResults = <ScanResult>[
          MockScanResult(mockDevice, serviceUuids: ['180d']) // HRM service UUID
        ];
        
        final isCadenceDevice = cadenceBtDevice.isDeviceOfThisType(mockDevice, nonCadenceScanResults);
        expect(isCadenceDevice, isFalse);
      });

      test('should handle empty cadenceBtDevice UUIDs', () {
        final emptyScanResults = <ScanResult>[
          MockScanResult(mockDevice, serviceUuids: [])
        ];
        
        final isCadenceDevice = cadenceBtDevice.isDeviceOfThisType(mockDevice, emptyScanResults);
        expect(isCadenceDevice, isFalse);
      });

      test('should handle missing scan result for device', () {
        final differentDevice = MockBluetoothDevice(id: '11:11:11:11:11:11');
        
        final isCadenceDevice = cadenceBtDevice.isDeviceOfThisType(differentDevice, mockScanResults);
        expect(isCadenceDevice, isFalse);
      });

      test('should be case insensitive for UUID matching', () {
        final cadenceScanResults = <ScanResult>[
          MockScanResult(mockDevice, serviceUuids: ['1816']) // lowercase
        ];
        
        final isCadenceDevice = cadenceBtDevice.isDeviceOfThisType(mockDevice, cadenceScanResults);
        expect(isCadenceDevice, isTrue);
      });

      test('should match partial UUID in longer string', () {
        final cadenceScanResults = <ScanResult>[
          MockScanResult(mockDevice, serviceUuids: ['00001816-0000-1000-8000-00805f9b34fb'])
        ];
        
        final isCadenceDevice = cadenceBtDevice.isDeviceOfThisType(mockDevice, cadenceScanResults);
        expect(isCadenceDevice, isTrue);
      });
    });

    test('should handle connection failure gracefully', () async {
      final failingDevice = FailingMockBluetoothDevice();
      final result = await cadenceBtDevice.connectToDevice(failingDevice);
      expect(result, isFalse);
    });

    test('should disconnect from cadence device', () async {
      await expectLater(
        cadenceBtDevice.disconnectFromDevice(mockDevice),
        completes,
      );
    });

    test('should return null for device page', () {
      final page = cadenceBtDevice.getDevicePage(mockDevice);
      expect(page, isNull);
    });

    test('should return empty actions list', () {
      final actions = cadenceBtDevice.getConnectedActions(mockDevice, mockContext);
      expect(actions, isEmpty);
    });

    test('should return null navigation callback', () {
      final callback = cadenceBtDevice.getNavigationCallback();
      expect(callback, isNull);
    });
  });
}

class MockBluetoothDevice extends BluetoothDevice {
  MockBluetoothDevice({String id = '00:00:00:00:00:00'}) 
      : super(remoteId: DeviceIdentifier(id));

  @override
  Future<void> connect({
    Duration timeout = const Duration(seconds: 35),
    int? mtu = 512,
    bool autoConnect = false,
    license = License.free
  }) async {
    // Simulate successful connection
    return;
  }

  @override
  Future<void> disconnect({
    int timeout = 35,
    bool queue = true,
    int androidDelay = 2000,
  }) async {
    // Simulate successful disconnection
    return;
  }
}

class FailingMockBluetoothDevice extends BluetoothDevice {
  FailingMockBluetoothDevice() : super(remoteId: const DeviceIdentifier('ff:ff:ff:ff:ff:ff'));

  @override
  Future<void> connect({
    Duration timeout = const Duration(seconds: 35),
    int? mtu = 512,
    bool autoConnect = false,
    license = License.free
  }) async {
    throw Exception('Connection failed');
  }

  @override
  Future<void> disconnect({
    int timeout = 35,
    bool queue = true,
    int androidDelay = 2000,
  }) async {
    throw Exception('Disconnection failed');
  }
}

class MockBuildContext extends BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class MockScanResult extends ScanResult {
  MockScanResult(
    BluetoothDevice device, {
    List<String> serviceUuids = const [],
  }) : super(
    device: device,
    advertisementData: AdvertisementData(
      advName: 'Test Cadence Device',
      connectable: true,
      manufacturerData: {},
      serviceData: {},
      serviceUuids: serviceUuids.map((uuid) => Guid(uuid)).toList(),
      txPowerLevel: null,
      appearance: null,
    ),
    rssi: -50,
    timeStamp: DateTime.now(),
  );
}
