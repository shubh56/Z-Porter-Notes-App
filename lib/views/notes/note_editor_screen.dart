import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_quill/flutter_quill.dart' as fq;
import 'package:zporter_notes_app/services/permission_service.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:zporter_notes_app/viewmodels/note_editor_viewmodel.dart';
import 'dart:math';
import 'dart:io';

class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({Key? key}) : super(key: key);

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late NoteEditorViewModel vm;
  TextEditingController? _titleController;
  final FocusNode _titleFocus = FocusNode();
  final FocusNode _editorFocus = FocusNode();
  final ScrollController _editorScrollController = ScrollController();
  bool _fabOpen = false;

  // Speech to text
  late stt.SpeechToText _speech;
  bool _listening = false;
  String _lastSpeechText = '';
  int _speechInsertionIndex = -1;

  @override
  void initState() {
    super.initState();
    // Initialize speech immediately
    _speech = stt.SpeechToText();
    // We cannot call Provider.of(...) with listen:true in initState, so use addPostFrameCallback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      vm = Provider.of<NoteEditorViewModel>(context, listen: false);
      _titleController = TextEditingController(text: vm.title);
      // Keep the controller in sync with VM title changes
      _titleController!.addListener(() {
        final text = _titleController!.text;
        vm.setTitle(text);
      });
      setState(() {}); // rebuild now controller is ready
    });
  }

  @override
  void dispose() {
    _titleController?.dispose();
    _titleFocus.dispose();
    _editorFocus.dispose();
    _editorScrollController.dispose();
    try {
      if (_listening) _speech.stop();
      _speech.cancel();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use Consumer so the UI rebuilds when VM notifies
    return Consumer<NoteEditorViewModel>(
      builder: (context, vmConsumer, _) {
        // ensure local vm reference (if not set in init)
        vm = vmConsumer;
        // if title controller wasn't created in init yet, return loading
        if (_titleController == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('New Note')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(vm.noteId == null ? 'New Note' : 'Edit Note'),
            actions: [
              IconButton(
                icon: vm.isBusy
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : const Icon(Icons.save),
                onPressed: vm.isBusy
                    ? null
                    : () async {
                        try {
                          await vm.saveNote();
                          Navigator.of(context).pop(true);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Save failed: $e')),
                          );
                        }
                      },
              ),
            ],
          ),
          body: Column(
            children: [
              // Title field: big font at top
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: TextField(
                  controller: _titleController!,
                  focusNode: _titleFocus,
                  decoration: const InputDecoration(
                    hintText: 'Title',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                ),
              ),
              // Editor with custom image embed rendering
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    // Tapping anywhere in the editor area focuses it
                    FocusScope.of(context).requestFocus(_editorFocus);
                  },
                  child: _QuillEditorWithImageSupport(
                    controller: vm.quillController,
                    focusNode: _editorFocus,
                  ),
                ),
              ),
            ],
          ),
          floatingActionButton: _buildFabColumn(vm),
        );
      },
    );
  }

  Widget _buildFabColumn(NoteEditorViewModel vm) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_fabOpen) ...[
          FloatingActionButton(
            heroTag: 'mic',
            mini: true,
            backgroundColor: _listening ? Colors.green : Colors.blue,
            child: Icon(_listening ? Icons.mic : Icons.mic_none),
            onPressed: () async {
              // Toggle listening
              if (_listening) {
                _stopListening();
              } else {
                // Prevent insertion into title: if title has focus, move cursor to end of document
                if (_titleFocus.hasFocus) {
                  _titleFocus.unfocus();
                  final docLen = vm.quillController.document.length;
                  vm.quillController.updateSelection(
                    TextSelection.collapsed(offset: docLen),
                    fq.ChangeSource.local,
                  );
                }
                await _startListening(vm);
              }
            },
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'camera',
            mini: true,
            child: const Icon(Icons.camera_alt),
            onPressed: () {
              // ensure not inserting into title
              if (_titleFocus.hasFocus) _titleFocus.unfocus();
              _showCaptureOptions(vm);
            },
          ),
          const SizedBox(height: 8),
        ],
        FloatingActionButton(
          heroTag: 'main',
          child: Icon(_fabOpen ? Icons.close : Icons.push_pin),
          onPressed: () {
            setState(() {
              _fabOpen = !_fabOpen;
            });
          },
        ),
      ],
    );
  }

  void _showCaptureOptions(NoteEditorViewModel vm) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Pick from gallery'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  // ensure insertion target is editor (not title)
                  try {
                    final docLen = vm.quillController.document.length;
                    vm.quillController.updateSelection(
                      TextSelection.collapsed(offset: docLen),
                      fq.ChangeSource.local,
                    );
                  } catch (_) {}

                  vm.insertImageFromGallery().catchError((e) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Pick failed: $e')));
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Open camera'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  try {
                    final docLen = vm.quillController.document.length;
                    vm.quillController.updateSelection(
                      TextSelection.collapsed(offset: docLen),
                      fq.ChangeSource.local,
                    );
                  } catch (_) {}

                  vm.insertImageFromCamera().catchError((e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Camera failed: $e')),
                    );
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _startListening(NoteEditorViewModel vm) async {
    if (!mounted) return;

    try {
      // Check microphone permission
      final perm = await vm.permissionService.checkAndRequestMicrophone();
      if (perm != PermissionResult.granted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied')),
        );
        return;
      }

      // Initialize speech if not already done
      if (!_speech.isAvailable) {
        final initialized = await _speech.initialize(
          onStatus: (status) {
            // Handle status changes if needed
          },
          onError: (error) {
            // Guard against widget being unmounted; handle 'no match' gracefully
            debugPrint('Speech init error: $error');
            if (!mounted) return;
            final msg = error.errorMsg;
            // For 'error_no_match' we don't spam the user; show a subtle hint and stop
            if (msg.contains('no_match')) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('No speech recognized. Try again.'),
                ),
              );
              try {
                _stopListening();
              } catch (_) {}
              return;
            }

            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Speech error: $msg')));
            try {
              _stopListening();
            } catch (_) {}
          },
        );
        if (!initialized) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Speech recognition not available on this device'),
            ),
          );
          return;
        }
      }

      if (!mounted) return;

      _lastSpeechText = '';
      _speechInsertionIndex = vm.quillController.selection.baseOffset;

      await _speech.listen(
        onResult: (result) {
          // Guard all operations against unmounted widget
          if (!mounted) return;

          try {
            final recognized = result.recognizedWords;
            final doc = vm.quillController.document;

            // Use current cursor position for insertion (allows text to follow user's position)
            int insertPos = vm.quillController.selection.baseOffset;
            if (insertPos < 0) insertPos = 0;
            if (insertPos > doc.length) insertPos = doc.length;

            // Remove previous partial result only if there's one stored
            if (_lastSpeechText.isNotEmpty && _speechInsertionIndex >= 0) {
              try {
                final deleteStart = _speechInsertionIndex;
                final deleteLen = _lastSpeechText.length;
                if (deleteStart >= 0 && deleteStart + deleteLen <= doc.length) {
                  doc.delete(deleteStart, deleteLen);
                  // Adjust insertion position after deletion
                  if (insertPos > deleteStart) {
                    insertPos = max(deleteStart, insertPos - deleteLen);
                  }
                }
              } catch (e) {
                debugPrint('Delete speech text error: $e');
              }
            }

            // Insert new recognized text at current cursor position
            if (recognized.isNotEmpty) {
              try {
                doc.insert(insertPos, recognized);
                final newCursorPos = insertPos + recognized.length;
                vm.quillController.updateSelection(
                  TextSelection.collapsed(offset: newCursorPos),
                  fq.ChangeSource.local,
                );
                // Store this insertion position for next partial result deletion
                _speechInsertionIndex = insertPos;
              } catch (e) {
                debugPrint('Insert speech text error: $e');
              }
            }

            if (result.finalResult) {
              // Final result: lock position and clear buffer so next sentence can go elsewhere
              _speechInsertionIndex = -1;
              _lastSpeechText = '';
            } else {
              // Partial: store text to remove on next update
              _lastSpeechText = recognized;
            }
          } catch (e) {
            debugPrint('onResult callback error: $e');
          }
        },
        cancelOnError: false,
        partialResults: true,
      );

      if (!mounted) return;
      setState(() {
        _listening = true;
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('Start listening error: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to start listening: $e')));
      _stopListening();
    }
  }

  void _stopListening() {
    try {
      _speech.stop();
    } catch (_) {}
    _listening = false;
    _speechInsertionIndex = -1;
    _lastSpeechText = '';
    if (mounted) setState(() {});
  }
}

