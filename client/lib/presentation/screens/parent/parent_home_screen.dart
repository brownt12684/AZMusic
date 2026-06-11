import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_keys.dart';
import '../../../app/routes/app_router.dart';
import '../../../core/config/app_config.dart';
import '../../../core/import/score_import_picker.dart';
import '../../../core/network/server_connection_error.dart';
import '../../../domain/entities/library_entry.dart';
import '../../../domain/entities/piece.dart';
import '../../../domain/entities/processing_settings.dart';
import '../../../domain/entities/profile.dart';
import '../../../domain/entities/review_candidate_package.dart';
import '../../../domain/entities/server_pairing.dart';
import '../../../domain/entities/server_job.dart';
import '../../providers/app_providers.dart';
import '../../providers/debug_tools_providers.dart';
import '../../providers/parent_workflow_refresh.dart';
import '../../providers/piece_providers.dart';
import '../../providers/processing_settings_providers.dart';
import '../../providers/profile_providers.dart';
import '../../providers/review_providers.dart';

const _activeWorkflowPollInterval = Duration(seconds: 5);

final _parentCloudStatusProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  if (!AppConfig.isServerPaired) {
    throw const ServerNotPairedException();
  }
  return ref.read(serverPieceSyncRepositoryProvider).fetchCloudStatus();
});

class ParentHomeScreen extends ConsumerWidget {
  const ParentHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(activeProfileProvider);
    final reviewQueue = ref.watch(parentReviewQueueProvider);
    final allEntries =
        ref.watch(allPiecesProvider).valueOrNull ?? const <LibraryEntry>[];
    final intakeEntries = ref.watch(parentIntakeEntriesProvider);
    final syncedPieces = ref.watch(parentSyncedPiecesProvider);
    final debugTools = ref.watch(parentDebugToolsProvider);
    final processingCapabilities = ref.watch(processingCapabilitiesProvider);
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
      await ref
          .read(parentSyncedPiecesProvider.notifier)
          .refresh(showLoading: false);
      await ref
          .read(processingCapabilitiesProvider.notifier)
          .refresh(showLoading: false);
      await ref.read(parentReviewQueueProvider.notifier).refresh();
    }

    void openPairingScreen() {
      Navigator.of(context).pushReplacementNamed(AppRouter.login);
    }

    Future<void> closeWorkflow({
      required String serverPieceId,
      required String title,
      String? localPieceId,
    }) async {
      try {
        await ref.read(allPiecesProvider.notifier).closeWorkflow(
              serverPieceId: serverPieceId,
              localPieceId: localPieceId,
            );
        scheduleParentWorkflowRefreshBurst(
          ref,
          trigger: SyncTrigger.manualRefresh,
          isActive: () => context.mounted,
        );
        if (!context.mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Closed $title from the parent workflow.')),
        );
      } catch (error) {
        if (!context.mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to close workflow item: $error')),
        );
      }
    }

    return _ParentWorkflowAutoRefresh(
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          key: AppKeys.parentHomeScreen,
          appBar: AppBar(
            title: Text('${profile.displayName} tools'),
            bottom: const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.all_inbox_outlined), text: 'Workflow'),
                Tab(icon: Icon(Icons.people_alt_outlined), text: 'Students'),
                Tab(icon: Icon(Icons.tune_outlined), text: 'Advanced'),
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
                  allEntries: allEntries,
                  syncedPieces: syncedPieces,
                  processingCapabilities: processingCapabilities,
                  debugTools: debugTools,
                  reviewQueue: reviewQueue,
                  reviewByPieceId: reviewByPieceId,
                  students: students,
                  onImport: () => _importScore(context, ref),
                  onToggleDebugTools: (enabled) {
                    return ref
                        .read(parentDebugToolsProvider.notifier)
                        .setEnabled(enabled);
                  },
                  onRefreshDebugJobs: () {
                    return ref
                        .read(parentDebugToolsProvider.notifier)
                        .refreshJobs();
                  },
                  onCancelDebugJob: (jobId) {
                    return ref
                        .read(parentDebugToolsProvider.notifier)
                        .cancelJob(jobId);
                  },
                  onRetryDebugJob: (jobId) {
                    return ref
                        .read(parentDebugToolsProvider.notifier)
                        .retryJob(jobId);
                  },
                  onClearDebugLibraries: () {
                    return ref
                        .read(parentDebugToolsProvider.notifier)
                        .clearLocalAndServerLibraries();
                  },
                  onClearDebugPiece: (target) {
                    return ref
                        .read(parentDebugToolsProvider.notifier)
                        .clearPiece(
                          title: target.title,
                          localPieceId: target.localPieceId,
                          serverPieceId: target.serverPieceId,
                        );
                  },
                  onRetryLocalUpload: (entry, reuploadAsNew) async {
                    await ref.read(allPiecesProvider.notifier).retryLocalUpload(
                          entry.piece.id,
                          reuploadAsNew: reuploadAsNew,
                        );
                    scheduleParentWorkflowRefreshBurst(
                      ref,
                      trigger: SyncTrigger.postImport,
                      isActive: () => context.mounted,
                    );
                    if (!context.mounted) {
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Retried ${entry.piece.title}.')),
                    );
                  },
                  onRemoveLocalItem: (entry) async {
                    await ref
                        .read(allPiecesProvider.notifier)
                        .removeLocalEntry(entry.piece.id);
                    if (!context.mounted) {
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Removed ${entry.piece.title} locally.'),
                      ),
                    );
                  },
                  onRepairPairing: openPairingScreen,
                  onOpenReview: (itemId) {
                    Navigator.of(context).pushNamed(
                      AppRouter.reviewCompare,
                      arguments: itemId,
                    );
                  },
                  onPushToProfile: (entry, profileId) {
                    return ref
                        .read(allPiecesProvider.notifier)
                        .pushToProfile(
                          pieceId: entry.piece.id,
                          profileId: profileId,
                        )
                        .then((_) {
                      scheduleParentWorkflowRefreshBurst(
                        ref,
                        trigger: SyncTrigger.parentPush,
                        isActive: () => context.mounted,
                      );
                    });
                  },
                  onPushRemoteToProfile: (piece, profileId) async {
                    final remotePiece = await ref
                        .read(serverPieceSyncRepositoryProvider)
                        .pushPieceToProfiles(piece.id, [profileId]);
                    ref
                        .read(parentSyncedPiecesProvider.notifier)
                        .upsert(RemotePieceSummary.fromDetail(remotePiece));
                    scheduleParentWorkflowRefreshBurst(
                      ref,
                      trigger: SyncTrigger.parentPush,
                      isActive: () => context.mounted,
                    );
                  },
                  onCloseWorkflow: (entry) {
                    final serverPieceId = entry.piece.serverPieceId;
                    if (serverPieceId == null) {
                      return Future<void>.value();
                    }
                    return closeWorkflow(
                      serverPieceId: serverPieceId,
                      localPieceId: entry.piece.id,
                      title: entry.piece.title,
                    );
                  },
                  onCloseRemoteWorkflow: (piece) {
                    return closeWorkflow(
                      serverPieceId: piece.id,
                      title: piece.title,
                    );
                  },
                ),
              ),
              RefreshIndicator(
                onRefresh: refreshParentData,
                child: _StudentsTab(
                  syncedPieces: syncedPieces,
                  students: students,
                  onRepairPairing: openPairingScreen,
                  onAddStudent: () {
                    _showAddStudentDialog(context, ref);
                  },
                  onCreatePairing: (student) {
                    _showStudentPairingDialog(context, ref, student);
                  },
                  onEditMetadata: (piece) => _showMetadataEditor(
                    context,
                    ref,
                    _MetadataEditSeed.fromRemote(piece),
                  ),
                  onPushOriginal: (piece, profileId) async {
                    final remotePiece = await ref
                        .read(serverPieceSyncRepositoryProvider)
                        .pushPieceToProfiles(
                          piece.id,
                          [profileId],
                          mode: 'original_pdf',
                        );
                    ref
                        .read(parentSyncedPiecesProvider.notifier)
                        .upsert(RemotePieceSummary.fromDetail(remotePiece));
                    scheduleParentWorkflowRefreshBurst(
                      ref,
                      trigger: SyncTrigger.parentPush,
                      isActive: () => context.mounted,
                    );
                  },
                  onPullForEdits: (piece) async {
                    await ref
                        .read(allPiecesProvider.notifier)
                        .pullRemotePieceForEdits(serverPieceId: piece.id);
                    scheduleParentWorkflowRefreshBurst(
                      ref,
                      trigger: SyncTrigger.manualRefresh,
                      isActive: () => context.mounted,
                    );
                  },
                ),
              ),
              RefreshIndicator(
                onRefresh: refreshParentData,
                child: _ServerToolsTab(
                  serverHealth: serverHealth,
                  onRepairPairing: openPairingScreen,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAddStudentDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final draft = await showDialog<_StudentDraft>(
      context: context,
      builder: (context) => const _AddStudentDialog(),
    );
    if (draft == null || !context.mounted) {
      return;
    }

    try {
      final student =
          await ref.read(localStudentProfilesProvider.notifier).addStudent(
                displayName: draft.displayName,
                instrument: draft.instrument,
              );
      ref.invalidate(availableProfilesProvider);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added ${student.displayName}.')),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to add student: $error')),
      );
    }
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
      scheduleParentWorkflowRefreshBurst(
        ref,
        trigger: SyncTrigger.postImport,
        isActive: () => context.mounted,
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
    if (!AppConfig.isServerPaired) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Pair the parent device with the AZMusic server before adding student devices.',
          ),
        ),
      );
      return;
    }

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
      refreshParentWorkflowInBackground(
        ref,
        trigger: SyncTrigger.manualRefresh,
      );
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

