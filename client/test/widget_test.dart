import 'dart:io';

import 'package:azmusic/app/app.dart';
import 'package:azmusic/app/app_keys.dart';
import 'package:azmusic/app/launch_options.dart';
import 'package:azmusic/data/repositories/server_piece_sync_repository.dart';
import 'package:azmusic/domain/entities/review_candidate_package.dart';
import 'package:azmusic/injection/container.dart';
import 'package:azmusic/presentation/providers/review_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
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
      seedDemoLibrary: false,
      resetLibraryOnLaunch: false,
      initialSurface: AppLaunchSurface.login,
    ),
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDirectoryProvider.overrideWith((ref) => tempDir),
          launchOptionsProvider.overrideWith((ref) => launchOptions),
          serverPieceSyncRepositoryProvider.overrideWith(
            (ref) => _FakeServerPieceSyncRepository(),
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

  testWidgets('student login opens the library shell', (WidgetTester tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(AppKeys.profileButton('student-alyse')));
    await pumpUntilFound(tester, find.byKey(AppKeys.libraryScreen));

    expect(find.byKey(AppKeys.libraryScreen), findsOneWidget);
    expect(find.byKey(AppKeys.libraryStatusBanner), findsOneWidget);
    expect(find.byKey(AppKeys.librarySearchField), findsOneWidget);
    expect(find.text("Alyse's library"), findsOneWidget);
  });

  testWidgets('parent login opens the review-focused home', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(AppKeys.profileButton('parent-main')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '1357');
    await tester.tap(find.text('Unlock'));
    await pumpUntilFound(tester, find.byKey(AppKeys.parentHomeScreen));

    expect(find.byKey(AppKeys.parentHomeScreen), findsOneWidget);
    expect(find.byKey(AppKeys.parentReviewCard), findsOneWidget);
    expect(find.byKey(AppKeys.parentImportButton), findsOneWidget);
    expect(find.text('Intake and push'), findsOneWidget);
  });

  testWidgets('shows sandbox launcher actions', (WidgetTester tester) async {
    await pumpApp(
      tester,
      launchOptions: const AppLaunchOptions(
        sandboxMode: true,
        seedDemoLibrary: false,
        resetLibraryOnLaunch: false,
        initialSurface: AppLaunchSurface.sandbox,
      ),
    );
    await pumpUntilFound(tester, find.byKey(AppKeys.sandboxLoadDemoButton));

    expect(find.byKey(AppKeys.sandboxLauncherScreen), findsOneWidget);
    expect(find.byKey(AppKeys.sandboxLoadDemoButton), findsOneWidget);
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
        seedDemoLibrary: true,
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
  @override
  Future<List<RemotePieceSummary>> fetchAssignedPieces(String profileId) async {
    return const [];
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
  Future<RemotePieceDetail> pushPieceToProfiles(
    String serverPieceId,
    List<String> profileIds,
  ) async {
    throw UnimplementedError('Push is not used in widget tests.');
  }
}
