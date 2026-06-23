import 'dart:io';

import 'package:azmusic/data/repositories/annotation_repository.dart';
import 'package:azmusic/domain/entities/annotation_layer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;
  late AnnotationRepository repository;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('azmusic_annotations_test_');
    repository = AnnotationRepository(appDirectory: tempDir);
  });

  tearDown(() async {
    await repository.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('saves, reloads, and clears page markup', () async {
    const stroke1 = AnnotationStroke(
      id: 'stroke-1',
      color: StrokeColor.orange,
      strokeWidth: 3,
      points: [
        OffsetPoint(x: 0.1, y: 0.2),
        OffsetPoint(x: 0.5, y: 0.6),
      ],
      tool: StrokeTool.pen,
    );

    final savedLayer1 = await repository.saveLayer(
      profileId: 'student-alyse',
      scoreVersionId: 'score-001',
      pageNumber: 2,
      strokes: [stroke1],
    );

    var reloadedLayer = await repository.loadLayer(
      profileId: 'student-alyse',
      scoreVersionId: 'score-001',
      pageNumber: 2,
    );

    expect(savedLayer1.pageNumber, 2);
    expect(reloadedLayer, isNotNull);
    expect(reloadedLayer!.strokes, hasLength(1));
    expect(reloadedLayer.strokes.first.id, 'stroke-1');

    const stroke2 = AnnotationStroke(
      id: 'stroke-2',
      color: StrokeColor.blue,
      strokeWidth: 4,
      points: [
        OffsetPoint(x: 0.3, y: 0.4),
        OffsetPoint(x: 0.7, y: 0.8),
      ],
      tool: StrokeTool.pen,
    );

    final savedLayer2 = await repository.saveLayer(
      profileId: 'student-alyse',
      scoreVersionId: 'score-001',
      pageNumber: 2,
      strokes: [stroke1, stroke2],
    );

    reloadedLayer = await repository.loadLayer(
      profileId: 'student-alyse',
      scoreVersionId: 'score-001',
      pageNumber: 2,
    );

    expect(reloadedLayer, isNotNull);
    expect(reloadedLayer!.strokes, hasLength(2));
    expect(reloadedLayer.strokes[0].id, 'stroke-1');
    expect(reloadedLayer.strokes[1].id, 'stroke-2');

    await repository.clearLayer(
      profileId: 'student-alyse',
      scoreVersionId: 'score-001',
      pageNumber: 2,
    );

    final clearedLayer = await repository.loadLayer(
      profileId: 'student-alyse',
      scoreVersionId: 'score-001',
      pageNumber: 2,
    );

    expect(clearedLayer, isNull);
  });
}
