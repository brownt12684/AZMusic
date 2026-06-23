/// A staged YouTube candidate performance for parent/teacher review.
class YouTubeCandidate {
  final String id;
  final String pieceId;
  final String youtubeVideoId;
  final String title;
  final String? thumbnailUrl;
  final bool isApproved;
  final DateTime? pushedAt;
  final DateTime? updatedAt;

  const YouTubeCandidate({
    required this.id,
    required this.pieceId,
    required this.youtubeVideoId,
    required this.title,
    this.thumbnailUrl,
    required this.isApproved,
    this.pushedAt,
    this.updatedAt,
  });

  factory YouTubeCandidate.fromJson(Map<String, dynamic> json) {
    return YouTubeCandidate(
      id: json['id'] as String,
      pieceId: json['piece_id'] as String,
      youtubeVideoId: json['youtube_video_id'] as String,
      title: json['title'] as String? ?? 'Reference Track',
      thumbnailUrl: json['thumbnail_url'] as String?,
      isApproved: json['is_approved'] as bool? ?? false,
      pushedAt: json['pushed_at'] != null ? DateTime.parse(json['pushed_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'piece_id': pieceId,
      'youtube_video_id': youtubeVideoId,
      'title': title,
      'thumbnail_url': thumbnailUrl,
      'is_approved': isApproved,
      'pushed_at': pushedAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
