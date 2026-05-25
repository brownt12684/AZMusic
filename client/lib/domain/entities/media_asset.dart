/// A media asset (audio recording or video) associated with a piece.
class MediaAsset {
  final String id;
  final String pieceId;
  final String filePath;
  final String? remoteUrl;
  final String format; // 'mp3', 'wav', 'mp4', etc.
  final int? durationMs;
  final int? fileSizeBytes;
  final String? thumbnailPath;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MediaAsset({
    required this.id,
    required this.pieceId,
    required this.filePath,
    this.remoteUrl,
    required this.format,
    this.durationMs,
    this.fileSizeBytes,
    this.thumbnailPath,
    required this.createdAt,
    required this.updatedAt,
  });

  MediaAsset copyWith({
    String? id,
    String? pieceId,
    String? filePath,
    String? remoteUrl,
    String? format,
    int? durationMs,
    int? fileSizeBytes,
    String? thumbnailPath,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MediaAsset(
      id: id ?? this.id,
      pieceId: pieceId ?? this.pieceId,
      filePath: filePath ?? this.filePath,
      remoteUrl: remoteUrl ?? this.remoteUrl,
      format: format ?? this.format,
      durationMs: durationMs ?? this.durationMs,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'piece_id': pieceId,
      'file_path': filePath,
      'remote_url': remoteUrl,
      'format': format,
      'duration_ms': durationMs,
      'file_size_bytes': fileSizeBytes,
      'thumbnail_path': thumbnailPath,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory MediaAsset.fromMap(Map<String, dynamic> map) {
    return MediaAsset(
      id: map['id'] as String,
      pieceId: map['piece_id'] as String,
      filePath: map['file_path'] as String,
      remoteUrl: map['remote_url'] as String?,
      format: map['format'] as String,
      durationMs: map['duration_ms'] as int?,
      fileSizeBytes: map['file_size_bytes'] as int?,
      thumbnailPath: map['thumbnail_path'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => toMap();
  factory MediaAsset.fromJson(Map<String, dynamic> json) =>
      MediaAsset.fromMap(json);

  /// Human-readable duration string (mm:ss).
  String get durationString {
    if (durationMs == null) return '--:--';
    final secs = durationMs! ~/ 1000;
    final mins = secs ~/ 60;
    final remaining = secs % 60;
    return '${mins.toString()}:${remaining.toString().padLeft(2, '0')}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MediaAsset && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'MediaAsset(id: $id, format: $format, duration: $durationString)';
}
