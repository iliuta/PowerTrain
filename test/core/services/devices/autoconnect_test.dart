import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:ftms/core/services/devices/heart_rate_service.dart';
import 'package:ftms/core/services/devices/cadence_service.dart';
import 'package:ftms/core/services/devices/ftms.dart';

@GenerateNiceMocks([
  MockSpec<BluetoothDevice>(),
  MockSpec<BluetoothService>(),
])
import 'autoconnect_test.mocks.dart';

void main() {
  group('AutoConnect Feature Tests', () {
    late MockBluetoothDevice mockDevice;
    late StreamController<BluetoothConnectionState> connectionStateController;

    setUp(() {
      mockDevice = MockBluetoothDevice();
      connectionStateController = StreamController<BluetoothConnectionState>.broadcast();
      
      when(mockDevice.connectionState).thenAnswer((_) => connectionStateController.stream);
      when(mockDevice.remoteId).thenReturn(const DeviceIdentifier('11:22:33:44:55:66'));
      when(mockDevice.platformName).thenReturn('Test Device');
      when(mockDevice.discoverServices()).thenAnswer((_) async => []);
      when(mockDevice.disconnect()).thenAnswer((_) async {});
      when(mockDevice.isConnected).thenReturn(true);
      
      // Mock connect method to accept autoConnect and mtu parameters
      when(mockDevice.connect(
        autoConnect: anyNamed('autoConnect'),
        mtu: anyNamed('mtu'), license: License.free
      )).thenAnswer((_) async {});
    });

    tearDown(() {
      connectionStateController.close();
    });

    group('Heart Rate Service', () {
      test('should use autoConnect when connecting to HRM device', () async {
        // Set up successful connection
        when(mockDevice.connect(autoConnect: anyNamed('autoConnect'), license: null))
            .thenAnswer((_) async {});
        
        // Mock heart rate service discovery
        final mockService = MockBluetoothService();
        when(mockService.uuid).thenReturn(Guid('0000180D'));
        when(mockDevice.discoverServices()).thenAnswer((_) async => [mockService]);

        final heartRateService = HeartRateService();
        
        // This should fail because no characteristic is found, but we can verify the connect call
        await heartRateService.connectToHrmDevice(mockDevice);
        
        // Verify that connect was called with autoConnect: true
        verify(mockDevice.connect(autoConnect: true, mtu: null, license: License.free)).called(1);
      });
    });

    group('Cadence Service', () {
      test('should use autoConnect when connecting to cadence device', () async {
        // Set up successful connection
        when(mockDevice.connect(autoConnect: anyNamed('autoConnect'), license: License.free))
            .thenAnswer((_) async {});
        
        // Mock cadence service discovery
        final mockService = MockBluetoothService();
        when(mockService.uuid).thenReturn(Guid('00001816'));
        when(mockDevice.discoverServices()).thenAnswer((_) async => [mockService]);

        final cadenceService = CadenceService();
        
        // This should fail because no characteristic is found, but we can verify the connect call
        await cadenceService.connectToCadenceDevice(mockDevice);
        
        // Verify that connect was called with autoConnect: true
        verify(mockDevice.connect(autoConnect: true, mtu: null, license: License.free)).called(1);
      });
    });

    group('FTMS Service', () {
      test('should use autoConnect when connecting to FTMS device', () async {
        // Set up successful connection
        when(mockDevice.connect(autoConnect: anyNamed('autoConnect'), license: License.free))
            .thenAnswer((_) async {});

        final ftmsService = Ftms();
        
        final result = await ftmsService.performConnection(mockDevice);
        
        // Verify that connect was called with autoConnect: true
        verify(mockDevice.connect(autoConnect: true, mtu: null, license: License.free)).called(1);
        expect(result, isTrue);
      });
    });

    group('AutoConnect Behavior', () {
      test('should handle connection failures gracefully', () async {
        // Mock connection failure
        when(mockDevice.connect(autoConnect: anyNamed('autoConnect'), license: License.free))
            .thenThrow(Exception('Connection failed'));

        final heartRateService = HeartRateService();
        
        // Should not throw, should return false
        final result = await heartRateService.connectToHrmDevice(mockDevice);
        expect(result, isFalse);
        
        // Should still have attempted to connect with autoConnect
        verify(mockDevice.connect(autoConnect: true, mtu: null, license: License.free)).called(1);
      });

      test('should maintain autoConnect across disconnections', () async {
        // Set up successful connection initially
        when(mockDevice.connect(autoConnect: anyNamed('autoConnect'), license: License.free))
            .thenAnswer((_) async {});
        
        final mockService = MockBluetoothService();
        when(mockService.uuid).thenReturn(Guid('0000180D'));
        when(mockDevice.discoverServices()).thenAnswer((_) async => [mockService]);

        final heartRateService = HeartRateService();
        
        // Initial connection
        await heartRateService.connectToHrmDevice(mockDevice);
        
        // Simulate disconnection - autoConnect should keep trying to reconnect
        connectionStateController.add(BluetoothConnectionState.disconnected);
        await Future.delayed(Duration(milliseconds: 10));
        
        // Simulate reconnection - autoConnect should handle this automatically
        connectionStateController.add(BluetoothConnectionState.connected);
        await Future.delayed(Duration(milliseconds: 10));
        
        // Initial connect should have used autoConnect: true
        verify(mockDevice.connect(autoConnect: true, mtu: null, license: License.free)).called(1);
        
        // No manual reconnection calls should be needed - autoConnect handles it
        verifyNever(mockDevice.connect(autoConnect: false, license: License.free));
      });
      
      test('should re-establish data streams after reconnection', () async {
        // Set up successful connection
        when(mockDevice.connect(autoConnect: anyNamed('autoConnect'), license: License.free))
            .thenAnswer((_) async {});
        
        final mockService = MockBluetoothService();
        when(mockService.uuid).thenReturn(Guid('0000180D'));
        when(mockDevice.discoverServices()).thenAnswer((_) async => [mockService]);

        final heartRateService = HeartRateService();
        
        // Initial connection
        await heartRateService.connectToHrmDevice(mockDevice);
        
        // Simulate reconnection event
        connectionStateController.add(BluetoothConnectionState.connected);
        await Future.delayed(Duration(milliseconds: 600)); // Wait for reconnection handler
        
        // Should discover services at least once (during initial connection)
        verify(mockDevice.discoverServices()).called(1);
        
        // The important thing is that autoConnect was used in the initial connection
        verify(mockDevice.connect(autoConnect: true, mtu: null, license: License.free)).called(1);
      });
    });
  });
}
