import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:ftms/core/services/devices/bt_device.dart';
import 'package:ftms/core/services/devices/bt_device_manager.dart';

@GenerateNiceMocks([
  MockSpec<BluetoothDevice>(),
  MockSpec<SupportedBTDeviceManager>(),
])
import 'bt_device_test.mocks.dart';

/// Concrete implementation of BTDevice for testing
class TestBTDevice extends BTDevice {
  bool connectionSucceeds = true;
  int connectCalls = 0;
  int disconnectCalls = 0;

  @override
  String get deviceTypeName => 'TestDevice';

  @override
  int get listPriority => 10;

  @override
  Widget? getDeviceIcon(BuildContext context) => null;

  @override
  bool isDeviceOfThisType(BluetoothDevice device, List<ScanResult> scanResults) {
    return true;
  }

  @override
  Future<bool> performConnection(BluetoothDevice device) async {
    connectCalls++;
    return connectionSucceeds;
  }

  @override
  Future<void> performDisconnection(BluetoothDevice device) async {
    disconnectCalls++;
  }

  @override
  Widget? getDevicePage(BluetoothDevice device) => null;
}

void main() {
  group('BTDevice', () {
    late TestBTDevice btDevice;
    late MockBluetoothDevice mockBluetoothDevice;
    late MockSupportedBTDeviceManager mockDeviceManager;
    late StreamController<BluetoothConnectionState> connectionStateController;

    setUp(() {
      btDevice = TestBTDevice();
      mockBluetoothDevice = MockBluetoothDevice();
      mockDeviceManager = MockSupportedBTDeviceManager();

      connectionStateController = StreamController<BluetoothConnectionState>.broadcast();

      when(mockBluetoothDevice.platformName).thenReturn('Test Device');
      when(mockBluetoothDevice.remoteId).thenReturn(const DeviceIdentifier('11:22:33:44:55:66'));
      when(mockBluetoothDevice.connectionState).thenAnswer((_) => connectionStateController.stream);

      btDevice.setDeviceManager(mockDeviceManager);
    });

    tearDown(() {
      connectionStateController.close();
    });

    group('Connection', () {
      test('connectToDevice should mark device as connected on success', () async {
        btDevice.connectionSucceeds = true;

        final result = await btDevice.connectToDevice(mockBluetoothDevice);

        expect(result, isTrue);
        expect(btDevice.isConnected, isTrue);
        expect(btDevice.connectedDevice, equals(mockBluetoothDevice));
        expect(btDevice.connectionState, equals(BluetoothConnectionState.connected));
        expect(btDevice.connectedAt, isNotNull);
      });

      test('connectToDevice should not mark device as connected on failure', () async {
        btDevice.connectionSucceeds = false;

        final result = await btDevice.connectToDevice(mockBluetoothDevice);

        expect(result, isFalse);
        expect(btDevice.isConnected, isFalse);
        expect(btDevice.connectedDevice, isNull);
      });

      test('connectToDevice should add device to manager registry', () async {
        btDevice.connectionSucceeds = true;

        await btDevice.connectToDevice(mockBluetoothDevice);

        verify(mockDeviceManager.addConnectedDevice('11:22:33:44:55:66', btDevice)).called(1);
      });
    });

    group('Disconnection', () {
      test('disconnectFromDevice should mark device as disconnected', () async {
        // First connect
        await btDevice.connectToDevice(mockBluetoothDevice);
        expect(btDevice.isConnected, isTrue);

        // Then disconnect
        await btDevice.disconnectFromDevice(mockBluetoothDevice);

        expect(btDevice.isConnected, isFalse);
        expect(btDevice.connectedDevice, isNull);
        expect(btDevice.connectionState, equals(BluetoothConnectionState.disconnected));
        expect(btDevice.connectedAt, isNull);
      });

      test('disconnectFromDevice should remove device from manager registry', () async {
        await btDevice.connectToDevice(mockBluetoothDevice);
        
        await btDevice.disconnectFromDevice(mockBluetoothDevice);

        verify(mockDeviceManager.removeConnectedDevice('11:22:33:44:55:66')).called(greaterThanOrEqualTo(1));
      });
    });

    group('Auto-Reconnection', () {
      test('should preserve connectedDevice reference on temporary disconnect', () async {
        // Connect first
        await btDevice.connectToDevice(mockBluetoothDevice);
        expect(btDevice.connectedDevice, equals(mockBluetoothDevice));

        // Simulate device disconnecting (via connection state stream)
        connectionStateController.add(BluetoothConnectionState.disconnected);
        await Future.delayed(Duration.zero);

        // Device reference should be preserved for reconnection
        expect(btDevice.connectedDevice, equals(mockBluetoothDevice));
        expect(btDevice.connectionState, equals(BluetoothConnectionState.disconnected));
        expect(btDevice.isConnected, isFalse);
      });

      test('should restore connected state when device reconnects', () async {
        // Connect first
        await btDevice.connectToDevice(mockBluetoothDevice);
        
        // Simulate disconnect
        connectionStateController.add(BluetoothConnectionState.disconnected);
        await Future.delayed(Duration.zero);
        expect(btDevice.isConnected, isFalse);

        // Simulate reconnect
        connectionStateController.add(BluetoothConnectionState.connected);
        await Future.delayed(Duration.zero);

        expect(btDevice.isConnected, isTrue);
        expect(btDevice.connectedDevice, equals(mockBluetoothDevice));
        expect(btDevice.connectionState, equals(BluetoothConnectionState.connected));
        expect(btDevice.connectedAt, isNotNull);
      });

      test('should re-add device to manager registry on reconnection', () async {
        // Connect first
        await btDevice.connectToDevice(mockBluetoothDevice);
        
        // Simulate disconnect
        connectionStateController.add(BluetoothConnectionState.disconnected);
        await Future.delayed(Duration.zero);

        // Clear invocations to count new calls
        clearInteractions(mockDeviceManager);

        // Simulate reconnect
        connectionStateController.add(BluetoothConnectionState.connected);
        await Future.delayed(Duration.zero);

        verify(mockDeviceManager.addConnectedDevice('11:22:33:44:55:66', btDevice)).called(1);
      });

      test('should notify manager of device changes on reconnection', () async {
        await btDevice.connectToDevice(mockBluetoothDevice);
        
        connectionStateController.add(BluetoothConnectionState.disconnected);
        await Future.delayed(Duration.zero);

        clearInteractions(mockDeviceManager);

        connectionStateController.add(BluetoothConnectionState.connected);
        await Future.delayed(Duration.zero);

        verify(mockDeviceManager.notifyDevicesChanged()).called(1);
      });

      test('should handle multiple disconnect-reconnect cycles', () async {
        await btDevice.connectToDevice(mockBluetoothDevice);

        // Cycle 1
        connectionStateController.add(BluetoothConnectionState.disconnected);
        await Future.delayed(Duration.zero);
        expect(btDevice.isConnected, isFalse);

        connectionStateController.add(BluetoothConnectionState.connected);
        await Future.delayed(Duration.zero);
        expect(btDevice.isConnected, isTrue);

        // Cycle 2
        connectionStateController.add(BluetoothConnectionState.disconnected);
        await Future.delayed(Duration.zero);
        expect(btDevice.isConnected, isFalse);

        connectionStateController.add(BluetoothConnectionState.connected);
        await Future.delayed(Duration.zero);
        expect(btDevice.isConnected, isTrue);

        // Device should still be valid
        expect(btDevice.connectedDevice, equals(mockBluetoothDevice));
      });
    });

    group('Explicit Disconnect vs Auto-Reconnect', () {
      test('explicit disconnect should clear connectedDevice reference', () async {
        await btDevice.connectToDevice(mockBluetoothDevice);

        // Explicit user disconnect
        await btDevice.disconnectFromDevice(mockBluetoothDevice);

        // Device reference should be cleared
        expect(btDevice.connectedDevice, isNull);
        expect(btDevice.isConnected, isFalse);
      });

      test('explicit disconnect should cancel connection subscription', () async {
        await btDevice.connectToDevice(mockBluetoothDevice);

        // Explicit user disconnect
        await btDevice.disconnectFromDevice(mockBluetoothDevice);

        // Any subsequent connection state changes should not affect the device
        // (subscription was cancelled)
        connectionStateController.add(BluetoothConnectionState.connected);
        await Future.delayed(Duration.zero);

        // Still disconnected because subscription was cancelled
        expect(btDevice.isConnected, isFalse);
        expect(btDevice.connectedDevice, isNull);
      });
    });

    group('Device Properties', () {
      test('name should return device platform name', () async {
        await btDevice.connectToDevice(mockBluetoothDevice);
        expect(btDevice.name, equals('Test Device'));
      });

      test('name should return placeholder when no device connected', () {
        expect(btDevice.name, equals('(no device)'));
      });

      test('id should return device remote id', () async {
        await btDevice.connectToDevice(mockBluetoothDevice);
        expect(btDevice.id, equals('11:22:33:44:55:66'));
      });

      test('id should return empty string when no device connected', () {
        expect(btDevice.id, equals(''));
      });
    });
  });
}
