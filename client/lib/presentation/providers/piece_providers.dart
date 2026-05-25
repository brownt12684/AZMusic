import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/local_library_repository.dart';
import '../../domain/entities/library_entry.dart';
import '../../domain/entities/piece.dart';
import '../../domain/entities/review_candidate_package.dart';
import '../../domain/entities/score_version.dart';
import '../../injection/container.dart';
import 'app_providers.dart';
import 'profile_providers.dart';
import 'review_providers.dart';

final libraryRepositoryProvider = Provider<LocalLibraryRepository>(
  (ref) {
    final repository = LocalLibraryRepository(
      appDirectory: ref.watch(appDirectoryProvider),
    );
    ref.onDispose(() {
      unawaited(repository.close());
    });
    return repository;
  },
);

final allPiecesProvider =
    AsyncNotifierProvider<PieceListNotifier, List<LibraryEntry>>(
  PieceListNotifier.new,
);

final parentSyncedPiecesProvider =
    FutureProvider<List<RemotePieceSummary>>((ref) {
  return ref.read(serverPieceSyncRepositoryProvider).fetchAllPieces();
});

class PieceListNotifier extends AsyncNotifier<List<LibraryEntry>> {
  LocalLibraryRepository? _repository;
  Future<List<LibraryEntry>>? _activeLoad;

  @override
  Future<List<LibraryEntry>> build() async {
    return _loadPieces(trigger: SyncTrigger.appLaunch);
  }

  Future<void> loadPieces({
    SyncTrigger trigger = SyncTrigger.manualRefresh,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _loadPieces(trigger: trigger));
  }

  Future<LibraryEntry> importScoreFile(
    String sourcePath, {
    String? assignedProfileId,
    String? composer,
    String? primaryInstrument,
    String? bookOrCollection,
  }) async {
    var entry = await _libraryRepository.importScoreForProfile(
      sourcePath: sourcePath,
      assignedProfileId: assignedProfileId,
      composer: composer,
      primaryInstrument: primaryInstrument,
      bookOrCollection: bookOrCollection,
    );
    entry = await _markProcessingIfServerUploadable(entry);
    await _uploadEntryToServer(entry);
    await loadPieces(trigger: SyncTrigger.postImport);
    return await _libraryRepository.findEntry(entry.piece.id) ?? entry;
  }

  Future<LibraryEntry> importToIntake(
    String sourcePath, {
    String? title,
    String? composer,
    String? primaryInstrument,
    String? bookOrCollection,
  }) async {
    var entry = await _libraryRepository.importScoreToIntake(
      sourcePath: sourcePath,
      title: title,
      composer: composer,
      primaryInstrument: primaryInstrument,
      bookOrCollection: bookOrCollection,
    );
    entry = await _markProcessingIfServerUploadable(entry);
    await _uploadEntryToServer(entry);
    await loadPieces(trigger: SyncTrigger.postImport);
    return await _libraryRepository.findEntry(entry.piece.id) ?? entry;
  }

  Future<void> pushToProfile({
    required String pieceId,
    required String profileId,
  }) async {
    final entry = await _libraryRepository.findEntry(pieceId);
    if (entry == null) {
      return;
    }

    final visibleToProfileIds = {
      ...entry.piece.visibleToProfileIds,
      profileId,
    }.toList(growable: false);

    await _libraryRepository.updatePiece(
      entry.piece.copyWith(
        visibleToProfileIds: visibleToProfileIds,
        libraryStatus: LibraryStatus.ready,
        updatedAt: DateTime.now(),
      ),
    );

    final serverPieceId = entry.piece.serverPieceId;
    if (serverPieceId != null) {
      try {
        await ref
            .read(serverPieceSyncRepositoryProvider)
            .pushPieceToProfiles(serverPieceId, [profileId]);
      } catch (_) {
        // Keep the local assignment and retry on the next sync.
      }
    }
    await loadPieces(trigger: SyncTrigger.parentPush);
  }

