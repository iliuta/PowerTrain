import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:ftms/core/services/devices/flutter_blue_plus_facade.dart';

/// Production implementation of FlutterBluePlus facade
class FlutterBluePlusFacadeImpl implements FlutterBluePlusFacade {
  bool _isDemoMode = false;

  @override
  bool get isDemoMode => _isDemoMode;

  @override
  set isDemoMode(bool value) => _isDemoMode = value;

  @override
  Stream<BluetoothAdapterState> get adapterState =>
      FlutterBluePlus.adapterState;

  @override
  BluetoothAdapterState get adapterStateNow => FlutterBluePlus.adapterStateNow;

  @override
  List<BluetoothDevice> get connectedDevices =>
      FlutterBluePlus.connectedDevices;

  @override
  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;

  @override
  Future<void> startScan({
    Duration timeout = const Duration(seconds: 15),
    List<Guid>? withServices,
  }) async {
    await FlutterBluePlus.startScan(
      timeout: timeout,
      withServices: withServices ?? [],
    );
  }

  @override
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  @override
  bool get isScanningNow => FlutterBluePlus.isScanningNow;

  @override
  Stream<bool> get isScanning => FlutterBluePlus.isScanning;

  @override
  void setLogLevel(LogLevel level) {
    FlutterBluePlus.setLogLevel(level);
  }
}