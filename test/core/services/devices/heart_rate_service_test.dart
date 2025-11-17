import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:ftms/core/services/devices/heart_rate_service.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

// Generate mocks for BluetoothDevice, BluetoothService, BluetoothCharacteristic
@GenerateNiceMocks([
  MockSpec<BluetoothDevice>(),
  MockSpec<BluetoothService>(),
  MockSpec<BluetoothCharacteristic>(),
  MockSpec<StreamSubscription<List<int>>>(),
])
import 'heart_rate_service_test.mocks.dart';

void main() {
  group('HeartRateService', () {
    late HeartRateService heartRateService;
    late MockBluetoothDevice mockDevice;
    late MockBluetoothService mockHeartRateService;
    late MockBluetoothCharacteristic mockCharacteristic;
    late StreamController<List<int>> characteristicValueController;
    late StreamController<BluetoothConnectionState> connectionStateController;

    setUp(() {
      // Create a fresh instance for each test
      heartRateService = HeartRateService();

      // Set up mock device
      mockDevice = MockBluetoothDevice();
      when(mockDevice.platformName).thenReturn('Mock HRM Device');

      // Set up mock service
      mockHeartRateService = MockBluetoothService();
      when(mockHeartRateService.uuid).thenReturn(Guid(HeartRateService.heartRateServiceUuid));

      // Set up mock characteristic
      mockCharacteristic = MockBluetoothCharacteristic();
      when(mockCharacteristic.uuid).thenReturn(Guid(HeartRateService.heartRateMeasurementCharacteristicUuid));

      // Set up controllers for streams
      characteristicValueController = StreamController<List<int>>.broadcast();
      connectionStateController = StreamController<BluetoothConnectionState>.broadcast();

      // Connect the mock streams
      when(mockCharacteristic.lastValueStream).thenAnswer((_) => characteristicValueController.stream);
      when(mockDevice.connectionState).thenAnswer((_) => connectionStateController.stream);

      // Configure device.connect to return successfully (with autoConnect parameters)
      when(mockDevice.connect(autoConnect: true, mtu: null, license: License.free)).thenAnswer((_) async {});
      
      // Mock device.isConnected to return true so we don't wait for connection state
      when(mockDevice.isConnected).thenReturn(true);

      // Configure device.disconnect to return successfully
      when(mockDevice.disconnect()).thenAnswer((_) async {});

      // Set up service discovery
      when(mockDevice.discoverServices()).thenAnswer((_) async => [mockHeartRateService]);

      // Set up characteristic in service
      when(mockHeartRateService.characteristics).thenReturn([mockCharacteristic]);

      // Set up characteristic notification - fix return value to be Future<bool>
      when(mockCharacteristic.setNotifyValue(any)).thenAnswer((_) async => true);
    });

    tearDown(() {
      characteristicValueController.close();
      connectionStateController.close();
    });

    test('should emit heart rate values when characteristic updates', () async {
      // Set up the expected values to test
      final expectedHeartRates = [72, 75, 80, 85];

      // Connect our service to the mock device
      final connected = await heartRateService.connectToHrmDevice(mockDevice);
      expect(connected, isTrue);

      // Verify heart rate stream is working by listening to it
      final heartRateValues = <int?>[];
      final subscription = heartRateService.heartRateStream.listen(heartRateValues.add);

      // Emit each heart rate value in 8-bit format (flags = 0, followed by heart rate)
      for (final heartRate in expectedHeartRates) {
        characteristicValueController.add([0x00, heartRate]);
        await Future.delayed(Duration(milliseconds: 10)); // Small delay to ensure processing
      }

      // Wait a bit to ensure all values are processed
      await Future.delayed(Duration(milliseconds: 100));

      // Verify received values match expected values
      expect(heartRateValues, expectedHeartRates);

      // Clean up
      await subscription.cancel();
      await heartRateService.disconnectHrmDevice();
    });

    test('should emit 16-bit heart rate values correctly', () async {
      // Connect our service to the mock device
      final connected = await heartRateService.connectToHrmDevice(mockDevice);
      expect(connected, isTrue);

      // Verify heart rate stream is working by listening to it
      final heartRateValues = <int?>[];
      final subscription = heartRateService.heartRateStream.listen(heartRateValues.add);

      // Use a valid 16-bit heart rate value (185 bpm)
      // In little-endian format:
      // First byte (LSB): 0xB9 = 185
      // Second byte (MSB): 0x00 = 0
      characteristicValueController.add([0x01, 0xB9, 0x00]); // 16-bit value with flag (0x01)
      await Future.delayed(Duration(milliseconds: 50));

      // Wait a bit to ensure values are processed
      await Future.delayed(Duration(milliseconds: 100));

      // Verify the expected value was received
      expect(heartRateValues.last, 185);

      // Clean up
      await subscription.cancel();
      await heartRateService.disconnectHrmDevice();
    });

    test('should emit null when device disconnects', () async {
      // Connect our service to the mock device
      final connected = await heartRateService.connectToHrmDevice(mockDevice);
      expect(connected, isTrue);

      // Verify heart rate stream is working by listening to it
      final heartRateValues = <int?>[];
      final subscription = heartRateService.heartRateStream.listen(heartRateValues.add);

      // Emit one heart rate value
      characteristicValueController.add([0x00, 72]); // 8-bit heart rate
      await Future.delayed(Duration(milliseconds: 50));

      // Simulate disconnection
      connectionStateController.add(BluetoothConnectionState.disconnected);
      await Future.delayed(Duration(milliseconds: 50));

      // Check that the last value is null
      expect(heartRateValues, contains(null));

      // Clean up
      await subscription.cancel();
    });

    test('should filter out invalid heart rate values', () async {
      // Connect our service to the mock device
      final connected = await heartRateService.connectToHrmDevice(mockDevice);
      expect(connected, isTrue);

      // Verify heart rate stream is working by listening to it
      final heartRateValues = <int?>[];
      final subscription = heartRateService.heartRateStream.listen(heartRateValues.add);

      // Valid heart rate
      characteristicValueController.add([0x00, 75]);
      await Future.delayed(Duration(milliseconds: 10));

      // Invalid heart rates (outside the valid range of 0-250 bpm)
      characteristicValueController.add([0x00, 0]);
      characteristicValueController.add([0x00, 251]);
      await Future.delayed(Duration(milliseconds: 50));

      // Should only have the valid value
      expect(heartRateValues, [75]);

      // Clean up
      await subscription.cancel();
      await heartRateService.disconnectHrmDevice();
    });
  });
}
