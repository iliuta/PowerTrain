// This file was moved from lib/ftms_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_ftms/flutter_ftms.dart';
import 'package:ftms/core/utils/logger.dart';

import '../models/supported_resistance_level_range.dart';
import '../models/supported_power_range.dart';

typedef WriteMachineControlPointCharacteristic = Future<void> Function(
    BluetoothDevice device, MachineControlPoint controlPoint);

class FTMSService {
  final BluetoothDevice ftmsDevice;
  final WriteMachineControlPointCharacteristic writeCharacteristic;

  FTMSService(this.ftmsDevice,
      {WriteMachineControlPointCharacteristic? writeCharacteristic})
      : writeCharacteristic =
            writeCharacteristic ?? FTMS.writeMachineControlPointCharacteristic;

  Future<void> writeCommand(MachineControlPointOpcodeType opcodeType,
      {int? resistanceLevel, int? power}) async {
    try {
      await _ftmsDeviceSetNotifyValue();

      // Now build and send the command
      MachineControlPoint? controlPoint;
      switch (opcodeType) {
        case MachineControlPointOpcodeType.requestControl:
          controlPoint = MachineControlPoint.requestControl();
          debugPrint('📤 Sending: requestControl');
          break;
        case MachineControlPointOpcodeType.reset:
          controlPoint = MachineControlPoint.reset();
          break;
        case MachineControlPointOpcodeType.setTargetSpeed:
          controlPoint = MachineControlPoint.setTargetSpeed(speed: 12);
          break;
        case MachineControlPointOpcodeType.setTargetInclination:
          controlPoint =
              MachineControlPoint.setTargetInclination(inclination: 23);
          break;
        case MachineControlPointOpcodeType.setTargetResistanceLevel:
          controlPoint = MachineControlPoint.setTargetResistanceLevel(
              resistanceLevel: resistanceLevel ?? 2);
          break;
        case MachineControlPointOpcodeType.setTargetPower:
          debugPrint('📤 Sending: setTargetPower($power W)');
          controlPoint =
              MachineControlPoint.setTargetPower(power: power ?? 150);
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
      debugPrint('✅ Command executed');
    } catch (e) {
      debugPrint('❌ writeCommand error: $e');
      rethrow;
    }
  }

  Future<void> _ftmsDeviceSetNotifyValue() async {
    // Find FTMS service (1826)
    final ftmsService = ftmsDevice.servicesList.firstWhere(
      (s) => s.uuid.toString().toLowerCase().contains('1826'),
    );

    // Find control point (2ad9)
    final controlChar = ftmsService.characteristics.firstWhere(
      (c) => c.uuid.toString().toLowerCase().contains('2ad9'),
    );

    // Enable notifications/indications FIRST (critical!)
    if (controlChar.properties.indicate && !controlChar.isNotifying) {
      await controlChar.setNotifyValue(true);
    } else if (controlChar.properties.notify && !controlChar.isNotifying) {
      await controlChar.setNotifyValue(true);
    }

    await Future.delayed(Duration(milliseconds: 100));
  }

  /// Reads the Supported Resistance Level Range characteristic (UUID: 2AD6)
  /// This characteristic is exposed by the Server if Resistance Control Target
  /// Setting feature is supported (according to FTMS spec 4.13)
  Future<SupportedResistanceLevelRange?> readSupportedResistanceLevelRange() async {
    try {
      // Find FTMS service (1826)
      final ftmsService = ftmsDevice.servicesList.firstWhere(
        (s) => s.uuid.toString().toLowerCase().contains('1826'),
      );

      // Find Supported Resistance Level Range characteristic (2AD6)
      final characteristic = ftmsService.characteristics.firstWhere(
        (c) => c.uuid.toString().toLowerCase().contains('2ad6'),
        orElse: () => throw Exception('Supported Resistance Level Range characteristic not found'),
      );

      // Read the characteristic value
      final value = await characteristic.read();
      debugPrint('📖 Read Supported Resistance Level Range: ${value.join(', ')}');

      return SupportedResistanceLevelRange.fromBytes(value);
    } catch (e) {
      debugPrint('❌ readSupportedResistanceLevelRange error: $e');
      rethrow;
    }
  }

  /// Reads the Supported Power Range characteristic (UUID: 2AD8)
  /// This characteristic is exposed by the Server if Power Target Setting
  /// feature is supported (according to FTMS spec 4.14)
  Future<SupportedPowerRange?> readSupportedPowerRange() async {
    try {
      // Find FTMS service (1826)
      final ftmsService = ftmsDevice.servicesList.firstWhere(
        (s) => s.uuid.toString().toLowerCase().contains('1826'),
      );

      // Find Supported Power Range characteristic (2AD8)
      final characteristic = ftmsService.characteristics.firstWhere(
        (c) => c.uuid.toString().toLowerCase().contains('2ad8'),
        orElse: () => throw Exception('Supported Power Range characteristic not found'),
      );

      // Read the characteristic value
      final value = await characteristic.read();
      debugPrint('📖 Read Supported Power Range: ${value.join(', ')}');

      return SupportedPowerRange.fromBytes(value);
    } catch (e) {
      debugPrint('❌ readSupportedPowerRange error: $e');
      rethrow;
    }
  }

  /// Executes an FTMS command with retry logic for reliability
  Future<void> _executeWithRetry(Future<void> Function() command, String operationName) async {
    const int maxRetries = 5;
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        await command();
        return; // Success, exit
      } catch (e) {
        debugPrint('Failed to $operationName (attempt ${attempt + 1}/$maxRetries): $e');
        if (attempt == maxRetries - 1) {
          debugPrint('All retries failed for $operationName');
          // Don't rethrow - FTMS commands should fail silently to not disrupt the session
          return;
        }
        await Future.delayed(const Duration(milliseconds: 500)); // Wait before retry
      }
    }
  }

  Future<void> setPowerWithControl(dynamic power) async {
    await _executeWithRetry(() async {
      await writeCommand(MachineControlPointOpcodeType.requestControl);
      await Future.delayed(const Duration(milliseconds: 100));
      await writeCommand(
          MachineControlPointOpcodeType.setTargetPower,
          power: power);
      logger.i('Requested control and sent setPowerWithControl($power W) command');
    }, 'setPowerWithControl');
  }

  Future<void> stopOrPauseWithControl() async {
    await _executeWithRetry(() async {
      await writeCommand(MachineControlPointOpcodeType.requestControl);
      await Future.delayed(const Duration(milliseconds: 100));
      await writeCommand(MachineControlPointOpcodeType.stopOrPause);
      logger.i('Requested control and sent stopOrPause command');
    }, 'stopOrPauseWithControl');
  }

  Future<void> setResistanceWithControl(int resistance) async {
    await _executeWithRetry(() async {
      await writeCommand(MachineControlPointOpcodeType.requestControl);
      await Future.delayed(const Duration(milliseconds: 100));
      await writeCommand(
          MachineControlPointOpcodeType.setTargetResistanceLevel,
          resistanceLevel: resistance);
      logger.i('Requested control and sent setTargetResistanceLevel($resistance) command');
    }, 'setResistanceWithControl');
  }

  Future<void> startOrResumeWithControl() async {
    await _executeWithRetry(() async {
      await writeCommand(MachineControlPointOpcodeType.requestControl);
      await Future.delayed(const Duration(milliseconds: 100));
      await writeCommand(MachineControlPointOpcodeType.startOrResume);
      logger.i('Requested control and sent startOrResume command');
    }, 'startOrResumeWithControl');
  }

  Future<void> resetWithControl() async {
    await _executeWithRetry(() async {
      await writeCommand(MachineControlPointOpcodeType.requestControl);
      await Future.delayed(const Duration(milliseconds: 100));
      await writeCommand(MachineControlPointOpcodeType.reset);
      logger.i('Requested control and sent reset command');
    }, 'resetWithControl');
  }

  Future<void> requestControlOnly() async {
    await _executeWithRetry(() async {
      await writeCommand(MachineControlPointOpcodeType.requestControl);
      await Future.delayed(const Duration(milliseconds: 100));
    }, 'resetWithControl');
  }
}
