import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../utils/logger.dart';

/// Service for managing Cadence Sensor devices
class CadenceService {
  static final CadenceService _instance = CadenceService._internal();
  factory CadenceService() => _instance;
  CadenceService._internal();

  /// only one cadence device can be connected at a time
  BluetoothDevice? _connectedCadenceDevice;
  BluetoothCharacteristic? _cadenceCharacteristic;
  StreamSubscription<List<int>>? _cadenceSubscription;
  Timer? _cadenceTimeoutTimer;
  
  final StreamController<int?> _cadenceController = StreamController<int?>.broadcast();
  
  /// Stream of cadence values from connected cadence device
  Stream<int?> get cadenceStream => _cadenceController.stream;
  
  /// Current cadence value from cadence device
  int? get currentCadence => _currentCadence;
  int? _currentCadence;
  
  /// Whether a cadence device is currently connected
  bool get isCadenceConnected => _connectedCadenceDevice != null && _cadenceCharacteristic != null;
  
  /// Connected cadence device name
  String? get connectedDeviceName => _connectedCadenceDevice?.platformName;

  static const String cadenceServiceUuid = "00001816";
  static const String cadenceServiceUuidShort = "1816";
  static const String cadenceMeasurementCharacteristicUuid = "00002A5B";
  static const String cadenceMeasurementCharacteristicUuidShort = "2A5B";

