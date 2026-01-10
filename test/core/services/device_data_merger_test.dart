import 'package:flutter_test/flutter_test.dart';
import 'package:ftms/core/services/device_data_merger.dart';
import 'package:flutter_ftms/flutter_ftms.dart';
import 'package:flutter_ftms/src/ftms/flag.dart';
import 'package:flutter_ftms/src/ftms/parameter_name.dart';

// Mock classes for testing
class MockDeviceData extends DeviceData {
  final List<MockParameter> _parameters;
  final DeviceDataType _type;
  final bool _hasMoreDataFlag;
  // ignore: unused_field
  final List<int> _rawData;

  MockDeviceData(
    this._parameters,
    this._type, {
    bool hasMoreDataFlag = false,
    List<int>? rawData,
  })  : _hasMoreDataFlag = hasMoreDataFlag,
        _rawData = rawData ?? [0, 0, 0, 0],
        super(rawData ?? [0, 0, 0, 0]);

  @override
  DeviceDataType get deviceDataType => _type;

  @override
  List<Flag> get allDeviceDataFlags => [];

  @override
  List<DeviceDataParameter> get allDeviceDataParameters =>
      _parameters.cast<DeviceDataParameter>();

  @override
  List<DeviceDataParameterValue> getDeviceDataParameterValues() {
    return _parameters.map((p) => MockParameterValue(p.name, p.value.toInt())).toList();
  }

  @override
  Map<Flag, bool> getDeviceDataFeatures() {
    return {
      DeviceDataFlag.moreDataFlag: _hasMoreDataFlag,
    };
  }
}

class MockParameter implements DeviceDataParameter {
  final ParameterName _name;
  final num _value;

  MockParameter(String name, this._value) : _name = MockParameterName(name);

  @override
  ParameterName get name => _name;

  num get value => _value;

  @override
  num get factor => 1;

  @override
  String get unit => 'W';

  @override
  Flag? get flag => null;

  @override
  int get size => 2;

  @override
  bool get signed => false;

  @override
  DeviceDataParameterValue toDeviceDataParameterValue(int value) {
    return MockParameterValue(_name, value);
  }

  @override
  String toString() => _value.toString();
}

class MockParameterName implements ParameterName {
  final String _name;

  MockParameterName(this._name);

  @override
  String get name => _name;

  @override
  String toString() => _name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ParameterName &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;
}

class MockParameterValue implements DeviceDataParameterValue {
  final ParameterName _name;
  final int _value;

  MockParameterValue(this._name, this._value);

  @override
  ParameterName get name => _name;

  @override
  int get value => _value;

  @override
  num get factor => 1;

  @override
  String get unit => 'W';

  @override
  Flag? get flag => null;

  @override
  int get size => 2;

  @override
  bool get signed => false;

  @override
  DeviceDataParameterValue toDeviceDataParameterValue(int value) {
    return MockParameterValue(_name, value);
  }
}

