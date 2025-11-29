import 'dart:typed_data';

/// Zwift Trainer Protocol - Protocol Buffers encoder
/// 
/// Based on reverse-engineered protocol from:
/// https://www.makinolo.com/blog/2024/10/20/zwift-trainer-protocol/
/// 
/// Messages use Protocol Buffers encoding with message ID prefix:
/// - 0x03: Riding Data (notifications from trainer)
/// - 0x04: Trainer Control (commands to trainer)
/// - 0x00: Request for information

class ZwiftProtobuf {
  /// Encode a Request for Information message (0x00)
  /// 
  /// Parameter values:
  /// - 0: General info request
  /// - 1-7: Specific field values
  /// - 520: Current gear ratio (Wahoo Kickr Core specific)
  static Uint8List encodeInfoRequest([int parameter = 0]) {
    final buffer = BytesBuilder();
    buffer.addByte(0x00); // Message ID: Request for information
    
    if (parameter != 0) {
      // Field 1 (parameter): key = (1 << 3) | 0 = 8 (0x08)
      buffer.addByte(0x08);
      buffer.add(_encodeVarint(parameter));
    }
    
    return buffer.toBytes();
  }
  
  /// Encode a Trainer Control message (0x04) with ERG power target
  /// 
  /// Field 3: PowerTarget (varint)
  /// Returns: [0x04, protobuf_encoded_data]
  static Uint8List encodePowerTarget(int watts) {
    final buffer = BytesBuilder();
    buffer.addByte(0x04); // Message ID: Trainer Control
    
    // Field 3 (PowerTarget): key = (3 << 3) | 0 = 24 (0x18)
    buffer.addByte(0x18);
    buffer.add(_encodeVarint(watts));
    
    return buffer.toBytes();
  }
  
  /// Encode a Trainer Control message (0x04) with simulation parameters
  /// 
  /// Field 4: SimulationParam (nested message)
  ///   - Field 1: Wind (sint32, zigzag encoded)
  ///   - Field 2: InclineX100 (sint32, zigzag encoded)
  ///   - Field 3: CWa (uint32)
  ///   - Field 4: Crr (uint32)
  static Uint8List encodeSimulation({
    int? windSpeedX100,      // Wind in m/s * 100 (negative = tailwind)
    int? inclineX100,        // Incline * 100 (e.g., 500 = 5%)
    int? cwaX10000,          // Aero coefficient CW*a * 10000 (Zwift uses 5100)
    int? crrX100000,         // Rolling resistance * 100000 (Zwift uses 400)
  }) {
    final buffer = BytesBuilder();
    buffer.addByte(0x04); // Message ID: Trainer Control
    
    // Build nested SimulationParam message
    final simBuffer = BytesBuilder();
    
    if (windSpeedX100 != null) {
      simBuffer.addByte(0x08); // Field 1, wire type 0 (varint)
      simBuffer.add(_encodeZigZag(windSpeedX100));
    }
    
    if (inclineX100 != null) {
      simBuffer.addByte(0x10); // Field 2, wire type 0 (varint)
      simBuffer.add(_encodeZigZag(inclineX100));
    }
    
    if (cwaX10000 != null) {
      simBuffer.addByte(0x18); // Field 3, wire type 0 (varint)
      simBuffer.add(_encodeVarint(cwaX10000));
    }
    
    if (crrX100000 != null) {
      simBuffer.addByte(0x20); // Field 4, wire type 0 (varint)
      simBuffer.add(_encodeVarint(crrX100000));
    }
    
    final simBytes = simBuffer.toBytes();
    
    // Field 4 (SimulationParam): key = (4 << 3) | 2 = 34 (0x22), wire type 2 (length-delimited)
    buffer.addByte(0x22);
    buffer.add(_encodeVarint(simBytes.length));
    buffer.add(simBytes);
    
    return buffer.toBytes();
  }
  
