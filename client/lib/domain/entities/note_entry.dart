class NoteEntry {
  const NoteEntry({
    required this.id,
    required this.profileId,
    required this.pieceId,
    required this.scoreVersionId,
    required this.text,
    this.pageNumber,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String profileId;
  final String pieceId;
  final String scoreVersionId;
  final String text;
  final int? pageNumber;
  final DateTime createdAt;
  final DateTime updatedAt;

  NoteEntry copyWith({
    String? id,
    String? profileId,
    String? pieceId,
    String? scoreVersionId,
    String? text,
    int? pageNumber,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NoteEntry(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      pieceId: pieceId ?? this.pieceId,
      scoreVersionId: scoreVersionId ?? this.scoreVersionId,
      text: text ?? this.text,
      pageNumber: pageNumber ?? this.pageNumber,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'profile_id': profileId,
      'piece_id': pieceId,
      'score_version_id': scoreVersionId,
      'text': text,
      'page_number': pageNumber,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory NoteEntry.fromJson(Map<String, dynamic> json) {
    return NoteEntry(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      pieceId: json['piece_id'] as String,
      scoreVersionId: json['score_version_id'] as String,
      text: json['text'] as String,
      pageNumber: json['page_number'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
