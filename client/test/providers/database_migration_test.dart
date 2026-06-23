import 'dart:io';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'package:azmusic/data/database/database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;
  late String dbPath;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('azmusic_db_migration_test_');
    dbPath = '${tempDir.path}/test_migration.sqlite';
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('database schema upgrade migrates version 1 to 2 successfully', () async {
    // 1. Manually create the stale SQLite database at version 1
    final rawDb = sqlite.sqlite3.open(dbPath);
    
    // Create old tables
    rawDb.execute('''
      CREATE TABLE IF NOT EXISTS annotation_layers (
        profile_id TEXT NOT NULL,
        score_version_id TEXT NOT NULL,
        page_number INTEGER NOT NULL,
        updated_at TEXT NOT NULL,
        payload TEXT NOT NULL,
        PRIMARY KEY (profile_id, score_version_id, page_number)
      );
    ''');
    
    rawDb.execute('''
      CREATE TABLE IF NOT EXISTS notes (
        id TEXT PRIMARY KEY,
        profile_id TEXT NOT NULL,
        piece_id TEXT NOT NULL,
        score_version_id TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        payload TEXT NOT NULL
      );
    ''');

    rawDb.execute('''
      CREATE TABLE IF NOT EXISTS library_entries (
        piece_id TEXT PRIMARY KEY,
        server_piece_id TEXT,
        updated_at TEXT NOT NULL,
        payload TEXT NOT NULL
      );
    ''');

    // Set schema version to 1 in SQLite user_version pragma
    rawDb.execute('PRAGMA user_version = 1;');
    
    rawDb.dispose();

    // 2. Open database with AppDatabase (Drift) which triggers migration to version 2
    final appDb = AppDatabase(dbPath: dbPath);
    
    // Force database initialization by performing a simple select
    await appDb.select(appDb.annotationLayers).get();

    // 3. Verify the tables and columns in the migrated database
    final rawDb2 = sqlite.sqlite3.open(dbPath);
    
    // Check user_version is now 2
    final userVersion = rawDb2.select('PRAGMA user_version;').first.columnAt(0) as int;
    expect(userVersion, 2);

    // Verify notes and library_entries tables are dropped
    final tablesResult = rawDb2.select("SELECT name FROM sqlite_master WHERE type='table';");
    final tableNames = tablesResult.map((row) => row.columnAt(0) as String).toList();
    expect(tableNames, isNot(contains('notes')));
    expect(tableNames, isNot(contains('library_entries')));

    // Verify annotation_layers has the new columns
    final colResult = rawDb2.select("PRAGMA table_info(annotation_layers);");
    final colNames = colResult.map((row) => row.columnAt(1) as String).toList();
    expect(colNames, contains('id'));
    expect(colNames, contains('strokes'));
    expect(colNames, contains('notes'));
    expect(colNames, contains('created_at'));
    expect(colNames, contains('updated_at'));
    expect(colNames, isNot(contains('payload')));

    rawDb2.dispose();
    await appDb.close();
  });
}
