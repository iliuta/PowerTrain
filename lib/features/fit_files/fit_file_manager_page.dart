// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/services/analytics/analytics_service.dart';
import '../../core/services/fit/fit_file_manager.dart';
import '../../core/services/strava/strava_service.dart';
import '../../core/utils/logger.dart';
import '../../l10n/app_localizations.dart';
import 'fit_file_detail_page.dart';

/// Screen for managing unsynchronized FIT files
class FitFileManagerPage extends StatefulWidget {
  const FitFileManagerPage({
    super.key,
    FitFileManager? fitFileManager,
    StravaService? stravaService,
    AnalyticsService? analyticsService,
  }) : 
    _fitFileManager = fitFileManager,
    _stravaService = stravaService,
    _analyticsService = analyticsService;

  final FitFileManager? _fitFileManager;
  final StravaService? _stravaService;
  final AnalyticsService? _analyticsService;

  @override
  State<FitFileManagerPage> createState() => _FitFileManagerPageState();
}

class _FitFileManagerPageState extends State<FitFileManagerPage> {
  late final FitFileManager _fitFileManager;
  late final StravaService _stravaService;
  late final AnalyticsService _analyticsService;
  
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
    _analyticsService = widget._analyticsService ?? AnalyticsService();
    _analyticsService.logScreenView(screenName: 'fit_file_manager');
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
            content: Text(AppLocalizations.of(context)!.failedToLoadFitFiles(e.toString())),
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
              content: Text(AppLocalizations.of(context)!.successfullyDeletedFiles(filesToDelete.length.toString())),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.failedToDeleteFiles(failedDeletions.length.toString())),
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
            content: Text(AppLocalizations.of(context)!.errorDeletingFiles(e.toString())),
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
        title: Text(AppLocalizations.of(context)!.deleteFitFiles),
        content: Text(
          AppLocalizations.of(context)!.deleteFitFilesConfirmation(_selectedFiles.length.toString()),
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
          SnackBar(
            content: Text(AppLocalizations.of(context)!.stravaAuthRequired),
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
      // Use activity name from the fit file info (already processed by the helper method)
      final activityName = fitFile.activityName ?? FitFileManager.extractActivityNameFromFilename(fitFile.fileName);

      // For now, default to cycling - in the future this could be determined from the file
      const activityType = 'ride';

      logger.i('Uploading FIT file to Strava: ${fitFile.fileName}');

      final uploadResult = await _stravaService.uploadActivity(
        fitFile.filePath,
        activityName,
        activityType: activityType,
        context: context,
      );

      if (uploadResult != null) {
        // Upload successful - delete the file
        final deleteSuccess = await _fitFileManager.deleteFitFile(fitFile.filePath);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                deleteSuccess
                  ? AppLocalizations.of(context)!.uploadedToStravaAndDeleted
                  : AppLocalizations.of(context)!.uploadedToStravaFailedDelete,
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
            SnackBar(
              content: Text(AppLocalizations.of(context)!.failedToUploadToStrava),
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
            content: Text(AppLocalizations.of(context)!.errorUploadingToStrava(e.toString())),
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
            content: Text(AppLocalizations.of(context)!.errorSharingFile(e.toString())),
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

  void _navigateToDetail(FitFileInfo fitFile) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FitFileDetailPage(
          fitFileInfo: fitFile,
          fitFileManager: _fitFileManager,
          analyticsService: _analyticsService,
        ),
      ),
    );
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
        title: Text(AppLocalizations.of(context)!.fitFiles),
        actions: [
          if (_fitFiles.isNotEmpty)
            TextButton(
              onPressed: _selectAll,
              child: Text(
                _selectedFiles.length == _fitFiles.length ? AppLocalizations.of(context)!.deselectAll : AppLocalizations.of(context)!.selectAll,
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
              label: Text(_isDeleting ? AppLocalizations.of(context)!.deleting : AppLocalizations.of(context)!.deleteSelected),
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.folder_open,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.noFitFilesFound,
              style: const TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.fitFilesWillAppear,
              style: const TextStyle(
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
                    AppLocalizations.of(context)!.filesInfo(_fitFiles.length.toString()),
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
                    fitFile.activityName ?? FitFileManager.extractActivityNameFromFilename(fitFile.fileName),
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
                        DateFormat.yMd(Localizations.localeOf(context).toString()).add_Hm().format(fitFile.creationDate),
                        style: TextStyle(
                          fontSize: 12,
                          color: isUploading ? Colors.grey : null,
                        ),
                      ),
                      Row(
                        children: [
                          if (fitFile.totalDistance != null)
                            Text(
                              '${(fitFile.totalDistance! / 1000).toStringAsFixed(1)}km',
                              style: TextStyle(
                                fontSize: 12,
                                color: isUploading ? Colors.grey : Colors.grey[600],
                              ),
                            ),
                          if (fitFile.totalDistance != null && fitFile.totalTime != null)
                            Text(
                              ' • ',
                              style: TextStyle(
                                fontSize: 12,
                                color: isUploading ? Colors.grey : Colors.grey[600],
                              ),
                            ),
                          if (fitFile.totalTime != null)
                            Text(
                              _formatDuration(fitFile.totalTime!),
                              style: TextStyle(
                                fontSize: 12,
                                color: isUploading ? Colors.grey : Colors.grey[600],
                              ),
                            ),
                          if (fitFile.totalDistance == null && fitFile.totalTime == null)
                            Text(
                              fitFile.formattedSize,
                              style: TextStyle(
                                fontSize: 12,
                                color: isUploading ? Colors.grey : Colors.grey[600],
                              ),
                            ),
                        ],
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
                            PopupMenuItem(
                              value: 'upload',
                              child: ListTile(
                                leading: Icon(Icons.cloud_upload),
                                title: Text(AppLocalizations.of(context)!.uploadToStrava),
                                dense: true,
                              ),
                            ),
                            PopupMenuItem(
                              value: 'download',
                              child: ListTile(
                                leading: Icon(Icons.download),
                                title: Text(AppLocalizations.of(context)!.share),
                                dense: true,
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: ListTile(
                                leading: Icon(Icons.delete, color: Colors.red),
                                title: Text(AppLocalizations.of(context)!.delete),
                                dense: true,
                              ),
                            ),
                          ],
                        ),
                  onTap: isUploading 
                    ? null 
                    : () => _navigateToDetail(fitFile),
                  onLongPress: isUploading 
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

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }
}
