import 'package:permission_handler/permission_handler.dart';

enum PermissionResult { granted, denied, permanentlyDenied }

class PermissionService {
  Future<PermissionResult> checkAndRequestMicrophone() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) return PermissionResult.granted;
    final res = await Permission.microphone.request();
    if (res.isGranted) return PermissionResult.granted;
    if (res.isPermanentlyDenied) return PermissionResult.permanentlyDenied;
    return PermissionResult.denied;
  }

  Future<PermissionResult> checkAndRequestCamera() async {
    final status = await Permission.camera.status;
    if (status.isGranted) return PermissionResult.granted;
    final res = await Permission.camera.request();
    if (res.isGranted) return PermissionResult.granted;
    if (res.isPermanentlyDenied) return PermissionResult.permanentlyDenied;
    return PermissionResult.denied;
  }

  Future<PermissionResult> checkAndRequestPhotos() async {
    // On Android use storage/media permissions depending on SDK; permission_handler handles mapping.
    final status = await Permission.photos.status;
    if (status.isGranted) return PermissionResult.granted;
    final res = await Permission.photos.request();
    if (res.isGranted) return PermissionResult.granted;
    if (res.isPermanentlyDenied) return PermissionResult.permanentlyDenied;
    return PermissionResult.denied;
  }

  Future<void> openAppSettings() => openAppSettings();
}
