import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_ftms/flutter_ftms.dart';

/// Wrapper around BluetoothDevice that provides demo functionality
/// This wraps a real BluetoothDevice.fromId to get a valid BluetoothDevice instance
/// while providing demo-specific behavior
class DemoFtmsDevice extends BluetoothDevice {
  final String _deviceId;
  final DeviceDataType deviceType;


  bool _isConnected = false;
  bool _isDisconnected = true;
  BluetoothConnectionState _lastConnectionState = BluetoothConnectionState.disconnected;

  final StreamController<BluetoothConnectionState> _connectionStateController =
  StreamController<BluetoothConnectionState>.broadcast();

  // Data simulation state
  int _strokeCount = 0;
  int _totalDistance = 0;
  int _totalCalories = 0;
  double _elapsedTimeSeconds = 0;
  int _resistanceLevel = 50; // Default resistance level

  // Demo state
  BluetoothCharacteristic? _dataCharacteristic;
  Timer? _dataEmissionTimer;

  DemoFtmsDevice({
    required String deviceId,
    required this.deviceType,
    required super.remoteId,
  }) : _deviceId = deviceId {
    // Create a BluetoothDevice using the fromId constructor
    // Note: This won't work for actual BLE operations but provides a valid object
  }

  /// Device ID
  String get deviceId => _deviceId;

  /// Whether the device is connected
  @override
  bool get isConnected => _isConnected;

  @override
  bool get isDisconnected => _isDisconnected;

  /// Stream of connection state changes
  /// Returns a stream that emits the current state immediately when subscribed,
  /// followed by any future state changes
  @override
  Stream<BluetoothConnectionState> get connectionState {
    final controller = StreamController<BluetoothConnectionState>();
    // Emit current state immediately
    controller.add(_lastConnectionState);
    // Forward future events
    _connectionStateController.stream.listen(
      controller.add,
      onError: controller.addError,
      onDone: controller.close,
    );
    return controller.stream;
  }

  List<BluetoothService> _fakeServicesList = [];
  @override
  List<BluetoothService> get servicesList  => _fakeServicesList;
  @override
  Future<List<BluetoothService>> discoverServices(
      {bool subscribeToServicesChanged = true, int timeout = 15}) async {
    // Create mock FTMS service (UUID 1826) with multiple characteristics
    final ftmsServiceUuid = Guid('00001826-0000-1000-8000-00805f9b34fb');

    // Determine which data characteristic UUID based on device type
    final dataCharacteristicUuid = Guid('00002ad1-0000-1000-8000-00805f9b34fb');  // Rower Data

    // Control Point characteristic (0x2AD9) - required for FTMS control operations
    final controlPointUuid = Guid('00002ad9-0000-1000-8000-00805f9b34fb');

    // Supported Resistance Level Range characteristic (0x2AD6) - read-only
    final supportedResistanceUuid = Guid('00002ad6-0000-1000-8000-00805f9b34fb');

    // Create the data characteristic
    final dataCharacteristic = _MockBluetoothCharacteristic(
      remoteId: remoteId,
      serviceUuid: ftmsServiceUuid,
      characteristicUuid: dataCharacteristicUuid,
      primaryServiceUuid: null,
      onWrite: null, // Data characteristic is read-only for notifications
    );
    _dataCharacteristic = dataCharacteristic;
    // Set initial data for the data characteristic
    final initialData = _buildRowerBytes(
      strokeRate: 24,
      strokeCount: 0,
      totalDistance: 0,
      instantaneousPace: 120,
      instantaneousPower: 150,
      totalEnergy: 0,
      energyPerHour: 540,
      energyPerMinute: 9,
      heartRate: 120,
      elapsedTime: 0,
    );
    dataCharacteristic.emitData(initialData);

    // Create the control point characteristic with write capability
    final controlPointCharacteristic = _MockBluetoothCharacteristic(
      remoteId: remoteId,
      serviceUuid: ftmsServiceUuid,
      characteristicUuid: controlPointUuid,
      primaryServiceUuid: null,
      onWrite: _handleControlPointWrite,
    );

    // Create the supported resistance level range characteristic (read-only)
    final supportedResistanceCharacteristic = _MockBluetoothCharacteristic(
      remoteId: remoteId,
      serviceUuid: ftmsServiceUuid,
      characteristicUuid: supportedResistanceUuid,
      primaryServiceUuid: null,
      onWrite: null, // Read-only
    );
    // Set the supported range: min 10, max 150, increment 10
    supportedResistanceCharacteristic.emitData([10, 0, 150, 0, 10, 0]);

    // Create the FTMS service with both characteristics
    final ftmsService = _MockBluetoothService(
      remoteId: remoteId,
      serviceUuid: ftmsServiceUuid,
      primaryServiceUuid: null,
      characteristics: [dataCharacteristic, controlPointCharacteristic, supportedResistanceCharacteristic],
    );
    _fakeServicesList = [ftmsService];
    return [ftmsService];
  }


