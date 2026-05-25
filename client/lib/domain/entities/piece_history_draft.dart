/// A draft state for a piece, tracking practice progress and history.
class PieceHistoryDraft {
  final String id;
  final String pieceId;
  final int totalPracticeSessions;
  final Duration totalPracticeTime;
  final int? lastPlayedPage;
  final String? currentFocus; // practice note
  final DateTime lastPracticedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PieceHistoryDraft({
    required this.id,
    required this.pieceId,
    this.totalPracticeSessions = 0,
    this.totalPracticeTime = Duration.zero,
    this.lastPlayedPage,
    this.currentFocus,
    required this.lastPracticedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  PieceHistoryDraft copyWith({
    String? id,
    String? pieceId,
    int? totalPracticeSessions,
    Duration? totalPracticeTime,
    int? lastPlayedPage,
    String? currentFocus,
    DateTime? lastPracticedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PieceHistoryDraft(
      id: id ?? this.id,
      pieceId: pieceId ?? this.pieceId,
      totalPracticeSessions:
          totalPracticeSessions ?? this.totalPracticeSessions,
      totalPracticeTime: totalPracticeTime ?? this.totalPracticeTime,
      lastPlayedPage: lastPlayedPage ?? this.lastPlayedPage,
      currentFocus: currentFocus ?? this.currentFocus,
      lastPracticedAt: lastPracticedAt ?? this.lastPracticedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'piece_id': pieceId,
      'total_practice_sessions': totalPracticeSessions,
      'total_practice_time_ms': totalPracticeTime.inMilliseconds,
      'last_played_page': lastPlayedPage,
      'current_focus': currentFocus,
      'last_practiced_at': lastPracticedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory PieceHistoryDraft.fromMap(Map<String, dynamic> map) {
    return PieceHistoryDraft(
      id: map['id'] as String,
      pieceId: map['piece_id'] as String,
      totalPracticeSessions: map['total_practice_sessions'] as int? ?? 0,
      totalPracticeTime: Duration(
        milliseconds: map['total_practice_time_ms'] as int? ?? 0,
      ),
      lastPlayedPage: map['last_played_page'] as int?,
      currentFocus: map['current_focus'] as String?,
      lastPracticedAt: DateTime.parse(map['last_practiced_at'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => toMap();
  factory PieceHistoryDraft.fromJson(Map<String, dynamic> json) =>
      PieceHistoryDraft.fromMap(json);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is PieceHistoryDraft && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
