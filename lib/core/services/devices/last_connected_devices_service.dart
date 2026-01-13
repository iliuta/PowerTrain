import 'package:shared_preferences/shared_preferences.dart';
import 'package:ftms/core/utils/logger.dart';
import 'package:ftms/core/models/bt_device_service_type.dart';
import 'package:ftms/core/models/device_types.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'bt_device_manager.dart';
import 'dart:convert';

/// Result of an auto-reconnection attempt
class AutoReconnectionResult {
  final BTDeviceServiceType deviceType;
  final String deviceName;
  final bool success;
  
  AutoReconnectionResult({
    required this.deviceType,
    required this.deviceName,
    required this.success,
  });
}

/// Service to manage last connected device information for auto-reconnection
/// Stores one device per device type (HRM, Cadence, FTMS)
class LastConnectedDevicesService {
  static const String _prefsPrefix = 'last_connected_device_';
  static LastConnectedDevicesService? _instance;
  final Set<String> _attemptedReconnections = {};
  final SupportedBTDeviceManager _deviceManager;
  
  /// Private constructor
  LastConnectedDevicesService._({SupportedBTDeviceManager? deviceManager})
      : _deviceManager = deviceManager ?? SupportedBTDeviceManager();
  
  /// Factory constructor for production use (singleton)
  factory LastConnectedDevicesService() {
    return _instance ??= LastConnectedDevicesService._();
  }
  
  /// Constructor for testing with dependency injection
  LastConnectedDevicesService.forTesting({required SupportedBTDeviceManager deviceManager})
      : _deviceManager = deviceManager;
  
  /// Reset singleton for testing
  static void resetInstance() {
    _instance = null;
  }
  
  /// Save device information for a specific device type
  /// This overwrites any previously stored device for this type
  Future<void> saveLastConnectedDevice({
    required BTDeviceServiceType deviceType,
    required String deviceId,
    required String deviceName,
    DeviceType? machineType,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _prefsPrefix + deviceType.name.toLowerCase();
      
      final deviceInfo = {
        'deviceId': deviceId,
        'deviceName': deviceName,
        'timestamp': DateTime.now().toIso8601String(),
        if (machineType != null) 'machineType': machineType.name,
      };
      
      await prefs.setString(key, jsonEncode(deviceInfo));
    } catch (e) {
      logger.e('❌ Failed to save last connected device: $e');
    }
  }
  
  /// Get the last connected device information for a specific device type
  Future<Map<String, dynamic>?> getLastConnectedDevice(BTDeviceServiceType deviceType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _prefsPrefix + deviceType.name.toLowerCase();
      
      final jsonString = prefs.getString(key);
      if (jsonString == null) {
        return null;
      }
      
      final deviceInfo = jsonDecode(jsonString) as Map<String, dynamic>;
      return {
        'deviceId': deviceInfo['deviceId'] as String,
        'deviceName': deviceInfo['deviceName'] as String,
        'timestamp': deviceInfo['timestamp'] as String,
        'machineType': deviceInfo['machineType'] as String?,
      };
    } catch (e) {
      logger.e('❌ Failed to load last connected device: $e');
      return null;
    }
  }
  
  /// Get all last connected devices (for all device types)
  Future<Map<BTDeviceServiceType, Map<String, dynamic>>> getAllLastConnectedDevices() async {
    final result = <BTDeviceServiceType, Map<String, dynamic>>{};
    
    // Check for each known device type
    for (final deviceType in BTDeviceServiceType.all) {
      final deviceInfo = await getLastConnectedDevice(deviceType);
      if (deviceInfo != null) {
        result[deviceType] = deviceInfo;
      }
    }
    
    return result;
  }
  
  /// Clear the last connected device for a specific device type
  Future<void> clearLastConnectedDevice(BTDeviceServiceType deviceType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _prefsPrefix + deviceType.name.toLowerCase();
      
      await prefs.remove(key);
    } catch (e) {
      logger.e('❌ Failed to clear last connected device: $e');
    }
  }
  
  /// Clear all last connected devices
  Future<void> clearAllLastConnectedDevices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((key) => key.startsWith(_prefsPrefix));
      
      for (final key in keys) {
        await prefs.remove(key);
      }
      
    } catch (e) {
      logger.e('❌ Failed to clear all last connected devices: $e');
    }
  }
  
  /// Reset the auto-reconnection tracking (useful for testing or app restart)
  void resetReconnectionTracking() {
    _attemptedReconnections.clear();
  }
  
  /// Attempt to auto-reconnect to previously connected devices found in scan results
  /// Returns a list of reconnection results for UI feedback
  Future<List<AutoReconnectionResult>> attemptAutoReconnections(
    List<ScanResult> scanResults,
  ) async {
    final results = <AutoReconnectionResult>[];
    
    // Get all previously connected devices
    final lastConnectedDevices = await getAllLastConnectedDevices();
    
    // Try to reconnect to each previously connected device
    for (final entry in lastConnectedDevices.entries) {
      final deviceType = entry.key;
      final deviceInfo = entry.value;
      final lastDeviceId = deviceInfo['deviceId']!;
      final lastDeviceName = deviceInfo['deviceName']!;
      
      // Skip if we've already attempted to reconnect this device
      if (_attemptedReconnections.contains(lastDeviceId)) {
        continue;
      }
      
      // Skip if device is already connected
      final alreadyConnected = _deviceManager.allConnectedDevices
          .any((device) => device.id == lastDeviceId);
      if (alreadyConnected) {
        _attemptedReconnections.add(lastDeviceId);
        continue;
      }
      
      // Look for this device in the scan results
      final scanResult = scanResults.where((result) => 
        result.device.remoteId.str == lastDeviceId
      ).firstOrNull;
      
      if (scanResult != null) {

        // Mark as attempted
        _attemptedReconnections.add(lastDeviceId);
        
        // Attempt to connect
        final device = scanResult.device;
        final btDevice = _deviceManager.getBTDevice(device, scanResults);
        
        if (btDevice != null) {

          final success = await btDevice.connectToDevice(device);
          
          if (success) {
            logger.i('✅ Auto-reconnection: Successfully reconnected to $lastDeviceName');
          } else {
            logger.i('❌ Auto-reconnection: Failed to reconnect to $lastDeviceName');
          }
          
          results.add(AutoReconnectionResult(
            deviceType: deviceType,
            deviceName: lastDeviceName,
            success: success,
          ));
        }
      }
    }
    
    return results;
  }
}
