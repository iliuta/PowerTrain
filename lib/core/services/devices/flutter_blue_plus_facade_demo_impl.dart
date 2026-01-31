import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_ftms/flutter_ftms.dart';
import 'package:ftms/core/services/devices/demo_ftms_device.dart';
import 'package:ftms/core/services/devices/flutter_blue_plus_facade.dart';

/// Demo implementation of FlutterBluePlus facade that returns fake devices
class DemoFlutterBluePlusFacade implements FlutterBluePlusFacade {
  DemoFlutterBluePlusFacade._();

  static final DemoFlutterBluePlusFacade _instance =
  DemoFlutterBluePlusFacade._();

  factory DemoFlutterBluePlusFacade() => _instance;

  final StreamController<BluetoothAdapterState> _adapterStateController =
  StreamController<BluetoothAdapterState>.broadcast();
  final StreamController<List<ScanResult>> _scanResultsController =
  StreamController<List<ScanResult>>.broadcast();
  final StreamController<bool> _isScanningController =
  StreamController<bool>.broadcast();

  bool _isScanningNow = false;
  bool _isDemoMode = true;

  late final DemoFtmsDevice _demoRowerDevice;
  late final DemoFtmsDevice _demoBikeDevice;

  bool _initialized = false;

  void _ensureInitialized() {
    if (!_initialized) {
      _demoRowerDevice = DemoFtmsDevice(
        deviceId: 'DEMO:00:00:00:00:01',
        deviceType: DeviceDataType.rower,
        remoteId: DeviceIdentifier("DEMO:00:00:00:00:01"),
      );
      _demoBikeDevice = DemoFtmsDevice(
        deviceId: 'DEMO:00:00:00:00:02',
        deviceType: DeviceDataType.indoorBike,
        remoteId: DeviceIdentifier("DEMO:00:00:00:00:01"),
      );
      _initialized = true;
    }
  }

  @override
  bool get isDemoMode => _isDemoMode;

  @override
  set isDemoMode(bool value) => _isDemoMode = value;

  @override
  Stream<BluetoothAdapterState> get adapterState =>
      _adapterStateController.stream;

  @override
  BluetoothAdapterState get adapterStateNow => BluetoothAdapterState.on;

  @override
  List<BluetoothDevice> get connectedDevices {
    _ensureInitialized();
    // Return demo devices that are connected using their underlying BluetoothDevice
    final connected = <BluetoothDevice>[];
    if (_demoRowerDevice.isConnected) {
      connected.add(_demoRowerDevice);
    }
    if (_demoBikeDevice.isConnected) {
      connected.add(_demoBikeDevice);
    }
    return connected;
  }

  @override
  Stream<List<ScanResult>> get scanResults => _scanResultsController.stream;

  @override
  Future<void> startScan({
    Duration timeout = const Duration(seconds: 15),
    List<Guid>? withServices,
  }) async {
    _ensureInitialized();
    _isScanningNow = true;
    _isScanningController.add(true);

    // Emit demo devices after a short delay to simulate scanning
    await Future.delayed(const Duration(milliseconds: 500));

    // Register demo device names in FlutterBluePlus internal maps
    _registerDemoDeviceName(
      _demoRowerDevice.remoteId,
      'Demo Rower',
    );
    _registerDemoDeviceName(
      _demoBikeDevice.remoteId,
      'Demo Indoor Bike',
    );

    final demoResults = <ScanResult>[
      ScanResult(
        device: _demoRowerDevice,
        advertisementData: AdvertisementData(
          advName: 'Demo Rower',
          connectable: true,
          manufacturerData: {},
          serviceData: {},
          serviceUuids: [Guid('00001826')],
          // FTMS Service UUID
          txPowerLevel: -50,
          appearance: null,
        ),
        rssi: -45,
        timeStamp: DateTime.now(),
      ),
      ScanResult(
        device: _demoBikeDevice,
        advertisementData: AdvertisementData(
          advName: 'Demo Indoor Bike',
          connectable: true,
          manufacturerData: {},
          serviceData: {},
          serviceUuids: [Guid('00001826')],
          // FTMS Service UUID
          txPowerLevel: -50,
          appearance: null,
        ),
        rssi: -50,
        timeStamp: DateTime.now(),
      ),
    ];

    _scanResultsController.add(demoResults);

    // Stop scanning after timeout
    Future.delayed(timeout, () {
      if (_isScanningNow) {
        stopScan();
      }
    });
  }

  /// Register demo device names in FlutterBluePlus internal maps
  /// This is a workaround to populate the platformName property
  void _registerDemoDeviceName(DeviceIdentifier remoteId, String name) {
    try {
      // Access the private _platformNames map in FlutterBluePlus using dynamic typing
      // Note: This accesses private members - necessary for demo mode to work properly
      dynamic fbp = FlutterBluePlus;
      Map platformNamesMap = fbp._platformNames ?? {};
      platformNamesMap[remoteId] = name;

      // Also register in _advNames for consistency
      Map advNamesMap = fbp._advNames ?? {};
      advNamesMap[remoteId] = name;
    } catch (e) {
      // Fallback: if access fails, just silently continue
      // The demo will still work, but platformName might be empty
    }
  }

  @override
  Future<void> stopScan() async {
    _isScanningNow = false;
    _isScanningController.add(false);
  }

  @override
  bool get isScanningNow => _isScanningNow;

  @override
  Stream<bool> get isScanning => _isScanningController.stream;

  @override
  void setLogLevel(LogLevel level) {
    // No-op for demo mode
  }

  /// Get the demo rower device
  DemoFtmsDevice get demoRowerDevice {
    _ensureInitialized();
    return _demoRowerDevice;
  }

  /// Get the demo bike device
  DemoFtmsDevice get demoBikeDevice {
    _ensureInitialized();
    return _demoBikeDevice;
  }

  /// Check if a device is a demo device
  bool isDemoDevice(BluetoothDevice device) {
    _ensureInitialized();
    return device.remoteId.str.startsWith('DEMO:');
  }

  /// Get the DemoFtmsDevice wrapper for a BluetoothDevice if it's a demo device
  DemoFtmsDevice? getDemoDevice(BluetoothDevice device) {
    _ensureInitialized();
    if (device.remoteId == _demoRowerDevice.remoteId) {
      return _demoRowerDevice;
    }
    if (device.remoteId == _demoBikeDevice.remoteId) {
      return _demoBikeDevice;
    }
    return null;
  }
}