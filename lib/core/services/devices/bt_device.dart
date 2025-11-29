import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:ftms/core/services/devices/bt_device_manager.dart';
import 'package:ftms/core/utils/logger.dart';
import '../../models/device_types.dart';
import '../../models/bt_device_service_type.dart';
import 'last_connected_devices_service.dart';

/// Abstract service interface for different types of Bluetooth devices
abstract class BTDevice {
  /// Human-readable name for this device type
  String get deviceTypeName;

  /// Priority for sorting in device lists (lower numbers appear first)
  int get listPriority;

  /// Icon to display for this device type
  Widget? getDeviceIcon(BuildContext context);

  // Connection state management
  BluetoothDevice? _connectedDevice;
  DateTime? _connectedAt;
  BluetoothConnectionState _connectionState = BluetoothConnectionState.disconnected;
  DeviceType? _deviceType;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  
  // Reference to the device manager (set by the manager during initialization)
  SupportedBTDeviceManager? _deviceManager;

  /// Connected device
  BluetoothDevice? get connectedDevice => _connectedDevice;

  /// Connection state
  BluetoothConnectionState get connectionState => _connectionState;

  /// Time when device was connected
  DateTime? get connectedAt => _connectedAt;

  /// Device type (for FTMS devices)
  DeviceType? get deviceType => _deviceType;

  /// Device name
  String get name => _connectedDevice?.platformName.isEmpty == true ? '(unknown device)' : _connectedDevice?.platformName ?? '(no device)';

  /// Device ID
  String get id => _connectedDevice?.remoteId.str ?? '';

  /// Whether this device is currently connected
  bool get isConnected => _connectedDevice != null && _connectionState == BluetoothConnectionState.connected;

  /// Check if a device is of this type (synchronous check for sorting)
  bool isDeviceOfThisType(BluetoothDevice device, List<ScanResult> scanResults);

  /// Connect to a device of this type
  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      final success = await performConnection(device);
      if (success) {
        await _setConnected(device);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Disconnect from a device of this type
  Future<void> disconnectFromDevice(BluetoothDevice device) async {
    try {
      await performDisconnection(device);
    } finally {
      await _setDisconnected();
    }
  }

  /// Abstract method for device-specific connection logic
  Future<bool> performConnection(BluetoothDevice device);

  /// Abstract method for device-specific disconnection logic
  Future<void> performDisconnection(BluetoothDevice device);

  /// Set the device manager (called by SupportedBTDeviceManager during initialization)
  void setDeviceManager(SupportedBTDeviceManager deviceManager) {
    _deviceManager = deviceManager;
  }

  /// Update device type (for FTMS devices)
  void updateDeviceType(DeviceType deviceType) {
    _deviceType = deviceType;
    _notifyDevicesChanged();
  }

  /// Internal method to mark device as connected
  Future<void> _setConnected(BluetoothDevice device) async {
    logger.i('📱 Setting device as connected: ${device.platformName} (${device.remoteId})');
    _connectedDevice = device;
    _connectedAt = DateTime.now();
    _connectionState = BluetoothConnectionState.connected;
    
    // Subscribe to connection state changes
    _connectionSubscription?.cancel();
    _connectionSubscription = device.connectionState.listen((state) {
      _updateConnectionState(state);
    });
    
    // Add to global registry via manager
    if (_deviceManager != null) {
      _deviceManager?.addConnectedDevice(device.remoteId.str, this);
    }
    
    // Save device information for auto-reconnection
    try {
      final lastConnectedService = LastConnectedDevicesService();
      await lastConnectedService.saveLastConnectedDevice(
        deviceType: BTDeviceServiceType.fromString(deviceTypeName),
        deviceId: device.remoteId.str,
        deviceName: device.platformName.isEmpty ? '(unknown device)' : device.platformName,
      );
    } catch (e) {
      // Ignore errors for unsupported device types (e.g., test devices)
      logger.w('⚠️ Could not save last connected device: $e');
    }
  }

  /// Internal method to mark device as disconnected
  Future<void> _setDisconnected() async {
    final deviceId = _connectedDevice?.remoteId.str;
    
    _connectionSubscription?.cancel();
    _connectionSubscription = null;
    _connectedDevice = null;
    _connectedAt = null;
    _connectionState = BluetoothConnectionState.disconnected;
    _deviceType = null;
    
    // Remove from global registry via manager
    if (deviceId != null && _deviceManager != null) {
      _deviceManager?.removeConnectedDevice(deviceId);
    }
  }

  /// Update connection state
  void _updateConnectionState(BluetoothConnectionState state) {
    _connectionState = state;
    if (state == BluetoothConnectionState.disconnected) {
      _setDisconnected();
    } else {
      _notifyDevicesChanged();
    }
  }

  /// Notify listeners of device changes
  void _notifyDevicesChanged() {
    if (_deviceManager != null) {
      // The manager will handle the notification
      _deviceManager?.notifyDevicesChanged();
    }
  }

  /// Get the page/widget to show when the device is connected (optional)
  Widget? getDevicePage(BluetoothDevice device);

  /// Get a navigation callback for this device type (alternative to getDevicePage)
  /// This allows device services to define navigation without importing UI components
  void Function(BuildContext context, BluetoothDevice device)? getNavigationCallback() {
    return null;
  }

  /// Get action buttons for the connected device (optional)
  List<Widget> getConnectedActions(BluetoothDevice device, BuildContext context) {
    final page = getDevicePage(device);
    final navigationCallback = getNavigationCallback();
    final actions = <Widget>[];
    
    if (page != null) {
      actions.add(
        ElevatedButton(
          child: const Text("Open"),
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
          child: const Text("Open"),
          onPressed: () => navigationCallback(context, device),
        ),
      );
    }
    
    return actions;
  }
}