  /// Connect to the demo device
  @override
  Future<void> connect({
    required License license,
    Duration timeout = const Duration(seconds: 35),
    int? mtu = 512,
    bool autoConnect = false,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _isConnected = true;
    _isDisconnected = false;
    _lastConnectionState = BluetoothConnectionState.connected;
    _connectionStateController.add(BluetoothConnectionState.connected);
  }

  /// Disconnect from the demo device
  @override
  Future<void> disconnect({
    int timeout = 35,
    bool queue = true,
    int androidDelay = 2000,
  }) async {
    _stopDataEmission();
    _dataCallback = null;
    _isConnected = false;
    _isDisconnected = true;
    _lastConnectionState = BluetoothConnectionState.disconnected;
    _connectionStateController.add(BluetoothConnectionState.disconnected);
  }

  /// Start emitting fake FTMS data
  void Function(DeviceData)? _dataCallback;

  void startDataEmission(void Function(DeviceData) callback) {
    debugPrint('🎭 DEMO: startDataEmission called');
    _dataCallback = callback;
    debugPrint('🎭 DEMO: ✅ Callback registered');
  }

  /// Parse FTMS bytes into DeviceData and send to callback
  void _emitParsedData(List<int> bytes) {
    if (_dataCallback == null) {
      debugPrint('🎭 DEMO: No callback registered, skipping data emission');
      return;
    }
    
    if (bytes.isEmpty) return;

    try {
      final deviceData = Rower(bytes);
      debugPrint('🎭 DEMO: ✅ Parsed ${bytes.length} bytes, calling callback');
      _dataCallback!(deviceData);
    } catch (e) {
      debugPrint('🎭 DEMO: ❌ Failed to parse data: $e');
    }
  }

  void _stopDataEmission() {
    _dataEmissionTimer?.cancel();
    _dataEmissionTimer = null;
  }

  /// Start emitting fake FTMS data to the callback
  void _startDataEmission() {
    _stopDataEmission();

    _dataEmissionTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      final bytes = _generateFakeDataBytes();
      debugPrint('🎭 DEMO: Timer tick, emitting ${bytes.length} bytes');
      // Emit to stream for any stream listeners
      if (_dataCharacteristic != null) {
        (_dataCharacteristic as _MockBluetoothCharacteristic).emitData(bytes);
      }
      // Also directly call the callback
      _emitParsedData(bytes);
    });
  }

  /// Generate fake FTMS data bytes
  List<int> _generateFakeDataBytes() {
    _elapsedTimeSeconds += 0.5;

    return _generateRowerDataBytes();
  }

  List<int> _generateRowerDataBytes() {
    // Simulate realistic rowing data
    final random = Random();

    // Stroke rate: 20-30 strokes per minute
    final strokeRate = 22 + random.nextInt(8);

    // Power: 100-300 watts with some variation
    final basePower = 150 + sin(_elapsedTimeSeconds * 0.1) * 50;
    final power = (basePower + random.nextInt(30) - 15).round().clamp(80, 350);

    // Speed: 2.5-4.5 m/s
    final speed =
        3.0 +
            sin(_elapsedTimeSeconds * 0.05) * 0.5 +
            (random.nextDouble() - 0.5) * 0.3;

    // Increment cumulative values
    if (_elapsedTimeSeconds % 2 < 0.5) {
      _strokeCount += 1;
    }
    _totalDistance += (speed * 0.5).round();
    _totalCalories += (power * 0.5 / 4186).round().clamp(
      0,
      1,
    ); // Rough calorie calculation

    // Calculate pace (time per 500m in seconds)
    final paceSeconds = speed > 0 ? (500 / speed).round() : 0;

    return _buildRowerBytes(
      strokeRate: strokeRate,
      strokeCount: _strokeCount,
      totalDistance: _totalDistance,
      instantaneousPace: paceSeconds,
      instantaneousPower: power,
      totalEnergy: _totalCalories,
      energyPerHour: (power * 3.6 / 4.186).round(),
      energyPerMinute: (power / 69.78).round(),
      heartRate: 120 + random.nextInt(20),
      elapsedTime: _elapsedTimeSeconds.round(),
    );
  }

  /// Build rower data bytes according to FTMS Rower Data characteristic format
  List<int> _buildRowerBytes({
    required int strokeRate,
    required int strokeCount,
    required int totalDistance,
    required int instantaneousPace,
    required int instantaneousPower,
    required int totalEnergy,
    required int energyPerHour,
    required int energyPerMinute,
    required int heartRate,
    required int elapsedTime,
  }) {
    // Flags field (2 bytes) - set all flags we're providing
    // Bit 0: More Data (0 = all data in this packet)
    // Bit 1: Average Stroke Rate (1 = present)
    // Bit 2: Total Distance (1 = present)
    // Bit 3: Instantaneous Pace (1 = present)
    // Bit 4: Average Pace (1 = present)
    // Bit 5: Instantaneous Power (1 = present)
    // Bit 6: Average Power (1 = present)
    // Bit 7: Resistance Level (1 = present)
    // Bit 8: Expended Energy (1 = present)
    // Bit 9: Heart Rate (1 = present)
    // Bit 10: Metabolic Equivalent (0 = not present)
    // Bit 11: Elapsed Time (1 = present)
    // Bit 12: Remaining Time (0 = not present)
    const flags = 0x0BFE; // Include all fields we have data for

    final bytes = <int>[
      flags & 0xFF,
      // Flags byte 0
      (flags >> 8) & 0xFF,
      // Flags byte 1
      (strokeRate * 2) & 0xFF,
      // Stroke Rate (unit 0.5 /min, so multiply by 2)
      strokeCount & 0xFF,
      // Stroke Count low byte
      (strokeCount >> 8) & 0xFF,
      // Stroke Count high byte
      (strokeRate * 2) & 0xFF,
      // Average Stroke Rate (same as stroke rate for simplicity)
      totalDistance & 0xFF,
      // Total Distance low byte
      (totalDistance >> 8) & 0xFF,
      (totalDistance >> 16) & 0xFF,
      instantaneousPace & 0xFF,
      // Pace low byte
      (instantaneousPace >> 8) & 0xFF,
      instantaneousPace & 0xFF,
      // Average Pace (same for simplicity)
      (instantaneousPace >> 8) & 0xFF,
      instantaneousPower & 0xFF,
      // Power low byte
      (instantaneousPower >> 8) & 0xFF,
      instantaneousPower & 0xFF,
      // Average Power (same for simplicity)
      (instantaneousPower >> 8) & 0xFF,
      _resistanceLevel & 0xFF,
      // Resistance Level low byte
      (_resistanceLevel >> 8) & 0xFF,
      // Resistance Level high byte
      totalEnergy & 0xFF,
      // Energy low byte
      (totalEnergy >> 8) & 0xFF,
      energyPerHour & 0xFF,
      // Energy per hour low byte
      (energyPerHour >> 8) & 0xFF,
      energyPerMinute & 0xFF,
      // Energy per minute
      heartRate & 0xFF,
      // Heart Rate
      elapsedTime & 0xFF,
      // Elapsed Time low byte
      (elapsedTime >> 8) & 0xFF,
    ];

    return bytes;
  }

  /// Handle writes to the FTMS Control Point characteristic
  void _handleControlPointWrite(List<int> value) {
    if (value.isEmpty) return;

    final command = value[0];
    switch (command) {
      case 0x00: // Request Control
      // Grant control - no specific action needed for demo
        break;
      case 0x01: // Reset
        _stopDataEmission();
        // Reset simulation state
        _strokeCount = 0;
        _totalDistance = 0;
        _totalCalories = 0;
        _elapsedTimeSeconds = 0;
        break;
      case 0x04: // Set Target Resistance Level
        if (value.length > 1) {
          int newLevel = value[1];
          // Clamp to 10-150
          newLevel = newLevel.clamp(10, 150);
          // Round to nearest 10
          _resistanceLevel = ((newLevel / 10).round() * 10).clamp(10, 150);
          debugPrint('🎭 DEMO: Resistance level set to $_resistanceLevel via control point');
        }
        break;
      case 0x07: // Start or Resume
        _startDataEmission();
        break;
      case 0x08: // Stop or Pause
        _stopDataEmission();
        break;
      default:
      // Unknown command - ignore
        break;
    }
  }

  /// Find the control point characteristic
  BluetoothCharacteristic? _findControlPointCharacteristic() {
    for (final service in _fakeServicesList) {
      for (final char in service.characteristics) {
        if (char.characteristicUuid == Guid('00002ad9-0000-1000-8000-00805f9b34fb')) {
          return char;
        }
      }
    }
    return null;
  }

  /// FTMS Control Operations
  Future<void> requestControl() async {
    final controlPoint = _findControlPointCharacteristic();
    if (controlPoint != null) {
      await controlPoint.write([0x00]); // Request Control command
    }
  }

  Future<void> reset() async {
    final controlPoint = _findControlPointCharacteristic();
    if (controlPoint != null) {
      await controlPoint.write([0x01]); // Reset command
    }
  }

  Future<void> startOrResume() async {
    final controlPoint = _findControlPointCharacteristic();
    if (controlPoint != null) {
      await controlPoint.write([0x07]); // Start or Resume command
    }
  }

  Future<void> stopOrPause() async {
    final controlPoint = _findControlPointCharacteristic();
    if (controlPoint != null) {
      await controlPoint.write([0x08]); // Stop or Pause command
    }
  }

  /// Set resistance level (10-150, increments of 10)
  Future<void> setResistanceLevel(int level) async {
    // Clamp and round to nearest 10
    level = level.clamp(10, 150);
    level = ((level / 10).round() * 10).clamp(10, 150);
    
    final controlPoint = _findControlPointCharacteristic();
    if (controlPoint != null) {
      await controlPoint.write([0x04, level]); // Set Target Resistance Level command
    } else {
      // Fallback: set directly
      _resistanceLevel = level;
    }
  }
}

