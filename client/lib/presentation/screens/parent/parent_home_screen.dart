import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_keys.dart';
import '../../../app/routes/app_router.dart';
import '../../../core/import/score_import_picker.dart';
import '../../../domain/entities/library_entry.dart';
import '../../../domain/entities/piece.dart';
import '../../../domain/entities/profile.dart';
import '../../../domain/entities/review_candidate_package.dart';
import '../../../domain/entities/server_pairing.dart';
import '../../providers/app_providers.dart';
import '../../providers/piece_providers.dart';
import '../../providers/profile_providers.dart';
import '../../providers/review_providers.dart';

class ParentHomeScreen extends ConsumerWidget {
  const ParentHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(activeProfileProvider);
    final reviewQueue = ref.watch(parentReviewQueueProvider);
    final intakeEntries = ref.watch(parentIntakeEntriesProvider);
    final syncedPieces = ref.watch(parentSyncedPiecesProvider);
    final students = ref.watch(studentProfilesProvider);
    final serverHealth = ref.watch(serverHealthProvider);
    final theme = Theme.of(context);

    final reviewItems = reviewQueue.valueOrNull ?? const <ReviewQueueEntry>[];
    final reviewByPieceId = {
      for (final item in reviewItems) item.pieceId: item,
    };

    Future<void> refreshParentData() async {
      await ref.read(allPiecesProvider.notifier).loadPieces(
            trigger: SyncTrigger.manualRefresh,
          );
      ref.invalidate(serverHealthProvider);
      ref.invalidate(parentSyncedPiecesProvider);
      await ref.read(parentReviewQueueProvider.notifier).refresh();
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        key: AppKeys.parentHomeScreen,
        appBar: AppBar(
          title: Text('${profile.displayName} tools'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.all_inbox_outlined), text: 'Intake'),
              Tab(icon: Icon(Icons.people_alt_outlined), text: 'Students'),
              Tab(icon: Icon(Icons.tune_outlined), text: 'Server'),
            ],
          ),
          actions: [
            IconButton(
              key: AppKeys.logoutButton,
              tooltip: 'Switch profile',
              onPressed: () {
                Navigator.of(context).pushReplacementNamed(AppRouter.login);
              },
              icon: const Icon(Icons.switch_account_outlined),
            ),
          ],
        ),
        body: TabBarView(
          children: [
            RefreshIndicator(
              onRefresh: refreshParentData,
              child: _IntakeAndPushTab(
                theme: theme,
                intakeEntries: intakeEntries,
                reviewQueue: reviewQueue,
                reviewByPieceId: reviewByPieceId,
                students: students,
                onImport: () => _importScore(context, ref),
                onOpenReview: (itemId) {
                  Navigator.of(context).pushNamed(
                    AppRouter.reviewCompare,
                    arguments: itemId,
                  );
                },
                onPushToProfile: (entry, profileId) {
                  return ref.read(allPiecesProvider.notifier).pushToProfile(
                        pieceId: entry.piece.id,
                        profileId: profileId,
                      );
                },
              ),
            ),
            RefreshIndicator(
              onRefresh: refreshParentData,
              child: _StudentsTab(
                syncedPieces: syncedPieces,
                students: students,
                onCreatePairing: (student) {
                  _showStudentPairingDialog(context, ref, student);
                },
                onEditMetadata: (piece) => _showMetadataEditor(
                  context,
                  ref,
                  _MetadataEditSeed.fromRemote(piece),
                ),
              ),
            ),
            RefreshIndicator(
              onRefresh: refreshParentData,
              child: _ServerToolsTab(
                serverHealth: serverHealth,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _importScore(BuildContext context, WidgetRef ref) async {
    try {
      final selectedPath =
          await ref.read(scoreImportPickerProvider).pickScorePath();
      if (selectedPath == null) {
        return;
      }
      final entry = await ref.read(allPiecesProvider.notifier).importToIntake(
            selectedPath,
          );
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Imported ${entry.piece.title} into parent intake.')),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $error')),
      );
    }
  }

  void _showStudentPairingDialog(
    BuildContext context,
    WidgetRef ref,
    Profile student,
  ) {
    final pairingFuture =
        ref.read(serverPieceSyncRepositoryProvider).fetchPairingCode(
              purpose: 'student_device',
              profileId: student.id,
              profileName: student.displayName,
              role: 'student',
            );

    showDialog<void>(
      context: context,
      builder: (context) {
        return _StudentPairingDialog(
          student: student,
          pairingFuture: pairingFuture,
        );
      },
    );
  }

  Future<void> _showMetadataEditor(
    BuildContext context,
    WidgetRef ref,
    _MetadataEditSeed seed,
  ) async {
    final draft = await showDialog<_MetadataEditDraft>(
      context: context,
      builder: (context) => _MetadataEditDialog(seed: seed),
    );
    if (draft == null || !context.mounted) {
      return;
    }

    try {
      await ref.read(allPiecesProvider.notifier).updateRemoteMetadata(
            serverPieceId: seed.serverPieceId,
            title: draft.title,
            composer: draft.composer,
            primaryInstrument: draft.primaryInstrument,
            bookOrCollection: draft.bookOrCollection,
            keySignature: draft.keySignature,
            tempo: draft.tempo,
            notes: draft.notes,
            aliases: draft.aliases,
            sourcePageStart: draft.sourcePageStart,
            sourcePageEnd: draft.sourcePageEnd,
          );
      ref.invalidate(parentReviewQueueProvider);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Updated metadata for ${draft.title}.')),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save metadata: $error')),
      );
    }
  }
}

