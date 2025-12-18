import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/services/fit/fit_file_manager.dart';
import '../../core/services/strava/strava_service.dart';
import '../../core/utils/logger.dart';

/// Screen for managing unsynchronized FIT files
class FitFileManagerPage extends StatefulWidget {
  const FitFileManagerPage({
    super.key,
    FitFileManager? fitFileManager,
    StravaService? stravaService,
  }) : 
    _fitFileManager = fitFileManager,
    _stravaService = stravaService;

  final FitFileManager? _fitFileManager;
  final StravaService? _stravaService;

  @override
  State<FitFileManagerPage> createState() => _FitFileManagerPageState();
}

class _FitFileManagerPageState extends State<FitFileManagerPage> {
  late final FitFileManager _fitFileManager;
  late final StravaService _stravaService;
  
  List<FitFileInfo> _fitFiles = [];
  bool _isLoading = true;
  bool _isDeleting = false;
  Set<String> _selectedFiles = {};
  final Set<String> _uploadingFiles = {};

  @override
  void initState() {
    super.initState();
    _fitFileManager = widget._fitFileManager ?? FitFileManager();
    _stravaService = widget._stravaService ?? StravaService();
    _loadFitFiles();
  }

  Future<void> _loadFitFiles() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final files = await _fitFileManager.getAllFitFiles();
      setState(() {
        _fitFiles = files;
        _selectedFiles.clear();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load FIT files: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteSelectedFiles() async {
    if (_selectedFiles.isEmpty) return;

    final confirmed = await _showDeleteConfirmationDialog();
    if (!confirmed) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      final filesToDelete = _selectedFiles.toList();
      final failedDeletions = await _fitFileManager.deleteFitFiles(filesToDelete);
      
      if (failedDeletions.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully deleted ${filesToDelete.length} file(s)'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete ${failedDeletions.length} file(s)'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

      await _loadFitFiles();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting files: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isDeleting = false;
      });
    }
  }

  Future<bool> _showDeleteConfirmationDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete FIT Files'),
        content: Text(
          'Are you sure you want to delete ${_selectedFiles.length} selected file(s)? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _uploadToStrava(FitFileInfo fitFile) async {
    // Check if user is authenticated
    final isAuthenticated = await _stravaService.isAuthenticated();
    if (!isAuthenticated) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please authenticate with Strava first in Settings'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() {
      _uploadingFiles.add(fitFile.filePath);
    });

    try {
      // Extract activity name from filename (remove timestamp and extension)
      final baseName = fitFile.fileName
          .replaceAll(RegExp(r'_\d{8}_\d{4}\.fit$'), '')
          .replaceAll('_', ' ');
      final activityName = '$baseName - PowerTrain';

      // For now, default to cycling - in the future this could be determined from the file
      const activityType = 'ride';

      logger.i('Uploading FIT file to Strava: ${fitFile.fileName}');

      final uploadResult = await _stravaService.uploadActivity(
        fitFile.filePath,
        activityName,
        activityType: activityType,
      );

      if (uploadResult != null) {
        // Upload successful - delete the file
        final deleteSuccess = await _fitFileManager.deleteFitFile(fitFile.filePath);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                deleteSuccess 
                  ? 'Successfully uploaded to Strava and deleted local file'
                  : 'Uploaded to Strava but failed to delete local file',
              ),
              backgroundColor: deleteSuccess ? Colors.green : Colors.orange,
            ),
          );
        }

        if (deleteSuccess) {
          await _loadFitFiles(); // Refresh the list
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to upload to Strava'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      logger.e('Error uploading to Strava: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading to Strava: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _uploadingFiles.remove(fitFile.filePath);
      });
    }
  }

  Future<void> _shareFitFile(FitFileInfo fitFile) async {
    try {
      final shareParams = ShareParams(
        files: [
          XFile(fitFile.filePath)
        ],
        text: 'FIT workout file: ${fitFile.fileName}'
      );
      await SharePlus.instance.share(shareParams);
    } catch (e) {
      logger.e('Error sharing FIT file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _toggleFileSelection(String filePath) {
    setState(() {
      if (_selectedFiles.contains(filePath)) {
        _selectedFiles.remove(filePath);
      } else {
        _selectedFiles.add(filePath);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedFiles.length == _fitFiles.length) {
        _selectedFiles.clear();
      } else {
        _selectedFiles = _fitFiles.map((f) => f.filePath).toSet();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FIT Files'),
        actions: [
          if (_fitFiles.isNotEmpty)
            TextButton(
              onPressed: _selectAll,
              child: Text(
                _selectedFiles.length == _fitFiles.length ? 'Deselect All' : 'Select All',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          IconButton(
            onPressed: _loadFitFiles,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: _selectedFiles.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _isDeleting ? null : _deleteSelectedFiles,
              icon: _isDeleting 
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete),
              label: Text(_isDeleting ? 'Deleting...' : 'Delete Selected'),
              backgroundColor: Colors.red,
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_fitFiles.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No FIT files found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'FIT files will appear here after completing training sessions',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (_fitFiles.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_fitFiles.length} file(s) • Tap to select, long press for options',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: _fitFiles.length,
            itemBuilder: (context, index) {
              final fitFile = _fitFiles[index];
              final isSelected = _selectedFiles.contains(fitFile.filePath);
              final isUploading = _uploadingFiles.contains(fitFile.filePath);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: Checkbox(
                    value: isSelected,
                    onChanged: isUploading 
                      ? null 
                      : (_) => _toggleFileSelection(fitFile.filePath),
                  ),
                  title: Text(
                    fitFile.fileName,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      color: isUploading ? Colors.grey : null,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('MMM dd, yyyy - HH:mm').format(fitFile.creationDate),
                        style: TextStyle(
                          fontSize: 12,
                          color: isUploading ? Colors.grey : null,
                        ),
                      ),
                      Text(
                        fitFile.formattedSize,
                        style: TextStyle(
                          fontSize: 12,
                          color: isUploading ? Colors.grey : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  trailing: isUploading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : PopupMenuButton<String>(
                          onSelected: (value) {
                            switch (value) {
                              case 'upload':
                                _uploadToStrava(fitFile);
                                break;
                              case 'download':
                                _shareFitFile(fitFile);
                                break;
                              case 'delete':
                                _selectedFiles.clear();
                                _selectedFiles.add(fitFile.filePath);
                                _deleteSelectedFiles();
                                break;
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'upload',
                              child: ListTile(
                                leading: Icon(Icons.cloud_upload),
                                title: Text('Upload to Strava'),
                                dense: true,
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'download',
                              child: ListTile(
                                leading: Icon(Icons.download),
                                title: Text('Share'),
                                dense: true,
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: ListTile(
                                leading: Icon(Icons.delete, color: Colors.red),
                                title: Text('Delete'),
                                dense: true,
                              ),
                            ),
                          ],
                        ),
                  onTap: isUploading 
                    ? null 
                    : () => _toggleFileSelection(fitFile.filePath),
                  selected: isSelected,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