  Future<void> updateRemoteMetadata({
    required String serverPieceId,
    required String title,
    String? composer,
    String? primaryInstrument,
    String? bookOrCollection,
    String? keySignature,
    String? tempo,
    String? notes,
    List<String> aliases = const <String>[],
    int? sourcePageStart,
    int? sourcePageEnd,
  }) async {
    final remotePiece =
        await ref.read(serverPieceSyncRepositoryProvider).updatePieceMetadata(
              serverPieceId,
              title: title,
              composer: composer,
              primaryInstrument: primaryInstrument,
              bookOrCollection: bookOrCollection,
              keySignature: keySignature,
              tempo: tempo,
              notes: notes,
              aliases: aliases,
              sourcePageStart: sourcePageStart,
              sourcePageEnd: sourcePageEnd,
            );
    await _mergeRemoteSummaryIntoLocalEntries(remotePiece);
    ref.invalidate(parentSyncedPiecesProvider);
    await loadPieces(trigger: SyncTrigger.manualRefresh);
  }

  Future<void> clearLibrary() async {
    await _libraryRepository.clearLibrary();
    state = const AsyncValue.data(<LibraryEntry>[]);
  }

  LocalLibraryRepository get _libraryRepository {
    final repository = _repository;
    if (repository != null) {
      return repository;
    }
    final created = ref.read(libraryRepositoryProvider);
    _repository = created;
    return created;
  }

  Future<List<LibraryEntry>> _loadPieces({
    required SyncTrigger trigger,
  }) async {
    final activeLoad = _activeLoad;
    if (activeLoad != null) {
      return activeLoad;
    }

    final loadFuture = _performLoad(trigger: trigger);
    _activeLoad = loadFuture;
    try {
      return await loadFuture;
    } finally {
      if (identical(_activeLoad, loadFuture)) {
        _activeLoad = null;
      }
    }
  }

  Future<List<LibraryEntry>> _performLoad({
    required SyncTrigger trigger,
  }) async {
    _repository = ref.read(libraryRepositoryProvider);
    final selectedStudent = ref.read(activeStudentProfileProvider);
    var entries = await _libraryRepository.loadLibrary();
    entries = await _normalizePendingUploadEntries(entries);

    final networkInfo = ref.read(networkInfoProvider);
    if (!await networkInfo.isConnected) {
      _setSyncBanner(LibrarySyncBannerState.offlineReady());
      return entries;
    }

    _setSyncBanner(LibrarySyncBannerState.syncing(trigger: trigger));
    final syncResult = await _syncEntries(entries, selectedStudent?.id);
    if (syncResult.hadRecoverableFailure) {
      final latestNetworkStatus = await networkInfo.isConnected;
      _setSyncBanner(
        latestNetworkStatus
            ? LibrarySyncBannerState.failedUsable()
            : LibrarySyncBannerState.offlineReady(),
      );
    } else {
      _setSyncBanner(LibrarySyncBannerState.synced(trigger: trigger));
    }

    return syncResult.entries;
  }

  void _setSyncBanner(LibrarySyncBannerState bannerState) {
    ref.read(librarySyncBannerProvider.notifier).state = bannerState;
  }

  Future<List<LibraryEntry>> _normalizePendingUploadEntries(
    List<LibraryEntry> entries,
  ) async {
    var changed = false;
    for (final entry in entries) {
      if (entry.piece.serverPieceId != null ||
          entry.piece.libraryStatus != LibraryStatus.processing) {
        continue;
      }
      await _libraryRepository.updatePiece(
        entry.piece.copyWith(
          libraryStatus: LibraryStatus.uploadPending,
          updatedAt: DateTime.now(),
        ),
      );
      changed = true;
    }

    if (!changed) {
      return entries;
    }
    return _libraryRepository.loadLibrary();
  }

