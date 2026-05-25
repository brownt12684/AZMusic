import 'dart:async';
import 'dart:io';

import 'package:azmusic/app/launch_options.dart';
import 'package:azmusic/core/config/app_config.dart';
import 'package:azmusic/core/network/network_info.dart';
import 'package:azmusic/data/repositories/server_piece_sync_repository.dart';
import 'package:azmusic/domain/entities/library_entry.dart';
import 'package:azmusic/domain/entities/piece.dart';
import 'package:azmusic/domain/entities/review_candidate_package.dart';
import 'package:azmusic/injection/container.dart';
import 'package:azmusic/presentation/providers/app_providers.dart';
import 'package:azmusic/presentation/providers/piece_providers.dart';
import 'package:azmusic/presentation/providers/review_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    await AppConfig.initialize();
  });

  setUp(() {
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

class _GatedUploadSyncRepository extends ServerPieceSyncRepository {
  _GatedUploadSyncRepository(this.gate);

  final Completer<void> gate;

  @override
  Future<String?> uploadImportedPiece(LibraryEntry entry) async {
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
