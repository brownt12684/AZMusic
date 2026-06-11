import 'dart:async';
import 'dart:io';

import 'package:azmusic/app/launch_options.dart';
import 'package:azmusic/core/config/app_config.dart';
import 'package:azmusic/core/network/network_info.dart';
import 'package:azmusic/data/repositories/server_piece_sync_repository.dart';
import 'package:azmusic/domain/entities/library_entry.dart';
import 'package:azmusic/domain/entities/piece.dart';
import 'package:azmusic/domain/entities/processing_settings.dart';
import 'package:azmusic/domain/entities/review_candidate_package.dart';
import 'package:azmusic/domain/entities/server_job.dart';
import 'package:azmusic/injection/container.dart';
import 'package:azmusic/presentation/providers/app_providers.dart';
import 'package:azmusic/presentation/providers/debug_tools_providers.dart';
import 'package:azmusic/presentation/providers/piece_providers.dart';
import 'package:azmusic/presentation/providers/review_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues(const <String, Object>{
      'server_host': 'test-server',
      'server_port': 8795,
      'server_id': 'test-server',
      'server_pairing_token': 'test-token',
    });
    await AppConfig.initialize();
    tempDir =
        Directory.systemTemp.createTempSync('azmusic_piece_provider_test_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<File> createSamplePdfFile({String name = 'provider_score.pdf'}) async {
    final file = File('${tempDir.path}${Platform.pathSeparator}$name');
    await file.writeAsBytes(const <int>[37, 80, 68, 70], flush: true);
    return file;
  }

  test('loadPieces reports offline-ready when the network is unavailable',
      () async {
    final container = _containerFor(
      tempDir,
      networkInfo: const _StaticNetworkInfo(false),
      syncRepository: _NoopSyncRepository(),
    );
    addTearDown(container.dispose);

    await container
        .read(allPiecesProvider.notifier)
        .loadPieces(trigger: SyncTrigger.manualRefresh);

    expect(container.read(connectionStatusProvider), 'offline-ready');
    expect(container.read(syncStatusProvider), isFalse);
  });

  test('loadPieces waits for server pairing before upload retry', () async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    await AppConfig.initialize();
    final syncRepository = _TrackingUploadSyncRepository();
    final container = _containerFor(
      tempDir,
      networkInfo: const _StaticNetworkInfo(true),
      syncRepository: syncRepository,
    );
    addTearDown(container.dispose);

    final repository = container.read(libraryRepositoryProvider);
    final sourceFile = await createSamplePdfFile();
    final entry = await repository.importScoreForProfile(
      sourcePath: sourceFile.path,
      assignedProfileId: 'student-alyse',
    );

    await container
        .read(allPiecesProvider.notifier)
        .loadPieces(trigger: SyncTrigger.connectivityReturn);

    final pendingEntry = await repository.findEntry(entry.piece.id);
    expect(pendingEntry, isNotNull);
    expect(pendingEntry!.piece.libraryStatus, LibraryStatus.uploadPending);
    expect(syncRepository.uploadCalls, 0);
    expect(container.read(connectionStatusProvider), 'failed-usable');
    expect(
      container.read(librarySyncBannerProvider).message,
      contains('Waiting for server pairing'),
    );
  });

  test(
      'loadPieces enters syncing and settles on synced when remote calls finish',
      () async {
    final gate = Completer<void>();
    final container = _containerFor(
      tempDir,
      networkInfo: const _StaticNetworkInfo(true),
      syncRepository: _DelayedSyncRepository(gate),
    );
    addTearDown(container.dispose);
    final seenStatuses = <LibrarySyncStatus>[];
    final subscription = container.listen<LibrarySyncBannerState>(
      librarySyncBannerProvider,
      (_, next) => seenStatuses.add(next.status),
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    final future = container
        .read(allPiecesProvider.notifier)
        .loadPieces(trigger: SyncTrigger.manualRefresh);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    gate.complete();
    await future;

    expect(seenStatuses, contains(LibrarySyncStatus.syncing));
    expect(container.read(connectionStatusProvider), 'synced');
    expect(container.read(syncStatusProvider), isFalse);
  });

  test(
      'loadPieces reports failed-but-usable when remote sync throws while online',
      () async {
    final container = _containerFor(
      tempDir,
      networkInfo: const _StaticNetworkInfo(true),
      syncRepository: _FailingSyncRepository(),
    );
    addTearDown(container.dispose);

    await container
        .read(allPiecesProvider.notifier)
        .loadPieces(trigger: SyncTrigger.manualRefresh);

    expect(container.read(connectionStatusProvider), 'failed-usable');
  });

  test('loadPieces retries pending uploads and binds the remote server id',
      () async {
    final container = _containerFor(
      tempDir,
      networkInfo: const _StaticNetworkInfo(true),
      syncRepository: _UploadBindingSyncRepository(),
    );
    addTearDown(container.dispose);

    final repository = container.read(libraryRepositoryProvider);
    final sourceFile = await createSamplePdfFile();
    final entry = await repository.importScore(sourcePath: sourceFile.path);

    await container
        .read(allPiecesProvider.notifier)
        .loadPieces(trigger: SyncTrigger.connectivityReturn);

    final reboundEntry = await repository.findEntry(entry.piece.id);
    expect(reboundEntry, isNotNull);
    expect(reboundEntry!.piece.serverPieceId, 'remote-${entry.piece.id}');
    expect(container.read(connectionStatusProvider), 'synced');
  });

  test('parent can retry a stale local upload', () async {
    final container = _containerFor(
      tempDir,
      networkInfo: const _StaticNetworkInfo(true),
      syncRepository: _UploadBindingSyncRepository(),
    );
    addTearDown(container.dispose);

    final repository = container.read(libraryRepositoryProvider);
    final sourceFile = await createSamplePdfFile(name: 'retry_stale.pdf');
    final entry = await repository.importScore(sourcePath: sourceFile.path);
    await repository.updatePiece(
      entry.piece.copyWith(libraryStatus: LibraryStatus.uploadPending),
    );

    await container
        .read(allPiecesProvider.notifier)
        .retryLocalUpload(entry.piece.id);

    final reboundEntry = await repository.findEntry(entry.piece.id);
    expect(reboundEntry, isNotNull);
    expect(reboundEntry!.piece.serverPieceId, 'remote-${entry.piece.id}');
    expect(reboundEntry.piece.libraryStatus, LibraryStatus.intake);
  });

  test('parent can reupload a local item whose server record is missing',
      () async {
    final container = _containerFor(
      tempDir,
      networkInfo: const _StaticNetworkInfo(true),
      syncRepository: _UploadBindingSyncRepository(),
    );
    addTearDown(container.dispose);

    final repository = container.read(libraryRepositoryProvider);
    final sourceFile = await createSamplePdfFile(name: 'server_missing.pdf');
    final entry = await repository.importScore(sourcePath: sourceFile.path);
    await repository.updatePiece(
      entry.piece.copyWith(
        serverPieceId: 'missing-server-piece',
        libraryStatus: LibraryStatus.uploadPending,
      ),
    );

    await container.read(allPiecesProvider.notifier).retryLocalUpload(
          entry.piece.id,
          reuploadAsNew: true,
        );

    final reboundEntry = await repository.findEntry(entry.piece.id);
    expect(reboundEntry, isNotNull);
    expect(reboundEntry!.piece.serverPieceId, 'remote-${entry.piece.id}');
  });

  test('parent can remove a stale local import', () async {
    final container = _containerFor(
      tempDir,
      networkInfo: const _StaticNetworkInfo(false),
      syncRepository: _NoopSyncRepository(),
    );
    addTearDown(container.dispose);

    final repository = container.read(libraryRepositoryProvider);
    final sourceFile = await createSamplePdfFile(name: 'remove_stale.pdf');
    final entry = await repository.importScore(sourcePath: sourceFile.path);

    await container
        .read(allPiecesProvider.notifier)
        .removeLocalEntry(entry.piece.id);

    expect(await repository.findEntry(entry.piece.id), isNull);
    expect(container.read(allPiecesProvider).valueOrNull, isEmpty);
  });

  test('duplicate import of the same file is blocked while upload is active',
      () async {
    final gate = Completer<void>();
    final container = _containerFor(
      tempDir,
      networkInfo: const _StaticNetworkInfo(true),
      syncRepository: _GatedUploadSyncRepository(gate),
    );
    addTearDown(container.dispose);

    final sourceFile = await createSamplePdfFile(name: 'duplicate_guard.pdf');
    final notifier = container.read(allPiecesProvider.notifier);
    final firstImport = notifier.importToIntake(sourceFile.path);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    await expectLater(
      notifier.importToIntake(sourceFile.path),
      throwsA(isA<StateError>()),
    );

    gate.complete();
    await firstImport;
  });

  test('background refresh does not duplicate an upload already in flight',
      () async {
    final gate = Completer<void>();
    final syncRepository = _GatedUploadSyncRepository(gate);
    final container = _containerFor(
      tempDir,
      networkInfo: const _StaticNetworkInfo(true),
      syncRepository: syncRepository,
    );
    addTearDown(container.dispose);

    await container.read(allPiecesProvider.future);
    final sourceFile =
        await createSamplePdfFile(name: 'refresh_duplicate_guard.pdf');
    final notifier = container.read(allPiecesProvider.notifier);
    final importFuture = notifier.importToIntake(sourceFile.path);

    for (var attempt = 0; attempt < 20; attempt += 1) {
      if (syncRepository.uploadCalls == 1) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(syncRepository.uploadCalls, 1);

    await notifier.loadPieces(trigger: SyncTrigger.manualRefresh);
    expect(syncRepository.uploadCalls, 1);

    gate.complete();
    await importFuture;
    expect(syncRepository.uploadCalls, 1);
  });

  test('parent intake excludes archived pieces after review rejection',
      () async {
    final container = _containerFor(
      tempDir,
      networkInfo: const _StaticNetworkInfo(false),
      syncRepository: _NoopSyncRepository(),
    );
    addTearDown(container.dispose);

    final repository = container.read(libraryRepositoryProvider);
    final sourceFile = await createSamplePdfFile(name: 'rejected_score.pdf');
    final entry = await repository.importScore(sourcePath: sourceFile.path);
    await repository.updatePiece(
      entry.piece.copyWith(libraryStatus: LibraryStatus.archived),
    );

    await container
        .read(allPiecesProvider.notifier)
        .loadPieces(trigger: SyncTrigger.manualRefresh);

    expect(container.read(parentIntakeEntriesProvider), isEmpty);
  });

  test('parent workflow keeps pushed ready items until they are closed',
      () async {
    final container = _containerFor(
      tempDir,
      networkInfo: const _StaticNetworkInfo(false),
      syncRepository: _NoopSyncRepository(),
    );
    addTearDown(container.dispose);

    final repository = container.read(libraryRepositoryProvider);
    final sourceFile = await createSamplePdfFile(name: 'pushed_score.pdf');
    final entry = await repository.importScore(sourcePath: sourceFile.path);

    await repository.updatePiece(
      entry.piece.copyWith(
        serverPieceId: 'remote-pushed-piece',
        visibleToProfileIds: const ['student-alyse'],
        libraryStatus: LibraryStatus.ready,
      ),
    );
    await container
        .read(allPiecesProvider.notifier)
        .loadPieces(trigger: SyncTrigger.manualRefresh);

    expect(container.read(parentIntakeEntriesProvider), hasLength(1));

    final readyEntry = container.read(parentIntakeEntriesProvider).single;
    await repository.updatePiece(
      readyEntry.piece.copyWith(
        workflowClosed: true,
        updatedAt: DateTime.now(),
      ),
    );
    await container
        .read(allPiecesProvider.notifier)
        .loadPieces(trigger: SyncTrigger.manualRefresh);

    expect(container.read(parentIntakeEntriesProvider), isEmpty);
  });

  test('parent workflow hides backend processing items behind tracker',
      () async {
    final container = _containerFor(
      tempDir,
      networkInfo: const _StaticNetworkInfo(false),
      syncRepository: _NoopSyncRepository(),
    );
    addTearDown(container.dispose);

    final repository = container.read(libraryRepositoryProvider);
    final sourceFile = await createSamplePdfFile(name: 'processing_score.pdf');
    final entry = await repository.importScore(sourcePath: sourceFile.path);
    await repository.updatePiece(
      entry.piece.copyWith(
        serverPieceId: 'remote-processing-piece',
        libraryStatus: LibraryStatus.processing,
      ),
    );

    await container
        .read(allPiecesProvider.notifier)
        .loadPieces(trigger: SyncTrigger.manualRefresh);

    expect(container.read(parentIntakeEntriesProvider), isEmpty);
  });

  test('pdf imports show processing while upload is still in flight', () async {
    final gate = Completer<void>();
    final container = _containerFor(
      tempDir,
      networkInfo: const _StaticNetworkInfo(true),
      syncRepository: _GatedUploadSyncRepository(gate),
    );
    addTearDown(container.dispose);

    await container.read(allPiecesProvider.future);
    final sourceFile =
        File('${tempDir.path}${Platform.pathSeparator}study.pdf');
    await sourceFile.writeAsBytes(const <int>[37, 80, 68, 70], flush: true);

    final importFuture = container
        .read(allPiecesProvider.notifier)
        .importToIntake(sourceFile.path);

    try {
      List<LibraryEntry>? entriesDuringUpload;
      for (var attempt = 0; attempt < 20; attempt += 1) {
        entriesDuringUpload = container.read(allPiecesProvider).valueOrNull;
        if (entriesDuringUpload?.isNotEmpty ?? false) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      expect(entriesDuringUpload, isNotNull);
      expect(entriesDuringUpload, hasLength(1));
      expect(entriesDuringUpload!.single.piece.libraryStatus,
          LibraryStatus.processing);
    } finally {
      if (!gate.isCompleted) {
        gate.complete();
      }
    }

    await importFuture;
  });

  test('parent metadata edits update synced local entries', () async {
    final container = _containerFor(
      tempDir,
      networkInfo: const _StaticNetworkInfo(true),
      syncRepository: _MetadataEditingSyncRepository(),
    );
    addTearDown(container.dispose);

    final repository = container.read(libraryRepositoryProvider);
    final sourceFile = await createSamplePdfFile(name: 'metadata_score.pdf');
    final entry = await repository.importScore(sourcePath: sourceFile.path);
    await repository.bindServerPieceId(
      localPieceId: entry.piece.id,
      serverPieceId: 'remote-editable-piece',
    );

    await container.read(allPiecesProvider.notifier).updateRemoteMetadata(
      serverPieceId: 'remote-editable-piece',
      title: 'Corrected Minuet',
      composer: 'J. S. Bach',
      primaryInstrument: 'Violin',
      bookOrCollection: 'Student Book',
      keySignature: 'G major',
      tempo: '92',
      notes: 'Parent corrected metadata.',
      aliases: const ['Minuet 1'],
    );

    final updatedEntry = await repository.findEntry(entry.piece.id);
    expect(updatedEntry, isNotNull);
    expect(updatedEntry!.piece.title, 'Corrected Minuet');
    expect(updatedEntry.piece.composer, 'J. S. Bach');
    expect(updatedEntry.piece.bookOrCollection, 'Student Book');
    expect(updatedEntry.piece.notes, 'Parent corrected metadata.');
    expect(updatedEntry.piece.catalogMetadata['aliases'], ['Minuet 1']);
  });

  test('parent review queue removes resolved items immediately', () async {
    final repository = _QueueSyncRepository([
      _reviewItem('review-1', pieceId: 'piece-1', title: 'First review'),
      _reviewItem('review-2', pieceId: 'piece-2', title: 'Second review'),
    ]);
    final container = _containerFor(
      tempDir,
      networkInfo: const _StaticNetworkInfo(true),
      syncRepository: repository,
    );
    addTearDown(container.dispose);

    final initialQueue = await container.read(parentReviewQueueProvider.future);
    expect(initialQueue.map((item) => item.id), ['review-1', 'review-2']);

    final queueNotifier = container.read(parentReviewQueueProvider.notifier);
    final nextItem = queueNotifier.nextAfterRemoving({'review-1'});
    queueNotifier.removeItems({'review-1'});

    expect(nextItem?.id, 'review-2');
    expect(
      container
          .read(parentReviewQueueProvider)
          .valueOrNull
          ?.map((item) => item.id),
      ['review-2'],
    );
    expect(repository.fetchReviewQueueCalls, 1);
  });

  test('parent synced remote pieces can be patched without reloading',
      () async {
    final repository = _RemotePieceListSyncRepository();
    final container = _containerFor(
      tempDir,
      networkInfo: const _StaticNetworkInfo(true),
      syncRepository: repository,
    );
    addTearDown(container.dispose);

    final initialPieces =
        await container.read(parentSyncedPiecesProvider.future);
    expect(initialPieces.single.title, 'Original remote title');

    container.read(parentSyncedPiecesProvider.notifier).upsert(
          const RemotePieceSummary(
            id: 'remote-ready-piece',
            title: 'Patched remote title',
            status: 'approved',
            libraryStatus: 'ready',
            visibleToProfileIds: ['student-alyse'],
          ),
        );

    final patchedPieces =
        container.read(parentSyncedPiecesProvider).valueOrNull;
    expect(patchedPieces?.single.title, 'Patched remote title');
    expect(patchedPieces?.single.visibleToProfileIds, ['student-alyse']);
    expect(repository.fetchAllPiecesCalls, 1);
  });

  test('debug clear removes local library and server workflow data', () async {
    final repository = _DebugToolsSyncRepository();
    final container = _containerFor(
      tempDir,
      networkInfo: const _StaticNetworkInfo(true),
      syncRepository: repository,
    );
    addTearDown(container.dispose);

    await container.read(allPiecesProvider.future);
    final sourceFile = await createSamplePdfFile(name: 'debug_clear.pdf');
    await container
        .read(allPiecesProvider.notifier)
        .importToIntake(sourceFile.path);
    expect(
      container.read(allPiecesProvider).valueOrNull,
      isNotEmpty,
    );

    await container
        .read(parentDebugToolsProvider.notifier)
        .clearLocalAndServerLibraries();

    expect(repository.clearServerWorkflowCalls, 1);
    expect(container.read(allPiecesProvider).valueOrNull, isEmpty);
    expect(container.read(parentDebugToolsProvider).message,
        'Cleared local and server workflow libraries.');
  });

  test('debug clear piece removes one local and server workflow item',
      () async {
    final repository = _DebugToolsSyncRepository();
    final container = _containerFor(
      tempDir,
      networkInfo: const _StaticNetworkInfo(true),
      syncRepository: repository,
    );
    addTearDown(container.dispose);

    await container.read(allPiecesProvider.future);
    final sourceFile = await createSamplePdfFile(name: 'debug_piece_clear.pdf');
    final entry = await container
        .read(allPiecesProvider.notifier)
        .importToIntake(sourceFile.path);
    final serverPieceId =
        entry.piece.serverPieceId ?? 'remote-${entry.piece.id}';
    expect(container.read(allPiecesProvider).valueOrNull, hasLength(1));

    await container.read(parentDebugToolsProvider.notifier).clearPiece(
          title: entry.piece.title,
          localPieceId: entry.piece.id,
          serverPieceId: serverPieceId,
        );

    expect(repository.clearServerPieceCalls, [serverPieceId]);
    expect(container.read(allPiecesProvider).valueOrNull, isEmpty);
    expect(container.read(parentDebugToolsProvider).message,
        'Cleared debug piece clear from the debug library workflow.');
  });

  test('debug cancel job refreshes job list and tracker', () async {
    final repository = _DebugToolsSyncRepository(
      jobs: [
        ServerJob(
          id: 'job-1',
          pieceId: 'piece-1',
          jobType: 'score_processing',
          status: 'queued',
          progress: 0,
          resultData: const {'piece_title': 'Debug Piece'},
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ],
    );
    final container = _containerFor(
      tempDir,
      networkInfo: const _StaticNetworkInfo(true),
      syncRepository: repository,
    );
    addTearDown(container.dispose);

    await container.read(parentDebugToolsProvider.notifier).setEnabled(true);
    expect(
        container.read(parentDebugToolsProvider).jobs.single.status, 'queued');

    await container.read(parentDebugToolsProvider.notifier).cancelJob('job-1');

    expect(repository.cancelJobCalls, ['job-1']);
    expect(container.read(parentDebugToolsProvider).jobs.single.status,
        'canceled');
    expect(container.read(parentDebugToolsProvider).message,
        'Canceled server job.');
  });

  test('debug retry job refreshes job list and tracker', () async {
    final repository = _DebugToolsSyncRepository(
      jobs: [
        ServerJob(
          id: 'job-1',
          pieceId: 'piece-1',
          pieceTitle: 'Landler',
          jobType: 'score_processing',
          status: 'failed',
          progress: 100,
          errorMessage: 'MuseScore Studio failed.',
          resultData: const {'retry_count': 2},
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ],
    );
    final container = _containerFor(
      tempDir,
      networkInfo: const _StaticNetworkInfo(true),
      syncRepository: repository,
    );
    addTearDown(container.dispose);

    await container.read(parentDebugToolsProvider.notifier).setEnabled(true);
    expect(
        container.read(parentDebugToolsProvider).jobs.single.status, 'failed');

    await container.read(parentDebugToolsProvider.notifier).retryJob('job-1');

    expect(repository.retryJobCalls, ['job-1']);
    final retried = container.read(parentDebugToolsProvider).jobs.single;
    expect(retried.status, 'queued');
    expect(retried.errorMessage, isNull);
    expect(retried.pieceLabel, 'Landler');
    expect(container.read(parentDebugToolsProvider).message,
        'Retried server processing job.');
  });
}

ProviderContainer _containerFor(
  Directory tempDir, {
  required NetworkInfo networkInfo,
  required ServerPieceSyncRepository syncRepository,
}) {
  return ProviderContainer(
    overrides: [
      appDirectoryProvider.overrideWith((ref) => tempDir),
      launchOptionsProvider.overrideWith(
        (ref) => const AppLaunchOptions(
          sandboxMode: false,
          resetLibraryOnLaunch: false,
          initialSurface: AppLaunchSurface.login,
        ),
      ),
      networkInfoProvider.overrideWith((ref) => networkInfo),
      serverPieceSyncRepositoryProvider.overrideWith((ref) => syncRepository),
    ],
  );
}

class _StaticNetworkInfo implements NetworkInfo {
  const _StaticNetworkInfo(this.connected);

  final bool connected;

  @override
  Future<bool> get isConnected async => connected;

  @override
  Stream<bool> get onConnectivityChanged => Stream<bool>.value(connected);
}

class _NoopSyncRepository extends ServerPieceSyncRepository {
  @override
  Future<List<RemotePieceSummary>> fetchAssignedPieces(String profileId) async {
    return const [];
  }

  @override
  Future<RemotePieceDetail> fetchPieceDetail(String serverPieceId) async {
    return const RemotePieceDetail(
      id: 'remote-piece',
      title: 'Remote piece',
      status: 'ok',
      libraryStatus: 'ready',
      visibleToProfileIds: ['student-alyse'],
      scoreVersions: [],
    );
  }
}

class _DelayedSyncRepository extends ServerPieceSyncRepository {
  _DelayedSyncRepository(this.gate);

  final Completer<void> gate;

  @override
  Future<List<RemotePieceSummary>> fetchAssignedPieces(String profileId) async {
    await gate.future;
    return const [];
  }

  @override
  Future<RemotePieceDetail> fetchPieceDetail(String serverPieceId) async {
    return const RemotePieceDetail(
      id: 'remote-piece',
      title: 'Remote piece',
      status: 'ok',
      libraryStatus: 'ready',
      visibleToProfileIds: ['student-alyse'],
      scoreVersions: [],
    );
  }
}

class _FailingSyncRepository extends ServerPieceSyncRepository {
  @override
  Future<List<RemotePieceSummary>> fetchAssignedPieces(String profileId) async {
    throw Exception('server unavailable');
  }

  @override
  Future<RemotePieceDetail> fetchPieceDetail(String serverPieceId) async {
    throw Exception('server unavailable');
  }
}

class _UploadBindingSyncRepository extends ServerPieceSyncRepository {
  @override
  Future<String?> uploadImportedPiece(LibraryEntry entry) async {
    return 'remote-${entry.piece.id}';
  }

  @override
  Future<List<RemotePieceSummary>> fetchAssignedPieces(String profileId) async {
    return const [];
  }

  @override
  Future<RemotePieceDetail> fetchPieceDetail(String serverPieceId) async {
    return RemotePieceDetail(
      id: serverPieceId,
      title: 'Synced imported score',
      status: 'ok',
      libraryStatus: 'intake',
      visibleToProfileIds: const [],
      scoreVersions: const [],
    );
  }
}

class _TrackingUploadSyncRepository extends ServerPieceSyncRepository {
  int uploadCalls = 0;

  @override
  Future<String?> uploadImportedPiece(LibraryEntry entry) async {
    uploadCalls += 1;
    return 'remote-${entry.piece.id}';
  }
}

class _GatedUploadSyncRepository extends ServerPieceSyncRepository {
  _GatedUploadSyncRepository(this.gate);

  final Completer<void> gate;
  int uploadCalls = 0;

  @override
  Future<String?> uploadImportedPiece(LibraryEntry entry) async {
    uploadCalls += 1;
    await gate.future;
    return 'remote-${entry.piece.id}';
  }

  @override
  Future<List<RemotePieceSummary>> fetchAssignedPieces(String profileId) async {
    return const [];
  }

  @override
  Future<RemotePieceDetail> fetchPieceDetail(String serverPieceId) async {
    return RemotePieceDetail(
      id: serverPieceId,
      title: 'Processing study',
      status: 'processing',
      libraryStatus: 'processing',
      visibleToProfileIds: const [],
      scoreVersions: const [],
    );
  }
}

class _MetadataEditingSyncRepository extends ServerPieceSyncRepository {
  RemotePieceSummary _summary = const RemotePieceSummary(
    id: 'remote-editable-piece',
    title: 'Editable piece',
    status: 'approved',
    libraryStatus: 'ready',
    visibleToProfileIds: [],
  );

  @override
  Future<List<RemotePieceSummary>> fetchAllPieces() async {
    return [_summary];
  }

  @override
  Future<List<RemotePieceSummary>> fetchAssignedPieces(String profileId) async {
    return const [];
  }

  @override
  Future<RemotePieceDetail> fetchPieceDetail(String serverPieceId) async {
    return RemotePieceDetail(
      id: _summary.id,
      title: _summary.title,
      composer: _summary.composer,
      primaryInstrument: _summary.primaryInstrument,
      bookOrCollection: _summary.bookOrCollection,
      keySignature: _summary.keySignature,
      tempo: _summary.tempo,
      notes: _summary.notes,
      processedMetadata: _summary.processedMetadata,
      catalogMetadata: _summary.catalogMetadata,
      catalogSuggestions: _summary.catalogSuggestions,
      validationWarnings: _summary.validationWarnings,
      status: _summary.status,
      libraryStatus: _summary.libraryStatus,
      visibleToProfileIds: _summary.visibleToProfileIds,
      scoreVersions: const [],
    );
  }

  @override
  Future<RemotePieceSummary> updatePieceMetadata(
    String serverPieceId, {
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
    _summary = RemotePieceSummary(
      id: serverPieceId,
      title: title,
      composer: composer,
      primaryInstrument: primaryInstrument,
      bookOrCollection: bookOrCollection,
      keySignature: keySignature,
      tempo: tempo,
      notes: notes,
      status: 'approved',
      libraryStatus: 'ready',
      visibleToProfileIds: const [],
      catalogMetadata: {
        'title': title,
        if (composer != null) 'composer': composer,
        if (notes != null) 'notes': notes,
        if (aliases.isNotEmpty) 'aliases': aliases,
      },
    );
    return _summary;
  }
}

ReviewQueueEntry _reviewItem(
  String id, {
  required String pieceId,
  required String title,
}) {
  return ReviewQueueEntry(
    id: id,
    pieceId: pieceId,
    itemType: 'score_candidate',
    title: title,
    description: 'Review $title',
    status: 'pending',
    createdAt: DateTime(2026),
    candidateData: const <String, dynamic>{},
  );
}

class _QueueSyncRepository extends ServerPieceSyncRepository {
  _QueueSyncRepository(this.queue);

  final List<ReviewQueueEntry> queue;
  int fetchReviewQueueCalls = 0;

  @override
  Future<List<ReviewQueueEntry>> fetchReviewQueue() async {
    fetchReviewQueueCalls += 1;
    return queue;
  }
}

class _RemotePieceListSyncRepository extends ServerPieceSyncRepository {
  int fetchAllPiecesCalls = 0;

  @override
  Future<List<RemotePieceSummary>> fetchAllPieces() async {
    fetchAllPiecesCalls += 1;
    return const [
      RemotePieceSummary(
        id: 'remote-ready-piece',
        title: 'Original remote title',
        status: 'approved',
        libraryStatus: 'ready',
        visibleToProfileIds: [],
      ),
    ];
  }
}

class _DebugToolsSyncRepository extends ServerPieceSyncRepository {
  _DebugToolsSyncRepository({
    List<ServerJob> jobs = const <ServerJob>[],
  }) : _jobs = [...jobs];

  List<ServerJob> _jobs;
  int clearServerWorkflowCalls = 0;
  final List<String> clearServerPieceCalls = [];
  final List<String> cancelJobCalls = [];
  final List<String> retryJobCalls = [];

  @override
  Future<String?> uploadImportedPiece(LibraryEntry entry) async {
    return 'remote-${entry.piece.id}';
  }

  @override
  Future<List<ServerJob>> fetchJobs() async {
    return _jobs;
  }

  @override
  Future<ServerJob> cancelJob(String jobId) async {
    cancelJobCalls.add(jobId);
    final canceled = _jobs.firstWhere((job) => job.id == jobId);
    final updated = ServerJob(
      id: canceled.id,
      pieceId: canceled.pieceId,
      pieceTitle: canceled.pieceTitle,
      pieceComposer: canceled.pieceComposer,
      pieceStatus: canceled.pieceStatus,
      jobType: canceled.jobType,
      status: 'canceled',
      progress: 100,
      errorMessage: 'Canceled by parent debug tools.',
      resultData: canceled.resultData,
      createdAt: canceled.createdAt,
      updatedAt: DateTime(2026, 1, 2),
    );
    _jobs = [
      updated,
      ..._jobs.where((job) => job.id != jobId),
    ];
    return updated;
  }

  @override
  Future<ServerJob> retryJob(String jobId) async {
    retryJobCalls.add(jobId);
    final failed = _jobs.firstWhere((job) => job.id == jobId);
    final updated = ServerJob(
      id: failed.id,
      pieceId: failed.pieceId,
      pieceTitle: failed.pieceTitle,
      pieceComposer: failed.pieceComposer,
      pieceStatus: failed.pieceStatus,
      jobType: failed.jobType,
      status: 'queued',
      progress: 0,
      resultData: {
        ...failed.resultData,
        'retry_count': 0,
        'manual_retry_count': 1,
      },
      createdAt: failed.createdAt,
      updatedAt: DateTime(2026, 1, 2),
    );
    _jobs = [
      updated,
      ..._jobs.where((job) => job.id != jobId),
    ];
    return updated;
  }

  @override
  Future<Map<String, dynamic>> clearServerWorkflowData() async {
    clearServerWorkflowCalls += 1;
    _jobs = const <ServerJob>[];
    return const {'status': 'cleared'};
  }

  @override
  Future<Map<String, dynamic>> clearServerPieceWorkflowData(
    String serverPieceId,
  ) async {
    clearServerPieceCalls.add(serverPieceId);
    _jobs = _jobs
        .where((job) => job.pieceId != serverPieceId)
        .toList(growable: false);
    return {'status': 'cleared', 'piece_id': serverPieceId};
  }

  @override
  Future<List<RemotePieceSummary>> fetchAllPieces() async {
    return const [];
  }

  @override
  Future<List<ReviewQueueEntry>> fetchReviewQueue() async {
    return const [];
  }

  @override
  Future<ProcessingCapabilities> fetchProcessingCapabilities() async {
    return _testProcessingCapabilities();
  }

  @override
  Future<RemotePieceDetail> fetchPieceDetail(String serverPieceId) async {
    return RemotePieceDetail(
      id: serverPieceId,
      title: 'Debug Piece',
      status: 'processing',
      libraryStatus: 'processing',
      visibleToProfileIds: const [],
      scoreVersions: const [],
    );
  }
}

ProcessingCapabilities _testProcessingCapabilities() {
  const executable = ProcessingExecutableStatus(
    name: 'Test executable',
    configured: true,
    available: true,
  );
  return ProcessingCapabilities(
    serverOnline: true,
    settings: ProcessingSettings(
      processingMode: 'server_only',
      allowStubMusicXml: true,
      productionMode: false,
      updatedAt: DateTime(2026),
    ),
    audiveris: executable,
    homr: executable,
    legato: executable,
    musescore: executable,
    ocr: executable,
    localLlm: executable,
    cloudLlm: executable,
    deviceWorkersEnabled: false,
    cloudWorkersEnabled: false,
    deviceWorkers: const [],
    jobSummary: const ProcessingJobSummary(
      queuedCount: 0,
      runningCount: 0,
      failedCount: 0,
      succeededCount: 0,
      canceledCount: 0,
    ),
    warnings: const [],
  );
}
