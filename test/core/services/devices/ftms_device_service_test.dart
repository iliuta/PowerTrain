import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:ftms/core/services/devices/ftms.dart';
import 'package:ftms/core/services/devices/bt_device_navigation_registry.dart';
import 'package:ftms/l10n/app_localizations.dart';

void main() {
  group('FtmsDeviceService', () {
    late Ftms ftmsBtDevice;
    late MockBluetoothDevice mockDevice;
    late MockBuildContext mockContext;
    late BTDeviceNavigationRegistry registry;

    setUp(() {
      ftmsBtDevice = Ftms();
      mockDevice = MockBluetoothDevice();
      mockContext = MockBuildContext();
      registry = BTDeviceNavigationRegistry();
      registry.clear();
    });

    tearDown(() {
      registry.clear();
    });

    test('should be a singleton', () {
      final service1 = Ftms();
      final service2 = Ftms();
      expect(service1, same(service2));
    });

    test('should return correct device type name', () {
      expect(ftmsBtDevice.deviceTypeName, equals('FTMS'));
    });

    test('should return correct list priority', () {
      expect(ftmsBtDevice.listPriority, equals(5));
    });

    test('should return fitness center icon', () {
      final icon = ftmsBtDevice.getDeviceIcon(mockContext);
      expect(icon, isA<Icon>());
      
      final iconWidget = icon as Icon;
      expect(iconWidget.icon, equals(Icons.fitness_center));
      expect(iconWidget.color, equals(Colors.blue));
      expect(iconWidget.size, equals(16));
    });

    group('isDeviceOfThisType', () {
      test('should identify FTMS device with ftmsBtDevice UUID', () {
        final ftmsScanResults = <ScanResult>[
          MockScanResult(mockDevice, serviceUuids: ['1826']) // FTMS service UUID
        ];
        
        final isFtmsDevice = ftmsBtDevice.isDeviceOfThisType(mockDevice, ftmsScanResults);
        expect(isFtmsDevice, isTrue);
      });

      test('should not identify device without FTMS ftmsBtDevice UUID', () {
        final nonFtmsScanResults = <ScanResult>[
          MockScanResult(mockDevice, serviceUuids: ['180d']) // HRM service UUID
        ];
        
        final isFtmsDevice = ftmsBtDevice.isDeviceOfThisType(mockDevice, nonFtmsScanResults);
        expect(isFtmsDevice, isFalse);
      });

      test('should handle empty ftmsBtDevice UUIDs', () {
        final emptyScanResults = <ScanResult>[
          MockScanResult(mockDevice, serviceUuids: [])
        ];
        
        final isFtmsDevice = ftmsBtDevice.isDeviceOfThisType(mockDevice, emptyScanResults);
        expect(isFtmsDevice, isFalse);
      });

      test('should handle missing scan result for device', () {
        final differentDevice = MockBluetoothDevice(id: '11:11:11:11:11:11');
        final scanResultsWithoutTargetDevice = <ScanResult>[MockScanResult(mockDevice)];
        
        final isFtmsDevice = ftmsBtDevice.isDeviceOfThisType(differentDevice, scanResultsWithoutTargetDevice);
        expect(isFtmsDevice, isFalse);
      });

      test('should be case insensitive for UUID matching', () {
        final ftmsScanResults = <ScanResult>[
          MockScanResult(mockDevice, serviceUuids: ['1826']) // lowercase
        ];
        
        final isFtmsDevice = ftmsBtDevice.isDeviceOfThisType(mockDevice, ftmsScanResults);
        expect(isFtmsDevice, isTrue);
      });
    });

    test('should return null for device page', () {
      final page = ftmsBtDevice.getDevicePage(mockDevice);
      expect(page, isNull);
    });

    test('should return navigation callback when registered', () {
      bool callbackCalled = false;
      void testCallback(BuildContext context, BluetoothDevice device) {
        callbackCalled = true;
      }

      registry.registerNavigation('FTMS', testCallback);
      
      final callback = ftmsBtDevice.getNavigationCallback();
      expect(callback, isNotNull);
      
      callback!(mockContext, mockDevice);
      expect(callbackCalled, isTrue);
    });

    test('should return null navigation callback when not registered', () {
      final callback = ftmsBtDevice.getNavigationCallback();
      expect(callback, isNull);
    });

    group('getConnectedActions', () {
      testWidgets('should return Open button when navigation callback is available', (WidgetTester tester) async {
        void testCallback(BuildContext context, BluetoothDevice device) {}
        registry.registerNavigation('FTMS', testCallback);

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) {
                final actions = ftmsBtDevice.getConnectedActions(mockDevice, context);
                expect(actions, hasLength(1));
                expect(actions.first, isA<ElevatedButton>());
                return Container();
              },
            ),
          ),
        );
      });

      testWidgets('should return empty list when no navigation callback available', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) {
                final actions = ftmsBtDevice.getConnectedActions(mockDevice, context);
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

class MockBluetoothDevice extends BluetoothDevice {
  MockBluetoothDevice({String id = '00:00:00:00:00:00'}) 
      : super(remoteId: DeviceIdentifier(id));
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
      advName: 'Test FTMS Device',
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
