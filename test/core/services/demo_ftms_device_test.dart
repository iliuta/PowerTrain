import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_ftms/flutter_ftms.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ftms/core/services/devices/demo_ftms_device.dart';
import 'package:ftms/core/services/ftms_service.dart';

void main() {
  group('DemoFtmsDevice', () {
    late DemoFtmsDevice demoDevice;

    setUp(() {
      demoDevice = DemoFtmsDevice(
        deviceId: 'demo-device-1',
        deviceType: DeviceDataType.rower,
        remoteId: DeviceIdentifier('00:00:00:00:00:00'),
      );
    });

    test('should report support for resistance control', () async {
      // Discover services
      final services = await demoDevice.discoverServices();
      
      // Verify FTMS service exists
      expect(services, isNotEmpty);
      final ftmsService = services.firstWhere(
        (s) => s.uuid.toString().toLowerCase().contains('1826'),
      );
      expect(ftmsService, isNotNull);

      // Verify machine feature characteristic exists
      final machineFeatureChar = ftmsService.characteristics.firstWhere(
        (c) => c.uuid.toString().toLowerCase().contains('2acc'),
        orElse: () => throw Exception('Machine Feature characteristic not found'),
      );
      expect(machineFeatureChar, isNotNull);

      // Read the machine feature data
      final machineFeatureData = machineFeatureChar.lastValue;
      expect(machineFeatureData, isNotEmpty);
      
      // Machine feature should have bit 7 set (0x80) for resistance level support
      expect(machineFeatureData[0] & 0x80, equals(0x80),
          reason: 'Bit 7 (resistance level flag) should be set in machine feature');
    });

    test('FTMSService.supportsResistanceControl should return true', () async {
      // Connect to discover services
      await demoDevice.discoverServices();
      
      // Create FTMSService with the demo device
      final ftmsService = FTMSService(demoDevice);
      
      // Check resistance control support
      final supportsResistance = await ftmsService.supportsResistanceControl();
      expect(supportsResistance, isTrue,
          reason: 'Demo device should report support for resistance control');
    });
  });
}