  Future<_PieceSyncResult> _syncEntries(
    List<LibraryEntry> entries,
    String? activeStudentProfileId,
  ) async {
    final syncRepository = ref.read(serverPieceSyncRepositoryProvider);
    var hadRecoverableFailure = false;

    for (final entry in entries) {
      final boundEntry = await _bindPendingUpload(entry);
      final serverPieceId = boundEntry.piece.serverPieceId;
      if (serverPieceId == null) {
        continue;
      }

      try {
        final remotePiece =
            await syncRepository.fetchPieceDetail(serverPieceId);
        await _mergeRemotePiece(boundEntry, remotePiece);
      } catch (_) {
        hadRecoverableFailure = true;
      }
    }

    if (activeStudentProfileId != null) {
      try {
        final assignedPieces = await syncRepository.fetchAssignedPieces(
          activeStudentProfileId,
        );
        for (final assignedPiece in assignedPieces) {
          final remotePiece = await syncRepository.fetchPieceDetail(
            assignedPiece.id,
          );
          final localEntry = await _libraryRepository.findEntryByServerPieceId(
            assignedPiece.id,
          );
          if (localEntry == null) {
            await _createLocalEntryFromRemotePiece(
              remotePiece,
              activeStudentProfileId,
            );
          } else {
            await _mergeRemotePiece(localEntry, remotePiece);
          }
        }
      } catch (_) {
        hadRecoverableFailure = true;
      }
    }

    return _PieceSyncResult(
      entries: await _libraryRepository.loadLibrary(),
      hadRecoverableFailure: hadRecoverableFailure,
    );
  }

  Future<void> _mergeRemotePiece(
    LibraryEntry localEntry,
    RemotePieceDetail remotePiece,
  ) async {
    final mergedVisibleToProfileIds = {
      ...localEntry.piece.visibleToProfileIds,
      ...remotePiece.visibleToProfileIds,
    }.toList(growable: false);
    await _libraryRepository.updatePiece(
      localEntry.piece.copyWith(
        title: remotePiece.title,
        composer: remotePiece.composer,
        primaryInstrument: remotePiece.primaryInstrument,
        bookOrCollection: remotePiece.bookOrCollection,
        keySignature: remotePiece.keySignature,
        tempo: remotePiece.tempo,
        difficulty: remotePiece.difficultyLevel,
        notes: remotePiece.notes ??
            _metadataString(remotePiece.catalogMetadata['notes']) ??
            localEntry.piece.notes,
        processedMetadata: remotePiece.processedMetadata.isEmpty
            ? localEntry.piece.processedMetadata
            : remotePiece.processedMetadata,
        pieceKind: remotePiece.pieceKind,
        sourceBookId: remotePiece.sourceBookId,
        sourcePageStart: remotePiece.sourcePageStart,
        sourcePageEnd: remotePiece.sourcePageEnd,
        catalogMetadata: remotePiece.catalogMetadata.isEmpty
            ? localEntry.piece.catalogMetadata
            : remotePiece.catalogMetadata,
        catalogSuggestions: remotePiece.catalogSuggestions.isEmpty
            ? localEntry.piece.catalogSuggestions
            : remotePiece.catalogSuggestions,
        validationWarnings: remotePiece.validationWarnings.isEmpty
            ? localEntry.piece.validationWarnings
            : remotePiece.validationWarnings,
        splitConfidence: remotePiece.splitConfidence,
        clearComposer: remotePiece.composer == null,
        clearPrimaryInstrument: remotePiece.primaryInstrument == null,
        clearBookOrCollection: remotePiece.bookOrCollection == null,
        clearKeySignature: remotePiece.keySignature == null,
        clearTempo: remotePiece.tempo == null,
        clearNotes: remotePiece.notes == null &&
            remotePiece.catalogMetadata['notes'] == null,
        clearSourceBookId: remotePiece.sourceBookId == null,
        clearSourcePageStart: remotePiece.sourcePageStart == null,
        clearSourcePageEnd: remotePiece.sourcePageEnd == null,
        clearSplitConfidence: remotePiece.splitConfidence == null,
        visibleToProfileIds: mergedVisibleToProfileIds,
        libraryStatus: _libraryStatusFromRemote(remotePiece.libraryStatus),
        updatedAt: DateTime.now(),
      ),
    );

    final approvedArtifacts = _approvedArtifactsFor(remotePiece);
    if (approvedArtifacts.isEmpty) {
      return;
    }

    final existingRemoteUrls = localEntry.scoreVersions
        .map((version) => version.remoteUrl)
        .whereType<String>()
        .where((remoteUrl) => remoteUrl.isNotEmpty)
        .toSet();
    final syncRepository = ref.read(serverPieceSyncRepositoryProvider);
    for (final artifact in approvedArtifacts) {
      if (artifact.version.fileUrl.isEmpty ||
          existingRemoteUrls.contains(artifact.version.fileUrl)) {
        continue;
      }

      final bytes =
          await syncRepository.downloadBytes(artifact.version.fileUrl);
      await _libraryRepository.importServerScoreVersion(
        localPieceId: localEntry.piece.id,
        bytes: bytes,
        fileExtension: artifact.version.fileExtension,
        title: artifact.title,
        format: artifact.version.format,
        remoteUrl: artifact.version.fileUrl,
        versionType: artifact.version.versionType,
        makePrimary: artifact.makePrimary,
        isStudentVisible: artifact.isStudentVisible,
        hideExistingStudentVisible: artifact.hideExistingStudentVisible,
      );
      existingRemoteUrls.add(artifact.version.fileUrl);
    }
  }

