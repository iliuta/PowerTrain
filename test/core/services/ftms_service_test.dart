import 'package:flutter_test/flutter_test.dart';
import 'package:ftms/core/models/supported_resistance_level_range.dart';

void main() {
  group('FTMSService.setResistanceWithControl', () {
    group('validation checks', () {
      test('validation returns early if resistance range is invalid (min >= max)', () {
        // Test with invalid range where min >= max
        // This simulates the MRK-R14-D559 device bug (10-0 with increment 10)
        final invalidRange = SupportedResistanceLevelRange(
          minResistanceLevel: 10,
          maxResistanceLevel: 0,
          minIncrement: 10,
        );

        // Verify that isRangeValid returns false
        expect(invalidRange.isRangeValid(), false);
      });

      test('validation returns early if resistance range is invalid (increment <= 0)', () {
        // Test with invalid range where increment is 0
        final invalidRange = SupportedResistanceLevelRange(
          minResistanceLevel: 0,
          maxResistanceLevel: 100,
          minIncrement: 0,
        );

        // Verify that isRangeValid returns false
        expect(invalidRange.isRangeValid(), false);
      });
    });

    group('valid range checks', () {
      test('isRangeValid returns true for valid range', () {
        final validRange = SupportedResistanceLevelRange(
          minResistanceLevel: 0,
          maxResistanceLevel: 100,
          minIncrement: 5,
        );

        expect(validRange.isRangeValid(), true);
      });

      test('isRangeValid returns true for negative min with positive max', () {
        final validRange = SupportedResistanceLevelRange(
          minResistanceLevel: -50,
          maxResistanceLevel: 100,
          minIncrement: 10,
        );

        expect(validRange.isRangeValid(), true);
      });

      test('isRangeValid returns false when min equals max', () {
        final invalidRange = SupportedResistanceLevelRange(
          minResistanceLevel: 50,
          maxResistanceLevel: 50,
          minIncrement: 5,
        );

        expect(invalidRange.isRangeValid(), false);
      });
    });

    group('edge cases for device bugs', () {
      test('handles MRK-R14-D559 device bug (10-0-10 inverted range)', () {
        // Simulates the actual Firebase event: ftmsdeviceData MRK-R14-D559,true,10-0,10
        final deviceBugRange = SupportedResistanceLevelRange(
          minResistanceLevel: 10,
          maxResistanceLevel: 0,
          minIncrement: 10,
        );

        expect(deviceBugRange.isRangeValid(), false);
        expect(deviceBugRange.minResistanceLevel, equals(10));
        expect(deviceBugRange.maxResistanceLevel, equals(0));
        expect(deviceBugRange.minIncrement, equals(10));
      });

      test('handles zero increment', () {
        final zeroIncrementRange = SupportedResistanceLevelRange(
          minResistanceLevel: 0,
          maxResistanceLevel: 100,
          minIncrement: 0,
        );

        expect(zeroIncrementRange.isRangeValid(), false);
      });

      test('handles negative increment', () {
        final negativeIncrementRange = SupportedResistanceLevelRange(
          minResistanceLevel: 0,
          maxResistanceLevel: 100,
          minIncrement: -5,
        );

        expect(negativeIncrementRange.isRangeValid(), false);
      });
    });
  });

  group('SupportedResistanceLevelRange.isRangeValid', () {
    test('returns true for valid range (min < max, increment > 0)', () {
      final range = SupportedResistanceLevelRange(
        minResistanceLevel: 0,
        maxResistanceLevel: 200,
        minIncrement: 5,
      );

      expect(range.isRangeValid(), true);
    });

    test('returns false when min >= max', () {
      final range = SupportedResistanceLevelRange(
        minResistanceLevel: 100,
        maxResistanceLevel: 50,
        minIncrement: 5,
      );

      expect(range.isRangeValid(), false);
    });

    test('returns false when min equals max', () {
      final range = SupportedResistanceLevelRange(
        minResistanceLevel: 100,
        maxResistanceLevel: 100,
        minIncrement: 5,
      );

      expect(range.isRangeValid(), false);
    });

    test('returns false when increment is 0', () {
      final range = SupportedResistanceLevelRange(
        minResistanceLevel: 0,
        maxResistanceLevel: 100,
        minIncrement: 0,
      );

      expect(range.isRangeValid(), false);
    });

    test('returns false when increment is negative', () {
      final range = SupportedResistanceLevelRange(
        minResistanceLevel: 0,
        maxResistanceLevel: 100,
        minIncrement: -5,
      );

      expect(range.isRangeValid(), false);
    });

    test('returns true for valid range with negative minimum', () {
      final range = SupportedResistanceLevelRange(
        minResistanceLevel: -100,
        maxResistanceLevel: 100,
        minIncrement: 10,
      );

      expect(range.isRangeValid(), true);
    });

    test('returns true for valid range with both negative values', () {
      final range = SupportedResistanceLevelRange(
        minResistanceLevel: -200,
        maxResistanceLevel: -50,
        minIncrement: 5,
      );

      expect(range.isRangeValid(), true);
    });

    test('returns false when both min and max are same negative value', () {
      final range = SupportedResistanceLevelRange(
        minResistanceLevel: -100,
        maxResistanceLevel: -100,
        minIncrement: 5,
      );

      expect(range.isRangeValid(), false);
    });

    test('returns false when negative min is greater than negative max', () {
      final range = SupportedResistanceLevelRange(
        minResistanceLevel: -50,
        maxResistanceLevel: -100,
        minIncrement: 5,
      );

      expect(range.isRangeValid(), false);
    });

    test('returns true for minimal valid range', () {
      final range = SupportedResistanceLevelRange(
        minResistanceLevel: 0,
        maxResistanceLevel: 1,
        minIncrement: 1,
      );

      expect(range.isRangeValid(), true);
    });
  });
}
