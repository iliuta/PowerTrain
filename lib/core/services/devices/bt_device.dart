import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:ftms/core/services/devices/bt_device_manager.dart';
import 'package:ftms/core/services/analytics/analytics_service.dart';
import 'package:ftms/core/utils/logger.dart';
import 'package:ftms/l10n/app_localizations.dart';
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
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  String? _customDisplayName; // For simulated/demo devices
  
  // Reference to the device manager (set by the manager during initialization)
  SupportedBTDeviceManager? _deviceManager;

  /// Connected device
  BluetoothDevice? get connectedDevice => _connectedDevice;

  /// Connection state
  BluetoothConnectionState get connectionState => _connectionState;

  /// Time when device was connected
  DateTime? get connectedAt => _connectedAt;

  /// Device name
  String get name {
    // Use custom display name if set (for simulated devices)
    if (_customDisplayName != null && _customDisplayName!.isNotEmpty) {
      return _customDisplayName!;
    }
    return _connectedDevice?.platformName.isEmpty == true ? '(unknown device)' : _connectedDevice?.platformName ?? '(no device)';
  }

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
      // User explicitly disconnected, so don't keep subscription for reconnection
      await _setDisconnected(keepSubscription: false);
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

  /// Save device information to preferences
  Future<void> _saveDeviceInfo({DeviceType? machineType}) async {
    try {
      final lastConnectedService = LastConnectedDevicesService();
      await lastConnectedService.saveLastConnectedDevice(
        deviceType: BTDeviceServiceType.fromString(deviceTypeName),
        deviceId: id,
        deviceName: name,
        machineType: machineType,
      );
    } catch (e) {
      logger.w('⚠️ Could not save last connected device: $e');
    }
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
    
    // Log analytics event for device connected
    AnalyticsService().logDeviceConnected(
      deviceType: deviceTypeName,
      deviceName: device.platformName.isEmpty ? '(unknown device)' : device.platformName,
    );
    
    // Save device information for auto-reconnection
    _saveDeviceInfo();
  }
  
  /// Protected method to mark a simulated/demo device as connected
  /// This version doesn't subscribe to connection state changes (for demo devices)
  @protected
  Future<void> setSimulatedDeviceConnected(BluetoothDevice device, {String? displayName}) async {
    final name = displayName ?? device.platformName;
    logger.i('📱 Setting simulated device as connected: $name (${device.remoteId})');
    _connectedDevice = device;
    _connectedAt = DateTime.now();
    _connectionState = BluetoothConnectionState.connected;
    _customDisplayName = displayName; // Store the custom display name
    
    // Don't subscribe to connection state for simulated devices
    _connectionSubscription?.cancel();
    _connectionSubscription = null;
    
    // Add to global registry via manager
    if (_deviceManager != null) {
      _deviceManager?.addConnectedDevice(device.remoteId.str, this);
    }
    
    notifyDevicesChanged();
  }
  
  /// Protected method to mark a simulated/demo device as disconnected
  @protected
  Future<void> setSimulatedDeviceDisconnected() async {
    final deviceId = _connectedDevice?.remoteId.str;
    
    _connectionSubscription?.cancel();
    _connectionSubscription = null;
    _connectedDevice = null;
    _customDisplayName = null; // Clear custom display name
    _connectedAt = null;
    _connectionState = BluetoothConnectionState.disconnected;
    
    // Remove from global registry via manager
    if (deviceId != null && _deviceManager != null) {
      _deviceManager?.removeConnectedDevice(deviceId);
    }
    
    notifyDevicesChanged();
  }

  /// Internal method to mark device as disconnected
  /// When [keepSubscription] is true, we keep the connection subscription
  /// to detect reconnection (used for auto-reconnect scenarios)
  Future<void> _setDisconnected({bool keepSubscription = false}) async {
    final deviceId = _connectedDevice?.remoteId.str;
    
    if (!keepSubscription) {
      _connectionSubscription?.cancel();
      _connectionSubscription = null;
      _connectedDevice = null;
    }
    _connectedAt = null;
    _connectionState = BluetoothConnectionState.disconnected;
    
    // Remove from global registry via manager
    if (deviceId != null && _deviceManager != null) {
      _deviceManager?.removeConnectedDevice(deviceId);
    }
    
    // Log analytics event for device disconnected
    if (_connectedDevice != null) {
      AnalyticsService().logDeviceDisconnected(
        deviceType: deviceTypeName,
        deviceName: _connectedDevice!.platformName.isEmpty ? '(unknown device)' : _connectedDevice!.platformName,
      );
    }
  }

  /// Internal method to restore device as connected (for reconnection)
  Future<void> _setReconnected() async {
    if (_connectedDevice == null) return;
    
    logger.i('📱 Restoring device as connected: ${_connectedDevice!.platformName} (${_connectedDevice!.remoteId})');
    _connectedAt = DateTime.now();
    _connectionState = BluetoothConnectionState.connected;
    
    // Re-add to global registry via manager
    if (_deviceManager != null) {
      _deviceManager?.addConnectedDevice(_connectedDevice!.remoteId.str, this);
    }
    
    notifyDevicesChanged();
  }

  /// Update connection state
  void _updateConnectionState(BluetoothConnectionState state) {
    final previousState = _connectionState;
    _connectionState = state;
    
    if (state == BluetoothConnectionState.disconnected) {
      // Keep subscription to detect reconnection (auto-reconnect scenario)
      _setDisconnected(keepSubscription: true);
    } else if (state == BluetoothConnectionState.connected && 
               previousState == BluetoothConnectionState.disconnected) {
      // Device reconnected
      _setReconnected();
    } else {
      notifyDevicesChanged();
    }
  }

  /// Notify listeners of device changes
  void notifyDevicesChanged() {
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
          child: Text(AppLocalizations.of(context)!.open),
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
          child: Text(AppLocalizations.of(context)!.open),
          onPressed: () => navigationCallback(context, device),
        ),
      );
    }
    
    return actions;
  }
}
