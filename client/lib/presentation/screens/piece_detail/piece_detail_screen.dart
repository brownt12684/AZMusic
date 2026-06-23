import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_keys.dart';
import '../../../app/score_reader_launcher.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../domain/entities/library_entry.dart';
import '../../../domain/entities/score_version.dart';
import '../../providers/piece_providers.dart';
import '../../providers/profile_providers.dart';
import '../../providers/media_providers.dart';
import '../../../domain/entities/youtube_candidate.dart';

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

    return Scaffold(
      key: AppKeys.pieceDetailScreen,
      appBar: AppBar(
        title: Text(entry.piece.title),
      ),
      body: ListView(
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
          const SizedBox(height: 16),
          _YouTubeAccompanimentsSection(
            pieceId: entry.piece.id,
            isTeacher: showAllScoreVersions,
          ),
        ],
      ),
    );
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
            if (scoreVersions.isEmpty)
              Text(
                'No stored score versions for $pieceTitle.',
                style: theme.textTheme.bodyMedium,
              ),
          ],
        ),
      ),
    );
  }
}

class _YouTubeAccompanimentsSection extends ConsumerStatefulWidget {
  const _YouTubeAccompanimentsSection({
    required this.pieceId,
    required this.isTeacher,
  });

  final String pieceId;
  final bool isTeacher;

  @override
  ConsumerState<_YouTubeAccompanimentsSection> createState() =>
      _YouTubeAccompanimentsSectionState();
}

class _YouTubeAccompanimentsSectionState
    extends ConsumerState<_YouTubeAccompanimentsSection> {
  bool _isSearching = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final assetsAsync = ref.watch(mediaAssetsProvider(widget.pieceId));
    final candidatesAsync = widget.isTeacher
        ? ref.watch(mediaCandidatesProvider(widget.pieceId))
        : const AsyncValue<List<YouTubeCandidate>>.data([]);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Accompaniments & Reference Media',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            assetsAsync.when(
              data: (assets) {
                if (assets.isEmpty) {
                  return const Text('No approved reference tracks.');
                }
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: assets.length,
                  itemBuilder: (context, index) {
                    final asset = assets[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.audiotrack),
                      title: Text(asset.remoteUrl != null
                          ? 'YouTube Audio (${asset.format.toUpperCase()})'
                          : 'Reference Audio'),
                      subtitle: Text(asset.durationString),
                      trailing: widget.isTeacher
                          ? TextButton.icon(
                              icon: const Icon(Icons.close, color: Colors.red),
                              label: const Text('Revoke',
                                  style: TextStyle(color: Colors.red)),
                              onPressed: () async {
                                await ref
                                    .read(mediaOperationsProvider)
                                    .revokeAsset(widget.pieceId, asset.id);
                              },
                            )
                          : null,
                    );
                  },
                );
              },
              error: (error, _) => Text('Error loading accompaniments: $error'),
              loading: () => const CircularProgressIndicator(),
            ),
            if (widget.isTeacher) ...[
              const Divider(height: 32),
              Text(
                'YouTube Candidates',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              candidatesAsync.when(
                data: (candidates) {
                  final unapproved =
                      candidates.where((c) => !c.isApproved).toList();
                  if (unapproved.isEmpty) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('No pending YouTube candidates staged.'),
                        const SizedBox(height: 12),
                        _isSearching
                            ? const Row(
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(width: 12),
                                  Text('Searching YouTube Data API...'),
                                ],
                              )
                            : OutlinedButton.icon(
                                onPressed: () async {
                                  setState(() {
                                    _isSearching = true;
                                  });
                                  try {
                                    await ref
                                        .read(mediaOperationsProvider)
                                        .searchYouTubeForPiece(widget.pieceId);
                                  } finally {
                                    setState(() {
                                      _isSearching = false;
                                    });
                                  }
                                },
                                icon: const Icon(Icons.search),
                                label: const Text('Search YouTube'),
                              ),
                      ],
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: unapproved.length,
                    itemBuilder: (context, index) {
                      final candidate = unapproved[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(candidate.title),
                          subtitle: Text('Video: ${candidate.youtubeVideoId}'),
                          trailing: ElevatedButton.icon(
                            icon: const Icon(Icons.cloud_upload_outlined),
                            label: const Text('Approve & Push'),
                            onPressed: () async {
                              await ref
                                  .read(mediaOperationsProvider)
                                  .pushCandidate(widget.pieceId, candidate.id);
                            },
                          ),
                        ),
                      );
                    },
                  );
                },
                error: (error, _) => Text('Error searching candidates: $error'),
                loading: () => const CircularProgressIndicator(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
