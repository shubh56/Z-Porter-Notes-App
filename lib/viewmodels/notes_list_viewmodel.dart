import 'package:flutter/foundation.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../models/note_model.dart';
import 'package:intl/intl.dart';

class NotesListViewModel extends ChangeNotifier {
  final FirestoreService firestoreService;
  final AuthService authService;

  List<NoteModel> _notes = [];
  List<NoteModel> get notes => _notes;

  bool isBusy = false;
  String? error;

  NotesListViewModel({
    required this.firestoreService,
    required this.authService,
  });

  Future<void> loadNotes() async {
    final user = authService.currentUser;
    if (user == null) return;
    isBusy = true;
    notifyListeners();
    try {
      final email = user.email;
      if (email == null) {
        _notes = [];
      } else {
        _notes = await firestoreService.getNotesForUserEmail(email);
      }
      error = null;
    } catch (e) {
      error = e.toString();
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  /// Group notes by month-year for UI
  Map<String, List<NoteModel>> groupedByMonthYear() {
    final fmt = DateFormat('MMMM yyyy');
    // Sort notes newest first by createdAt
    final sorted = List<NoteModel>.from(_notes)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final map = <String, List<NoteModel>>{};
    for (final n in sorted) {
      final key = fmt.format(n.createdAt);
      map.putIfAbsent(key, () => []).add(n);
    }

    // Ensure map preserves insertion order (newest month first)
    return Map<String, List<NoteModel>>.from(map);
  }

  Future<void> deleteNoteAndMedia(String noteId) async {
    final user = authService.currentUser;
    if (user == null) return;
    isBusy = true;
    notifyListeners();
    try {
      final email = user.email;
      if (email != null)
        await firestoreService.deleteNoteForUserEmail(email, noteId);
      _notes.removeWhere((n) => n.id == noteId);
      error = null;
    } catch (e) {
      error = e.toString();
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }
}
