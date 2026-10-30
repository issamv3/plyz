import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
class PermissionService {
  static Future<void> ensureStorageAccess() async {
    if (!Platform.isAndroid) return;
    final toRequest = <Permission>[];
    if (!await Permission.videos.isGranted) {
      toRequest.add(Permission.videos);
    }
    if (!await Permission.storage.isGranted) {
      toRequest.add(Permission.storage);
    }
    if (toRequest.isNotEmpty) {
      await toRequest.request();
    }
    if (!await Permission.manageExternalStorage.isGranted) {
      await Permission.manageExternalStorage.request();
    }
  }
}
