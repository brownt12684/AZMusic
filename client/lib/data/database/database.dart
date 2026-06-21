import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;

import '../../domain/entities/annotation_layer.dart';
import '../../domain/entities/library_entry.dart';
import '../../domain/entities/note_entry.dart';
import '../../domain/entities/piece.dart';
import '../../domain/entities/practice_recording.dart';
import '../../domain/entities/score_version.dart';
import 'tables.dart'
    show
        Profiles,
        Pieces,
        ScoreVersions,
        AnnotationLayers,
        AnnotationStrokes,
        AnnotationNotes,
        MediaAssets,
        MediaMatchCandidates,
        ProcessingJobs,
        ReviewItems,
        PieceHistoryDrafts,
        SyncStates,
        PracticeRecordings;

part 'database.g.dart';

/// Returns the default database path inside [appDirectory].
String defaultDatabasePath(Directory appDirectory) {
  return p.join(appDirectory.path, 'azmusic.sqlite');
}

@DriftDatabase(
  tables: [
    Profiles,
    Pieces,
    ScoreVersions,
    AnnotationLayers,
    AnnotationStrokes,
    AnnotationNotes,
    MediaAssets,
    MediaMatchCandidates,
    ProcessingJobs,
    ReviewItems,
    PieceHistoryDrafts,
    SyncStates,
    PracticeRecordings,
  ],
  daos: [
    AppDatabaseDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase({required String dbPath}) : super(_openConnection(dbPath));

  static QueryExecutor _openConnection(String dbPath) {
    return LazyDatabase(() async => NativeDatabase(File(dbPath)));
  }

  @override
  int get schemaVersion => 1;

  // ─── Profiles ──────────────────────────────────────────────────────────────

  Future<List<ProfileRow>> loadProfiles() {
    return select(profiles).get();
  }

  Future<ProfileRow?> loadProfile(String id) {
    return (select(profiles)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Not used by active code paths. Stub.
  Future<void> upsertProfile(Object profile) => throw UnimplementedError('upsertProfile');

  // ─── Pieces ────────────────────────────────────────────────────────────────

  Future<List<PieceRow>> loadPieces() {
    return select(pieces).get();
  }

  Future<PieceRow?> findPiece(String id) {
    return (select(pieces)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Not used by active code paths. Stub.
  Future<void> upsertPiece(Piece piece) => throw UnimplementedError('upsertPiece');

  // ─── ScoreVersions ─────────────────────────────────────────────────────────

  Future<List<ScoreVersion>> loadScoreVersionsForPiece(String pieceId) async {
    final rows = await (select(scoreVersions)
          ..where((t) => t.pieceId.equals(pieceId)))
        .get();
    return rows.map(_scoreVersionFromRow).toList();
  }

  /// Not used by active code paths. Stub.
  Future<void> upsertScoreVersion(ScoreVersion sv) =>
      throw UnimplementedError('upsertScoreVersion');

  // ─── Library entries (composite of Piece + ScoreVersions) ──────────────────

  Future<List<LibraryEntry>> loadLibraryEntries() async {
    final pieceRows = await select(pieces).get();
    final result = <LibraryEntry>[];
    for (final pieceRow in pieceRows) {
      final versions = await loadScoreVersionsForPiece(pieceRow.id);
      result.add(LibraryEntry(
        piece: _pieceFromRow(pieceRow),
        scoreVersions: versions,
      ));
    }
    return result;
  }

  Future<void> replaceLibraryEntries(List<LibraryEntry> entries) async {
    await transaction(() async {
      await deleteAllPieces();
      for (final entry in entries) {
        final piece = entry.piece;
        await into(pieces).insert(
          PiecesCompanion.insert(
            id: piece.id,
            title: piece.title,
            composer: Value(piece.composer),
            serverPieceId: Value(piece.serverPieceId),
            assignedProfileId: Value(piece.assignedProfileId),
            visibleToProfileIds: jsonEncode(piece.visibleToProfileIds),
            previousVisibleToProfileIds:
                Value(piece.previousVisibleToProfileIds.isEmpty
                    ? null
                    : jsonEncode(piece.previousVisibleToProfileIds)),
            primaryInstrument: Value(piece.primaryInstrument),
            bookOrCollection: Value(piece.bookOrCollection),
            libraryStatus: _libraryStatusName(piece.libraryStatus),
            normalizedTitle: piece.normalizedTitle,
            normalizedComposer:
                Value(piece.normalizedComposer?.toLowerCase()),
            sortTitle: piece.sortTitle.toLowerCase(),
            sortComposer: Value(piece.sortComposer?.toLowerCase()),
            opus: Value(piece.opus),
            movement: Value(piece.movement),
            keySignature: Value(piece.keySignature),
            tempo: Value(piece.tempo),
            difficulty: Value(piece.difficulty),
            genre: Value(piece.genre),
            notes: Value(piece.notes),
            processedMetadata:
                Value(jsonEncode(piece.processedMetadata)),
            pieceKind: Value(piece.pieceKind),
            sourceBookId: Value(piece.sourceBookId),
            sourcePageStart: Value(piece.sourcePageStart),
            sourcePageEnd: Value(piece.sourcePageEnd),
            catalogMetadata:
                Value(jsonEncode(piece.catalogMetadata)),
            catalogSuggestions:
                Value(jsonEncode(piece.catalogSuggestions)),
            validationWarnings:
                Value(jsonEncode(piece.validationWarnings)),
            splitConfidence: Value(piece.splitConfidence),
            sourceContentSha256: Value(piece.sourceContentSha256),
            workflowClosed: Value(piece.workflowClosed),
            createdAt: piece.createdAt,
            updatedAt: piece.updatedAt,
          ),
        );
        for (final sv in entry.scoreVersions) {
          await into(scoreVersions).insert(
            ScoreVersionsCompanion.insert(
              id: sv.id,
              pieceId: sv.pieceId,
              title: sv.title,
              filePath: sv.filePath,
              remoteUrl: Value(sv.remoteUrl),
              versionType: Value(sv.versionType),
              format: sv.format,
              pageCount: Value(sv.pageCount),
              checksum: Value(sv.checksum),
              isPrimary: sv.isPrimary,
              isStudentVisible: sv.isStudentVisible,
              createdAt: sv.createdAt,
              updatedAt: sv.updatedAt,
            ),
          );
        }
      }
    });
  }

  Future<void> clearLibrary() async {
    await transaction(() async {
      await deleteAllPieces();
    });
  }

  Future<void> upsertLibraryEntry(LibraryEntry entry) async {
    final piece = entry.piece;
    await into(pieces).insertOnConflictUpdate(
      PiecesCompanion.insert(
        id: piece.id,
        title: piece.title,
        composer: Value(piece.composer),
        serverPieceId: Value(piece.serverPieceId),
        assignedProfileId: Value(piece.assignedProfileId),
        visibleToProfileIds: jsonEncode(piece.visibleToProfileIds),
        previousVisibleToProfileIds:
            Value(piece.previousVisibleToProfileIds.isEmpty
                ? null
                : jsonEncode(piece.previousVisibleToProfileIds)),
        primaryInstrument: Value(piece.primaryInstrument),
        bookOrCollection: Value(piece.bookOrCollection),
        libraryStatus: _libraryStatusName(piece.libraryStatus),
        normalizedTitle: piece.normalizedTitle,
        normalizedComposer:
            Value(piece.normalizedComposer?.toLowerCase()),
        sortTitle: piece.sortTitle.toLowerCase(),
        sortComposer: Value(piece.sortComposer?.toLowerCase()),
        opus: Value(piece.opus),
        movement: Value(piece.movement),
        keySignature: Value(piece.keySignature),
        tempo: Value(piece.tempo),
        difficulty: Value(piece.difficulty),
        genre: Value(piece.genre),
        notes: Value(piece.notes),
        processedMetadata: Value(jsonEncode(piece.processedMetadata)),
        pieceKind: Value(piece.pieceKind),
        sourceBookId: Value(piece.sourceBookId),
        sourcePageStart: Value(piece.sourcePageStart),
        sourcePageEnd: Value(piece.sourcePageEnd),
        catalogMetadata: Value(jsonEncode(piece.catalogMetadata)),
        catalogSuggestions:
            Value(jsonEncode(piece.catalogSuggestions)),
        validationWarnings:
            Value(jsonEncode(piece.validationWarnings)),
        splitConfidence: Value(piece.splitConfidence),
        sourceContentSha256: Value(piece.sourceContentSha256),
        workflowClosed: Value(piece.workflowClosed),
        createdAt: piece.createdAt,
        updatedAt: piece.updatedAt,
      ),
    );

    for (final sv in entry.scoreVersions) {
      await into(scoreVersions).insertOnConflictUpdate(
        ScoreVersionsCompanion.insert(
          id: sv.id,
          pieceId: sv.pieceId,
          title: sv.title,
          filePath: sv.filePath,
          remoteUrl: Value(sv.remoteUrl),
          versionType: Value(sv.versionType),
          format: sv.format,
          pageCount: Value(sv.pageCount),
          checksum: Value(sv.checksum),
          isPrimary: sv.isPrimary,
          isStudentVisible: sv.isStudentVisible,
          createdAt: sv.createdAt,
          updatedAt: sv.updatedAt,
        ),
      );
    }
  }

  Future<void> deleteLibraryEntry(String pieceId) async {
    await transaction(() async {
      await (delete(scoreVersions)
            ..where((t) => t.pieceId.equals(pieceId)))
          .go();
      await (delete(pieces)..where((t) => t.id.equals(pieceId))).go();
    });
  }

  Future<LibraryEntry?> findLibraryEntry(String pieceId) async {
    final pieceRow = await findPiece(pieceId);
    if (pieceRow == null) return null;
    final versions = await loadScoreVersionsForPiece(pieceRow.id);
    return LibraryEntry(
      piece: _pieceFromRow(pieceRow),
      scoreVersions: versions,
    );
  }

  Future<LibraryEntry?> findLibraryEntryByServerPieceId(
      String serverPieceId) async {
    final row = await (select(pieces)
          ..where((t) => t.serverPieceId.equals(serverPieceId)))
        .getSingleOrNull();
    if (row == null) return null;
    final versions = await loadScoreVersionsForPiece(row.id);
    return LibraryEntry(
      piece: _pieceFromRow(row),
      scoreVersions: versions,
    );
  }

  Future<void> migrateLibraryJsonIfNeeded(File indexFile) async {
    // No-op if the legacy JSON migration is not needed.
    // This method exists for compatibility with existing repositories.
  }

  Future<void> deleteAllPieces() async {
    await transaction(() async {
      final allPieceRows = await select(pieces).get();
      for (final pieceRow in allPieceRows) {
        await (delete(scoreVersions)
              ..where((t) => t.pieceId.equals(pieceRow.id)))
            .go();
      }
      await delete(pieces).go();
    });
  }

  // ─── AnnotationLayers ──────────────────────────────────────────────────────

  Future<AnnotationLayer?> loadAnnotationLayer({
    required String profileId,
    required String scoreVersionId,
    required int pageNumber,
  }) async {
    final row = await (select(annotationLayers)
          ..where((t) =>
              t.profileId.equals(profileId) &
              t.scoreVersionId.equals(scoreVersionId) &
              t.pageNumber.equals(pageNumber)))
        .getSingleOrNull();
    if (row == null) return null;
    return _annotationLayerFromRow(row);
  }

  Future<void> upsertAnnotationLayer({
    required String profileId,
    required AnnotationLayer layer,
  }) async {
    final existing = await loadAnnotationLayer(
      profileId: profileId,
      scoreVersionId: layer.scoreVersionId,
      pageNumber: layer.pageNumber,
    );
    if (existing != null) {
      await (update(annotationLayers)
            ..where((t) => t.id.equals(layer.id)))
          .write(AnnotationLayersCompanion(
        strokes: Value(
            jsonEncode(layer.strokes.map((s) => s.toMap()).toList())),
        notes:
            Value(jsonEncode(layer.notes.map((n) => n.toMap()).toList())),
        updatedAt: Value(layer.updatedAt),
      ));
    } else {
      await into(annotationLayers).insert(
        AnnotationLayersCompanion.insert(
          id: layer.id,
          profileId: profileId,
          scoreVersionId: layer.scoreVersionId,
          pageNumber: layer.pageNumber,
          strokes:
              jsonEncode(layer.strokes.map((s) => s.toMap()).toList()),
          notes: jsonEncode(layer.notes.map((n) => n.toMap()).toList()),
          createdAt: layer.createdAt,
          updatedAt: layer.updatedAt,
        ),
      );
    }
  }

  Future<void> deleteAnnotationLayer({
    required String profileId,
    required String scoreVersionId,
    required int pageNumber,
  }) async {
    final row = await loadAnnotationLayer(
      profileId: profileId,
      scoreVersionId: scoreVersionId,
      pageNumber: pageNumber,
    );
    if (row != null) {
      await (delete(annotationLayers)..where((t) => t.id.equals(row.id)))
          .go();
    }
  }

  // ─── Notes ─────────────────────────────────────────────────────────────────

  Future<List<NoteEntry>> loadNotes({
    required String profileId,
    required String pieceId,
    required String scoreVersionId,
  }) async {
    // Notes are stored as part of annotation layers in this simplified schema.
    // For now, return empty list; the note_repository handles JSON fallback.
    return const [];
  }

  Future<void> upsertNote(NoteEntry note) async {
    // Store notes via annotation layer mechanism for simplicity.
    final existing = await (select(annotationLayers)
          ..where((t) =>
              t.profileId.equals(note.profileId) &
              t.scoreVersionId.equals(note.scoreVersionId)))
        .getSingleOrNull();
    if (existing != null) {
      // Append note to existing layer's notes JSON.
      final currentNotes = jsonDecode(existing.notes) as List<dynamic>;
      currentNotes.add(note.toJson());
      await (update(annotationLayers)
            ..where((t) => t.id.equals(existing.id)))
          .write(AnnotationLayersCompanion(
        notes: Value(jsonEncode(currentNotes)),
        updatedAt: Value(DateTime.now()),
      ));
    }
  }

  Future<void> deleteNote(String noteId) async {
    // No-op in simplified schema; actual deletion handled by JSON fallback.
  }

  // ─── PracticeRecordings ────────────────────────────────────────────────────

  Future<List<PracticeRecording>> listPracticeRecordings({
    required String pieceId,
    required String profileId,
  }) async {
    final rows = await (select(practiceRecordings)
          ..where((t) =>
              t.pieceId.equals(pieceId) & t.profileId.equals(profileId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
    return rows.map(_practiceRecordingFromRow).toList();
  }

  Future<PracticeRecording> savePracticeRecording({
    required String id,
    required String pieceId,
    required String profileId,
    String? scoreVersionId,
    required String filePath,
    required int durationMs,
    bool isSentToTeacher = false,
  }) async {
    final now = DateTime.now();
    await into(practiceRecordings).insert(
      PracticeRecordingsCompanion.insert(
        id: id,
        pieceId: pieceId,
        profileId: profileId,
        scoreVersionId: Value(scoreVersionId),
        filePath: filePath,
        durationMs: durationMs,
        createdAt: now,
        isSentToTeacher: Value(isSentToTeacher),
      ),
    );
    return PracticeRecording(
      id: id,
      pieceId: pieceId,
      profileId: profileId,
      scoreVersionId: scoreVersionId,
      filePath: filePath,
      durationMs: durationMs,
      createdAt: now,
      isSentToTeacher: isSentToTeacher,
    );
  }

  Future<void> updatePracticeRecordingStatus(String id, bool isSentToTeacher) async {
    await (update(practiceRecordings)..where((t) => t.id.equals(id))).write(
      PracticeRecordingsCompanion(isSentToTeacher: Value(isSentToTeacher)),
    );
  }

  Future<void> deletePracticeRecording(String recordingId) async {
    await (delete(practiceRecordings)
          ..where((t) => t.id.equals(recordingId)))
        .go();
  }

  // ─── helpers ───────────────────────────────────────────────────────────────

  /// Maps a Drift [PieceRow] to the domain [Piece] entity.
  Piece _pieceFromRow(PieceRow row) {
    return Piece(
      id: row.id,
      title: row.title,
      composer: row.composer,
      serverPieceId: row.serverPieceId,
      assignedProfileId: row.assignedProfileId,
      visibleToProfileIds:
          (jsonDecode(row.visibleToProfileIds) as List<dynamic>)
              .map((e) => e as String)
              .toList(),
      previousVisibleToProfileIds: row.previousVisibleToProfileIds != null
          ? (jsonDecode(row.previousVisibleToProfileIds!) as List<dynamic>)
              .map((e) => e as String)
              .toList()
          : const <String>[],
      primaryInstrument: row.primaryInstrument,
      bookOrCollection: row.bookOrCollection,
      libraryStatus: _parseLibraryStatus(row.libraryStatus),
      normalizedTitle: row.normalizedTitle,
      normalizedComposer: row.normalizedComposer,
      sortTitle: row.sortTitle,
      sortComposer: row.sortComposer,
      opus: row.opus,
      movement: row.movement,
      keySignature: row.keySignature,
      tempo: row.tempo,
      difficulty: row.difficulty,
      genre: row.genre,
      notes: row.notes,
      processedMetadata: row.processedMetadata != null
          ? Map<String, dynamic>.from(
              jsonDecode(row.processedMetadata!) as Map)
          : const <String, dynamic>{},
      pieceKind: row.pieceKind,
      sourceBookId: row.sourceBookId,
      sourcePageStart: row.sourcePageStart,
      sourcePageEnd: row.sourcePageEnd,
      catalogMetadata: row.catalogMetadata != null
          ? Map<String, dynamic>.from(
              jsonDecode(row.catalogMetadata!) as Map)
          : const <String, dynamic>{},
      catalogSuggestions: row.catalogSuggestions != null
          ? (jsonDecode(row.catalogSuggestions!) as List<dynamic>)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : const <Map<String, dynamic>>[],
      validationWarnings: row.validationWarnings != null
          ? (jsonDecode(row.validationWarnings!) as List<dynamic>)
              .map((e) => e.toString())
              .toList()
          : const <String>[],
      splitConfidence: row.splitConfidence,
      sourceContentSha256: row.sourceContentSha256,
      workflowClosed: row.workflowClosed,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  /// Maps a Drift [ScoreVersionRow] to the domain [ScoreVersion] entity.
  ScoreVersion _scoreVersionFromRow(ScoreVersionRow row) {
    return ScoreVersion(
      id: row.id,
      pieceId: row.pieceId,
      title: row.title,
      filePath: row.filePath,
      remoteUrl: row.remoteUrl,
      versionType: row.versionType,
      format: row.format,
      pageCount: row.pageCount,
      checksum: row.checksum,
      isPrimary: row.isPrimary,
      isStudentVisible: row.isStudentVisible,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  /// Maps a Drift [AnnotationLayerRow] to the domain [AnnotationLayer] entity.
  AnnotationLayer _annotationLayerFromRow(AnnotationLayerRow row) {
    final strokes = (jsonDecode(row.strokes) as List<dynamic>)
        .map((s) => AnnotationStroke.fromMap(s as Map<String, dynamic>))
        .toList();
    final notes = (jsonDecode(row.notes) as List<dynamic>)
        .map((n) => AnnotationNote.fromMap(n as Map<String, dynamic>))
        .toList();
    return AnnotationLayer(
      id: row.id,
      scoreVersionId: row.scoreVersionId,
      pageNumber: row.pageNumber,
      strokes: strokes,
      notes: notes,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  /// Maps a Drift [PracticeRecordingRow] to the domain [PracticeRecording] entity.
  PracticeRecording _practiceRecordingFromRow(PracticeRecordingRow row) {
    return PracticeRecording(
      id: row.id,
      pieceId: row.pieceId,
      profileId: row.profileId,
      scoreVersionId: row.scoreVersionId,
      filePath: row.filePath,
      durationMs: row.durationMs,
      createdAt: row.createdAt,
      isSentToTeacher: row.isSentToTeacher,
    );
  }

  String _libraryStatusName(LibraryStatus status) => status.name;

  LibraryStatus _parseLibraryStatus(String name) {
    return LibraryStatus.values.firstWhere(
      (e) => e.name == name,
      orElse: () => LibraryStatus.intake,
    );
  }
}

// ─── DAO for practice recordings ─────────────────────────────────────────────

@DriftAccessor(tables: [PracticeRecordings])
class AppDatabaseDao extends DatabaseAccessor<AppDatabase>
    with _$AppDatabaseDaoMixin {
  AppDatabaseDao(super.db);
}
