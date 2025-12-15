import 'package:flutter_test/flutter_test.dart';
import 'package:ftms/core/models/supported_resistance_level_range.dart';

void main() {
  group('SupportedResistanceLevelRange', () {
    test('can be created with required parameters', () {
      final range = SupportedResistanceLevelRange(
        minResistanceLevel: -50,
        maxResistanceLevel: 1000,
        minIncrement: 5,
      );

      expect(range.minResistanceLevel, equals(-50));
      expect(range.maxResistanceLevel, equals(1000));
      expect(range.minIncrement, equals(5));
    });

    test('getters return correct values', () {
      final range = SupportedResistanceLevelRange(
        minResistanceLevel: -25,
        maxResistanceLevel: 500,
        minIncrement: 10,
      );

      expect(range.minControlValue, equals(-25));
      expect(range.maxControlValue, equals(500));
      expect(range.controlIncrement, equals(10));
    });

    test('fromBytes parses valid data with positive values correctly', () {
      // Test data: min=100, max=800, increment=20
      // 100 = 0x0064 (little endian: 0x64, 0x00)
      // 800 = 0x0320 (little endian: 0x20, 0x03)
      // 20 = 0x0014 (little endian: 0x14, 0x00)
      final data = [0x64, 0x00, 0x20, 0x03, 0x14, 0x00];

      final range = SupportedResistanceLevelRange.fromBytes(data);

      expect(range.minResistanceLevel, equals(100));
      expect(range.maxResistanceLevel, equals(800));
      expect(range.minIncrement, equals(20));
    });

    test('fromBytes parses valid data with negative values correctly', () {
      // Test data: min=-100, max=500, increment=10
      // -100 = 0xFF9C (little endian: 0x9C, 0xFF)
      // 500 = 0x01F4 (little endian: 0xF4, 0x01)
      // 10 = 0x000A (little endian: 0x0A, 0x00)
      final data = [0x9C, 0xFF, 0xF4, 0x01, 0x0A, 0x00];

      final range = SupportedResistanceLevelRange.fromBytes(data);

      expect(range.minResistanceLevel, equals(-100));
      expect(range.maxResistanceLevel, equals(500));
      expect(range.minIncrement, equals(10));
    });

    test('fromBytes throws ArgumentError for insufficient data', () {
      final data = [0x64, 0x00, 0x20]; // Only 3 bytes

      expect(
        () => SupportedResistanceLevelRange.fromBytes(data),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('toString returns formatted string', () {
      final range = SupportedResistanceLevelRange(
        minResistanceLevel: -25,
        maxResistanceLevel: 275,
        minIncrement: 5,
      );

      expect(
        range.toString(),
        equals('SupportedResistanceLevelRange(min: -25 Ω, max: 275 Ω, increment: 5 Ω)'),
      );
    });
  });
}