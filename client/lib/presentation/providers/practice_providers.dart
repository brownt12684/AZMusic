import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/network/server_connection_error.dart';

class PracticeAlert {
  final String id;
  final String teacherProfileId;
  final String teacherName;
  final String studentProfileId;
  final String? pieceId;
  final String? pieceTitle;
  final String? messageNotes;
  final bool isRead;
  final DateTime createdAt;

  const PracticeAlert({
    required this.id,
    required this.teacherProfileId,
    required this.teacherName,
    required this.studentProfileId,
    this.pieceId,
    this.pieceTitle,
    this.messageNotes,
    required this.isRead,
    required this.createdAt,
  });

  factory PracticeAlert.fromJson(Map<String, dynamic> json) {
    return PracticeAlert(
      id: json['id'] as String,
      teacherProfileId: json['teacher_profile_id'] as String,
      teacherName: json['teacher_name'] as String? ?? 'Teacher',
      studentProfileId: json['student_profile_id'] as String,
      pieceId: json['piece_id'] as String?,
      pieceTitle: json['piece_title'] as String?,
      messageNotes: json['message_notes'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class PracticeAlertsState {
  final List<PracticeAlert> pendingRequests;
  final bool isLoading;
  final String? error;

  const PracticeAlertsState({
    this.pendingRequests = const [],
    this.isLoading = false,
    this.error,
  });

  PracticeAlertsState copyWith({
    List<PracticeAlert>? pendingRequests,
    bool? isLoading,
    String? error,
  }) {
    return PracticeAlertsState(
      pendingRequests: pendingRequests ?? this.pendingRequests,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

final practiceApiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

final practiceAlertsProvider = StateNotifierProvider<PracticeAlertsNotifier,
    PracticeAlertsState>((ref) => PracticeAlertsNotifier());

class PracticeAlertsNotifier extends StateNotifier<PracticeAlertsState> {
  PracticeAlertsNotifier() : super(const PracticeAlertsState());

  Future<void> fetchAlerts(String studentId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final client = ApiClient();
      final response = await client.get(
        '/api/v1/practice/student/$studentId/alerts',
      );
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final items = data['pending_requests'] as List<dynamic>? ?? [];
        final alerts = items
            .whereType<Map<String, dynamic>>()
            .map((e) => PracticeAlert.fromJson(e))
            .toList();
        state = state.copyWith(
          pendingRequests: alerts,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          error: 'Failed to load practice alerts',
          isLoading: false,
        );
      }
    } catch (error) {
      state = state.copyWith(
        error: formatServerConnectionError(error),
        isLoading: false,
      );
    }
  }

  Future<void> markAsRead(String requestId) async {
    try {
      final client = ApiClient();
      await client.post('/api/v1/practice/requests/$requestId/read');
      state = state.copyWith(
        pendingRequests: state.pendingRequests
            .map((a) => a.id == requestId
                ? PracticeAlert(
                    id: a.id,
                    teacherProfileId: a.teacherProfileId,
                    teacherName: a.teacherName,
                    studentProfileId: a.studentProfileId,
                    pieceId: a.pieceId,
                    pieceTitle: a.pieceTitle,
                    messageNotes: a.messageNotes,
                    isRead: true,
                    createdAt: a.createdAt,
                  )
                : a)
            .toList(),
      );
    } catch (_) {
      // Silently fail — alerts will refresh on next fetch
    }
  }

  void clear() {
    state = const PracticeAlertsState();
  }
}
