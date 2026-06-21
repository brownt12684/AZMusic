import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../database/database.dart';
import 'server_piece_sync_repository.dart';
import '../../domain/entities/practice_recording.dart';

/// Abstract contract for practice recording persistence.
abstract class RecordingRepository {
  /// Return all recordings for [pieceId]+[profileId], newest first.
  Future<List<PracticeRecording>> listForPiece({
    required String pieceId,
    required String profileId,
  });

  /// Persist a completed recording.
  /// [tempPath] – path written by the `record` package during capture.
  /// The file is moved into the managed recordings folder.
  Future<PracticeRecording> save({
    required String pieceId,
    required String profileId,
    String? scoreVersionId,
    required String tempPath,
    required int durationMs,
  });

  /// Delete the recording row and its audio file.
  Future<void> delete(String recordingId);

  /// Update the human label on a recording.
  Future<PracticeRecording> relabel(String recordingId, String label);

  /// Attempts to upload any unsynced recordings to the backend.
  Future<void> syncPendingRecordings();
}

/// Local implementation backed by Drift SQLite + filesystem.
class LocalRecordingRepository implements RecordingRepository {
  LocalRecordingRepository({
    required Directory appDocDir,
    AppDatabase? database,
    ServerPieceSyncRepository? syncRepository,
  })  : _db = database ?? AppDatabase(dbPath: defaultDatabasePath(appDocDir)),
        _syncRepo = syncRepository ?? ServerPieceSyncRepository(),
        _appDocDir = appDocDir;

  final AppDatabase _db;
  final Directory _appDocDir;
  final ServerPieceSyncRepository _syncRepo;

  /// Resolved directory: <appDocDir>/library/scores/<pieceId>/recordings/
  Directory _recordingDir(String pieceId) {
    return Directory(p.join(_appDocDir.path, 'library', 'scores', pieceId, 'recordings'));
  }

  @override
  Future<List<PracticeRecording>> listForPiece({
    required String pieceId,
    required String profileId,
  }) async {
    return _db.listPracticeRecordings(pieceId: pieceId, profileId: profileId);
  }

  @override
  Future<PracticeRecording> save({
    required String pieceId,
    required String profileId,
    String? scoreVersionId,
    required String tempPath,
    required int durationMs,
  }) async {
    final id = const Uuid().v4();
    final ext = p.extension(tempPath).isEmpty ? '.m4a' : p.extension(tempPath);
    final dir = _recordingDir(pieceId);
    await dir.create(recursive: true);
    final destPath = p.join(dir.path, '$id$ext');

    // Move temp file to managed location.
    final tempFile = File(tempPath);
    if (await tempFile.exists()) {
      await tempFile.copy(destPath);
      await _safeDelete(tempFile);
    }

    bool isSynced = false;
    try {
      await _syncRepo.uploadPracticeRecording(
        pieceId: pieceId,
        studentProfileId: profileId,
        filePath: destPath,
      );
      isSynced = true;
    } catch (_) {
      // Ignored: device is offline or server unavailable. Will retry later.
    }

    return _db.savePracticeRecording(
      id: id,
      pieceId: pieceId,
      profileId: profileId,
      scoreVersionId: scoreVersionId,
      filePath: destPath,
      durationMs: durationMs,
      isSentToTeacher: isSynced,
    );
  }

  @override
  Future<void> delete(String recordingId) async {
    await _db.deletePracticeRecording(recordingId);
  }

  @override
  Future<PracticeRecording> relabel(String recordingId, String label) {
    // No-op in simplified schema; labels not stored separately.
    throw UnimplementedError('relabel is not implemented');
  }

  @override
  Future<void> syncPendingRecordings() async {
    final pendingRows = await (_db.select(_db.practiceRecordings)
          ..where((t) => t.isSentToTeacher.equals(false)))
        .get();

    for (final row in pendingRows) {
      try {
        await _syncRepo.uploadPracticeRecording(
          pieceId: row.pieceId,
          studentProfileId: row.profileId,
          filePath: row.filePath,
        );
        await _db.updatePracticeRecordingStatus(row.id, true);
      } catch (_) {
        // Stop on first failure assuming network issues
        break;
      }
    }
  }

  /// Safely delete a file, ignoring errors if it doesn't exist.
  static Future<void> _safeDelete(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}
