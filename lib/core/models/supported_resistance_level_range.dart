/// Model for FTMS Supported Resistance Level Range characteristic
/// UUID: 2AD6
/// Reference: Bluetooth FTMS Specification
/// https://www.bluetooth.org/DocMan/handlers/DownloadDoc.ashx?doc_id=423422
class SupportedResistanceLevelRange {
  /// Minimum Resistance Level in ohms
  final int minResistanceLevel;

  /// Maximum Resistance Level in ohms
  final int maxResistanceLevel;

  /// Minimum Increment in ohms
  final int minIncrement;

  SupportedResistanceLevelRange({
    required this.minResistanceLevel,
    required this.maxResistanceLevel,
    required this.minIncrement,
  });
  
  /// Returns the minimum control value (in ohms)
  int get minControlValue => minResistanceLevel;
  
  /// Returns the maximum control value (in ohms)
  int get maxControlValue => maxResistanceLevel;
  
  /// Returns the control increment step (in ohms)
  int get controlIncrement => minIncrement;

  /// Parse the characteristic value (6 bytes minimum)
  /// Format (Supported Resistance Level Range characteristic):
  /// Bytes 0-1: Minimum Resistance Level (sint16)
  /// Bytes 2-3: Maximum Resistance Level (sint16)
  /// Bytes 4-5: Minimum Increment (uint16)
  factory SupportedResistanceLevelRange.fromBytes(List<int> data) {
    if (data.length < 6) {
      throw ArgumentError('Expected at least 6 bytes, got ${data.length}');
    }

    // Parse sint16 for min resistance level
    int minRaw = (data[1] << 8) | data[0];
    if (minRaw & 0x8000 != 0) {
      minRaw = minRaw - 0x10000; // Convert to signed
    }
    final minResistanceLevel = minRaw;

    // Parse sint16 for max resistance level
    int maxRaw = (data[3] << 8) | data[2];
    if (maxRaw & 0x8000 != 0) {
      maxRaw = maxRaw - 0x10000; // Convert to signed
    }
    final maxResistanceLevel = maxRaw;

    // Parse uint16 for min increment
    final minIncrement = ((data[5] << 8) | data[4]).toUnsigned(16);

    return SupportedResistanceLevelRange(
      minResistanceLevel: minResistanceLevel,
      maxResistanceLevel: maxResistanceLevel,
      minIncrement: minIncrement,
    );
  }

  @override
  String toString() =>
      'SupportedResistanceLevelRange(min: $minResistanceLevel Ω, max: $maxResistanceLevel Ω, increment: $minIncrement Ω)';
}
