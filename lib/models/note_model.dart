import 'package:cloud_firestore/cloud_firestore.dart';

class NoteModel {
  final String id;
  final String title;
  final String content; // encrypted content or raw JSON string
  final String excerpt;
  final List<Map<String, dynamic>>
  mediaMetadata; // storage metadata (downloadUrl, storagePath)
  final DateTime createdAt;
  final DateTime updatedAt;
  final String authorEmail;

  NoteModel({
    required this.id,
    required this.title,
    required this.content,
    required this.excerpt,
    required this.mediaMetadata,
    required this.createdAt,
    required this.updatedAt,
    required this.authorEmail,
  });

  Map<String, dynamic> toMap() => {
    'title': title,
    'content': content,
    'excerpt': excerpt,
    'mediaMetadata': mediaMetadata,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
    'authorEmail': authorEmail,
  };

  static NoteModel fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NoteModel(
      id: doc.id,
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      excerpt: data['excerpt'] ?? '',
      mediaMetadata: List<Map<String, dynamic>>.from(
        data['mediaMetadata'] ?? [],
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      authorEmail: data['authorEmail'] ?? '',
    );
  }
}
