import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/note_repository.dart';
import '../../domain/entities/note_entry.dart';
import '../../injection/container.dart';

typedef NotesNotebookRequest = ({
  String profileId,
  String pieceId,
  String scoreVersionId
});

final noteRepositoryProvider = Provider<NoteRepository>(
  (ref) {
    final repository =
        NoteRepository(appDirectory: ref.watch(appDirectoryProvider));
    ref.onDispose(() {
      unawaited(repository.close());
    });
    return repository;
  },
);

final pieceNotesProvider = AsyncNotifierProvider.family<PieceNotesNotifier,
    List<NoteEntry>, NotesNotebookRequest>(
  PieceNotesNotifier.new,
);

class PieceNotesNotifier
    extends FamilyAsyncNotifier<List<NoteEntry>, NotesNotebookRequest> {
  late NoteRepository _repository;

  @override
  Future<List<NoteEntry>> build(NotesNotebookRequest arg) async {
    _repository = ref.watch(noteRepositoryProvider);
    return _repository.loadNotes(
      profileId: arg.profileId,
      pieceId: arg.pieceId,
      scoreVersionId: arg.scoreVersionId,
    );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _repository.loadNotes(
        profileId: arg.profileId,
        pieceId: arg.pieceId,
        scoreVersionId: arg.scoreVersionId,
      ),
    );
  }

  Future<void> addNote({
    required String text,
    int? pageNumber,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }
    await _repository.addNote(
      profileId: arg.profileId,
      pieceId: arg.pieceId,
      scoreVersionId: arg.scoreVersionId,
      text: trimmed,
      pageNumber: pageNumber,
    );
    await refresh();
  }

  Future<void> updateNote({
    required String noteId,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }
    await _repository.updateNote(
      profileId: arg.profileId,
      pieceId: arg.pieceId,
      scoreVersionId: arg.scoreVersionId,
      noteId: noteId,
      text: trimmed,
    );
    await refresh();
  }

  Future<void> deleteNote(String noteId) async {
    await _repository.deleteNote(
      profileId: arg.profileId,
      pieceId: arg.pieceId,
      scoreVersionId: arg.scoreVersionId,
      noteId: noteId,
    );
    await refresh();
  }
}
