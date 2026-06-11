import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;

import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../domain/entities/library_entry.dart';
import '../../domain/entities/processing_settings.dart';
import '../../domain/entities/review_candidate_package.dart';
import '../../domain/entities/server_pairing.dart';
import '../../domain/entities/server_job.dart';

class ServerPieceSyncRepository {
  ServerPieceSyncRepository({
    ApiClient? apiClient,
  }) : _apiClient = apiClient ?? ApiClient();

  static const Duration _metadataReviewTimeout = Duration(minutes: 2);
  static const Duration _scoreReviewTimeout = Duration(minutes: 6);
  static const Duration _scoreRenderTimeout = Duration(minutes: 4);

  final ApiClient _apiClient;

  Dio get client => _apiClient.client;

  Future<String?> uploadImportedPiece(LibraryEntry entry) async {
    if (!AppConfig.isServerPaired) {
      return null;
    }

    final rawScore = entry.scoreVersions.firstWhere(
      (scoreVersion) => scoreVersion.versionType == 'raw',
      orElse: () => entry.primaryScore,
    );
    final rawFormat = rawScore.format.toLowerCase();
    if (rawFormat != 'pdf' && rawFormat != 'image') {
      return null;
    }

    final formData = FormData.fromMap({
      'title': entry.piece.title,
      if (entry.piece.composer != null) 'composer': entry.piece.composer,
      if (entry.piece.primaryInstrument != null)
        'primary_instrument': entry.piece.primaryInstrument,
      if (entry.piece.bookOrCollection != null)
        'book_or_collection': entry.piece.bookOrCollection,
      if (entry.piece.pieceKind == 'book') 'catalog_mode': 'book',
      'file': await MultipartFile.fromFile(
        rawScore.filePath,
        filename: path.basename(rawScore.filePath),
      ),
    });

    final response =
        await _apiClient.post('/api/v1/pieces/import', data: formData);
    final data = Map<String, dynamic>.from(response.data as Map);
    return data['id'] as String?;
  }