class _IntakeAndPushTab extends StatelessWidget {
  const _IntakeAndPushTab({
    required this.theme,
    required this.intakeEntries,
    required this.reviewQueue,
    required this.reviewByPieceId,
    required this.students,
    required this.onImport,
    required this.onOpenReview,
    required this.onPushToProfile,
  });

  final ThemeData theme;
  final List<LibraryEntry> intakeEntries;
  final AsyncValue<List<ReviewQueueEntry>> reviewQueue;
  final Map<String, ReviewQueueEntry> reviewByPieceId;
  final List<Profile> students;
  final VoidCallback onImport;
  final ValueChanged<String> onOpenReview;
  final Future<void> Function(LibraryEntry entry, String profileId)
      onPushToProfile;

  @override
  Widget build(BuildContext context) {
    final matchedReviewItemIds = {
      for (final entry in intakeEntries)
        if (reviewByPieceId[entry.piece.serverPieceId] != null)
          reviewByPieceId[entry.piece.serverPieceId]!.id,
    };

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ParentActionCards(theme: theme),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: AppKeys.parentImportButton,
          onPressed: onImport,
          icon: const Icon(Icons.upload_file_outlined),
          label: const Text('Import music for processing'),
        ),
        const SizedBox(height: 20),
        Text(
          'Process, review, push',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        if (intakeEntries.isEmpty)
          const _ParentEmptyState(
            title: 'No intake items yet',
            body:
                'Import PDFs or scans here. They stay in intake until processing, parent review, and push are complete.',
          )
        else
          Column(
            key: AppKeys.parentIntakeList,
            children: intakeEntries
                .map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _IntakeEntryCard(
                      entry: entry,
                      students: students,
                      reviewItem: reviewByPieceId[entry.piece.serverPieceId],
                      onOpenReview: onOpenReview,
                      onPushToProfile: (profileId) {
                        return onPushToProfile(entry, profileId);
                      },
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        reviewQueue.when(
          data: (items) {
            final unmatchedItems = items
                .where((item) => !matchedReviewItemIds.contains(item.id))
                .toList(growable: false);
            if (unmatchedItems.isEmpty) {
              return const SizedBox.shrink();
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  'Server review items',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                ...unmatchedItems.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ReviewItemCard(
                      item: item,
                      onOpenReview: () => onOpenReview(item.id),
                    ),
                  ),
                ),
              ],
            );
          },
          error: (error, _) => Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _QueueErrorCard(error: error),
          ),
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      ],
    );
  }
}

class _StudentsTab extends StatelessWidget {
  const _StudentsTab({
    required this.syncedPieces,
    required this.students,
    required this.onCreatePairing,
    required this.onEditMetadata,
  });

