class ServerJob {
  const ServerJob({
    required this.id,
    this.pieceId,
    this.pieceTitle,
    this.pieceComposer,
    this.pieceStatus,
    required this.jobType,
    required this.status,
    required this.progress,
    this.errorMessage,
    required this.resultData,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String? pieceId;
  final String? pieceTitle;
  final String? pieceComposer;
  final String? pieceStatus;
  final String jobType;
  final String status;
  final double progress;
  final String? errorMessage;
  final Map<String, dynamic> resultData;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get canCancel => status == 'queued' || status == 'running';
  bool get canRetry => status == 'failed' && jobType == 'score_processing';

  String get pieceLabel {
    final title =
        pieceTitle ?? resultData['piece_title'] ?? resultData['title'];
    if (title is String && title.trim().isNotEmpty) {
      return title.trim();
    }
    return pieceId ?? 'No piece id';
  }

  factory ServerJob.fromJson(Map<String, dynamic> json) {
    return ServerJob(
      id: json['id'] as String,
      pieceId: json['piece_id'] as String?,
      pieceTitle: json['piece_title'] as String?,
      pieceComposer: json['piece_composer'] as String?,
      pieceStatus: json['piece_status'] as String?,
      jobType: json['job_type'] as String? ?? 'unknown',
      status: json['status'] as String? ?? 'unknown',
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      errorMessage: json['error_message'] as String?,
      resultData: Map<String, dynamic>.from(
        json['result_data'] as Map? ?? const <String, dynamic>{},
      ),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
