class ActivityEvent {
  final String id;
  final String eventType;
  final String? profileId;
  final String? targetProfileId;
  final String? pieceId;
  final String? recordingId;
  final String content;
  final DateTime createdAt;

  const ActivityEvent({
    required this.id,
    required this.eventType,
    this.profileId,
    this.targetProfileId,
    this.pieceId,
    this.recordingId,
    required this.content,
    required this.createdAt,
  });

  factory ActivityEvent.fromJson(Map<String, dynamic> json) {
    return ActivityEvent(
      id: json['id'] as String,
      eventType: json['event_type'] as String,
      profileId: json['profile_id'] as String?,
      targetProfileId: json['target_profile_id'] as String?,
      pieceId: json['piece_id'] as String?,
      recordingId: json['recording_id'] as String?,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class PracticeSession {
  final String id;
  final String studentProfileId;
  final String? pieceId;
  final int durationSeconds;
  final DateTime sessionDate;

  const PracticeSession({
    required this.id,
    required this.studentProfileId,
    this.pieceId,
    required this.durationSeconds,
    required this.sessionDate,
  });

  factory PracticeSession.fromJson(Map<String, dynamic> json) {
    return PracticeSession(
      id: json['id'] as String,
      studentProfileId: json['student_profile_id'] as String,
      pieceId: json['piece_id'] as String?,
      durationSeconds: json['duration_seconds'] as int,
      sessionDate: DateTime.parse(json['session_date'] as String),
    );
  }
}

class StudioEvent {
  final String id;
  final String title;
  final String? description;
  final DateTime startTime;
  final DateTime endTime;
  final String? studentProfileId;
  final String? teacherProfileId;
  final DateTime createdAt;

  const StudioEvent({
    required this.id,
    required this.title,
    this.description,
    required this.startTime,
    required this.endTime,
    this.studentProfileId,
    this.teacherProfileId,
    required this.createdAt,
  });

  factory StudioEvent.fromJson(Map<String, dynamic> json) {
    return StudioEvent(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: DateTime.parse(json['end_time'] as String),
      studentProfileId: json['student_profile_id'] as String?,
      teacherProfileId: json['teacher_profile_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class Goal {
  final String id;
  final String title;
  final String? description;
  final String studentProfileId;
  final String? pieceId;
  final DateTime? dueDate;
  final bool isCompleted;
  final DateTime createdAt;

  const Goal({
    required this.id,
    required this.title,
    this.description,
    required this.studentProfileId,
    this.pieceId,
    this.dueDate,
    required this.isCompleted,
    required this.createdAt,
  });

  factory Goal.fromJson(Map<String, dynamic> json) {
    return Goal(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      studentProfileId: json['student_profile_id'] as String,
      pieceId: json['piece_id'] as String?,
      dueDate: json['due_date'] != null ? DateTime.parse(json['due_date'] as String) : null,
      isCompleted: json['is_completed'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
