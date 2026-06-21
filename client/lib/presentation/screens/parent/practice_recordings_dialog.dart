import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

import '../../../core/config/app_config.dart';
import '../../../domain/entities/practice_recording.dart';
import '../../../domain/entities/profile.dart';
import '../../providers/review_providers.dart';

void showPracticeRecordingsDialog(
  BuildContext context,
  WidgetRef ref,
  Profile student,
) {
  showDialog<void>(
    context: context,
    builder: (context) => _PracticeRecordingsDialog(student: student),
  );
}

class _PracticeRecordingsDialog extends ConsumerStatefulWidget {
  const _PracticeRecordingsDialog({required this.student});

  final Profile student;

  @override
  ConsumerState<_PracticeRecordingsDialog> createState() =>
      _PracticeRecordingsDialogState();
}

class _PracticeRecordingsDialogState
    extends ConsumerState<_PracticeRecordingsDialog> {
  List<RemotePracticeRecording>? _recordings;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRecordings();
  }

  Future<void> _loadRecordings() async {
    try {
      final repo = ref.read(serverPieceSyncRepositoryProvider);
      final recordings = await repo.fetchStudentRecordings(widget.student.id);
      if (mounted) {
        setState(() {
          _recordings = recordings;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load recordings: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 800),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${widget.student.displayName}\'s Practice Recordings',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _buildBody(theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline,
                  color: theme.colorScheme.error, size: 48),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.error),
              ),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: _loadRecordings,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final recordings = _recordings;
    if (recordings == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (recordings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam_off_outlined,
                  size: 48, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text(
                'No practice recordings found.',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: recordings.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final recording = recordings[index];
        final dateStr = DateFormat.yMMMd().add_jm().format(recording.submittedAt.toLocal());
        
        return ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          leading: const Icon(Icons.video_library_outlined, size: 32),
          title: Text(
            'Recording for piece ${recording.pieceId}', // We will update DTO to get pieceTitle
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(dateStr),
          trailing: const Icon(Icons.play_arrow_outlined),
          onTap: () {
            _playRecording(context, recording);
          },
        );
      },
    );
  }

  void _playRecording(BuildContext context, RemotePracticeRecording recording) {
    final repo = ref.read(serverPieceSyncRepositoryProvider);
    final url = repo.getPracticeRecordingVideoUrl(recording.id);
    
    showDialog<void>(
      context: context,
      builder: (context) => _VideoPlayerOverlay(
        videoUrl: url,
        token: AppConfig.serverPairingToken,
      ),
    );
  }
}

class _VideoPlayerOverlay extends StatefulWidget {
  const _VideoPlayerOverlay({
    required this.videoUrl,
    required this.token,
  });

  final String videoUrl;
  final String? token;

  @override
  State<_VideoPlayerOverlay> createState() => _VideoPlayerOverlayState();
}

class _VideoPlayerOverlayState extends State<_VideoPlayerOverlay> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
        httpHeaders: widget.token != null
            ? {'X-AZMusic-Device-Token': widget.token!}
            : {},
      );
      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _initialized = true;
        });
        _controller!.play();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          Center(
            child: _buildVideoContent(theme),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 32),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoContent(ThemeData theme) {
    if (_error != null) {
      return Text('Failed to load video: $_error', style: const TextStyle(color: Colors.red));
    }
    if (!_initialized || _controller == null) {
      return const CircularProgressIndicator();
    }
    return AspectRatio(
      aspectRatio: _controller!.value.aspectRatio,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          VideoPlayer(_controller!),
          VideoProgressIndicator(
            _controller!,
            allowScrubbing: true,
            colors: VideoProgressColors(
              playedColor: theme.colorScheme.primary,
            ),
          ),
          Center(
            child: IconButton(
              iconSize: 64,
              color: Colors.white.withValues(alpha: 0.8),
              icon: Icon(
                _controller!.value.isPlaying ? Icons.pause_circle : Icons.play_circle,
              ),
              onPressed: () {
                setState(() {
                  _controller!.value.isPlaying ? _controller!.pause() : _controller!.play();
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