  /// Encode a Trainer Control message (0x04) with physical parameters
  /// 
  /// Field 5: PhysicalParam (nested message)
  ///   - Field 2: GearRatioX10000 (uint32)
  ///   - Field 4: BikeWeightX100 (uint32, in kg)
  ///   - Field 5: RiderWeightX100 (uint32, in kg)
  static Uint8List encodePhysical({
    int? gearRatioX10000,
    int? bikeWeightX100,     // Bike weight in kg * 100
    int? riderWeightX100,    // Rider weight in kg * 100
  }) {
    final buffer = BytesBuilder();
    buffer.addByte(0x04); // Message ID: Trainer Control
    
    // Build nested PhysicalParam message
    final physBuffer = BytesBuilder();
    
    if (gearRatioX10000 != null) {
      physBuffer.addByte(0x10); // Field 2, wire type 0 (varint)
      physBuffer.add(_encodeVarint(gearRatioX10000));
    }
    
    if (bikeWeightX100 != null) {
      physBuffer.addByte(0x20); // Field 4, wire type 0 (varint)
      physBuffer.add(_encodeVarint(bikeWeightX100));
    }
    
    if (riderWeightX100 != null) {
      physBuffer.addByte(0x28); // Field 5, wire type 0 (varint)
      physBuffer.add(_encodeVarint(riderWeightX100));
    }
    
    final physBytes = physBuffer.toBytes();
    
    // Field 5 (PhysicalParam): key = (5 << 3) | 2 = 42 (0x2A), wire type 2 (length-delimited)
    buffer.addByte(0x2A);
    buffer.add(_encodeVarint(physBytes.length));
    buffer.add(physBytes);
    
    return buffer.toBytes();
  }
  
  /// Encode unsigned varint (Protocol Buffers format)
  static Uint8List _encodeVarint(int value) {
    final buffer = BytesBuilder();
    var v = value;
    
    while (v >= 0x80) {
      buffer.addByte((v & 0x7F) | 0x80);
      v >>= 7;
    }
    buffer.addByte(v & 0x7F);
    
    return buffer.toBytes();
  }
  
  /// Encode signed integer using ZigZag encoding (Protocol Buffers sint32)
  static Uint8List _encodeZigZag(int value) {
    final zigzag = (value << 1) ^ (value >> 31);
    return _encodeVarint(zigzag);
  }
  
  // ========== DECODERS ==========
  
  /// Decode a Zwift trainer message based on message ID
  /// 
  /// Returns a map with message type and decoded data
  static Map<String, dynamic>? decodeMessage(List<int> data) {
    if (data.isEmpty) return null;
    
    final messageId = data[0];
    final payload = data.sublist(1);
    
    switch (messageId) {
      case 0x03:
        return {'type': 'RidingData', 'data': _decodeRidingData(payload)};
      case 0x04:
        return {'type': 'TrainerControl', 'data': _decodeTrainerControl(payload)};
      case 0x00:
        return {'type': 'InfoResponse', 'data': _decodeInfoResponse(payload)};
      default:
        return {'type': 'Unknown', 'messageId': messageId, 'raw': data};
    }
  }
  
  /// Decode Riding Data message (0x03)
  /// 
  /// Fields:
  /// - Field 1: Power (uint32)
  /// - Field 2: Cadence (uint32)
  /// - Field 3: SpeedX100 (uint32)
  /// - Field 4: HR (uint32)
  /// - Field 5: Unknown1 (uint32)
  /// - Field 6: Unknown2 (uint32)
  static Map<String, dynamic> _decodeRidingData(List<int> data) {
    final result = <String, dynamic>{};
    int offset = 0;
    
    while (offset < data.length) {
      final key = data[offset++];
      final fieldNumber = key >> 3;
      final wireType = key & 0x07;
      
      if (wireType == 0) { // Varint
        final value = _decodeVarint(data, offset);
        offset = value['offset']!;
        final intValue = value['value']!;
        
        switch (fieldNumber) {
          case 1:
            result['power'] = intValue;
            break;
          case 2:
            result['cadence'] = intValue;
            break;
          case 3:
            result['speedX100'] = intValue;
            result['speedKmh'] = intValue / 100.0;
            break;
          case 4:
            result['heartRate'] = intValue;
            break;
          case 5:
            result['unknown1'] = intValue;
            break;
          case 6:
            result['unknown2'] = intValue;
            break;
        }
      } else {
        // Unknown wire type - skip
        break;
      }
    }
    
    return result;
  }
  