class _ParentWorkflowAutoRefresh extends ConsumerStatefulWidget {
  const _ParentWorkflowAutoRefresh({
    required this.child,
  });

  final Widget child;

  @override
  ConsumerState<_ParentWorkflowAutoRefresh> createState() =>
      _ParentWorkflowAutoRefreshState();
}

class _ParentWorkflowAutoRefreshState
    extends ConsumerState<_ParentWorkflowAutoRefresh> {
  Timer? _timer;
  bool _refreshing = false;
  bool _polling = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summary =
        ref.watch(processingCapabilitiesProvider).valueOrNull?.jobSummary;
    final shouldPoll = summary != null &&
        (summary.queuedCount > 0 || summary.runningCount > 0);

    if (shouldPoll != _polling) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _setPolling(shouldPoll);
        }
      });
    }

    return widget.child;
  }

  void _setPolling(bool enabled) {
    if (_polling == enabled) {
      return;
    }
    _polling = enabled;
    _timer?.cancel();
    _timer = null;
    if (!enabled) {
      return;
    }
    _timer = Timer.periodic(
      _activeWorkflowPollInterval,
      (_) => _refreshWorkflow(),
    );
  }

  Future<void> _refreshWorkflow() async {
    if (_refreshing) {
      return;
    }
    _refreshing = true;
    try {
      await refreshParentWorkflow(
        ref,
        trigger: SyncTrigger.manualRefresh,
      );
    } finally {
      _refreshing = false;
    }
  }
}

class _IntakeAndPushTab extends StatelessWidget {
  const _IntakeAndPushTab({
    required this.theme,
    required this.intakeEntries,
    required this.allEntries,
    required this.syncedPieces,
    required this.processingCapabilities,
    required this.debugTools,
    required this.reviewQueue,
    required this.reviewByPieceId,
    required this.students,
    required this.onImport,
    required this.onToggleDebugTools,
    required this.onRefreshDebugJobs,
    required this.onCancelDebugJob,
    required this.onRetryDebugJob,
    required this.onClearDebugLibraries,
    required this.onClearDebugPiece,
    required this.onRetryLocalUpload,
    required this.onRemoveLocalItem,
    required this.onRepairPairing,
    required this.onOpenReview,
    required this.onPushToProfile,
    required this.onPushRemoteToProfile,
    required this.onCloseWorkflow,
    required this.onCloseRemoteWorkflow,
  });

  final ThemeData theme;
  final List<LibraryEntry> intakeEntries;
  final List<LibraryEntry> allEntries;
  final AsyncValue<List<RemotePieceSummary>> syncedPieces;
  final AsyncValue<ProcessingCapabilities> processingCapabilities;
  final ParentDebugToolsState debugTools;
  final AsyncValue<List<ReviewQueueEntry>> reviewQueue;
  final Map<String, ReviewQueueEntry> reviewByPieceId;
  final List<Profile> students;
  final VoidCallback onImport;
  final Future<void> Function(bool enabled) onToggleDebugTools;
  final Future<void> Function() onRefreshDebugJobs;
  final Future<void> Function(String jobId) onCancelDebugJob;
  final Future<void> Function(String jobId) onRetryDebugJob;
  final Future<void> Function() onClearDebugLibraries;
  final Future<void> Function(_DebugPieceTarget target) onClearDebugPiece;
  final Future<void> Function(LibraryEntry entry, bool reuploadAsNew)
      onRetryLocalUpload;
  final Future<void> Function(LibraryEntry entry) onRemoveLocalItem;
  final VoidCallback onRepairPairing;
  final ValueChanged<String> onOpenReview;
  final Future<void> Function(LibraryEntry entry, String profileId)
      onPushToProfile;
  final Future<void> Function(RemotePieceSummary piece, String profileId)
      onPushRemoteToProfile;
  final Future<void> Function(LibraryEntry entry) onCloseWorkflow;
  final Future<void> Function(RemotePieceSummary piece) onCloseRemoteWorkflow;

