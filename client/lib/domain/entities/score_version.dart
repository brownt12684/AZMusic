/// A version of a musical score (PDF or image-based).
class ScoreVersion {
  final String id;
  final String pieceId;
  final String title;
  final String filePath;
  final String? remoteUrl;
  final String? versionType;
  final String format; // 'pdf', 'image', 'musicxml'
  final int? pageCount;
  final String? checksum;
  final bool isPrimary;
  final bool isStudentVisible;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ScoreVersion({
    required this.id,
    required this.pieceId,
    required this.title,
    required this.filePath,
    this.remoteUrl,
    this.versionType,
    required this.format,
    this.pageCount,
    this.checksum,
    this.isPrimary = false,
    this.isStudentVisible = true,
    required this.createdAt,
    required this.updatedAt,
  });

  ScoreVersion copyWith({
    String? id,
    String? pieceId,
    String? title,
    String? filePath,
    String? remoteUrl,
    String? versionType,
    String? format,
    int? pageCount,
    String? checksum,
    bool? isPrimary,
    bool? isStudentVisible,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ScoreVersion(
      id: id ?? this.id,
      pieceId: pieceId ?? this.pieceId,
      title: title ?? this.title,
      filePath: filePath ?? this.filePath,
      remoteUrl: remoteUrl ?? this.remoteUrl,
      versionType: versionType ?? this.versionType,
      format: format ?? this.format,
      pageCount: pageCount ?? this.pageCount,
      checksum: checksum ?? this.checksum,
      isPrimary: isPrimary ?? this.isPrimary,
      isStudentVisible: isStudentVisible ?? this.isStudentVisible,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'piece_id': pieceId,
      'title': title,
      'file_path': filePath,
      'remote_url': remoteUrl,
      'version_type': versionType,
      'format': format,
      'page_count': pageCount,
      'checksum': checksum,
      'is_primary': isPrimary,
      'is_student_visible': isStudentVisible,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory ScoreVersion.fromMap(Map<String, dynamic> map) {
    return ScoreVersion(
      id: map['id'] as String,
      pieceId: map['piece_id'] as String,
      title: map['title'] as String,
      filePath: map['file_path'] as String,
      remoteUrl: map['remote_url'] as String?,
      versionType: map['version_type'] as String?,
      format: map['format'] as String,
      pageCount: map['page_count'] as int?,
      checksum: map['checksum'] as String?,
      isPrimary: map['is_primary'] as bool? ?? false,
      isStudentVisible: map['is_student_visible'] as bool? ?? true,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => toMap();
  factory ScoreVersion.fromJson(Map<String, dynamic> json) =>
      ScoreVersion.fromMap(json);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ScoreVersion && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ScoreVersion(id: $id, title: $title, format: $format)';
}
