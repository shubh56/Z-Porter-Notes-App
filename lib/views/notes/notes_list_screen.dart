import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zporter_notes_app/services/auth_service.dart';
import 'package:zporter_notes_app/services/firestore_service.dart';
import 'package:zporter_notes_app/services/media_service.dart';
import 'package:zporter_notes_app/services/permission_service.dart';
import 'package:zporter_notes_app/viewmodels/app_viewmodel.dart';
import 'package:zporter_notes_app/viewmodels/note_editor_viewmodel.dart';
import 'package:zporter_notes_app/viewmodels/notes_list_viewmodel.dart';
import 'package:zporter_notes_app/views/notes/note_editor_screen.dart';
import 'package:zporter_notes_app/views/notes/note_view_screen.dart';
import 'package:zporter_notes_app/views/auth/login_screen.dart';
import 'package:zporter_notes_app/services/storage_service.dart';
import 'package:zporter_notes_app/services/encryption_service.dart';

class NotesListScreen extends StatefulWidget {
  @override
  State<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends State<NotesListScreen> {
  late NotesListViewModel vm;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      vm = Provider.of<NotesListViewModel>(context, listen: false);
      vm.loadNotes();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NotesListViewModel>(
      builder: (context, vm, _) {
        final grouped = vm.groupedByMonthYear();
        final screenSize = MediaQuery.of(context).size;
        final isTablet = screenSize.width > 600;

        return Scaffold(
          appBar: AppBar(
            title: const Text('All your notes'),
            actions: [
              Consumer<AppViewModel>(
                builder: (context, appVm, _) {
                  if (!appVm.isLoggedIn) {
                    return IconButton(
                      icon: const Icon(Icons.login),
                      onPressed: () => Navigator.of(
                        context,
                      ).push(MaterialPageRoute(builder: (_) => LoginScreen())),
                    );
                  }
                  return IconButton(
                    icon: const Icon(Icons.logout),
                    onPressed: () => appVm.signOut(),
                  );
                },
              ),
            ],
          ),
          body: vm.isBusy
              ? const Center(child: CircularProgressIndicator())
              : !Provider.of<AppViewModel>(context).isLoggedIn
              ? const Center(child: Text('login to start creating Notes'))
              : vm.notes.isEmpty
              ? const Center(child: Text('All your notes will appear here'))
              : isTablet
              ? _buildGridLayout(context, vm, grouped)
              : _buildListLayout(context, vm, grouped),
          floatingActionButton: FloatingActionButton(
            child: const Icon(Icons.add),
            onPressed: () => _createNewNote(context, vm),
          ),
        );
      },
    );
  }

  Widget _buildListLayout(
    BuildContext context,
    NotesListViewModel vm,
    Map<String, dynamic> grouped,
  ) {
    return ListView(
      children: grouped.entries.map((entry) {
        final header = entry.key;
        final items = entry.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                header,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...items.map((note) {
              return _buildNoteListTile(context, vm, note);
            }).toList(),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildGridLayout(
    BuildContext context,
    NotesListViewModel vm,
    Map<String, dynamic> grouped,
  ) {
    final screenSize = MediaQuery.of(context).size;
    final columns = screenSize.width > 1200 ? 3 : 2;

    return ListView(
      children: grouped.entries.map((entry) {
        final header = entry.key;
        final items = entry.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                header,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                childAspectRatio: 1.2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final note = items[index];
                return _buildNoteCard(context, vm, note);
              },
            ),
            const SizedBox(height: 16),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildNoteListTile(BuildContext context, NotesListViewModel vm, note) {
    return ListTile(
      title: Text(note.title.isEmpty ? '(no title)' : note.title),
      subtitle: Text(
        note.excerpt,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: PopupMenuButton(
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'delete',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.delete, color: Colors.red),
                SizedBox(width: 8),
                Text('Delete', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ],
        onSelected: (value) async {
          if (value == 'delete') {
            await _deleteNote(context, vm, note);
          }
        },
      ),
      onTap: () async {
        final res = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => NoteViewScreen(note: note)),
        );
        if (res == true) await vm.loadNotes();
      },
    );
  }

  Widget _buildNoteCard(BuildContext context, NotesListViewModel vm, note) {
    return Card(
      color: const Color(0xFF1A1A1F),
      child: InkWell(
        onTap: () async {
          final res = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => NoteViewScreen(note: note)),
          );
          if (res == true) await vm.loadNotes();
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                note.title.isEmpty ? '(no title)' : note.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  note.excerpt,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.bottomRight,
                child: PopupMenuButton(
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) async {
                    if (value == 'delete') {
                      await _deleteNote(context, vm, note);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteNote(
    BuildContext context,
    NotesListViewModel vm,
    note,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Note'),
        content: const Text(
          'Are you sure you want to delete this note? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final auth = Provider.of<AuthService>(context, listen: false);
        final repo = Provider.of<FirestoreService>(context, listen: false);
        final userEmail = auth.currentUser?.email;

        if (userEmail != null) {
          await repo.deleteNoteForUserEmail(userEmail, note.id);
          await vm.loadNotes();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
        }
      }
    }
  }

  void _createNewNote(BuildContext context, NotesListViewModel vm) async {
    final appVm = Provider.of<AppViewModel>(context, listen: false);
    if (!appVm.isLoggedIn) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => LoginScreen()));
      return;
    }

    final repo = Provider.of<FirestoreService>(context, listen: false);
    final auth = Provider.of<AuthService>(context, listen: false);
    final media = Provider.of<MediaService>(context, listen: false);
    final perm = Provider.of<PermissionService>(context, listen: false);

    final editorVm = NoteEditorViewModel(
      firestoreService: repo,
      authService: auth,
      mediaService: media,
      permissionService: perm,
      storageService: Provider.of<StorageService>(context, listen: false),
      encryptionService: Provider.of<EncryptionService>(context, listen: false),
    );

    final res = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider<NoteEditorViewModel>.value(
          value: editorVm,
          child: const NoteEditorScreen(),
        ),
      ),
    );
    if (res == true) await vm.loadNotes();
  }
}
