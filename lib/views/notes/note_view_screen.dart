import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_quill/flutter_quill.dart' as fq;
import 'package:video_player/video_player.dart';
import '../../models/note_model.dart';
import '../../services/encryption_service.dart';
import 'package:zporter_notes_app/services/firestore_service.dart';
import 'package:zporter_notes_app/services/auth_service.dart';
import 'package:zporter_notes_app/services/media_service.dart';
import 'package:zporter_notes_app/services/permission_service.dart';
import 'package:zporter_notes_app/services/storage_service.dart';
import 'package:zporter_notes_app/viewmodels/note_editor_viewmodel.dart';
import 'package:zporter_notes_app/views/notes/note_editor_screen.dart';

class NoteViewScreen extends StatefulWidget {
  final NoteModel note;
  const NoteViewScreen({Key? key, required this.note}) : super(key: key);

  @override
  State<NoteViewScreen> createState() => _NoteViewScreenState();
}

class _NoteViewScreenState extends State<NoteViewScreen> {
  fq.QuillController? _controller;
  bool _loading = true;
  late TextEditingController _titleController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note.title);
    _prepareDocument();
  }

  Future<void> _prepareDocument() async {
    final enc = Provider.of<EncryptionService?>(context, listen: false);
    String content = widget.note.content;
    if (enc != null && content.isNotEmpty) {
      try {
        final decrypted = await enc.decryptString(content);
        content = decrypted;
      } catch (e) {
        // ignore and use raw
      }
    }

    try {
      final decoded = jsonDecode(content);
      final doc = fq.Document.fromJson(decoded);
      _controller = fq.QuillController(
        document: doc,
        selection: const TextSelection.collapsed(offset: 0),
      );
    } catch (e) {
      // if parsing fails, put plain text into document
      final doc = fq.Document()..insert(0, content);
      _controller = fq.QuillController(
        document: doc,
        selection: const TextSelection.collapsed(offset: 0),
      );
    }

    setState(() {
      _loading = false;
    });
  }

  @override
  void dispose() {
    _controller = null;
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _titleController,
          decoration: InputDecoration(
            hintText: 'Title',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final repo = Provider.of<FirestoreService>(
                context,
                listen: false,
              );
              final auth = Provider.of<AuthService>(context, listen: false);
              final media = Provider.of<MediaService>(context, listen: false);
              final perm = Provider.of<PermissionService>(
                context,
                listen: false,
              );
              final storage = Provider.of<StorageService>(
                context,
                listen: false,
              );
              final enc = Provider.of<EncryptionService?>(
                context,
                listen: false,
              );

              final initialDoc = _controller?.document;

              final editorVm = NoteEditorViewModel(
                firestoreService: repo,
                authService: auth,
                mediaService: media,
                permissionService: perm,
                storageService: storage,
                encryptionService: enc,
                noteId: widget.note.id,
                initialDocument: initialDoc,
                initialTitle: widget.note.title,
                initialMedia: widget.note.mediaMetadata,
              );

              final res = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) =>
                      ChangeNotifierProvider<NoteEditorViewModel>.value(
                        value: editorVm,
                        child: NoteEditorScreen(),
                      ),
                ),
              );

              if (res == true) Navigator.of(context).pop(true);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
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
                      child: const Text(
                        'Delete',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                try {
                  final repo = Provider.of<FirestoreService>(
                    context,
                    listen: false,
                  );
                  final auth = Provider.of<AuthService>(context, listen: false);
                  final userEmail = auth.currentUser?.email;

                  if (userEmail != null) {
                    await repo.deleteNoteForUserEmail(
                      userEmail,
                      widget.note.id,
                    );
                    if (mounted) {
                      Navigator.of(context).pop(true);
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Delete failed: $e')),
                    );
                  }
                }
              }
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildResponsiveBody(context),
    );
  }

  Widget _buildResponsiveBody(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    final padding = isTablet ? 24.0 : 12.0;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(padding),
            child: fq.QuillEditor.basic(controller: _controller!),
          ),
          if (widget.note.mediaMetadata.isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: padding, vertical: 16),
              child: const Text(
                'Media',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: padding),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.note.mediaMetadata.length,
                itemBuilder: (context, index) {
                  final m = widget.note.mediaMetadata[index];
                  final path = m['path'] as String?;
                  final mime = (m['mime'] as String?) ?? '';
                  if (path == null || path.isEmpty)
                    return const SizedBox.shrink();

                  if (mime.startsWith('image')) {
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(path),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: const Color(0xFF1A1A1F),
                              padding: const EdgeInsets.all(16),
                              child: Center(
                                child: Text(
                                  'Image not found: ${m['fileName'] ?? 'unknown'}',
                                  style: const TextStyle(
                                    color: Color(0xFF7F7F82),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  } else if (mime.startsWith('video')) {
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: _VideoTileLocal(path: path),
                    );
                  } else {
                    return ListTile(
                      title: Text(m['fileName'] ?? 'file'),
                      subtitle: Text(path),
                    );
                  }
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _VideoTile extends StatefulWidget {
  final String url;
  const _VideoTile({Key? key, required this.url}) : super(key: key);

  @override
  State<_VideoTile> createState() => _VideoTileState();
}

class _VideoTileState extends State<_VideoTile> {
  VideoPlayerController? _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        setState(() {
          _initialized = true;
        });
      });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized)
      return SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    return AspectRatio(
      aspectRatio: _controller!.value.aspectRatio,
      child: Stack(
        children: [
          VideoPlayer(_controller!),
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  if (_controller!.value.isPlaying) {
                    _controller!.pause();
                  } else {
                    _controller!.play();
                  }
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Local video player for videos stored locally
class _VideoTileLocal extends StatefulWidget {
  final String path;
  const _VideoTileLocal({Key? key, required this.path}) : super(key: key);

  @override
  State<_VideoTileLocal> createState() => _VideoTileLocalState();
}

class _VideoTileLocalState extends State<_VideoTileLocal> {
  VideoPlayerController? _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.path))
      ..initialize()
          .then((_) {
            setState(() {
              _initialized = true;
            });
          })
          .catchError((e) {
            debugPrint('Video init error: $e');
            setState(() {
              _initialized = true; // set true to show error
            });
          });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_initialized)
      return SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );

    if (_controller!.value.hasError)
      return SizedBox(
        height: 200,
        child: Center(child: Text('Error loading video: ${widget.path}')),
      );

    return AspectRatio(
      aspectRatio: _controller!.value.aspectRatio,
      child: Stack(
        children: [
          VideoPlayer(_controller!),
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  if (_controller!.value.isPlaying) {
                    _controller!.pause();
                  } else {
                    _controller!.play();
                  }
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
