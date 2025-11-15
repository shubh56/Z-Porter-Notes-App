import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_quill/flutter_quill.dart' as fq;
import 'package:uuid/uuid.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../services/media_service.dart';
import '../services/permission_service.dart';
import '../services/storage_service.dart';
import '../services/encryption_service.dart';
import 'package:flutter/services.dart';

class NoteEditorViewModel extends ChangeNotifier {
  final FirestoreService firestoreService;
  final AuthService authService;
  final MediaService mediaService;
  final PermissionService permissionService;
  final StorageService? storageService;
  final EncryptionService? encryptionService;

  String? noteId;
  fq.QuillController quillController;
  String title = '';
  List<Map<String, dynamic>> mediaMetadata = [];
  bool isBusy = false;
  String? error;

  NoteEditorViewModel({
    required this.firestoreService,
    required this.authService,
    required this.mediaService,
    required this.permissionService,
    this.storageService,
    this.encryptionService,
    this.noteId,
    fq.Document? initialDocument,
    String? initialTitle,
    List<Map<String, dynamic>>? initialMedia,
  }) : quillController = fq.QuillController(
         document: initialDocument ?? fq.Document(),
         selection: const TextSelection.collapsed(offset: 0),
       ) {
    title = initialTitle ?? '';
    mediaMetadata = initialMedia ?? [];
  }

  void setTitle(String v) {
    title = v;
    notifyListeners();
  }

  Future<void> insertImageFromGallery() async {
    final perm = await permissionService.checkAndRequestCamera();
    if (perm != PermissionResult.granted) {
      throw Exception('Camera/Photos permission denied');
    }
    final meta = await mediaService.pickFromGalleryAndSave();
    if (meta == null) return;
    // Insert image text placeholder (actual image is tracked in mediaMetadata)
    mediaMetadata.add(meta);
    final imageIndex = mediaMetadata.length; // 1-based numbering
    final index = quillController.selection.baseOffset;
    final pos = index < 0 ? quillController.document.length : index;
    final placeholder = '[Image: $imageIndex]';
    quillController.document.insert(pos, placeholder + '\n');
    quillController.updateSelection(
      TextSelection.collapsed(offset: pos + placeholder.length + 1),
      fq.ChangeSource.local,
    );
    notifyListeners();
  }

  Future<void> insertImageFromCamera() async {
    // Request camera permission first
    final perm = await permissionService.checkAndRequestCamera();
    if (perm != PermissionResult.granted) {
      throw Exception('Camera permission denied');
    }

    // Capture and copy the file into app directory (MediaService handles this)
    final meta = await mediaService.captureFromCameraAndSave(video: false);
    if (meta == null) return;

    // Keep metadata so we can persist it to Firestore (metadata only — file stays local)
    mediaMetadata.add(meta);

    // Insert an image text placeholder with index (actual image is tracked in mediaMetadata)
    final imageIndex = mediaMetadata.length; // 1-based numbering
    final index = quillController.selection.baseOffset;
    final pos = index < 0 ? quillController.document.length : index;
    final placeholder = '[Image: $imageIndex]';

    quillController.document.insert(pos, placeholder + '\n');

    // Move cursor to after the inserted text
    quillController.updateSelection(
      TextSelection.collapsed(offset: pos + placeholder.length + 1),
      fq.ChangeSource.local,
    );

    // Notify listeners so the UI updates
    notifyListeners();
  }

  Future<void> startSpeechToText(
    Function(String) onPartial,
    Function() onDone,
    Function(String) onError,
  ) async {
    final perm = await permissionService.checkAndRequestMicrophone();
    if (perm != PermissionResult.granted) {
      onError('Microphone permission denied');
      return;
    }
    // The speech_to_text flow runs in the view (UI) because it produces partial updates best handled by widgets
    // Here we only expose permission gating and any finalization saving.
  }

  Future<void> saveNote() async {
    final user = authService.currentUser;
    if (user == null) throw Exception('Not authenticated');
    isBusy = true;
    notifyListeners();
    try {
      final delta = quillController.document.toDelta().toJson();
      final excerpt = _generateExcerptFromDelta(delta);

      // Encrypt content JSON if encryptionService is provided, otherwise store raw JSON
      final contentJson = jsonEncode(delta);
      final encryptedContent = encryptionService != null
          ? await encryptionService!.encryptString(contentJson)
          : contentJson;

      // Keep media metadata as-is with local file paths (no Firebase upload)
      final finalMedia = <Map<String, dynamic>>[];
      for (final m in mediaMetadata) {
        finalMedia.add({
          'fileName': m['fileName'] ?? 'unknown',
          'path': m['path'] ?? '',
          'mime': m['mime'] ?? 'application/octet-stream',
        });
      }

      final doc = {
        'title': title,
        'content': encryptedContent,
        'excerpt': excerpt,
        'mediaMetadata': finalMedia,
        'authorEmail': user.email ?? '',
      };

      if (noteId == null) {
        final nid = Uuid().v4();
        noteId = await firestoreService.createNoteForUserEmail(
          user.email!,
          doc,
          id: nid,
        );
      } else {
        await firestoreService.updateNoteForUserEmail(
          user.email!,
          noteId!,
          doc,
        );
      }
      error = null;
    } catch (e) {
      error = e.toString();
      rethrow;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  String _generateExcerptFromDelta(dynamic delta) {
    try {
      // Extract plain text from delta (which is a list of operations)
      if (delta is! List) return '';

      final buffer = StringBuffer();
      for (final op in delta) {
        if (op is Map && op['insert'] != null) {
          final insert = op['insert'];
          if (insert is String) {
            buffer.write(insert);
          }
        }
      }

      final text = buffer.toString().trim();
      if (text.isEmpty) return '';

      // Return first 200 chars as excerpt
      if (text.length <= 200) return text;
      return text.substring(0, 200);
    } catch (e) {
      return '';
    }
  }
}