  /// Decode Trainer Control message (0x04)
  /// 
  /// Fields:
  /// - Field 1: ResistancePercent (uint32) - likely exists but not confirmed
  /// - Field 3: PowerTarget (uint32)
  /// - Field 4: SimulationParam (nested message)
  /// - Field 5: PhysicalParam (nested message)
  static Map<String, dynamic> _decodeTrainerControl(List<int> data) {
    final result = <String, dynamic>{};
    int offset = 0;
    
    while (offset < data.length) {
      final key = data[offset++];
      final fieldNumber = key >> 3;
      final wireType = key & 0x07;
      
      if (wireType == 0) { // Varint
        final value = _decodeVarint(data, offset);
        offset = value['offset']!;
        final intValue = value['value']!;
        
        switch (fieldNumber) {
          case 1:
            result['resistancePercent'] = intValue;
            break;
          case 3:
            result['powerTarget'] = intValue;
            break;
        }
      } else if (wireType == 2) { // Length-delimited (nested message)
        final length = _decodeVarint(data, offset);
        offset = length['offset']!;
        final lengthValue = length['value']!;
        final nestedData = data.sublist(offset, offset + lengthValue);
        offset += lengthValue;
        
        switch (fieldNumber) {
          case 4:
            result['simulation'] = _decodeSimulationParam(nestedData);
            break;
          case 5:
            result['physical'] = _decodePhysicalParam(nestedData);
            break;
        }
      }
    }
    
    return result;
  }
  
  /// Decode SimulationParam nested message
  static Map<String, dynamic> _decodeSimulationParam(List<int> data) {
    final result = <String, dynamic>{};
    int offset = 0;
    
    while (offset < data.length) {
      final key = data[offset++];
      final fieldNumber = key >> 3;
      final wireType = key & 0x07;
      
      if (wireType == 0) {
        final value = _decodeVarint(data, offset);
        offset = value['offset']!;
        final intValue = value['value']!;
        
        switch (fieldNumber) {
          case 1: // Wind (sint32)
            final windX100 = _decodeZigZag(intValue);
            result['windX100'] = windX100;
            result['windMps'] = windX100 / 100.0;
            break;
          case 2: // Incline (sint32)
            final inclineX100 = _decodeZigZag(intValue);
            result['inclineX100'] = inclineX100;
            result['inclinePercent'] = inclineX100 / 100.0;
            break;
          case 3: // CWa (uint32)
            result['cwaX10000'] = intValue;
            result['cwa'] = intValue / 10000.0;
            break;
          case 4: // Crr (uint32)
            result['crrX100000'] = intValue;
            result['crr'] = intValue / 100000.0;
            break;
        }
      }
    }
    
    return result;
  }
  
  /// Decode PhysicalParam nested message
  static Map<String, dynamic> _decodePhysicalParam(List<int> data) {
    final result = <String, dynamic>{};
    int offset = 0;
    
    while (offset < data.length) {
      final key = data[offset++];
      final fieldNumber = key >> 3;
      final wireType = key & 0x07;
      
      if (wireType == 0) {
        final value = _decodeVarint(data, offset);
        offset = value['offset']!;
        final intValue = value['value']!;
        
        switch (fieldNumber) {
          case 2: // GearRatio
            result['gearRatioX10000'] = intValue;
            result['gearRatio'] = intValue / 10000.0;
            break;
          case 4: // BikeWeight
            result['bikeWeightX100'] = intValue;
            result['bikeWeightKg'] = intValue / 100.0;
            break;
          case 5: // RiderWeight
            result['riderWeightX100'] = intValue;
            result['riderWeightKg'] = intValue / 100.0;
            break;
        }
      }
    }
    
    return result;
  }
  
  /// Decode Info Response message (0x00)
  static Map<String, dynamic> _decodeInfoResponse(List<int> data) {
    final result = <String, dynamic>{};
    int offset = 0;
    
    while (offset < data.length) {
      if (offset >= data.length) break;
      
      final key = data[offset++];
      final fieldNumber = key >> 3;
      final wireType = key & 0x07;
      
      if (wireType == 0) {
        final value = _decodeVarint(data, offset);
        offset = value['offset']!;
        result['field$fieldNumber'] = value['value']!;
      } else if (wireType == 2) {
        final length = _decodeVarint(data, offset);
        offset = length['offset']!;
        final lengthValue = length['value']!;
        result['field${fieldNumber}_data'] = data.sublist(offset, offset + lengthValue);
        offset += lengthValue;
      }
    }
    
    return result;
  }
  
  /// Decode unsigned varint
  /// Returns map with 'value' and new 'offset'
  static Map<String, int> _decodeVarint(List<int> data, int offset) {
    int value = 0;
    int shift = 0;
    int currentOffset = offset;
    
    while (currentOffset < data.length) {
      final byte = data[currentOffset++];
      value |= (byte & 0x7F) << shift;
      
      if ((byte & 0x80) == 0) {
        return {'value': value, 'offset': currentOffset};
      }
      
      shift += 7;
    }
    
    return {'value': value, 'offset': currentOffset};
  }
  
  /// Decode ZigZag encoded signed integer
  static int _decodeZigZag(int zigzag) {
    return (zigzag >> 1) ^ -(zigzag & 1);
  }
}
