import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../utils/logger.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

/// Result of a Bluetooth scan operation
enum BTScanResult {
  success,
  permissionDenied,
  scanError,
}

/// Centralized service for Bluetooth scanning operations
class BluetoothScanService {
  // Singleton instance
  static final BluetoothScanService _instance = BluetoothScanService._internal();
  factory BluetoothScanService() => _instance;
  BluetoothScanService._internal();

  static final List<Guid> supportedServices = [
    Guid.fromString("00001826"), // FTMS Service UUID
    Guid.fromString("0000180D"), // Heart Rate Service UUID
    Guid.fromString("00001816"), // Cycling Speed and Cadence Service UUID
  ];

  /// Start scanning for the supported Bluetooth devices
  Future<BTScanResult> startScan({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    logger.i('Starting Bluetooth scan process...');

    // Check if Bluetooth adapter is on
    if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
      logger.w('Bluetooth adapter is not on. Current state: ${FlutterBluePlus.adapterStateNow}');
      return BTScanResult.scanError;
    }

    // Request Bluetooth permissions first
    logger.i('Requesting Bluetooth permissions...');
    final hasPermissions = await _requestBluetoothPermissions();

    if (!hasPermissions) {
      logger.w('Bluetooth permissions denied');
      return BTScanResult.permissionDenied;
    }

    logger.i('Bluetooth permissions granted, starting scan...');

    try {
      await FlutterBluePlus.startScan(
        timeout: timeout,
        withServices: supportedServices,
      );
      logger.i('Bluetooth scan started successfully');
      return BTScanResult.success;
    } catch (e) {
      logger.e('Failed to start Bluetooth scan: $e');
      return BTScanResult.scanError;
    }
  }

  /// Request all necessary Bluetooth permissions for Android
  Future<bool> _requestBluetoothPermissions() async {
    if (!Platform.isAndroid) {
      logger.i('Not Android, skipping permission requests');
      return true; // No runtime permissions needed on other platforms
    }

    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;
    final sdkInt = androidInfo.version.sdkInt;

    logger.i('Android SDK version: $sdkInt');

    List<ph.Permission> permissions = [];

    // For Android 12+ (API level 31+), request new Bluetooth permissions
    if (sdkInt >= 31) {
      logger.i('Using Android 12+ permissions');
      permissions.addAll([
        ph.Permission.bluetoothScan,
        ph.Permission.bluetoothConnect,
        ph.Permission.locationWhenInUse, // Still needed for Bluetooth scanning
      ]);
    } else {
      logger.i('Using legacy Android permissions');
      permissions.addAll([
        ph.Permission.bluetooth,
        ph.Permission.location,
        ph.Permission.locationWhenInUse,
      ]);
    }

    logger.i('Requesting permissions: ${permissions.map((p) => p.toString()).join(', ')}');
    Map<ph.Permission, ph.PermissionStatus> statuses = await permissions.request();

    // Log the status of each permission
    statuses.forEach((permission, status) {
      logger.i('Permission $permission: $status');
    });

    // Check if all permissions are granted
    final allGranted = statuses.values.every((status) =>
    status == ph.PermissionStatus.granted ||
        status == ph.PermissionStatus.limited);

    logger.i('All permissions granted: $allGranted');
    return allGranted;
  }
}
