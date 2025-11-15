import 'dart:io';
import 'dart:convert';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload a local file to storage under a path derived from the user's
  /// encoded email and noteId. Returns a map with storagePath and downloadUrl.
  Future<Map<String, dynamic>> uploadFile({
    required File file,
    required String userEmail,
    required String noteId,
  }) async {
    final userKey = _encodeEmail(userEmail);
    final fileName = file.path.split(Platform.pathSeparator).last;
    final storagePath = '$userKey/notes/$noteId/$fileName';
    final ref = _storage.ref().child(storagePath);
    final uploadTask = ref.putFile(file);
    final snap = await uploadTask.whenComplete(() {});
    final url = await snap.ref.getDownloadURL();
    return {
      'storagePath': storagePath,
      'downloadUrl': url,
      'fileName': fileName,
    };
  }

  String _encodeEmail(String email) {
    final lower = email.trim().toLowerCase();
    return base64Url.encode(utf8.encode(lower));
  }
}
