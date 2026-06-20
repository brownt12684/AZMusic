import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_keys.dart';
import '../../../app/score_reader_launcher.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../domain/entities/library_entry.dart';
import '../../../domain/entities/score_version.dart';
import '../../providers/piece_providers.dart';
import '../../providers/profile_providers.dart';
import '../../providers/practice_providers.dart';

class PieceDetailScreen extends ConsumerWidget {
  const PieceDetailScreen({
    super.key,
    this.pieceId,
  });

  final String? pieceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (pieceId == null) {
      return const _PieceFallbackScaffold(
        title: 'Piece not selected',
        message:
            'Open a piece from the library to inspect its local score versions.',
      );
    }

    final libraryState = ref.watch(allPiecesProvider);
    final entry = ref.watch(pieceEntryProvider(pieceId!));
    final showAllScoreVersions =
        ref.watch(activeStudentProfileProvider) == null;

    if (entry == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Piece detail')),
        body: libraryState.when(
          data: (_) => const _CenteredMessage(
            icon: Icons.music_off_outlined,
            message: 'That piece is no longer in the local library.',
          ),
          error: (error, _) => _CenteredMessage(
            icon: Icons.error_outline,
            message: 'Unable to load piece detail.\n$error',
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final student = ref.watch(activeStudentProfileProvider);
    final recordingsState = ref.watch(practiceRecordingsProvider);
    final hasRecording = recordingsState.hasRecordingForPiece(entry.piece.id);

    return Scaffold(
      key: AppKeys.pieceDetailScreen,
      appBar: AppBar(
        title: Text(entry.piece.title),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: Colors.grey.shade100,
            child: FilledButton.icon(
              onPressed: () => _showRecordDialog(context, ref, entry.piece.id),
              icon: const Icon(Icons.mic),
              label: const Text('Record Practice'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1D9E75),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                _SummaryCard(
                  entry: entry,
                  visibleScoreVersionCount: _visibleScoreVersions(
                    entry.scoreVersions,
                    showAllScoreVersions: showAllScoreVersions,
                  ).length,
                ),
                const SizedBox(height: 16),
                _MediaAndRecordingsSection(
                  pieceId: entry.piece.id,
                  studentId: student?.id ?? '',
                  hasRecording: hasRecording,
                  lastRecordingAt: recordingsState.recordings
                      .where((r) => r.pieceId == entry.piece.id)
                      .isNotEmpty
                      ? recordingsState.recordings.firstWhere(
                          (r) => r.pieceId == entry.piece.id,
                        ).submittedAt
                      : null,
                ),
                const SizedBox(height: 16),
                _ScoreVersionsSection(
                  pieceTitle: entry.piece.title,
                  scoreVersions: _visibleScoreVersions(
                    entry.scoreVersions,
                    showAllScoreVersions: showAllScoreVersions,
                  ),
                  onOpenVersion: (scoreVersion) {
                    ref.read(scoreReaderLauncherProvider).open(
                          context,
                          ScoreReaderLaunchRequest(
                            pieceId: entry.piece.id,
                            scoreVersionId: scoreVersion.id,
                          ),
                        );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showRecordDialog(
    BuildContext context,
    WidgetRef ref,
    String pieceId,
  ) async {
    final notifier = ref.read(practiceRecordingsProvider.notifier);
    final success = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'm4a', 'wav', 'aac', 'ogg', 'flac'],
    ).then((result) async {
      if (result == null || result.files.single.path == null) return false;
      final filePath = result.files.single.path!;
      final studentId = ref.read(activeStudentProfileProvider)?.id ?? '';
      return notifier.uploadRecording(
        studentId: studentId,
        pieceId: pieceId,
        filePath: filePath,
      );
    });

    if (!context.mounted) return;
    if (success == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recording uploaded successfully.'),
          backgroundColor: Color(0xFF1D9E75),
        ),
      );
    } else if (success == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload failed. Please try again.')),
      );
    }
  }
}

class _PieceFallbackScaffold extends StatelessWidget {
  const _PieceFallbackScaffold({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _CenteredMessage(
        icon: Icons.library_music_outlined,
        message: message,
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.entry,
    required this.visibleScoreVersionCount,
  });

  final LibraryEntry entry;
  final int visibleScoreVersionCount;

  @override
  Widget build(BuildContext context) {
    final piece = entry.piece;
    final theme = Theme.of(context);
    final metadata = <String>[
      if (piece.composer?.isNotEmpty ?? false) piece.composer!,
      if (piece.primaryInstrument?.isNotEmpty ?? false)
        piece.primaryInstrument!,
      if (piece.bookOrCollection?.isNotEmpty ?? false) piece.bookOrCollection!,
      if (piece.keySignature?.isNotEmpty ?? false) piece.keySignature!,
      if (piece.tempo?.isNotEmpty ?? false) 'Tempo ${piece.tempo!}',
      if (piece.difficulty?.isNotEmpty ?? false) piece.difficulty!,
      if (piece.genre?.isNotEmpty ?? false) piece.genre!,
      piece.libraryStatus.name,
      '$visibleScoreVersionCount stored score${visibleScoreVersionCount == 1 ? '' : 's'}',
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              piece.title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (metadata.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    metadata.map((item) => Chip(label: Text(item))).toList(),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Imported ${DateFormatter.formatDate(piece.createdAt)}',
              style: theme.textTheme.bodyMedium,
            ),
            if (piece.notes?.isNotEmpty ?? false) ...[
              const SizedBox(height: 12),
              Text(piece.notes!),
            ],
            if (piece.processedMetadata.isNotEmpty) ...[
              const SizedBox(height: 16),
              _ProcessedMetadataSummary(metadata: piece.processedMetadata),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProcessedMetadataSummary extends StatelessWidget {
  const _ProcessedMetadataSummary({required this.metadata});

  final Map<String, dynamic> metadata;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final values = <String>[
      if (_metadataText(metadata['time_signature']) != null)
        'Time ${_metadataText(metadata['time_signature'])}',
      if (_metadataText(metadata['measure_count']) != null)
        '${_metadataText(metadata['measure_count'])} measures',
      if (_metadataText(metadata['part_count']) != null)
        '${_metadataText(metadata['part_count'])} parts',
      if (_metadataText(metadata['software']) != null)
        'Source ${_metadataText(metadata['software'])}',
    ];

    if (values.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Processed metadata',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: values.map((item) => Chip(label: Text(item))).toList(),
        ),
      ],
    );
  }
}

List<ScoreVersion> _visibleScoreVersions(
  List<ScoreVersion> scoreVersions, {
  required bool showAllScoreVersions,
}) {
  return scoreVersions.where((scoreVersion) {
    if (scoreVersion.format == 'musicxml') {
      return false;
    }
    return showAllScoreVersions || scoreVersion.isStudentVisible;
  }).toList(growable: false);
}

String? _metadataText(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is Iterable) {
    final joined = value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .join(', ');
    return joined.isEmpty ? null : joined;
  }
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

class _ScoreVersionsSection extends StatelessWidget {
  const _ScoreVersionsSection({
    required this.pieceTitle,
    required this.scoreVersions,
    required this.onOpenVersion,
  });

  final String pieceTitle;
  final List<ScoreVersion> scoreVersions;
  final ValueChanged<ScoreVersion> onOpenVersion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Stored scores',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ...scoreVersions.map(
              (scoreVersion) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(scoreVersion.title),
                subtitle: Text(
                  '${scoreVersion.format.toUpperCase()} / ${DateFormatter.formatDate(scoreVersion.createdAt)}',
                ),
                trailing: FilledButton.tonalIcon(
                  key: AppKeys.openScoreButton(scoreVersion.id),
                  onPressed: () => onOpenVersion(scoreVersion),
                  icon: const Icon(Icons.menu_book_outlined),
                  label: const Text('Open'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Play Media & Recordings Section ─────────────────────────────────

class _MediaAndRecordingsSection extends ConsumerStatefulWidget {
  const _MediaAndRecordingsSection({
    required this.pieceId,
    required this.studentId,
    required this.hasRecording,
    required this.lastRecordingAt,
  });

  final String pieceId;
  final String studentId;
  final bool hasRecording;
  final DateTime? lastRecordingAt;

  @override
  ConsumerState<_MediaAndRecordingsSection> createState() =>
      _MediaAndRecordingsSectionState();
}

class _MediaAndRecordingsSectionState
    extends ConsumerState<_MediaAndRecordingsSection> {
  bool _isUploading = false;
  String? _uploadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.studentId.isNotEmpty) {
        ref.read(practiceRecordingsProvider.notifier).fetchRecordings(widget.studentId);
      }
    });
  }

  Future<void> _pickAndUploadAudio() async {
    if (_isUploading) return;

    setState(() {
      _isUploading = true;
      _uploadError = null;
    });

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'm4a', 'wav', 'aac', 'ogg', 'flac'],
      );

      if (result == null || result.files.single.path == null) {
        setState(() => _isUploading = false);
        return;
      }

      final filePath = result.files.single.path!;
      final notifier = ref.read(practiceRecordingsProvider.notifier);
      final success = await notifier.uploadRecording(
        studentId: widget.studentId,
        pieceId: widget.pieceId,
        filePath: filePath,
      );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recording uploaded successfully.'),
            backgroundColor: Color(0xFF1D9E75),
          ),
        );
      } else {
        setState(() => _uploadError = 'Upload failed. Please try again.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadError = 'Unable to pick audio file.');
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.headphones_outlined, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Play media & recordings',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // YouTube / media content area (populated when server data is available)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Approved practice media and YouTube references will appear here.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'YouTube candidates are discovered automatically when a piece is processed.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Recording button
            if (_uploadError != null) ...[
              Text(_uploadError!, style: TextStyle(color: Colors.red.shade700)),
              const SizedBox(height: 8),
            ],
            FilledButton.icon(
              onPressed: _isUploading ? null : _pickAndUploadAudio,
              icon: _isUploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.mic),
              label: Text(_isUploading
                  ? 'Uploading...'
                  : (widget.hasRecording ? 'Re-record' : 'Record Practice')),
            ),
          ],
        ),
      ),
    );
  }
}
