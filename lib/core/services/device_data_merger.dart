import 'dart:async';
import 'package:flutter_ftms/flutter_ftms.dart';

/// Service for merging split FTMS device data packets using the "More Data" flag.
/// 
/// According to FTMS specification, Bit 0 of the Flags field indicates:
/// - Bit 0 = 1: More data is coming for this update (don't emit yet)
/// - Bit 0 = 0: This is the last packet for this update (safe to emit)
/// 
/// Some devices (like Yosuda rower) send data in multiple packets:
/// - Packet A (Flags 0x7F00): Averages with More Data flag set (Bit 0 = 1)
/// - Packet B (Flags 0x0009): Real-time with More Data flag clear (Bit 0 = 0)
/// 
/// This service uses the More Data flag to intelligently merge packets,
/// with a fallback timeout for devices that don't properly implement the flag.
class DeviceDataMerger {
  final Duration fallbackTimeout;
  final void Function(DeviceData) onMergedData;
  
  Timer? _timeoutTimer;
  DeviceData? _bufferedData;
  int _packetCount = 0;
  int _mergedPacketCount = 0;
  
  DeviceDataMerger({
    required this.onMergedData,
    this.fallbackTimeout = const Duration(milliseconds: 100),
  });
  
  /// Process incoming device data packet.
  /// Uses the FTMS "More Data" flag (Bit 0) to determine if more packets are expected.
  void processPacket(DeviceData data) {
    _packetCount++;
    
    // Check if this packet has the "More Data" flag set
    final hasMoreData = _hasMoreDataFlag(data);
    
    if (_bufferedData == null) {
      // First packet
      if (hasMoreData) {
        // More data is coming - buffer this packet and start timeout
        _bufferedData = data;
        _startTimeoutTimer();
      } else {
        // No more data - emit immediately (single-packet device)
        onMergedData(data);
      }
    } else {
      // We have a buffered packet - merge this one with it
      try {
        _bufferedData!.merge(data);
        _mergedPacketCount++;
        
        if (hasMoreData) {
          // Still more data coming - keep buffering
          _resetTimeoutTimer();
        } else {
          // This is the last packet - emit merged data
          _cancelTimeoutTimer();
          _emitAndClear();
        }
      } catch (e) {
        // Merge failed (different device types or other error)
        // Emit buffered data and start fresh with new packet
        _cancelTimeoutTimer();
        _emitAndClear();
        
        // Process the new packet
        if (hasMoreData) {
          _bufferedData = data;
          _startTimeoutTimer();
        } else {
          onMergedData(data);
        }
      }
    }
  }
  
  /// Check if the More Data flag (Bit 0) is set in the packet's flags
  bool _hasMoreDataFlag(DeviceData data) {
    try {
      final features = data.getDeviceDataFeatures();
      // DeviceDataFlag.moreDataFlag is the More Data flag (Bit 0)
      return features[DeviceDataFlag.moreDataFlag] == true;
    } catch (e) {
      // If we can't read the flag, assume no more data (fail-safe)
      return false;
    }
  }
  
  void _startTimeoutTimer() {
    _timeoutTimer = Timer(fallbackTimeout, () {
      // Timeout expired - emit buffered data even without More Data flag cleared
      // This handles devices that don't properly implement the flag
      _emitAndClear();
    });
  }
  
  void _resetTimeoutTimer() {
    _cancelTimeoutTimer();
    _startTimeoutTimer();
  }
  
  void _cancelTimeoutTimer() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
  }
  
  void _emitAndClear() {
    if (_bufferedData != null) {
      onMergedData(_bufferedData!);
      _bufferedData = null;
    }
  }
  
  /// Get statistics about packet merging (useful for debugging)
  Map<String, dynamic> getStats() {
    return {
      'totalPackets': _packetCount,
      'mergedPackets': _mergedPacketCount,
      'isBuffering': _bufferedData != null,
      'fallbackTimeoutMs': fallbackTimeout.inMilliseconds,
    };
  }
  
  /// Reset the merger state
  void reset() {
    _cancelTimeoutTimer();
    _bufferedData = null;
    _packetCount = 0;
    _mergedPacketCount = 0;
  }
  
  /// Dispose resources
  void dispose() {
    _cancelTimeoutTimer();
    _bufferedData = null;
  }
}