  Future<List<RemotePieceSummary>> fetchAssignedPieces(String profileId) async {
    final response = await _apiClient.get('/api/v1/pieces/assigned/$profileId');
    final items = response.data as List<dynamic>;
    return items
        .map(
            (item) => RemotePieceSummary.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<RemotePieceSummary>> fetchAllPieces() async {
    final response = await _apiClient.get('/api/v1/pieces/');
    final items = response.data as List<dynamic>;
    return items
        .map(
            (item) => RemotePieceSummary.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<ReviewQueueEntry>> fetchReviewQueue() async {
    final response = await _apiClient.get('/api/v1/review/');
    final items = response.data as List<dynamic>;
    return items
        .map((item) => ReviewQueueEntry.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<ProcessingSettings> fetchProcessingSettings() async {
    final response = await _apiClient.get('/api/v1/processing/settings');
    return ProcessingSettings.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ProcessingSettings> updateProcessingSettings(
    ProcessingSettings settings,
  ) async {
    final response = await _apiClient.patch(
      '/api/v1/processing/settings',
      data: settings.toUpdateJson(),
    );
    return ProcessingSettings.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ProcessingValidation> validateProcessingSettings(
    ProcessingSettings settings,
  ) async {
    final response = await _apiClient.post(
      '/api/v1/processing/settings/validate',
      data: settings.toUpdateJson(),
    );
    return ProcessingValidation.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ProcessingCapabilities> fetchProcessingCapabilities() async {
    final response = await _apiClient.get('/api/v1/processing/capabilities');
    return ProcessingCapabilities.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<GeminiOAuthStatus> fetchGeminiOAuthStatus() async {
    final response =
        await _apiClient.get('/api/v1/processing/gemini/oauth/status');
    return GeminiOAuthStatus.fromJson(response.data as Map<String, dynamic>);
  }

  Future<GeminiOAuthStart> startGeminiOAuth() async {
    final response =
        await _apiClient.post('/api/v1/processing/gemini/oauth/start');
    return GeminiOAuthStart.fromJson(response.data as Map<String, dynamic>);
  }

  Future<GeminiOAuthStatus> installGeminiOAuthClientSecret(
    String filePath,
  ) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        filePath,
        filename: path.basename(filePath),
      ),
    });
    final response = await _apiClient.post(
      '/api/v1/processing/gemini/oauth/client-secret',
      data: formData,
    );
    return GeminiOAuthStatus.fromJson(response.data as Map<String, dynamic>);
  }

  Future<GeminiOAuthStatus> disconnectGeminiOAuth() async {
    final response =
        await _apiClient.post('/api/v1/processing/gemini/oauth/disconnect');
    return GeminiOAuthStatus.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<ServerJob>> fetchJobs() async {
    final response = await _apiClient.get('/api/v1/jobs/');
    final items = response.data as List<dynamic>;
    return items
        .map((item) => ServerJob.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<ServerJob> cancelJob(String jobId) async {
    final response = await _apiClient.post('/api/v1/jobs/$jobId/cancel');
    return ServerJob.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ServerJob> retryJob(String jobId) async {
    final response = await _apiClient.post('/api/v1/jobs/$jobId/retry');
    return ServerJob.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> clearServerWorkflowData() async {
    final response = await _apiClient.post('/api/v1/debug/clear-workflow');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> clearServerPieceWorkflowData(
    String serverPieceId,
  ) async {
    final response =
        await _apiClient.delete('/api/v1/debug/pieces/$serverPieceId');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<ServerPairingCode> fetchPairingCode({
    String purpose = 'student_device',
    String? profileId,
    String? profileName,
    String role = 'student',
  }) async {
    final response = await _apiClient.get(
      '/api/v1/pairing/code',
      queryParameters: {
        'purpose': purpose,
        if (profileId != null) 'profile_id': profileId,
        if (profileName != null) 'profile_name': profileName,
        'role': role,
      },
    );
    return ServerPairingCode.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ServerPairingClaim> claimPairingCode({
    required String pairingCode,
    required String deviceId,
    required String deviceName,
    required String platform,
  }) async {
    final response = await _apiClient.post(
      '/api/v1/pairing/claim',
      data: {
        'pairing_code': pairingCode,
        'device_id': deviceId,
        'device_name': deviceName,
        'platform': platform,
      },
    );
    return ServerPairingClaim.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ReviewQueueEntry> fetchReviewItem(String itemId) async {
    final response = await _apiClient.get('/api/v1/review/$itemId');
    return ReviewQueueEntry.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> approveReviewItem(
    String itemId, {
    String? selectedCandidateId,
  }) async {
    await _apiClient.post(
      '/api/v1/review/$itemId',
      data: {
        'action': 'approve',
        if (selectedCandidateId != null &&
            selectedCandidateId.trim().isNotEmpty)
          'selected_candidate_id': selectedCandidateId.trim(),
      },
    );
  }

  Future<void> rejectReviewItem(String itemId) async {
    await _apiClient.post('/api/v1/review/$itemId', data: {'action': 'reject'});
  }

  Future<ReviewBulkApprovalResult> approveBookReviewItems({
    String? sourceBookId,
    String? sourceReviewItemId,
    required String processingStage,
  }) async {
    final response = await _apiClient.post(
      '/api/v1/review/bulk/approve',
      data: {
        if (sourceBookId != null && sourceBookId.trim().isNotEmpty)
          'source_book_id': sourceBookId.trim(),
        if (sourceReviewItemId != null && sourceReviewItemId.trim().isNotEmpty)
          'source_review_item_id': sourceReviewItemId.trim(),
        'processing_stage': processingStage,
      },
    );
    return ReviewBulkApprovalResult.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<Map<String, dynamic>> requestReviewReprocess(
    String itemId, {
    String reprocessType = 'metadata',
    String? parentNotes,
  }) async {
    final response = await client.post(
      '/api/v1/review/$itemId/reprocess',
      data: {
        'reprocess_type': reprocessType,
        if (parentNotes != null && parentNotes.trim().isNotEmpty)
          'parent_notes': parentNotes.trim(),
      },
      options: Options(
        receiveTimeout: reprocessType == 'score'
            ? _scoreReviewTimeout
            : _metadataReviewTimeout,
        sendTimeout: const Duration(seconds: 30),
      ),
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> requestCorrectionJsonReview(
    String itemId, {
    String? parentNotes,
  }) async {
    final response = await client.post(
      '/api/v1/review/$itemId/llm-correction-json',
      data: {
        'reprocess_type': 'score',
        if (parentNotes != null && parentNotes.trim().isNotEmpty)
          'parent_notes': parentNotes.trim(),
      },
      options: Options(
        receiveTimeout: _scoreReviewTimeout,
        sendTimeout: const Duration(seconds: 30),
      ),
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> openScoreVersionInMuseScore({
    required String serverPieceId,
    required String scoreVersionId,
  }) async {
    final response = await _apiClient.post(
      '/api/v1/pieces/$serverPieceId/score_versions/$scoreVersionId/open-musescore',
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> rerenderScoreVersion({
    required String serverPieceId,
    required String canonicalScoreVersionId,
    required String renderedScoreVersionId,
  }) async {
    final response = await client.post(
      '/api/v1/pieces/$serverPieceId/score_versions/$canonicalScoreVersionId/rerender',
      data: {'rendered_score_version_id': renderedScoreVersionId},
      options: Options(
        receiveTimeout: _scoreRenderTimeout,
        sendTimeout: const Duration(seconds: 30),
      ),
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> uploadEditedScoreVersion({
    required String serverPieceId,
    required String canonicalScoreVersionId,
    required String renderedScoreVersionId,
    required String filePath,
  }) async {
    final formData = FormData.fromMap({
      'rendered_score_version_id': renderedScoreVersionId,
      'file': await MultipartFile.fromFile(
        filePath,
        filename: path.basename(filePath),
      ),
    });
    final response = await client.post(
      '/api/v1/pieces/$serverPieceId/score_versions/$canonicalScoreVersionId/edited-candidate',
      data: formData,
      options: Options(
        receiveTimeout: _scoreRenderTimeout,
        sendTimeout: const Duration(minutes: 2),
      ),
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<RemotePieceDetail> fetchPieceDetail(String serverPieceId) async {
    final response = await _apiClient.get('/api/v1/pieces/$serverPieceId');
    return RemotePieceDetail.fromJson(response.data as Map<String, dynamic>);
  }

  Future<RemotePieceDetail> pushPieceToProfiles(
    String serverPieceId,
    List<String> profileIds, {
    String mode = 'cleaned_pdf',
  }) async {
    final response = await _apiClient.post(
      '/api/v1/pieces/$serverPieceId/push',
      data: {
        'profile_ids': profileIds,
        'mode': mode,
      },
    );
    return RemotePieceDetail.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ServerJob> startNotationLab(String serverPieceId) async {
    final response = await _apiClient.post(
      '/api/v1/pieces/$serverPieceId/notation-lab/start',
    );
    return ServerJob.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> fetchCloudStatus() async {
    final response = await _apiClient.get('/api/v1/cloud/status');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> syncCloudManifest() async {
    final response = await _apiClient.post('/api/v1/cloud/sync');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> restoreCloudManifest() async {
    final response = await _apiClient.post('/api/v1/cloud/restore');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<RemotePieceDetail> pullPieceForEdits(String serverPieceId) async {
    final response = await _apiClient.post(
      '/api/v1/pieces/$serverPieceId/workflow/pull-for-edits',
    );
    return RemotePieceDetail.fromJson(response.data as Map<String, dynamic>);
  }

  Future<RemotePieceDetail> closePieceWorkflow(String serverPieceId) async {
    final response = await _apiClient.post(
      '/api/v1/pieces/$serverPieceId/workflow/close',
    );
    return RemotePieceDetail.fromJson(response.data as Map<String, dynamic>);
  }

  Future<RemotePieceSummary> updatePieceMetadata(
    String serverPieceId, {
    required String title,
    String? composer,
    String? primaryInstrument,
    String? bookOrCollection,
    String? keySignature,
    String? tempo,
    String? notes,
    List<String> aliases = const <String>[],
    int? sourcePageStart,
    int? sourcePageEnd,
  }) async {
    final catalogMetadata = <String, dynamic>{
      'title': title,
      if (composer != null && composer.trim().isNotEmpty)
        'composer': composer.trim(),
      if (primaryInstrument != null && primaryInstrument.trim().isNotEmpty)
        'primary_instrument': primaryInstrument.trim(),
      if (bookOrCollection != null && bookOrCollection.trim().isNotEmpty)
        'book_or_collection': bookOrCollection.trim(),
      if (keySignature != null && keySignature.trim().isNotEmpty)
        'key_signature': keySignature.trim(),
      if (tempo != null && tempo.trim().isNotEmpty) 'tempo': tempo.trim(),
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      if (aliases.isNotEmpty) 'aliases': aliases,
      if (sourcePageStart != null) 'source_page_start': sourcePageStart,
      if (sourcePageEnd != null) 'source_page_end': sourcePageEnd,
    };
    final response = await _apiClient.patch(
      '/api/v1/pieces/$serverPieceId',
      data: {
        'title': title.trim(),
        'composer': _nullableText(composer),
        'primary_instrument': _nullableText(primaryInstrument),
        'book_or_collection': _nullableText(bookOrCollection),
        'key_signature': _nullableText(keySignature),
        'tempo': _nullableText(tempo),
        'notes': _nullableText(notes),
        'source_page_start': sourcePageStart,
        'source_page_end': sourcePageEnd,
        'catalog_metadata': catalogMetadata,
      },
    );
    return RemotePieceSummary.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<int>> downloadBytes(String url) async {
    final response = await _apiClient.client.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data ?? const <int>[];
  }

  Future<List<LibraryEntry>> syncApprovedVersions({
    required List<LibraryEntry> entries,
    required Future<void> Function({
      required String localPieceId,
      required List<int> bytes,
      required String fileExtension,
      required String title,
      required String format,
      required String remoteUrl,
      bool makePrimary,
    }) onImportScoreVersion,
  }) async {
    final syncedEntries = <LibraryEntry>[];

    for (final entry in entries) {
      final serverPieceId = entry.piece.serverPieceId;
      if (serverPieceId == null) {
        syncedEntries.add(entry);
        continue;
      }

      try {
        final remotePiece = await fetchPieceDetail(serverPieceId);
        final defaultVersion = remotePiece.scoreVersions.firstWhere(
          (version) =>
              version.studentDefault &&
              (version.format == 'pdf' || version.format == 'image'),
          orElse: () => remotePiece.scoreVersions.firstWhere(
            (version) =>
                version.artifactRole == 'cleaned_pdf' &&
                (version.format == 'pdf' || version.format == 'image'),
            orElse: () => remotePiece.scoreVersions.firstWhere(
              (version) =>
                  version.scoreVersionRole == 'processed_render_pdf' &&
                  (version.format == 'pdf' || version.format == 'image'),
              orElse: () => remotePiece.scoreVersions.firstWhere(
                (version) => version.isDefault,
                orElse: () => remotePiece.scoreVersions.first,
              ),
            ),
          ),
        );

        final hasVersion = entry.scoreVersions.any(
          (version) => version.remoteUrl == defaultVersion.fileUrl,
        );
        if (!hasVersion &&
            defaultVersion.fileUrl.isNotEmpty &&
            (defaultVersion.format == 'pdf' ||
                defaultVersion.format == 'image')) {
          final download = await _apiClient.client.get<List<int>>(
            defaultVersion.fileUrl,
            options: Options(responseType: ResponseType.bytes),
          );

          await onImportScoreVersion(
            localPieceId: entry.piece.id,
            bytes: download.data ?? const <int>[],
            fileExtension: defaultVersion.fileExtension,
            title: defaultVersion.artifactRole == 'cleaned_pdf'
                ? 'Student PDF'
                : defaultVersion.versionType == 'approved'
                    ? 'Approved student PDF'
                    : 'Student PDF candidate',
            format: defaultVersion.format,
            remoteUrl: defaultVersion.fileUrl,
            makePrimary: true,
          );
        }
      } catch (_) {
        // Keep local-only behavior when the server is unavailable.
      }

      syncedEntries.add(entry);
    }

    return syncedEntries;
  }
}

String? _nullableText(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
