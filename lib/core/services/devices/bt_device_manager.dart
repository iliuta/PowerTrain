import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_ftms/flutter_ftms.dart';
import 'package:ftms/core/services/devices/cadence.dart';
import 'package:ftms/core/services/devices/flutter_blue_plus_facade_impl.dart';
import 'package:ftms/core/utils/logger.dart';
import 'bt_device.dart';
import 'hrm.dart';
import 'ftms.dart';
import 'flutter_blue_plus_facade.dart';
import 'ftms_facade.dart';
import 'dart:async';

/// Manager for handling different types of Bluetooth devices
class SupportedBTDeviceManager {
  static SupportedBTDeviceManager? _instance;
  
  final FlutterBluePlusFacade _flutterBluePlusFacade;
  final FtmsFacade _ftmsFacade;
  final List<BTDevice> _supportedBTDevices;

  // Global device tracking
  final StreamController<List<BTDevice>> _globalDevicesController = 
      StreamController<List<BTDevice>>.broadcast();
  final Map<String, BTDevice> _allConnectedDevices = {};

  /// Private constructor for dependency injection
  SupportedBTDeviceManager._({
    required FlutterBluePlusFacade flutterBluePlusFacade,
    required FtmsFacade ftmsFacade,
    required List<BTDevice> supportedDevices,
  }) : _flutterBluePlusFacade = flutterBluePlusFacade,
       _ftmsFacade = ftmsFacade,
       _supportedBTDevices = supportedDevices;

  /// Factory constructor for production use (singleton)
  factory SupportedBTDeviceManager() {
    return _instance ??= SupportedBTDeviceManager._(
      flutterBluePlusFacade: FlutterBluePlusFacadeImpl(),
      ftmsFacade: FtmsFacadeImpl(),
      supportedDevices: [
        Hrm(),
        Cadence(),
        Ftms(),
      ],
    );
  }

  /// Constructor for testing with dependency injection
  SupportedBTDeviceManager.forTesting({
    required FlutterBluePlusFacade flutterBluePlusFacade,
    required FtmsFacade ftmsFacade,
    required List<BTDevice> supportedDevices,
  }) : _flutterBluePlusFacade = flutterBluePlusFacade,
       _ftmsFacade = ftmsFacade,
       _supportedBTDevices = supportedDevices;

  /// Reset singleton for testing
  static void resetInstance() {
    _instance = null;
  }

  /// Stream of all connected devices
  Stream<List<BTDevice>> get connectedDevicesStream => _globalDevicesController.stream;

  /// List of all connected devices
  List<BTDevice> get allConnectedDevices => List.unmodifiable(_allConnectedDevices.values);

  /// Get the list of device services
  List<BTDevice> get deviceServices => List.unmodifiable(_supportedBTDevices);

  /// Initialize the device management system
  Future<void> initialize() async {
    // Initialize each device service
    for (final btDevice in _supportedBTDevices) {
      btDevice.setDeviceManager(this);
    }

    // Listen to Bluetooth adapter state changes
    _flutterBluePlusFacade.adapterState.listen((state) {
      if (state == BluetoothAdapterState.off) {
        // Clear all devices when Bluetooth is turned off
        _allConnectedDevices.clear();
        _notifyDevicesChanged();
      }
    });

    logger.i('🚀 Initializing BTDevice system...');
    _notifyDevicesChanged();
  }

  /// Add a device to the global registry
  void addConnectedDevice(String deviceId, BTDevice btDevice) {
    _allConnectedDevices[deviceId] = btDevice;
    logger.i('📱 Added device to global registry. Total devices: ${_allConnectedDevices.length}');
    _notifyDevicesChanged();
  }

  /// Remove a device from the global registry
  void removeConnectedDevice(String deviceId) {
    _allConnectedDevices.remove(deviceId);
    logger.i('📱 Removed device from global registry. Total devices: ${_allConnectedDevices.length}');
    _notifyDevicesChanged();
  }

  /// Notify listeners of device changes (public method for BTDevice instances)
  void notifyDevicesChanged() {
    _notifyDevicesChanged();
  }

  /// Notify listeners of device changes
  void _notifyDevicesChanged() {
    _globalDevicesController.add(allConnectedDevices);
  }

  /// Find the primary device service for a given device
  BTDevice? getBTDevice(BluetoothDevice device, List<ScanResult> scanResults) {
    // Return the first btDevice that matches the device
    // Services are ordered by priority (HRM first, then FTMS)
    for (final btDevice in _supportedBTDevices) {
      if (btDevice.isDeviceOfThisType(device, scanResults)) {
        return btDevice;
      }
    }
    return null;
  }

