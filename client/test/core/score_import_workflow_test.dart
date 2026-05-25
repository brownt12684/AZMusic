import 'dart:convert';
import 'dart:io';

import 'package:azmusic/core/import/score_import_picker.dart';
import 'package:azmusic/core/import/score_import_workflow.dart';
import 'package:azmusic/data/repositories/local_library_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;
  late LocalLibraryRepository repository;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('azmusic_import_workflow_');
    repository = LocalLibraryRepository(appDirectory: tempDir);
  });

  tearDown(() async {
    await repository.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<File> createSamplePngFile() async {
    final file =
        File('${tempDir.path}${Platform.pathSeparator}sample_score.png');
    await file.writeAsBytes(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9WnSUs8AAAAASUVORK5CYII=',
      ),
      flush: true,
    );
    return file;
  }

  test('canceling import leaves the library unchanged', () async {
    final workflow = ScoreImportWorkflow(
      picker: _FakeScoreImportPicker([null]),
      repository: repository,
    );

    final entry = await workflow.importPickedScore();

    expect(entry, isNull);
    expect(await repository.loadLibrary(), isEmpty);
  });

  test('importing an image score persists it locally', () async {
    final imageFile = await createSamplePngFile();
    final workflow = ScoreImportWorkflow(
      picker: _FakeScoreImportPicker([imageFile.path]),
      repository: repository,
    );

    final entry = await workflow.importPickedScore();
    final reloadedRepository = LocalLibraryRepository(appDirectory: tempDir);
    final entries = await reloadedRepository.loadLibrary();
    await reloadedRepository.close();

    expect(entry, isNotNull);
    expect(entries, hasLength(1));
    expect(entries.single.piece.title, 'sample score');
    expect(File(entries.single.primaryScore.filePath).existsSync(), isTrue);
  });
}

class _FakeScoreImportPicker implements ScoreImportPicker {
  _FakeScoreImportPicker(List<String?> responses)
      : _responses = List<String?>.of(responses);

  final List<String?> _responses;

  @override
  Future<String?> pickScorePath() async {
    if (_responses.isEmpty) {
      return null;
    }

    return _responses.removeAt(0);
  }
}
