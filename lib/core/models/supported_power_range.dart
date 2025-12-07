/// Model for FTMS Supported Power Range characteristic
/// UUID: 2AD8
/// Reference: Bluetooth FTMS Specification
/// https://www.bluetooth.org/DocMan/handlers/DownloadDoc.ashx?doc_id=423422
class SupportedPowerRange {
  /// Minimum Power in watts
  final int minPower;

  /// Maximum Power in watts
  final int maxPower;

  /// Minimum Increment in watts
  final int minIncrement;

  SupportedPowerRange({
    required this.minPower,
    required this.maxPower,
    required this.minIncrement,
  });
  
  /// Returns the minimum control value (in watts)
  int get minControlValue => minPower;
  
  /// Returns the maximum control value (in watts)
  int get maxControlValue => maxPower;
  
  /// Returns the control increment step (in watts)
  int get controlIncrement => minIncrement;

  /// Parse the characteristic value (6 bytes)
  /// Format (Supported Power Range characteristic):
  /// Bytes 0-1: Minimum Power (uint16)
  /// Bytes 2-3: Maximum Power (uint16)
  /// Bytes 4-5: Minimum Increment (uint16)
  factory SupportedPowerRange.fromBytes(List<int> data) {
    if (data.length < 6) {
      throw ArgumentError('Expected at least 6 bytes, got ${data.length}');
    }

    // Parse uint16 for min power
    final minPower = ((data[1] << 8) | data[0]).toUnsigned(16);

    // Parse uint16 for max power
    final maxPower = ((data[3] << 8) | data[2]).toUnsigned(16);

    // Parse uint16 for min increment
    final minIncrement = ((data[5] << 8) | data[4]).toUnsigned(16);

    return SupportedPowerRange(
      minPower: minPower,
      maxPower: maxPower,
      minIncrement: minIncrement,
    );
  }

  @override
  String toString() =>
      'SupportedPowerRange(min: $minPower W, max: $maxPower W, increment: $minIncrement W)';
}
