import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:fit_tool/fit_tool.dart';
import '../../utils/logger.dart';

/// Model representing a FIT file with metadata
class FitFileInfo {
  final String fileName;
  final String filePath;
  final DateTime creationDate;
  final int fileSizeBytes;
  final String? activityName;
  final double? totalDistance;
  final Duration? totalTime;

  FitFileInfo({
    required this.fileName,
    required this.filePath,
    required this.creationDate,
    required this.fileSizeBytes,
    this.activityName,
    this.totalDistance,
    this.totalTime,
  });

  String get formattedSize {
    if (fileSizeBytes < 1024) {
      return '${fileSizeBytes}B';
    } else if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)}KB';
    } else {
      return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
  }
}

/// Model representing a data point from FIT file records
class FitDataPoint {
  final DateTime timestamp;
  final double? speed; // m/s
  final int? cadence; // rpm
  final int? heartRate; // bpm
  final int? power; // watts
  final double? distance; // meters
  final double? altitude; // meters

  FitDataPoint({
    required this.timestamp,
    this.speed,
    this.cadence,
    this.heartRate,
    this.power,
    this.distance,
    this.altitude,
  });
}

/// Model representing detailed FIT file data with time-series
class FitFileDetail {
  final String fileName;
  final String filePath;
  final DateTime creationDate;
  final int fileSizeBytes;
  final String activityName;
  final Sport? sport;
  final double? totalDistance;
  final Duration? totalTime;
  final List<FitDataPoint> dataPoints;

  FitFileDetail({
    required this.fileName,
    required this.filePath,
    required this.creationDate,
    required this.fileSizeBytes,
    required this.activityName,
    this.sport,
    this.totalDistance,
    this.totalTime,
    required this.dataPoints,
  });

  // Computed averages
  double? get averageSpeed => dataPoints.where((p) => p.speed != null).isNotEmpty
      ? dataPoints.where((p) => p.speed != null).map((p) => p.speed!).reduce((a, b) => a + b) / dataPoints.where((p) => p.speed != null).length
      : null;

  double? get averageCadence => dataPoints.where((p) => p.cadence != null).isNotEmpty
      ? dataPoints.where((p) => p.cadence != null).map((p) => p.cadence!.toDouble()).reduce((a, b) => a + b) / dataPoints.where((p) => p.cadence != null).length
      : null;

  double? get averageHeartRate => dataPoints.where((p) => p.heartRate != null).isNotEmpty
      ? dataPoints.where((p) => p.heartRate != null).map((p) => p.heartRate!.toDouble()).reduce((a, b) => a + b) / dataPoints.where((p) => p.heartRate != null).length
      : null;

  double? get averagePower => dataPoints.where((p) => p.power != null).isNotEmpty
      ? dataPoints.where((p) => p.power != null).map((p) => p.power!.toDouble()).reduce((a, b) => a + b) / dataPoints.where((p) => p.power != null).length
      : null;
}

/// Service for managing FIT files - listing, deleting, and checking sync status
class FitFileManager {
  static const String _fitFilesDirName = 'fit_files';

  /// Extract activity name from FIT filename
  /// Removes timestamp and extension, replaces underscores with spaces
  static String extractActivityNameFromFilename(String fileName) {
    // Extract activity name from filename (remove timestamp and extension)
    final baseName = fileName
        .replaceAll(RegExp(r'_\d{8}_\d{4}\.fit$'), '')
        .replaceAll('_', ' ');
    return '$baseName - PowerTrain';
  }

