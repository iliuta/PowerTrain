import 'dart:math';
import 'package:flutter/services.dart';

/// Provides GPX files for route display
class GpxFileProvider {
  static List<String>? _cachedGpxFiles;
  
  /// Load available GPX files from the asset manifest
  static Future<List<String>> _loadGpxFileList() async {
    if (_cachedGpxFiles != null) {
      return _cachedGpxFiles!;
    }
    
    try {
      final manifestContent = await AssetManifest.loadFromAssetBundle(rootBundle);
      final manifests = manifestContent.listAssets();
      
      _cachedGpxFiles = manifests
          .where((String key) => key.startsWith('assets/gpx/') && key.endsWith('.gpx'))
          .toList();
      
      return _cachedGpxFiles!;
    } catch (e) {
      // Fallback to empty list if manifest loading fails
      _cachedGpxFiles = [];
      return _cachedGpxFiles!;
    }
  }

  /// Get a random GPX file path from available files
  static Future<String?> getRandomGpxFile() async {
    final files = await _loadGpxFileList();
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

  /// Get all available GPX file paths
  static Future<List<String>> getAllGpxFiles() async {
    return await _loadGpxFileList();
  }
}
