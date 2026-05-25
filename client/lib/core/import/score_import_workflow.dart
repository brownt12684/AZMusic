import '../../data/repositories/local_library_repository.dart';
import '../../domain/entities/library_entry.dart';
import 'score_import_picker.dart';

class ScoreImportWorkflow {
  const ScoreImportWorkflow({
    required ScoreImportPicker picker,
    required LocalLibraryRepository repository,
  })  : _picker = picker,
        _repository = repository;

  final ScoreImportPicker _picker;
  final LocalLibraryRepository _repository;

  Future<LibraryEntry?> importPickedScore() async {
    final selectedPath = await _picker.pickScorePath();
    if (selectedPath == null) {
      return null;
    }

    return _repository.importScore(sourcePath: selectedPath);
  }
}
