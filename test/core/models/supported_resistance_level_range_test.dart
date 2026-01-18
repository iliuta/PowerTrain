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
}