  Future<void> _mergeRemoteSummaryIntoLocalEntries(
    RemotePieceSummary remotePiece,
  ) async {
    final entries = await _libraryRepository.loadLibrary();
    for (final entry in entries) {
      if (entry.piece.serverPieceId != remotePiece.id) {
        continue;
      }
      await _libraryRepository.updatePiece(
        entry.piece.copyWith(
          title: remotePiece.title,
          composer: remotePiece.composer,
          primaryInstrument: remotePiece.primaryInstrument,
          bookOrCollection: remotePiece.bookOrCollection,
          keySignature: remotePiece.keySignature,
          tempo: remotePiece.tempo,
          difficulty: remotePiece.difficultyLevel,
          notes: remotePiece.notes ??
              _metadataString(remotePiece.catalogMetadata['notes']),
          processedMetadata: remotePiece.processedMetadata.isEmpty
              ? entry.piece.processedMetadata
              : remotePiece.processedMetadata,
          pieceKind: remotePiece.pieceKind,
          sourceBookId: remotePiece.sourceBookId,
          sourcePageStart: remotePiece.sourcePageStart,
          sourcePageEnd: remotePiece.sourcePageEnd,
          catalogMetadata: remotePiece.catalogMetadata,
          catalogSuggestions: remotePiece.catalogSuggestions,
          validationWarnings: remotePiece.validationWarnings,
          splitConfidence: remotePiece.splitConfidence,
          clearComposer: remotePiece.composer == null,
          clearPrimaryInstrument: remotePiece.primaryInstrument == null,
          clearBookOrCollection: remotePiece.bookOrCollection == null,
          clearKeySignature: remotePiece.keySignature == null,
          clearTempo: remotePiece.tempo == null,
          clearNotes: remotePiece.notes == null &&
              remotePiece.catalogMetadata['notes'] == null,
          clearSourceBookId: remotePiece.sourceBookId == null,
          clearSourcePageStart: remotePiece.sourcePageStart == null,
          clearSourcePageEnd: remotePiece.sourcePageEnd == null,
          clearSplitConfidence: remotePiece.splitConfidence == null,
          visibleToProfileIds: remotePiece.visibleToProfileIds.isEmpty
              ? entry.piece.visibleToProfileIds
              : remotePiece.visibleToProfileIds,
          libraryStatus: _libraryStatusFromRemote(remotePiece.libraryStatus),
          updatedAt: DateTime.now(),
        ),
      );
    }
  }