  @override
  Widget build(BuildContext context) {
    final remotePieces =
        syncedPieces.valueOrNull ?? const <RemotePieceSummary>[];
    final debugPieceTargets = _buildDebugPieceTargets(
      localEntries: allEntries,
      remotePieces: remotePieces,
    );
    final reviewItems = reviewQueue.valueOrNull ?? const <ReviewQueueEntry>[];
    final remotePieceIds = remotePieces.map((piece) => piece.id).toSet();
    final localServerPieceIds = {
      for (final entry in intakeEntries)
        if (entry.piece.serverPieceId != null) entry.piece.serverPieceId!,
    };
    final localUploadProblems = intakeEntries.where((entry) {
      if (entry.piece.workflowClosed ||
          entry.piece.libraryStatus == LibraryStatus.archived) {
        return false;
      }
      if (entry.piece.serverPieceId == null) {
        return entry.piece.libraryStatus == LibraryStatus.uploadPending ||
            entry.piece.libraryStatus == LibraryStatus.intake;
      }
      return syncedPieces.hasValue &&
          !remotePieceIds.contains(entry.piece.serverPieceId);
    }).toList(growable: false);
    final localReviewOrReady = intakeEntries.where((entry) {
      if (localUploadProblems.contains(entry)) {
        return false;
      }
      return entry.piece.serverPieceId != null;
    }).toList(growable: false);
    final bookWorkflows = _buildBookWorkflows(
      pieces: remotePieces,
      reviewItems: reviewItems,
    );
    final groupedReviewItemIds = {
      for (final workflow in bookWorkflows)
        for (final item in workflow.reviewItems) item.id,
    };
    final looseReviewItems = reviewItems
        .where((item) => !groupedReviewItemIds.contains(item.id))
        .toList(growable: false);
    final readyRemotePieces = remotePieces.where((piece) {
      if (piece.workflowClosed ||
          piece.libraryStatus != 'ready' ||
          localServerPieceIds.contains(piece.id)) {
        return false;
      }
      return true;
    }).toList(growable: false);
    final readyLocalEntries = localReviewOrReady
        .where((entry) => entry.piece.libraryStatus == LibraryStatus.ready)
        .toList(growable: false);
    final activeLocalEntries = localReviewOrReady
        .where((entry) => entry.piece.libraryStatus != LibraryStatus.ready)
        .toList(growable: false);

    return ListView(
      key: AppKeys.parentWorkflowList,
      padding: const EdgeInsets.all(16),
      children: [
        _ParentActionCards(theme: theme),
        const SizedBox(height: 12),
        _WorkflowSection(
          title: 'Import',
          subtitle:
              'Choose a PDF or scan. AZMusic preserves the original and prepares a student PDF for metadata review.',
          children: [
            FilledButton.icon(
              key: AppKeys.parentImportButton,
              onPressed: onImport,
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('Import music'),
            ),
            if (localUploadProblems.isEmpty)
              const _ParentEmptyState(
                title: 'No local upload problems',
                body:
                    'Imports that reach the server move into Processing automatically.',
              )
            else
              Column(
                key: AppKeys.parentIntakeList,
                children: localUploadProblems.map((entry) {
                  final serverMissing = entry.piece.serverPieceId != null;
                  return Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _LocalImportProblemCard(
                      entry: entry,
                      serverMissing: serverMissing,
                      onRetry: () => onRetryLocalUpload(entry, serverMissing),
                      onRemove: () => onRemoveLocalItem(entry),
                    ),
                  );
                }).toList(growable: false),
              ),
          ],
        ),
        _WorkflowSection(
          title: 'Processing',
          subtitle:
              'Books stay grouped here while the server splits pages and prepares student PDFs.',
          children: [
            processingCapabilities.when(
              data: (capabilities) => _ProcessingTrackerCard(
                summary: capabilities.jobSummary,
              ),
              error: (error, _) => _ProcessingTrackerErrorCard(error: error),
              loading: () => const _ProcessingTrackerLoadingCard(),
            ),
            if (bookWorkflows.isEmpty && activeLocalEntries.isEmpty)
              const _ParentEmptyState(
                title: 'No active book processing',
                body:
                    'After a book upload, you will see one grouped book workflow instead of dozens of loose pieces.',
              )
            else ...[
              ...bookWorkflows.map(
                (workflow) => Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _BookWorkflowCard(
                    workflow: workflow,
                    onOpenReview: onOpenReview,
                  ),
                ),
              ),
              ...activeLocalEntries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _IntakeEntryCard(
                    entry: entry,
                    students: students,
                    reviewItem: reviewByPieceId[entry.piece.serverPieceId],
                    onOpenReview: onOpenReview,
                    onPushToProfile: (profileId) {
                      return onPushToProfile(entry, profileId);
                    },
                    onCloseWorkflow: () => onCloseWorkflow(entry),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            _ParentDebugToolsCard(
              state: debugTools,
              pieces: debugPieceTargets,
              onToggle: onToggleDebugTools,
              onRefreshJobs: onRefreshDebugJobs,
              onCancelJob: onCancelDebugJob,
              onRetryJob: onRetryDebugJob,
              onClearLibraries: onClearDebugLibraries,
              onClearPiece: onClearDebugPiece,
            ),
          ],
        ),
        _WorkflowSection(
          title: 'Review',
          subtitle:
              'Approve metadata and the student PDF. Notation conversion lives in Advanced Notation Lab.',
          children: [
            if (reviewQueue.hasError)
              _QueueErrorCard(
                error: reviewQueue.error!,
                onRepairPairing: onRepairPairing,
              )
            else if (reviewQueue.isLoading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (bookWorkflows
                    .where((workflow) => workflow.reviewItems.isNotEmpty)
                    .isEmpty &&
                looseReviewItems.isEmpty)
              const _ParentEmptyState(
                title: 'No review items ready',
                body:
                    'Metadata review cards appear here as student PDFs become ready.',
              )
            else ...[
              ...bookWorkflows
                  .where((workflow) => workflow.reviewItems.isNotEmpty)
                  .map(
                    (workflow) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _BookReviewGroupCard(
                        workflow: workflow,
                        onOpenReview: onOpenReview,
                      ),
                    ),
                  ),
              ...looseReviewItems.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ReviewItemCard(
                    item: item,
                    onOpenReview: () => onOpenReview(item.id),
                  ),
                ),
              ),
            ],
          ],
        ),
        _WorkflowSection(
          title: 'Ready to Push',
          subtitle:
              'Approved student PDFs stay here until you assign them to a student or close them from the workflow.',
          children: [
            if (syncedPieces.hasError)
              _QueueErrorCard(
                error: syncedPieces.error!,
                onRepairPairing: onRepairPairing,
              )
            else if (syncedPieces.isLoading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (readyRemotePieces.isEmpty && readyLocalEntries.isEmpty)
              const _ParentEmptyState(
                title: 'Nothing ready to push',
                body:
                    'Approved student PDFs will appear here after parent metadata review is complete.',
              )
            else ...[
              if (readyRemotePieces.isNotEmpty)
                Column(
                  key: AppKeys.parentServerReadyList,
                  children: readyRemotePieces.map(
                    (piece) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ServerReadyPushCard(
                          piece: piece,
                          students: students,
                          onPushToProfile: (profileId) {
                            return onPushRemoteToProfile(piece, profileId);
                          },
                          onCloseWorkflow: () => onCloseRemoteWorkflow(piece),
                        ),
                      );
                    },
                  ).toList(growable: false),
                ),
              ...readyLocalEntries.map(
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
                    onCloseWorkflow: () => onCloseWorkflow(entry),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _WorkflowSection extends StatelessWidget {
  const _WorkflowSection({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _LocalImportProblemCard extends StatelessWidget {
  const _LocalImportProblemCard({
    required this.entry,
    required this.serverMissing,
    required this.onRetry,
    required this.onRemove,
  });

  final LibraryEntry entry;
  final bool serverMissing;
  final Future<void> Function() onRetry;
  final Future<void> Function() onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = serverMissing
        ? 'This item points to a server record that is no longer present. Re-upload it as a new import or remove the local copy.'
        : 'Waiting for a server connection before upload. Retry when the server is online, or remove this local-only import.';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.tertiary.withValues(alpha: 0.24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.cloud_upload_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.piece.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              _WorkflowStatusChip(
                label: serverMissing ? 'server missing' : 'needs upload',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: const Icon(Icons.replay_outlined),
                label:
                    Text(serverMissing ? 'Re-upload as new' : 'Retry upload'),
              ),
              OutlinedButton.icon(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remove local item'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BookWorkflow {
  const _BookWorkflow({
    required this.id,
    required this.title,
    this.book,
    this.children = const <RemotePieceSummary>[],
    this.reviewItems = const <ReviewQueueEntry>[],
  });

  final String id;
  final String title;
  final RemotePieceSummary? book;
  final List<RemotePieceSummary> children;
  final List<ReviewQueueEntry> reviewItems;

  int get detectedCount => children.length;
  int get metadataPendingCount => reviewItems
      .where((item) => _reviewProcessingStage(item) == 'split_review_needed')
      .length;
  int get museScorePendingCount => reviewItems
      .where(
        (item) =>
            _reviewProcessingStage(item) == 'notation_edit_queued' ||
            _reviewProcessingStage(item) == 'candidate_review_needed',
      )
      .length;
  int get approvedCount =>
      children.where((piece) => piece.libraryStatus == 'ready').length;
  int get pushedCount =>
      children.where((piece) => piece.visibleToProfileIds.isNotEmpty).length;
  int get processingCount => children
      .where(
        (piece) =>
            piece.libraryStatus == 'processing' ||
            piece.status == 'processing' ||
            piece.libraryStatus == 'review',
      )
      .length;

  ReviewQueueEntry? get nextReviewItem {
    final metadataItems = reviewItems
        .where((item) => _reviewProcessingStage(item) == 'split_review_needed')
        .toList(growable: false);
    if (metadataItems.isNotEmpty) {
      return metadataItems.first;
    }
    if (reviewItems.isNotEmpty) {
      return reviewItems.first;
    }
    return null;
  }
}

class _BookWorkflowCard extends StatelessWidget {
  const _BookWorkflowCard({
    required this.workflow,
    required this.onOpenReview,
  });

  final _BookWorkflow workflow;
  final ValueChanged<String> onOpenReview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nextReview = workflow.nextReviewItem;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFE4F6EE),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.menu_book_outlined,
                  color: Color(0xFF126B4A),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      workflow.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _bookWorkflowSummary(workflow),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              _WorkflowStatusChip(label: _bookWorkflowStatus(workflow)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text('${workflow.detectedCount} detected')),
              Chip(label: Text('${workflow.metadataPendingCount} metadata')),
              Chip(
                label: Text('${workflow.museScorePendingCount} notation edits'),
              ),
              Chip(label: Text('${workflow.approvedCount} approved')),
              if (workflow.pushedCount > 0)
                Chip(label: Text('${workflow.pushedCount} pushed')),
            ],
          ),
          if (nextReview != null) ...[
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () => onOpenReview(nextReview.id),
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Open next review'),
            ),
          ],
        ],
      ),
    );
  }
}

class _BookReviewGroupCard extends StatelessWidget {
  const _BookReviewGroupCard({
    required this.workflow,
    required this.onOpenReview,
  });

  final _BookWorkflow workflow;
  final ValueChanged<String> onOpenReview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nextReview = workflow.nextReviewItem;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.fact_check_outlined, color: Color(0xFF854F0B)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  workflow.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${workflow.metadataPendingCount} metadata review(s), '
                  '${workflow.museScorePendingCount} notation edit item(s).',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (nextReview != null) ...[
                  const SizedBox(height: 10),
                  FilledButton.tonalIcon(
                    onPressed: () => onOpenReview(nextReview.id),
                    icon: const Icon(Icons.arrow_forward_outlined),
                    label: const Text('Continue review'),
                  ),
                ],
              ],
            ),
          ),
          Chip(label: Text('${workflow.reviewItems.length} open')),
        ],
      ),
    );
  }
}

