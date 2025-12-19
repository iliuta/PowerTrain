import 'dart:math';
import 'package:flutter/services.dart';
import 'package:ftms/core/models/device_types.dart';
import 'gpx_data.dart';

/// Provides GPX files for route display
class GpxFileProvider {
  /// Load available GPX files from the asset manifest for a specific device type
  static Future<List<String>> _loadGpxFileList(DeviceType deviceType) async {
    final manifestContent = await AssetManifest.loadFromAssetBundle(rootBundle);
    final manifests = manifestContent.listAssets();
    
    // Determine the directory based on device type
    final directory = _getDirectoryForDeviceType(deviceType);
    
    final files = manifests
        .where((String key) => key.startsWith(directory) && key.endsWith('.gpx'))
        .toList();
    
    return files;
  }

  /// Get the GPX directory path for a specific device type
  static String _getDirectoryForDeviceType(DeviceType deviceType) {
    return switch (deviceType) {
      DeviceType.rower => 'assets/gpx/rower/',
      DeviceType.indoorBike => 'assets/gpx/indoorBike/',
    };
  }

  /// Get a random GPX file path from available files for a specific device type
  static Future<String?> getRandomGpxFile(DeviceType deviceType) async {
    final files = await _loadGpxFileList(deviceType);
    if (files.isEmpty) return null;
    
    final random = Random();
    final index = random.nextInt(files.length);
    return files[index];
  }

  /// Load and return sorted list of GPX data for a device type
  static Future<List<GpxData>> getSortedGpxData(DeviceType deviceType) async {
    final files = await _loadGpxFileList(deviceType);
    final gpxDataList = <GpxData>[];

    for (final file in files) {
      final data = await GpxData.loadFromAsset(file);
      if (data != null) {
        gpxDataList.add(data);
      }
    }

    gpxDataList.sort((a, b) => a.totalDistance.compareTo(b.totalDistance));
    return gpxDataList;
  }
}
