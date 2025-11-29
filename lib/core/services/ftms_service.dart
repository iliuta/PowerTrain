// This file was moved from lib/ftms_service.dart
import 'package:flutter_ftms/flutter_ftms.dart';

typedef WriteMachineControlPointCharacteristic = Future<void> Function(
    BluetoothDevice device, MachineControlPoint controlPoint);

class FTMSService {
  final BluetoothDevice ftmsDevice;
  final WriteMachineControlPointCharacteristic writeCharacteristic;

  FTMSService(this.ftmsDevice, {WriteMachineControlPointCharacteristic? writeCharacteristic})
      : writeCharacteristic = writeCharacteristic ?? FTMS.writeMachineControlPointCharacteristic;
  
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
  

}
