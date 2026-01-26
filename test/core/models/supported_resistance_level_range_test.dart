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

    test('maxUserInput returns correct value', () {
      final range = SupportedResistanceLevelRange(
        minResistanceLevel: 10,
        maxResistanceLevel: 150,
        minIncrement: 10,
      );

      expect(range.maxUserInput, equals(15));
    });

    test('convertUserInputToMachine converts correctly', () {
      final range = SupportedResistanceLevelRange(
        minResistanceLevel: 10,
        maxResistanceLevel: 150,
        minIncrement: 10,
      );

      expect(range.convertUserInputToMachine(1), equals(10));
      expect(range.convertUserInputToMachine(2), equals(20));
      expect(range.convertUserInputToMachine(15), equals(150));
    });

    test('convertUserInputToMachine throws for invalid input', () {
      final range = SupportedResistanceLevelRange(
        minResistanceLevel: 10,
        maxResistanceLevel: 150,
        minIncrement: 10,
      );

      expect(
        () => range.convertUserInputToMachine(0),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => range.convertUserInputToMachine(16),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('convertMachineToUserInput converts correctly', () {
      final range = SupportedResistanceLevelRange(
        minResistanceLevel: 10,
        maxResistanceLevel: 150,
        minIncrement: 10,
      );

      expect(range.convertMachineToUserInput(10), equals(1));
      expect(range.convertMachineToUserInput(20), equals(2));
      expect(range.convertMachineToUserInput(150), equals(15));
    });

    test('convertMachineToUserInput throws for invalid input', () {
      final range = SupportedResistanceLevelRange(
        minResistanceLevel: 10,
        maxResistanceLevel: 150,
        minIncrement: 10,
      );

      expect(
        () => range.convertMachineToUserInput(5),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => range.convertMachineToUserInput(160),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => range.convertMachineToUserInput(15), // not a multiple
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('SupportedResistanceLevelRange with min=1, max=32, step=1', () {
    late SupportedResistanceLevelRange range;

    setUp(() {
      range = SupportedResistanceLevelRange(
        minResistanceLevel: 1,
        maxResistanceLevel: 32,
        minIncrement: 1,
      );
    });

    test('maxUserInput returns correct value', () {
      expect(range.maxUserInput, equals(32));
    });

    test('convertUserInputToMachine converts correctly', () {
      expect(range.convertUserInputToMachine(1), equals(1));
      expect(range.convertUserInputToMachine(2), equals(2));
      expect(range.convertUserInputToMachine(16), equals(16));
      expect(range.convertUserInputToMachine(32), equals(32));
    });

    test('convertUserInputToMachine throws for invalid input', () {
      expect(
        () => range.convertUserInputToMachine(0),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => range.convertUserInputToMachine(33),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('convertMachineToUserInput converts correctly', () {
      expect(range.convertMachineToUserInput(1), equals(1));
      expect(range.convertMachineToUserInput(2), equals(2));
      expect(range.convertMachineToUserInput(16), equals(16));
      expect(range.convertMachineToUserInput(32), equals(32));
    });

    test('convertMachineToUserInput throws for invalid input', () {
      expect(
        () => range.convertMachineToUserInput(0),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => range.convertMachineToUserInput(33),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('SupportedResistanceLevelRange with min=0, max=100, step=1', () {
    late SupportedResistanceLevelRange range;

    setUp(() {
      range = SupportedResistanceLevelRange(
        minResistanceLevel: 0,
        maxResistanceLevel: 100,
        minIncrement: 1,
      );
    });

    test('maxUserInput returns correct value', () {
      expect(range.maxUserInput, equals(100));
    });

    test('convertUserInputToMachine converts correctly', () {
      expect(range.convertUserInputToMachine(1), equals(1));
      expect(range.convertUserInputToMachine(2), equals(2));
      expect(range.convertUserInputToMachine(50), equals(50));
      expect(range.convertUserInputToMachine(100), equals(100));
    });

    test('convertUserInputToMachine throws for invalid input', () {
      expect(
        () => range.convertUserInputToMachine(0),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => range.convertUserInputToMachine(101),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('convertMachineToUserInput converts correctly', () {
      expect(range.convertMachineToUserInput(1), equals(1));
      expect(range.convertMachineToUserInput(2), equals(2));
      expect(range.convertMachineToUserInput(50), equals(50));
      expect(range.convertMachineToUserInput(100), equals(100));
    });

    test('convertMachineToUserInput throws for invalid input', () {
      expect(
        () => range.convertMachineToUserInput(-1),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => range.convertMachineToUserInput(101),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('defaultOfflineRange', () {
    test('returns correct default range', () {
      final defaultRange = SupportedResistanceLevelRange.defaultOfflineRange;
      
      expect(defaultRange.minResistanceLevel, equals(10));
      expect(defaultRange.maxResistanceLevel, equals(150));
      expect(defaultRange.minIncrement, equals(10));
      expect(defaultRange.maxUserInput, equals(15));
    });

    test('defaultOfflineRange user input conversion works correctly', () {
      final defaultRange = SupportedResistanceLevelRange.defaultOfflineRange;
      
      // User input 1 -> machine value 10
      expect(defaultRange.convertUserInputToMachine(1), equals(10));
      // User input 5 -> machine value 50
      expect(defaultRange.convertUserInputToMachine(5), equals(50));
      // User input 15 -> machine value 150
      expect(defaultRange.convertUserInputToMachine(15), equals(150));
    });
  });

  group('convertFromDefaultRange', () {
    test('converts from default range to actual machine range - same range', () {
      // Machine has the same range as default
      final range = SupportedResistanceLevelRange(
        minResistanceLevel: 10,
        maxResistanceLevel: 150,
        minIncrement: 10,
      );

      expect(range.convertFromDefaultRange(10), equals(10));
      expect(range.convertFromDefaultRange(80), equals(80));
      expect(range.convertFromDefaultRange(150), equals(150));
    });

    test('converts from default range to actual machine range - different range', () {
      // Machine has range 0-100 with increment 10
      final range = SupportedResistanceLevelRange(
        minResistanceLevel: 0,
        maxResistanceLevel: 100,
        minIncrement: 10,
      );

      // Default 10 (min) -> 0 (min of actual)
      expect(range.convertFromDefaultRange(10), equals(0));
      // Default 150 (max) -> 100 (max of actual)
      expect(range.convertFromDefaultRange(150), equals(100));
      // Default 80 (50% of 10-150) -> 50 (50% of 0-100)
      expect(range.convertFromDefaultRange(80), equals(50));
    });

    test('converts from default range - rounds to nearest valid step', () {
      // Machine has range 1-32 with increment 1
      final range = SupportedResistanceLevelRange(
        minResistanceLevel: 1,
        maxResistanceLevel: 32,
        minIncrement: 1,
      );

      // Default 10 (min) -> 1 (min of actual)
      expect(range.convertFromDefaultRange(10), equals(1));
      // Default 150 (max) -> 32 (max of actual)
      expect(range.convertFromDefaultRange(150), equals(32));
      // Default 80 (50% of 10-150) -> 17 (approximately 50% of 1-32)
      expect(range.convertFromDefaultRange(80), equals(17));
    });

    test('converts from default range - rounds to nearest valid step', () {
      // Machine has range 1-32 with increment 1
      final range = SupportedResistanceLevelRange(
        minResistanceLevel: 1,
        maxResistanceLevel: 16,
        minIncrement: 1,
      );

      // Default 10 (min) -> 1 (min of actual)
      expect(range.convertFromDefaultRange(10), equals(1));
      expect(range.convertFromDefaultRange(20), equals(2));
      expect(range.convertFromDefaultRange(30), equals(3));
      expect(range.convertFromDefaultRange(40), equals(4));
      expect(range.convertFromDefaultRange(50), equals(5));
      expect(range.convertFromDefaultRange(60), equals(6));
      expect(range.convertFromDefaultRange(70), equals(7));
      expect(range.convertFromDefaultRange(80), equals(9));
      expect(range.convertFromDefaultRange(90), equals(10));
      expect(range.convertFromDefaultRange(100), equals(11));
      expect(range.convertFromDefaultRange(110), equals(12));
      expect(range.convertFromDefaultRange(120), equals(13));
      expect(range.convertFromDefaultRange(130), equals(14));
      expect(range.convertFromDefaultRange(140), equals(15));
      expect(range.convertFromDefaultRange(150), equals(16));
    });

    test('converts from default range - larger actual range', () {
      // Machine has range 0-1500 with increment 100
      final range = SupportedResistanceLevelRange(
        minResistanceLevel: 0,
        maxResistanceLevel: 1500,
        minIncrement: 100,
      );

      // Default 10 (min) -> 0 (min of actual)
      expect(range.convertFromDefaultRange(10), equals(0));
      // Default 150 (max) -> 1500 (max of actual)
      expect(range.convertFromDefaultRange(150), equals(1500));
      // Default 80 (50% of 10-150) -> 750 (50% of 0-1500), rounded to nearest 100
      expect(range.convertFromDefaultRange(80), equals(800));
    });
  });

  group('convertToDefaultRange', () {
    test('converts from actual machine range to default range - same range', () {
      // Machine has the same range as default
      final range = SupportedResistanceLevelRange(
        minResistanceLevel: 10,
        maxResistanceLevel: 150,
        minIncrement: 10,
      );

      expect(range.convertToDefaultRange(10), equals(10));
      expect(range.convertToDefaultRange(80), equals(80));
      expect(range.convertToDefaultRange(150), equals(150));
    });

    test('converts from actual machine range to default range - different range', () {
      // Machine has range 0-100 with increment 10
      final range = SupportedResistanceLevelRange(
        minResistanceLevel: 0,
        maxResistanceLevel: 100,
        minIncrement: 10,
      );

      // Actual 0 (min) -> 10 (min of default)
      expect(range.convertToDefaultRange(0), equals(10));
      // Actual 100 (max) -> 150 (max of default)
      expect(range.convertToDefaultRange(100), equals(150));
      // Actual 50 (50% of 0-100) -> 80 (50% of 10-150)
      expect(range.convertToDefaultRange(50), equals(80));
    });


    test('converts from actual machine range - rounds to nearest valid step in default range', () {
      // Machine has range 1-32 with increment 1
      final range = SupportedResistanceLevelRange(
        minResistanceLevel: 1,
        maxResistanceLevel: 32,
        minIncrement: 1,
      );

      // Actual 1 (min) -> 10 (min of default)
      expect(range.convertToDefaultRange(1), equals(10));
      // Actual 32 (max) -> 150 (max of default)
      expect(range.convertToDefaultRange(32), equals(150));
      // Actual 16 (approximately 50% of 1-32) -> 80 (50% of 10-150)
      expect(range.convertToDefaultRange(16), equals(80));
    });

    test('round trip conversion preserves relative position', () {
      // Machine has range 0-200 with increment 20
      final range = SupportedResistanceLevelRange(
        minResistanceLevel: 0,
        maxResistanceLevel: 200,
        minIncrement: 20,
      );

      // Start with machine value 100 (50% of 0-200)
      final defaultValue = range.convertToDefaultRange(100);
      // Convert back to machine value
      final machineValue = range.convertFromDefaultRange(defaultValue);
      
      // Should be the same or very close
      expect(machineValue, equals(100));
    });
  });
}