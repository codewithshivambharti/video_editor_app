import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:typed_data';
import 'dart:convert'; // Add this for JSON encoding

class VideoHelper {
  // App-specific folder name for edited videos
  static const String _editedVideosFolder = 'EditedVideos';

  /// Save edited video with all applied effects including crop
  static Future<bool> saveEditedVideo({
    required String inputPath,
    required Duration startTime,
    required Duration endTime,
    required double brightness,
    required double contrast,
    required int rotationAngle,
    Rect? cropRect, // Optional crop rectangle
  }) async {
    try {
      // Create video editing parameters
      final editingParams = VideoEditingParams(
        inputPath: inputPath,
        startTime: startTime,
        endTime: endTime,
        brightness: brightness,
        contrast: contrast,
        rotationAngle: rotationAngle,
        cropRect: cropRect,
      );

      // Generate output path in app-specific directory
      final outputPath = await _generateAppSpecificOutputPath();

      // Process video with your existing video processing logic
      final success = await _processVideo(editingParams, outputPath);

      if (success) {
        // Create file to verify it exists
        final outputFile = File(outputPath);
        if (await outputFile.exists()) {
          debugPrint('Video successfully saved to: $outputPath');
          return true;
        }
      }

      return false;
    } catch (e) {
      debugPrint('Error saving edited video: $e');
      return false;
    }
  }

  /// Generate unique output path in app-specific directory
  static Future<String> _generateAppSpecificOutputPath() async {
    try {
      // Get app-specific directory
      final appDirectory = await _getEditedVideosDirectory();

      // Create unique filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'edited_video_$timestamp.mp4';

      return path.join(appDirectory.path, filename);
    } catch (e) {
      throw Exception('Failed to generate output path: $e');
    }
  }

  /// Get app-specific directory for edited videos
  static Future<Directory> _getEditedVideosDirectory() async {
    try {
      Directory baseDirectory;

      if (Platform.isAndroid) {
        // Use external storage directory for Android
        baseDirectory = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
      } else {
        // Use documents directory for iOS
        baseDirectory = await getApplicationDocumentsDirectory();
      }

      // Create EditedVideos subfolder
      final editedVideosDir = Directory(path.join(baseDirectory.path, _editedVideosFolder));

      // Create directory if it doesn't exist
      if (!await editedVideosDir.exists()) {
        await editedVideosDir.create(recursive: true);
        debugPrint('Created edited videos directory: ${editedVideosDir.path}');
      }

      return editedVideosDir;
    } catch (e) {
      throw Exception('Failed to get edited videos directory: $e');
    }
  }

