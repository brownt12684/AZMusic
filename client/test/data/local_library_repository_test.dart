import 'dart:io';

import 'package:azmusic/data/repositories/local_library_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;
  late LocalLibraryRepository repository;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('azmusic_library_test_');
    repository = LocalLibraryRepository(appDirectory: tempDir);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('imports and persists the demo score locally', () async {
    final importedEntry = await repository.importDemoScore();
    final reloadedLibrary = await repository.loadLibrary();
    final indexFile = File(
      '${tempDir.path}${Platform.pathSeparator}library${Platform.pathSeparator}library_index.json',
    );

    expect(reloadedLibrary, hasLength(1));
    expect(reloadedLibrary.single.piece.title, 'AZMusic Sandbox Demo Score');
    expect(File(importedEntry.primaryScore.filePath).existsSync(), isTrue);
    expect(indexFile.existsSync(), isTrue);
  });
}
