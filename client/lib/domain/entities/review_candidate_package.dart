class ReviewQueueEntry {
  const ReviewQueueEntry({
    required this.id,
    required this.pieceId,
    required this.itemType,
    required this.title,
    required this.description,
    required this.status,
    required this.createdAt,
    this.candidateData = const <String, dynamic>{},
  });

  final String id;
  final String pieceId;
  final String itemType;
  final String title;
  final String description;
  final String status;
  final DateTime createdAt;
  final Map<String, dynamic> candidateData;

  factory ReviewQueueEntry.fromJson(Map<String, dynamic> json) {
    return ReviewQueueEntry(
      id: json['id'] as String,
      pieceId: json['piece_id'] as String,
      itemType: json['item_type'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(json['created_at'] as String),
      candidateData: Map<String, dynamic>.from(
        json['candidate_data'] as Map<String, dynamic>? ??
            const <String, dynamic>{},
      ),
    );
  }
}

class ReviewBulkApprovalResult {
  const ReviewBulkApprovalResult({
    required this.sourceBookId,
    required this.processingStage,
    required this.approvedCount,
    required this.skippedCount,
    required this.failedCount,
    this.approvedItemIds = const <String>[],
    this.skippedItemIds = const <String>[],
    this.failedItems = const <Map<String, dynamic>>[],
  });

  final String sourceBookId;
  final String processingStage;
  final int approvedCount;
  final int skippedCount;
  final int failedCount;
  final List<String> approvedItemIds;
  final List<String> skippedItemIds;
  final List<Map<String, dynamic>> failedItems;

  factory ReviewBulkApprovalResult.fromJson(Map<String, dynamic> json) {
    return ReviewBulkApprovalResult(
      sourceBookId: json['source_book_id'] as String? ?? '',
      processingStage: json['processing_stage'] as String? ?? '',
      approvedCount: json['approved_count'] as int? ?? 0,
      skippedCount: json['skipped_count'] as int? ?? 0,
      failedCount: json['failed_count'] as int? ?? 0,
      approvedItemIds: _stringListFromJson(json['approved_item_ids']),
      skippedItemIds: _stringListFromJson(json['skipped_item_ids']),
      failedItems: _metadataListFromJson(json['failed_items']),
    );
  }
}

class RemotePieceSummary {
  const RemotePieceSummary({
    required this.id,
    required this.title,
    required this.status,
    required this.libraryStatus,
    required this.visibleToProfileIds,
    this.composer,
    this.primaryInstrument,
    this.bookOrCollection,
    this.keySignature,
    this.tempo,
    this.difficultyLevel,
    this.notes,
    this.processedMetadata = const <String, dynamic>{},
    this.pieceKind = 'piece',
    this.sourceBookId,
    this.sourcePageStart,
    this.sourcePageEnd,
    this.catalogMetadata = const <String, dynamic>{},
    this.catalogSuggestions = const <Map<String, dynamic>>[],
    this.validationWarnings = const <String>[],
    this.splitConfidence,
  });

  final String id;
  final String title;
  final String status;
  final String libraryStatus;
  final List<String> visibleToProfileIds;
  final String? composer;
  final String? primaryInstrument;
  final String? bookOrCollection;
  final String? keySignature;
  final String? tempo;
  final String? difficultyLevel;
  final String? notes;
  final Map<String, dynamic> processedMetadata;
  final String pieceKind;
  final String? sourceBookId;
  final int? sourcePageStart;
  final int? sourcePageEnd;
  final Map<String, dynamic> catalogMetadata;
  final List<Map<String, dynamic>> catalogSuggestions;
  final List<String> validationWarnings;
  final double? splitConfidence;

  factory RemotePieceSummary.fromJson(Map<String, dynamic> json) {
    return RemotePieceSummary(
      id: json['id'] as String,
      title: json['title'] as String,
      composer: json['composer'] as String?,
      primaryInstrument: json['primary_instrument'] as String?,
      bookOrCollection: json['book_or_collection'] as String?,
      keySignature: json['key_signature'] as String?,
      tempo: json['tempo'] as String?,
      difficultyLevel: json['difficulty_level'] as String?,
      notes: json['notes'] as String?,
      processedMetadata: _metadataMapFromJson(json['processed_metadata']),
      pieceKind: json['piece_kind'] as String? ?? 'piece',
      sourceBookId: json['source_book_id'] as String?,
      sourcePageStart: json['source_page_start'] as int?,
      sourcePageEnd: json['source_page_end'] as int?,
      catalogMetadata: _metadataMapFromJson(json['catalog_metadata']),
      catalogSuggestions: _metadataListFromJson(json['catalog_suggestions']),
      validationWarnings: _stringListFromJson(json['validation_warnings']),
      splitConfidence: (json['split_confidence'] as num?)?.toDouble(),
      status: json['status'] as String,
      libraryStatus: json['library_status'] as String? ?? 'intake',
      visibleToProfileIds:
          (json['visible_to_profile_ids'] as List<dynamic>? ?? const [])
              .map((item) => item as String)
              .toList(),
    );
  }
}

class RemoteScoreVersion {
  const RemoteScoreVersion({
    required this.id,
    required this.versionType,
    required this.filePath,
    required this.fileUrl,
    required this.isDefault,
  });

  final String id;
  final String versionType;
  final String filePath;
  final String fileUrl;
  final bool isDefault;

  String get fileExtension {
    final dotIndex = filePath.lastIndexOf('.');
    if (dotIndex == -1) {
      return '';
    }
    return filePath.substring(dotIndex);
  }

  String get format {
    final extension = fileExtension.toLowerCase();
    switch (extension) {
      case '.pdf':
        return 'pdf';
      case '.png':
      case '.jpg':
      case '.jpeg':
      case '.webp':
        return 'image';
      case '.musicxml':
      case '.xml':
      case '.mxl':
        return 'musicxml';
      default:
        return extension.replaceFirst('.', '');
    }
  }

  factory RemoteScoreVersion.fromJson(Map<String, dynamic> json) {
    return RemoteScoreVersion(
      id: json['id'] as String,
      versionType: json['version_type'] as String,
      filePath: json['file_path'] as String,
      fileUrl: json['file_url'] as String? ?? '',
      isDefault: json['is_default'] as bool? ?? false,
    );
  }
}

class RemotePieceDetail {
  const RemotePieceDetail({
    required this.id,
    required this.title,
    required this.status,
    required this.libraryStatus,
    required this.visibleToProfileIds,
    required this.scoreVersions,
    this.composer,
    this.primaryInstrument,
    this.bookOrCollection,
    this.keySignature,
    this.tempo,
    this.difficultyLevel,
    this.notes,
    this.processedMetadata = const <String, dynamic>{},
    this.pieceKind = 'piece',
    this.sourceBookId,
    this.sourcePageStart,
    this.sourcePageEnd,
    this.catalogMetadata = const <String, dynamic>{},
    this.catalogSuggestions = const <Map<String, dynamic>>[],
    this.validationWarnings = const <String>[],
    this.splitConfidence,
  });

  final String id;
  final String title;
  final String? composer;
  final String? primaryInstrument;
  final String? bookOrCollection;
  final String? keySignature;
  final String? tempo;
  final String? difficultyLevel;
  final String? notes;
  final Map<String, dynamic> processedMetadata;
  final String pieceKind;
  final String? sourceBookId;
  final int? sourcePageStart;
  final int? sourcePageEnd;
  final Map<String, dynamic> catalogMetadata;
  final List<Map<String, dynamic>> catalogSuggestions;
  final List<String> validationWarnings;
  final double? splitConfidence;
  final String status;
  final String libraryStatus;
  final List<String> visibleToProfileIds;
  final List<RemoteScoreVersion> scoreVersions;

  factory RemotePieceDetail.fromJson(Map<String, dynamic> json) {
    return RemotePieceDetail(
      id: json['id'] as String,
      title: json['title'] as String,
      composer: json['composer'] as String?,
      primaryInstrument: json['primary_instrument'] as String?,
      bookOrCollection: json['book_or_collection'] as String?,
      keySignature: json['key_signature'] as String?,
      tempo: json['tempo'] as String?,
      difficultyLevel: json['difficulty_level'] as String?,
      notes: json['notes'] as String?,
      processedMetadata: _metadataMapFromJson(json['processed_metadata']),
      pieceKind: json['piece_kind'] as String? ?? 'piece',
      sourceBookId: json['source_book_id'] as String?,
      sourcePageStart: json['source_page_start'] as int?,
      sourcePageEnd: json['source_page_end'] as int?,
      catalogMetadata: _metadataMapFromJson(json['catalog_metadata']),
      catalogSuggestions: _metadataListFromJson(json['catalog_suggestions']),
      validationWarnings: _stringListFromJson(json['validation_warnings']),
      splitConfidence: (json['split_confidence'] as num?)?.toDouble(),
      status: json['status'] as String,
      libraryStatus: json['library_status'] as String? ?? 'intake',
      visibleToProfileIds:
          (json['visible_to_profile_ids'] as List<dynamic>? ?? const [])
              .map((item) => item as String)
              .toList(),
      scoreVersions: (json['score_versions'] as List<dynamic>? ?? const [])
          .map(
            (version) => RemoteScoreVersion.fromJson(
              version as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}

Map<String, dynamic> _metadataMapFromJson(dynamic value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return const <String, dynamic>{};
}

List<Map<String, dynamic>> _metadataListFromJson(dynamic value) {
  if (value is List) {
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
  return const <Map<String, dynamic>>[];
}

List<String> _stringListFromJson(dynamic value) {
  if (value is List) {
    return value.map((item) => item.toString()).toList();
  }
  return const <String>[];
}