class _WorkflowStatusChip extends StatelessWidget {
  const _WorkflowStatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Chip(
      visualDensity: VisualDensity.compact,
      label: Text(label),
      labelStyle: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w700,
      ),
      backgroundColor:
          theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
    );
  }
}

List<_BookWorkflow> _buildBookWorkflows({
  required List<RemotePieceSummary> pieces,
  required List<ReviewQueueEntry> reviewItems,
}) {
  final booksById = <String, RemotePieceSummary>{
    for (final piece in pieces)
      if (piece.pieceKind == 'book' && !piece.workflowClosed) piece.id: piece,
  };
  final childrenByBookId = <String, List<RemotePieceSummary>>{};
  for (final piece in pieces) {
    final sourceBookId = piece.sourceBookId;
    if (sourceBookId == null ||
        sourceBookId.isEmpty ||
        piece.workflowClosed ||
        piece.pieceKind == 'book') {
      continue;
    }
    childrenByBookId.putIfAbsent(sourceBookId, () => []).add(piece);
  }

  final reviewsByBookId = <String, List<ReviewQueueEntry>>{};
  for (final item in reviewItems) {
    final sourceBookId = _reviewSourceBookId(item);
    if (sourceBookId == null || sourceBookId.isEmpty) {
      continue;
    }
    reviewsByBookId.putIfAbsent(sourceBookId, () => []).add(item);
  }

  final bookIds = <String>{
    ...booksById.keys,
    ...childrenByBookId.keys,
    ...reviewsByBookId.keys,
  };
  final workflows = bookIds.map((bookId) {
    final book = booksById[bookId];
    final children = childrenByBookId[bookId] ?? const <RemotePieceSummary>[];
    final reviews = reviewsByBookId[bookId] ?? const <ReviewQueueEntry>[];
    return _BookWorkflow(
      id: bookId,
      title: _bookWorkflowTitle(book, children, reviews),
      book: book,
      children: children,
      reviewItems: reviews,
    );
  }).toList();
  workflows.sort((left, right) => left.title.compareTo(right.title));
  return workflows;
}

