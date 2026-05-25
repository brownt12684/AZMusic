import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class ScoreImportPicker {
  Future<String?> pickScorePath();
}

class FilePickerScoreImportPicker implements ScoreImportPicker {
  @override
  Future<String?> pickScorePath() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'webp'],
    );

    return result?.files.single.path;
  }
}

final scoreImportPickerProvider = Provider<ScoreImportPicker>(
  (ref) => FilePickerScoreImportPicker(),
);
