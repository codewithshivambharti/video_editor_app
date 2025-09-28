import 'package:permission_handler/permission_handler.dart';

class PermissionHelper {
  static Future<bool> requestStoragePermission() async {
    try {
      // For Android 13+ (API 33+), we need different permissions
      if (await Permission.photos.isDenied) {
        final status = await Permission.photos.request();
        if (status.isGranted) return true;
      }

      if (await Permission.videos.isDenied) {
        final status = await Permission.videos.request();
        if (status.isGranted) return true;
      }

      // Fallback for older Android versions
      if (await Permission.storage.isDenied) {
        final status = await Permission.storage.request();
        return status.isGranted;
      }

      return await Permission.storage.isGranted ||
          await Permission.photos.isGranted ||
          await Permission.videos.isGranted;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> requestCameraPermission() async {
    try {
      if (await Permission.camera.isDenied) {
        final status = await Permission.camera.request();
        return status.isGranted;
      }
      return await Permission.camera.isGranted;
    } catch (e) {
      return false;
    }
  }
}
