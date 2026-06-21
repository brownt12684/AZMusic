/// A student practice recording (video) associated with a piece.
class PracticeRecording {
  final String id;
  final String pieceId;
  final String profileId;
  final String? scoreVersionId;
  final String filePath; // absolute local path to video file
  final int durationMs;
  final DateTime createdAt;
  final bool isSentToTeacher;

  const PracticeRecording({
    required this.id,
    required this.pieceId,
    required this.profileId,
    this.scoreVersionId,
    required this.filePath,
    required this.durationMs,
    required this.createdAt,
    this.isSentToTeacher = false,
  });

  PracticeRecording copyWith({
    String? id,
    String? pieceId,
    String? profileId,
    String? scoreVersionId,
    String? filePath,
    int? durationMs,
    DateTime? createdAt,
    bool? isSentToTeacher,
  }) {
    return PracticeRecording(
      id: id ?? this.id,
      pieceId: pieceId ?? this.pieceId,
      profileId: profileId ?? this.profileId,
      scoreVersionId: scoreVersionId ?? this.scoreVersionId,
      filePath: filePath ?? this.filePath,
      durationMs: durationMs ?? this.durationMs,
      createdAt: createdAt ?? this.createdAt,
      isSentToTeacher: isSentToTeacher ?? this.isSentToTeacher,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'piece_id': pieceId,
      'profile_id': profileId,
      'score_version_id': scoreVersionId,
      'file_path': filePath,
      'duration_ms': durationMs,
      'created_at': createdAt.toIso8601String(),
      'is_sent_to_teacher': isSentToTeacher ? 1 : 0,
    };
  }

  factory PracticeRecording.fromMap(Map<String, dynamic> map) {
    return PracticeRecording(
      id: map['id'] as String,
      pieceId: map['piece_id'] as String,
      profileId: map['profile_id'] as String,
      scoreVersionId: map['score_version_id'] as String?,
      filePath: map['file_path'] as String,
      durationMs: map['duration_ms'] as int? ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      isSentToTeacher: (map['is_sent_to_teacher'] as int?) == 1,
    );
  }

  Map<String, dynamic> toJson() => toMap();
  factory PracticeRecording.fromJson(Map<String, dynamic> json) =>
      PracticeRecording.fromMap(json);

  /// Human-readable duration string (mm:ss).
  String get formattedDuration {
    if (durationMs == 0) return '--:--';
    final secs = durationMs ~/ 1000;
    final mins = secs ~/ 60;
    final remaining = secs % 60;
    return '${mins.toString()}:${remaining.toString().padLeft(2, '0')}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is PracticeRecording && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'PracticeRecording(id: $id, duration: $formattedDuration, sent: $isSentToTeacher)';
}

/// DTO for a practice recording fetched from the server.
class RemotePracticeRecording {
  final String id;
  final String studentProfileId;
  final String pieceId;
  final DateTime submittedAt;

  const RemotePracticeRecording({
    required this.id,
    required this.studentProfileId,
    required this.pieceId,
    required this.submittedAt,
  });

  factory RemotePracticeRecording.fromJson(Map<String, dynamic> json) {
    return RemotePracticeRecording(
      id: json['id'] as String,
      studentProfileId: json['student_profile_id'] as String,
      pieceId: json['piece_id'] as String,
      submittedAt: DateTime.parse(json['submitted_at'] as String),
    );
  }
}
