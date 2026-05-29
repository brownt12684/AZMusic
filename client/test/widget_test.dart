import 'dart:io';

import 'package:azmusic/app/app.dart';
import 'package:azmusic/app/app_keys.dart';
import 'package:azmusic/app/launch_options.dart';
import 'package:azmusic/core/config/app_config.dart';
import 'package:azmusic/core/network/network_info.dart';
import 'package:azmusic/data/repositories/server_piece_sync_repository.dart';
import 'package:azmusic/domain/entities/review_candidate_package.dart';
import 'package:azmusic/injection/container.dart';
import 'package:azmusic/presentation/providers/app_providers.dart';
import 'package:azmusic/presentation/providers/review_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    await AppConfig.initialize();
    tempDir = Directory.systemTemp.createTempSync('azmusic_widget_test_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<void> pumpApp(
    WidgetTester tester, {
    AppLaunchOptions launchOptions = const AppLaunchOptions(
      sandboxMode: false,
      resetLibraryOnLaunch: false,
      initialSurface: AppLaunchSurface.login,
    ),
    _FakeServerPieceSyncRepository? repository,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDirectoryProvider.overrideWith((ref) => tempDir),
          launchOptionsProvider.overrideWith((ref) => launchOptions),
          serverPieceSyncRepositoryProvider.overrideWith(
            (ref) => repository ?? _FakeServerPieceSyncRepository(),
          ),
          networkInfoProvider.overrideWith((ref) => _FakeNetworkInfo()),
          serverHealthProvider.overrideWith(
            (ref) async => const ServerHealthState(
              status: ServerHealthStatus.online,
              serverUrl: 'http://test-server',
              message: 'AZMusic server',
            ),
          ),
        ],
        child: const AzMusicApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  Future<void> pumpUntilFound(
    WidgetTester tester,
    Finder finder, {
    int maxPumps = 100,
  }) async {
    for (var i = 0; i < maxPumps; i++) {
      if (finder.evaluate().isNotEmpty) {
        return;
      }
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('starts at the login screen', (WidgetTester tester) async {
    await pumpApp(tester);
    await pumpUntilFound(tester, find.byKey(AppKeys.loginScreen));

    expect(find.byKey(AppKeys.loginScreen), findsOneWidget);
    expect(find.text("Who's practicing today?"), findsOneWidget);
    expect(find.byKey(AppKeys.profileButton('student-alyse')), findsOneWidget);
    expect(find.byKey(AppKeys.profileButton('parent-main')), findsOneWidget);
  });

  testWidgets('student login opens the library shell',
      (WidgetTester tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(AppKeys.profileButton('student-alyse')));
    await pumpUntilFound(tester, find.byKey(AppKeys.libraryScreen));

    expect(find.byKey(AppKeys.libraryScreen), findsOneWidget);
    expect(find.byKey(AppKeys.libraryStatusBanner), findsOneWidget);
    expect(find.byKey(AppKeys.librarySearchField), findsOneWidget);
    expect(find.text("Alyse's library"), findsOneWidget);
  });

  testWidgets('parent login opens the tabbed parent home', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(AppKeys.profileButton('parent-main')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '0000');
    await tester.tap(find.text('Unlock'));
    await pumpUntilFound(tester, find.byKey(AppKeys.parentHomeScreen));

    expect(find.byKey(AppKeys.parentHomeScreen), findsOneWidget);
    expect(find.byKey(AppKeys.parentReviewCard), findsOneWidget);
    expect(find.byKey(AppKeys.parentImportButton), findsOneWidget);
    expect(find.text('Process, review, push'), findsOneWidget);

    await tester.tap(find.text('Server'));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.parentServerStatus), findsOneWidget);
  });

  testWidgets('parent intake shows server-ready pieces from remote sync', (
    WidgetTester tester,
  ) async {
    final repository = _FakeServerPieceSyncRepository(
      allPieces: const [
        RemotePieceSummary(
          id: 'server-ready-piece',
          title: 'Ready Server Etude',
          status: 'approved',
          libraryStatus: 'ready',
          visibleToProfileIds: [],
          primaryInstrument: 'Cello',
        ),
      ],
    );
    await pumpApp(tester, repository: repository);
    await tester.tap(find.byKey(AppKeys.profileButton('parent-main')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '0000');
    await tester.tap(find.text('Unlock'));
    await pumpUntilFound(tester, find.byKey(AppKeys.parentServerReadyList));

    expect(find.text('Ready to push from server'), findsOneWidget);
    expect(find.text('Ready Server Etude'), findsOneWidget);

    final pushButton = find.byKey(
      AppKeys.pushToProfileButton('server-ready-piece', 'student-alyse'),
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, -320));
    await tester.pumpAndSettle();
    await tester.tap(pushButton);
    await tester.pump();

    expect(repository.pushCalls, hasLength(1));
    expect(repository.pushCalls.single.pieceId, 'server-ready-piece');
    expect(repository.pushCalls.single.profileIds, ['student-alyse']);
  });

  testWidgets('shows sandbox launcher actions', (WidgetTester tester) async {
    await pumpApp(
      tester,
      launchOptions: const AppLaunchOptions(
        sandboxMode: true,
        resetLibraryOnLaunch: false,
        initialSurface: AppLaunchSurface.sandbox,
      ),
    );
    await pumpUntilFound(tester, find.byKey(AppKeys.sandboxResetLibraryButton));

    expect(find.byKey(AppKeys.sandboxLauncherScreen), findsOneWidget);
    expect(find.byKey(AppKeys.sandboxOpenReaderButton), findsOneWidget);
    expect(find.byKey(AppKeys.sandboxOpenReviewQueueButton), findsOneWidget);
  });

  testWidgets('sandbox review launch opens the parent home', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      launchOptions: const AppLaunchOptions(
        sandboxMode: true,
        resetLibraryOnLaunch: false,
        initialSurface: AppLaunchSurface.reviewQueue,
      ),
    );
    await pumpUntilFound(tester, find.byKey(AppKeys.parentHomeScreen));

    expect(find.byKey(AppKeys.parentHomeScreen), findsOneWidget);
    expect(find.byKey(AppKeys.parentReviewCard), findsOneWidget);
  });
}

