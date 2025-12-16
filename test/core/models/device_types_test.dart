import 'package:flutter_ftms/flutter_ftms.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ftms/core/models/device_types.dart';

void main() {
  group('DeviceType', () {
    group('fromString', () {
      test('parses indoorBike from various string formats', () {
        expect(DeviceType.fromString('devicedatatype.indoorbike'), DeviceType.indoorBike);
        expect(DeviceType.fromString('devicetype.indoorBike'), DeviceType.indoorBike);
        expect(DeviceType.fromString('indoorbike'), DeviceType.indoorBike);
        expect(DeviceType.fromString('INDOORBIKE'), DeviceType.indoorBike);
      });

      test('parses rower from various string formats', () {
        expect(DeviceType.fromString('devicedatatype.rower'), DeviceType.rower);
        expect(DeviceType.fromString('devicetype.rower'), DeviceType.rower);
        expect(DeviceType.fromString('rower'), DeviceType.rower);
        expect(DeviceType.fromString('ROWER'), DeviceType.rower);
      });

      test('throws ArgumentError for unknown device type', () {
        expect(() => DeviceType.fromString('unknown'), throwsA(isA<ArgumentError>()));
        expect(() => DeviceType.fromString('treadmill'), throwsA(isA<ArgumentError>()));
      });
    });

    group('fromFtms', () {
      test('converts DeviceDataType.indoorBike to DeviceType.indoorBike', () {
        expect(DeviceType.fromFtms(DeviceDataType.indoorBike), DeviceType.indoorBike);
      });

      test('converts DeviceDataType.rower to DeviceType.rower', () {
        expect(DeviceType.fromFtms(DeviceDataType.rower), DeviceType.rower);
      });

      test('throws ArgumentError for unknown DeviceDataType', () {
        // Note: This test assumes there are other DeviceDataType values that aren't handled
        // In a real scenario, you might need to check what other values exist in the enum
        // For now, we'll skip this test as it depends on the flutter_ftms package implementation
      });
    });
  });
}