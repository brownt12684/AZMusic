import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/network/server_connection_error.dart';
import '../../data/repositories/server_piece_sync_repository.dart';
import '../../domain/entities/review_candidate_package.dart';

final serverPieceSyncRepositoryProvider = Provider<ServerPieceSyncRepository>(
  (ref) => ServerPieceSyncRepository(),
);

final parentReviewQueueProvider =
    AsyncNotifierProvider<ParentReviewQueueNotifier, List<ReviewQueueEntry>>(
  ParentReviewQueueNotifier.new,
);

class ParentReviewQueueNotifier extends AsyncNotifier<List<ReviewQueueEntry>> {
  @override
  Future<List<ReviewQueueEntry>> build() async {
    return _loadQueue();
  }

  Future<void> refresh({bool showLoading = true}) async {
    if (showLoading) {
      state = const AsyncValue.loading();
    }
    state = await AsyncValue.guard(_loadQueue);
  }

  Future<void> refreshInBackground() async {
    try {
      final queue = await _loadQueue();
      state = AsyncValue.data(queue);
    } catch (error, stackTrace) {
      if (state.valueOrNull == null) {
        state = AsyncValue.error(error, stackTrace);
      }
    }
  }

  List<ReviewQueueEntry> currentItems() {
    return state.valueOrNull ?? const <ReviewQueueEntry>[];
  }

  ReviewQueueEntry? nextAfterRemoving(
    Iterable<String> itemIds, {
    String? currentItemId,
  }) {
    final removedIds = itemIds.toSet();
    for (final item in currentItems()) {
      if (removedIds.contains(item.id)) {
        continue;
      }
      if (currentItemId != null && item.id == currentItemId) {
        continue;
      }
      return item;
    }
    return null;
  }

  void removeItems(Iterable<String> itemIds) {
    final removedIds = itemIds.toSet();
    if (removedIds.isEmpty) {
      return;
    }
    final current = currentItems();
    if (current.isEmpty) {
      return;
    }
    state = AsyncValue.data(
      current
          .where((item) => !removedIds.contains(item.id))
          .toList(growable: false),
    );
  }

  Future<List<ReviewQueueEntry>> _loadQueue() async {
    if (!AppConfig.isServerPaired) {
      throw const ServerNotPairedException();
    }
    return ref.read(serverPieceSyncRepositoryProvider).fetchReviewQueue();
  }
}

final reviewItemDetailProvider =
    FutureProvider.family<ReviewQueueEntry, String>((ref, itemId) {
  if (!AppConfig.isServerPaired) {
    throw const ServerNotPairedException();
  }
  return ref.read(serverPieceSyncRepositoryProvider).fetchReviewItem(itemId);
});
