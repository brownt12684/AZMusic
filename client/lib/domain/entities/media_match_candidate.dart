/// A candidate match between a media recording and a piece/score.
/// Used during the AI-assisted review process.
class MediaMatchCandidate {
  final String id;
  final String mediaAssetId;
  final String pieceId;
  final String scoreVersionId;
  final double similarityScore;
  final MatchStatus status;
  final String? aiNotes;
  final DateTime createdAt;

  const MediaMatchCandidate({
    required this.id,
    required this.mediaAssetId,
    required this.pieceId,
    required this.scoreVersionId,
    required this.similarityScore,
    required this.status,
    this.aiNotes,
    required this.createdAt,
  });

  MediaMatchCandidate copyWith({
    String? id,
    String? mediaAssetId,
    String? pieceId,
    String? scoreVersionId,
    double? similarityScore,
    MatchStatus? status,
    String? aiNotes,
    DateTime? createdAt,
  }) {
    return MediaMatchCandidate(
      id: id ?? this.id,
      mediaAssetId: mediaAssetId ?? this.mediaAssetId,
      pieceId: pieceId ?? this.pieceId,
      scoreVersionId: scoreVersionId ?? this.scoreVersionId,
      similarityScore: similarityScore ?? this.similarityScore,
      status: status ?? this.status,
      aiNotes: aiNotes ?? this.aiNotes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'media_asset_id': mediaAssetId,
      'piece_id': pieceId,
      'score_version_id': scoreVersionId,
      'similarity_score': similarityScore,
      'status': status.name,
      'ai_notes': aiNotes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory MediaMatchCandidate.fromMap(Map<String, dynamic> map) {
    return MediaMatchCandidate(
      id: map['id'] as String,
      mediaAssetId: map['media_asset_id'] as String,
      pieceId: map['piece_id'] as String,
      scoreVersionId: map['score_version_id'] as String,
      similarityScore: (map['similarity_score'] as num).toDouble(),
      status: MatchStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => MatchStatus.pending,
      ),
      aiNotes: map['ai_notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => toMap();
  factory MediaMatchCandidate.fromJson(Map<String, dynamic> json) =>
      MediaMatchCandidate.fromMap(json);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MediaMatchCandidate && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Status of an AI match candidate.
enum MatchStatus { pending, accepted, rejected }