String _bookWorkflowTitle(
  RemotePieceSummary? book,
  List<RemotePieceSummary> children,
  List<ReviewQueueEntry> reviews,
) {
  if (book != null) {
    return book.title;
  }
  for (final child in children) {
    final title =
        child.bookOrCollection ?? child.catalogMetadata['book_or_collection'];
    final text = _metadataString(title);
    if (text != null) {
      return text;
    }
  }
  for (final review in reviews) {
    final catalog = review.candidateData['catalog_metadata'];
    if (catalog is Map) {
      final title = _metadataString(catalog['book_or_collection']);
      if (title != null) {
        return title;
      }
    }
  }
  return 'Book import';
}

String _bookWorkflowSummary(_BookWorkflow workflow) {
  if (workflow.reviewItems.isEmpty && workflow.processingCount == 0) {
    return 'Book source uploaded. Waiting for extracted pieces or review output.';
  }
  return '${workflow.detectedCount} piece(s) detected, '
      '${workflow.processingCount} processing/reviewing, '
      '${workflow.approvedCount} approved.';
}

String _bookWorkflowStatus(_BookWorkflow workflow) {
  if (workflow.metadataPendingCount > 0) {
    return 'metadata review';
  }
  if (workflow.museScorePendingCount > 0) {
    return 'notation edit';
  }
  if (workflow.processingCount > 0) {
    return 'processing';
  }
  if (workflow.approvedCount > 0) {
    return 'ready';
  }
  return 'uploaded';
}

String? _reviewSourceBookId(ReviewQueueEntry item) {
  return _metadataString(item.candidateData['source_book_id']);
}

String? _reviewProcessingStage(ReviewQueueEntry item) {
  return _metadataString(item.candidateData['processing_stage']);
}

class _ProcessingTrackerCard extends StatelessWidget {
  const _ProcessingTrackerCard({required this.summary});

