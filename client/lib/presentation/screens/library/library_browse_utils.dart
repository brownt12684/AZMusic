import '../../../domain/entities/library_entry.dart';

typedef LibraryAlphaSelector = String Function(LibraryEntry entry);

int? findAlphaJumpIndex(
  List<LibraryEntry> entries,
  String letter, {
  required LibraryAlphaSelector selector,
}) {
  final normalizedLetter = letter.trim().toLowerCase();
  if (normalizedLetter.isEmpty) {
    return null;
  }

  for (var index = 0; index < entries.length; index++) {
    if (selector(entries[index]).trim().toLowerCase().startsWith(
          normalizedLetter,
        )) {
      return index;
    }
  }

  return null;
}