  Future<void> _createLocalEntryFromRemotePiece(
    RemotePieceDetail remotePiece,
    String profileId,
  ) async {
    final approvedArtifacts = _approvedArtifactsFor(remotePiece);
    final primaryArtifact = approvedArtifacts.firstWhereOrNull(
      (artifact) => artifact.makePrimary,
    );
    if (primaryArtifact == null || primaryArtifact.version.fileUrl.isEmpty) {
      return;
    }

    final syncRepository = ref.read(serverPieceSyncRepositoryProvider);
    final download =
        await syncRepository.downloadBytes(primaryArtifact.version.fileUrl);

    final createdEntry = await _libraryRepository.createServerLinkedEntry(
      serverPieceId: remotePiece.id,
      title: remotePiece.title,
      composer: remotePiece.composer,
      visibleToProfileIds: remotePiece.visibleToProfileIds.isEmpty
          ? <String>[profileId]
          : remotePiece.visibleToProfileIds,
      primaryInstrument: remotePiece.primaryInstrument,
      bookOrCollection: remotePiece.bookOrCollection,
      keySignature: remotePiece.keySignature,
      tempo: remotePiece.tempo,
      difficulty: remotePiece.difficultyLevel,
      notes: remotePiece.notes ??
          _metadataString(remotePiece.catalogMetadata['notes']),
      processedMetadata: remotePiece.processedMetadata,
      pieceKind: remotePiece.pieceKind,
      sourceBookId: remotePiece.sourceBookId,
      sourcePageStart: remotePiece.sourcePageStart,
      sourcePageEnd: remotePiece.sourcePageEnd,
      catalogMetadata: remotePiece.catalogMetadata,
      catalogSuggestions: remotePiece.catalogSuggestions,
      validationWarnings: remotePiece.validationWarnings,
      splitConfidence: remotePiece.splitConfidence,
      libraryStatus: _libraryStatusFromRemote(remotePiece.libraryStatus),
      bytes: download,
      fileExtension: primaryArtifact.version.fileExtension,
      scoreTitle: primaryArtifact.title,
      format: primaryArtifact.version.format,
      remoteUrl: primaryArtifact.version.fileUrl,
      versionType: primaryArtifact.version.versionType,
      isPrimary: true,
      isStudentVisible: primaryArtifact.isStudentVisible,
    );

    for (final artifact in approvedArtifacts.skip(1)) {
      if (artifact.version.fileUrl.isEmpty) {
        continue;
      }
      final bytes =
          await syncRepository.downloadBytes(artifact.version.fileUrl);
      await _libraryRepository.importServerScoreVersion(
        localPieceId: createdEntry.piece.id,
        bytes: bytes,
        fileExtension: artifact.version.fileExtension,
        title: artifact.title,
        format: artifact.version.format,
        remoteUrl: artifact.version.fileUrl,
        versionType: artifact.version.versionType,
        makePrimary: artifact.makePrimary,
        isStudentVisible: artifact.isStudentVisible,
        hideExistingStudentVisible: artifact.hideExistingStudentVisible,
      );
    }
  }

  List<_RemoteArtifactImport> _approvedArtifactsFor(
      RemotePieceDetail remotePiece) {
    final approvedVersions = remotePiece.scoreVersions
        .where((version) => version.versionType == 'approved')
        .toList(growable: false);
    if (approvedVersions.isEmpty) {
      return const <_RemoteArtifactImport>[];
    }

    final imports = <_RemoteArtifactImport>[];
    final approvedReaderVersion = approvedVersions.firstWhereOrNull(
      (version) => version.format == 'pdf' || version.format == 'image',
    );
    if (approvedReaderVersion != null) {
      imports.add(
        _RemoteArtifactImport(
          version: approvedReaderVersion,
          title: _titleForRemoteVersion(approvedReaderVersion),
          makePrimary: true,
          isStudentVisible: true,
          hideExistingStudentVisible: true,
        ),
      );
    }

    final approvedMusicXml = approvedVersions.firstWhereOrNull(
      (version) => version.format == 'musicxml',
    );
    if (approvedMusicXml != null) {
      imports.add(
        _RemoteArtifactImport(
          version: approvedMusicXml,
          title: _titleForRemoteVersion(approvedMusicXml),
          makePrimary: false,
          isStudentVisible: false,
          hideExistingStudentVisible: false,
        ),
      );
    }

    return imports;
  }

  String _titleForRemoteVersion(RemoteScoreVersion version) {
    if (version.versionType == 'approved' && version.format == 'musicxml') {
      return 'Approved MusicXML';
    }
    switch (version.versionType) {
      case 'approved':
        return 'Approved processed score';
      case 'reconstructed_candidate':
        return 'Processed score candidate';
      default:
        return 'Server score';
    }
  }

  LibraryStatus _libraryStatusFromRemote(String libraryStatus) {
    return LibraryStatus.values.firstWhere(
      (status) => status.name == libraryStatus,
      orElse: () => LibraryStatus.intake,
    );
  }

  Future<LibraryEntry> _bindPendingUpload(LibraryEntry entry) async {
    if (entry.piece.serverPieceId != null) {
      return entry;
    }

    final serverPieceId = await _uploadEntryToServer(entry);
    if (serverPieceId == null) {
      return entry;
    }

    return await _libraryRepository.findEntry(entry.piece.id) ?? entry;
  }