  final ProcessingJobSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completedCount = summary.succeededCount + summary.failedCount;
    final totalCount =
        completedCount + summary.queuedCount + summary.runningCount;
    final hasJobs = totalCount > 0;
    final progress = hasJobs ? completedCount / totalCount : null;
    final activeText = summary.runningCount == 0 && summary.queuedCount == 0
        ? 'No active server processing jobs.'
        : '${summary.runningCount} running, ${summary.queuedCount} queued.';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.pending_actions_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Processing tracker',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Chip(
                  label: Text(
                    hasJobs ? '$completedCount / $totalCount done' : 'Idle',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 10),
            Text(
              activeText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (summary.failedCount > 0) ...[
              const SizedBox(height: 8),
              Text(
                '${summary.failedCount} job(s) failed. Check Server for details.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DebugPieceTarget {
  const _DebugPieceTarget({
    required this.title,
    required this.scopeLabel,
    this.localPieceId,
    this.serverPieceId,
  });

  final String title;
  final String scopeLabel;
  final String? localPieceId;
  final String? serverPieceId;

  String get keyId => serverPieceId ?? localPieceId ?? title;
}

List<_DebugPieceTarget> _buildDebugPieceTargets({
  required List<LibraryEntry> localEntries,
  required List<RemotePieceSummary> remotePieces,
}) {
  final targets = <_DebugPieceTarget>[];
  final seenServerPieceIds = <String>{};
  for (final entry in localEntries) {
    final serverPieceId = entry.piece.serverPieceId;
    if (serverPieceId != null) {
      seenServerPieceIds.add(serverPieceId);
    }
    targets.add(
      _DebugPieceTarget(
        title: entry.piece.title,
        localPieceId: entry.piece.id,
        serverPieceId: serverPieceId,
        scopeLabel: serverPieceId == null
            ? 'Local library data'
            : 'Local and server workflow data',
      ),
    );
  }
  for (final piece in remotePieces) {
    if (seenServerPieceIds.contains(piece.id)) {
      continue;
    }
    targets.add(
      _DebugPieceTarget(
        title: piece.title,
        serverPieceId: piece.id,
        scopeLabel: 'Server workflow data',
      ),
    );
  }
  targets
      .sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  return targets;
}

class _ParentDebugToolsCard extends StatelessWidget {
  const _ParentDebugToolsCard({
    required this.state,
    required this.pieces,
    required this.onToggle,
    required this.onRefreshJobs,
    required this.onCancelJob,
    required this.onRetryJob,
    required this.onClearLibraries,
    required this.onClearPiece,
  });

  final ParentDebugToolsState state;
  final List<_DebugPieceTarget> pieces;
  final Future<void> Function(bool enabled) onToggle;
  final Future<void> Function() onRefreshJobs;
  final Future<void> Function(String jobId) onCancelJob;
  final Future<void> Function(String jobId) onRetryJob;
  final Future<void> Function() onClearLibraries;
  final Future<void> Function(_DebugPieceTarget piece) onClearPiece;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final failedCount =
        state.jobs.where((job) => job.status == 'failed').length;
    final runningCount =
        state.jobs.where((job) => job.status == 'running').length;
    final queuedCount =
        state.jobs.where((job) => job.status == 'queued').length;
    final visibleJobs = _prioritizedDebugJobs(state.jobs).take(40).toList();
    return DecoratedBox(
      key: AppKeys.parentDebugToolsCard,
      decoration: BoxDecoration(
        color: state.enabled
            ? theme.colorScheme.errorContainer.withValues(alpha: 0.16)
            : theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: state.enabled
              ? theme.colorScheme.error.withValues(alpha: 0.24)
              : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              key: AppKeys.parentDebugToolsToggle,
              contentPadding: EdgeInsets.zero,
              value: state.enabled,
              onChanged: state.busy ? null : (value) => onToggle(value),
              title: const Text('Debug tools'),
              subtitle: const Text(
                'For test cleanup only. These actions can remove local and server workflow data.',
              ),
            ),
            if (state.enabled) ...[
              const SizedBox(height: 8),
              if (state.busy) const LinearProgressIndicator(),
              if (state.message != null) ...[
                const SizedBox(height: 8),
                Text(
                  state.message!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (state.error != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Debug action failed: ${formatServerConnectionError(state.error!)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    key: AppKeys.parentDebugClearLibrariesButton,
                    onPressed: state.busy
                        ? null
                        : () => _confirmClearLibraries(context),
                    icon: const Icon(Icons.delete_sweep_outlined),
                    label: const Text('Clear local + server libraries'),
                  ),
                  OutlinedButton.icon(
                    key: AppKeys.parentDebugRefreshJobsButton,
                    onPressed: state.busy ? null : onRefreshJobs,
                    icon: const Icon(Icons.refresh_outlined),
                    label: const Text('Refresh server jobs'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Pieces',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Clear one problem import without resetting the full library.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              if (pieces.isEmpty)
                Text(
                  'No local or server pieces found.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              else
                ...pieces.take(30).map(
                      (piece) => _DebugPieceRow(
                        piece: piece,
                        busy: state.busy,
                        onClear: () => _confirmClearPiece(context, piece),
                      ),
                    ),
              const SizedBox(height: 14),
              Text(
                'Server jobs',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (state.jobs.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '$failedCount failed, $runningCount running, $queuedCount queued. '
                  'Showing jobs needing attention first.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: failedCount > 0
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight:
                        failedCount > 0 ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              if (state.jobs.isEmpty)
                Text(
                  'No server jobs found.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              else
                ...visibleJobs.map(
                  (job) => _DebugJobRow(
                    job: job,
                    busy: state.busy,
                    onCancel: () => _confirmCancelJob(context, job),
                    onRetry: () => _confirmRetryJob(context, job),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmClearLibraries(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear debug libraries?'),
        content: const Text(
          'This clears this Windows client library and server import, review, job, and generated workflow data. Pairing, students, parent PIN, and processing settings are preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await onClearLibraries();
    }
  }

  Future<void> _confirmClearPiece(
    BuildContext context,
    _DebugPieceTarget piece,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear ${piece.title}?'),
        content: Text(
          'This removes ${piece.scopeLabel.toLowerCase()} for this piece only. '
          'Other imports, pairing, students, parent PIN, and processing settings are preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear piece'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await onClearPiece(piece);
    }
  }

  Future<void> _confirmCancelJob(
    BuildContext context,
    ServerJob job,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel server job?'),
        content: Text(
          'Cancel ${job.jobType} job ${job.id}? Running tools may finish their current subprocess, but the job will not publish final review output after cancellation is detected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep running'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancel job'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await onCancelJob(job.id);
    }
  }

  Future<void> _confirmRetryJob(
    BuildContext context,
    ServerJob job,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retry processing?'),
        content: Text(
          'Retry processing for ${job.pieceLabel}? This reruns the advanced notation pipeline and will not block the already approved student PDF.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Retry processing'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await onRetryJob(job.id);
    }
  }
}

List<ServerJob> _prioritizedDebugJobs(List<ServerJob> jobs) {
  final sorted = [...jobs];
  sorted.sort((a, b) {
    final priorityCompare = _debugJobStatusPriority(a.status)
        .compareTo(_debugJobStatusPriority(b.status));
    if (priorityCompare != 0) {
      return priorityCompare;
    }
    return b.updatedAt.compareTo(a.updatedAt);
  });
  return sorted;
}

int _debugJobStatusPriority(String status) {
  return switch (status) {
    'failed' => 0,
    'running' => 1,
    'queued' => 2,
    'canceled' => 3,
    _ => 4,
  };
}

class _DebugPieceRow extends StatelessWidget {
  const _DebugPieceRow({
    required this.piece,
    required this.busy,
    required this.onClear,
  });

  final _DebugPieceTarget piece;
  final bool busy;
  final Future<void> Function() onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  piece.title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  piece.scopeLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            key: AppKeys.parentDebugClearPieceButton(piece.keyId),
            onPressed: busy ? null : onClear,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Clear piece'),
          ),
        ],
      ),
    );
  }
}

class _DebugJobRow extends StatelessWidget {
  const _DebugJobRow({
    required this.job,
    required this.busy,
    required this.onCancel,
    required this.onRetry,
  });

  final ServerJob job;
  final bool busy;
  final Future<void> Function() onCancel;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = switch (job.status) {
      'queued' || 'running' => const Color(0xFF854F0B),
      'succeeded' => const Color(0xFF126B4A),
      'failed' => theme.colorScheme.error,
      'canceled' => theme.colorScheme.onSurfaceVariant,
      _ => theme.colorScheme.onSurface,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.pieceLabel,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${job.jobType} ${job.status}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Chip(
                visualDensity: VisualDensity.compact,
                label: Text(job.status),
                labelStyle: TextStyle(color: statusColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: job.progress.clamp(0, 100) / 100),
          const SizedBox(height: 6),
          Text(
            '${job.progress.toStringAsFixed(0)}% - updated ${_shortDateTime(job.updatedAt)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (job.errorMessage?.isNotEmpty ?? false) ...[
            const SizedBox(height: 6),
            Text(
              job.errorMessage!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          if (job.canCancel) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: AppKeys.parentDebugCancelJobButton(job.id),
              onPressed: busy ? null : onCancel,
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Cancel'),
            ),
          ],
          if (job.canRetry) ...[
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              key: AppKeys.parentDebugRetryJobButton(job.id),
              onPressed: busy ? null : onRetry,
              icon: const Icon(Icons.replay_outlined),
              label: const Text('Retry processing'),
            ),
          ],
        ],
      ),
    );
  }
}

String _shortDateTime(DateTime value) {
  if (value.millisecondsSinceEpoch == 0) {
    return 'unknown';
  }
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$month/$day $hour:$minute';
}

class _ProcessingTrackerLoadingCard extends StatelessWidget {
  const _ProcessingTrackerLoadingCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: LinearProgressIndicator(),
      ),
    );
  }
}

class _ProcessingTrackerErrorCard extends StatelessWidget {
  const _ProcessingTrackerErrorCard({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: theme.colorScheme.error.withValues(alpha: 0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Unable to load processing tracker: $error',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onErrorContainer,
          ),
        ),
      ),
    );
  }
}

class _StudentsTab extends StatelessWidget {
  const _StudentsTab({
    required this.syncedPieces,
    required this.students,
    required this.onRepairPairing,
    required this.onAddStudent,
    required this.onCreatePairing,
    required this.onEditMetadata,
    required this.onPushOriginal,
    required this.onPullForEdits,
  });

  final AsyncValue<List<RemotePieceSummary>> syncedPieces;
  final List<Profile> students;
  final VoidCallback onRepairPairing;
  final VoidCallback onAddStudent;
  final ValueChanged<Profile> onCreatePairing;
  final ValueChanged<RemotePieceSummary> onEditMetadata;
  final Future<void> Function(RemotePieceSummary piece, String profileId)
      onPushOriginal;
  final Future<void> Function(RemotePieceSummary piece) onPullForEdits;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StudentDevicePairingCard(
          students: students,
          onAddStudent: onAddStudent,
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
                    'Once imports reach the server, parent-managed metadata, student PDFs, and assignments will appear here.',
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
                        onPushOriginal: (profileId) =>
                            onPushOriginal(piece, profileId),
                        onPullForEdits: () => onPullForEdits(piece),
                      ),
                    ),
                  )
                  .toList(growable: false),
            );
          },
          error: (error, _) => _QueueErrorCard(
            error: error,
            onRepairPairing: onRepairPairing,
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

class _ServerToolsTab extends StatelessWidget {
  const _ServerToolsTab({
    required this.serverHealth,
    required this.onRepairPairing,
  });

  final AsyncValue<ServerHealthState> serverHealth;
  final VoidCallback onRepairPairing;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ServerStatusCard(
          serverHealth: serverHealth,
          onRepairPairing: onRepairPairing,
        ),
        const SizedBox(height: 12),
        const _CloudSyncCard(),
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
    required this.onCloseWorkflow,
  });

  final LibraryEntry entry;
  final List<Profile> students;
  final ReviewQueueEntry? reviewItem;
  final ValueChanged<String> onOpenReview;
  final Future<void> Function(String profileId) onPushToProfile;
  final Future<void> Function() onCloseWorkflow;

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
    final canCloseWorkflow = canPush &&
        piece.serverPieceId != null &&
        piece.visibleToProfileIds.isNotEmpty;

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
                label: const Text('Review metadata'),
              ),
            ],
          ] else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...students.map((student) {
                  final alreadyVisible =
                      piece.visibleToProfileIds.contains(student.id);
                  return FilledButton.tonalIcon(
                    key: AppKeys.pushToProfileButton(piece.id, student.id),
                    onPressed: alreadyVisible
                        ? null
                        : () => onPushToProfile(student.id),
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
                }),
                if (canCloseWorkflow)
                  OutlinedButton.icon(
                    onPressed: onCloseWorkflow,
                    icon: const Icon(Icons.done_all_outlined),
                    label: const Text('Close workflow'),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  String _statusMessage(LibraryStatus status, bool hasReviewItem) {
    return switch (status) {
      LibraryStatus.intake => 'Waiting for server upload.',
      LibraryStatus.uploadPending =>
        'Waiting for server connection before upload.',
      LibraryStatus.processing =>
        'Server is preparing the student PDF and metadata.',
      LibraryStatus.review => hasReviewItem
          ? 'Student PDF is ready. Review metadata before pushing.'
          : 'Student PDF is ready, but the review item is still syncing.',
      LibraryStatus.needsEdits =>
        'Metadata or notation was rejected or pulled back. You can still push the student PDF fallback.',
      LibraryStatus.ready => 'Student PDF ready to push.',
      LibraryStatus.archived => 'Rejected or archived after parent review.',
    };
  }
}

class _ServerReadyPushCard extends StatelessWidget {
  const _ServerReadyPushCard({
    required this.piece,
    required this.students,
    required this.onPushToProfile,
    required this.onCloseWorkflow,
  });

  final RemotePieceSummary piece;
  final List<Profile> students;
  final Future<void> Function(String profileId) onPushToProfile;
  final Future<void> Function() onCloseWorkflow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final assignedNames = students
        .where((student) => piece.visibleToProfileIds.contains(student.id))
        .map((student) => student.displayName)
        .toList(growable: false);
    final subtitle = <String>[
      if (piece.composer?.isNotEmpty ?? false) piece.composer!,
      if (piece.primaryInstrument?.isNotEmpty ?? false)
        piece.primaryInstrument!,
      if (piece.bookOrCollection?.isNotEmpty ?? false) piece.bookOrCollection!,
      if (assignedNames.isEmpty)
        'Not assigned to a student'
      else
        'Assigned to ${assignedNames.join(', ')}',
    ].join(' - ');
    final canCloseWorkflow = piece.visibleToProfileIds.isNotEmpty;

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
            crossAxisAlignment: CrossAxisAlignment.start,
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
              const Chip(label: Text('Ready')),
            ],
          ),
          const SizedBox(height: 12),
          if (students.isEmpty)
            Text(
              'Create a student profile before pushing this approved piece.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...students.map((student) {
                  final alreadyVisible =
                      piece.visibleToProfileIds.contains(student.id);
                  return FilledButton.tonalIcon(
                    key: AppKeys.pushToProfileButton(piece.id, student.id),
                    onPressed: alreadyVisible
                        ? null
                        : () => onPushToProfile(student.id),
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
                }),
                if (canCloseWorkflow)
                  OutlinedButton.icon(
                    onPressed: onCloseWorkflow,
                    icon: const Icon(Icons.done_all_outlined),
                    label: const Text('Close workflow'),
                  ),
              ],
            ),
        ],
      ),
    );
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
      LibraryStatus.needsEdits => (
          background: const Color(0xFFFFF2D7),
          foreground: const Color(0xFF854F0B),
          label: 'Needs edits',
        ),
      LibraryStatus.uploadPending => (
          background: const Color(0xFFFAEEDA),
          foreground: const Color(0xFF854F0B),
          label: 'Server',
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
  const _ServerStatusCard({
    required this.serverHealth,
    required this.onRepairPairing,
  });

  final AsyncValue<ServerHealthState> serverHealth;
  final VoidCallback onRepairPairing;

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
        final label = state.isOnline
            ? 'Server online'
            : AppConfig.isServerPaired
                ? 'Server offline'
                : 'Server not paired';

        return Container(
          key: AppKeys.parentServerStatus,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: foreground.withValues(alpha: 0.18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
              if (state.message != null) ...[
                const SizedBox(height: 8),
                Text(
                  state.message!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: foreground.withValues(alpha: 0.86),
                  ),
                ),
              ],
              if (!state.isOnline) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: onRepairPairing,
                  icon: const Icon(Icons.qr_code_scanner_outlined),
                  label: Text(
                    AppConfig.isServerPaired
                        ? 'Repair server pairing'
                        : 'Pair this device',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: foreground,
                    side: BorderSide(
                      color: foreground.withValues(alpha: 0.38),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
      error: (error, stackTrace) => Container(
        key: AppKeys.parentServerStatus,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFAEEDA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x33854F0B)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Server check failed',
              style: theme.textTheme.labelLarge?.copyWith(
                color: const Color(0xFF854F0B),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              formatServerConnectionError(error),
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF854F0B),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onRepairPairing,
              icon: const Icon(Icons.qr_code_scanner_outlined),
              label: const Text('Repair server pairing'),
            ),
          ],
        ),
      ),
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
    required this.onAddStudent,
    required this.onCreatePairing,
  });

  final List<Profile> students;
  final VoidCallback onAddStudent;
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
            'Add student profiles here, then generate a separate QR code for each student device.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: AppKeys.parentAddStudentButton,
            onPressed: onAddStudent,
            icon: const Icon(Icons.person_add_alt_1_outlined),
            label: const Text('Add student'),
          ),
          const SizedBox(height: 12),
          if (students.isEmpty)
            Text(
              'No students have been added yet.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
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

class _StudentDraft {
  const _StudentDraft({
    required this.displayName,
    required this.instrument,
  });

  final String displayName;
  final InstrumentType instrument;
}

class _AddStudentDialog extends StatefulWidget {
  const _AddStudentDialog();

  @override
  State<_AddStudentDialog> createState() => _AddStudentDialogState();
}

class _AddStudentDialogState extends State<_AddStudentDialog> {
  final TextEditingController _nameController = TextEditingController();
  InstrumentType _instrument = InstrumentType.cello;
  String? _nameError;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add student'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: AppKeys.parentStudentNameField,
              controller: _nameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Student name',
                errorText: _nameError,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<InstrumentType>(
              initialValue: _instrument,
              decoration: const InputDecoration(
                labelText: 'Primary instrument',
                border: OutlineInputBorder(),
              ),
              items: InstrumentType.values
                  .map(
                    (instrument) => DropdownMenuItem(
                      value: instrument,
                      child: Text(_instrumentLabel(instrument)),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _instrument = value;
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: AppKeys.parentCreateStudentButton,
          onPressed: _submit,
          child: const Text('Create student'),
        ),
      ],
    );
  }

  void _submit() {
    final displayName = _nameController.text.trim();
    if (displayName.isEmpty) {
      setState(() {
        _nameError = 'Student name is required.';
      });
      return;
    }
    Navigator.of(context).pop(
      _StudentDraft(displayName: displayName, instrument: _instrument),
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
                      'Advanced Notation Lab settings',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Configure OCR, Audiveris, and MuseScore Studio for notation editing.',
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

class _CloudSyncCard extends ConsumerWidget {
  const _CloudSyncCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final status = ref.watch(_parentCloudStatusProvider);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: status.when(
          loading: () => const Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Loading cloud sync status...'),
            ],
          ),
          error: (error, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cloud sync unavailable',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                formatServerConnectionError(error),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ),
          data: (payload) => _CloudSyncStatusBody(payload: payload),
        ),
      ),
    );
  }
}

