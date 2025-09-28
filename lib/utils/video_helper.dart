import 'dart:io';
import 'package:path_provider/path_provider.dart';

class VideoHelper {
  static const String videoEditsFolderName = 'VideoEdits';

  static Future<Directory> _getVideoEditsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final videoEditsDir = Directory('${appDir.path}/$videoEditsFolderName');

    if (!await videoEditsDir.exists()) {
      await videoEditsDir.create(recursive: true);
    }

    return videoEditsDir;
  }

  static Future<String> getOutputPath() async {
    final dir = await _getVideoEditsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${dir.path}/video_$timestamp.mp4';
  }

  static Future<List<File>> getSavedVideos() async {
    try {
      final dir = await _getVideoEditsDirectory();
      final files = await dir.list().toList();

      return files
          .whereType<File>()
          .where((file) => file.path.toLowerCase().endsWith('.mp4'))
          .toList()
        ..sort(
            (a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    } catch (e) {
      return [];
    }
  }

  static Future<bool> deleteVideo(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> saveEditedVideo({
    required String inputPath,
    required Duration startTime,
    required Duration endTime,
    required double brightness,
    required double contrast,
    required int rotationAngle,
  }) async {
    try {
      final inputFile = File(inputPath);
      if (!await inputFile.exists()) {
        return false;
      }

      final outputPath = await getOutputPath();
      final outputFile = File(outputPath);

      // For now, we'll copy the original file as a placeholder
      // In a real implementation, you would use FFmpeg or similar to apply edits
      await inputFile.copy(outputPath);

      // Create metadata file to store edit information
      final metadataPath = outputPath.replaceAll('.mp4', '_metadata.json');
      final metadataFile = File(metadataPath);
      await metadataFile.writeAsString('''
{
  "originalPath": "$inputPath",
  "startTime": "${startTime.inMilliseconds}",
  "endTime": "${endTime.inMilliseconds}",
  "brightness": "$brightness",
  "contrast": "$contrast",
  "rotationAngle": "$rotationAngle",
  "editedAt": "${DateTime.now().toIso8601String()}"
}
''');

      return await outputFile.exists();
    } catch (e) {
      print('Error saving video: $e');
      return false;
    }
  }

  static String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes);
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  static String getVideoSize(File file) {
    try {
      final bytes = file.lengthSync();
      if (bytes < 1024) return '${bytes}B';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    } catch (e) {
      return 'Unknown';
    }
  }
}
