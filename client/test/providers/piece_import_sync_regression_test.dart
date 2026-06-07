import 'dart:convert';
import 'dart:io';

import 'package:azmusic/app/launch_options.dart';
import 'package:azmusic/core/config/app_config.dart';
import 'package:azmusic/core/network/network_info.dart';
import 'package:azmusic/data/repositories/server_piece_sync_repository.dart';
import 'package:azmusic/domain/entities/library_entry.dart';
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
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues(const <String, Object>{
      'server_host': 'test-server',
      'server_port': 8795,
      'server_id': 'test-server',
      'server_pairing_token': 'test-token',
    });
    await AppConfig.initialize();
    tempDir = Directory.systemTemp.createTempSync(
      'azmusic_piece_import_sync_regression_',
    );
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<File> createSamplePdfFile({String name = 'student_import.pdf'}) async {
    final file = File('${tempDir.path}${Platform.pathSeparator}$name');
    await file.writeAsBytes(const <int>[37, 80, 68, 70], flush: true);
    return file;
  }

  test(
      'student import stays visible while the remote piece is still processing',
      () async {
    final container = _containerFor(
      tempDir,
      const _StaticNetworkInfo(true),
      _StubSyncRepository(
        remotePiece: const RemotePieceDetail(
          id: 'remote-processing-piece',
          title: 'Processing imported score',
          status: 'processing',
          libraryStatus: 'processing',
          visibleToProfileIds: <String>[],
          scoreVersions: <RemoteScoreVersion>[],
        ),
      ),
    );
    addTearDown(container.dispose);

    final repository = container.read(libraryRepositoryProvider);
    final sourceFile = await createSamplePdfFile();
    final importedEntry = await repository.importScoreForProfile(
      sourcePath: sourceFile.path,
      assignedProfileId: 'student-alyse',
    );

    await container
        .read(allPiecesProvider.notifier)
        .loadPieces(trigger: SyncTrigger.manualRefresh);

    final studentEntries = container.read(studentLibraryEntriesProvider);
    final syncedEntry = studentEntries.singleWhere(
      (entry) => entry.piece.id == importedEntry.piece.id,
    );

    expect(studentEntries, hasLength(1));
    expect(syncedEntry.piece.serverPieceId, 'remote-processing-piece');
    expect(syncedEntry.piece.libraryStatus.name, 'processing');
    expect(
      syncedEntry.piece.visibleToProfileIds,
      contains('student-alyse'),
    );
  });

  test(
      'approved remote artifacts replace the default while keeping original fallback visible',
      () async {
    final container = _containerFor(
      tempDir,
      const _StaticNetworkInfo(true),
      _StubSyncRepository(
        remotePiece: const RemotePieceDetail(
          id: 'remote-approved-piece',
          title: 'Approved imported score',
          status: 'approved',
          libraryStatus: 'ready',
          visibleToProfileIds: <String>[],
          scoreVersions: <RemoteScoreVersion>[
            RemoteScoreVersion(
              id: 'approved-pdf',
              versionType: 'approved',
              filePath: 'approved-demo.pdf',
              fileUrl: 'https://example.test/files/approved-demo.pdf',
              isDefault: true,
            ),
            RemoteScoreVersion(
              id: 'approved-musicxml',
              versionType: 'approved',
              filePath: 'approved-demo.musicxml',
              fileUrl: 'https://example.test/files/approved-demo.musicxml',
              isDefault: false,
            ),
          ],
        ),
      ),
    );
    addTearDown(container.dispose);

    final repository = container.read(libraryRepositoryProvider);
    final sourceFile = await createSamplePdfFile(name: 'student_approved.pdf');
    final importedEntry = await repository.importScoreForProfile(
      sourcePath: sourceFile.path,
      assignedProfileId: 'student-alyse',
    );

    await container
        .read(allPiecesProvider.notifier)
        .loadPieces(trigger: SyncTrigger.manualRefresh);

    final syncedEntry =
        container.read(pieceEntryProvider(importedEntry.piece.id));
    expect(syncedEntry, isNotNull);
    expect(syncedEntry!.piece.serverPieceId, 'remote-approved-piece');
    expect(syncedEntry.piece.libraryStatus.name, 'ready');
    expect(syncedEntry.scoreVersions, hasLength(3));
    expect(
      syncedEntry.primaryScore.remoteUrl,
      'https://example.test/files/approved-demo.pdf',
    );

    final rawVersion = syncedEntry.scoreVersions.firstWhere(
      (scoreVersion) => scoreVersion.versionType == 'raw',
    );
    final musicXmlVersion = syncedEntry.scoreVersions.firstWhere(
      (scoreVersion) => scoreVersion.format == 'musicxml',
    );

    expect(rawVersion.isStudentVisible, isTrue);
    expect(musicXmlVersion.isStudentVisible, isFalse);
    expect(musicXmlVersion.isPrimary, isFalse);
    expect(
      container.read(studentLibraryEntriesProvider).single.piece.id,
      importedEntry.piece.id,
    );
  });
}

ProviderContainer _containerFor(
  Directory tempDir,
  NetworkInfo networkInfo,
  ServerPieceSyncRepository syncRepository,
) {
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

class _StubSyncRepository extends ServerPieceSyncRepository {
  _StubSyncRepository({required this.remotePiece});

  final RemotePieceDetail remotePiece;

  @override
  Future<String?> uploadImportedPiece(LibraryEntry entry) async =>
      remotePiece.id;

  @override
  Future<List<RemotePieceSummary>> fetchAssignedPieces(String profileId) async {
    return const <RemotePieceSummary>[];
  }

  @override
  Future<RemotePieceDetail> fetchPieceDetail(String serverPieceId) async {
    return remotePiece;
  }

  @override
  Future<List<int>> downloadBytes(String url) async {
    if (url.endsWith('.musicxml')) {
      return utf8.encode('<score-partwise version="4.0"></score-partwise>');
    }
    return const <int>[37, 80, 68, 70];
  }
}
