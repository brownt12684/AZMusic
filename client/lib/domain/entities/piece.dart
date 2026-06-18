/// A musical piece (composition/work) in the library.
enum LibraryStatus {
  intake,
  uploadPending,
  processing,
  review,
  ready,
  needsEdits,
  archived,
}

class Piece {
  final String id;
  final String title;
  final String? composer;
  final String? serverPieceId;
  final String? assignedProfileId;
  final List<String> visibleToProfileIds;
  final List<String> previousVisibleToProfileIds;
  final String? primaryInstrument;
  final String? bookOrCollection;
  final LibraryStatus libraryStatus;
  final String normalizedTitle;
  final String? normalizedComposer;
  final String sortTitle;
  final String? sortComposer;
  final String? opus;
  final String? movement;
  final String? keySignature;
  final String? tempo;
  final String? difficulty;
  final String? genre;
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
  final String? sourceContentSha256;
  final bool workflowClosed;
  final DateTime createdAt;
  final DateTime updatedAt;

  Piece({
    required this.id,
    required this.title,
    this.composer,
    this.serverPieceId,
    this.assignedProfileId,
    this.visibleToProfileIds = const <String>[],
    this.previousVisibleToProfileIds = const <String>[],
    this.primaryInstrument,
    this.bookOrCollection,
    this.libraryStatus = LibraryStatus.intake,
    String? normalizedTitle,
    this.normalizedComposer,
    String? sortTitle,
    this.sortComposer,
    this.opus,
    this.movement,
    this.keySignature,
    this.tempo,
    this.difficulty,
    this.genre,
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
    this.sourceContentSha256,
    this.workflowClosed = false,
    required this.createdAt,
    required this.updatedAt,
  })  : normalizedTitle = normalizedTitle ?? _normalizeForSearch(title),
        sortTitle = sortTitle ?? _normalizeForSort(title);

