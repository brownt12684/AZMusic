import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/network/server_connection_error.dart';
import '../../domain/entities/server_job.dart';
import 'app_providers.dart';
import 'piece_providers.dart';
import 'processing_settings_providers.dart';
import 'review_providers.dart';

final parentDebugToolsProvider =
    NotifierProvider<ParentDebugToolsNotifier, ParentDebugToolsState>(
  ParentDebugToolsNotifier.new,
);

class ParentDebugToolsState {
  const ParentDebugToolsState({
    this.enabled = false,
    this.busy = false,
    this.jobs = const <ServerJob>[],
    this.message,
    this.error,
  });

  final bool enabled;
  final bool busy;
  final List<ServerJob> jobs;
  final String? message;
  final Object? error;

  ParentDebugToolsState copyWith({
    bool? enabled,
    bool? busy,
    List<ServerJob>? jobs,
    String? message,
    Object? error,
    bool clearMessage = false,
    bool clearError = false,
  }) {
    return ParentDebugToolsState(
      enabled: enabled ?? this.enabled,
      busy: busy ?? this.busy,
      jobs: jobs ?? this.jobs,
      message: clearMessage ? null : message ?? this.message,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class ParentDebugToolsNotifier extends Notifier<ParentDebugToolsState> {
  @override
  ParentDebugToolsState build() {
    return const ParentDebugToolsState();
  }

  Future<void> setEnabled(bool enabled) async {
    state = state.copyWith(
      enabled: enabled,
      clearError: true,
      clearMessage: true,
    );
    if (enabled) {
      await refreshJobs();
    }
  }

  Future<void> refreshJobs() async {
    if (!AppConfig.isServerPaired) {
      state = state.copyWith(
        busy: false,
        error: const ServerNotPairedException(),
        clearMessage: true,
      );
      return;
    }
    state = state.copyWith(busy: true, clearError: true, clearMessage: true);
    try {
      final jobs =
          await ref.read(serverPieceSyncRepositoryProvider).fetchJobs();
      state = state.copyWith(busy: false, jobs: jobs, clearError: true);
    } catch (error) {
      state = state.copyWith(busy: false, error: error, clearMessage: true);
    }
  }

  Future<void> cancelJob(String jobId) async {
    if (!AppConfig.isServerPaired) {
      state = state.copyWith(error: const ServerNotPairedException());
      return;
    }
    state = state.copyWith(busy: true, clearError: true, clearMessage: true);
    try {
      await ref.read(serverPieceSyncRepositoryProvider).cancelJob(jobId);
      await _refreshParentWorkflow();
      final jobs =
          await ref.read(serverPieceSyncRepositoryProvider).fetchJobs();
      state = state.copyWith(
        busy: false,
        jobs: jobs,
        message: 'Canceled server job.',
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(busy: false, error: error, clearMessage: true);
    }
  }

  Future<void> retryJob(String jobId) async {
    if (!AppConfig.isServerPaired) {
      state = state.copyWith(error: const ServerNotPairedException());
      return;
    }
    state = state.copyWith(busy: true, clearError: true, clearMessage: true);
    try {
      await ref.read(serverPieceSyncRepositoryProvider).retryJob(jobId);
      await _refreshParentWorkflow();
      final jobs =
          await ref.read(serverPieceSyncRepositoryProvider).fetchJobs();
      state = state.copyWith(
        busy: false,
        jobs: jobs,
        message: 'Retried server processing job.',
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(busy: false, error: error, clearMessage: true);
    }
  }

  Future<void> clearLocalAndServerLibraries() async {
    state = state.copyWith(busy: true, clearError: true, clearMessage: true);
    try {
      await ref.read(allPiecesProvider.notifier).clearLibrary();
      if (AppConfig.isServerPaired) {
        await ref
            .read(serverPieceSyncRepositoryProvider)
            .clearServerWorkflowData();
      }
      await _refreshParentWorkflow();
      final jobs = AppConfig.isServerPaired
          ? await ref.read(serverPieceSyncRepositoryProvider).fetchJobs()
          : const <ServerJob>[];
      state = state.copyWith(
        busy: false,
        jobs: jobs,
        message: AppConfig.isServerPaired
            ? 'Cleared local and server workflow libraries.'
            : 'Cleared local library. Server is not paired.',
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(busy: false, error: error, clearMessage: true);
    }
  }

  Future<void> clearPiece({
    required String title,
    String? localPieceId,
    String? serverPieceId,
  }) async {
    if (localPieceId == null && serverPieceId == null) {
      state = state.copyWith(
        error: StateError('No local or server piece id was provided.'),
        clearMessage: true,
      );
      return;
    }
    state = state.copyWith(busy: true, clearError: true, clearMessage: true);
    try {
      if (serverPieceId != null) {
        if (!AppConfig.isServerPaired) {
          throw const ServerNotPairedException();
        }
        await ref
            .read(serverPieceSyncRepositoryProvider)
            .clearServerPieceWorkflowData(serverPieceId);
      }
      if (localPieceId != null) {
        await ref.read(allPiecesProvider.notifier).removeLocalEntry(
              localPieceId,
            );
      }
      await _refreshParentWorkflow();
      final jobs = AppConfig.isServerPaired
          ? await ref.read(serverPieceSyncRepositoryProvider).fetchJobs()
          : const <ServerJob>[];
      state = state.copyWith(
        busy: false,
        jobs: jobs,
        message: 'Cleared $title from the debug library workflow.',
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(busy: false, error: error, clearMessage: true);
    }
  }

  Future<void> _refreshParentWorkflow() async {
    ref.invalidate(serverHealthProvider);
    await ref
        .read(parentSyncedPiecesProvider.notifier)
        .refresh(showLoading: false);
    await ref
        .read(processingCapabilitiesProvider.notifier)
        .refresh(showLoading: false);
    await ref.read(parentReviewQueueProvider.notifier).refresh(
          showLoading: false,
        );
    await ref.read(allPiecesProvider.notifier).refreshInBackground(
          trigger: SyncTrigger.manualRefresh,
        );
  }
}