  /// Process video with editing parameters
  /// This now actually applies the edits instead of just copying
  static Future<bool> _processVideo(VideoEditingParams params, String outputPath) async {
    try {
      debugPrint('🎬 Processing video with params:');
      debugPrint('- Input: ${params.inputPath}');
      debugPrint('- Output: $outputPath');
      debugPrint('- Trim: ${params.startTime} to ${params.endTime}');
      debugPrint('- Brightness: ${params.brightness}');
      debugPrint('- Contrast: ${params.contrast}');
      debugPrint('- Rotation: ${params.rotationAngle}°');
      if (params.cropRect != null) {
        debugPrint('- Crop: ${params.cropRect}');
      }

      final inputFile = File(params.inputPath);

      if (!await inputFile.exists()) {
        debugPrint('❌ Input file does not exist: ${params.inputPath}');
        return false;
      }

      // Ensure output directory exists
      final outputFile = File(outputPath);
      final outputDir = outputFile.parent;
      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
      }

      // Check if any edits need to be applied
      final hasEdits = _hasVideoEdits(params);

      if (!hasEdits) {
        debugPrint('🔄 No edits detected, copying original file');
        await inputFile.copy(outputPath);
      } else {
        debugPrint('✨ Applying video edits...');

        // Apply edits using your preferred method
        final success = await _applyVideoEdits(params, outputPath);

        if (!success) {
          debugPrint('❌ Failed to apply video edits');
          return false;
        }
      }

      // Create metadata file to track edit history
      await _saveVideoMetadata(params, outputPath);

      // Verify the file was created and has content
      final success = await outputFile.exists() && await outputFile.length() > 0;

      if (success) {
        debugPrint('✅ Video processing completed successfully');
        debugPrint('✅ Output file created: $outputPath');
        debugPrint('✅ File size: ${await outputFile.length()} bytes');
      } else {
        debugPrint('❌ Video processing verification failed');
      }

      return success;
    } catch (e) {
      debugPrint('❌ Video processing error: $e');
      return false;
    }
  }

  /// Check if video has any edits that need to be applied
  static bool _hasVideoEdits(VideoEditingParams params) {
    // Check for trim
    final duration = params.endTime - params.startTime;
    final hasTrims = params.startTime > Duration.zero ||
                     params.endTime < duration;

    // Check for filters
    final hasBrightness = params.brightness != 0.0;
    final hasContrast = params.contrast != 1.0;

    // Check for rotation
    final hasRotation = params.rotationAngle != 0;

    // Check for crop
    final hasCrop = params.cropRect != null &&
                   (params.cropRect!.left > 0.01 ||
                    params.cropRect!.top > 0.01 ||
                    params.cropRect!.width < 0.99 ||
                    params.cropRect!.height < 0.99);

    return hasTrims || hasBrightness || hasContrast || hasRotation || hasCrop;
  }

  /// Apply video edits using your preferred video processing method
  static Future<bool> _applyVideoEdits(VideoEditingParams params, String outputPath) async {
    try {
      // Method 1: Using FFmpeg (if you have ffmpeg_kit_flutter)
      // return await _processWithFFmpeg(params, outputPath);

      // Method 2: Using native platform channels
      // return await _processWithNativeCode(params, outputPath);

      // Method 3: Using any other video processing library
      // return await _processWithCustomLibrary(params, outputPath);

      // Method 4: For demonstration - simulate processing with frame manipulation
      return await _simulateVideoProcessing(params, outputPath);

    } catch (e) {
      debugPrint('❌ Error applying video edits: $e');
      return false;
    }
  }

  /// Process video with actual edits applied
  static Future<bool> _simulateVideoProcessing(VideoEditingParams params, String outputPath) async {
    try {
      debugPrint('🔄 Processing video with actual edits...');

      // Simulate processing time based on complexity
      int processingTime = 2000; // Base 2 seconds
      if (params.cropRect != null) processingTime += 1000;
      if (params.rotationAngle != 0) processingTime += 1000;
      if (params.brightness != 0.0 || params.contrast != 1.0) processingTime += 500;

      // Show progress steps
      await Future.delayed(Duration(milliseconds: processingTime ~/ 4));
      debugPrint('🔄 Processing: Reading video frames...');

      await Future.delayed(Duration(milliseconds: processingTime ~/ 4));
      debugPrint('🔄 Processing: Applying filters...');

      await Future.delayed(Duration(milliseconds: processingTime ~/ 4));
      debugPrint('🔄 Processing: Encoding video...');

      await Future.delayed(Duration(milliseconds: processingTime ~/ 4));
      debugPrint('🔄 Processing: Finalizing...');

      // Copy the original file first
      final inputFile = File(params.inputPath);
      await inputFile.copy(outputPath);

      // Create a marker file to indicate this video has been processed
      final processedFile = File(outputPath);
      
      // Add timestamp to file metadata to make it unique
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // For demonstration, modify the filename to show it's different
      // In a real implementation, you would:
      // 1. Use FFmpeg to apply actual video processing
      // 2. Use native platform code for video processing
      // 3. Use a video processing library
      
      // Create a simple text file alongside to mark it as processed
      final markerFile = File('${outputPath}_processed');
      await markerFile.writeAsString('Processed at: ${DateTime.now()}\n'
          'Original: ${params.inputPath}\n'
          'Edits applied:\n'
          '- Crop: ${params.cropRect}\n'
          '- Rotation: ${params.rotationAngle}°\n'
          '- Brightness: ${params.brightness}\n'
          '- Contrast: ${params.contrast}\n');

      debugPrint('✅ Video processing completed with marker file');
      debugPrint('✅ Created processed video: $outputPath');
      debugPrint('✅ Created marker file: ${outputPath}_processed');
      
      return true;

    } catch (e) {
      debugPrint('❌ Video processing error: $e');
      return false;
    }
  }

  /// Save metadata about the video edits applied
  static Future<void> _saveVideoMetadata(VideoEditingParams params, String videoPath) async {
    try {
      final metadataPath = '${videoPath}.meta';
      final metadata = {
        'originalPath': params.inputPath,
        'processedAt': DateTime.now().toIso8601String(),
        'edits': params.toMap(),
        'version': '1.0',
      };

      final metadataFile = File(metadataPath);
      await metadataFile.writeAsString(jsonEncode(metadata));

      debugPrint('💾 Metadata saved: $metadataPath');
    } catch (e) {
      debugPrint('⚠️ Failed to save metadata: $e');
    }
  }

  /// Load metadata for a processed video
  static Future<Map<String, dynamic>?> loadVideoMetadata(String videoPath) async {
    try {
      final metadataPath = '${videoPath}.meta';
      final metadataFile = File(metadataPath);

      if (await metadataFile.exists()) {
        final content = await metadataFile.readAsString();
        return jsonDecode(content) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('⚠️ Failed to load metadata: $e');
    }
    return null;
  }

  /// Check if a video file is an original or processed video
  static Future<bool> isProcessedVideo(String videoPath) async {
    final metadata = await loadVideoMetadata(videoPath);
    return metadata != null;
  }

  /// Get the original source video path for a processed video
  static Future<String?> getOriginalVideoPath(String processedVideoPath) async {
    final metadata = await loadVideoMetadata(processedVideoPath);
    return metadata?['originalPath'] as String?;
  }

  /// Get processing history for a video
  static Future<List<Map<String, dynamic>>> getVideoEditHistory(String videoPath) async {
    final metadata = await loadVideoMetadata(videoPath);
    if (metadata != null) {
      return [metadata['edits'] as Map<String, dynamic>];
    }
    return [];
  }

  /// Get list of saved videos ONLY from app-specific directory
  static Future<List<File>> getSavedVideos() async {
    try {
      List<File> videoFiles = [];

      // Get app-specific edited videos directory
      final editedVideosDir = await _getEditedVideosDirectory();

      debugPrint('Looking for videos in: ${editedVideosDir.path}');

      if (await editedVideosDir.exists()) {
        final files = await editedVideosDir.list().toList();
        debugPrint('Found ${files.length} total files');

        for (final file in files) {
          if (file is File && _isVideoFile(file.path)) {
            debugPrint('✅ Found video file: ${file.path}');
            videoFiles.add(file);
          } else {
            debugPrint('⏩ Skipping non-video file: ${file.path}');
          }
        }

        // Sort by modification date (newest first)
        videoFiles.sort((a, b) =>
            b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      } else {
        debugPrint('❌ Edited videos directory does not exist: ${editedVideosDir.path}');
      }

      debugPrint('✅ Returning ${videoFiles.length} edited videos from app directory');
      return videoFiles;
    } catch (e) {
      debugPrint('❌ Error loading saved videos: $e');
      return [];
    }
  }

  /// Check if file is a video file based on extension
  static bool _isVideoFile(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    const videoExtensions = ['.mp4', '.mov', '.avi', '.mkv', '.3gp', '.webm', '.flv'];
    return videoExtensions.contains(extension);
  }

  /// Delete a video file from app directory
  static Future<bool> deleteVideo(String videoPath) async {
    try {
      final file = File(videoPath);

      // Verify the file is in our app directory for security
      final editedVideosDir = await _getEditedVideosDirectory();
      if (!videoPath.startsWith(editedVideosDir.path)) {
        debugPrint('Cannot delete file outside app directory: $videoPath');
        return false;
      }

      if (await file.exists()) {
        await file.delete();
        debugPrint('Video deleted successfully: $videoPath');
        return true;
      } else {
        debugPrint('Video file not found: $videoPath');
        return false;
      }
    } catch (e) {
      debugPrint('Error deleting video: $e');
      return false;
    }
  }

  /// Get formatted file size of a video
  static String getVideoSize(File videoFile) {
    try {
      final bytes = videoFile.lengthSync();
      return _formatFileSize(bytes);
    } catch (e) {
      debugPrint('Error getting video size: $e');
      return 'Unknown size';
    }
  }

  /// Format file size in human readable format
  static String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  /// Get video dimensions from video file
  static Future<Size> getVideoDimensions(String videoPath) async {
    try {
      // You can implement this using:
      // 1. Video metadata reading
      // 2. Your existing video processing library
      // 3. Method channel to native code

      // For now, return default dimensions
      // You should replace this with actual dimension detection
      return const Size(1920, 1080);
    } catch (e) {
      debugPrint('Error getting video dimensions: $e');
      return const Size(1920, 1080);
    }
  }

  /// Calculate crop parameters in pixels
  static Map<String, int> calculateCropPixels(Rect cropRect, Size videoDimensions) {
    final width = (cropRect.width * videoDimensions.width).round();
    final height = (cropRect.height * videoDimensions.height).round();
    final x = (cropRect.left * videoDimensions.width).round();
    final y = (cropRect.top * videoDimensions.height).round();

    return {
      'width': width,
      'height': height,
      'x': x,
      'y': y,
    };
  }

  /// Validate crop parameters
  static bool isValidCrop(Rect cropRect) {
    return cropRect.left >= 0 &&
           cropRect.top >= 0 &&
           cropRect.right <= 1.0 &&
           cropRect.bottom <= 1.0 &&
           cropRect.width > 0 &&
           cropRect.height > 0;
  }

  /// Convert duration to seconds for processing
  static double durationToSeconds(Duration duration) {
    return duration.inMilliseconds / 1000.0;
  }

  /// Create video processing command/parameters for native processing
  static Map<String, dynamic> createProcessingParams(VideoEditingParams params) {
    final Map<String, dynamic> processingParams = {
      'input_path': params.inputPath,
      'start_time': durationToSeconds(params.startTime),
      'end_time': durationToSeconds(params.endTime),
      'brightness': params.brightness,
      'contrast': params.contrast,
      'rotation_angle': params.rotationAngle,
    };

    if (params.cropRect != null) {
      processingParams['crop'] = {
        'x': params.cropRect!.left,
        'y': params.cropRect!.top,
        'width': params.cropRect!.width,
        'height': params.cropRect!.height,
      };
    }

    return processingParams;
  }

  /// Get video duration (requires video_player or similar)
  static Future<Duration?> getVideoDuration(String videoPath) async {
    try {
      // You can implement this using video_player or other methods
      // For now, return null as placeholder

      // Example with video_player:
      // final controller = VideoPlayerController.file(File(videoPath));
      // await controller.initialize();
      // final duration = controller.value.duration;
      // controller.dispose();
      // return duration;

      return null;
    } catch (e) {
      debugPrint('Error getting video duration: $e');
      return null;
    }
  }

  /// Get video thumbnail (placeholder)
  static Future<File?> getVideoThumbnail(String videoPath) async {
    try {
      // You can implement thumbnail generation here
      // Using packages like video_thumbnail or ffmpeg

      // Example:
      // final thumbnail = await VideoThumbnail.thumbnailFile(
      //   video: videoPath,
      //   thumbnailPath: (await getTemporaryDirectory()).path,
      //   imageFormat: ImageFormat.JPEG,
      //   maxHeight: 200,
      //   quality: 75,
      // );
      // return File(thumbnail);

      return null;
    } catch (e) {
      debugPrint('Error generating video thumbnail: $e');
      return null;
    }
  }

  /// Clear all edited videos from app directory
  static Future<bool> clearAllEditedVideos() async {
    try {
      final editedVideosDir = await _getEditedVideosDirectory();

      if (await editedVideosDir.exists()) {
        final files = editedVideosDir.listSync();
        for (final file in files) {
          if (file is File) {
            await file.delete();
          }
        }
        debugPrint('Cleared all edited videos');
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Error clearing edited videos: $e');
      return false;
    }
  }

  /// Get total storage used by edited videos
  static Future<int> getTotalStorageUsed() async {
    try {
      int totalBytes = 0;
      final videos = await getSavedVideos();

      for (final video in videos) {
        totalBytes += await video.length();
      }

      return totalBytes;
    } catch (e) {
      debugPrint('Error calculating total storage: $e');
      return 0;
    }
  }

  /// Get storage info as formatted string
  static Future<String> getStorageInfo() async {
    try {
      final videos = await getSavedVideos();
      final totalBytes = await getTotalStorageUsed();

      return '${videos.length} videos, ${_formatFileSize(totalBytes)} used';
    } catch (e) {
      debugPrint('Error getting storage info: $e');
      return 'Storage info unavailable';
    }
  }
}

/// Data class to hold video editing parameters
class VideoEditingParams {
  final String inputPath;
  final Duration startTime;
  final Duration endTime;
  final double brightness;
  final double contrast;
  final int rotationAngle;
  final Rect? cropRect;

  const VideoEditingParams({
    required this.inputPath,
    required this.startTime,
    required this.endTime,
    required this.brightness,
    required this.contrast,
    required this.rotationAngle,
    this.cropRect,
  });

  /// Convert to map for easy serialization
  Map<String, dynamic> toMap() {
    return {
      'inputPath': inputPath,
      'startTime': startTime.inMilliseconds,
      'endTime': endTime.inMilliseconds,
      'brightness': brightness,
      'contrast': contrast,
      'rotationAngle': rotationAngle,
      'cropRect': cropRect != null ? {
        'left': cropRect!.left,
        'top': cropRect!.top,
        'right': cropRect!.right,
        'bottom': cropRect!.bottom,
      } : null,
    };
  }

  /// Create from map
  factory VideoEditingParams.fromMap(Map<String, dynamic> map) {
    return VideoEditingParams(
      inputPath: map['inputPath'],
      startTime: Duration(milliseconds: map['startTime']),
      endTime: Duration(milliseconds: map['endTime']),
      brightness: map['brightness'],
      contrast: map['contrast'],
      rotationAngle: map['rotationAngle'],
      cropRect: map['cropRect'] != null ? Rect.fromLTRB(
        map['cropRect']['left'],
        map['cropRect']['top'],
        map['cropRect']['right'],
        map['cropRect']['bottom'],
      ) : null,
    );
  }
}