class _CloudSyncStatusBody extends ConsumerWidget {
  const _CloudSyncStatusBody({required this.payload});

  final Map<String, dynamic> payload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final connected = payload['connected'] as bool? ?? false;
    final repository = payload['repository'] as String?;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.cloud_sync_outlined),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Parent cloud restore',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Chip(label: Text(connected ? 'GitHub linked' : 'GitHub pending')),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          repository == null || repository.isEmpty
              ? 'Interim GitHub sync is not configured yet. Student devices still resync from the paired server.'
              : 'Sync target: $repository',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: () => _runCloudAction(
                context,
                ref,
                action: () => ref
                    .read(serverPieceSyncRepositoryProvider)
                    .syncCloudManifest(),
                successPrefix: 'Cloud manifest synced',
              ),
              icon: const Icon(Icons.upload_outlined),
              label: const Text('Sync manifest'),
            ),
            OutlinedButton.icon(
              onPressed: () => _runCloudAction(
                context,
                ref,
                action: () => ref
                    .read(serverPieceSyncRepositoryProvider)
                    .restoreCloudManifest(),
                successPrefix: 'Restore manifest checked',
              ),
              icon: const Icon(Icons.restore_outlined),
              label: const Text('Check restore'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _runCloudAction(
    BuildContext context,
    WidgetRef ref, {
    required Future<Map<String, dynamic>> Function() action,
    required String successPrefix,
  }) async {
    try {
      final result = await action();
      ref.invalidate(_parentCloudStatusProvider);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$successPrefix: ${result['pieces_count'] ?? 0} pieces, '
            '${result['notes_count'] ?? 0} notes.',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cloud action failed: $error')),
      );
    }
  }
}