  /// Get all device services that match a given device
  List<BTDevice> getAllMatchingBTDevices(BluetoothDevice device, List<ScanResult> scanResults) {
    return _supportedBTDevices
        .where((service) => service.isDeviceOfThisType(device, scanResults))
        .toList();
  }

  /// Sort devices by their type priority
  List<ScanResult> sortBTDevicesByPriority(List<ScanResult> scanResults) {
    final sortedData = List<ScanResult>.from(scanResults);
    
    sortedData.sort((a, b) {
      final aService = getBTDevice(a.device, scanResults);
      final bService = getBTDevice(b.device, scanResults);
      
      // If both have services, sort by priority
      if (aService != null && bService != null) {
        final priorityComparison = aService.listPriority.compareTo(bService.listPriority);
        if (priorityComparison != 0) return priorityComparison;
      }
      
      // If only one has a service, prioritize it
      if (aService != null && bService == null) return -1;
      if (aService == null && bService != null) return 1;
      
      // If neither has a service or same priority, sort by signal strength
      return b.rssi.compareTo(a.rssi);
    });
    
    return sortedData;
  }

  /// Connect to a device using the appropriate service
  Future<bool> connectToDevice(BluetoothDevice device, List<ScanResult> scanResults) async {
    final btDevice = getBTDevice(device, scanResults);
    if (btDevice != null) {
      return await btDevice.connectToDevice(device);
    }
    return false;
  }

  /// Identify and connect to already connected devices
  Future<void> identifyAndConnectExistingDevices() async {
    final connectedBtDevices = _flutterBluePlusFacade.connectedDevices;
    logger.i('🔍 Found ${connectedBtDevices.length} already connected Bluetooth devices');
    
    for (final device in connectedBtDevices) {
      logger.i('🔍 Identifying device: ${device.platformName} (${device.remoteId})');
      await _identifyAndConnectDevice(device);
    }
  }

  /// Identify the type of an already-connected device and connect it
  Future<void> _identifyAndConnectDevice(BluetoothDevice device) async {
    logger.i('🔍 Starting identification for device: ${device.platformName}');
    
    // Check each supported device service type
    
    // 1. Check if it's an FTMS device
    try {
      logger.i('🔍 Checking if device is FTMS...');
      final isFtmsDevice = await _ftmsFacade.isBluetoothDeviceFTMSDevice(device);
      if (isFtmsDevice) {
        logger.i('✅ Device is FTMS, connecting...');
        final ftmsService = _supportedBTDevices.firstWhere((s) => s.deviceTypeName == 'FTMS');
        await ftmsService.connectToDevice(device);
        return;
      }
      logger.i('❌ Device is not FTMS');
    } catch (e) {
      logger.i('❌ Error checking FTMS: $e');
      // Continue to next check
    }
    
    // 2. Check if it's an HRM or Cadence device using service discovery
    try {
      logger.i('🔍 Discovering services for non-FTMS device...');
      final services = await device.discoverServices();
      logger.i('🔍 Found ${services.length} services');
      
      // Check for Heart Rate service UUID (0x180D)
      final hasHrmService = services.any((service) => 
          service.uuid.toString().toUpperCase().contains('180D'));
      
      if (hasHrmService) {
        logger.i('✅ Device has HRM service, connecting...');
        final hrmService = _supportedBTDevices.firstWhere((s) => s.deviceTypeName == 'HRM');
        await hrmService.connectToDevice(device);
        return;
      }
      
      // Check for Cycling Speed and Cadence service UUID (0x1816)
      final hasCadenceService = services.any((service) => 
          service.uuid.toString().toUpperCase().contains('1816'));
      
      if (hasCadenceService) {
        logger.i('✅ Device has Cadence service, connecting...');
        final cadenceService = _supportedBTDevices.firstWhere((s) => s.deviceTypeName == 'Cadence');
        await cadenceService.connectToDevice(device);
        return;
      }
      
      logger.i('❌ Device has no supported services');
      
    } catch (e) {
      logger.i('❌ Error discovering services: $e');
      // Device is not a supported type, ignore
    }
  }

  /// Get the first connected FTMS device
  BTDevice? getConnectedFtmsDevice() {
    try {
      return _allConnectedDevices.values.firstWhere((device) => device.deviceTypeName == 'FTMS');
    } catch (e) {
      return null;
    }
  }

  /// Get all connected devices of a specific type
  List<BTDevice> getConnectedDevicesOfType(String deviceTypeName) {
    return _allConnectedDevices.values
        .where((device) => device.deviceTypeName == deviceTypeName)
        .toList();
  }
}