/// Mock BluetoothCharacteristic for demo service discovery
class _MockBluetoothCharacteristic extends BluetoothCharacteristic {
  final void Function(List<int> value)? onWrite;

  final StreamController<List<int>> _valueController = StreamController<List<int>>.broadcast();
  List<int> _lastValue = [];
  late final Stream<List<int>> _stream;

  _MockBluetoothCharacteristic({
    required super.remoteId,
    required super.serviceUuid,
    required super.characteristicUuid,
    super.primaryServiceUuid,
    this.onWrite,
  }) {
    // Cache the stream to ensure the same instance is always returned
    _stream = _valueController.stream;
  }

  @override
  Stream<List<int>> get onValueReceived => _stream;

  @override
  List<int> get lastValue => _lastValue;

  bool get hasListener => _valueController.hasListener;

  void emitData(List<int> data) {
    _lastValue = data;
    debugPrint('🎭 MOCK CHAR: emitData called with ${data.length} bytes, hasListener: ${_valueController.hasListener}');
    _valueController.add(data);
    debugPrint('🎭 MOCK CHAR: Data added to stream controller');
  }

  @override
  Future<void> write(List<int> value, {bool withoutResponse = false, bool allowLongWrite = false, int timeout = 15}) async {
    if (onWrite != null) {
      onWrite!(value);
    }
    // Update last value for readable characteristics
    if (properties.read) {
      _lastValue = value;
    }
    // Simulate write delay
    await Future.delayed(const Duration(milliseconds: 50));
  }

