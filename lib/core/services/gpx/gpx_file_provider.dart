import 'dart:math';
import 'package:flutter/services.dart';
import 'package:ftms/core/models/device_types.dart';

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

  /// Verify that a GPX file exists
  static Future<bool> gpxFileExists(String path) async {
    try {
      await rootBundle.loadString(path);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get all available GPX file paths for a specific device type
  static Future<List<String>> getAllGpxFiles(DeviceType deviceType) async {
    return await _loadGpxFileList(deviceType);
  }
}
