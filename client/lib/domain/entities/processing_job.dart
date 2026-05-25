/// A background processing job (e.g., AI analysis, transcription).
class ProcessingJob {
  final String id;
  final JobType type;
  final String? mediaAssetId;
  final String? pieceId;
  final String? scoreVersionId;
  final JobStatus status;
  final double? progress; // 0.0 - 1.0
  final String? errorMessage;
  final Map<String, dynamic>? result;
  final DateTime createdAt;
  final DateTime? completedAt;

  const ProcessingJob({
    required this.id,
    required this.type,
    this.mediaAssetId,
    this.pieceId,
    this.scoreVersionId,
    required this.status,
    this.progress,
    this.errorMessage,
    this.result,
    required this.createdAt,
    this.completedAt,
  });

  ProcessingJob copyWith({
    String? id,
    JobType? type,
    String? mediaAssetId,
    String? pieceId,
    String? scoreVersionId,
    JobStatus? status,
    double? progress,
    String? errorMessage,
    Map<String, dynamic>? result,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return ProcessingJob(
      id: id ?? this.id,
      type: type ?? this.type,
      mediaAssetId: mediaAssetId ?? this.mediaAssetId,
      pieceId: pieceId ?? this.pieceId,
      scoreVersionId: scoreVersionId ?? this.scoreVersionId,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: errorMessage ?? this.errorMessage,
      result: result ?? this.result,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'media_asset_id': mediaAssetId,
      'piece_id': pieceId,
      'score_version_id': scoreVersionId,
      'status': status.name,
      'progress': progress,
      'error_message': errorMessage,
      'result': result?.toString(),
      'created_at': createdAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
    };
  }

  factory ProcessingJob.fromMap(Map<String, dynamic> map) {
    return ProcessingJob(
      id: map['id'] as String,
      type: JobType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => JobType.aiAnalysis,
      ),
      mediaAssetId: map['media_asset_id'] as String?,
      pieceId: map['piece_id'] as String?,
      scoreVersionId: map['score_version_id'] as String?,
      status: JobStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => JobStatus.pending,
      ),
      progress:
          map['progress'] != null ? (map['progress'] as num).toDouble() : null,
      errorMessage: map['error_message'] as String?,
      result: map['result'] != null ? {'output': map['result']} : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      completedAt: map['completed_at'] != null
          ? DateTime.parse(map['completed_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => toMap();
  factory ProcessingJob.fromJson(Map<String, dynamic> json) =>
      ProcessingJob.fromMap(json);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ProcessingJob && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Type of processing job.
enum JobType { aiAnalysis, transcription, audioEnhance, scoreOCR }

/// Status of a processing job.
enum JobStatus { pending, running, completed, failed }
