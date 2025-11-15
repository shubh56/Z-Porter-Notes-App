import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/note_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String usersCollection = 'users';

  /// Convert email to a storage/firestore-safe key (base64url)
  String _userKeyFromEmail(String email) {
    return base64Url.encode(utf8.encode(email.trim().toLowerCase()));
  }

  Future<List<NoteModel>> getNotesForUserEmail(String email) async {
    final key = _userKeyFromEmail(email);
    final col = _db.collection('$usersCollection/$key/notes');
    final snap = await col.orderBy('createdAt', descending: true).get();
    return snap.docs.map((d) => NoteModel.fromDoc(d)).toList();
  }

  Future<String> createNoteForUserEmail(
    String email,
    Map<String, dynamic> doc, {
    String? id,
  }) async {
    final key = _userKeyFromEmail(email);
    final col = _db.collection('$usersCollection/$key/notes');
    final docId = id ?? Uuid().v4();
    await col.doc(docId).set({
      ...doc,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return docId;
  }

  Future<void> updateNoteForUserEmail(
    String email,
    String noteId,
    Map<String, dynamic> doc,
  ) async {
    final key = _userKeyFromEmail(email);
    final docRef = _db.collection('$usersCollection/$key/notes').doc(noteId);
    await docRef.update({...doc, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<void> deleteNoteForUserEmail(String email, String noteId) async {
    final key = _userKeyFromEmail(email);
    await _db.collection('$usersCollection/$key/notes').doc(noteId).delete();
  }
}
