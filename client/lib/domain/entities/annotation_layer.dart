/// Annotation layer for a specific page of a score.
/// Stores drawing strokes, highlights, and text notes.
class AnnotationLayer {
  final String id;
  final String scoreVersionId;
  final int pageNumber;
  final List<AnnotationStroke> strokes;
  final List<AnnotationNote> notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AnnotationLayer({
    required this.id,
    required this.scoreVersionId,
    required this.pageNumber,
    required this.strokes,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  AnnotationLayer copyWith({
    String? id,
    String? scoreVersionId,
    int? pageNumber,
    List<AnnotationStroke>? strokes,
    List<AnnotationNote>? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AnnotationLayer(
      id: id ?? this.id,
      scoreVersionId: scoreVersionId ?? this.scoreVersionId,
      pageNumber: pageNumber ?? this.pageNumber,
      strokes: strokes ?? this.strokes,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'score_version_id': scoreVersionId,
      'page_number': pageNumber,
      'strokes': strokes.map((s) => s.toMap()).toList(),
      'notes': notes.map((n) => n.toMap()).toList(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory AnnotationLayer.fromMap(Map<String, dynamic> map) {
    return AnnotationLayer(
      id: map['id'] as String,
      scoreVersionId: map['score_version_id'] as String,
      pageNumber: map['page_number'] as int,
      strokes: (map['strokes'] as List<dynamic>)
          .map((e) => AnnotationStroke.fromMap(e as Map<String, dynamic>))
          .toList(),
      notes: (map['notes'] as List<dynamic>)
          .map((e) => AnnotationNote.fromMap(e as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => toMap();
  factory AnnotationLayer.fromJson(Map<String, dynamic> json) =>
      AnnotationLayer.fromMap(json);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AnnotationLayer && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'AnnotationLayer(id: $id, page: $pageNumber, strokes: ${strokes.length})';
}

/// A single drawing stroke on a score page.
class AnnotationStroke {
  final String id;
  final StrokeColor color;
  final double strokeWidth;
  final List<OffsetPoint> points;
  final StrokeTool tool;

  const AnnotationStroke({
    required this.id,
    required this.color,
    required this.strokeWidth,
    required this.points,
    required this.tool,
  });

  AnnotationStroke copyWith({
    String? id,
    StrokeColor? color,
    double? strokeWidth,
    List<OffsetPoint>? points,
    StrokeTool? tool,
  }) {
    return AnnotationStroke(
      id: id ?? this.id,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      points: points ?? this.points,
      tool: tool ?? this.tool,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'color': color.name,
      'stroke_width': strokeWidth,
      'points': points.map((p) => p.toMap()).toList(),
      'tool': tool.name,
    };
  }

  factory AnnotationStroke.fromMap(Map<String, dynamic> map) {
    return AnnotationStroke(
      id: map['id'] as String,
      color: StrokeColor.values.firstWhere(
        (e) => e.name == map['color'],
        orElse: () => StrokeColor.red,
      ),
      strokeWidth: (map['stroke_width'] as num).toDouble(),
      points: (map['points'] as List<dynamic>)
          .map((e) => OffsetPoint.fromMap(e as Map<String, dynamic>))
          .toList(),
      tool: StrokeTool.values.firstWhere(
        (e) => e.name == map['tool'],
        orElse: () => StrokeTool.pen,
      ),
    );
  }

  Map<String, dynamic> toJson() => toMap();
  factory AnnotationStroke.fromJson(Map<String, dynamic> json) =>
      AnnotationStroke.fromMap(json);
}

/// A text note attached to a position on the score.
class AnnotationNote {
  final String id;
  final OffsetPoint position;
  final String text;
  final DateTime createdAt;

  const AnnotationNote({
    required this.id,
    required this.position,
    required this.text,
    required this.createdAt,
  });

  AnnotationNote copyWith({
    String? id,
    OffsetPoint? position,
    String? text,
    DateTime? createdAt,
  }) {
    return AnnotationNote(
      id: id ?? this.id,
      position: position ?? this.position,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'position': position.toMap(),
      'text': text,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory AnnotationNote.fromMap(Map<String, dynamic> map) {
    return AnnotationNote(
      id: map['id'] as String,
      position: OffsetPoint.fromMap(map['position'] as Map<String, dynamic>),
      text: map['text'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => toMap();
  factory AnnotationNote.fromJson(Map<String, dynamic> json) =>
      AnnotationNote.fromMap(json);
}

/// A 2D point (normalized 0-1 coordinates for page-relative positioning).
class OffsetPoint {
  final double x;
  final double y;

  const OffsetPoint({required this.x, required this.y});

  Map<String, dynamic> toMap() => {'x': x, 'y': y};
  factory OffsetPoint.fromMap(Map<String, dynamic> map) {
    return OffsetPoint(
        x: (map['x'] as num).toDouble(), y: (map['y'] as num).toDouble());
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OffsetPoint && x == other.x && y == other.y;

  @override
  int get hashCode => Object.hash(x, y);
}

/// Drawing tool type.
enum StrokeTool { pen, highlighter, eraser }

/// Stroke color palette.
enum StrokeColor {
  red,
  blue,
  green,
  yellow,
  orange,
  purple,
  black,
}
