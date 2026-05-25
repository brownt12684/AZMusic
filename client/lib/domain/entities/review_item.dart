/// An item in the review queue for the instructor to evaluate.
class ReviewItem {
  final String id;
  final String pieceId;
  final String mediaAssetId;
  final String? scoreVersionId;
  final ReviewStatus status;
  final String? instructorNotes;
  final double? overallRating; // 1.0 - 5.0
  final DateTime createdAt;
  final DateTime? reviewedAt;

  const ReviewItem({
    required this.id,
    required this.pieceId,
    required this.mediaAssetId,
    this.scoreVersionId,
    required this.status,
    this.instructorNotes,
    this.overallRating,
    required this.createdAt,
    this.reviewedAt,
  });

  ReviewItem copyWith({
    String? id,
    String? pieceId,
    String? mediaAssetId,
    String? scoreVersionId,
    ReviewStatus? status,
    String? instructorNotes,
    double? overallRating,
    DateTime? createdAt,
    DateTime? reviewedAt,
  }) {
    return ReviewItem(
      id: id ?? this.id,
      pieceId: pieceId ?? this.pieceId,
      mediaAssetId: mediaAssetId ?? this.mediaAssetId,
      scoreVersionId: scoreVersionId ?? this.scoreVersionId,
      status: status ?? this.status,
      instructorNotes: instructorNotes ?? this.instructorNotes,
      overallRating: overallRating ?? this.overallRating,
      createdAt: createdAt ?? this.createdAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'piece_id': pieceId,
      'media_asset_id': mediaAssetId,
      'score_version_id': scoreVersionId,
      'status': status.name,
      'instructor_notes': instructorNotes,
      'overall_rating': overallRating,
      'created_at': createdAt.toIso8601String(),
      'reviewed_at': reviewedAt?.toIso8601String(),
    };
  }

  factory ReviewItem.fromMap(Map<String, dynamic> map) {
    return ReviewItem(
      id: map['id'] as String,
      pieceId: map['piece_id'] as String,
      mediaAssetId: map['media_asset_id'] as String,
      scoreVersionId: map['score_version_id'] as String?,
      status: ReviewStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => ReviewStatus.pending,
      ),
      instructorNotes: map['instructor_notes'] as String?,
      overallRating: map['overall_rating'] != null
          ? (map['overall_rating'] as num).toDouble()
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      reviewedAt: map['reviewed_at'] != null
          ? DateTime.parse(map['reviewed_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => toMap();
  factory ReviewItem.fromJson(Map<String, dynamic> json) =>
      ReviewItem.fromMap(json);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ReviewItem && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Status of a review item.
enum ReviewStatus { pending, inReview, completed, archived }
