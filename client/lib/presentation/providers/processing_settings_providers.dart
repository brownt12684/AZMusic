import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/network/server_connection_error.dart';
import '../../domain/entities/processing_settings.dart';
import 'review_providers.dart';

final processingCapabilitiesProvider = AsyncNotifierProvider<
    ProcessingCapabilitiesNotifier, ProcessingCapabilities>(
  ProcessingCapabilitiesNotifier.new,
);

class ProcessingCapabilitiesNotifier
    extends AsyncNotifier<ProcessingCapabilities> {
  @override
  Future<ProcessingCapabilities> build() {
    return _loadCapabilities();
  }

  Future<void> refresh({bool showLoading = true}) async {
    if (showLoading) {
      state = const AsyncValue.loading();
    }
    state = await AsyncValue.guard(_loadCapabilities);
  }

  Future<void> refreshInBackground() async {
    try {
      state = AsyncValue.data(await _loadCapabilities());
    } catch (error, stackTrace) {
      if (state.valueOrNull == null) {
        state = AsyncValue.error(error, stackTrace);
      }
    }
  }

  Future<ProcessingCapabilities> _loadCapabilities() {
    if (!AppConfig.isServerPaired) {
      throw const ServerNotPairedException();
    }
    return ref
        .read(serverPieceSyncRepositoryProvider)
        .fetchProcessingCapabilities();
  }
}

final processingSettingsProvider =
    AsyncNotifierProvider<ProcessingSettingsNotifier, ProcessingSettings>(
  ProcessingSettingsNotifier.new,
);

class ProcessingSettingsNotifier extends AsyncNotifier<ProcessingSettings> {
  @override
  Future<ProcessingSettings> build() {
    if (!AppConfig.isServerPaired) {
      throw const ServerNotPairedException();
    }
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
      await ref
          .read(processingCapabilitiesProvider.notifier)
          .refresh(showLoading: false);
      state = AsyncValue.data(saved);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }
}
