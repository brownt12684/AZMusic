import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

import '../../core/error/errors.dart';
import '../database/database.dart';
import '../../domain/entities/library_entry.dart';
import '../../domain/entities/piece.dart';
import '../../domain/entities/score_version.dart';

class LocalLibraryRepository {
  LocalLibraryRepository({
    required Directory appDirectory,
    AppDatabase? database,
    Uuid? uuid,
  })  : _appDirectory = appDirectory,
        _database =
            database ?? AppDatabase(dbPath: defaultDatabasePath(appDirectory)),
        _uuid = uuid ?? const Uuid();

  final Directory _appDirectory;
  final AppDatabase _database;
  final Uuid _uuid;

  Future<void> close() => _database.close();

  AppDatabase get db => _database;

  Future<List<LibraryEntry>> loadLibrary() async {
    print('DEBUG: loadLibrary inside repository starting');
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      print('DEBUG: checking legacy migration...');
      await _database.migrateLibraryJsonIfNeeded(await _indexFile());
    }
    print('DEBUG: calling database.loadLibraryEntries...');
    final entries = await _database.loadLibraryEntries();
    print('DEBUG: database.loadLibraryEntries finished, count: ${entries.length}');
    entries.sort(
      (left, right) => right.piece.updatedAt.compareTo(left.piece.updatedAt),
    );
    print('DEBUG: loadLibrary inside repository finishing');
    return entries;
  }

  Future<LibraryEntry> importScore({required String sourcePath}) async {
    return importScoreForProfile(sourcePath: sourcePath);
  }

  Future<LibraryEntry> importScoreForProfile({
    required String sourcePath,
    String? assignedProfileId,
    String? composer,
    String? primaryInstrument,
    String? bookOrCollection,
    String pieceKind = 'piece',
  }) async {
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw FileError(
        message: 'The selected score file could not be found.',
        filePath: sourcePath,
      );
    }

    final format = _formatForExtension(path.extension(sourcePath));
    if (format == null) {
      throw FileError(
        message: 'Only PDF files and image scans are supported right now.',
        filePath: sourcePath,
      );
    }

    final importedAt = DateTime.now();
    final pieceId = _uuid.v4();
    final scoreVersionId = _uuid.v4();
    final destinationDirectory = await _scoreDirectory(pieceId);
    final destinationPath = path.join(
      destinationDirectory.path,
      '$scoreVersionId${path.extension(sourcePath).toLowerCase()}',
    );

    await sourceFile.copy(destinationPath);

    final title = _titleFromSourcePath(sourcePath);
    final sourceContentSha256 =
        (await sha256.bind(sourceFile.openRead()).first).toString();
    final piece = Piece(
      id: pieceId,
      title: title,
      composer: composer,
      assignedProfileId: assignedProfileId,
      visibleToProfileIds: assignedProfileId == null
          ? const <String>[]
          : <String>[assignedProfileId],
      primaryInstrument: primaryInstrument,
      bookOrCollection: bookOrCollection,
      pieceKind: pieceKind,
      sourceContentSha256: sourceContentSha256,
      libraryStatus: assignedProfileId == null
          ? LibraryStatus.intake
          : LibraryStatus.uploadPending,
      createdAt: importedAt,
      updatedAt: importedAt,
    );
    final scoreVersion = ScoreVersion(
      id: scoreVersionId,
      pieceId: pieceId,
      title: 'Original import',
      filePath: destinationPath,
      versionType: 'raw',
      format: format,
      pageCount: format == 'image' ? 1 : null,
      isPrimary: true,
      isStudentVisible: assignedProfileId != null,
      createdAt: importedAt,
      updatedAt: importedAt,
    );
    final entry = LibraryEntry(
      piece: piece,
      scoreVersions: [scoreVersion],
    );

    final entries = await loadLibrary();
    entries.insert(0, entry);
    await _database.replaceLibraryEntries(entries);
    return entry;
  }

  Future<LibraryEntry> importScoreToIntake({
    required String sourcePath,
    String? title,
    String? composer,
    String? primaryInstrument,
    String? bookOrCollection,
    String pieceKind = 'piece',
  }) async {
    final entry = await importScoreForProfile(
      sourcePath: sourcePath,
      composer: composer,
      primaryInstrument: primaryInstrument,
      bookOrCollection: bookOrCollection,
      pieceKind: pieceKind,
    );
    if (title == null || title.trim().isEmpty) {
      return entry;
    }
    final updated = LibraryEntry(
      piece: entry.piece.copyWith(
        title: title.trim(),
        normalizedTitle: title.trim().toLowerCase(),
        sortTitle: title.trim().toLowerCase(),
      ),
      scoreVersions: entry.scoreVersions,
    );
    await saveEntry(updated);
    return updated;
  }

  Future<void> clearLibrary() async {
    for (final relativePath in ['library', 'sandbox']) {
      final directory = Directory(path.join(_appDirectory.path, relativePath));
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    }
    await _database.clearLibrary();
  }

  Future<void> saveEntry(LibraryEntry entry) async {
    await _database.upsertLibraryEntry(entry);
  }

  Future<void> removeEntry(String pieceId) async {
    final scoreDirectory = Directory(
      path.join(_appDirectory.path, 'library', 'scores', pieceId),
    );
    if (await scoreDirectory.exists()) {
      await scoreDirectory.delete(recursive: true);
    }
    await _database.deleteLibraryEntry(pieceId);
  }

  Future<LibraryEntry?> findEntry(String pieceId) async {
    await _database.migrateLibraryJsonIfNeeded(await _indexFile());
    return _database.findLibraryEntry(pieceId);
  }

  Future<LibraryEntry?> findEntryByServerPieceId(String serverPieceId) async {
    await _database.migrateLibraryJsonIfNeeded(await _indexFile());
    return _database.findLibraryEntryByServerPieceId(serverPieceId);
  }

  Future<void> bindServerPieceId({
    required String localPieceId,
    required String serverPieceId,
    LibraryStatus? libraryStatus,
  }) async {
    final entry = await findEntry(localPieceId);
    if (entry == null) {
      return;
    }

    await saveEntry(
      LibraryEntry(
        piece: entry.piece.copyWith(
          serverPieceId: serverPieceId,
          libraryStatus: libraryStatus ?? entry.piece.libraryStatus,
          updatedAt: DateTime.now(),
        ),
        scoreVersions: entry.scoreVersions,
      ),
    );
  }

  Future<void> updatePiece(Piece piece) async {
    final entry = await findEntry(piece.id);
    if (entry == null) {
      return;
    }
    await saveEntry(
        LibraryEntry(piece: piece, scoreVersions: entry.scoreVersions));
  }

  Future<void> setPieceVisibility({
    required String localPieceId,
    required List<String> visibleToProfileIds,
    LibraryStatus? libraryStatus,
  }) async {
    final entry = await findEntry(localPieceId);
    if (entry == null) {
      return;
    }
    await updatePiece(
      entry.piece.copyWith(
        visibleToProfileIds: visibleToProfileIds,
        libraryStatus: libraryStatus ?? entry.piece.libraryStatus,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> appendScoreVersion({
    required String localPieceId,
    required ScoreVersion scoreVersion,
    bool makePrimary = false,
    bool hideExistingStudentVisible = false,
  }) async {
    final entry = await findEntry(localPieceId);
    if (entry == null) {
      return;
    }

    final nextVersions = entry.scoreVersions
        .where((version) => version.id != scoreVersion.id)
        .map((version) {
      var updatedVersion = version;
      if (makePrimary && updatedVersion.isPrimary) {
        updatedVersion = updatedVersion.copyWith(
          isPrimary: false,
          updatedAt: DateTime.now(),
        );
      }
      if (hideExistingStudentVisible && updatedVersion.isStudentVisible) {
        updatedVersion = updatedVersion.copyWith(
          isStudentVisible: false,
          updatedAt: DateTime.now(),
        );
      }
      return updatedVersion;
    }).toList();
    final normalizedScoreVersion = scoreVersion.copyWith(
      isPrimary: makePrimary || scoreVersion.isPrimary,
    );
    if (makePrimary) {
      nextVersions.add(normalizedScoreVersion);
    } else {
      nextVersions.insert(0, normalizedScoreVersion);
    }

    await saveEntry(
      LibraryEntry(
        piece: entry.piece.copyWith(updatedAt: DateTime.now()),
        scoreVersions: nextVersions,
      ),
    );
  }

  Future<ScoreVersion?> importServerScoreVersion({
    required String localPieceId,
    required List<int> bytes,
    required String fileExtension,
    required String title,
    required String format,
    required String remoteUrl,
    String? versionType,
    bool makePrimary = true,
    bool isStudentVisible = true,
    bool hideExistingStudentVisible = false,
  }) async {
    final entry = await findEntry(localPieceId);
    if (entry == null) {
      return null;
    }

    final scoreVersionId = _uuid.v4();
    final destinationDirectory = await _scoreDirectory(localPieceId);
    final normalizedExtension = fileExtension.startsWith('.')
        ? fileExtension.toLowerCase()
        : '.${fileExtension.toLowerCase()}';
    final destinationPath = path.join(
      destinationDirectory.path,
      '$scoreVersionId$normalizedExtension',
    );
    final destinationFile = File(destinationPath);
    await destinationFile.writeAsBytes(bytes, flush: true);

    final scoreVersion = ScoreVersion(
      id: scoreVersionId,
      pieceId: localPieceId,
      title: title,
      filePath: destinationPath,
      remoteUrl: remoteUrl,
      versionType: versionType,
      format: format,
      pageCount: format == 'image' ? 1 : null,
      isPrimary: makePrimary,
      isStudentVisible: isStudentVisible,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await appendScoreVersion(
      localPieceId: localPieceId,
      scoreVersion: scoreVersion,
      makePrimary: makePrimary,
      hideExistingStudentVisible: hideExistingStudentVisible,
    );
    return scoreVersion;
  }

  Future<LibraryEntry> createServerLinkedEntry({
    required String serverPieceId,
    required String title,
    String? composer,
    required List<String> visibleToProfileIds,
    List<String> previousVisibleToProfileIds = const <String>[],
    String? primaryInstrument,
    String? bookOrCollection,
    String? keySignature,
    String? tempo,
    String? difficulty,
    String? notes,
    Map<String, dynamic> processedMetadata = const <String, dynamic>{},
    String pieceKind = 'piece',
    String? sourceBookId,
    int? sourcePageStart,
    int? sourcePageEnd,
    Map<String, dynamic> catalogMetadata = const <String, dynamic>{},
    List<Map<String, dynamic>> catalogSuggestions =
        const <Map<String, dynamic>>[],
    List<String> validationWarnings = const <String>[],
    double? splitConfidence,
    bool workflowClosed = false,
    required LibraryStatus libraryStatus,
    required List<int> bytes,
    required String fileExtension,
    required String scoreTitle,
    required String format,
    required String remoteUrl,
    String? versionType,
    bool isPrimary = true,
    bool isStudentVisible = true,
  }) async {
    final importedAt = DateTime.now();
    final pieceId = _uuid.v4();
    final scoreVersionId = _uuid.v4();
    final destinationDirectory = await _scoreDirectory(pieceId);
    final normalizedExtension = fileExtension.startsWith('.')
        ? fileExtension.toLowerCase()
        : '.${fileExtension.toLowerCase()}';
    final destinationPath = path.join(
      destinationDirectory.path,
      '$scoreVersionId$normalizedExtension',
    );
    final destinationFile = File(destinationPath);
    await destinationFile.writeAsBytes(bytes, flush: true);

    final piece = Piece(
      id: pieceId,
      title: title,
      composer: composer,
      serverPieceId: serverPieceId,
      visibleToProfileIds: visibleToProfileIds,
      previousVisibleToProfileIds: previousVisibleToProfileIds,
      primaryInstrument: primaryInstrument,
      bookOrCollection: bookOrCollection,
      keySignature: keySignature,
      tempo: tempo,
      difficulty: difficulty,
      notes: notes,
      processedMetadata: processedMetadata,
      pieceKind: pieceKind,
      sourceBookId: sourceBookId,
      sourcePageStart: sourcePageStart,
      sourcePageEnd: sourcePageEnd,
      catalogMetadata: catalogMetadata,
      catalogSuggestions: catalogSuggestions,
      validationWarnings: validationWarnings,
      splitConfidence: splitConfidence,
      workflowClosed: workflowClosed,
      libraryStatus: libraryStatus,
      createdAt: importedAt,
      updatedAt: importedAt,
    );
    final scoreVersion = ScoreVersion(
      id: scoreVersionId,
      pieceId: pieceId,
      title: scoreTitle,
      filePath: destinationPath,
      remoteUrl: remoteUrl,
      versionType: versionType,
      format: format,
      pageCount: format == 'image' ? 1 : null,
      isPrimary: isPrimary,
      isStudentVisible: isStudentVisible,
      createdAt: importedAt,
      updatedAt: importedAt,
    );
    final entry = LibraryEntry(piece: piece, scoreVersions: [scoreVersion]);
    final entries = await loadLibrary();
    entries.insert(0, entry);
    await _database.replaceLibraryEntries(entries);
    return entry;
  }

  Future<File> _indexFile() async {
    final libraryDirectory = await _libraryDirectory();
    return File(path.join(libraryDirectory.path, 'library_index.json'));
  }

  Future<Directory> _libraryDirectory() async {
    final directory = Directory(path.join(_appDirectory.path, 'library'));
    await directory.create(recursive: true);
    return directory;
  }

  Future<Directory> _scoreDirectory(String pieceId) async {
    final directory = Directory(
      path.join(_appDirectory.path, 'library', 'scores', pieceId),
    );
    await directory.create(recursive: true);
    return directory;
  }

  String _titleFromSourcePath(String sourcePath) {
    final baseName = path.basenameWithoutExtension(sourcePath).trim();
    if (baseName.isEmpty) {
      return 'Imported score';
    }

    return baseName
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String? _formatForExtension(String extension) {
    switch (extension.toLowerCase()) {
      case '.pdf':
        return 'pdf';
      case '.png':
      case '.jpg':
      case '.jpeg':
      case '.webp':
        return 'image';
      default:
        return null;
    }
  }
}
