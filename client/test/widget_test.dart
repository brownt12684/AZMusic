import 'dart:io';

import 'package:azmusic/app/app.dart';
import 'package:azmusic/app/app_keys.dart';
import 'package:azmusic/app/launch_options.dart';
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
    ReviewQueueEntry reviewItem,
  ) async {
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
      AppKeys.pushToProfileButton('server-ready-piece', 'student-alyse'),
    );
    await scrollParentWorkflowUntilFound(tester, pushButton);
    await tester.tap(pushButton);
    await tester.pump();

    expect(repository.pushCalls, hasLength(1));
    expect(repository.pushCalls.single.pieceId, 'server-ready-piece');
    expect(repository.pushCalls.single.profileIds, ['student-alyse']);
  });

  testWidgets('parent workflow polls while server processing jobs are active', (
    WidgetTester tester,
  ) async {
    await AppConfig.setParentPin('2468');
    await AppConfig.applyServerPairing(
      serverUrl: 'http://test-server',
      serverId: 'test-server',
      pairingToken: 'test-token',
    );
    final repository = _FakeServerPieceSyncRepository(
      jobSummaries: const [
        ProcessingJobSummary(
          queuedCount: 2,
          runningCount: 1,
          failedCount: 0,
          succeededCount: 0,
          canceledCount: 0,
        ),
        ProcessingJobSummary(
          queuedCount: 1,
          runningCount: 1,
          failedCount: 0,
          succeededCount: 1,
          canceledCount: 0,
        ),
      ],
    );

    await pumpApp(tester, repository: repository);
    await tester.tap(find.byKey(AppKeys.profileButton('parent-main')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(AppKeys.parentPinEntryField), '2468');
    await tester.tap(find.text('Unlock'));
    await pumpUntilFound(tester, find.byKey(AppKeys.parentHomeScreen));

    final initialReviewFetches = repository.fetchReviewQueueCalls;
    final initialCapabilityFetches =
        repository.fetchProcessingCapabilitiesCalls;
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 300));

    expect(repository.fetchReviewQueueCalls, greaterThan(initialReviewFetches));
    expect(
      repository.fetchProcessingCapabilitiesCalls,
      greaterThan(initialCapabilityFetches),
    );

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
  required Map<String, dynamic> candidateData,
}) {
  return ReviewQueueEntry(
    id: 'review-1',
    pieceId: 'piece-1',
    itemType: 'score_candidate',
    title: 'Review reconstructed score',
    description: 'Compare candidates.',
    status: 'pending',
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
    this.reviewItem,
    ProcessingSettings? processingSettings,
  }) : processingSettings = processingSettings ??
            ProcessingSettings(
              processingMode: 'server_only',
              allowStubMusicXml: true,
              productionMode: false,
              updatedAt: DateTime(2026, 6, 11),
            );

  final List<RemotePieceSummary> allPieces;
  final List<ServerJob> jobs;
  final List<ProcessingJobSummary> jobSummaries;
  final ReviewQueueEntry? reviewItem;
  ProcessingSettings processingSettings;
  ProcessingSettings? savedProcessingSettings;
  final List<_PushCall> pushCalls = [];
  int fetchAllPiecesCalls = 0;
  int fetchReviewQueueCalls = 0;
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
    return const [];
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
    final item = reviewItem;
    if (item != null && item.id == itemId) {
      return item;
    }
    throw UnimplementedError('No fake review item was provided for $itemId.');
  }

  @override
  Future<void> approveReviewItem(
    String itemId, {
    String? selectedCandidateId,
  }) async {}

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
