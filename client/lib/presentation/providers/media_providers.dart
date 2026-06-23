import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/media_repository.dart';
import '../../domain/entities/media_asset.dart';
import '../../domain/entities/youtube_candidate.dart';
import 'piece_providers.dart';

final mediaRepositoryProvider = Provider<MediaRepository>((ref) {
  final libRepo = ref.watch(libraryRepositoryProvider);
  return MediaRepository(database: libRepo.db);
});

final mediaCandidatesProvider = FutureProvider.family<List<YouTubeCandidate>, String>((ref, pieceId) async {
  final repo = ref.watch(mediaRepositoryProvider);
  return repo.fetchCandidates(pieceId);
});

final mediaAssetsProvider = FutureProvider.family<List<MediaAsset>, String>((ref, pieceId) async {
  final libRepo = ref.watch(libraryRepositoryProvider);
  // Watch allPiecesProvider to reload when local pieces list changes (e.g. syncs)
  ref.watch(allPiecesProvider);
  return libRepo.db.loadMediaAssetsForPiece(pieceId);
});

// A notifier to handle media operations (push, revoke, trigger search, sync delta)
final mediaOperationsProvider = Provider((ref) {
  final repo = ref.watch(mediaRepositoryProvider);
  final libRepo = ref.watch(libraryRepositoryProvider);

  return MediaOperations(repo: repo, db: libRepo.db, ref: ref);
});

class MediaOperations {
  MediaOperations({
    required this.repo,
    required this.db,
    required this.ref,
  });

  final MediaRepository repo;
  final db;
  final ProviderRef ref;

  Future<void> searchYouTubeForPiece(String pieceId) async {
    await repo.triggerSearch(pieceId);
    ref.invalidate(mediaCandidatesProvider(pieceId));
  }

  Future<void> pushCandidate(String pieceId, String candidateId) async {
    final success = await repo.pushMedia(candidateId);
    if (success) {
      ref.invalidate(mediaCandidatesProvider(pieceId));
      ref.invalidate(mediaAssetsProvider(pieceId));
    }
  }

  Future<void> revokeAsset(String pieceId, String assetId) async {
    final success = await repo.revokeMedia(assetId);
    if (success) {
      ref.invalidate(mediaCandidatesProvider(pieceId));
      ref.invalidate(mediaAssetsProvider(pieceId));
    }
  }

  Future<void> syncMediaForPiece(String pieceId) async {
    await repo.syncDeltaForPiece(pieceId, db);
    ref.invalidate(mediaAssetsProvider(pieceId));
  }

  Future<void> triggerRetroactiveSync() async {
    final success = await repo.triggerRetroactiveSync();
    if (success) {
      ref.invalidate(allPiecesProvider);
    }
  }

  Future<void> triggerBatchRetroactiveSearch() async {
    final pieces = ref.read(allPiecesProvider).valueOrNull ?? const [];
    for (final entry in pieces) {
      final piece = entry.piece;
      if (piece.serverPieceId != null) {
        final existingAssets = await db.loadMediaAssetsForPiece(piece.id);
        if (existingAssets.isEmpty) {
          await repo.triggerSearch(piece.serverPieceId!);
        }
      }
    }
  }
}
