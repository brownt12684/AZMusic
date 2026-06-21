// client/lib/presentation/screens/reader/modules/recording_module.dart
//
// The "Record" panel inside ReaderScreen.
// Shows a camera preview at the top for video recording, and a list of past recordings below.
//
// Usage inside reader_screen.dart:
//
//   case ReaderModule.record:
//     return RecordingModule(
//       pieceId:        widget.pieceId,
//       profileId:      activeProfile.id,
//       scoreVersionId: activeScoreVersionId,
//     );

import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

import '../../../../domain/entities/practice_recording.dart';
import '../../../providers/recording_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────

class RecordingModule extends ConsumerWidget {
  const RecordingModule({
    super.key,
    required this.pieceId,
    required this.profileId,
    this.scoreVersionId,
  });

  final String pieceId;
  final String profileId;
  final String? scoreVersionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        _RecorderControls(
          pieceId: pieceId,
          profileId: profileId,
          scoreVersionId: scoreVersionId,
        ),
        const Divider(height: 1),
        Expanded(
          child: _RecordingList(pieceId: pieceId, profileId: profileId),
        ),
      ],
    );
  }
}

// ─── recorder controls ────────────────────────────────────────────────────────

class _RecorderControls extends ConsumerWidget {
  const _RecorderControls({
    required this.pieceId,
    required this.profileId,
    this.scoreVersionId,
  });

  final String pieceId;
  final String profileId;
  final String? scoreVersionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = (pieceId: pieceId, profileId: profileId, scoreVersionId: scoreVersionId);
    final recorderState = ref.watch(recorderProvider(args));
    final notifier = ref.read(recorderProvider(args).notifier);

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Practice Video Recording', style: theme.textTheme.titleSmall),
          const SizedBox(height: 12),
          
          if (recorderState.status == RecorderStatus.initializing)
            const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (recorderState.cameraController != null && 
                   recorderState.cameraController!.value.isInitialized)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 1 / recorderState.cameraController!.value.aspectRatio,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CameraPreview(recorderState.cameraController!),
                    if (recorderState.isRecording)
                      Positioned(
                        top: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _PulsingDot(color: cs.error),
                              const SizedBox(width: 8),
                              Text(
                                recorderState.formattedElapsed,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Positioned(
                      bottom: 16,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: _RecordButton(
                          state: recorderState,
                          onStart: notifier.startRecording,
                          onStop: notifier.stopRecording,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  recorderState.errorMessage ?? 'Camera not available',
                  style: theme.textTheme.bodyMedium?.copyWith(color: cs.error),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RecordButton extends StatelessWidget {
  const _RecordButton({
    required this.state,
    required this.onStart,
    required this.onStop,
  });

  final RecorderState state;
  final VoidCallback onStart;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isRecording = state.isRecording;
    final isBusy = state.isBusy;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isRecording ? cs.errorContainer.withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.9),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      child: IconButton(
        iconSize: 40,
        icon: isBusy
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: isRecording ? cs.error : cs.primary,
                ),
              )
            : Icon(
                isRecording ? Icons.stop_rounded : Icons.videocam_rounded,
                color: isRecording ? cs.onErrorContainer : Colors.black87,
              ),
        tooltip: isRecording ? 'Stop recording' : 'Start recording',
        onPressed: isBusy ? null : (isRecording ? onStop : onStart),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});
  final Color color;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: _anim.value,
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color),
        ),
      ),
    );
  }
}

// ─── recordings list ──────────────────────────────────────────────────────────

class _RecordingList extends ConsumerWidget {
  const _RecordingList({required this.pieceId, required this.profileId});
  final String pieceId;
  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncList = ref.watch(recordingListProvider((pieceId: pieceId, profileId: profileId)));

    return asyncList.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load recordings: $e')),
      data: (recordings) {
        if (recordings.isEmpty) {
          return Center(
            child: Text(
              'No recordings yet.\nTap the video icon to capture your practice.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 16),
          itemCount: recordings.length,
          itemBuilder: (ctx, i) => _RecordingTile(recording: recordings[i]),
        );
      },
    );
  }
}

// ─── individual tile ──────────────────────────────────────────────────────────

class _RecordingTile extends ConsumerWidget {
  const _RecordingTile({required this.recording});
  final PracticeRecording recording;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listNotifier = ref.read(
      recordingListProvider((pieceId: recording.pieceId, profileId: recording.profileId)).notifier,
    );

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      leading: IconButton(
        iconSize: 28,
        icon: Icon(Icons.play_circle_fill_rounded, color: cs.primary),
        tooltip: 'Play video',
        onPressed: () => _playVideo(context, recording),
      ),
      title: Text(
        _formatDate(recording.createdAt),
        style: theme.textTheme.bodyMedium,
      ),
      subtitle: Text(
        recording.durationMs > 0 ? recording.formattedDuration : '--:--',
        style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      ),
      trailing: IconButton(
        iconSize: 20,
        icon: Icon(Icons.delete_outline_rounded, color: cs.onSurfaceVariant),
        tooltip: 'Delete recording',
        onPressed: () => _confirmDelete(context, listNotifier),
      ),
    );
  }

  void _playVideo(BuildContext context, PracticeRecording rec) {
    showDialog(
      context: context,
      builder: (ctx) => _VideoPlayerDialog(file: File(rec.filePath)),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    if (d == today) return 'Today  ${DateFormat.jm().format(dt)}';
    if (d == today.subtract(const Duration(days: 1))) return 'Yesterday  ${DateFormat.jm().format(dt)}';
    return DateFormat('MMM d  h:mm a').format(dt);
  }

  Future<void> _confirmDelete(
    BuildContext context,
    RecordingListNotifier listNotifier,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete recording?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await listNotifier.remove(recording.id);
    }
  }
}

class _VideoPlayerDialog extends StatefulWidget {
  const _VideoPlayerDialog({required this.file});
  final File file;

  @override
  State<_VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<_VideoPlayerDialog> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(widget.file)
      ..initialize().then((_) {
        setState(() {
          _initialized = true;
        });
        _controller.play();
      }).catchError((err) {
        setState(() {
          _error = err.toString();
        });
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: _error != null
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Error playing video: $_error', style: const TextStyle(color: Colors.red)),
              )
            : !_initialized
                ? const SizedBox(
                    height: 200,
                    width: 200,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        VideoPlayer(_controller),
                        _PlayPauseOverlay(controller: _controller),
                        VideoProgressIndicator(_controller, allowScrubbing: true),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _PlayPauseOverlay extends StatelessWidget {
  const _PlayPauseOverlay({required this.controller});
  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        controller.value.isPlaying ? controller.pause() : controller.play();
      },
      child: ValueListenableBuilder(
        valueListenable: controller,
        builder: (context, VideoPlayerValue value, child) {
          if (!value.isPlaying && value.isInitialized) {
            return const Center(
              child: Icon(Icons.play_arrow, color: Colors.white, size: 64.0),
            );
          }
          return const SizedBox.expand();
        },
      ),
    );
  }
}