  /// Get the FIT files directory
  Future<Directory> _getFitFilesDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    return Directory('${directory.path}/$_fitFilesDirName');
  }

  /// Get all FIT files sorted by creation date (newest first)
  Future<List<FitFileInfo>> getAllFitFiles() async {
    try {
      final fitDir = await _getFitFilesDirectory();
      
      if (!await fitDir.exists()) {
        logger.i('FIT files directory does not exist');
        return [];
      }

      final files = await fitDir
          .list()
          .where((entity) => entity is File && entity.path.endsWith('.fit'))
          .cast<File>()
          .toList();

      final fitFiles = <FitFileInfo>[];

      for (final file in files) {
        try {
          final stat = await file.stat();
          final fileName = file.path.split('/').last;
          
          // Parse FIT file to extract activity data
          String activityName = extractActivityNameFromFilename(fileName); // Default to filename-based name
          double? totalDistance;
          Duration? totalTime;
          
          try {
            // Use FitDecoder to extract messages from the FIT file
            final messages = <dynamic>[];
            final byteStream = file.openRead();
            await for (final message in byteStream.transform(FitDecoder())) {
              messages.add(message);
            }
            
            // Extract data from session message (contains activity summary)
            final sessionMessages = messages.whereType<SessionMessage>();
            
            if (sessionMessages.isNotEmpty) {
              final session = sessionMessages.first;
              totalDistance = session.totalDistance;
              if (session.totalTimerTime != null) {
                totalTime = Duration(seconds: session.totalTimerTime!.toInt());
              }
              // Keep filename-based name as primary, but log if we found session data
              try {
                final sessionName = session.name;
                // Check if session name is meaningful (not generic like "session")
                final isMeaningfulName = sessionName.isNotEmpty && 
                                        !sessionName.toLowerCase().contains('session') &&
                                        sessionName != 'Unknown';
                if (isMeaningfulName) {
                  logger.i('Found meaningful session name in FIT file: $sessionName (keeping filename-based: $activityName)');
                }
              } catch (e) {
                // Keep filename-based name
              }
            }
          } catch (e) {
            logger.w('Failed to parse FIT file ${file.path}: $e');
            // Continue with filename-based activity name
          }
          
          fitFiles.add(FitFileInfo(
            fileName: fileName,
            filePath: file.path,
            creationDate: stat.modified,
            fileSizeBytes: stat.size,
            activityName: activityName,
            totalDistance: totalDistance,
            totalTime: totalTime,
          ));
        } catch (e) {
          logger.w('Failed to get stats for file ${file.path}: $e');
        }
      }

      // Sort by creation date (newest first)
      fitFiles.sort((a, b) => b.creationDate.compareTo(a.creationDate));

      logger.i('Found ${fitFiles.length} FIT files');
      return fitFiles;
    } catch (e) {
      logger.e('Failed to list FIT files: $e');
      return [];
    }
  }

  /// Delete a specific FIT file
  Future<bool> deleteFitFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        logger.i('Successfully deleted FIT file: $filePath');
        return true;
      } else {
        logger.w('FIT file not found: $filePath');
        return false;
      }
    } catch (e) {
      logger.e('Failed to delete FIT file $filePath: $e');
      return false;
    }
  }

  /// Delete multiple FIT files
  Future<List<String>> deleteFitFiles(List<String> filePaths) async {
    final failedDeletions = <String>[];
    
    for (final filePath in filePaths) {
      final success = await deleteFitFile(filePath);
      if (!success) {
        failedDeletions.add(filePath);
      }
    }
    
    return failedDeletions;
  }

  /// Get the total number of FIT files
  Future<int> getFitFileCount() async {
    final files = await getAllFitFiles();
    return files.length;
  }

  /// Get the total size of all FIT files in bytes
  Future<int> getTotalFitFileSize() async {
    final files = await getAllFitFiles();
    return files.fold<int>(0, (total, file) => total + file.fileSizeBytes);
  }

  /// Get detailed data from a specific FIT file including time-series data points
  Future<FitFileDetail?> getFitFileDetail(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        logger.w('FIT file not found: $filePath');
        return null;
      }

      final stat = await file.stat();
      final fileName = file.path.split('/').last;

      // Parse FIT file to extract all data
      final messages = <dynamic>[];
      final byteStream = file.openRead();
      await for (final message in byteStream.transform(FitDecoder())) {
        messages.add(message);
      }

      // Extract session data
      String activityName = extractActivityNameFromFilename(fileName);
      Sport? sport;
      double? totalDistance;
      Duration? totalTime;

      final sessionMessages = messages.whereType<SessionMessage>();
      if (sessionMessages.isNotEmpty) {
        final session = sessionMessages.first;
        sport = session.sport;
        totalDistance = session.totalDistance;
        if (session.totalTimerTime != null) {
          totalTime = Duration(seconds: session.totalTimerTime!.toInt());
        }
        // Try to get activity name from session
        try {
          final sessionName = session.name;
          final isMeaningfulName = sessionName.isNotEmpty &&
                                  !sessionName.toLowerCase().contains('session') &&
                                  sessionName != 'Unknown';
          if (isMeaningfulName) {
            activityName = sessionName;
          }
        } catch (e) {
          // Keep filename-based name
        }
      }

      // Extract record data points
      final dataPoints = <FitDataPoint>[];
      final recordMessages = messages.whereType<RecordMessage>();

      // Sort records by timestamp
      final sortedRecords = recordMessages.toList()
        ..sort((a, b) => (a.timestamp ?? 0).compareTo(b.timestamp ?? 0));

      FitDataPoint? previousPoint;

      for (final record in sortedRecords) {
        try {
          final timestamp = record.timestamp;
          if (timestamp != null) {
            // timestamp is already in milliseconds since Unix epoch (January 1st, 1970)
            final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);

            // Calculate speed if not present
            double? calculatedSpeed = record.speed;
            if (calculatedSpeed == null && previousPoint != null && record.distance != null && previousPoint.distance != null) {
              final distanceDiff = record.distance! - previousPoint.distance!;
              final timeDiff = dateTime.difference(previousPoint.timestamp).inSeconds;
              if (timeDiff > 0 && distanceDiff >= 0) {
                calculatedSpeed = distanceDiff / timeDiff; // m/s
              }
            }

            final point = FitDataPoint(
              timestamp: dateTime,
              speed: calculatedSpeed,
              cadence: record.cadence,
              heartRate: record.heartRate,
              power: record.power,
              distance: record.distance,
              altitude: record.altitude,
            );

            dataPoints.add(point);
            previousPoint = point;
          }
        } catch (e) {
          logger.w('Failed to parse record: $e');
        }
      }

      // Sort data points by timestamp
      dataPoints.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      return FitFileDetail(
        fileName: fileName,
        filePath: filePath,
        creationDate: stat.modified,
        fileSizeBytes: stat.size,
        activityName: activityName,
        sport: sport,
        totalDistance: totalDistance,
        totalTime: totalTime,
        dataPoints: dataPoints,
      );
    } catch (e) {
      logger.e('Failed to get FIT file detail for $filePath: $e');
      return null;
    }
  }
}
