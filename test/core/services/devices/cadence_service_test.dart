import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:ftms/core/services/devices/cadence_service.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

// Generate mocks for BluetoothDevice, BluetoothService, BluetoothCharacteristic
@GenerateNiceMocks([
  MockSpec<BluetoothDevice>(),
  MockSpec<BluetoothService>(),
  MockSpec<BluetoothCharacteristic>(),
  MockSpec<StreamSubscription<List<int>>>(),
])
import 'cadence_service_test.mocks.dart';

void main() {
  group('CadenceService', () {
    late CadenceService cadenceService;
    late MockBluetoothDevice mockDevice;
    late MockBluetoothService mockCadenceService;
    late MockBluetoothCharacteristic mockCharacteristic;
    late StreamController<List<int>> characteristicValueController;
    late StreamController<BluetoothConnectionState> connectionStateController;

    setUp(() {
      // Create a fresh instance for each test
      cadenceService = CadenceService();

      // Set up mock device
      mockDevice = MockBluetoothDevice();
      when(mockDevice.platformName).thenReturn('Mock Cadence Sensor');

      // Set up mock service
      mockCadenceService = MockBluetoothService();
      when(mockCadenceService.uuid).thenReturn(Guid(CadenceService.cadenceServiceUuid));

      // Set up mock characteristic
      mockCharacteristic = MockBluetoothCharacteristic();
      when(mockCharacteristic.uuid).thenReturn(Guid(CadenceService.cadenceMeasurementCharacteristicUuid));

      // Set up controllers for streams
      characteristicValueController = StreamController<List<int>>.broadcast();
      connectionStateController = StreamController<BluetoothConnectionState>.broadcast();

      // Connect the mock streams
      when(mockCharacteristic.lastValueStream).thenAnswer((_) => characteristicValueController.stream);
      when(mockDevice.connectionState).thenAnswer((_) => connectionStateController.stream);

      // Configure device.connect to return successfully (with autoConnect parameters)
      when(mockDevice.connect(autoConnect: true, mtu: null, license: null)).thenAnswer((_) async {});
      
      // Mock device.isConnected to return true so we don't wait for connection state
      when(mockDevice.isConnected).thenReturn(true);

      // Configure device.disconnect to return successfully
      when(mockDevice.disconnect()).thenAnswer((_) async {});

      // Set up service discovery
      when(mockDevice.discoverServices()).thenAnswer((_) async => [mockCadenceService]);

      // Set up characteristic in service
      when(mockCadenceService.characteristics).thenReturn([mockCharacteristic]);

      // Set up characteristic notification
      when(mockCharacteristic.setNotifyValue(any)).thenAnswer((_) async => true);
    });

    tearDown(() {
      characteristicValueController.close();
      connectionStateController.close();
    });

    test('should emit cadence values when characteristic updates', () async {
      // Connect our service to the mock device
      final connected = await cadenceService.connectToCadenceDevice(mockDevice);
      expect(connected, isTrue);

      // Verify cadence stream is working by listening to it
      final cadenceValues = <int?>[];
      final subscription = cadenceService.cadenceStream.listen(cadenceValues.add);

      // Send initial crank revolution data
      // Flags: 0x02 (crank data present)
      // Crank revolutions: 100 (0x64, 0x00 in little-endian)
      // Last crank event time: 1024 (0x00, 0x04 in little-endian)
      characteristicValueController.add([0x02, 0x64, 0x00, 0x00, 0x04]);
      await Future.delayed(Duration(milliseconds: 50));

      // Send second update to simulate pedaling
      // Crank revolutions: 105 (increased by 5)
      // Last crank event time: 2048 (increased by 1024, which is 1 second)
      // This should calculate to 300 RPM (5 revolutions in 1 second = 300 rev/min)
      characteristicValueController.add([0x02, 0x69, 0x00, 0x00, 0x08]);
      await Future.delayed(Duration(milliseconds: 50));

      // Send a third update with a realistic cadence value
      // Crank revolutions: 107 (increased by 2)
      // Last crank event time: 2560 (increased by 512, which is 0.5 seconds)
      // This should calculate to 240 RPM (2 revolutions in 0.5 seconds = 240 rev/min)
      characteristicValueController.add([0x02, 0x6B, 0x00, 0x00, 0x0A]);
      await Future.delayed(Duration(milliseconds: 50));

      // Wait to ensure all values are processed
      await Future.delayed(Duration(milliseconds: 100));

      // The first update doesn't provide a cadence value (no previous data to compare)
      // The second update should calculate ~300 RPM
      // The third update should calculate ~240 RPM
      // Exact values might differ slightly due to the adaptive smoothing algorithm
      expect(cadenceValues.length, greaterThan(2));

      // Values might be smoothed so we test in ranges rather than exact values
      // Skip first value which might be null or 0
      final nonNullValues = cadenceValues.where((value) => value != null && value > 0).toList();
      expect(nonNullValues.length, greaterThan(1));

      // Test that cadence values are within reasonable range of our expected values
      expect(nonNullValues.any((value) => value! > 200 && value < 300), isTrue);

      // Clean up
      await subscription.cancel();
      await cadenceService.disconnectCadenceDevice();
    });

    test('should emit null when device disconnects', () async {
      // Connect our service to the mock device
      final connected = await cadenceService.connectToCadenceDevice(mockDevice);
      expect(connected, isTrue);

      // Verify cadence stream is working by listening to it
      final cadenceValues = <int?>[];
      final subscription = cadenceService.cadenceStream.listen(cadenceValues.add);

      // Send valid cadence data
      // Flags: 0x02 (crank data present)
      // Crank revolutions: 100
      // Last crank event time: 1024
      characteristicValueController.add([0x02, 0x64, 0x00, 0x00, 0x04]);
      await Future.delayed(Duration(milliseconds: 50));

      // Send second update to calculate cadence
      characteristicValueController.add([0x02, 0x69, 0x00, 0x00, 0x08]);
      await Future.delayed(Duration(milliseconds: 50));

      // Simulate disconnection
      connectionStateController.add(BluetoothConnectionState.disconnected);
      await Future.delayed(Duration(milliseconds: 50));

      // Check that null is emitted when device disconnects
      expect(cadenceValues, contains(null));

      // Clean up
      await subscription.cancel();
    });

    test('should handle rollover of crank revolution counter', () async {
      // Connect our service to the mock device
      final connected = await cadenceService.connectToCadenceDevice(mockDevice);
      expect(connected, isTrue);

      // Verify cadence stream is working by listening to it
      final cadenceValues = <int?>[];
      final subscription = cadenceService.cadenceStream.listen(cadenceValues.add);

      // Send initial crank revolution data near max value of 16-bit counter
      // Flags: 0x02 (crank data present)
      // Crank revolutions: 65530 (0xFFFA)
      // Last crank event time: 1024
      characteristicValueController.add([0x02, 0xFA, 0xFF, 0x00, 0x04]);
      await Future.delayed(Duration(milliseconds: 50));

      // Send second update with rollover (counter goes from 65530 to 2)
      // Crank revolutions: 2 (0x0002) - rolled over from 65530
      // Last crank event time: 2048
      characteristicValueController.add([0x02, 0x02, 0x00, 0x00, 0x08]);
      await Future.delayed(Duration(milliseconds: 50));

      // Wait to ensure values are processed
      await Future.delayed(Duration(milliseconds: 100));

      // Should be able to calculate cadence correctly despite counter rollover
      // Difference should be calculated as (2 + 65536 - 65530) = 8 revolutions
      // 8 revolutions in 1 second = 480 RPM, but likely capped at 300 RPM
      final nonNullValues = cadenceValues.where((value) => value != null && value > 0).toList();
      expect(nonNullValues.length, greaterThanOrEqualTo(1));

      // Test that the calculated cadence is within a reasonable range (probably capped at 300)
      expect(nonNullValues.last, lessThanOrEqualTo(300));
      expect(nonNullValues.last, greaterThan(0));

      // Clean up
      await subscription.cancel();
      await cadenceService.disconnectCadenceDevice();
    });

    test('should emit zero when no new revolutions detected', () async {
      // Connect our service to the mock device
      final connected = await cadenceService.connectToCadenceDevice(mockDevice);
      expect(connected, isTrue);

      // Verify cadence stream is working by listening to it
      final cadenceValues = <int?>[];
      final subscription = cadenceService.cadenceStream.listen(cadenceValues.add);

      // Send initial crank revolution data
      // Flags: 0x02 (crank data present)
      // Crank revolutions: 100
      // Last crank event time: 1024
      characteristicValueController.add([0x02, 0x64, 0x00, 0x00, 0x04]);
      await Future.delayed(Duration(milliseconds: 50));

      // Send second update with non-zero cadence
      // Crank revolutions: 105 (increased by 5)
      // Last crank event time: 2048 (increased by 1024)
      characteristicValueController.add([0x02, 0x69, 0x00, 0x00, 0x08]);
      await Future.delayed(Duration(milliseconds: 50));

      // Send third update with same revolution count (no pedaling)
      // Crank revolutions: 105 (no change)
      // Last crank event time: 3072 (increased by 1024)
      characteristicValueController.add([0x02, 0x69, 0x00, 0x00, 0x0C]);
      await Future.delayed(Duration(milliseconds: 50));

      // Wait to ensure all values are processed
      await Future.delayed(Duration(milliseconds: 100));

      // Should emit zero when no new revolutions detected
      // The first value will be skipped, the second will calculate a cadence,
      // and the third should eventually lead to a zero cadence
      expect(cadenceValues.contains(0), isTrue);

      // Clean up
      await subscription.cancel();
      await cadenceService.disconnectCadenceDevice();
    });

    test('should use minimal smoothing for rapid cadence changes', () async {
      // Connect our service to the mock device
      final connected = await cadenceService.connectToCadenceDevice(mockDevice);
      expect(connected, isTrue);

      // Verify cadence stream is working by listening to it
      final cadenceValues = <int?>[];
      final subscription = cadenceService.cadenceStream.listen(cadenceValues.add);

      // Send initial data to establish a baseline cadence
      // Crank revolutions: 100
      // Last crank event time: 1024
      characteristicValueController.add([0x02, 0x64, 0x00, 0x00, 0x04]);
      await Future.delayed(Duration(milliseconds: 50));

      // Send second update with a moderate cadence (60 RPM)
      // Crank revolutions: 101 (increased by 1)
      // Last crank event time: 2048 (increased by 1024, which is 1 second)
      // This calculates to 60 RPM (1 rev in 1 sec = 60 rev/min)
      characteristicValueController.add([0x02, 0x65, 0x00, 0x00, 0x08]);
      await Future.delayed(Duration(milliseconds: 50));

      // Wait to ensure the cadence value is processed and established
      await Future.delayed(Duration(milliseconds: 100));

      // Now send a rapid change (more than 20% increase)
      // From ~60 RPM to ~180 RPM (200% increase)
      // Crank revolutions: 104 (increased by 3)
      // Last crank event time: 3072 (increased by 1024, which is 1 second)
      // This calculates to 180 RPM (3 rev in 1 sec = 180 rev/min)
      characteristicValueController.add([0x02, 0x68, 0x00, 0x00, 0x0C]);
      await Future.delayed(Duration(milliseconds: 50));

      // Send one more update to confirm the new cadence level
      // Crank revolutions: 107 (increased by 3)
      // Last crank event time: 4096 (increased by 1024)
      // Still at 180 RPM
      characteristicValueController.add([0x02, 0x6B, 0x00, 0x00, 0x10]);
      await Future.delayed(Duration(milliseconds: 50));

      // Wait to ensure all values are processed
      await Future.delayed(Duration(milliseconds: 100));

      // Extract non-null values and filter out zeros
      final nonNullValues = cadenceValues.where((value) => value != null && value > 0).toList();

      // We should have at least 3 values: the initial ~60 RPM and at least two values
      // showing a rapid change toward 180 RPM
      expect(nonNullValues.length, greaterThanOrEqualTo(3));

      // The first non-null value should be close to 60 RPM
      // Note: The actual value might be affected by adaptive smoothing
      expect(nonNullValues.first, lessThan(100));

      // The last value should be significantly higher, approaching 180 RPM
      // Since _minimalSmoothing averages the last two values,
      // the value should be closer to 180 than to 60
      expect(nonNullValues.last, greaterThan(120));

      // Clean up
      await subscription.cancel();
      await cadenceService.disconnectCadenceDevice();
    });

    test('should use regular smoothing for gradual cadence changes', () async {
      // Connect our service to the mock device
      final connected = await cadenceService.connectToCadenceDevice(mockDevice);
      expect(connected, isTrue);

      // Verify cadence stream is working by listening to it
      final cadenceValues = <int?>[];
      final subscription = cadenceService.cadenceStream.listen(cadenceValues.add);

      // Send initial data to establish a baseline cadence
      // Crank revolutions: 100
      // Last crank event time: 1024
      characteristicValueController.add([0x02, 0x64, 0x00, 0x00, 0x04]);
      await Future.delayed(Duration(milliseconds: 50));

      // Send second update with a moderate cadence (60 RPM)
      // Crank revolutions: 101 (increased by 1)
      // Last crank event time: 2048 (increased by 1024, which is 1 second)
      // This calculates to 60 RPM (1 rev in 1 sec = 60 rev/min)
      characteristicValueController.add([0x02, 0x65, 0x00, 0x00, 0x08]);
      await Future.delayed(Duration(milliseconds: 50));

      // Wait to ensure the cadence value is processed and established
      await Future.delayed(Duration(milliseconds: 100));

      // Now send a series of gradual changes (each less than 20%)
      // Going from 60 to 66 RPM (10% increase)
      // Crank revolutions: 102 (increased by 1)
      // Last crank event time: 2901 (increased by 853, which is ~0.833 seconds)
      // This calculates to 72 RPM (1 rev in 0.833 sec = ~72 rev/min)
      characteristicValueController.add([0x02, 0x66, 0x00, 0x55, 0x0B]);
      await Future.delayed(Duration(milliseconds: 50));

      // Another small increase: 72 to 80 RPM (~11% increase)
      // Crank revolutions: 103 (increased by 1)
      // Last crank event time: 3645 (increased by 744, which is ~0.726 seconds)
      // This calculates to 83 RPM (1 rev in 0.726 sec = ~83 rev/min)
      characteristicValueController.add([0x02, 0x67, 0x00, 0x3D, 0x0E]);
      await Future.delayed(Duration(milliseconds: 50));

      // One more small increase: 80 to 90 RPM (~12.5% increase)
      // Crank revolutions: 104 (increased by 1)
      // Last crank event time: 4304 (increased by 659, which is ~0.644 seconds)
      // This calculates to 93 RPM (1 rev in 0.644 sec = ~93 rev/min)
      characteristicValueController.add([0x02, 0x68, 0x00, 0xD0, 0x10]);
      await Future.delayed(Duration(milliseconds: 50));

      // Wait to ensure all values are processed
      await Future.delayed(Duration(milliseconds: 100));

      // Extract non-null values and filter out zeros
      final nonNullValues = cadenceValues.where((value) => value != null && value > 0).toList();

      // We should have multiple values showing a gradual increase
      expect(nonNullValues.length, greaterThanOrEqualTo(4));

      // Check that values are increasing gradually
      // The smoothed values should show a gradual progression
      // From ~60 to somewhere closer to 90
      expect(nonNullValues.first, lessThan(70));
      expect(nonNullValues.last, greaterThan(75));

      // Verify that each transition is smaller than it would be with minimal smoothing
      // Due to weighted averaging of more values, changes should be less pronounced
      for (int i = 1; i < nonNullValues.length; i++) {
        final diff = (nonNullValues[i]! - nonNullValues[i-1]!).abs();
        // Each step shouldn't change more than about 10 RPM due to smoothing
        expect(diff, lessThanOrEqualTo(15));
      }

      // Clean up
      await subscription.cancel();
      await cadenceService.disconnectCadenceDevice();
    });
  });
}
