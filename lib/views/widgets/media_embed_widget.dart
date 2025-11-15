// lib/widgets/media_embed_widget.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as fq;
import 'package:video_player/video_player.dart';

/// Embed builder compatible with flutter_quill variant where:
/// - build(BuildContext, EmbedContext) -> Widget
/// - buildWidgetSpan(Widget child) -> WidgetSpan
/// - toPlainText(Embed) -> String
/// - expanded getter present
class MediaEmbedBuilder implements fq.EmbedBuilder {
  const MediaEmbedBuilder();

  @override
  String get key => 'media';

  /// false => inline behavior; true => block (full-width)
  @override
  bool get expanded => false;

  /// Build the widget that will be inserted into the editor for the embed.
  /// The embedContext contains the node (embed data) and controller if needed.
  @override
  Widget build(BuildContext context, fq.EmbedContext embedContext) {
    final node = embedContext.node;
    final dynamic data = node.value.data;
    final String value = data?.toString() ?? '';

    final low = value.toLowerCase();
    if (low.endsWith('.mp4') || low.contains('.mp4')) {
      return _LocalVideoPlayer(path: value);
    } else {
      final file = File(value);
      if (file.existsSync()) {
        return ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 300),
          child: Image.file(file, fit: BoxFit.cover),
        );
      } else if (value.startsWith('http')) {
        return ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 300),
          child: Image.network(value, fit: BoxFit.cover),
        );
      } else {
        return Container(
          height: 160,
          color: Colors.black12,
          child: const Center(child: Text('Media unavailable')),
        );
      }
    }
  }

  /// This matches the API your flutter_quill expects:
  /// it receives the already-built widget and must return a WidgetSpan wrapper.
  @override
  WidgetSpan buildWidgetSpan(Widget child) {
    return WidgetSpan(child: child);
  }

  /// Plain text fallback for this embed (used for copy/paste, indexing).
  @override
  String toPlainText(fq.Embed node) {
    final val = node.value.data?.toString() ?? '';
    final low = val.toLowerCase();
    if (low.endsWith('.mp4') || low.contains('.mp4')) return '[video]';
    if (val.isNotEmpty) return '[image]';
    return '[media]';
  }
}

/// Simple video player for local or network videos.
class _LocalVideoPlayer extends StatefulWidget {
  final String path;
  const _LocalVideoPlayer({required this.path});

  @override
  State<_LocalVideoPlayer> createState() => _LocalVideoPlayerState();
}

class _LocalVideoPlayerState extends State<_LocalVideoPlayer> {
  VideoPlayerController? _ctrl;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  Future<void> _initController() async {
    final p = widget.path;
    try {
      if (p.startsWith('http')) {
        _ctrl = VideoPlayerController.network(p);
      } else {
        _ctrl = VideoPlayerController.file(File(p));
      }
      await _ctrl!.initialize();
      setState(() {});
    } catch (e) {
      debugPrint('Video init error: $e');
      // keep silent and show fallback UI instead
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ctrl == null || !_ctrl!.value.isInitialized) {
      return Container(
        height: 160,
        color: Colors.black12,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    return GestureDetector(
      onTap: () {
        setState(() {
          if (_ctrl!.value.isPlaying) {
            _ctrl!.pause();
          } else {
            _ctrl!.play();
          }
        });
      },
      child: AspectRatio(
        aspectRatio: _ctrl!.value.aspectRatio,
        child: VideoPlayer(_ctrl!),
      ),
    );
  }
}