  Piece copyWith({
    String? id,
    String? title,
    String? composer,
    String? serverPieceId,
    String? assignedProfileId,
    List<String>? visibleToProfileIds,
    List<String>? previousVisibleToProfileIds,
    String? primaryInstrument,
    String? bookOrCollection,
    LibraryStatus? libraryStatus,
    String? normalizedTitle,
    String? normalizedComposer,
    String? sortTitle,
    String? sortComposer,
    String? opus,
    String? movement,
    String? keySignature,
    String? tempo,
    String? difficulty,
    String? genre,
    String? notes,
    Map<String, dynamic>? processedMetadata,
    String? pieceKind,
    String? sourceBookId,
    int? sourcePageStart,
    int? sourcePageEnd,
    Map<String, dynamic>? catalogMetadata,
    List<Map<String, dynamic>>? catalogSuggestions,
    List<String>? validationWarnings,
    double? splitConfidence,
    String? sourceContentSha256,
    bool? workflowClosed,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearComposer = false,
    bool clearServerPieceId = false,
    bool clearPrimaryInstrument = false,
    bool clearBookOrCollection = false,
    bool clearKeySignature = false,
    bool clearTempo = false,
    bool clearNotes = false,
    bool clearSourceBookId = false,
    bool clearSourcePageStart = false,
    bool clearSourcePageEnd = false,
    bool clearSplitConfidence = false,
  }) {
    return Piece(
      id: id ?? this.id,
      title: title ?? this.title,
      composer: clearComposer ? null : composer ?? this.composer,
      serverPieceId:
          clearServerPieceId ? null : serverPieceId ?? this.serverPieceId,
      assignedProfileId: assignedProfileId ?? this.assignedProfileId,
      visibleToProfileIds: visibleToProfileIds ?? this.visibleToProfileIds,
      previousVisibleToProfileIds:
          previousVisibleToProfileIds ?? this.previousVisibleToProfileIds,
      primaryInstrument: clearPrimaryInstrument
          ? null
          : primaryInstrument ?? this.primaryInstrument,
      bookOrCollection: clearBookOrCollection
          ? null
          : bookOrCollection ?? this.bookOrCollection,
      libraryStatus: libraryStatus ?? this.libraryStatus,
      normalizedTitle: normalizedTitle ?? this.normalizedTitle,
      normalizedComposer: normalizedComposer ?? this.normalizedComposer,
      sortTitle: sortTitle ?? this.sortTitle,
      sortComposer: sortComposer ?? this.sortComposer,
      opus: opus ?? this.opus,
      movement: movement ?? this.movement,
      keySignature:
          clearKeySignature ? null : keySignature ?? this.keySignature,
      tempo: clearTempo ? null : tempo ?? this.tempo,
      difficulty: difficulty ?? this.difficulty,
      genre: genre ?? this.genre,
      notes: clearNotes ? null : notes ?? this.notes,
      processedMetadata: processedMetadata ?? this.processedMetadata,
      pieceKind: pieceKind ?? this.pieceKind,
      sourceBookId:
          clearSourceBookId ? null : sourceBookId ?? this.sourceBookId,
      sourcePageStart:
          clearSourcePageStart ? null : sourcePageStart ?? this.sourcePageStart,
      sourcePageEnd:
          clearSourcePageEnd ? null : sourcePageEnd ?? this.sourcePageEnd,
      catalogMetadata: catalogMetadata ?? this.catalogMetadata,
      catalogSuggestions: catalogSuggestions ?? this.catalogSuggestions,
      validationWarnings: validationWarnings ?? this.validationWarnings,
      splitConfidence:
          clearSplitConfidence ? null : splitConfidence ?? this.splitConfidence,
      sourceContentSha256: sourceContentSha256 ?? this.sourceContentSha256,
      workflowClosed: workflowClosed ?? this.workflowClosed,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'composer': composer,
      'server_piece_id': serverPieceId,
      'assigned_profile_id': assignedProfileId,
      'visible_to_profile_ids': visibleToProfileIds,
      'previous_visible_to_profile_ids': previousVisibleToProfileIds,
      'primary_instrument': primaryInstrument,
      'book_or_collection': bookOrCollection,
      'library_status': libraryStatus.name,
      'normalized_title': normalizedTitle,
      'normalized_composer': normalizedComposer,
      'sort_title': sortTitle,
      'sort_composer': sortComposer,
      'opus': opus,
      'movement': movement,
      'key_signature': keySignature,
      'tempo': tempo,
      'difficulty': difficulty,
      'genre': genre,
      'notes': notes,
      'processed_metadata': processedMetadata,
      'piece_kind': pieceKind,
      'source_book_id': sourceBookId,
      'source_page_start': sourcePageStart,
      'source_page_end': sourcePageEnd,
      'catalog_metadata': catalogMetadata,
      'catalog_suggestions': catalogSuggestions,
      'validation_warnings': validationWarnings,
      'split_confidence': splitConfidence,
      'source_content_sha256': sourceContentSha256,
      'workflow_closed': workflowClosed,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Piece.fromMap(Map<String, dynamic> map) {
    final legacyAssignedProfileId = map['assigned_profile_id'] as String?;
    final visibleToProfileIds =
        (map['visible_to_profile_ids'] as List<dynamic>?)
                ?.map((item) => item as String)
                .toList() ??
            (legacyAssignedProfileId == null
                ? const <String>[]
                : <String>[legacyAssignedProfileId]);
    final title = map['title'] as String;
    final composer = map['composer'] as String?;
    return Piece(
      id: map['id'] as String,
      title: title,
      composer: composer,
      serverPieceId: map['server_piece_id'] as String?,
      assignedProfileId: legacyAssignedProfileId,
      visibleToProfileIds: visibleToProfileIds,
      previousVisibleToProfileIds:
          (map['previous_visible_to_profile_ids'] as List<dynamic>?)
                  ?.map((item) => item as String)
                  .toList() ??
              const <String>[],
      primaryInstrument: map['primary_instrument'] as String?,
      bookOrCollection: map['book_or_collection'] as String?,
      libraryStatus: LibraryStatus.values.firstWhere(
        (value) => value.name == map['library_status'],
        orElse: () {
          final legacyStatus = (map['status'] as String?)?.toLowerCase();
          switch (legacyStatus) {
            case 'approved':
              return LibraryStatus.ready;
            case 'review_pending':
              return LibraryStatus.review;
            case 'needs_edits':
            case 'needsedits':
              return LibraryStatus.needsEdits;
            case 'upload_pending':
              return LibraryStatus.uploadPending;
            case 'processing':
              return LibraryStatus.processing;
            case 'archived':
            case 'rejected':
              return LibraryStatus.archived;
            default:
              return visibleToProfileIds.isEmpty
                  ? LibraryStatus.intake
                  : LibraryStatus.ready;
          }
        },
      ),
      normalizedTitle:
          map['normalized_title'] as String? ?? _normalizeForSearch(title),
      normalizedComposer: map['normalized_composer'] as String? ??
          (composer == null ? null : _normalizeForSearch(composer)),
      sortTitle: map['sort_title'] as String? ?? _normalizeForSort(title),
      sortComposer: map['sort_composer'] as String? ??
          (composer == null ? null : _normalizeForSort(composer)),
      opus: map['opus'] as String?,
      movement: map['movement'] as String?,
      keySignature: map['key_signature'] as String?,
      tempo: map['tempo'] as String?,
      difficulty: map['difficulty'] as String?,
      genre: map['genre'] as String?,
      notes: map['notes'] as String?,
      processedMetadata: Map<String, dynamic>.from(
        map['processed_metadata'] as Map? ?? const <String, dynamic>{},
      ),
      pieceKind: map['piece_kind'] as String? ?? 'piece',
      sourceBookId: map['source_book_id'] as String?,
      sourcePageStart: map['source_page_start'] as int?,
      sourcePageEnd: map['source_page_end'] as int?,
      catalogMetadata: Map<String, dynamic>.from(
        map['catalog_metadata'] as Map? ?? const <String, dynamic>{},
      ),
      catalogSuggestions:
          (map['catalog_suggestions'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList(),
      validationWarnings:
          (map['validation_warnings'] as List<dynamic>? ?? const <dynamic>[])
              .map((item) => item.toString())
              .toList(),
      splitConfidence: (map['split_confidence'] as num?)?.toDouble(),
      sourceContentSha256: map['source_content_sha256'] as String?,
      workflowClosed: map['workflow_closed'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => toMap();
  factory Piece.fromJson(Map<String, dynamic> json) => Piece.fromMap(json);

  /// Human-readable title with optional composer and movement.
  String get displayName {
    final parts = <String>[title];
    if (composer != null) parts.insert(0, composer!);
    if (movement != null) parts.add('($movement)');
    return parts.join(' - ');
  }

  bool isVisibleToProfile(String profileId) {
    return visibleToProfileIds.contains(profileId) ||
        assignedProfileId == profileId;
  }

  bool matchesQuery(String query) {
    final normalizedQuery = _normalizeForSearch(query);
    if (normalizedQuery.isEmpty) {
      return true;
    }
    return normalizedTitle.contains(normalizedQuery) ||
        (normalizedComposer?.contains(normalizedQuery) ?? false) ||
        (_normalizeForSearch(bookOrCollection ?? '')
            .contains(normalizedQuery)) ||
        (_normalizeForSearch(primaryInstrument ?? '')
            .contains(normalizedQuery)) ||
        _catalogSearchText().contains(normalizedQuery);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Piece && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Piece(id: $id, title: $title, composer: $composer, '
      'serverPieceId: $serverPieceId, assignedProfileId: $assignedProfileId)';
}

extension _PieceCatalogSearch on Piece {
  String _catalogSearchText() {
    final values = <String>[
      ...catalogMetadata.values.map((value) => value.toString()),
      ...processedMetadata.values.map((value) => value.toString()),
      ...catalogSuggestions.expand(
        (suggestion) => suggestion.values.map((value) => value.toString()),
      ),
    ];
    return _normalizeForSearch(values.join(' '));
  }
}

String _normalizeForSearch(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _normalizeForSort(String value) {
  final normalized = _normalizeForSearch(value);
  const removablePrefixes = <String>['the ', 'a ', 'an '];
  for (final prefix in removablePrefixes) {
    if (normalized.startsWith(prefix)) {
      return normalized.substring(prefix.length);
    }
  }
  return normalized;
}
