import 'package:flutter_ftms/flutter_ftms.dart';
import 'package:ftms/core/services/devices/flutter_blue_plus_facade_provider.dart';
import 'package:ftms/core/services/user_settings_service.dart';
import '../../utils/logger.dart';

/// Facade interface for FTMS operations to enable testing
abstract class FtmsFacade {
  /// Check if a Bluetooth device is an FTMS device
  Future<bool> isBluetoothDeviceFTMSDevice(BluetoothDevice device);
  
  /// Use device data characteristic and get callback with data
  void useDeviceDataCharacteristic(
    BluetoothDevice device,
    void Function(DeviceData) callback, {
    DeviceDataType? preferredDeviceDataType,
  });
  
  Future<bool> connectToFTMSDevice(BluetoothDevice device) async {
    await FTMS.connectToFTMSDevice(device);
    return true;
  }

  Future<void> disconnectFromFTMSDevice(BluetoothDevice device) async {
    await FTMS.disconnectFromFTMSDevice(device);
  }
}

/// Production implementation of FTMS facade
class FtmsFacadeImpl extends FtmsFacade {
  @override
  Future<bool> isBluetoothDeviceFTMSDevice(BluetoothDevice device) {
    return FTMS.isBluetoothDeviceFTMSDevice(device);
  }
  
  @override
  void useDeviceDataCharacteristic(
    BluetoothDevice device,
    void Function(DeviceData) callback, {
    DeviceDataType? preferredDeviceDataType,
  }) {
    FTMS.useDeviceDataCharacteristic(
      device,
      callback,
      preferredDeviceDataType: preferredDeviceDataType,
    );
  }

}

/// Demo implementation of FTMS facade that works with demo devices
class DemoFtmsFacade extends FtmsFacade {
  @override
  Future<bool> isBluetoothDeviceFTMSDevice(BluetoothDevice device) async {
    // Check if this is a demo device by checking the device ID
    final demoFacade = FlutterBluePlusFacadeProvider().demoFacade;
    if (demoFacade.isDemoDevice(device)) {
      return true;
    }
    // Fall back to real check for non-demo devices
    return FTMS.isBluetoothDeviceFTMSDevice(device);
  }
  
  @override
  void useDeviceDataCharacteristic(
    BluetoothDevice device,
    void Function(DeviceData) callback, {
    DeviceDataType? preferredDeviceDataType,
  }) {
    final demoFacade = FlutterBluePlusFacadeProvider().demoFacade;
    final demoDevice = demoFacade.getDemoDevice(device);
    
    if (demoDevice != null) {
      logger.d('🎭 DEMO FACADE: Calling startDataEmission on demo device ${device.remoteId.str}');
      // Start emitting fake data for demo device
      demoDevice.startDataEmission(callback);
      return;
    }
    
    // Fall back to real implementation for non-demo devices
    FTMS.useDeviceDataCharacteristic(
      device,
      callback,
      preferredDeviceDataType: preferredDeviceDataType,
    );
  }
}

/// Provider for FTMS facade that switches between real and demo mode
class FtmsFacadeProvider {
  FtmsFacadeProvider._();
  static final FtmsFacadeProvider _instance = FtmsFacadeProvider._();
  factory FtmsFacadeProvider() => _instance;
  
  final FtmsFacadeImpl _realFacade = FtmsFacadeImpl();
  final DemoFtmsFacade _demoFacade = DemoFtmsFacade();
  
  FtmsFacade get facade {
    final settings = UserSettingsService.instance.getCachedSettings();
    final isDemoMode = settings?.demoModeEnabled ?? false;
    return isDemoMode ? _demoFacade : _realFacade;
  }
}