  /// Connect to a cadence device and start receiving cadence data
  Future<bool> connectToCadenceDevice(BluetoothDevice device) async {
    try {
      logger.i('Connecting to Cadence device: ${device.platformName}');
      
      // Disconnect any existing cadence device first
      await disconnectCadenceDevice();
      
      // Connect to the device with autoConnect for automatic reconnection
      // This ensures the device will automatically reconnect when it becomes available
      // after any disconnection (e.g., during training sessions)
      // Note: mtu must be null when using autoConnect
      await device.connect(autoConnect: true, mtu: null, license: License.free);
      
      // Wait for the device to be actually connected before proceeding
      if (!device.isConnected) {
        // Wait for connection state to become connected
        await device.connectionState
            .where((state) => state == BluetoothConnectionState.connected)
            .first
            .timeout(Duration(seconds: 10));
      }
      
      // Discover services
      final services = await device.discoverServices();
      
      // Find cadence service
      BluetoothService? cadenceService = _findCadenceService(services);
      
      if (cadenceService == null) {
        logger.w('Cadence service not found on device ${device.platformName}');
        await device.disconnect();
        return false;
      }
      
      // Find cadence measurement characteristic
      BluetoothCharacteristic? cadenceCharacteristic = _findCadenceCharacteristic(cadenceService);
      
      if (cadenceCharacteristic == null) {
        logger.w('Cadence measurement characteristic not found on device ${device.platformName}');
        await device.disconnect();
        return false;
      }
      
      // Enable notifications
      await cadenceCharacteristic.setNotifyValue(true);
      
      // Subscribe to cadence data
      _cadenceSubscription = _listenToCadenceCharacteristic(cadenceCharacteristic);
      
      // Store connection details
      _connectedCadenceDevice = device;
      _cadenceCharacteristic = cadenceCharacteristic;
      
      // Start timeout timer to detect when pedaling stops
      _startCadenceTimeoutTimer();
      
      // Listen for connection state changes to handle both disconnection and reconnection
      device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          logger.i('Cadence device disconnected - waiting for autoConnect reconnection');
          _handleDisconnection();
        } else if (state == BluetoothConnectionState.connected) {
          logger.i('Cadence device reconnected - re-establishing data stream');
          _handleReconnection(device);
        }
      });
      
      logger.i('Successfully connected to Cadence device: ${device.platformName}');
      return true;
      
    } catch (e) {
      logger.e('Failed to connect to Cadence device: $e');
      await device.disconnect().catchError((_) {});
      return false;
    }
  }

  StreamSubscription<List<int>> _listenToCadenceCharacteristic(BluetoothCharacteristic cadenceCharacteristic) {
    return cadenceCharacteristic.lastValueStream.listen(
      _parseCadenceData,
      onError: (error) {
        logger.e('Error receiving cadence data: $error');
      },
    );
  }

  BluetoothCharacteristic? _findCadenceCharacteristic(BluetoothService cadenceService) {
     BluetoothCharacteristic? cadenceCharacteristic;
    for (final characteristic in cadenceService.characteristics) {
      final characteristicUuidString = characteristic.uuid.toString().toUpperCase();
      if (characteristicUuidString == cadenceMeasurementCharacteristicUuid.toUpperCase() ||
          characteristicUuidString == cadenceMeasurementCharacteristicUuidShort.toUpperCase()) {
        cadenceCharacteristic = characteristic;
        break;
      }
    }
    return cadenceCharacteristic;
  }

  BluetoothService? _findCadenceService(List<BluetoothService> services) {
    BluetoothService? cadenceService;
    for (final service in services) {
      final serviceUuidString = service.uuid.toString().toUpperCase();
      if (serviceUuidString == cadenceServiceUuid.toUpperCase() ||
          serviceUuidString == cadenceServiceUuidShort.toUpperCase()) {
        cadenceService = service;
        break;
      }
    }
    return cadenceService;
  }
  
  /// Disconnect from the current cadence device
  Future<void> disconnectCadenceDevice() async {
    if (_connectedCadenceDevice != null) {
      try {
        logger.i('Disconnecting from Cadence device: ${_connectedCadenceDevice!.platformName}');
        await _cadenceSubscription?.cancel();
        await _connectedCadenceDevice!.disconnect();
      } catch (e) {
        logger.e('Error disconnecting from Cadence device: $e');
      }
    }
    _handleDisconnection();
  }
  
  void _handleDisconnection() {
    _cadenceSubscription?.cancel();
    _cadenceSubscription = null;
    _stopCadenceTimeoutTimer();
    _connectedCadenceDevice = null;
    _cadenceCharacteristic = null;
    _currentCadence = null;
    _lastCrankRevolutions = null;
    _lastCrankEventTime = null;
    _lastUpdateTime = null;
    _cadenceHistory.clear();
    _cadenceController.add(null);
    logger.i('Cadence device disconnected');
  }
  
  /// Handle device reconnection by re-establishing data streams
  Future<void> _handleReconnection(BluetoothDevice device) async {
    try {
      // Clear any existing subscriptions first
      _cadenceSubscription?.cancel();
      _cadenceSubscription = null;
      _stopCadenceTimeoutTimer();
      
      // Wait a moment for the connection to stabilize
      await Future.delayed(Duration(milliseconds: 500));
      
      // Rediscover services to get fresh service references
      final services = await device.discoverServices();
      final cadenceService = _findCadenceService(services);
      
      if (cadenceService == null) {
        logger.w('Cadence service not found after reconnection');
        return;
      }
      
      final cadenceCharacteristic = _findCadenceCharacteristic(cadenceService);
      if (cadenceCharacteristic == null) {
        logger.w('Cadence characteristic not found after reconnection');
        return;
      }
      
      // Re-enable notifications
      await cadenceCharacteristic.setNotifyValue(true);
      
      // Re-subscribe to cadence data
      _cadenceSubscription = _listenToCadenceCharacteristic(cadenceCharacteristic);
      
      // Update stored references
      _connectedCadenceDevice = device;
      _cadenceCharacteristic = cadenceCharacteristic;
      
      // Restart the timeout timer
      _startCadenceTimeoutTimer();
      
      logger.i('Cadence data stream re-established after reconnection');
    } catch (e) {
      logger.e('Failed to re-establish cadence data stream after reconnection: $e');
    }
  }
  
  /// Parse cadence data from BLE characteristic
  void _parseCadenceData(List<int> data) {
    if (data.isEmpty) return;
    
    try {
      // Log raw data for debugging
      logger.d('Received cadence data: $data (length: ${data.length})');
      
      // Parse according to CSC Measurement format
      // The CSC measurement characteristic contains wheel revolution data and crank revolution data
      // Minimum 1 byte for flags, but actual data depends on what's included
      if (data.isEmpty) return; // Need at least flags byte
      
      final flags = data[0];
      int cadence = 0;
      
      logger.d('CSC flags: 0x${flags.toRadixString(16).padLeft(2, '0')} (wheel: ${(flags & 0x01) != 0}, crank: ${(flags & 0x02) != 0})');
      
      // Check if crank revolution data is present (bit 1 of flags)
      if ((flags & 0x02) != 0) {
        // Find crank revolution data position
        int offset = 1;
        
        // Skip wheel revolution data if present (bit 0 of flags)
        if ((flags & 0x01) != 0) {
          offset += 6; // 4 bytes cumulative wheel revolutions + 2 bytes last wheel event time
        }
        
        // Check if we have enough data for crank revolution data (4 bytes minimum)
        if (data.length >= offset + 4) {
          // Extract crank revolution count (2 bytes) and last crank event time (2 bytes)
          final crankRevolutions = data[offset] + (data[offset + 1] << 8);
          final lastCrankEventTime = data[offset + 2] + (data[offset + 3] << 8);
          
          logger.d('Crank data: revolutions=$crankRevolutions, eventTime=$lastCrankEventTime (raw bytes: [${data[offset]}, ${data[offset + 1]}, ${data[offset + 2]}, ${data[offset + 3]}])');
          
          // Calculate cadence if we have previous data
          if (_lastCrankRevolutions != null && _lastCrankEventTime != null) {
            var revDiff = crankRevolutions - _lastCrankRevolutions!;
            var timeDiff = lastCrankEventTime - _lastCrankEventTime!;
            
            // Handle revolution counter rollover (16-bit counter)
            if (revDiff < 0) {
              revDiff += 65536;
            }
            
            // Handle time rollover (16-bit counter)
            if (timeDiff < 0) {
              timeDiff += 65536;
            }
            
            logger.d('Rev diff: $revDiff, time diff: $timeDiff');
            
            if (timeDiff > 0 && revDiff > 0) {
              // Convert to RPM (revolutions per minute)
              // Time unit is 1/1024 seconds according to CSC specification
              // Formula: (revolutions / time_in_seconds) * 60 = RPM
              // where time_in_seconds = timeDiff / 1024
              final timeInSeconds = timeDiff / 1024.0;
              
              // Calculate base cadence - sensor counts pedal strokes, so divide by 2 for full revolutions
              final baseCadence = (revDiff / timeInSeconds) * 60.0;
              cadence = (baseCadence * _cadenceMultiplier).round();
              
              // Additional validation - cadence should be reasonable
              if (cadence > 300) {
                logger.w('Calculated cadence too high: $cadence, capping at 300');
                cadence = 300;
              } else if (cadence < 3) {
                // Filter out very low cadence values that might be noise (reduced threshold for responsiveness)
                cadence = 0;
              }
              
              logger.d('Calculated cadence: $cadence rpm (base: ${baseCadence.toStringAsFixed(1)}, multiplier: $_cadenceMultiplier, revDiff: $revDiff, timeInSeconds: ${timeInSeconds.toStringAsFixed(3)}s)');
            } else if (revDiff == 0) {
              // No new revolutions - this means we're still receiving data but no pedaling
              cadence = 0;
              logger.d('No new revolutions, setting cadence to 0');
            } else if (revDiff > 0 && timeDiff == 0) {
              // Revolution count increased but no time passed - keep previous cadence
              logger.d('Revolution increased but no time diff, keeping previous cadence');
              cadence = _currentCadence ?? 0;
            }
          }
          
          _lastCrankRevolutions = crankRevolutions;
          _lastCrankEventTime = lastCrankEventTime;
          _lastUpdateTime = DateTime.now().millisecondsSinceEpoch;
        } else {
          logger.w('Insufficient data for crank revolution data: need ${offset + 4} bytes, got ${data.length}');
        }
      } else {
        logger.w('Crank revolution data not present in flags');
      }
      
      // Validate cadence value and update stream
      if (cadence >= 0 && cadence <= 300) {
        // For rapid changes, use less smoothing to be more responsive
        final finalCadence = cadence > 0 ? _adaptiveSmoothing(cadence) : 0;
        
        // Clear history when cadence goes to 0 for clean restart
        if (finalCadence == 0) {
          _cadenceHistory.clear();
        }
        
        _currentCadence = finalCadence;
        _cadenceController.add(finalCadence);
        logger.d('Final cadence: $finalCadence rpm (raw: $cadence rpm)');
      } else if (cadence > 300) {
        logger.w('Invalid cadence value received: $cadence');
      }
      
    } catch (e) {
      logger.e('Error parsing cadence data: $e');
    }
  }
  
  int? _lastCrankRevolutions;
  int? _lastCrankEventTime;
  int? _lastUpdateTime;
  final List<int> _cadenceHistory = [];
  static const int _maxHistorySize = 3; // Reduced from 5 for faster response
  
  // Cadence multiplier to handle different sensor interpretations
  // Some sensors count pedal strokes (half revolutions), others count full revolutions
  static const double _cadenceMultiplier = 1.0; // Simplified since we already divide by 2 in calculation
  
  /// Start a timer to detect when pedaling has stopped
  void _startCadenceTimeoutTimer() {
    _cadenceTimeoutTimer?.cancel();
    _cadenceTimeoutTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
      if (_lastUpdateTime != null) {
        final currentTime = DateTime.now().millisecondsSinceEpoch;
        final timeSinceLastUpdate = currentTime - _lastUpdateTime!;
        
        // If more than 1.5 seconds since last update and we have a non-zero cadence, set to 0
        if (timeSinceLastUpdate > 1500 && _currentCadence != null && _currentCadence! > 0) {
          _currentCadence = 0;
          _cadenceController.add(0);
          logger.d('Cadence timeout: setting to 0 after ${timeSinceLastUpdate}ms of no data');
        }
      }
    });
  }

  /// Stop the cadence timeout timer
  void _stopCadenceTimeoutTimer() {
    _cadenceTimeoutTimer?.cancel();
    _cadenceTimeoutTimer = null;
  }

  /// Check if a device is a Cadence Sensor device
  static bool isCadenceDevice(BluetoothDevice device, List<ScanResult> scanResults) {
    try {
      // Check if the device advertises Cadence Service in scan results
      final scanResult = scanResults.firstWhere(
        (result) => result.device.remoteId == device.remoteId,
        orElse: () => ScanResult(
          device: device,
          advertisementData: AdvertisementData(
            advName: '',
            txPowerLevel: null,
            appearance: null,
            connectable: false,
            manufacturerData: {},
            serviceData: {},
            serviceUuids: [],
          ),
          rssi: 0,
          timeStamp: DateTime.now(),
        ),
      );
      
      // Check if Cadence Service UUID is advertised
      final advertisedServices = scanResult.advertisementData.serviceUuids
          .map((uuid) => uuid.toString().toUpperCase())
          .toList();
      
      // Check for both full UUID and short UUID
      return advertisedServices.contains(cadenceServiceUuid.toUpperCase()) || 
             advertisedServices.contains(cadenceServiceUuidShort.toUpperCase());
    } catch (e) {
      return false;
    }
  }

  /// Apply adaptive smoothing that responds faster to rapid changes
  int _adaptiveSmoothing(int rawCadence) {
    // If we have previous cadence, check for rapid changes
    if (_currentCadence != null && _currentCadence! > 0) {
      final changePct = ((rawCadence - _currentCadence!).abs() / _currentCadence!) * 100;
      
      // If change is more than 20%, use minimal smoothing for responsiveness
      if (changePct > 20) {
        logger.d('Rapid cadence change detected (${changePct.toStringAsFixed(1)}%), using minimal smoothing');
        return _minimalSmoothing(rawCadence);
      }
    }
    
    // For normal changes, use regular weighted smoothing
    return _smoothCadence(rawCadence);
  }
  
  /// Minimal smoothing for rapid changes - only use last 2 values
  int _minimalSmoothing(int rawCadence) {
    if (_cadenceHistory.isEmpty) {
      _cadenceHistory.add(rawCadence);
      return rawCadence;
    }
    
    // Use simple average of current and last value for responsiveness
    final lastValue = _cadenceHistory.last;
    final smoothed = ((rawCadence + lastValue) / 2).round();
    
    // Update history
    _cadenceHistory.add(rawCadence);
    if (_cadenceHistory.length > _maxHistorySize) {
      _cadenceHistory.removeAt(0);
    }
    
    logger.d('Minimal smoothing: raw=$rawCadence, last=$lastValue, smoothed=$smoothed');
    return smoothed;
  }
  
  /// Apply responsive smoothing to cadence readings using weighted moving average
  int _smoothCadence(int rawCadence) {
    _cadenceHistory.add(rawCadence);
    
    // Keep only the last N readings
    if (_cadenceHistory.length > _maxHistorySize) {
      _cadenceHistory.removeAt(0);
    }
    
    // Calculate weighted average with more weight on recent readings
    if (_cadenceHistory.isEmpty) return rawCadence;
    
    if (_cadenceHistory.length == 1) {
      return _cadenceHistory.first;
    }
    
    // Use weighted average: most recent value gets 50% weight, others split the remaining 50%
    final length = _cadenceHistory.length;
    final mostRecent = _cadenceHistory.last;
    final others = _cadenceHistory.take(length - 1).toList();
    
    final otherWeight = 0.5 / others.length;
    double weightedSum = mostRecent * 0.5;
    
    for (final value in others) {
      weightedSum += value * otherWeight;
    }
    
    final smoothed = weightedSum.round();
    
    logger.d('Cadence smoothing: raw=$rawCadence, history=$_cadenceHistory, smoothed=$smoothed (weighted)');
    return smoothed;
  }
}
