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

}

/// Information about a GPX file
class GpxFileInfo {
  final String assetPath;
  final String title;
  final double distance;

  const GpxFileInfo({
    required this.assetPath,
    required this.title,
    required this.distance,
  });

  /// Load and return sorted list of GPX files with data for a device type
  static Future<List<GpxFileInfo>> getSortedGpxFilesWithData(DeviceType deviceType) async {
    //final files = await GpxFileProvider._loadGpxFileList(deviceType);
    final files = await GpxFileProvider._loadGpxFileList(DeviceType.rower);
    final infos = <GpxFileInfo>[];

    for (final file in files) {
      final data = await GpxData.loadFromAsset(file);
      if (data != null) {
        final title = _extractTitleFromPath(file);
        infos.add(GpxFileInfo(
          assetPath: file,
          title: title,
          distance: data.totalDistance,
        ));
      }
    }

    infos.sort((a, b) => a.distance.compareTo(b.distance));
    return infos;
  }

  static String _extractTitleFromPath(String path) {
    final filename = path.split('/').last;
    return filename.replaceAll('.gpx', '').replaceAll('-', ' ');
  }
}