class _FakeServerPieceSyncRepository extends ServerPieceSyncRepository {
  _FakeServerPieceSyncRepository({
    this.allPieces = const <RemotePieceSummary>[],
  });

  final List<RemotePieceSummary> allPieces;
  final List<_PushCall> pushCalls = [];

  @override
  Future<List<RemotePieceSummary>> fetchAssignedPieces(String profileId) async {
    return const [];
  }

  @override
  Future<List<RemotePieceSummary>> fetchAllPieces() async {
    return allPieces;
  }

  @override
  Future<List<ReviewQueueEntry>> fetchReviewQueue() async {
    return const [];
  }

  @override
  Future<ReviewQueueEntry> fetchReviewItem(String itemId) async {
    throw UnimplementedError('Review item detail is not used in widget tests.');
  }

  @override
  Future<void> approveReviewItem(String itemId) async {}

  @override
  Future<void> rejectReviewItem(String itemId) async {}

  @override
  Future<ReviewBulkApprovalResult> approveBookReviewItems({
    String? sourceBookId,
    String? sourceReviewItemId,
    required String processingStage,
  }) async {
    return ReviewBulkApprovalResult(
      sourceBookId: sourceBookId ?? '',
      processingStage: processingStage,
      approvedCount: 0,
      skippedCount: 0,
      failedCount: 0,
    );
  }

  @override
  Future<RemotePieceDetail> pushPieceToProfiles(
    String serverPieceId,
    List<String> profileIds,
  ) async {
    pushCalls.add(_PushCall(serverPieceId, profileIds));
    return RemotePieceDetail(
      id: serverPieceId,
      title: 'Ready Server Etude',
      status: 'approved',
      libraryStatus: 'ready',
      visibleToProfileIds: profileIds,
      scoreVersions: const [],
    );
  }
}

class _PushCall {
  const _PushCall(this.pieceId, this.profileIds);

  final String pieceId;
  final List<String> profileIds;
}

class _FakeNetworkInfo implements NetworkInfo {
  @override
  Future<bool> get isConnected async => true;

  @override
  Stream<bool> get onConnectivityChanged => Stream<bool>.value(true);
}