// Custom widget to render Quill editor with image support
class _QuillEditorWithImageSupport extends StatelessWidget {
  final fq.QuillController controller;
  final FocusNode? focusNode;

  const _QuillEditorWithImageSupport({
    Key? key,
    required this.controller,
    this.focusNode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: fq.QuillEditor.basic(
              controller: controller,
              focusNode: focusNode,
            ),
          ),
          // Display inline images from mediaMetadata text placeholders
          _ImagePreviewBuilder(controller: controller),
        ],
      ),
    );
  }
}

// Extracts and displays images from [Image: index] placeholders
class _ImagePreviewBuilder extends StatelessWidget {
  final fq.QuillController controller;

  const _ImagePreviewBuilder({Key? key, required this.controller})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Get the NoteEditorViewModel to access mediaMetadata
    final vm = Provider.of<NoteEditorViewModel?>(context);
    if (vm == null || vm.mediaMetadata.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Attached Images:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: vm.mediaMetadata.length,
              itemBuilder: (context, index) {
                final meta = vm.mediaMetadata[index];
                final path = meta['path'] as String?;
                if (path == null) return const SizedBox.shrink();

                final imageNumber = index + 1; // 1-based numbering

                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.file(
                          File(path),
                          fit: BoxFit.cover,
                          width: 100,
                          height: 100,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Center(child: Text('📷')),
                            );
                          },
                        ),
                      ),
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Image $imageNumber',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