  final AsyncValue<List<RemotePieceSummary>> syncedPieces;
  final List<Profile> students;
  final ValueChanged<Profile> onCreatePairing;
  final ValueChanged<RemotePieceSummary> onEditMetadata;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StudentDevicePairingCard(
          students: students,
          onCreatePairing: onCreatePairing,
        ),
        const SizedBox(height: 20),
        Text(
          'Student libraries',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        syncedPieces.when(
          data: (pieces) {
            if (pieces.isEmpty) {
              return const _ParentEmptyState(
                title: 'No synced pieces yet',
                body:
                    'Once imports reach the server, parent-managed metadata and student assignments will appear here.',
              );
            }
            return Column(
              children: pieces
                  .map(
                    (piece) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _SyncedPieceCard(
                        piece: piece,
                        students: students,
                        onEditMetadata: () => onEditMetadata(piece),
                      ),
                    ),
                  )
                  .toList(growable: false),
            );
          },
          error: (error, _) => _QueueErrorCard(error: error),
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      ],
    );
  }
}

class _ServerToolsTab extends StatelessWidget {
  const _ServerToolsTab({required this.serverHealth});

  final AsyncValue<ServerHealthState> serverHealth;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ServerStatusCard(serverHealth: serverHealth),
        const SizedBox(height: 12),
        const _ProcessingSettingsCard(),
      ],
    );
  }
}

class _ParentActionCards extends StatelessWidget {
  const _ParentActionCards({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: AppKeys.parentReviewCard,
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Parent intake drives the library',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Import raw music here, let the server process it, review the candidate, then push the approved piece to one or more student profiles.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _IntakeEntryCard extends StatelessWidget {
  const _IntakeEntryCard({
    required this.entry,
    required this.students,
    required this.reviewItem,
    required this.onOpenReview,
    required this.onPushToProfile,
  });

  final LibraryEntry entry;
  final List<Profile> students;
  final ReviewQueueEntry? reviewItem;
  final ValueChanged<String> onOpenReview;
  final Future<void> Function(String profileId) onPushToProfile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final piece = entry.piece;
    final subtitle = <String>[
      if (piece.composer?.isNotEmpty ?? false) piece.composer!,
      if (piece.primaryInstrument?.isNotEmpty ?? false)
        piece.primaryInstrument!,
      if (piece.bookOrCollection?.isNotEmpty ?? false) piece.bookOrCollection!,
    ].join(' - ');
    final canPush = piece.libraryStatus == LibraryStatus.ready;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      piece.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              _ParentStatusBadge(status: piece.libraryStatus),
            ],
          ),
          const SizedBox(height: 12),
          if (!canPush) ...[
            Text(
              _statusMessage(piece.libraryStatus, reviewItem != null),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (piece.libraryStatus == LibraryStatus.review &&
                reviewItem != null) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => onOpenReview(reviewItem!.id),
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Review processed candidate'),
              ),
            ],
          ] else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: students.map((student) {
                final alreadyVisible =
                    piece.visibleToProfileIds.contains(student.id);
                return FilledButton.tonalIcon(
                  key: AppKeys.pushToProfileButton(piece.id, student.id),
                  onPressed:
                      alreadyVisible ? null : () => onPushToProfile(student.id),
                  icon: Icon(
                    alreadyVisible
                        ? Icons.check_circle_outline
                        : Icons.send_outlined,
                  ),
                  label: Text(
                    alreadyVisible
                        ? '${student.displayName} added'
                        : 'Push to ${student.displayName}',
                  ),
                );
              }).toList(growable: false),
            ),
        ],
      ),
    );
  }

  String _statusMessage(LibraryStatus status, bool hasReviewItem) {
    return switch (status) {
      LibraryStatus.intake => 'Waiting for processing or server upload.',
      LibraryStatus.uploadPending => 'Waiting to upload to the server.',
      LibraryStatus.processing => 'Backend processing is still running.',
      LibraryStatus.review => hasReviewItem
          ? 'Processing is complete. Review metadata and score output before pushing.'
          : 'Processing is complete, but the review item is still syncing.',
      LibraryStatus.ready => 'Ready to push.',
      LibraryStatus.archived => 'Rejected or archived after parent review.',
    };
  }
}

