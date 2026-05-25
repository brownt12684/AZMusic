import 'dart:convert';
import 'dart:io';

import 'package:uuid/uuid.dart';

import '../database/database.dart';
import '../../domain/entities/note_entry.dart';

class NoteRepository {
  NoteRepository({
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

  Future<List<NoteEntry>> loadNotes({
    required String profileId,
    required String pieceId,
    required String scoreVersionId,
  }) async {
    final sqliteNotes = await _database.loadNotes(
      profileId: profileId,
      pieceId: pieceId,
      scoreVersionId: scoreVersionId,
    );
    if (sqliteNotes.isNotEmpty) {
      return sqliteNotes;
    }

    final file = await _notebookFile(
      profileId: profileId,
      pieceId: pieceId,
      scoreVersionId: scoreVersionId,
    );
    if (!await file.exists()) {
      return const <NoteEntry>[];
    }

    final rawJson = await file.readAsString();
    if (rawJson.trim().isEmpty) {
      return const <NoteEntry>[];
    }

    final decoded = json.decode(rawJson) as List<dynamic>;
    final notes = decoded
        .map((item) => NoteEntry.fromJson(item as Map<String, dynamic>))
        .toList();
    notes.sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    for (final note in notes) {
      await _database.upsertNote(note);
    }
    return notes;
  }

  Future<NoteEntry> addNote({
    required String profileId,
    required String pieceId,
    required String scoreVersionId,
    required String text,
    int? pageNumber,
  }) async {
    final now = DateTime.now();
    final note = NoteEntry(
      id: _uuid.v4(),
      profileId: profileId,
      pieceId: pieceId,
      scoreVersionId: scoreVersionId,
      text: text.trim(),
      pageNumber: pageNumber,
      createdAt: now,
      updatedAt: now,
    );
    await _database.upsertNote(note);
    return note;
  }

  Future<void> updateNote({
    required String profileId,
    required String pieceId,
    required String scoreVersionId,
    required String noteId,
    required String text,
  }) async {
    final notes = await loadNotes(
      profileId: profileId,
      pieceId: pieceId,
      scoreVersionId: scoreVersionId,
    );
    for (final note in notes) {
      if (note.id == noteId) {
        await _database.upsertNote(
          note.copyWith(text: text.trim(), updatedAt: DateTime.now()),
        );
        return;
      }
    }
  }

  Future<void> deleteNote({
    required String profileId,
    required String pieceId,
    required String scoreVersionId,
    required String noteId,
  }) async {
    await _database.deleteNote(noteId);
  }

  Future<File> _notebookFile({
    required String profileId,
    required String pieceId,
    required String scoreVersionId,
  }) async {
    final directory = Directory(
      '${_appDirectory.path}${Platform.pathSeparator}library'
      '${Platform.pathSeparator}notes'
      '${Platform.pathSeparator}$profileId'
      '${Platform.pathSeparator}$pieceId',
    );
    await directory.create(recursive: true);
    return File(
        '${directory.path}${Platform.pathSeparator}$scoreVersionId.json');
  }
}
