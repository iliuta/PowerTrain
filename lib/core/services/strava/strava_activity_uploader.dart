import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../utils/logger.dart';
import 'strava_config.dart';
import 'strava_token_manager.dart';

/// Handles uploading activities to Strava
class StravaActivityUploader {
  final StravaTokenManager _tokenManager;
  
  StravaActivityUploader({StravaTokenManager? tokenManager})
      : _tokenManager = tokenManager ?? StravaTokenManager();
  
  /// Uploads a FIT file activity to Strava
  Future<Map<String, dynamic>?> uploadActivity(
    String fitFilePath, 
    String activityName, {
    String activityType = 'workout',
    BuildContext? context,
  }) async {
    try {
      // Ensure we have a valid access token
      final accessToken = await _tokenManager.getValidAccessToken(context);
      if (accessToken == null) {
        logger.e('❌ No valid Strava access token available');
        return null;
      }
      
      logger.i('📤 Uploading activity to Strava: $activityName');
      
      // Create multipart request for file upload
      final request = http.MultipartRequest('POST', Uri.parse(StravaConfig.uploadUrl));
      
      // Add authorization header
      request.headers['Authorization'] = 'Bearer $accessToken';
      
      // Add the file to the request
      final file = await http.MultipartFile.fromPath('file', fitFilePath);
      request.files.add(file);
      
      // Add required fields
      request.fields['name'] = activityName;
      request.fields['data_type'] = 'fit';
      request.fields['activity_type'] = activityType;
      
      // Send the request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 201 || response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        logger.i('✅ Activity uploaded successfully: ${responseData['id']}');
        return responseData;
      } else {
        logger.e('❌ Failed to upload activity: ${response.statusCode}');
        logger.e('Response: ${response.body}');
        return null;
      }
    } catch (e) {
      logger.e('❌ Error uploading activity: $e');
      return null;
    }
  }
  
  /// Uploads activity with additional metadata
  Future<Map<String, dynamic>?> uploadActivityWithMetadata({
    required String fitFilePath,
    required String name,
    String? description,
    String activityType = 'workout',
    bool isPrivate = false,
    bool hasHeartrate = false,
    bool hasPower = false,
    BuildContext? context,
  }) async {
    try {
      final accessToken = await _tokenManager.getValidAccessToken(context);
      if (accessToken == null) {
        logger.e('❌ No valid Strava access token available');
        return null;
      }
      
      logger.i('📤 Uploading activity with metadata: $name');
      
      final request = http.MultipartRequest('POST', Uri.parse(StravaConfig.uploadUrl));
      request.headers['Authorization'] = 'Bearer $accessToken';
      
      // Add file
      final file = await http.MultipartFile.fromPath('file', fitFilePath);
      request.files.add(file);
      
      // Add metadata fields
      request.fields['name'] = name;
      request.fields['data_type'] = 'fit';
      request.fields['activity_type'] = activityType;
      
      if (description != null) {
        request.fields['description'] = description;
      }
      
      if (isPrivate) {
        request.fields['private'] = '1';
      }
      
      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 201 || response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        logger.i('✅ Activity with metadata uploaded successfully: ${responseData['id']}');
        return responseData;
      } else {
        logger.e('❌ Failed to upload activity with metadata: ${response.statusCode}');
        logger.e('Response: ${response.body}');
        return null;
      }
    } catch (e) {
      logger.e('❌ Error uploading activity with metadata: $e');
      return null;
    }
  }
}
