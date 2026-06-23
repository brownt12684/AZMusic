import 'dart:io';

import 'package:azmusic/data/repositories/annotation_repository.dart';
import 'package:azmusic/domain/entities/annotation_layer.dart';
import 'package:azmusic/injection/container.dart';
import 'package:azmusic/presentation/providers/annotation_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('azmusic_annotation_provider_test_');
  });

  tearDown(() async {
    // Wait a brief moment for async ref.onDispose database close to complete
    await Future<void>.delayed(const Duration(milliseconds: 200));
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  test('annotation provider handles sequential strokes and database persistence', () async {
    final container = ProviderContainer(
      overrides: [
        appDirectoryProvider.overrideWith((ref) => tempDir),
      ],
    );
    addTearDown(container.dispose);

    const arg = (
      profileId: 'student-alyse',
      scoreVersionId: 'score-001',
      pageNumber: 2,
    );

    // 1. Initial State
    var state = await container.read(annotationPageProvider(arg).future);
    expect(state.strokes, isEmpty);
    expect(state.isDrawing, isFalse);

    final notifier = container.read(annotationPageProvider(arg).notifier);

    // 2. Toggle Drawing Mode
    notifier.setDrawing(true);
    state = container.read(annotationPageProvider(arg)).value!;
    expect(state.isDrawing, isTrue);

    // 3. Draw Stroke 1
    notifier.beginStroke();
    notifier.addPoint(const OffsetPoint(x: 0.1, y: 0.2));
    notifier.addPoint(const OffsetPoint(x: 0.3, y: 0.4));
    await notifier.commitStroke();

    state = container.read(annotationPageProvider(arg)).value!;
    expect(state.strokes, hasLength(1));
    expect(state.strokes[0].points, hasLength(2));

    // 4. Draw Stroke 2
    notifier.beginStroke();
    notifier.addPoint(const OffsetPoint(x: 0.5, y: 0.6));
    notifier.addPoint(const OffsetPoint(x: 0.7, y: 0.8));
    await notifier.commitStroke();

    state = container.read(annotationPageProvider(arg)).value!;
    expect(state.strokes, hasLength(2));
    expect(state.strokes[0].points, hasLength(2));
    expect(state.strokes[1].points, hasLength(2));

    // 5. Reload from DB (new container)
    final container2 = ProviderContainer(
      overrides: [
        appDirectoryProvider.overrideWith((ref) => tempDir),
      ],
    );
    addTearDown(container2.dispose);

    final state2 = await container2.read(annotationPageProvider(arg).future);
    expect(state2.strokes, hasLength(2));
  });
}
