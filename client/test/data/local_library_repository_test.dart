import 'dart:convert';
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
    await repository.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<File> createSamplePdfFile({String name = 'sample_score.pdf'}) async {
    final file = File('${tempDir.path}${Platform.pathSeparator}$name');
    await file.writeAsBytes(const <int>[37, 80, 68, 70], flush: true);
    return file;
  }

  test('imports and persists a pdf score locally', () async {
    final sourceFile = await createSamplePdfFile();
    final importedEntry = await repository.importScore(
      sourcePath: sourceFile.path,
    );
    final reloadedLibrary = await repository.loadLibrary();
    final databaseFile = File(
      '${tempDir.path}${Platform.pathSeparator}azmusic.sqlite',
    );

    expect(reloadedLibrary, hasLength(1));
    expect(reloadedLibrary.single.piece.title, 'sample score');
    expect(File(importedEntry.primaryScore.filePath).existsSync(), isTrue);
    expect(databaseFile.existsSync(), isTrue);
  });

  test('student imports start as upload pending with a visible raw score',
      () async {
    final sourceFile = await createSamplePdfFile(name: 'student_study.pdf');
    final importedEntry = await repository.importScoreForProfile(
      sourcePath: sourceFile.path,
      assignedProfileId: 'student-alyse',
    );

    expect(importedEntry.piece.libraryStatus.name, 'uploadPending');
    expect(importedEntry.primaryScore.versionType, 'raw');
    expect(importedEntry.primaryScore.isPrimary, isTrue);
    expect(importedEntry.primaryScore.isStudentVisible, isTrue);
  });

  test('approved replacement keeps raw fallback visible and musicxml hidden',
      () async {
    final sourceFile = await createSamplePdfFile(name: 'approved_study.pdf');
    final importedEntry = await repository.importScoreForProfile(
      sourcePath: sourceFile.path,
      assignedProfileId: 'student-alyse',
    );

    await repository.importServerScoreVersion(
      localPieceId: importedEntry.piece.id,
      bytes: const <int>[37, 80, 68, 70],
      fileExtension: '.pdf',
      title: 'Approved processed score',
      format: 'pdf',
      remoteUrl: 'https://example.test/files/approved.pdf',
      versionType: 'approved',
      makePrimary: true,
      isStudentVisible: true,
      hideExistingStudentVisible: false,
    );
    await repository.importServerScoreVersion(
      localPieceId: importedEntry.piece.id,
      bytes: utf8.encode('<score-partwise version="4.0"></score-partwise>'),
      fileExtension: '.musicxml',
      title: 'Approved MusicXML',
      format: 'musicxml',
      remoteUrl: 'https://example.test/files/approved.musicxml',
      versionType: 'approved',
      makePrimary: false,
      isStudentVisible: false,
    );

    final reloadedEntry = await repository.findEntry(importedEntry.piece.id);
    expect(reloadedEntry, isNotNull);
    expect(reloadedEntry!.scoreVersions, hasLength(3));
    expect(reloadedEntry.primaryScore.remoteUrl,
        'https://example.test/files/approved.pdf');

    final rawVersion = reloadedEntry.scoreVersions.firstWhere(
      (scoreVersion) => scoreVersion.versionType == 'raw',
    );
    final musicXmlVersion = reloadedEntry.scoreVersions.firstWhere(
      (scoreVersion) => scoreVersion.format == 'musicxml',
    );

    expect(rawVersion.isStudentVisible, isTrue);
    expect(rawVersion.isPrimary, isFalse);
    expect(musicXmlVersion.isStudentVisible, isFalse);
    expect(musicXmlVersion.isPrimary, isFalse);
  });
}