class _ParentStatusBadge extends StatelessWidget {
  const _ParentStatusBadge({required this.status});

  final LibraryStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = switch (status) {
      LibraryStatus.ready => (
          background: const Color(0xFFE4F6EE),
          foreground: const Color(0xFF126B4A),
          label: 'Ready',
        ),
      LibraryStatus.review => (
          background: const Color(0xFFFAEEDA),
          foreground: const Color(0xFF854F0B),
          label: 'Review',
        ),
      LibraryStatus.uploadPending => (
          background: const Color(0xFFFAEEDA),
          foreground: const Color(0xFF854F0B),
          label: 'Upload',
        ),
      LibraryStatus.processing => (
          background: const Color(0xFFE8DDD0),
          foreground: const Color(0xFF6B5E53),
          label: 'Processing',
        ),
      LibraryStatus.archived => (
          background: const Color(0xFFF5DDDD),
          foreground: const Color(0xFF8A1F1F),
          label: 'Archived',
        ),
      LibraryStatus.intake => (
          background: theme.colorScheme.surfaceContainerHighest,
          foreground: theme.colorScheme.onSurfaceVariant,
          label: 'Intake',
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        palette.label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: palette.foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ServerStatusCard extends StatelessWidget {
  const _ServerStatusCard({required this.serverHealth});

  final AsyncValue<ServerHealthState> serverHealth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return serverHealth.when(
      data: (state) {
        final icon = state.isOnline
            ? Icons.cloud_done_outlined
            : Icons.cloud_off_outlined;
        final foreground =
            state.isOnline ? const Color(0xFF126B4A) : const Color(0xFF854F0B);
        final background =
            state.isOnline ? const Color(0xFFE4F6EE) : const Color(0xFFFAEEDA);
        final label = state.isOnline ? 'Server online' : 'Server offline';

        return Container(
          key: AppKeys.parentServerStatus,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: foreground.withValues(alpha: 0.18)),
          ),
          child: Row(
            children: [
              Icon(icon, color: foreground, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      state.serverUrl,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: foreground.withValues(alpha: 0.82),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      error: (error, stackTrace) => const SizedBox.shrink(),
      loading: () {
        return Container(
          key: AppKeys.parentServerStatus,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
              Text(
                'Checking server',
                style: theme.textTheme.labelLarge,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StudentDevicePairingCard extends StatelessWidget {
  const _StudentDevicePairingCard({
    required this.students,
    required this.onCreatePairing,
  });

  final List<Profile> students;
  final ValueChanged<Profile> onCreatePairing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add student devices',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'After the parent/admin device is initialized from the server setup page, generate a separate QR code for each student device.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: students.map((student) {
              return FilledButton.tonalIcon(
                key: AppKeys.studentDevicePairingButton(student.id),
                onPressed: () => onCreatePairing(student),
                icon: const Icon(Icons.qr_code_2_outlined),
                label: Text('Pair ${student.displayName} device'),
              );
            }).toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _StudentPairingDialog extends StatelessWidget {
  const _StudentPairingDialog({
    required this.student,
    required this.pairingFuture,
  });

  final Profile student;
  final Future<ServerPairingCode> pairingFuture;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text('Pair ${student.displayName} device'),
      content: SizedBox(
        width: 460,
        child: FutureBuilder<ServerPairingCode>(
          future: pairingFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return Text('Unable to create pairing code: ${snapshot.error}');
            }
            final code = snapshot.data!;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 220,
                    height: 220,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border:
                          Border.all(color: theme.colorScheme.outlineVariant),
                    ),
                    child: Image.network(
                      code.qrPngUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(child: Text('QR unavailable'));
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SelectableText('Code: ${code.pairingCode}'),
                const SizedBox(height: 6),
                SelectableText(
                    'Student: ${code.profileName ?? student.displayName}'),
                const SizedBox(height: 6),
                SelectableText('Server: ${code.serverUrl}'),
                const SizedBox(height: 10),
                Text(
                  'This QR assigns the device to ${student.displayName}. It is separate from the first server setup QR used to initialize the parent/admin device.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _ProcessingSettingsCard extends StatelessWidget {
  const _ProcessingSettingsCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: AppKeys.parentProcessingSettingsButton,
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).pushNamed(AppRouter.parentProcessingSettings);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.tune_outlined,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Server processing settings',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Configure Audiveris, MuseScore, OCR, stub fallback, and experimental device processing.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _SyncedPieceCard extends StatelessWidget {
  const _SyncedPieceCard({
    required this.piece,
    required this.students,
    required this.onEditMetadata,
  });

  final RemotePieceSummary piece;
  final List<Profile> students;
  final VoidCallback onEditMetadata;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final assignedNames = students
        .where((student) => piece.visibleToProfileIds.contains(student.id))
        .map((student) => student.displayName)
        .toList(growable: false);
    final subtitle = <String>[
      if (piece.composer?.isNotEmpty ?? false) piece.composer!,
      if (piece.bookOrCollection?.isNotEmpty ?? false) piece.bookOrCollection!,
      if (assignedNames.isEmpty)
        'Not assigned to a student'
      else
        'Assigned to ${assignedNames.join(', ')}',
    ].join(' · ');

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFE4F6EE),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.library_music_outlined,
              color: Color(0xFF126B4A),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  piece.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text(piece.libraryStatus)),
                    if (piece.pieceKind == 'book')
                      const Chip(label: Text('Book source')),
                    OutlinedButton.icon(
                      onPressed: onEditMetadata,
                      icon: const Icon(Icons.edit_note_outlined),
                      label: const Text('Edit metadata'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewItemCard extends StatelessWidget {
  const _ReviewItemCard({
    required this.item,
    required this.onOpenReview,
  });

  final ReviewQueueEntry item;
  final VoidCallback onOpenReview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary =
        item.candidateData['summary'] as String? ?? item.description;
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        key: AppKeys.reviewQueueItem(item.id),
        borderRadius: BorderRadius.circular(20),
        onTap: onOpenReview,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFFAEEDA),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.fact_check_outlined,
                  color: Color(0xFF854F0B),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      summary,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.tonalIcon(
                      onPressed: onOpenReview,
                      icon: const Icon(Icons.fact_check_outlined),
                      label: const Text('Open review'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Chip(
                label: Text(item.status),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetadataEditSeed {
  const _MetadataEditSeed({
    required this.serverPieceId,
    required this.title,
    this.composer,
    this.primaryInstrument,
    this.bookOrCollection,
    this.keySignature,
    this.tempo,
    this.notes,
    this.aliases = const <String>[],
    this.sourcePageStart,
    this.sourcePageEnd,
  });

  final String serverPieceId;
  final String title;
  final String? composer;
  final String? primaryInstrument;
  final String? bookOrCollection;
  final String? keySignature;
  final String? tempo;
  final String? notes;
  final List<String> aliases;
  final int? sourcePageStart;
  final int? sourcePageEnd;

  factory _MetadataEditSeed.fromRemote(RemotePieceSummary piece) {
    return _MetadataEditSeed(
      serverPieceId: piece.id,
      title: piece.title,
      composer: piece.composer,
      primaryInstrument: piece.primaryInstrument,
      bookOrCollection: piece.bookOrCollection,
      keySignature: piece.keySignature,
      tempo: piece.tempo,
      notes: piece.notes ?? _metadataString(piece.catalogMetadata['notes']),
      aliases: _aliasesFrom(piece.catalogMetadata['aliases']),
      sourcePageStart: piece.sourcePageStart,
      sourcePageEnd: piece.sourcePageEnd,
    );
  }
}

class _MetadataEditDraft {
  const _MetadataEditDraft({
    required this.title,
    this.composer,
    this.primaryInstrument,
    this.bookOrCollection,
    this.keySignature,
    this.tempo,
    this.notes,
    this.aliases = const <String>[],
    this.sourcePageStart,
    this.sourcePageEnd,
  });

  final String title;
  final String? composer;
  final String? primaryInstrument;
  final String? bookOrCollection;
  final String? keySignature;
  final String? tempo;
  final String? notes;
  final List<String> aliases;
  final int? sourcePageStart;
  final int? sourcePageEnd;
}

class _MetadataEditDialog extends StatefulWidget {
  const _MetadataEditDialog({required this.seed});

  final _MetadataEditSeed seed;

  @override
  State<_MetadataEditDialog> createState() => _MetadataEditDialogState();
}

class _MetadataEditDialogState extends State<_MetadataEditDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _composerController;
  late final TextEditingController _instrumentController;
  late final TextEditingController _bookController;
  late final TextEditingController _keyController;
  late final TextEditingController _tempoController;
  late final TextEditingController _aliasesController;
  late final TextEditingController _notesController;
  late final TextEditingController _pageStartController;
  late final TextEditingController _pageEndController;
  String? _titleError;

  @override
  void initState() {
    super.initState();
    final seed = widget.seed;
    _titleController = TextEditingController(text: seed.title);
    _composerController = TextEditingController(text: seed.composer ?? '');
    _instrumentController =
        TextEditingController(text: seed.primaryInstrument ?? '');
    _bookController = TextEditingController(text: seed.bookOrCollection ?? '');
    _keyController = TextEditingController(text: seed.keySignature ?? '');
    _tempoController = TextEditingController(text: seed.tempo ?? '');
    _aliasesController = TextEditingController(text: seed.aliases.join(', '));
    _notesController = TextEditingController(text: seed.notes ?? '');
    _pageStartController =
        TextEditingController(text: seed.sourcePageStart?.toString() ?? '');
    _pageEndController =
        TextEditingController(text: seed.sourcePageEnd?.toString() ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _composerController.dispose();
    _instrumentController.dispose();
    _bookController.dispose();
    _keyController.dispose();
    _tempoController.dispose();
    _aliasesController.dispose();
    _notesController.dispose();
    _pageStartController.dispose();
    _pageEndController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit metadata'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Title',
                  errorText: _titleError,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _composerController,
                decoration: const InputDecoration(
                  labelText: 'Composer',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _instrumentController,
                decoration: const InputDecoration(
                  labelText: 'Primary instrument',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _bookController,
                decoration: const InputDecoration(
                  labelText: 'Book or collection',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _keyController,
                      decoration: const InputDecoration(
                        labelText: 'Key signature',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _tempoController,
                      decoration: const InputDecoration(
                        labelText: 'Tempo',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _aliasesController,
                decoration: const InputDecoration(
                  labelText: 'Alternate titles',
                  helperText: 'Separate aliases with commas.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _pageStartController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Source page start',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _pageEndController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Source page end',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Parent notes',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save metadata'),
        ),
      ],
    );
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() {
        _titleError = 'Title is required.';
      });
      return;
    }
    Navigator.of(context).pop(
      _MetadataEditDraft(
        title: title,
        composer: _optionalText(_composerController.text),
        primaryInstrument: _optionalText(_instrumentController.text),
        bookOrCollection: _optionalText(_bookController.text),
        keySignature: _optionalText(_keyController.text),
        tempo: _optionalText(_tempoController.text),
        notes: _optionalText(_notesController.text),
        aliases: _aliasesFrom(_aliasesController.text),
        sourcePageStart: _optionalInt(_pageStartController.text),
        sourcePageEnd: _optionalInt(_pageEndController.text),
      ),
    );
  }
}

class _ParentEmptyState extends StatelessWidget {
  const _ParentEmptyState({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 44,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _QueueErrorCard extends StatelessWidget {
  const _QueueErrorCard({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_outlined, size: 44),
          const SizedBox(height: 12),
          Text(
            'Unable to load the parent review queue.',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '$error',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

String? _metadataString(dynamic value) {
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

String? _optionalText(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

int? _optionalInt(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  return int.tryParse(trimmed);
}

List<String> _aliasesFrom(dynamic value) {
  if (value is Iterable) {
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  if (value is String) {
    return value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  return const <String>[];
}
