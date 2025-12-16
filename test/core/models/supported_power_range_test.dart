import 'package:flutter_test/flutter_test.dart';
import 'package:ftms/core/models/supported_power_range.dart';

void main() {
  group('SupportedPowerRange', () {
    test('can be created with required parameters', () {
      final range = SupportedPowerRange(
        minPower: 0,
        maxPower: 400,
        minIncrement: 5,
      );

      expect(range.minPower, equals(0));
      expect(range.maxPower, equals(400));
      expect(range.minIncrement, equals(5));
    });

    test('getters return correct values', () {
      final range = SupportedPowerRange(
        minPower: 10,
        maxPower: 300,
        minIncrement: 10,
      );

      expect(range.minControlValue, equals(10));
      expect(range.maxControlValue, equals(300));
      expect(range.controlIncrement, equals(10));
    });

    test('fromBytes parses valid data correctly', () {
      // Test data: min=50, max=350, increment=5
      // 50 = 0x0032 (little endian: 0x32, 0x00)
      // 350 = 0x015E (little endian: 0x5E, 0x01)
      // 5 = 0x0005 (little endian: 0x05, 0x00)
      final data = [0x32, 0x00, 0x5E, 0x01, 0x05, 0x00];

      final range = SupportedPowerRange.fromBytes(data);

      expect(range.minPower, equals(50));
      expect(range.maxPower, equals(350));
      expect(range.minIncrement, equals(5));
    });

    test('fromBytes throws ArgumentError for insufficient data', () {
      final data = [0x32, 0x00, 0x5E]; // Only 3 bytes

      expect(
        () => SupportedPowerRange.fromBytes(data),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('toString returns formatted string', () {
      final range = SupportedPowerRange(
        minPower: 25,
        maxPower: 275,
        minIncrement: 10,
      );

      expect(
        range.toString(),
        equals('SupportedPowerRange(min: 25 W, max: 275 W, increment: 10 W)'),
      );
    });
  });
}