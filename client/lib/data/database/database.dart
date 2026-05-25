import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:sqlite3/sqlite3.dart';

import '../../domain/entities/annotation_layer.dart';
import '../../domain/entities/library_entry.dart';
import '../../domain/entities/note_entry.dart';

class AppDatabase {
  AppDatabase({required this.dbPath});

  final String dbPath;
  Database? _db;

  Future<Database> open() async {
    final existing = _db;
    if (existing != null) {
      return existing;
    }

    final file = File(dbPath);
    await file.parent.create(recursive: true);
    final database = sqlite3.open(dbPath);
    _db = database;
    _createSchema(database);
    return database;
  }

  Future<void> close() async {
    _db?.dispose();
    _db = null;
  }

  Future<List<LibraryEntry>> loadLibraryEntries() async {
    final database = await open();
    final rows = database.select(
      'SELECT payload FROM library_entries ORDER BY updated_at DESC',
    );
    return rows
        .map(
          (row) => LibraryEntry.fromJson(
            json.decode(row['payload'] as String) as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<void> replaceLibraryEntries(List<LibraryEntry> entries) async {
    final database = await open();
    database.execute('BEGIN IMMEDIATE');
    try {
      database.execute('DELETE FROM library_entries');
      final statement = database.prepare(
        'INSERT INTO library_entries(piece_id, server_piece_id, updated_at, payload) '
        'VALUES (?, ?, ?, ?)',
      );
      try {
        for (final entry in entries) {
          statement.execute([
            entry.piece.id,
            entry.piece.serverPieceId,
            entry.piece.updatedAt.toIso8601String(),
            json.encode(entry.toJson()),
          ]);
        }
      } finally {
        statement.dispose();
      }
      database.execute('COMMIT');
    } catch (_) {
      database.execute('ROLLBACK');
      rethrow;
    }
  }

  Future<void> upsertLibraryEntry(LibraryEntry entry) async {
    final entries = await loadLibraryEntries();
    final nextEntries = entries
        .where((existing) => existing.piece.id != entry.piece.id)
        .toList();
    nextEntries.insert(0, entry);
    await replaceLibraryEntries(nextEntries);
  }

  Future<LibraryEntry?> findLibraryEntry(String pieceId) async {
    final database = await open();
    final rows = database.select(
      'SELECT payload FROM library_entries WHERE piece_id = ? LIMIT 1',
      [pieceId],
    );
    if (rows.isEmpty) {
      return null;
    }
    return LibraryEntry.fromJson(
      json.decode(rows.first['payload'] as String) as Map<String, dynamic>,
    );
  }

  Future<LibraryEntry?> findLibraryEntryByServerPieceId(
    String serverPieceId,
  ) async {
    final database = await open();
    final rows = database.select(
      'SELECT payload FROM library_entries WHERE server_piece_id = ? LIMIT 1',
      [serverPieceId],
    );
    if (rows.isEmpty) {
      return null;
    }
    return LibraryEntry.fromJson(
      json.decode(rows.first['payload'] as String) as Map<String, dynamic>,
    );
  }

  Future<void> clearLibrary() async {
    final database = await open();
    database.execute('DELETE FROM library_entries');
  }

  Future<void> migrateLibraryJsonIfNeeded(File indexFile) async {
    final database = await open();
    final migrated = _meta(database, 'library_json_migrated') == '1';
    if (migrated || !await indexFile.exists()) {
      return;
    }
    final rawJson = await indexFile.readAsString();
    if (rawJson.trim().isEmpty) {
      _setMeta(database, 'library_json_migrated', '1');
      return;
    }
    final decoded = json.decode(rawJson) as List<dynamic>;
    final entries = decoded
        .map((item) => LibraryEntry.fromJson(item as Map<String, dynamic>))
        .toList();
    await replaceLibraryEntries(entries);
    final backupFile = File('${indexFile.path}.migrated-backup');
    if (!await backupFile.exists()) {
      await indexFile.copy(backupFile.path);
    }
    _setMeta(database, 'library_json_migrated', '1');
  }

  Future<AnnotationLayer?> loadAnnotationLayer({
    required String profileId,
    required String scoreVersionId,
    required int pageNumber,
  }) async {
    final database = await open();
    final rows = database.select(
      'SELECT payload FROM annotation_layers '
      'WHERE profile_id = ? AND score_version_id = ? AND page_number = ? '
      'LIMIT 1',
      [profileId, scoreVersionId, pageNumber],
    );
    if (rows.isEmpty) {
      return null;
    }
    return AnnotationLayer.fromJson(
      json.decode(rows.first['payload'] as String) as Map<String, dynamic>,
    );
  }

  Future<void> upsertAnnotationLayer({
    required String profileId,
    required AnnotationLayer layer,
  }) async {
    final database = await open();
    database.execute(
      'INSERT INTO annotation_layers(profile_id, score_version_id, page_number, updated_at, payload) '
      'VALUES (?, ?, ?, ?, ?) '
      'ON CONFLICT(profile_id, score_version_id, page_number) DO UPDATE SET '
      'updated_at = excluded.updated_at, payload = excluded.payload',
      [
        profileId,
        layer.scoreVersionId,
        layer.pageNumber,
        layer.updatedAt.toIso8601String(),
        json.encode(layer.toJson()),
      ],
    );
  }

  Future<void> deleteAnnotationLayer({
    required String profileId,
    required String scoreVersionId,
    required int pageNumber,
  }) async {
    final database = await open();
    database.execute(
      'DELETE FROM annotation_layers '
      'WHERE profile_id = ? AND score_version_id = ? AND page_number = ?',
      [profileId, scoreVersionId, pageNumber],
    );
  }

  Future<List<NoteEntry>> loadNotes({
    required String profileId,
    required String pieceId,
    required String scoreVersionId,
  }) async {
    final database = await open();
    final rows = database.select(
      'SELECT payload FROM notes '
      'WHERE profile_id = ? AND piece_id = ? AND score_version_id = ? '
      'ORDER BY updated_at DESC',
      [profileId, pieceId, scoreVersionId],
    );
    return rows
        .map(
          (row) => NoteEntry.fromJson(
            json.decode(row['payload'] as String) as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<void> upsertNote(NoteEntry note) async {
    final database = await open();
    database.execute(
      'INSERT INTO notes(id, profile_id, piece_id, score_version_id, updated_at, payload) '
      'VALUES (?, ?, ?, ?, ?, ?) '
      'ON CONFLICT(id) DO UPDATE SET updated_at = excluded.updated_at, payload = excluded.payload',
      [
        note.id,
        note.profileId,
        note.pieceId,
        note.scoreVersionId,
        note.updatedAt.toIso8601String(),
        json.encode(note.toJson()),
      ],
    );
  }

  Future<void> deleteNote(String noteId) async {
    final database = await open();
    database.execute('DELETE FROM notes WHERE id = ?', [noteId]);
  }

  String? _meta(Database database, String key) {
    final rows = database.select(
      'SELECT value FROM metadata WHERE key = ? LIMIT 1',
      [key],
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['value'] as String?;
  }

  void _setMeta(Database database, String key, String value) {
    database.execute(
      'INSERT INTO metadata(key, value) VALUES (?, ?) '
      'ON CONFLICT(key) DO UPDATE SET value = excluded.value',
      [key, value],
    );
  }

  void _createSchema(Database database) {
    database.execute('PRAGMA foreign_keys = ON');
    database.execute('''
      CREATE TABLE IF NOT EXISTS metadata (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
    database.execute('''
      CREATE TABLE IF NOT EXISTS library_entries (
        piece_id TEXT PRIMARY KEY,
        server_piece_id TEXT,
        updated_at TEXT NOT NULL,
        payload TEXT NOT NULL
      )
    ''');
    database.execute(
      'CREATE INDEX IF NOT EXISTS ix_library_entries_server_piece_id '
      'ON library_entries(server_piece_id)',
    );
    database.execute('''
      CREATE TABLE IF NOT EXISTS annotation_layers (
        profile_id TEXT NOT NULL,
        score_version_id TEXT NOT NULL,
        page_number INTEGER NOT NULL,
        updated_at TEXT NOT NULL,
        payload TEXT NOT NULL,
        PRIMARY KEY(profile_id, score_version_id, page_number)
      )
    ''');
    database.execute('''
      CREATE TABLE IF NOT EXISTS notes (
        id TEXT PRIMARY KEY,
        profile_id TEXT NOT NULL,
        piece_id TEXT NOT NULL,
        score_version_id TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        payload TEXT NOT NULL
      )
    ''');
    database.execute(
      'CREATE INDEX IF NOT EXISTS ix_notes_scope '
      'ON notes(profile_id, piece_id, score_version_id)',
    );
  }
}

String defaultDatabasePath(Directory appDirectory) {
  return path.join(appDirectory.path, 'azmusic.sqlite');
}
