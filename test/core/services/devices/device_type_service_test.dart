import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:ftms/core/services/devices/bt_device.dart';
import 'package:ftms/core/services/devices/bt_device_manager.dart';
import 'package:ftms/l10n/app_localizations.dart';
import 'dart:async';

void main() {
  group('DeviceTypeService', () {
    late TestDeviceTypeService service;
    late MockBluetoothDevice mockDevice;
    late MockBuildContext mockContext;
    late SupportedBTDeviceManager deviceManager;

    setUp(() {
      service = TestDeviceTypeService();
      mockDevice = MockBluetoothDevice();
      mockContext = MockBuildContext();
      deviceManager = SupportedBTDeviceManager();
      
      // Set up the device manager reference
      service.setDeviceManager(deviceManager);
    });

    test('should return correct device type name', () {
      expect(service.deviceTypeName, equals('Test Device'));
    });

    test('should return correct list priority', () {
      expect(service.listPriority, equals(100));
    });

    test('should return device icon', () {
      final icon = service.getDeviceIcon(mockContext);
      expect(icon, isA<Icon>());
    });

    test('should identify device type correctly', () {
      final scanResults = [MockScanResult(mockDevice)];
      final isCorrectType = service.isDeviceOfThisType(mockDevice, scanResults);
      expect(isCorrectType, isTrue);
    });

    test('should connect to device successfully', () async {
      final result = await service.connectToDevice(mockDevice);
      expect(result, isTrue);
      expect(service.lastConnectedDevice, equals(mockDevice));
    });

    test('should disconnect from device', () async {
      await service.disconnectFromDevice(mockDevice);
      expect(service.lastDisconnectedDevice, equals(mockDevice));
    });

    test('should return device page', () {
      final page = service.getDevicePage(mockDevice);
      expect(page, isA<Container>());
    });

    test('should return null navigation callback by default', () {
      final callback = service.getNavigationCallback();
      expect(callback, isNull);
    });

    group('getConnectedActions', () {
      testWidgets('should return Open button when device page is available', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) {
                final actions = service.getConnectedActions(mockDevice, context);
                expect(actions, hasLength(1));
                expect(actions.first, isA<ElevatedButton>());
                return Container();
              },
            ),
          ),
        );
      });

      testWidgets('should return Open button when navigation callback is available', (WidgetTester tester) async {
        service.hasNavigationCallback = true;
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) {
                final actions = service.getConnectedActions(mockDevice, context);
                expect(actions, hasLength(1));
                expect(actions.first, isA<ElevatedButton>());
                return Container();
              },
            ),
          ),
        );
      });

      testWidgets('should prioritize device page over navigation callback', (WidgetTester tester) async {
        service.hasNavigationCallback = true;
        service.hasDevicePage = true;
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) {
                final actions = service.getConnectedActions(mockDevice, context);
                expect(actions, hasLength(1));
                // Should use device page, not navigation callback
                expect(service.getDevicePageCalled, isTrue);
                return Container();
              },
            ),
          ),
        );
      });

      testWidgets('should return empty list when no page or callback available', (WidgetTester tester) async {
        service.hasDevicePage = false;
        service.hasNavigationCallback = false;
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) {
                final actions = service.getConnectedActions(mockDevice, context);
                expect(actions, isEmpty);
                return Container();
              },
            ),
          ),
        );
      });
    });
  });
}

class TestDeviceTypeService extends BTDevice {
  BluetoothDevice? lastConnectedDevice;
  BluetoothDevice? lastDisconnectedDevice;
  bool hasDevicePage = true;
  bool hasNavigationCallback = false;
  bool getDevicePageCalled = false;

  @override
  String get deviceTypeName => 'Test Device';

  @override
  int get listPriority => 100;

  @override
  Widget? getDeviceIcon(BuildContext context) {
    return const Icon(Icons.device_unknown);
  }

  @override
  bool isDeviceOfThisType(BluetoothDevice device, List<ScanResult> scanResults) {
    return true; // Always return true for testing
  }

  @override
  Future<bool> performConnection(BluetoothDevice device) async {
    lastConnectedDevice = device;
    return true;
  }

  @override
  Future<void> performDisconnection(BluetoothDevice device) async {
    lastDisconnectedDevice = device;
  }

  @override
  Widget? getDevicePage(BluetoothDevice device) {
    getDevicePageCalled = true;
    return hasDevicePage ? Container() : null;
  }

  @override
  void Function(BuildContext context, BluetoothDevice device)? getNavigationCallback() {
    return hasNavigationCallback 
        ? (context, device) {} 
        : null;
  }
}

class MockBluetoothDevice extends BluetoothDevice {
  MockBluetoothDevice() : super(remoteId: const DeviceIdentifier('00:00:00:00:00:00'));
  
  // Mock connection state stream controller
  final StreamController<BluetoothConnectionState> _connectionStateController = 
      StreamController<BluetoothConnectionState>.broadcast();
  
  @override
  Stream<BluetoothConnectionState> get connectionState => _connectionStateController.stream;
  
  @override
  String get platformName => 'Test Device';
  
  // Method to simulate connection state changes in tests
  void simulateConnectionState(BluetoothConnectionState state) {
    _connectionStateController.add(state);
  }
  
  void dispose() {
    _connectionStateController.close();
  }
}

class MockBuildContext extends BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class MockScanResult extends ScanResult {
  MockScanResult(BluetoothDevice device) : super(
    device: device,
    advertisementData: AdvertisementData(
      advName: 'Test Device',
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