class _SyncedPieceCard extends StatelessWidget {
  const _SyncedPieceCard({
    required this.piece,
    required this.students,
    required this.onEditMetadata,
    required this.onPushOriginal,
    required this.onPullForEdits,
  });

  final RemotePieceSummary piece;
  final List<Profile> students;
  final VoidCallback onEditMetadata;
  final ValueChanged<String> onPushOriginal;
  final VoidCallback onPullForEdits;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final assignedNames = students
        .where((student) => piece.visibleToProfileIds.contains(student.id))
        .map((student) => student.displayName)
        .toList(growable: false);
    final unassignedStudents = students
        .where((student) => !piece.visibleToProfileIds.contains(student.id))
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
                    if (assignedNames.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: onPullForEdits,
                        icon: const Icon(Icons.build_outlined),
                        label: const Text('Pull back for edits'),
                      ),
                    for (final student in unassignedStudents)
                      OutlinedButton.icon(
                        onPressed: () => onPushOriginal(student.id),
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: Text('Push original to ${student.displayName}'),
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
  const _QueueErrorCard({
    required this.error,
    required this.onRepairPairing,
  });

  final Object error;
  final VoidCallback onRepairPairing;

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
            isServerConnectionError(error)
                ? 'Server connection needs attention.'
                : 'Unable to load the parent review queue.',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            formatServerConnectionError(error),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          if (isServerConnectionError(error)) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRepairPairing,
              icon: const Icon(Icons.qr_code_scanner_outlined),
              label: Text(
                AppConfig.isServerPaired
                    ? 'Repair server pairing'
                    : 'Pair this device',
              ),
            ),
          ],
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

String _instrumentLabel(InstrumentType instrument) {
  switch (instrument) {
    case InstrumentType.violin:
      return 'Violin';
    case InstrumentType.viola:
      return 'Viola';
    case InstrumentType.cello:
      return 'Cello';
    case InstrumentType.doubleBass:
      return 'Double bass';
    case InstrumentType.guitar:
      return 'Guitar';
    case InstrumentType.piano:
      return 'Piano';
    case InstrumentType.other:
      return 'Other';
  }
}
