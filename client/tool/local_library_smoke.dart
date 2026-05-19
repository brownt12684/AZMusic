import 'dart:io';

import 'package:azmusic/data/repositories/local_library_repository.dart';

Future<void> main() async {
  final appDirectory = await Directory.systemTemp.createTemp(
    'azmusic_local_library_smoke_',
  );

  try {
    final repository = LocalLibraryRepository(appDirectory: appDirectory);
    final importedEntry = await repository.importDemoScore();
    final library = await repository.loadLibrary();

    if (library.length != 1) {
      throw StateError(
        'Expected exactly one library entry after demo import, found ${library.length}.',
      );
    }

    final reloadedEntry = library.single;
    final importedFile = File(importedEntry.primaryScore.filePath);
    if (!importedFile.existsSync()) {
      throw StateError(
        'Expected imported demo score file to exist at ${importedFile.path}.',
      );
    }

    if (reloadedEntry.piece.title != 'AZMusic Sandbox Demo Score') {
      throw StateError(
        'Unexpected demo piece title: ${reloadedEntry.piece.title}.',
      );
    }

    stdout.writeln('local_library_smoke: ok');
    stdout.writeln('piece=${reloadedEntry.piece.title}');
    stdout.writeln('score=${reloadedEntry.primaryScore.filePath}');
  } finally {
    if (appDirectory.existsSync()) {
      await appDirectory.delete(recursive: true);
    }
  }
}