  Future<String?> _uploadEntryToServer(LibraryEntry entry) async {
    try {
      final serverPieceId = await ref
          .read(serverPieceSyncRepositoryProvider)
          .uploadImportedPiece(entry);
      if (serverPieceId == null) {
        return null;
      }
      await _libraryRepository.bindServerPieceId(
        localPieceId: entry.piece.id,
        serverPieceId: serverPieceId,
        libraryStatus: LibraryStatus.processing,
      );
      return serverPieceId;
    } catch (_) {
      // Local import remains the source of truth when the server is unavailable.
      if (entry.piece.libraryStatus != LibraryStatus.uploadPending) {
        await _libraryRepository.updatePiece(
          entry.piece.copyWith(
            libraryStatus: LibraryStatus.uploadPending,
            updatedAt: DateTime.now(),
          ),
        );
      }
      return null;
    }
  }

  Future<LibraryEntry> _markProcessingIfServerUploadable(
    LibraryEntry entry,
  ) async {
    final rawScore = entry.scoreVersions.firstWhere(
      (scoreVersion) => scoreVersion.versionType == 'raw',
      orElse: () => entry.primaryScore,
    );
    final rawFormat = rawScore.format.toLowerCase();
    if (rawFormat != 'pdf' && rawFormat != 'image') {
      state = AsyncValue.data(await _libraryRepository.loadLibrary());
      return entry;
    }

    final updatedEntry = LibraryEntry(
      piece: entry.piece.copyWith(
        libraryStatus: LibraryStatus.processing,
        updatedAt: DateTime.now(),
      ),
      scoreVersions: entry.scoreVersions,
    );
    await _libraryRepository.saveEntry(updatedEntry);
    state = AsyncValue.data(await _libraryRepository.loadLibrary());
    return updatedEntry;
  }
}

class _PieceSyncResult {
  const _PieceSyncResult({
    required this.entries,
    required this.hadRecoverableFailure,
  });

  final List<LibraryEntry> entries;
  final bool hadRecoverableFailure;
}

final studentLibraryEntriesProvider = Provider<List<LibraryEntry>>((ref) {
  final studentProfile = ref.watch(activeStudentProfileProvider);
  final entries =
      ref.watch(allPiecesProvider).valueOrNull ?? const <LibraryEntry>[];
  if (studentProfile == null) {
    return const <LibraryEntry>[];
  }
  return entries
      .where(
        (entry) =>
            entry.piece.isVisibleToProfile(studentProfile.id) &&
            entry.piece.libraryStatus != LibraryStatus.intake &&
            entry.piece.libraryStatus != LibraryStatus.archived,
      )
      .toList(growable: false);
});

class _RemoteArtifactImport {
  const _RemoteArtifactImport({
    required this.version,
    required this.title,
    required this.makePrimary,
    required this.isStudentVisible,
    required this.hideExistingStudentVisible,
  });

  final RemoteScoreVersion version;
  final String title;
  final bool makePrimary;
  final bool isStudentVisible;
  final bool hideExistingStudentVisible;
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

final parentIntakeEntriesProvider = Provider<List<LibraryEntry>>((ref) {
  final entries =
      ref.watch(allPiecesProvider).valueOrNull ?? const <LibraryEntry>[];
  return entries.where((entry) {
    if (entry.piece.libraryStatus == LibraryStatus.archived) {
      return false;
    }
    return entry.piece.libraryStatus != LibraryStatus.ready ||
        entry.piece.visibleToProfileIds.isEmpty;
  }).toList(growable: false);
});

final pieceEntryProvider =
    Provider.family<LibraryEntry?, String>((ref, pieceId) {
  final entries =
      ref.watch(allPiecesProvider).valueOrNull ?? const <LibraryEntry>[];
  return entries.firstWhereOrNull((entry) => entry.piece.id == pieceId);
});

final scoreVersionForPieceProvider =
    Provider.family<ScoreVersion?, ({String pieceId, String? scoreVersionId})>((
  ref,
  request,
) {
  final entry = ref.watch(pieceEntryProvider(request.pieceId));
  if (entry == null) {
    return null;
  }

  if (request.scoreVersionId == null) {
    return entry.primaryScore;
  }

  return entry.scoreVersions.firstWhereOrNull(
    (version) => version.id == request.scoreVersionId,
  );
});