void main() {
  group('DeviceDataMerger', () {
    late List<DeviceData> emittedData;
    late DeviceDataMerger merger;

    setUp(() {
      emittedData = [];
      merger = DeviceDataMerger(
        onMergedData: (data) => emittedData.add(data),
      );
    });

    tearDown(() {
      merger.dispose();
    });

    test('emits single packet immediately when More Data flag is not set', () async {
      final packet1 = MockDeviceData(
        [
          MockParameter('Average Stroke Rate', 12),
          MockParameter('Total Distance', 1357),
        ],
        DeviceDataType.rower,
        hasMoreDataFlag: false, // No more data coming
      );

      merger.processPacket(packet1);

      // Give a small delay for async processing
      await Future.delayed(const Duration(milliseconds: 10));

      expect(emittedData.length, equals(1));
      final values = emittedData[0].getDeviceDataParameterValues();
      expect(values.length, equals(2));
    });

    test('buffers packet when More Data flag is set', () async {
      final packet1 = MockDeviceData(
        [
          MockParameter('Average Stroke Rate', 12),
          MockParameter('Total Distance', 1357),
        ],
        DeviceDataType.rower,
        hasMoreDataFlag: true, // More data coming
      );

      merger.processPacket(packet1);

      // Wait a bit to ensure it's not emitted
      await Future.delayed(const Duration(milliseconds: 50));

      expect(emittedData.length, equals(0)); // Should still be buffering
    });

    test('merges two packets when More Data flag indicates continuation', () async {
      // Packet A with More Data flag set
      final packet1 = MockDeviceData(
        [
          MockParameter('Average Stroke Rate', 12),
          MockParameter('Total Distance', 1357),
        ],
        DeviceDataType.rower,
        hasMoreDataFlag: true, // More data coming
      );

      // Packet B with More Data flag clear
      final packet2 = MockDeviceData(
        [
          MockParameter('Stroke Rate', 0),
          MockParameter('Stroke Count', 295),
        ],
        DeviceDataType.rower,
        hasMoreDataFlag: false, // No more data
      );

      merger.processPacket(packet1);
      await Future.delayed(const Duration(milliseconds: 5));
      merger.processPacket(packet2);

      await Future.delayed(const Duration(milliseconds: 10));

      expect(emittedData.length, equals(1));
      expect(emittedData[0], isNotNull);
    });

    test('simulates Yosuda rower packet pattern with More Data flags', () async {
      // Packet A (Flags 0x7F00): Averages, More Data flag SET (bit 0 = 1)
      final packetA = MockDeviceData(
        [
          MockParameter('Average Stroke Rate', 12),
          MockParameter('Total Distance', 1357),
          MockParameter('Average Pace', 263),
          MockParameter('Average Power', 107),
        ],
        DeviceDataType.rower,
        hasMoreDataFlag: true, // Bit 0 = 1, more data coming
      );

      // Packet B (Flags 0x0009): Real-time, More Data flag CLEAR (bit 0 = 0)
      final packetB = MockDeviceData(
        [
          MockParameter('Stroke Rate', 0),
          MockParameter('Stroke Count', 295),
          MockParameter('Total Energy', 128),
          MockParameter('Elapsed Time', 715),
        ],
        DeviceDataType.rower,
        hasMoreDataFlag: false, // Bit 0 = 0, no more data
      );

      merger.processPacket(packetA);
      await Future.delayed(const Duration(milliseconds: 5)); // Short delay like real BLE
      merger.processPacket(packetB);

      await Future.delayed(const Duration(milliseconds: 10));

      // Verify that merger combined the packets into one emission
      expect(emittedData.length, equals(1));
      expect(emittedData[0], isNotNull);
      expect(emittedData[0].deviceDataType, equals(DeviceDataType.rower));
    });

    test('handles three packets with More Data flags', () async {
      final packet1 = MockDeviceData(
        [MockParameter('Power', 100)],
        DeviceDataType.rower,
        hasMoreDataFlag: true,
      );

      final packet2 = MockDeviceData(
        [MockParameter('Cadence', 50)],
        DeviceDataType.rower,
        hasMoreDataFlag: true,
      );

      final packet3 = MockDeviceData(
        [MockParameter('Distance', 1000)],
        DeviceDataType.rower,
        hasMoreDataFlag: false, // Last packet
      );

      merger.processPacket(packet1);
      await Future.delayed(const Duration(milliseconds: 5));
      merger.processPacket(packet2);
      await Future.delayed(const Duration(milliseconds: 5));
      merger.processPacket(packet3);

      await Future.delayed(const Duration(milliseconds: 10));

      expect(emittedData.length, equals(1));
      expect(emittedData[0], isNotNull);
    });

    test('resets state correctly', () async {
      final packet1 = MockDeviceData(
        [MockParameter('Average Stroke Rate', 12)],
        DeviceDataType.rower,
        hasMoreDataFlag: true,
      );

      merger.processPacket(packet1);
      merger.reset();

      final stats = merger.getStats();
      expect(stats['totalPackets'], equals(0));
      expect(stats['isBuffering'], equals(false));
    });

    test('provides accurate statistics', () {
      final packet1 = MockDeviceData(
        [MockParameter('Average Stroke Rate', 12)],
        DeviceDataType.rower,
        hasMoreDataFlag: true,
      );

      merger.processPacket(packet1);

      final stats = merger.getStats();
      expect(stats['totalPackets'], equals(1));
      expect(stats['isBuffering'], equals(true));
    });

    test('emits separate packets when each has More Data flag clear', () async {
      final packet1 = MockDeviceData(
        [MockParameter('Power', 100)],
        DeviceDataType.rower,
        hasMoreDataFlag: false,
      );

      final packet2 = MockDeviceData(
        [MockParameter('Cadence', 50)],
        DeviceDataType.rower,
        hasMoreDataFlag: false,
      );

      merger.processPacket(packet1);
      await Future.delayed(const Duration(milliseconds: 10));
      merger.processPacket(packet2);
      await Future.delayed(const Duration(milliseconds: 10));

      expect(emittedData.length, equals(2));
      expect(emittedData[0].getDeviceDataParameterValues().length, equals(1));
      expect(emittedData[1].getDeviceDataParameterValues().length, equals(1));
    });
  });
}
