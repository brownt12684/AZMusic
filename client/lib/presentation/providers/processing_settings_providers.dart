import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/processing_settings.dart';
import 'review_providers.dart';

final processingCapabilitiesProvider =
    FutureProvider<ProcessingCapabilities>((ref) {
  return ref
      .read(serverPieceSyncRepositoryProvider)
      .fetchProcessingCapabilities();
});

final processingSettingsProvider =
    AsyncNotifierProvider<ProcessingSettingsNotifier, ProcessingSettings>(
  ProcessingSettingsNotifier.new,
);

class ProcessingSettingsNotifier extends AsyncNotifier<ProcessingSettings> {
  @override
  Future<ProcessingSettings> build() {
    return ref
        .read(serverPieceSyncRepositoryProvider)
        .fetchProcessingSettings();
  }

  Future<ProcessingValidation> validate(ProcessingSettings settings) {
    return ref
        .read(serverPieceSyncRepositoryProvider)
        .validateProcessingSettings(settings);
  }

  Future<void> save(ProcessingSettings settings) async {
    state = const AsyncValue.loading();
    try {
      final saved = await ref
          .read(serverPieceSyncRepositoryProvider)
          .updateProcessingSettings(settings);
      ref.invalidate(processingCapabilitiesProvider);
      state = AsyncValue.data(saved);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }
}
