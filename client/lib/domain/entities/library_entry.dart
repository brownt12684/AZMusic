import 'piece.dart';
import 'score_version.dart';

/// A piece together with every locally available score version.
class LibraryEntry {
  const LibraryEntry({
    required this.piece,
    required this.scoreVersions,
  });

  final Piece piece;
  final List<ScoreVersion> scoreVersions;

  ScoreVersion get primaryScore {
    for (final scoreVersion in scoreVersions.reversed) {
      if (scoreVersion.isPrimary) {
        return scoreVersion;
      }
    }
    return scoreVersions.last;
  }

  Map<String, dynamic> toJson() {
    return {
      'piece': piece.toJson(),
      'score_versions':
          scoreVersions.map((version) => version.toJson()).toList(),
    };
  }

  factory LibraryEntry.fromJson(Map<String, dynamic> json) {
    return LibraryEntry(
      piece: Piece.fromJson(json['piece'] as Map<String, dynamic>),
      scoreVersions: (json['score_versions'] as List<dynamic>)
          .map((version) =>
              ScoreVersion.fromJson(version as Map<String, dynamic>))
          .toList(),
    );
  }
}
