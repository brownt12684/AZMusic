import 'dart:io';

import 'package:azmusic/data/repositories/local_library_repository.dart';

Future<void> main() async {
  final appDirectory = await Directory.systemTemp.createTemp(
    'azmusic_local_library_smoke_',
  );

  try {
    final repository = LocalLibraryRepository(appDirectory: appDirectory);
    final sourceFile = File(
      '${appDirectory.path}${Platform.pathSeparator}smoke_score.pdf',
    );
    await sourceFile.writeAsBytes(const <int>[37, 80, 68, 70], flush: true);

    final importedEntry = await repository.importScore(
      sourcePath: sourceFile.path,
    );
    final library = await repository.loadLibrary();

    if (library.length != 1) {
      throw StateError(
        'Expected exactly one library entry after import, found ${library.length}.',
      );
    }

    final reloadedEntry = library.single;
    final importedFile = File(importedEntry.primaryScore.filePath);
    if (!importedFile.existsSync()) {
      throw StateError(
        'Expected imported score file to exist at ${importedFile.path}.',
      );
    }

    if (reloadedEntry.piece.title != 'smoke score') {
      throw StateError(
        'Unexpected piece title: ${reloadedEntry.piece.title}.',
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
