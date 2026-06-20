/// A single table-of-contents entry from a score PDF.
class TocEntry {
  const TocEntry({
    required this.title,
    required this.page,
    this.depth = 0,
  });

  final String title;
  final int page;
  final int depth;

  factory TocEntry.fromJson(Map<String, dynamic> json) {
    return TocEntry(
      title: json['title'] as String? ?? '',
      page: json['page'] as int? ?? 1,
      depth: json['depth'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'page': page,
        'depth': depth,
      };
}

/// Result of fetching TOC for a score version.
class TocResult {
  const TocResult({
    required this.scoreVersionId,
    required this.pieceId,
    required this.source,
    required this.entries,
  });

  final String scoreVersionId;
  final String pieceId;
  final String source; // "embedded", "ocr", "none"
  final List<TocEntry> entries;

  factory TocResult.fromJson(Map<String, dynamic> json) {
    final entriesRaw = json['entries'] as List<dynamic>? ?? [];
    return TocResult(
      scoreVersionId: json['score_version_id'] as String? ?? '',
      pieceId: json['piece_id'] as String? ?? '',
      source: json['source'] as String? ?? 'none',
      entries:
          entriesRaw.map((e) => TocEntry.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}
