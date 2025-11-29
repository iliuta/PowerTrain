// This file was moved from lib/ftms_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_ftms/flutter_ftms.dart';
import 'zwift_protobuf.dart';
import '../models/zwift_trainer_data.dart';

typedef WriteMachineControlPointCharacteristic = Future<void> Function(
    BluetoothDevice device, MachineControlPoint controlPoint);

class FTMSService {
  final BluetoothDevice ftmsDevice;
  final WriteMachineControlPointCharacteristic writeCharacteristic;
  
  // Zwift proprietary service UUIDs (present on Zwift Hub)
  static const zwiftServiceUuid = '00000001-19ca-4651-86e5-fa29dcdd09d1';
  static const zwiftControlUuid = '00000003-19ca-4651-86e5-fa29dcdd09d1';
  static const zwiftNotifyUuid = '00000002-19ca-4651-86e5-fa29dcdd09d1';
  
  bool _zwiftInitialized = false;
  
  // Monitoring streams
  final _ridingDataController = StreamController<ZwiftRidingData>.broadcast();
  final _trainerControlController = StreamController<ZwiftTrainerControl>.broadcast();
  final _trainerStatusController = StreamController<ZwiftTrainerStatus>.broadcast();
  final _rawMessageController = StreamController<Map<String, dynamic>>.broadcast();
  
  ZwiftTrainerStatus _currentStatus = ZwiftTrainerStatus();
  
  /// Stream of riding data updates (0x03 messages)
  Stream<ZwiftRidingData> get ridingDataStream => _ridingDataController.stream;
  
  /// Stream of trainer control messages (0x04 messages)
  Stream<ZwiftTrainerControl> get trainerControlStream => _trainerControlController.stream;
  
  /// Stream of combined trainer status
  Stream<ZwiftTrainerStatus> get trainerStatusStream => _trainerStatusController.stream;
  
  /// Stream of raw decoded messages (for debugging)
  Stream<Map<String, dynamic>> get rawMessageStream => _rawMessageController.stream;
  
  /// Current trainer status snapshot
  ZwiftTrainerStatus get currentStatus => _currentStatus;

  FTMSService(this.ftmsDevice, {WriteMachineControlPointCharacteristic? writeCharacteristic})
      : writeCharacteristic = writeCharacteristic ?? FTMS.writeMachineControlPointCharacteristic;
  
  /// Dispose of all stream controllers
  void dispose() {
    _ridingDataController.close();
    _trainerControlController.close();
    _trainerStatusController.close();
    _rawMessageController.close();
  }
  
  /// Start monitoring Zwift proprietary protocol messages
  /// 
  /// Subscribe to notifications from the Zwift trainer to receive:
  /// - Riding data (0x03): power, cadence, speed, HR
  /// - Trainer control responses (0x04): current settings/acknowledgments
  /// - Other protocol messages
  /// 
  /// Call this before sending control commands to understand current trainer state
  Future<void> startMonitoring() async {
    try {
      debugPrint('🔍 Starting Zwift protocol monitoring...');
      
      final services = ftmsDevice.servicesList;
      final zwiftService = services.firstWhere(
        (s) => s.uuid.toString().toLowerCase() == zwiftServiceUuid.toLowerCase(),
        orElse: () => throw Exception('Zwift proprietary service not found'),
      );
      
      final notifyChar = zwiftService.characteristics.firstWhere(
        (c) => c.uuid.toString().toLowerCase() == zwiftNotifyUuid.toLowerCase(),
        orElse: () => throw Exception('Zwift notify characteristic not found'),
      );
      
      // Subscribe to notifications
      if (!notifyChar.isNotifying) {
        debugPrint('📡 Subscribing to Zwift notifications...');
        await notifyChar.setNotifyValue(true);
      }
      
      // Listen and decode messages
      notifyChar.lastValueStream.listen((data) {
        if (data.isEmpty) return;
        
        _handleZwiftMessage(data);
      });
      
      debugPrint('✅ Zwift monitoring started');
      debugPrint('   - Riding data stream: active');
      debugPrint('   - Trainer control stream: active');
    } catch (e) {
      debugPrint('❌ Failed to start monitoring: $e');
      rethrow;
    }
  }
  