  @override
  Future<List<int>> read({int timeout = 15}) async {
    // For demo purposes, return last value for readable characteristics
    if (properties.read) {
      // Simulate read delay
      await Future.delayed(const Duration(milliseconds: 20));
      return _lastValue;
    } else {
      // Characteristic doesn't support read
      throw Exception('Characteristic does not support read operation');
    }
  }

  @override
  CharacteristicProperties get properties {
    // For control point, allow write and indicate
    if (characteristicUuid == Guid('00002ad9-0000-1000-8000-00805f9b34fb')) {
      return CharacteristicProperties(
        broadcast: false,
        read: true,
        writeWithoutResponse: true,
        write: true,
        notify: false,
        indicate: true,
        authenticatedSignedWrites: false,
        extendedProperties: false,
        notifyEncryptionRequired: false,
        indicateEncryptionRequired: false,
      );
    }
    // For supported resistance level range, allow read
    if (characteristicUuid == Guid('00002ad6-0000-1000-8000-00805f9b34fb')) {
      return CharacteristicProperties(
        broadcast: false,
        read: true,
        writeWithoutResponse: false,
        write: false,
        notify: false,
        indicate: false,
        authenticatedSignedWrites: false,
        extendedProperties: false,
        notifyEncryptionRequired: false,
        indicateEncryptionRequired: false,
      );
    }
    // For data characteristics, allow notify
    return CharacteristicProperties(
      broadcast: false,
      read: true,
      writeWithoutResponse: false,
      write: false,
      notify: true,
      indicate: false,
      authenticatedSignedWrites: false,
      extendedProperties: false,
      notifyEncryptionRequired: false,
      indicateEncryptionRequired: false,
    );
  }

