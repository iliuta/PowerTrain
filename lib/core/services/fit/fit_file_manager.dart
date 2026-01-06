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
    int totalSize = 0;
    for (final file in files) {
      totalSize += file.fileSizeBytes;
    }
    return totalSize;
  }
}
