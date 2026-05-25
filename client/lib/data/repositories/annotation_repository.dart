import 'dart:convert';
import 'dart:io';

import 'package:uuid/uuid.dart';

import '../database/database.dart';
import '../../domain/entities/annotation_layer.dart';

class AnnotationRepository {
  AnnotationRepository({
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

  Future<AnnotationLayer?> loadLayer({
    required String profileId,
    required String scoreVersionId,
    required int pageNumber,
  }) async {
    final sqliteLayer = await _database.loadAnnotationLayer(
      profileId: profileId,
      scoreVersionId: scoreVersionId,
      pageNumber: pageNumber,
    );
    if (sqliteLayer != null) {
      return sqliteLayer;
    }

    return _loadLegacyLayerFile(
      profileId: profileId,
      scoreVersionId: scoreVersionId,
      pageNumber: pageNumber,
    );
  }

  Future<AnnotationLayer> saveLayer({
    required String profileId,
    required String scoreVersionId,
    required int pageNumber,
    required List<AnnotationStroke> strokes,
  }) async {
    final existingLayer = await loadLayer(
      profileId: profileId,
      scoreVersionId: scoreVersionId,
      pageNumber: pageNumber,
    );
    final now = DateTime.now();
    final nextLayer = (existingLayer ??
            AnnotationLayer(
              id: _uuid.v4(),
              scoreVersionId: scoreVersionId,
              pageNumber: pageNumber,
              strokes: const <AnnotationStroke>[],
              notes: const <AnnotationNote>[],
              createdAt: now,
              updatedAt: now,
            ))
        .copyWith(
      strokes: strokes,
      updatedAt: now,
    );

    await _database.upsertAnnotationLayer(
      profileId: profileId,
      layer: nextLayer,
    );
    return nextLayer;
  }

  Future<void> clearLayer({
    required String profileId,
    required String scoreVersionId,
    required int pageNumber,
  }) async {
    await _database.deleteAnnotationLayer(
      profileId: profileId,
      scoreVersionId: scoreVersionId,
      pageNumber: pageNumber,
    );
    final file = _legacyLayerFile(
      profileId: profileId,
      scoreVersionId: scoreVersionId,
      pageNumber: pageNumber,
    );
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<AnnotationLayer?> _loadLegacyLayerFile({
    required String profileId,
    required String scoreVersionId,
    required int pageNumber,
  }) async {
    final file = _legacyLayerFile(
      profileId: profileId,
      scoreVersionId: scoreVersionId,
      pageNumber: pageNumber,
    );
    if (!await file.exists()) {
      return null;
    }
    final rawJson = await file.readAsString();
    if (rawJson.trim().isEmpty) {
      return null;
    }
    final layer = AnnotationLayer.fromJson(
      json.decode(rawJson) as Map<String, dynamic>,
    );
    await _database.upsertAnnotationLayer(profileId: profileId, layer: layer);
    return layer;
  }

  File _legacyLayerFile({
    required String profileId,
    required String scoreVersionId,
    required int pageNumber,
  }) {
    return File(
      '${_appDirectory.path}${Platform.pathSeparator}annotations'
      '${Platform.pathSeparator}$profileId'
      '${Platform.pathSeparator}$scoreVersionId'
      '${Platform.pathSeparator}page_$pageNumber.json',
    );
  }
}