  @override
  Future<bool> setNotifyValue(bool notify, {int timeout = 15, bool forceIndications = false}) async  {
    // No-op for demo
    await Future.delayed(const Duration(milliseconds: 20));
    return notify;
  }

  @override
  List<BluetoothDescriptor> get descriptors {
    // For characteristics that support indicate/notify, add CCCD descriptor
    if (properties.indicate || properties.notify) {
      return [
        _MockBluetoothDescriptor(
          remoteId: remoteId,
          serviceUuid: serviceUuid,
          characteristicUuid: characteristicUuid,
          descriptorUuid: Guid('00002902-0000-1000-8000-00805f9b34fb'), // CCCD
        ),
      ];
    }
    return [];
  }
}

/// Mock BluetoothDescriptor for demo CCCD
class _MockBluetoothDescriptor extends BluetoothDescriptor {
  _MockBluetoothDescriptor({
    required super.remoteId,
    required super.serviceUuid,
    required super.characteristicUuid,
    required super.descriptorUuid,
  });

  @override
  Future<void> write(List<int> value, {bool allowLongWrite = false, int timeout = 15}) async {
    // For CCCD, value [0x02, 0x00] enables indications, [0x00, 0x00] disables
    // Just succeed for demo
    await Future.delayed(const Duration(milliseconds: 20));
  }
}

/// Mock BluetoothService for demo service discovery
/// Creates a service object by implementing the interface
class _MockBluetoothService implements BluetoothService {
  @override
  final DeviceIdentifier remoteId;

  @override
  final Guid? primaryServiceUuid;

  @override
  final Guid serviceUuid;

  @override
  final List<BluetoothCharacteristic> characteristics;

  _MockBluetoothService({
    required this.remoteId,
    required this.serviceUuid,
    required this.primaryServiceUuid,
    required this.characteristics,
  });

  @override
  Guid get uuid => serviceUuid;

  @override
  DeviceIdentifier get deviceId => remoteId;

  @override
  bool get isPrimary => primaryServiceUuid == null;

  @override
  bool get isSecondary => primaryServiceUuid != null;

  @override
  List<BluetoothService> get includedServices => [];

  @override
  BluetoothService? get primaryService => null;
}