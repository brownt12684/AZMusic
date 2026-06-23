import 'package:drift/drift.dart';

/// Stable storage keys used by the client-side persistence layer.
class TableNames {
  static const profiles = 'profiles';
  static const pieces = 'pieces';
  static const scoreVersions = 'score_versions';
  static const annotationLayers = 'annotation_layers';
  static const annotationStrokes = 'annotation_strokes';
  static const annotationNotes = 'annotation_notes';
  static const mediaAssets = 'media_assets';
  static const mediaMatchCandidates = 'media_match_candidates';
  static const processingJobs = 'processing_jobs';
  static const reviewItems = 'review_items';
  static const pieceHistoryDrafts = 'piece_history_drafts';
  static const syncStates = 'sync_states';
  static const practiceRecordings = 'practice_recordings';
}

// Drift table definitions

@DataClassName('ProfileRow')
class Profiles extends Table {
  TextColumn get id => text()();
  TextColumn get displayName => text()();
  TextColumn get role => text()();
  BoolColumn get parentPinRequired => boolean()();
  BoolColumn get isDefaultOnDevice => boolean()();
  TextColumn get localPin => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get avatarUrl => text().nullable()();
  TextColumn get instrument => text()();
  IntColumn get gradeLevel => integer().nullable()();
  TextColumn get subtitle => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PieceRow')
class Pieces extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get composer => text().nullable()();
  TextColumn get serverPieceId => text().nullable()();
  TextColumn get assignedProfileId => text().nullable()();
  TextColumn get visibleToProfileIds => text()();
  TextColumn get previousVisibleToProfileIds => text().nullable()();
  TextColumn get primaryInstrument => text().nullable()();
  TextColumn get bookOrCollection => text().nullable()();
  TextColumn get libraryStatus => text()();
  TextColumn get normalizedTitle => text()();
  TextColumn get normalizedComposer => text().nullable()();
  TextColumn get sortTitle => text()();
  TextColumn get sortComposer => text().nullable()();
  TextColumn get opus => text().nullable()();
  TextColumn get movement => text().nullable()();
  TextColumn get keySignature => text().nullable()();
  TextColumn get tempo => text().nullable()();
  TextColumn get difficulty => text().nullable()();
  TextColumn get genre => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get processedMetadata => text().nullable()();
  TextColumn get pieceKind => text().withDefault(const Constant('piece'))();
  TextColumn get sourceBookId => text().nullable()();
  IntColumn get sourcePageStart => integer().nullable()();
  IntColumn get sourcePageEnd => integer().nullable()();
  TextColumn get catalogMetadata => text().nullable()();
  TextColumn get catalogSuggestions => text().nullable()();
  TextColumn get validationWarnings => text().nullable()();
  RealColumn get splitConfidence => real().nullable()();
  TextColumn get sourceContentSha256 => text().nullable()();
  BoolColumn get workflowClosed => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ScoreVersionRow')
class ScoreVersions extends Table {
  TextColumn get id => text()();
  TextColumn get pieceId => text().references(Pieces, #id)();
  TextColumn get title => text()();
  TextColumn get filePath => text()();
  TextColumn get remoteUrl => text().nullable()();
  TextColumn get versionType => text().nullable()();
  TextColumn get format => text()();
  IntColumn get pageCount => integer().nullable()();
  TextColumn get checksum => text().nullable()();
  BoolColumn get isPrimary => boolean()();
  BoolColumn get isStudentVisible => boolean()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('AnnotationLayerRow')
class AnnotationLayers extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text()();
  TextColumn get scoreVersionId => text()();
  IntColumn get pageNumber => integer()();
  TextColumn get strokes => text()();
  TextColumn get notes => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('AnnotationStrokeRow')
class AnnotationStrokes extends Table {
  TextColumn get id => text()();
  TextColumn get layerId => text().references(AnnotationLayers, #id)();
  TextColumn get color => text()();
  RealColumn get strokeWidth => real()();
  TextColumn get points => text()();
  TextColumn get tool => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('AnnotationNoteRow')
class AnnotationNotes extends Table {
  TextColumn get id => text()();
  TextColumn get layerId => text().references(AnnotationLayers, #id)();
  RealColumn get x => real()();
  RealColumn get y => real()();
  TextColumn get noteText => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('MediaAssetRow')
class MediaAssets extends Table {
  TextColumn get id => text()();
  TextColumn get pieceId => text().references(Pieces, #id)();
  TextColumn get filePath => text()();
  TextColumn get remoteUrl => text().nullable()();
  TextColumn get format => text()();
  IntColumn get durationMs => integer().nullable()();
  IntColumn get fileSizeBytes => integer().nullable()();
  TextColumn get thumbnailPath => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('MediaMatchCandidateRow')
class MediaMatchCandidates extends Table {
  TextColumn get id => text()();
  TextColumn get mediaAssetId => text().references(MediaAssets, #id)();
  TextColumn get pieceId => text().references(Pieces, #id)();
  TextColumn get scoreVersionId => text().references(ScoreVersions, #id)();
  RealColumn get similarityScore => real()();
  TextColumn get status => text()();
  TextColumn get aiNotes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class ProcessingJobs extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()();
  TextColumn get mediaAssetId => text().nullable()();
  TextColumn get pieceId => text().references(Pieces, #id).nullable()();
  TextColumn get scoreVersionId => text().nullable()();
  TextColumn get status => text()();
  RealColumn get progress => real().nullable()();
  TextColumn get errorMessage => text().nullable()();
  TextColumn get result => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class ReviewItems extends Table {
  TextColumn get id => text()();
  TextColumn get pieceId => text().references(Pieces, #id)();
  TextColumn get mediaAssetId => text().nullable()();
  TextColumn get scoreVersionId => text().nullable()();
  TextColumn get status => text()();
  TextColumn get instructorNotes => text().nullable()();
  RealColumn get overallRating => real().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get reviewedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class PieceHistoryDrafts extends Table {
  TextColumn get id => text()();
  TextColumn get pieceId => text().references(Pieces, #id)();
  IntColumn get totalPracticeSessions => integer()();
  Int64Column get totalPracticeTimeMs => int64()();
  IntColumn get lastPlayedPage => integer().nullable()();
  TextColumn get currentFocus => text().nullable()();
  DateTimeColumn get lastPracticedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class SyncStates extends Table {
  TextColumn get entityType => text()();
  TextColumn get entityId => text().nullable()();
  TextColumn get lastSyncHash => text()();
  DateTimeColumn get lastSyncAt => dateTime()();
  TextColumn get lastDirection => text()();
  TextColumn get status => text()();
  TextColumn get errorMessage => text().nullable()();

  @override
  Set<Column> get primaryKey => {entityType, entityId};
}

@DataClassName('PracticeRecordingRow')
class PracticeRecordings extends Table {
  TextColumn get id => text()();
  TextColumn get pieceId => text().references(Pieces, #id)();
  TextColumn get profileId => text()();
  TextColumn get scoreVersionId => text().nullable()();
  TextColumn get filePath => text()();
  IntColumn get durationMs => integer()();
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get isSentToTeacher => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
