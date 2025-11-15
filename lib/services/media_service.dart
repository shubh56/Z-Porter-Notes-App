import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';

class MediaService {
  final ImagePicker _picker = ImagePicker();

  /// Save picked file to app private directory and return local path + metadata
  Future<Map<String, dynamic>?> pickFromGalleryAndSave({
    bool allowVideo = true,
  }) async {
    XFile? file;
    if (allowVideo) {
      // allow both image and video selection - try picking media via image picker
      // image_picker doesn't have a combined pick option, so prefer picking image first
      file = await _picker.pickImage(source: ImageSource.gallery);
      if (file == null) {
        // try video
        file = await _picker.pickVideo(source: ImageSource.gallery);
      }
    } else {
      file = await _picker.pickImage(source: ImageSource.gallery);
    }
    if (file == null) return null;
    return _copyToAppDir(file);
  }

  Future<Map<String, dynamic>?> captureFromCameraAndSave({
    required bool video,
  }) async {
    XFile? file;
    if (video) {
      file = await _picker.pickVideo(source: ImageSource.camera);
    } else {
      file = await _picker.pickImage(source: ImageSource.camera);
    }
    if (file == null) return null;
    return _copyToAppDir(file);
  }

  Future<Map<String, dynamic>> _copyToAppDir(XFile file) async {
    final appDir = await getApplicationDocumentsDirectory();
    final uid = Uuid().v4();
    final ext = file.path.split('.').last;
    final fileName = 'media_$uid.$ext';
    final dest = File('${appDir.path}/$fileName');
    await File(file.path).copy(dest.path);
    final stat = await dest.stat();
    return {
      'fileName': fileName,
      'path': dest.path,
      'size': stat.size,
      'mime': file.mimeType ?? (ext == 'mp4' ? 'video/mp4' : 'image/${ext}'),
    };
  }

  /// Delete local media file
  Future<void> deleteLocalFile(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (e) {
      debugPrint('deleteLocalFile error: $e');
    }
  }
}
