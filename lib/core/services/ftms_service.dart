// This file was moved from lib/ftms_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_ftms/flutter_ftms.dart';

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
      await Future.delayed(Duration(milliseconds: 100));
    } else if (controlChar.properties.notify && !controlChar.isNotifying) {
      await controlChar.setNotifyValue(true);
      await Future.delayed(Duration(milliseconds: 100));
    }

    await Future.delayed(Duration(milliseconds: 200));
  }
}
