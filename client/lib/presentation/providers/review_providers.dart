import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_loadQueue);
  }

  Future<List<ReviewQueueEntry>> _loadQueue() async {
    return ref.read(serverPieceSyncRepositoryProvider).fetchReviewQueue();
  }
}

final reviewItemDetailProvider =
    FutureProvider.family<ReviewQueueEntry, String>((ref, itemId) {
  return ref.read(serverPieceSyncRepositoryProvider).fetchReviewItem(itemId);
});
