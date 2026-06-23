import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../domain/entities/media_asset.dart';
import '../../domain/entities/youtube_candidate.dart';
import '../database/database.dart';

class MediaRepository {
  MediaRepository({
    ApiClient? apiClient,
    AppDatabase? database,
  })  : _apiClient = apiClient ?? ApiClient(),
        _db = database;

  final ApiClient _apiClient;
  final AppDatabase? _db;

  Future<List<YouTubeCandidate>> fetchCandidates(String pieceId) async {
    if (!AppConfig.isServerPaired) return const [];
    final response = await _apiClient.get('/api/v1/pieces/$pieceId/candidates');
    final items = response.data as List<dynamic>;
    return items
        .map((item) => YouTubeCandidate.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<YouTubeCandidate>> triggerSearch(String pieceId) async {
    if (!AppConfig.isServerPaired) return const [];
    final response = await _apiClient.post('/api/v1/pieces/$pieceId/search');
    final items = response.data as List<dynamic>;
    return items
        .map((item) => YouTubeCandidate.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<bool> pushMedia(String assetId) async {
    if (!AppConfig.isServerPaired) return false;
    try {
      await _apiClient.post('/api/v1/media/$assetId/push');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> revokeMedia(String assetId) async {
    if (!AppConfig.isServerPaired) return false;
    try {
      await _apiClient.post('/api/v1/media/$assetId/revoke');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Downloads the transcode file from the server and saves it to local app directory.
  Future<String> downloadMediaFile(String pieceId, String assetId, String format) async {
    final appDir = await getApplicationDocumentsDirectory();
    final localFolder = Directory(path.join(appDir.path, 'media'));
    if (!await localFolder.exists()) {
      await localFolder.create(recursive: true);
    }
    final extension = format.startsWith('.') ? format : '.$format';
    final localPath = path.join(localFolder.path, '$assetId$extension');

    await _apiClient.client.download(
      '/api/v1/media/$pieceId/$assetId/file',
      localPath,
    );
    return localPath;
  }

  /// Syncs delta from the server.
  Future<void> syncDeltaForPiece(String pieceId, AppDatabase db) async {
    if (!AppConfig.isServerPaired) return;
    
    // Check client last sync time. For simplicity, we query local database or use a default past date.
    // In practice, we query server-delta since epoch or 1970 to load everything.
    // Let's look up if there are already local assets for this piece. If none, last sync is epoch.
    final existing = await db.loadMediaAssetsForPiece(pieceId);
    final lastSync = existing.isEmpty 
        ? DateTime.fromMillisecondsSinceEpoch(0)
        : existing.map((e) => e.updatedAt).reduce((a, b) => a.isAfter(b) ? a : b);

    final response = await _apiClient.get(
      '/api/v1/pieces/$pieceId/sync-delta',
      queryParameters: {
        'client_last_sync': lastSync.toUtc().toIso8601String(),
      },
    );

    final data = Map<String, dynamic>.from(response.data as Map);
    final attachments = data['media_attachments'] as List<dynamic>;
    final deletions = data['media_deletions'] as List<dynamic>;

    // Handle deletions (revoked assets)
    for (final id in deletions) {
      final idStr = id as String;
      final localMatches = existing.where((e) => e.id == idStr);
      for (final match in localMatches) {
        try {
          final file = File(match.filePath);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {}
      }
      await db.deleteMediaAsset(idStr);
    }

    // Handle new/updated attachments
    for (final item in attachments) {
      final map = Map<String, dynamic>.from(item as Map);
      final assetId = map['id'] as String;
      final youtubeVideoId = map['youtube_video_id'] as String?;
      final format = map['format'] as String? ?? 'mp3';

      // Download the file from server
      final localPath = await downloadMediaFile(pieceId, assetId, format);

      final asset = MediaAsset(
        id: assetId,
        pieceId: pieceId,
        filePath: localPath,
        remoteUrl: youtubeVideoId != null ? 'https://youtube.com/watch?v=$youtubeVideoId' : null,
        format: format,
        durationMs: map['duration_ms'] as int?,
        fileSizeBytes: map['file_size_bytes'] as int?,
        thumbnailPath: map['thumbnail_url'] as String?,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await db.saveMediaAsset(asset);
    }
  }

  Future<bool> triggerRetroactiveSync() async {
    if (!AppConfig.isServerPaired) return false;
    try {
      await _apiClient.post('/api/v1/media/retroactive-sync');
      return true;
    } catch (_) {
      return false;
    }
  }
}