  /// Stop monitoring (unsubscribe from notifications)
  Future<void> stopMonitoring() async {
    try {
      debugPrint('🔍 Stopping Zwift protocol monitoring...');
      
      final services = ftmsDevice.servicesList;
      final zwiftService = services.firstWhere(
        (s) => s.uuid.toString().toLowerCase() == zwiftServiceUuid.toLowerCase(),
        orElse: () => throw Exception('Zwift proprietary service not found'),
      );
      
      final notifyChar = zwiftService.characteristics.firstWhere(
        (c) => c.uuid.toString().toLowerCase() == zwiftNotifyUuid.toLowerCase(),
        orElse: () => throw Exception('Zwift notify characteristic not found'),
      );
      
      if (notifyChar.isNotifying) {
        await notifyChar.setNotifyValue(false);
        debugPrint('✅ Monitoring stopped');
      }
    } catch (e) {
      debugPrint('❌ Failed to stop monitoring: $e');
    }
  }
  
  /// Internal handler for incoming Zwift messages
  void _handleZwiftMessage(List<int> data) {
    try {
      // Log raw data
      debugPrint('📨 Zwift message: ${data.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}');
      
      // Decode using protobuf decoder
      final decoded = ZwiftProtobuf.decodeMessage(data);
      if (decoded == null) {
        debugPrint('⚠️  Failed to decode message');
        return;
      }
      
      debugPrint('   Type: ${decoded['type']}');
      
      // Emit raw message for debugging
      _rawMessageController.add(decoded);
      
      // Handle specific message types
      switch (decoded['type']) {
        case 'RidingData':
          final ridingData = ZwiftRidingData.fromProtobuf(decoded['data'] as Map<String, dynamic>);
          debugPrint('   $ridingData');
          
          _ridingDataController.add(ridingData);
          _currentStatus = _currentStatus.copyWith(ridingData: ridingData);
          _trainerStatusController.add(_currentStatus);
          break;
          
        case 'TrainerControl':
          final control = ZwiftTrainerControl.fromProtobuf(decoded['data'] as Map<String, dynamic>);
          debugPrint('   $control');
          
          _trainerControlController.add(control);
          _currentStatus = _currentStatus.copyWith(control: control);
          _trainerStatusController.add(_currentStatus);
          break;
          
        case 'InfoResponse':
          debugPrint('   Info: ${decoded['data']}');
          break;
          
        default:
          debugPrint('   Unknown message: ${decoded['data']}');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error handling message: $e');
      debugPrint('   Stack: $stackTrace');
    }
  }
  
  /// Request current trainer information
  /// 
  /// Sends a request for information (0x00) to query trainer state
  /// Parameter values:
  /// - 0: General info
  /// - 520: Current gear ratio (Wahoo Kickr Core)
  Future<void> requestTrainerInfo([int parameter = 0]) async {
    try {
      debugPrint('🔍 Requesting trainer info (param: $parameter)...');
      
      final services = ftmsDevice.servicesList;
      final zwiftService = services.firstWhere(
        (s) => s.uuid.toString().toLowerCase() == zwiftServiceUuid.toLowerCase(),
        orElse: () => throw Exception('Zwift proprietary service not found'),
      );
      
      final controlChar = zwiftService.characteristics.firstWhere(
        (c) => c.uuid.toString().toLowerCase() == zwiftControlUuid.toLowerCase(),
        orElse: () => throw Exception('Zwift control characteristic not found'),
      );
      
      final command = ZwiftProtobuf.encodeInfoRequest(parameter);
      
      debugPrint('📤 Info request: ${command.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}');
      
      if (controlChar.properties.writeWithoutResponse) {
        await controlChar.write(command, withoutResponse: true);
      } else if (controlChar.properties.write) {
        await controlChar.write(command, withoutResponse: false);
      }
      
      debugPrint('✅ Info request sent');
    } catch (e) {
      debugPrint('❌ Failed to request info: $e');
      rethrow;
    }
  }
  
  /// Try using FTMS Indoor Bike Simulation Parameters (OpCode 0x11)
  /// This bypasses the high-level flutter_ftms API to send raw bytes
  Future<void> setFtmsSimulationParameters({
    required double windSpeedMps,
    required double gradePercent,
    double crr = 0.004,
    double cwa = 0.51,
  }) async {
    try {
      debugPrint('🔧 Attempting FTMS Indoor Bike Simulation (OpCode 0x11)');
      debugPrint('   Wind: $windSpeedMps m/s, Grade: $gradePercent %, Crr: $crr, CWa: $cwa');
      
      // Find FTMS service and control point characteristic
      final services = ftmsDevice.servicesList;
      final ftmsService = services.firstWhere(
        (s) => s.uuid.toString().toLowerCase() == '00001826-0000-1000-8000-00805f9b34fb',
        orElse: () => throw Exception('FTMS service not found'),
      );
      
      final controlChar = ftmsService.characteristics.firstWhere(
        (c) => c.uuid.toString().toLowerCase() == '00002ad9-0000-1000-8000-00805f9b34fb',
        orElse: () => throw Exception('FTMS Control Point not found'),
      );
      
      // Build OpCode 0x11 packet according to FTMS spec
      // Format: [OpCode, WindSpeed (sint16), Grade (sint16), Crr (uint8), CWa (uint8)]
      final windSpeedInt = (windSpeedMps * 100).round().clamp(-32768, 32767);
      final gradeInt = (gradePercent * 100).round().clamp(-32768, 32767);
      final crrInt = (crr * 10000).round().clamp(0, 255);
      final cwaInt = (cwa * 100).round().clamp(0, 255);
      
      final command = [
        0x11, // OpCode: Set Indoor Bike Simulation Parameters
        windSpeedInt & 0xFF, (windSpeedInt >> 8) & 0xFF, // Wind speed (sint16, little-endian)
        gradeInt & 0xFF, (gradeInt >> 8) & 0xFF,         // Grade (sint16, little-endian)
        crrInt,  // Crr (uint8)
        cwaInt,  // CWa (uint8)
      ];
      
      debugPrint('📤 FTMS command: ${command.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}');
      
      await controlChar.write(command, withoutResponse: false);
      debugPrint('✅ FTMS simulation parameters sent');
    } catch (e) {
      debugPrint('❌ Failed to send FTMS simulation: $e');
      rethrow;
    }
  }
  
  Future<void> writeCommand(MachineControlPointOpcodeType opcodeType, {int? resistanceLevel, int? power}) async {
    MachineControlPoint? controlPoint;
    switch (opcodeType) {
      case MachineControlPointOpcodeType.requestControl:
        controlPoint = MachineControlPoint.requestControl();
        break;
      case MachineControlPointOpcodeType.reset:
        controlPoint = MachineControlPoint.reset();
        break;
      case MachineControlPointOpcodeType.setTargetSpeed:
        controlPoint = MachineControlPoint.setTargetSpeed(speed: 12);
        break;
      case MachineControlPointOpcodeType.setTargetInclination:
        controlPoint = MachineControlPoint.setTargetInclination(inclination: 23);
        break;
      case MachineControlPointOpcodeType.setTargetResistanceLevel:
        controlPoint = MachineControlPoint.setTargetResistanceLevel(resistanceLevel: resistanceLevel ?? 2);
        break;
      case MachineControlPointOpcodeType.setTargetPower:
        controlPoint = MachineControlPoint.setTargetPower(power: power ?? 150);
        break;
      case MachineControlPointOpcodeType.setTargetHeartRate:
        controlPoint = MachineControlPoint.setTargetHeartRate(heartRate: 45);
        break;
      case MachineControlPointOpcodeType.startOrResume:
        controlPoint = MachineControlPoint.startOrResume();
        break;
      case MachineControlPointOpcodeType.stopOrPause:
        controlPoint = MachineControlPoint.stopOrPause(pause: true);
        break;
    }

    await writeCharacteristic(ftmsDevice, controlPoint);
  }
  
  /// Initialize Zwift proprietary protocol session
  /// 
  /// This sends a request for information and sets up bike/rider parameters.
  /// Should be called before sending control commands.
  Future<void> initializeZwiftSession({
    double bikeWeightKg = 8.0,
    double riderWeightKg = 75.0,
  }) async {
    try {
      debugPrint('🔧 Initializing Zwift session...');
      
      final services = ftmsDevice.servicesList;
      final zwiftService = services.firstWhere(
        (s) => s.uuid.toString().toLowerCase() == zwiftServiceUuid.toLowerCase(),
        orElse: () => throw Exception('Zwift proprietary service not found'),
      );
      
      final notifyChar = zwiftService.characteristics.firstWhere(
        (c) => c.uuid.toString().toLowerCase() == zwiftNotifyUuid.toLowerCase(),
        orElse: () => throw Exception('Zwift notify characteristic not found'),
      );
      
      // Subscribe to notifications
      if (!notifyChar.isNotifying) {
        debugPrint('📡 Subscribing to Zwift notifications...');
        await notifyChar.setNotifyValue(true);
        notifyChar.lastValueStream.listen((data) {
          if (data.isNotEmpty) {
            debugPrint('📨 Zwift response: ${data.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}');
          }
        });
        // Longer delay to ensure subscription is stable
        await Future.delayed(Duration(milliseconds: 500));
      }
      
      // NOTE: According to makinolo.com blog, Zwift doesn't use PowerTarget with trainers
      // Only simulation mode is used. We'll skip initialization commands to avoid
      // overwhelming the trainer and focus on simulation-based control.
      
      _zwiftInitialized = true;
      debugPrint('✅ Zwift session initialized (simulation mode only)');
    } catch (e) {
      debugPrint('❌ Failed to initialize Zwift session: $e');
      rethrow;
    }
  }
  
  /// Zwift Proprietary Service: Simulate ERG mode using slope adjustment
  /// 
  /// NOTE: According to makinolo.com blog, Zwift doesn't actually use PowerTarget
  /// field with trainers - only simulation mode. This method uses a simplified
  /// power-to-grade conversion to simulate ERG mode behavior.
  /// 
  /// The approach: Calculate approximate incline grade needed to generate the
  /// target power at typical cycling speed (~25 km/h).
  /// 
  /// Simplified power formula: Power ≈ (Grade% × Gravity × Mass × Speed) / 100
  /// Therefore: Grade% ≈ (Power × 100) / (9.8 × Mass × Speed)
  /// 
  /// This is a rough approximation and won't match true ERG mode precision,
  /// but should provide basic resistance control for testing.
  /// 
  /// Tries both FTMS standard (OpCode 0x11) and Zwift proprietary protocols.
  Future<void> setZwiftPowerViaSlope(int targetWatts, {
    double riderMassKg = 75.0,
    double speedKmh = 25.0,
  }) async {
    try {
      debugPrint('🔧 Simulating ERG mode via slope: $targetWatts W');
      
      // Convert speed to m/s
      final speedMs = speedKmh / 3.6;
      
      // Calculate approximate grade needed for target power
      // Power = grade% × 9.8 × mass × speed / 100
      // Rearranged: grade% = (power × 100) / (9.8 × mass × speed)
      final gradePercent = (targetWatts * 100) / (9.8 * riderMassKg * speedMs);
      final gradePercentClamped = gradePercent.clamp(-20.0, 20.0); // Safety limits
      
      debugPrint('   Calculated grade: ${gradePercentClamped.toStringAsFixed(2)}%');
      debugPrint('   (Assuming $speedKmh km/h, $riderMassKg kg rider)');
      
      // Try FTMS standard protocol first (OpCode 0x11)
      try {
        debugPrint('   Trying FTMS Indoor Bike Simulation (OpCode 0x11)...');
        await setFtmsSimulationParameters(
          windSpeedMps: 0.0,
          gradePercent: gradePercentClamped,
          crr: 0.004,
          cwa: 0.51,
        );
        debugPrint('✅ Zwift slope-based ERG set to $targetWatts W (${gradePercentClamped.toStringAsFixed(1)}% grade) via FTMS');
        return;
      } catch (ftmsError) {
        debugPrint('⚠️  FTMS failed: $ftmsError');
        debugPrint('   Falling back to Zwift proprietary protocol...');
      }
      
      // Fallback to Zwift proprietary protocol
      if (!_zwiftInitialized) {
        await initializeZwiftSession();
      }
      
      // Convert to protocol format (grade% × 100)
      final inclineX100 = (gradePercentClamped * 100).round();
      
      await setZwiftSimulation(
        windSpeedX100: 0,
        inclineX100: inclineX100,
        cwaX10000: 5100,  // Zwift default
        crrX100000: 400,  // Zwift default
      );
      
      debugPrint('✅ Zwift slope-based ERG set to $targetWatts W (${gradePercentClamped.toStringAsFixed(1)}% grade) via proprietary');
    } catch (e) {
      debugPrint('❌ Failed to set Zwift slope-ERG: $e');
      rethrow;
    }
  }
  
  /// Zwift Proprietary Service: Set ERG mode target power (EXPERIMENTAL)
  /// 
  /// WARNING: According to makinolo.com blog, Zwift app doesn't use PowerTarget
  /// field with trainers - only simulation mode. This method attempts to use
  /// the PowerTarget field anyway for experimental purposes.
  /// 
  /// Based on reverse-engineered protocol from:
  /// https://www.makinolo.com/blog/2024/10/20/zwift-trainer-protocol/
  /// 
  /// Uses Protocol Buffers encoding with message ID 0x04 (Trainer Control)
  /// PowerTarget is field 3 in the protobuf message
  /// 
  /// Service UUID: 00000001-19ca-4651-86e5-fa29dcdd09d1 (confirmed on Zwift Hub)
  /// Control Char: 00000003-19ca-4651-86e5-fa29dcdd09d1 (WRITE_NO_RESP only)
  /// 
  /// Command format: [0x04, protobuf(PowerTarget=watts)]
  /// Example for 150W: 0x04 0x18 0x96 0x01
  ///   - 0x04 = Message ID (Trainer Control)
  ///   - 0x18 = Field 3 (PowerTarget), wire type 0
  ///   - 0x96 0x01 = 150 encoded as varint
  Future<void> setZwiftPower(int watts) async {
    try {
      debugPrint('🔧 Attempting Zwift proprietary ERG control: $watts W');
      
      // Auto-initialize if not done yet
      if (!_zwiftInitialized) {
        debugPrint('⚠️  Session not initialized - initializing now...');
        await initializeZwiftSession();
      }
      
      final services = ftmsDevice.servicesList;
      
      final zwiftService = services.firstWhere(
        (s) => s.uuid.toString().toLowerCase() == zwiftServiceUuid.toLowerCase(),
        orElse: () => throw Exception('Zwift proprietary service not found. Is this a Zwift Hub?'),
      );
      
      debugPrint('✅ Found Zwift service: ${zwiftService.uuid}');
      
      // Find the control characteristic
      final controlChar = zwiftService.characteristics.firstWhere(
        (c) => c.uuid.toString().toLowerCase() == zwiftControlUuid.toLowerCase(),
        orElse: () => throw Exception('Zwift control characteristic not found'),
      );
      
      // Find the notification characteristic to monitor responses
      const zwiftNotifyUuid = '00000002-19ca-4651-86e5-fa29dcdd09d1';
      final notifyChar = zwiftService.characteristics.firstWhere(
        (c) => c.uuid.toString().toLowerCase() == zwiftNotifyUuid.toLowerCase(),
        orElse: () => throw Exception('Zwift notify characteristic not found'),
      );
      
      // Ensure notifications are enabled
      if (!notifyChar.isNotifying) {
        await notifyChar.setNotifyValue(true);
        notifyChar.lastValueStream.listen((data) {
          debugPrint('📨 Zwift notification: ${data.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}');
        });
      }
      
      debugPrint('✅ Found control characteristic: ${controlChar.uuid}');
      
      // Build ERG command using Protocol Buffers
      final wattsValue = watts.clamp(0, 2000); // Safety limit
      final command = ZwiftProtobuf.encodePowerTarget(wattsValue);
      
      debugPrint('📤 Sending ERG command (protobuf): ${command.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}');
      debugPrint('   Target: $wattsValue W');
      
      // Try write without response if normal write isn't supported
      if (controlChar.properties.writeWithoutResponse) {
        debugPrint('   Using writeWithoutResponse...');
        await controlChar.write(command, withoutResponse: true);
      } else if (controlChar.properties.write) {
        debugPrint('   Using normal write...');
        await controlChar.write(command, withoutResponse: false);
      } else {
        throw Exception('Characteristic does not support write operations');
      }
      
      debugPrint('✅ Zwift ERG command sent successfully: $watts W');
    } catch (e) {
      debugPrint('❌ Failed to send Zwift proprietary command: $e');
      rethrow;
    }
  }
  
  /// Zwift Proprietary Service: Set simulation mode (incline, wind, Crr, CWa)
  /// 
  /// Uses Protocol Buffers encoding with message ID 0x04 (Trainer Control)
  /// SimulationParam is field 4 in the protobuf message
  /// 
  /// WARNING: Be cautious with Crr and CWa values - incorrect scaling causes
  /// erratic trainer behavior. Values must match Zwift's scaling:
  ///   - Wind: m/s * 100 (negative = tailwind, Zwift fixes to 0)
  ///   - Incline: grade% * 100 (e.g., 500 = 5%)
  ///   - CWa: coefficient * 10000 (Zwift fixes to 5100 = 0.51)
  ///   - Crr: coefficient * 100000 (Zwift fixes to 400 = 0.004)
  Future<void> setZwiftSimulation({
    int? windSpeedX100,
    int? inclineX100,
    int? cwaX10000,
    int? crrX100000,
  }) async {
    try {
      debugPrint('🔧 Attempting Zwift simulation mode');
      
      final services = ftmsDevice.servicesList;
      final zwiftService = services.firstWhere(
        (s) => s.uuid.toString().toLowerCase() == zwiftServiceUuid.toLowerCase(),
        orElse: () => throw Exception('Zwift proprietary service not found'),
      );
      
      final controlChar = zwiftService.characteristics.firstWhere(
        (c) => c.uuid.toString().toLowerCase() == zwiftControlUuid.toLowerCase(),
        orElse: () => throw Exception('Zwift control characteristic not found'),
      );
      
      // Build simulation command using Protocol Buffers
      final command = ZwiftProtobuf.encodeSimulation(
        windSpeedX100: windSpeedX100,
        inclineX100: inclineX100,
        cwaX10000: cwaX10000,
        crrX100000: crrX100000,
      );
      
      debugPrint('📤 Sending simulation command (protobuf): ${command.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}');
      if (inclineX100 != null) debugPrint('   Incline: ${inclineX100 / 100}%');
      if (windSpeedX100 != null) debugPrint('   Wind: ${windSpeedX100 / 100} m/s');
      
      if (controlChar.properties.writeWithoutResponse) {
        await controlChar.write(command, withoutResponse: true);
      } else if (controlChar.properties.write) {
        await controlChar.write(command, withoutResponse: false);
      } else {
        throw Exception('Characteristic does not support write operations');
      }
      
      debugPrint('✅ Zwift simulation command sent successfully');
    } catch (e) {
      debugPrint('❌ Failed to send Zwift simulation command: $e');
      rethrow;
    }
  }
  
  /// Zwift Proprietary Service: Set resistance level (0-100%)
  /// 
  /// NOTE: Resistance mode field (field 1) is not confirmed in the protocol.
  /// The makinolo blog mentions it likely exists but wasn't captured in BLE traffic
  /// since Zwift doesn't use percentage resistance mode.
  /// 
  /// This implementation is EXPERIMENTAL and may not work.
  Future<void> setZwiftResistance(int resistancePercent) async {
    try {
      debugPrint('🔧 Attempting Zwift proprietary resistance control: $resistancePercent %');
      
      final services = ftmsDevice.servicesList;
      final zwiftService = services.firstWhere(
        (s) => s.uuid.toString().toLowerCase() == zwiftServiceUuid.toLowerCase(),
        orElse: () => throw Exception('Zwift proprietary service not found'),
      );
      
      final controlChar = zwiftService.characteristics.firstWhere(
        (c) => c.uuid.toString().toLowerCase() == zwiftControlUuid.toLowerCase(),
        orElse: () => throw Exception('Zwift control characteristic not found'),
      );
      
      // Build resistance command: [0x47, resistance%, 0x00, 0x00, 0x00]
      // NOTE: This is speculative - field 1 in the protobuf message is likely
      // for resistance mode, but we're keeping the old format as a fallback
      final resistance = resistancePercent.clamp(0, 100);
      final command = [0x04, 0x08, resistance]; // Message 0x04, Field 1, value
      
      debugPrint('📤 Sending resistance command (experimental): ${command.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}');
      debugPrint('   Target: $resistance % (EXPERIMENTAL - may not work)');
      
      if (controlChar.properties.writeWithoutResponse) {
        debugPrint('   Using writeWithoutResponse...');
        await controlChar.write(command, withoutResponse: true);
      } else if (controlChar.properties.write) {
        debugPrint('   Using normal write...');
        await controlChar.write(command, withoutResponse: false);
      } else {
        throw Exception('Characteristic does not support write operations');
      }
      
      debugPrint('✅ Zwift resistance command sent successfully: $resistance %');
    } catch (e) {
      debugPrint('❌ Failed to send Zwift proprietary command: $e');
      rethrow;
    }
  }

}
