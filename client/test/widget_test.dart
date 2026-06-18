import 'dart:async';
import 'dart:io';

import 'package:azmusic/app/app.dart';
import 'package:azmusic/app/app_keys.dart';
import 'package:azmusic/app/launch_options.dart';
import 'package:azmusic/app/routes/app_router.dart';
import 'package:azmusic/core/config/app_config.dart';
import 'package:azmusic/core/network/network_info.dart';
import 'package:azmusic/data/repositories/server_piece_sync_repository.dart';
import 'package:azmusic/domain/entities/processing_settings.dart';
import 'package:azmusic/domain/entities/review_candidate_package.dart';
import 'package:azmusic/domain/entities/server_job.dart';
import 'package:azmusic/injection/container.dart';
import 'package:azmusic/presentation/providers/app_providers.dart';
import 'package:azmusic/presentation/providers/review_providers.dart';
import 'package:azmusic/presentation/screens/parent/processing_settings_screen.dart';
import 'package:azmusic/presentation/screens/parent/review_compare_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    debugUseReviewPdfPlaceholder = false;
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    await AppConfig.initialize();
    tempDir = Directory.systemTemp.createTempSync('azmusic_widget_test_');
  });

  tearDown(() async {
    debugUseReviewPdfPlaceholder = false;
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

  Future<void> pumpReviewCompareScreen(
    WidgetTester tester,
    ReviewQueueEntry reviewItem, {
    _FakeServerPieceSyncRepository? repository,
  }) async {
    final fakeRepository =
        repository ?? _FakeServerPieceSyncRepository(reviewItem: reviewItem);
    await AppConfig.applyServerPairing(
      serverUrl: 'http://test-server',
      serverId: 'test-server',
      pairingToken: 'test-token',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDirectoryProvider.overrideWith((ref) => tempDir),
          serverPieceSyncRepositoryProvider.overrideWith(
            (ref) => fakeRepository,
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
        child: MaterialApp(
          home: ReviewCompareScreen(itemId: reviewItem.id),
          onGenerateRoute: (settings) {
            if (settings.name == AppRouter.reviewCompare) {
              final itemId = settings.arguments as String?;
              return MaterialPageRoute<void>(
                builder: (_) => ReviewCompareScreen(itemId: itemId),
              );
            }
            return MaterialPageRoute<void>(
              builder: (_) => Scaffold(
                body: Center(child: Text('Page not found: ${settings.name}')),
              ),
            );
          },
        ),
      ),
    );
    await pumpUntilFound(tester, find.byKey(AppKeys.reviewCompareScreen));
  }

  Future<void> scrollParentWorkflowUntilFound(
    WidgetTester tester,
    Finder finder, {
    int maxScrolls = 12,
  }) async {
    for (var i = 0; i < maxScrolls; i++) {
      await tester.pump();
      if (finder.evaluate().isNotEmpty) {
        await tester.ensureVisible(finder);
        await tester.pump();
        return;
      }
      await tester.drag(
        find.byKey(AppKeys.parentWorkflowList),
        const Offset(0, -500),
      );
      await tester.pump();
    }
  }

  Future<void> scrollFirstListViewUntilFound(
    WidgetTester tester,
    Finder finder, {
    int maxScrolls = 12,
  }) async {
    for (var i = 0; i < maxScrolls; i++) {
      await tester.pump();
      if (finder.evaluate().isNotEmpty) {
        await tester.ensureVisible(finder);
        await tester.pump();
        return;
      }
      await tester.drag(find.byType(ListView).first, const Offset(0, -500));
      await tester.pump();
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
    await AppConfig.setParentPin('2468');
    await pumpApp(tester);
    await tester.tap(find.byKey(AppKeys.profileButton('parent-main')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(AppKeys.parentPinEntryField), '2468');
    await tester.tap(find.text('Unlock'));
    await pumpUntilFound(tester, find.byKey(AppKeys.parentHomeScreen));

    expect(find.byKey(AppKeys.parentHomeScreen), findsOneWidget);
    expect(find.byKey(AppKeys.parentReviewCard), findsOneWidget);
    expect(find.byKey(AppKeys.parentImportButton), findsOneWidget);
    expect(find.text('Import'), findsOneWidget);

    await tester.tap(find.text('Advanced'));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.parentServerStatus), findsOneWidget);
  });

  testWidgets('parent debug tools stay hidden until enabled', (
    WidgetTester tester,
  ) async {
    await AppConfig.setParentPin('2468');
    await AppConfig.applyServerPairing(
      serverUrl: 'http://test-server',
      serverId: 'test-server',
      pairingToken: 'test-token',
    );
    await pumpApp(tester);
    await tester.tap(find.byKey(AppKeys.profileButton('parent-main')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(AppKeys.parentPinEntryField), '2468');
    await tester.tap(find.text('Unlock'));
    await pumpUntilFound(tester, find.byKey(AppKeys.parentHomeScreen));

    await scrollParentWorkflowUntilFound(
      tester,
      find.byKey(AppKeys.parentDebugToolsToggle),
    );
    expect(find.byKey(AppKeys.parentDebugToolsToggle), findsOneWidget);
    expect(find.byKey(AppKeys.parentDebugClearLibrariesButton), findsNothing);

    await tester.tap(find.byKey(AppKeys.parentDebugToolsToggle));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(AppKeys.parentDebugClearLibrariesButton), findsOneWidget);
    expect(find.byKey(AppKeys.parentDebugRefreshJobsButton), findsOneWidget);
  });

  testWidgets('parent debug tools pin failed jobs above newer successful jobs',
      (
    WidgetTester tester,
  ) async {
    await AppConfig.setParentPin('2468');
    await AppConfig.applyServerPairing(
      serverUrl: 'http://test-server',
      serverId: 'test-server',
      pairingToken: 'test-token',
    );
    final now = DateTime(2026, 6, 5, 12);
    final repository = _FakeServerPieceSyncRepository(
      jobs: [
        for (var index = 0; index < 45; index++)
          ServerJob(
            id: 'success-$index',
            pieceId: 'piece-$index',
            jobType: 'score_processing',
            status: 'succeeded',
            progress: 100,
            resultData: const {},
            createdAt: now.add(Duration(minutes: index)),
            updatedAt: now.add(Duration(minutes: index)),
          ),
        ServerJob(
          id: 'failed-job',
          pieceId: 'failed-piece',
          pieceTitle: 'Landler',
          jobType: 'score_processing',
          status: 'failed',
          progress: 100,
          errorMessage:
              'MuseScore Studio failed without returning diagnostic output.',
          resultData: const {},
          createdAt: now.subtract(const Duration(hours: 1)),
          updatedAt: now.subtract(const Duration(hours: 1)),
        ),
      ],
    );

    await pumpApp(tester, repository: repository);
    await tester.tap(find.byKey(AppKeys.profileButton('parent-main')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(AppKeys.parentPinEntryField), '2468');
    await tester.tap(find.text('Unlock'));
    await pumpUntilFound(tester, find.byKey(AppKeys.parentHomeScreen));

    await scrollParentWorkflowUntilFound(
      tester,
      find.byKey(AppKeys.parentDebugToolsToggle),
    );
    await tester.tap(find.byKey(AppKeys.parentDebugToolsToggle));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('1 failed'), findsOneWidget);
    expect(find.text('Landler'), findsOneWidget);
    expect(find.text('score_processing failed'), findsOneWidget);
    expect(find.text('failed'), findsOneWidget);
    expect(find.byKey(AppKeys.parentDebugRetryJobButton('failed-job')),
        findsOneWidget);
    expect(find.textContaining('MuseScore Studio failed'), findsOneWidget);
  });

  testWidgets('parent intake shows server-ready pieces from remote sync', (
    WidgetTester tester,
  ) async {
    await AppConfig.setParentPin('2468');
    await AppConfig.applyServerPairing(
      serverUrl: 'http://test-server',
      serverId: 'test-server',
      pairingToken: 'test-token',
    );
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
    await pumpApp(
      tester,
      repository: repository,
    );
    await tester.tap(find.byKey(AppKeys.profileButton('parent-main')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(AppKeys.parentPinEntryField), '2468');
    await tester.tap(find.text('Unlock'));
    await tester.pump(const Duration(milliseconds: 500));
    await pumpUntilFound(tester, find.byKey(AppKeys.parentHomeScreen));
    await scrollParentWorkflowUntilFound(tester, find.text('Ready to Push'));
    await pumpUntilFound(tester, find.byKey(AppKeys.parentServerReadyList));

    expect(find.text('Ready to Push'), findsOneWidget);
    expect(find.text('Ready Server Etude'), findsOneWidget);

    final pushButton = find.byKey(
      AppKeys.pushToAllStudentsButton('server-ready-piece'),
    );
    await scrollParentWorkflowUntilFound(tester, pushButton);
    await tester.tap(pushButton);
    await tester.pump();

    expect(repository.pushCalls, hasLength(1));
    expect(repository.pushCalls.single.pieceId, 'server-ready-piece');
    expect(
      repository.pushCalls.single.profileIds,
      ['student-alyse', 'student-zora'],
    );
    expect(repository.pushCalls.single.mode, 'cleaned_pdf');

    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Ready Server Etude'), findsNothing);
    expect(find.text('Nothing ready to push'), findsOneWidget);
  });

  testWidgets('parent can push a ready piece to selected students', (
    WidgetTester tester,
  ) async {
    await AppConfig.setParentPin('2468');
    await AppConfig.applyServerPairing(
      serverUrl: 'http://test-server',
      serverId: 'test-server',
      pairingToken: 'test-token',
    );
    final repository = _FakeServerPieceSyncRepository(
      allPieces: const [
        RemotePieceSummary(
          id: 'server-select-piece',
          title: 'Selective Etude',
          status: 'approved',
          libraryStatus: 'ready',
          visibleToProfileIds: [],
          primaryInstrument: 'Cello',
        ),
      ],
    );
    await pumpApp(
      tester,
      repository: repository,
    );
    await tester.tap(find.byKey(AppKeys.profileButton('parent-main')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(AppKeys.parentPinEntryField), '2468');
    await tester.tap(find.text('Unlock'));
    await tester.pump(const Duration(milliseconds: 500));
    await pumpUntilFound(tester, find.byKey(AppKeys.parentHomeScreen));
    await scrollParentWorkflowUntilFound(tester, find.text('Ready to Push'));
    await pumpUntilFound(tester, find.byKey(AppKeys.parentServerReadyList));

    final selectButton = find.byKey(
      AppKeys.pushToSelectedStudentsButton('server-select-piece'),
    );
    await scrollParentWorkflowUntilFound(tester, selectButton);
    await tester.tap(selectButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(
      find.byKey(
        AppKeys.pushStudentSelectionCheckbox(
          'server-select-piece',
          'student-zora',
        ),
      ),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(
        AppKeys.pushSelectedStudentsConfirmButton('server-select-piece'),
      ),
    );
    await tester.pump();

    expect(repository.pushCalls, hasLength(1));
    expect(repository.pushCalls.single.pieceId, 'server-select-piece');
    expect(repository.pushCalls.single.profileIds, ['student-zora']);
    expect(repository.pushCalls.single.mode, 'cleaned_pdf');
  });

  testWidgets('parent shows book packages before child metadata review', (
    WidgetTester tester,
  ) async {
    await AppConfig.setParentPin('2468');
    await AppConfig.applyServerPairing(
      serverUrl: 'http://test-server',
      serverId: 'test-server',
      pairingToken: 'test-token',
    );
    final repository = _FakeServerPieceSyncRepository(
      allPieces: const [
        RemotePieceSummary(
          id: 'server-book',
          title: 'Position Pieces for Cello, Book 1',
          status: 'imported',
          libraryStatus: 'intake',
          visibleToProfileIds: [],
          pieceKind: 'book',
          primaryInstrument: 'Cello',
        ),
      ],
    );
    await pumpApp(
      tester,
      repository: repository,
    );
    await tester.tap(find.byKey(AppKeys.profileButton('parent-main')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(AppKeys.parentPinEntryField), '2468');
    await tester.tap(find.text('Unlock'));
    await tester.pump(const Duration(milliseconds: 500));
    await pumpUntilFound(tester, find.byKey(AppKeys.parentHomeScreen));
    await scrollParentWorkflowUntilFound(tester, find.text('Ready to Push'));
    await pumpUntilFound(tester, find.byKey(AppKeys.parentServerReadyList));

    expect(find.text('Position Pieces for Cello, Book 1'), findsOneWidget);
    expect(find.text('Book / collection'), findsOneWidget);

    final pushButton = find.byKey(
      AppKeys.pushToAllStudentsButton('server-book'),
    );
    await scrollParentWorkflowUntilFound(tester, pushButton);
    expect(find.text('Push book to all students'), findsOneWidget);
    await tester.tap(pushButton);
    await tester.pump();

    expect(repository.pushCalls, hasLength(1));
    expect(repository.pushCalls.single.pieceId, 'server-book');
    expect(repository.pushCalls.single.mode, 'cleaned_pdf');
  });

  testWidgets('parent ready shows reviewed book packages as pushable', (
    WidgetTester tester,
  ) async {
    await AppConfig.setParentPin('2468');
    await AppConfig.applyServerPairing(
      serverUrl: 'http://test-server',
      serverId: 'test-server',
      pairingToken: 'test-token',
    );
    final repository = _FakeServerPieceSyncRepository(
      allPieces: const [
        RemotePieceSummary(
          id: 'server-book',
          title: 'Position Pieces for Cello, Book 1',
          status: 'approved',
          libraryStatus: 'ready',
          visibleToProfileIds: [],
          pieceKind: 'book',
          primaryInstrument: 'Cello',
        ),
      ],
    );
    await pumpApp(
      tester,
      repository: repository,
    );
    await tester.tap(find.byKey(AppKeys.profileButton('parent-main')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(AppKeys.parentPinEntryField), '2468');
    await tester.tap(find.text('Unlock'));
    await tester.pump(const Duration(milliseconds: 500));
    await pumpUntilFound(tester, find.byKey(AppKeys.parentHomeScreen));
    await scrollParentWorkflowUntilFound(tester, find.text('Ready to Push'));
    await pumpUntilFound(tester, find.byKey(AppKeys.parentServerReadyList));

    expect(find.text('Position Pieces for Cello, Book 1'), findsOneWidget);
    expect(find.text('Book / collection'), findsOneWidget);

    final pushButton = find.byKey(
      AppKeys.pushToAllStudentsButton('server-book'),
    );
    await scrollParentWorkflowUntilFound(tester, pushButton);
    expect(find.text('Push book to all students'), findsOneWidget);
    await tester.tap(pushButton);
    await tester.pump();

    expect(repository.pushCalls, hasLength(1));
    expect(repository.pushCalls.single.pieceId, 'server-book');
    expect(
      repository.pushCalls.single.profileIds,
      ['student-alyse', 'student-zora'],
    );
    expect(repository.pushCalls.single.mode, 'cleaned_pdf');
  });

  testWidgets(
    'parent workflow hides completed book processing after child push',
    (WidgetTester tester) async {
      await AppConfig.setParentPin('2468');
      await AppConfig.applyServerPairing(
        serverUrl: 'http://test-server',
        serverId: 'test-server',
        pairingToken: 'test-token',
      );

      final repository = _FakeServerPieceSyncRepository(
        allPieces: const [
          RemotePieceSummary(
            id: 'server-child-pushed',
            title: 'Child Already Pushed',
            status: 'approved',
            libraryStatus: 'ready',
            visibleToProfileIds: ['student-zora'],
            sourceBookId: 'server-book-complete',
            primaryInstrument: 'Cello',
          ),
          RemotePieceSummary(
            id: 'server-book-complete',
            title: 'Completed Book Source',
            status: 'approved',
            libraryStatus: 'ready',
            visibleToProfileIds: [],
            pieceKind: 'book',
            primaryInstrument: 'Cello',
          ),
        ],
      );

      await pumpApp(tester, repository: repository);
      await tester.tap(find.byKey(AppKeys.profileButton('parent-main')));
      await tester.pump();
      await pumpUntilFound(tester, find.byKey(AppKeys.parentPinEntryField));
      await tester.enterText(find.byKey(AppKeys.parentPinEntryField), '2468');
      await tester.tap(find.text('Unlock'));
      await tester.pump(const Duration(milliseconds: 500));
      await pumpUntilFound(tester, find.byKey(AppKeys.parentHomeScreen));

      await scrollParentWorkflowUntilFound(
        tester,
        find.text('Processing tracker'),
      );
      expect(find.text('No active processing'), findsNothing);
      expect(find.text('Child Already Pushed'), findsNothing);

      await scrollParentWorkflowUntilFound(tester, find.text('Ready to Push'));
      await scrollParentWorkflowUntilFound(
        tester,
        find.byKey(AppKeys.pushToAllStudentsButton('server-book-complete')),
      );

      expect(find.text('Completed Book Source'), findsOneWidget);
      expect(find.text('Book / collection'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'parent workflow keeps completed book reviews out of processing',
    (WidgetTester tester) async {
      await AppConfig.setParentPin('2468');
      await AppConfig.applyServerPairing(
        serverUrl: 'http://test-server',
        serverId: 'test-server',
        pairingToken: 'test-token',
      );

      final repository = _FakeServerPieceSyncRepository(
        allPieces: const [
          RemotePieceSummary(
            id: 'review-child',
            title: 'The Troubadour / Hoedown',
            status: 'review_pending',
            libraryStatus: 'review',
            visibleToProfileIds: [],
            sourceBookId: 'review-book',
            primaryInstrument: 'Cello',
          ),
          RemotePieceSummary(
            id: 'review-book',
            title:
                'Position Pieces two song page 38 The Troubadour and Hoedown',
            status: 'imported',
            libraryStatus: 'intake',
            visibleToProfileIds: [],
            pieceKind: 'book',
            primaryInstrument: 'Cello',
          ),
        ],
        reviewItems: [
          ReviewQueueEntry(
            id: 'review-split',
            pieceId: 'review-child',
            itemType: 'score_candidate',
            title: 'Review book split for The Troubadour / Hoedown',
            description: 'Review the extracted piece metadata.',
            status: 'pending',
            createdAt: DateTime(2026, 6, 17),
            candidateData: const {
              'source_book_id': 'review-book',
              'processing_stage': 'split_review_needed',
            },
          ),
        ],
      );

      await pumpApp(tester, repository: repository);
      await tester.tap(find.byKey(AppKeys.profileButton('parent-main')));
      await tester.pump();
      await pumpUntilFound(tester, find.byKey(AppKeys.parentPinEntryField));
      await tester.enterText(find.byKey(AppKeys.parentPinEntryField), '2468');
      await tester.tap(find.text('Unlock'));
      await tester.pump(const Duration(milliseconds: 500));
      await pumpUntilFound(tester, find.byKey(AppKeys.parentHomeScreen));

      await scrollParentWorkflowUntilFound(
        tester,
        find.text('Processing tracker'),
      );
      expect(find.text('No active processing'), findsNothing);
      expect(find.text('metadata review'), findsNothing);

      await scrollParentWorkflowUntilFound(
        tester,
        find.text('1 metadata review(s), 0 notation edit item(s).'),
      );
      expect(
        find.text('1 metadata review(s), 0 notation edit item(s).'),
        findsOneWidget,
      );
      expect(find.text('1 open'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'parent workflow shows pulled back pieces and repushes previous students',
    (WidgetTester tester) async {
      await AppConfig.setParentPin('2468');
      await AppConfig.applyServerPairing(
        serverUrl: 'http://test-server',
        serverId: 'test-server',
        pairingToken: 'test-token',
      );

      final repository = _FakeServerPieceSyncRepository(
        allPieces: const [
          RemotePieceSummary(
            id: 'pulled-back-piece',
            title: 'Pulled Back Etude',
            status: 'needs_edits',
            libraryStatus: 'needsEdits',
            visibleToProfileIds: [],
            previousVisibleToProfileIds: ['student-zora'],
            primaryInstrument: 'Cello',
          ),
          RemotePieceSummary(
            id: 'ready-after-edits',
            title: 'Ready After Edits',
            status: 'approved',
            libraryStatus: 'ready',
            visibleToProfileIds: [],
            previousVisibleToProfileIds: ['student-zora'],
            primaryInstrument: 'Cello',
          ),
        ],
      );

      await pumpApp(tester, repository: repository);
      await tester.tap(find.byKey(AppKeys.profileButton('parent-main')));
      await tester.pump();
      await pumpUntilFound(tester, find.byKey(AppKeys.parentPinEntryField));
      await tester.enterText(find.byKey(AppKeys.parentPinEntryField), '2468');
      await tester.tap(find.text('Unlock'));
      await tester.pump(const Duration(milliseconds: 500));
      await pumpUntilFound(tester, find.byKey(AppKeys.parentHomeScreen));

      await scrollParentWorkflowUntilFound(
        tester,
        find.text('Pulled Back Etude'),
      );
      expect(find.textContaining('Pulled back from Zora'), findsOneWidget);
      expect(find.text('Needs edits'), findsOneWidget);

      final repushButton = find.byKey(
        AppKeys.repushToPreviousStudentsButton('ready-after-edits'),
      );
      await scrollParentWorkflowUntilFound(tester, repushButton);
      expect(find.text('Ready After Edits'), findsOneWidget);
      expect(find.text('Repush to previous students'), findsOneWidget);
      await tester.tap(repushButton);
      await tester.pump();

      expect(repository.pushCalls, hasLength(1));
      expect(repository.pushCalls.single.pieceId, 'ready-after-edits');
      expect(repository.pushCalls.single.profileIds, ['student-zora']);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('parent workflow polls while server processing jobs are active', (
    WidgetTester tester,
  ) async {
    await AppConfig.setParentPin('2468');
    await AppConfig.applyServerPairing(
      serverUrl: 'http://test-server',
      serverId: 'test-server',
      pairingToken: 'test-token',
    );
    final now = DateTime(2026, 6, 17, 12);
    final activeSummary = ProcessingJobSummary(
      queuedCount: 2,
      runningCount: 1,
      failedCount: 0,
      succeededCount: 0,
      canceledCount: 0,
      activeJobs: [
        ServerJob(
          id: 'active-troubadour',
          pieceId: 'piece-troubadour',
          pieceTitle: 'The Troubadour',
          jobType: 'score_processing',
          status: 'running',
          progress: 40,
          resultData: const {},
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );
    const idleSummary = ProcessingJobSummary(
      queuedCount: 0,
      runningCount: 0,
      failedCount: 0,
      succeededCount: 3,
      canceledCount: 0,
    );
    final repository = _FakeServerPieceSyncRepository(
      jobSummaries: [activeSummary],
    );

    await pumpApp(tester, repository: repository);
    await tester.tap(find.byKey(AppKeys.profileButton('parent-main')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(AppKeys.parentPinEntryField), '2468');
    await tester.tap(find.text('Unlock'));
    await pumpUntilFound(tester, find.byKey(AppKeys.parentHomeScreen));
    await scrollParentWorkflowUntilFound(
      tester,
      find.textContaining('Processing The Troubadour'),
    );
    expect(find.textContaining('Processing The Troubadour'), findsOneWidget);
    expect(find.textContaining('40%'), findsOneWidget);
    expect(find.text('Remaining server tasks'), findsNothing);

    final trackerTile = find.byKey(AppKeys.parentProcessingTracker);
    await tester.ensureVisible(trackerTile);
    await tester.drag(
      find.byKey(AppKeys.parentWorkflowList),
      const Offset(0, 250),
    );
    await tester.pump();
    await tester.tap(trackerTile);
    await tester.pumpAndSettle();
    expect(find.text('Remaining server tasks'), findsOneWidget);
    expect(find.text('The Troubadour'), findsOneWidget);

    final initialReviewFetches = repository.fetchReviewQueueCalls;
    final initialCapabilityFetches =
        repository.fetchProcessingCapabilitiesCalls;
    repository.jobSummaries[0] = idleSummary;
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 300));

    expect(repository.fetchReviewQueueCalls, greaterThan(initialReviewFetches));
    expect(
      repository.fetchProcessingCapabilitiesCalls,
      greaterThan(initialCapabilityFetches),
    );
    expect(find.text('The Troubadour'), findsNothing);
    expect(find.text('No active server processing jobs.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('first parent login creates a parent PIN', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(AppKeys.profileButton('parent-main')));
    await tester.pumpAndSettle();

    expect(find.text('Create parent PIN'), findsOneWidget);
    await tester.enterText(find.byKey(AppKeys.parentPinSetupField), '0000');
    await tester.enterText(find.byKey(AppKeys.parentPinConfirmField), '0000');
    await tester.tap(find.byKey(AppKeys.parentPinCreateButton));
    await pumpUntilFound(tester, find.byKey(AppKeys.parentHomeScreen));

    expect(AppConfig.verifyParentPin('0000'), isTrue);
    expect(find.byKey(AppKeys.parentHomeScreen), findsOneWidget);
  });

  testWidgets('parent can add a student profile for device pairing', (
    WidgetTester tester,
  ) async {
    await AppConfig.setParentPin('2468');
    await pumpApp(tester);
    await tester.tap(find.byKey(AppKeys.profileButton('parent-main')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(AppKeys.parentPinEntryField), '2468');
    await tester.tap(find.text('Unlock'));
    await pumpUntilFound(tester, find.byKey(AppKeys.parentHomeScreen));

    await tester.tap(find.text('Students'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AppKeys.parentAddStudentButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(AppKeys.parentStudentNameField), 'Kai');
    await tester.tap(find.byKey(AppKeys.parentCreateStudentButton));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.studentDevicePairingButton('student-kai')),
        findsOneWidget);
    expect(find.text('Pair Kai device'), findsOneWidget);
  });

  testWidgets('parent student libraries filter pushed pieces by student', (
    WidgetTester tester,
  ) async {
    await AppConfig.setParentPin('2468');
    await AppConfig.applyServerPairing(
      serverUrl: 'http://test-server',
      serverId: 'test-server',
      pairingToken: 'test-token',
    );
    final repository = _FakeServerPieceSyncRepository(
      allPieces: const [
        RemotePieceSummary(
          id: 'alyse-piece',
          title: 'Alyse Etude',
          status: 'approved',
          libraryStatus: 'ready',
          visibleToProfileIds: ['student-alyse'],
          primaryInstrument: 'Cello',
        ),
        RemotePieceSummary(
          id: 'kai-piece',
          title: 'Kai March',
          status: 'approved',
          libraryStatus: 'ready',
          visibleToProfileIds: ['student-kai'],
          primaryInstrument: 'Cello',
        ),
      ],
    );

    await pumpApp(tester, repository: repository);
    await tester.tap(find.byKey(AppKeys.profileButton('parent-main')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(AppKeys.parentPinEntryField), '2468');
    await tester.tap(find.text('Unlock'));
    await pumpUntilFound(tester, find.byKey(AppKeys.parentHomeScreen));

    await tester.tap(find.text('Students'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AppKeys.parentAddStudentButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(AppKeys.parentStudentNameField), 'Kai');
    await tester.tap(find.byKey(AppKeys.parentCreateStudentButton));
    await tester.pumpAndSettle();

    await pumpUntilFound(
      tester,
      find.byKey(AppKeys.parentStudentLibrarySelector('student-alyse')),
    );
    expect(find.text('Alyse library (1)'), findsOneWidget);
    expect(find.text('Alyse Etude'), findsOneWidget);
    expect(find.text('Kai March'), findsNothing);

    await tester.tap(
      find.byKey(AppKeys.parentStudentLibrarySelector('student-kai')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kai library (1)'), findsOneWidget);
    expect(find.text('Kai March'), findsOneWidget);
    expect(find.text('Alyse Etude'), findsNothing);
  });

  testWidgets('parent student libraries infer students from pushed assignments',
      (
    WidgetTester tester,
  ) async {
    await AppConfig.setParentPin('2468');
    await AppConfig.applyServerPairing(
      serverUrl: 'http://test-server',
      serverId: 'test-server',
      pairingToken: 'test-token',
    );
    final repository = _FakeServerPieceSyncRepository(
      allPieces: const [
        RemotePieceSummary(
          id: 'mira-piece',
          title: 'Mira Minuet',
          status: 'approved',
          libraryStatus: 'ready',
          visibleToProfileIds: ['student-mira'],
          primaryInstrument: 'Cello',
        ),
      ],
    );

    await pumpApp(tester, repository: repository);
    await tester.tap(find.byKey(AppKeys.profileButton('parent-main')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(AppKeys.parentPinEntryField), '2468');
    await tester.tap(find.text('Unlock'));
    await pumpUntilFound(tester, find.byKey(AppKeys.parentHomeScreen));

    await tester.tap(find.text('Students'));
    await tester.pumpAndSettle();
    await pumpUntilFound(
      tester,
      find.byKey(AppKeys.parentStudentLibrarySelector('student-mira')),
    );
    await tester.tap(
      find.byKey(AppKeys.parentStudentLibrarySelector('student-mira')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mira library (1)'), findsOneWidget);
    expect(find.text('Mira Minuet'), findsOneWidget);
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

  testWidgets('review screen hides OMR compare for backend candidates', (
    WidgetTester tester,
  ) async {
    debugUseReviewPdfPlaceholder = true;
    final reviewItem = _reviewEntry(
      candidateData: const {
        'piece_title': 'Canon',
        'summary': 'Review rendered output.',
        'provenance': 'audiveris_omr',
        'engine_name': 'audiveris',
        'raw_file_url': 'http://test-server/raw.pdf',
        'raw_content_type': 'application/pdf',
        'score_version_id': 'rendered-audiveris',
        'rendered_file_url': 'http://test-server/audiveris.pdf',
        'canonical_score_version_id': 'canonical-audiveris',
        'canonical_file_url': 'http://test-server/audiveris.musicxml',
        'render_validation_status': 'valid',
        'omr_candidates': [
          {
            'candidate_id': 'audiveris-candidate',
            'label': 'Audiveris candidate',
            'engine_name': 'audiveris',
            'score_version_id': 'rendered-audiveris',
            'rendered_file_url': 'http://test-server/audiveris.pdf',
            'canonical_score_version_id': 'canonical-audiveris',
            'canonical_file_url': 'http://test-server/audiveris.musicxml',
            'render_validation_status': 'valid',
          },
          {
            'candidate_id': 'homr-candidate',
            'label': 'HOMR candidate',
            'engine_name': 'homr',
            'score_version_id': 'rendered-homr',
            'rendered_file_url': 'http://test-server/homr.pdf',
            'canonical_score_version_id': 'canonical-homr',
            'canonical_file_url': 'http://test-server/homr.musicxml',
            'render_validation_status': 'valid',
          },
        ],
      },
    );

    await pumpReviewCompareScreen(tester, reviewItem);
    await pumpUntilFound(tester, find.text('Canon'));

    expect(find.text('Side-by-side compare'), findsOneWidget);
    expect(find.text('OMR compare'), findsNothing);
    expect(find.text('OMR candidate compare'), findsNothing);
    expect(find.text('HOMR candidate'), findsNothing);
  });

  testWidgets('review screen hides local LLM metadata review action', (
    WidgetTester tester,
  ) async {
    debugUseReviewPdfPlaceholder = true;
    final reviewItem = _reviewEntry(
      candidateData: const {
        'piece_title': 'Canon',
        'summary': 'Review rendered output.',
        'provenance': 'audiveris_omr',
        'raw_file_url': 'http://test-server/raw.pdf',
        'raw_content_type': 'application/pdf',
        'processing_stage': 'metadata_review_needed',
      },
    );

    await pumpReviewCompareScreen(tester, reviewItem);
    await pumpUntilFound(tester, find.text('Canon'));

    expect(find.text('Send to local LLM for metadata review'), findsNothing);
    expect(find.text('Send to LLM'), findsNothing);
    expect(find.text('Edit metadata'), findsOneWidget);
  });

  testWidgets('metadata review approval action is labeled Approve Metadata', (
    WidgetTester tester,
  ) async {
    debugUseReviewPdfPlaceholder = true;
    final reviewItem = _reviewEntry(
      candidateData: const {
        'piece_title': 'Canon',
        'summary': 'Review extracted metadata.',
        'raw_file_url': 'http://test-server/raw.pdf',
        'raw_content_type': 'application/pdf',
        'processing_stage': 'metadata_review_needed',
      },
    );

    await pumpReviewCompareScreen(tester, reviewItem);
    await pumpUntilFound(tester, find.text('Canon'));
    await scrollFirstListViewUntilFound(tester, find.text('Approve Metadata'));

    expect(find.text('Approve Metadata'), findsOneWidget);
    expect(find.text('Approve student PDF'), findsNothing);
  });

  testWidgets('metadata review advances while server approval is pending', (
    WidgetTester tester,
  ) async {
    debugUseReviewPdfPlaceholder = true;
    final approvalGate = Completer<void>();
    final firstItem = _reviewEntry(
      id: 'review-first',
      pieceId: 'piece-first',
      candidateData: const {
        'piece_title': 'First Etude',
        'summary': 'Review extracted metadata.',
        'raw_file_url': 'http://test-server/first.pdf',
        'raw_content_type': 'application/pdf',
        'processing_stage': 'metadata_review_needed',
      },
    );
    final secondItem = _reviewEntry(
      id: 'review-second',
      pieceId: 'piece-second',
      candidateData: const {
        'piece_title': 'Second Etude',
        'summary': 'Review extracted metadata.',
        'raw_file_url': 'http://test-server/second.pdf',
        'raw_content_type': 'application/pdf',
        'processing_stage': 'metadata_review_needed',
      },
    );
    final repository = _FakeServerPieceSyncRepository(
      reviewItems: [firstItem, secondItem],
      approveReviewGate: approvalGate,
    );

    await pumpReviewCompareScreen(tester, firstItem, repository: repository);
    await pumpUntilFound(tester, find.text('First Etude'));
    await tester.pump(const Duration(milliseconds: 200));
    await scrollFirstListViewUntilFound(tester, find.text('Approve Metadata'));
    await tester.tap(find.text('Approve Metadata'));
    await tester.pump();

    await pumpUntilFound(tester, find.text('Second Etude'));
    await tester.pumpAndSettle();

    expect(find.text('Second Etude'), findsOneWidget);
    expect(find.text('First Etude'), findsNothing);
    expect(repository.approvedReviewItemIds, ['review-first']);
    expect(approvalGate.isCompleted, isFalse);

    approvalGate.complete();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('metadata review restore reports server approval failure', (
    WidgetTester tester,
  ) async {
    debugUseReviewPdfPlaceholder = true;
    final firstItem = _reviewEntry(
      id: 'review-first',
      pieceId: 'piece-first',
      candidateData: const {
        'piece_title': 'First Etude',
        'summary': 'Review extracted metadata.',
        'raw_file_url': 'http://test-server/first.pdf',
        'raw_content_type': 'application/pdf',
        'processing_stage': 'metadata_review_needed',
      },
    );
    final secondItem = _reviewEntry(
      id: 'review-second',
      pieceId: 'piece-second',
      candidateData: const {
        'piece_title': 'Second Etude',
        'summary': 'Review extracted metadata.',
        'raw_file_url': 'http://test-server/second.pdf',
        'raw_content_type': 'application/pdf',
        'processing_stage': 'metadata_review_needed',
      },
    );
    final repository = _FakeServerPieceSyncRepository(
      reviewItems: [firstItem, secondItem],
      approveReviewError: StateError('approval failed'),
    );

    await pumpReviewCompareScreen(tester, firstItem, repository: repository);
    await pumpUntilFound(tester, find.text('First Etude'));
    await tester.pump(const Duration(milliseconds: 200));
    await scrollFirstListViewUntilFound(tester, find.text('Approve Metadata'));
    await tester.tap(find.text('Approve Metadata'));
    await tester.pump();
    await pumpUntilFound(tester, find.text('Second Etude'));
    await tester.pumpAndSettle();
    await pumpUntilFound(
      tester,
      find.textContaining('Unable to approve metadata'),
    );

    expect(repository.approvedReviewItemIds, ['review-first']);
    expect(
      find.textContaining('Unable to approve metadata'),
      findsOneWidget,
    );
  });

  testWidgets('review screen exposes human notation edit actions', (
    WidgetTester tester,
  ) async {
    debugUseReviewPdfPlaceholder = true;
    final reviewItem = _reviewEntry(
      candidateData: const {
        'piece_title': 'Canon',
        'summary': 'Review rendered output.',
        'provenance': 'audiveris_omr',
        'raw_file_url': 'http://test-server/raw.pdf',
        'raw_content_type': 'application/pdf',
        'score_version_id': 'rendered-audiveris',
        'rendered_file_url': 'http://test-server/audiveris.pdf',
        'canonical_score_version_id': 'canonical-audiveris',
        'canonical_file_url': 'http://test-server/audiveris.musicxml',
        'render_validation_status': 'valid',
      },
    );

    await AppConfig.applyServerPairing(
      serverUrl: 'http://test-server',
      serverId: 'test-server',
      pairingToken: 'test-token',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serverPieceSyncRepositoryProvider.overrideWith(
            (ref) => _FakeServerPieceSyncRepository(reviewItem: reviewItem),
          ),
        ],
        child: MaterialApp(
          home: ReviewCompareScreen(itemId: reviewItem.id),
        ),
      ),
    );
    await pumpUntilFound(tester, find.text('Canon'));
    await scrollFirstListViewUntilFound(
      tester,
      find.byKey(AppKeys.reviewOpenMuseScoreButton),
    );
    expect(find.byKey(AppKeys.reviewOpenMuseScoreButton), findsOneWidget);
    expect(find.text('Edit in MuseScore'), findsOneWidget);

    await scrollFirstListViewUntilFound(
      tester,
      find.byKey(AppKeys.reviewUploadEditedMusicXmlButton),
    );
    expect(
        find.byKey(AppKeys.reviewUploadEditedMusicXmlButton), findsOneWidget);
    expect(find.text('Upload edited MusicXML'), findsOneWidget);

    await scrollFirstListViewUntilFound(tester, find.text('Mark edit ready'));
    expect(find.text('Mark edit ready'), findsOneWidget);
    expect(find.text('Reject candidate'), findsNothing);
    expect(find.text('Correction JSON check'), findsNothing);
  });

  testWidgets('review screen hides stale local LLM notation outcome', (
    WidgetTester tester,
  ) async {
    debugUseReviewPdfPlaceholder = true;
    final reviewItem = _reviewEntry(
      candidateData: const {
        'piece_title': 'Canon',
        'summary': 'Review rendered output.',
        'provenance': 'audiveris_omr',
        'raw_file_url': 'http://test-server/raw.pdf',
        'raw_content_type': 'application/pdf',
        'score_version_id': 'rendered-audiveris',
        'rendered_file_url': 'http://test-server/audiveris.pdf',
        'canonical_score_version_id': 'canonical-audiveris',
        'canonical_file_url': 'http://test-server/audiveris.musicxml',
        'render_validation_status': 'valid',
        'llm_notation_review_status': 'metadata_or_layout_only',
        'llm_review_summary': 'Only a label cleanup was safe.',
        'llm_notation_findings': [
          {
            'measure_number': 4,
            'note_index': 2,
            'issue': 'Rest could not be matched safely.',
            'recommended_action': 'Parent should edit in MuseScore.',
          }
        ],
        'llm_tool_results': [
          {
            'name': 'replace_musicxml_text',
            'message': 'Part label cleanup.',
            'affects_notation': false,
          }
        ],
      },
    );

    await pumpReviewCompareScreen(tester, reviewItem);
    await pumpUntilFound(tester, find.text('Canon'));
    await scrollFirstListViewUntilFound(
      tester,
      find.byKey(AppKeys.reviewOpenMuseScoreButton),
    );

    expect(find.text('LLM notation check'), findsNothing);
    expect(find.text('Outcome: metadata/layout only'), findsNothing);
    expect(find.text('Only a label cleanup was safe.'), findsNothing);
    expect(find.textContaining('non-notation edit'), findsNothing);
    expect(find.text('Edit in MuseScore'), findsOneWidget);
  });

  testWidgets('processing settings hide and preserve experimental fields', (
    WidgetTester tester,
  ) async {
    await AppConfig.applyServerPairing(
      serverUrl: 'http://test-server',
      serverId: 'test-server',
      pairingToken: 'test-token',
    );
    final repository = _FakeServerPieceSyncRepository(
      processingSettings: ProcessingSettings(
        audiverisCliPath: 'C:/Tools/Audiveris/bin/audiveris.bat',
        homrCliPath: 'C:/Tools/HOMR/homr.exe',
        legatoCliPath: 'C:/Tools/LEGATO/legato.py',
        legatoModelPath: 'guangyangmusic/legato',
        musescoreCliPath: 'C:/Program Files/MuseScore 4/bin/MuseScore4.exe',
        ocrCliPath: 'C:/Program Files/Tesseract-OCR/tesseract.exe',
        localLlmProvider: 'lmstudio',
        localLlmBaseUrl: 'http://127.0.0.1:1234/v1',
        cloudEnabled: true,
        cloudProvider: 'custom',
        cloudModel: 'vision-model',
        cloudBaseUrl: 'http://cloud.example/v1',
        processingMode: 'device_workers',
        allowStubMusicXml: false,
        productionMode: true,
        updatedAt: DateTime(2026, 6, 11),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serverPieceSyncRepositoryProvider.overrideWith((ref) => repository),
          serverHealthProvider.overrideWith(
            (ref) async => const ServerHealthState(
              status: ServerHealthStatus.online,
              serverUrl: 'http://test-server',
              message: 'AZMusic server',
            ),
          ),
        ],
        child: const MaterialApp(home: ProcessingSettingsScreen()),
      ),
    );
    await pumpUntilFound(
      tester,
      find.byKey(AppKeys.parentProcessingSettingsScreen),
    );

    expect(find.text('HOMR CLI path'), findsNothing);
    expect(find.text('LEGATO runner path'), findsNothing);
    expect(find.text('Local inference'), findsNothing);
    expect(find.text('Experimental processing providers'), findsNothing);
    expect(find.textContaining('HOMR:'), findsNothing);
    expect(find.textContaining('LEGATO:'), findsNothing);
    expect(find.textContaining('Local LLM:'), findsNothing);
    expect(find.textContaining('Cloud LLM:'), findsNothing);

    await scrollFirstListViewUntilFound(tester, find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = repository.savedProcessingSettings!;
    expect(saved.processingMode, 'server_only');
    expect(saved.omrStrategy, 'audiveris_quality_sweep');
    expect(saved.homrCliPath, 'C:/Tools/HOMR/homr.exe');
    expect(saved.legatoCliPath, 'C:/Tools/LEGATO/legato.py');
    expect(saved.legatoModelPath, 'guangyangmusic/legato');
    expect(saved.localLlmProvider, 'lmstudio');
    expect(saved.localLlmBaseUrl, 'http://127.0.0.1:1234/v1');
    expect(saved.cloudEnabled, isTrue);
    expect(saved.cloudProvider, 'custom');
    expect(saved.cloudModel, 'vision-model');
    expect(saved.cloudBaseUrl, 'http://cloud.example/v1');
  });
}

ReviewQueueEntry _reviewEntry({
  String id = 'review-1',
  String pieceId = 'piece-1',
  String itemType = 'score_candidate',
  String title = 'Review reconstructed score',
  String description = 'Compare candidates.',
  String status = 'pending',
  required Map<String, dynamic> candidateData,
}) {
  return ReviewQueueEntry(
    id: id,
    pieceId: pieceId,
    itemType: itemType,
    title: title,
    description: description,
    status: status,
    createdAt: DateTime(2026, 6, 7),
    candidateData: candidateData,
  );
}

class _FakeServerPieceSyncRepository extends ServerPieceSyncRepository {
  _FakeServerPieceSyncRepository({
    this.allPieces = const <RemotePieceSummary>[],
    this.jobs = const <ServerJob>[],
    this.jobSummaries = const <ProcessingJobSummary>[
      ProcessingJobSummary(
        queuedCount: 0,
        runningCount: 0,
        failedCount: 0,
        succeededCount: 0,
        canceledCount: 0,
      ),
    ],
    this.reviewItems = const <ReviewQueueEntry>[],
    this.reviewItem,
    this.approveReviewGate,
    this.approveReviewError,
    ProcessingSettings? processingSettings,
  }) : processingSettings = processingSettings ??
            ProcessingSettings(
              processingMode: 'server_only',
              allowStubMusicXml: true,
              productionMode: false,
              updatedAt: DateTime(2026, 6, 11),
            );

  List<RemotePieceSummary> allPieces;
  final List<ServerJob> jobs;
  final List<ProcessingJobSummary> jobSummaries;
  final List<ReviewQueueEntry> reviewItems;
  final ReviewQueueEntry? reviewItem;
  final Completer<void>? approveReviewGate;
  final Object? approveReviewError;
  ProcessingSettings processingSettings;
  ProcessingSettings? savedProcessingSettings;
  final List<_PushCall> pushCalls = [];
  final List<String> approvedReviewItemIds = [];
  final List<String> downloadedUrls = [];
  int fetchAllPiecesCalls = 0;
  int fetchReviewQueueCalls = 0;
  int fetchReviewItemCalls = 0;
  int fetchProcessingCapabilitiesCalls = 0;

  @override
  Future<List<RemotePieceSummary>> fetchAssignedPieces(String profileId) async {
    return const [];
  }

  @override
  Future<List<RemotePieceSummary>> fetchAllPieces() async {
    fetchAllPiecesCalls += 1;
    return allPieces;
  }

  @override
  Future<List<ReviewQueueEntry>> fetchReviewQueue() async {
    fetchReviewQueueCalls += 1;
    return reviewItems;
  }

  @override
  Future<ProcessingCapabilities> fetchProcessingCapabilities() async {
    final summaryIndex = fetchProcessingCapabilitiesCalls < jobSummaries.length
        ? fetchProcessingCapabilitiesCalls
        : jobSummaries.length - 1;
    final jobSummary = jobSummaries[summaryIndex];
    fetchProcessingCapabilitiesCalls += 1;
    const executable = ProcessingExecutableStatus(
      name: 'Test executable',
      configured: true,
      available: true,
    );
    return ProcessingCapabilities(
      serverOnline: true,
      settings: processingSettings,
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
      jobSummary: jobSummary,
      warnings: const [],
    );
  }

  @override
  Future<ProcessingSettings> fetchProcessingSettings() async {
    return processingSettings;
  }

  @override
  Future<ProcessingSettings> updateProcessingSettings(
    ProcessingSettings settings,
  ) async {
    savedProcessingSettings = settings;
    processingSettings = settings;
    return settings;
  }

  @override
  Future<ProcessingValidation> validateProcessingSettings(
    ProcessingSettings settings,
  ) async {
    const executable = ProcessingExecutableStatus(
      name: 'Test executable',
      configured: true,
      available: true,
    );
    return const ProcessingValidation(
      valid: true,
      audiveris: executable,
      homr: executable,
      legato: executable,
      musescore: executable,
      ocr: executable,
      warnings: [],
    );
  }

  @override
  Future<GeminiOAuthStatus> fetchGeminiOAuthStatus() async {
    return const GeminiOAuthStatus(
      configured: false,
      connected: false,
      available: false,
      model: '',
    );
  }

  @override
  Future<ReviewQueueEntry> fetchReviewItem(String itemId) async {
    fetchReviewItemCalls += 1;
    final item = reviewItem;
    if (item != null && item.id == itemId) {
      return item;
    }
    for (final queuedItem in reviewItems) {
      if (queuedItem.id == itemId) {
        return queuedItem;
      }
    }
    throw UnimplementedError('No fake review item was provided for $itemId.');
  }

  @override
  Future<void> approveReviewItem(
    String itemId, {
    String? selectedCandidateId,
  }) async {
    approvedReviewItemIds.add(itemId);
    final gate = approveReviewGate;
    if (gate != null) {
      await gate.future;
    }
    final error = approveReviewError;
    if (error != null) {
      throw error;
    }
  }

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
    List<String> profileIds, {
    String mode = 'processed',
  }) async {
    pushCalls.add(_PushCall(serverPieceId, profileIds, mode));
    final existingPiece = allPieces.firstWhere(
      (piece) => piece.id == serverPieceId,
      orElse: () => RemotePieceSummary(
        id: serverPieceId,
        title: 'Ready Server Etude',
        status: 'approved',
        libraryStatus: 'ready',
        visibleToProfileIds: const [],
      ),
    );
    final visibleToProfileIds = {
      ...existingPiece.visibleToProfileIds,
      ...profileIds,
    }.toList(growable: false);
    final previousVisibleToProfileIds = existingPiece
        .previousVisibleToProfileIds
        .where((profileId) => !profileIds.contains(profileId))
        .toList(growable: false);
    final remotePiece = RemotePieceDetail(
      id: existingPiece.id,
      title: existingPiece.title,
      composer: existingPiece.composer,
      primaryInstrument: existingPiece.primaryInstrument,
      bookOrCollection: existingPiece.bookOrCollection,
      keySignature: existingPiece.keySignature,
      tempo: existingPiece.tempo,
      difficultyLevel: existingPiece.difficultyLevel,
      notes: existingPiece.notes,
      processedMetadata: existingPiece.processedMetadata,
      pieceKind: existingPiece.pieceKind,
      sourceBookId: existingPiece.sourceBookId,
      sourcePageStart: existingPiece.sourcePageStart,
      sourcePageEnd: existingPiece.sourcePageEnd,
      catalogMetadata: existingPiece.catalogMetadata,
      catalogSuggestions: existingPiece.catalogSuggestions,
      validationWarnings: existingPiece.validationWarnings,
      splitConfidence: existingPiece.splitConfidence,
      workflowClosed: existingPiece.workflowClosed,
      sourceContentSha256: existingPiece.sourceContentSha256,
      sourceBookFingerprint: existingPiece.sourceBookFingerprint,
      logicalPieceKey: existingPiece.logicalPieceKey,
      canonicalPieceId: existingPiece.canonicalPieceId,
      attemptStatus: existingPiece.attemptStatus,
      duplicateAttemptCount: existingPiece.duplicateAttemptCount,
      duplicateReason: existingPiece.duplicateReason,
      isDuplicateAttempt: existingPiece.isDuplicateAttempt,
      status: existingPiece.status,
      libraryStatus: existingPiece.libraryStatus,
      visibleToProfileIds: visibleToProfileIds,
      previousVisibleToProfileIds: previousVisibleToProfileIds,
      scoreVersions: const [],
    );
    allPieces = [
      RemotePieceSummary.fromDetail(remotePiece),
      ...allPieces.where((piece) => piece.id != serverPieceId),
    ];
    return remotePiece;
  }

  @override
  Future<List<ServerJob>> fetchJobs() async {
    return jobs;
  }

  @override
  Future<ServerJob> retryJob(String jobId) async {
    final job = jobs.firstWhere((item) => item.id == jobId);
    return ServerJob(
      id: job.id,
      pieceId: job.pieceId,
      pieceTitle: job.pieceTitle,
      pieceComposer: job.pieceComposer,
      pieceStatus: job.pieceStatus,
      jobType: job.jobType,
      status: 'queued',
      progress: 0,
      resultData: {
        ...job.resultData,
        'retry_count': 0,
        'manual_retry_count': 1,
      },
      createdAt: job.createdAt,
      updatedAt: DateTime(2026, 6, 5, 13),
    );
  }

  @override
  Future<Map<String, dynamic>> clearServerWorkflowData() async {
    return const {'status': 'cleared'};
  }

  @override
  Future<List<int>> downloadBytes(String url) async {
    downloadedUrls.add(url);
    return const [37, 80, 68, 70];
  }
}

class _PushCall {
  const _PushCall(this.pieceId, this.profileIds, this.mode);

  final String pieceId;
  final List<String> profileIds;
  final String mode;
}

class _FakeNetworkInfo implements NetworkInfo {
  @override
  Future<bool> get isConnected async => true;

  @override
  Stream<bool> get onConnectivityChanged => Stream<bool>.value(true);
}
