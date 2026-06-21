import '../../core/network/api_client.dart';
import '../../domain/entities/activity.dart';

class ActivityRepository {
  ActivityRepository({
    ApiClient? apiClient,
  }) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<ActivityEvent>> fetchActivityFeed({String? studentId, int limit = 50}) async {
    final response = await _apiClient.get(
      '/api/v1/activity/feed',
      queryParameters: {
        if (studentId != null) 'student_id': studentId,
        'limit': limit,
      },
    );
    final items = response.data as List<dynamic>;
    return items.map((item) => ActivityEvent.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<List<PracticeSession>> fetchPracticeSessions(String studentId) async {
    final response = await _apiClient.get('/api/v1/activity/students/$studentId/sessions');
    final items = response.data as List<dynamic>;
    return items.map((item) => PracticeSession.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<List<StudioEvent>> fetchEvents() async {
    final response = await _apiClient.get('/api/v1/activity/events');
    final items = response.data as List<dynamic>;
    return items.map((item) => StudioEvent.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<List<Goal>> fetchGoals(String studentId) async {
    final response = await _apiClient.get('/api/v1/activity/students/$studentId/goals');
    final items = response.data as List<dynamic>;
    return items.map((item) => Goal.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<Goal> createGoal(
    String studentId, {
    required String title,
    String? description,
    DateTime? dueDate,
    String? pieceId,
  }) async {
    final response = await _apiClient.post(
      '/api/v1/activity/students/$studentId/goals',
      data: {
        'title': title,
        'description': description,
        if (dueDate != null) 'due_date': dueDate.toIso8601String(),
        if (pieceId != null) 'piece_id': pieceId,
      },
    );
    return Goal.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Goal> toggleGoal(String goalId) async {
    final response = await _apiClient.patch('/api/v1/activity/goals/$goalId/toggle');
    return Goal.fromJson(response.data as Map<String, dynamic>);
  }

  Future<StudioEvent> createEvent({
    required String title,
    String? description,
    required DateTime startTime,
    required DateTime endTime,
    String? studentProfileId,
    String? teacherProfileId,
  }) async {
    final response = await _apiClient.post(
      '/api/v1/activity/events',
      data: {
        'title': title,
        'description': description,
        'start_time': startTime.toIso8601String(),
        'end_time': endTime.toIso8601String(),
        if (studentProfileId != null) 'student_profile_id': studentProfileId,
        if (teacherProfileId != null) 'teacher_profile_id': teacherProfileId,
      },
    );
    return StudioEvent.fromJson(response.data as Map<String, dynamic>);
  }

  Future<PracticeSession> createPracticeSession(
    String studentId, {
    String? pieceId,
    required int durationSeconds,
    required DateTime sessionDate,
  }) async {
    final response = await _apiClient.post(
      '/api/v1/activity/students/$studentId/sessions',
      data: {
        if (pieceId != null) 'piece_id': pieceId,
        'duration_seconds': durationSeconds,
        'session_date': sessionDate.toIso8601String(),
      },
    );
    return PracticeSession.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ActivityEvent> createActivityEvent({
    required String eventType,
    String? profileId,
    String? targetProfileId,
    String? pieceId,
    String? recordingId,
    required String content,
  }) async {
    final response = await _apiClient.post(
      '/api/v1/activity/feed',
      data: {
        'event_type': eventType,
        if (profileId != null) 'profile_id': profileId,
        if (targetProfileId != null) 'target_profile_id': targetProfileId,
        if (pieceId != null) 'piece_id': pieceId,
        if (recordingId != null) 'recording_id': recordingId,
        'content': content,
      },
    );
    return ActivityEvent.fromJson(response.data as Map<String, dynamic>);
  }
}

