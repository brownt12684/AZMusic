import 'package:azmusic/domain/entities/library_entry.dart';
import 'package:azmusic/domain/entities/piece.dart';
import 'package:azmusic/domain/entities/score_version.dart';
import 'package:azmusic/presentation/screens/library/library_browse_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('findAlphaJumpIndex returns the first matching row in filtered results',
      () {
    final entries = [
      _entry(title: 'Bourree'),
      _entry(title: 'Gavotte'),
      _entry(title: 'Minuet'),
      _entry(title: 'Musette'),
    ];

    final index = findAlphaJumpIndex(
      entries,
      'M',
      selector: (entry) => entry.piece.sortTitle,
    );

    expect(index, 2);
  });

  test('findAlphaJumpIndex stays null when the dragged letter has no match',
      () {
    final entries = [
      _entry(title: 'Etude'),
      _entry(title: 'Gigue'),
    ];

    final index = findAlphaJumpIndex(
      entries,
      'Q',
      selector: (entry) => entry.piece.sortTitle,
    );

    expect(index, isNull);
  });
}

LibraryEntry _entry({
  required String title,
}) {
  final now = DateTime.utc(2026, 5, 20);
  return LibraryEntry(
    piece: Piece(
      id: title,
      title: title,
      createdAt: now,
      updatedAt: now,
    ),
    scoreVersions: [
      ScoreVersion(
        id: 'score-$title',
        pieceId: title,
        title: 'Original import',
        filePath: '/tmp/$title.pdf',
        format: 'pdf',
        createdAt: now,
        updatedAt: now,
      ),
    ],
  );
}
