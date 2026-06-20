import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/network/server_connection_error.dart';

// ── Practice Alerts (teacher requests) ──────────────────────────────

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

// ── Practice Recordings (student uploads) ───────────────────────────

class PracticeRecording {
  final String id;
  final String studentProfileId;
  final String pieceId;
  final String? localFilePath;
  final DateTime submittedAt;

  const PracticeRecording({
    required this.id,
    required this.studentProfileId,
    required this.pieceId,
    this.localFilePath,
    required this.submittedAt,
  });

  factory PracticeRecording.fromJson(Map<String, dynamic> json) {
    return PracticeRecording(
      id: json['id'] as String,
      studentProfileId: json['student_profile_id'] as String,
      pieceId: json['piece_id'] as String,
      localFilePath: json['local_file_path'] as String?,
      submittedAt: DateTime.parse(json['submitted_at'] as String),
    );
  }
}

class PracticeRecordingsState {
  final List<PracticeRecording> recordings;
  final Map<String, String?> uploadingErrors; // pieceId -> error message
  final bool isLoading;
  final String? error;

  const PracticeRecordingsState({
    this.recordings = const [],
    this.uploadingErrors = const {},
    this.isLoading = false,
    this.error,
  });

  PracticeRecordingsState copyWith({
    List<PracticeRecording>? recordings,
    Map<String, String?>? uploadingErrors,
    bool? isLoading,
    String? error,
  }) {
    return PracticeRecordingsState(
      recordings: recordings ?? this.recordings,
      uploadingErrors: uploadingErrors ?? this.uploadingErrors,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  bool hasRecordingForPiece(String pieceId) {
    return recordings.any((r) => r.pieceId == pieceId);
  }
}

// ── Providers ───────────────────────────────────────────────────────

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

final practiceRecordingsProvider = StateNotifierProvider<PracticeRecordingsNotifier,
    PracticeRecordingsState>((ref) => PracticeRecordingsNotifier());

class PracticeRecordingsNotifier extends StateNotifier<PracticeRecordingsState> {
  PracticeRecordingsNotifier() : super(const PracticeRecordingsState());

  Future<void> fetchRecordings(String studentId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final client = ApiClient();
      final response = await client.get(
        '/api/v1/practice/student/$studentId/recordings',
      );
      if (response.statusCode == 200) {
        final data = response.data as List<dynamic>;
        final recordings = data
            .whereType<Map<String, dynamic>>()
            .map((e) => PracticeRecording.fromJson(e))
            .toList();
        state = state.copyWith(
          recordings: recordings,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          error: 'Failed to load recordings',
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

  Future<bool> uploadRecording({
    required String studentId,
    required String pieceId,
    required String filePath,
  }) async {
    // Mark this piece as uploading
    final newErrors = Map<String, String?>.from(state.uploadingErrors);
    newErrors[pieceId] = null; // null means "uploading"
    state = state.copyWith(uploadingErrors: newErrors);

    try {
      final client = ApiClient();
      final formData = FormData.fromMap({
        'piece_id': pieceId,
        'student_profile_id': studentId,
        'audio_file': await MultipartFile.fromFile(filePath),
      });

      final response = await client.post(
        '/api/v1/practice/recordings/upload',
        data: formData,
      );

      if (response.statusCode == 200) {
        // Refresh the full list to include the new recording
        await fetchRecordings(studentId);
        return true;
      } else {
        final errorMsg = 'Upload failed (${response.statusCode})';
        final updatedErrors = Map<String, String?>.from(state.uploadingErrors);
        updatedErrors[pieceId] = errorMsg;
        state = state.copyWith(uploadingErrors: updatedErrors);
        return false;
      }
    } catch (error) {
      final errorMsg = formatServerConnectionError(error);
      final updatedErrors = Map<String, String?>.from(state.uploadingErrors);
      updatedErrors[pieceId] = errorMsg;
      state = state.copyWith(uploadingErrors: updatedErrors);
      return false;
    } finally {
      // Remove the piece from uploading errors after success/failure
      final updatedErrors = Map<String, String?>.from(state.uploadingErrors);
      updatedErrors.remove(pieceId);
      if (updatedErrors != state.uploadingErrors) {
        state = state.copyWith(uploadingErrors: updatedErrors);
      }
    }
  }

  void clear() {
    state = const PracticeRecordingsState();
  }
}
