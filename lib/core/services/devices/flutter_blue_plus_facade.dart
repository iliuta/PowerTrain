import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Facade interface for FlutterBluePlus operations to enable testing and demo mode
abstract class FlutterBluePlusFacade {
  /// Stream of Bluetooth adapter state changes
  Stream<BluetoothAdapterState> get adapterState;

  /// Current Bluetooth adapter state
  BluetoothAdapterState get adapterStateNow;

  /// Get list of currently connected devices
  List<BluetoothDevice> get connectedDevices;

  /// Stream of scan results
  Stream<List<ScanResult>> get scanResults;

  /// Start scanning for Bluetooth devices
  Future<void> startScan({
    Duration timeout = const Duration(seconds: 15),
    List<Guid>? withServices,
  });

  /// Stop scanning for Bluetooth devices
  Future<void> stopScan();

  /// Check if currently scanning
  bool get isScanningNow;

  /// Stream of scanning state changes
  Stream<bool> get isScanning;

  /// Whether demo mode is enabled
  bool get isDemoMode;

  /// Enable or disable demo mode
  set isDemoMode(bool value);

  /// Set the log level
  void setLogLevel(LogLevel level);
}






