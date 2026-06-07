class ProcessingSettings {
  const ProcessingSettings({
    this.audiverisCliPath,
    this.homrCliPath,
    this.musescoreCliPath,
    this.musescoreStylePath,
    this.ocrCliPath,
    this.ocrLanguage = 'eng',
    this.ocrEffort = 'balanced',
    this.omrStrategy = 'audiveris_quality_sweep',
    this.maxConcurrentJobs = 2,
    this.localLlmProvider,
    this.localLlmModel,
    this.cloudEnabled = false,
    this.cloudProvider,
    this.cloudModel,
    this.cloudBaseUrl,
    this.cloudApiKey,
    this.cloudApiKeyConfigured = false,
    required this.processingMode,
    required this.allowStubMusicXml,
    required this.productionMode,
    this.lastProcessingError,
    this.lastLlmProcessingError,
    this.lastCloudProcessingError,
    required this.updatedAt,
  });

  final String? audiverisCliPath;
  final String? homrCliPath;
  final String? musescoreCliPath;
  final String? musescoreStylePath;
  final String? ocrCliPath;
  final String ocrLanguage;
  final String ocrEffort;
  final String omrStrategy;
  final int maxConcurrentJobs;
  final String? localLlmProvider;
  final String? localLlmModel;
  final bool cloudEnabled;
  final String? cloudProvider;
  final String? cloudModel;
  final String? cloudBaseUrl;
  final String? cloudApiKey;
  final bool cloudApiKeyConfigured;
  final String processingMode;
  final bool allowStubMusicXml;
  final bool productionMode;
  final String? lastProcessingError;
  final String? lastLlmProcessingError;
  final String? lastCloudProcessingError;
  final DateTime updatedAt;

  ProcessingSettings copyWith({
    String? audiverisCliPath,
    String? homrCliPath,
    String? musescoreCliPath,
    String? musescoreStylePath,
    String? ocrCliPath,
    String? ocrLanguage,
    String? ocrEffort,
    String? omrStrategy,
    int? maxConcurrentJobs,
    String? localLlmProvider,
    String? localLlmModel,
    bool? cloudEnabled,
    String? cloudProvider,
    String? cloudModel,
    String? cloudBaseUrl,
    String? cloudApiKey,
    bool? cloudApiKeyConfigured,
    String? processingMode,
    bool? allowStubMusicXml,
    bool? productionMode,
    String? lastProcessingError,
    String? lastLlmProcessingError,
    String? lastCloudProcessingError,
    DateTime? updatedAt,
    bool clearAudiverisPath = false,
    bool clearHomrPath = false,
    bool clearMuseScorePath = false,
    bool clearMuseScoreStylePath = false,
    bool clearOcrPath = false,
    bool clearLocalLlmProvider = false,
    bool clearLocalLlmModel = false,
    bool clearCloudProvider = false,
    bool clearCloudModel = false,
    bool clearCloudBaseUrl = false,
    bool clearCloudApiKey = false,
  }) {
    return ProcessingSettings(
      audiverisCliPath:
          clearAudiverisPath ? null : audiverisCliPath ?? this.audiverisCliPath,
      homrCliPath: clearHomrPath ? null : homrCliPath ?? this.homrCliPath,
      musescoreCliPath:
          clearMuseScorePath ? null : musescoreCliPath ?? this.musescoreCliPath,
      musescoreStylePath: clearMuseScoreStylePath
          ? null
          : musescoreStylePath ?? this.musescoreStylePath,
      ocrCliPath: clearOcrPath ? null : ocrCliPath ?? this.ocrCliPath,
      ocrLanguage: ocrLanguage ?? this.ocrLanguage,
      ocrEffort: ocrEffort ?? this.ocrEffort,
      omrStrategy: omrStrategy ?? this.omrStrategy,
      maxConcurrentJobs: maxConcurrentJobs ?? this.maxConcurrentJobs,
      localLlmProvider: clearLocalLlmProvider
          ? null
          : localLlmProvider ?? this.localLlmProvider,
      localLlmModel:
          clearLocalLlmModel ? null : localLlmModel ?? this.localLlmModel,
      cloudEnabled: cloudEnabled ?? this.cloudEnabled,
      cloudProvider:
          clearCloudProvider ? null : cloudProvider ?? this.cloudProvider,
      cloudModel: clearCloudModel ? null : cloudModel ?? this.cloudModel,
      cloudBaseUrl:
          clearCloudBaseUrl ? null : cloudBaseUrl ?? this.cloudBaseUrl,
      cloudApiKey: clearCloudApiKey ? null : cloudApiKey ?? this.cloudApiKey,
      cloudApiKeyConfigured:
          cloudApiKeyConfigured ?? this.cloudApiKeyConfigured,
      processingMode: processingMode ?? this.processingMode,
      allowStubMusicXml: allowStubMusicXml ?? this.allowStubMusicXml,
      productionMode: productionMode ?? this.productionMode,
      lastProcessingError: lastProcessingError ?? this.lastProcessingError,
      lastLlmProcessingError:
          lastLlmProcessingError ?? this.lastLlmProcessingError,
      lastCloudProcessingError:
          lastCloudProcessingError ?? this.lastCloudProcessingError,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'audiveris_cli_path': audiverisCliPath,
      'homr_cli_path': homrCliPath,
      'musescore_cli_path': musescoreCliPath,
      'musescore_style_path': musescoreStylePath,
      'ocr_cli_path': ocrCliPath,
      'ocr_language': ocrLanguage,
      'ocr_effort': ocrEffort,
      'omr_strategy': omrStrategy,
      'max_concurrent_jobs': maxConcurrentJobs,
      'local_llm_provider': localLlmProvider,
      'local_llm_model': localLlmModel,
      'cloud_enabled': cloudEnabled,
      'cloud_provider': cloudProvider,
      'cloud_model': cloudModel,
      'cloud_base_url': cloudBaseUrl,
      if (cloudApiKey != null) 'cloud_api_key': cloudApiKey,
      'processing_mode': processingMode,
      'allow_stub_musicxml': allowStubMusicXml,
    };
  }

  factory ProcessingSettings.fromJson(Map<String, dynamic> json) {
    return ProcessingSettings(
      audiverisCliPath: json['audiveris_cli_path'] as String?,
      homrCliPath: json['homr_cli_path'] as String?,
      musescoreCliPath: json['musescore_cli_path'] as String?,
      musescoreStylePath: json['musescore_style_path'] as String?,
      ocrCliPath: json['ocr_cli_path'] as String?,
      ocrLanguage: json['ocr_language'] as String? ?? 'eng',
      ocrEffort: json['ocr_effort'] as String? ?? 'balanced',
      omrStrategy: json['omr_strategy'] as String? ?? 'audiveris_quality_sweep',
      maxConcurrentJobs: json['max_concurrent_jobs'] as int? ?? 2,
      localLlmProvider: json['local_llm_provider'] as String?,
      localLlmModel: json['local_llm_model'] as String?,
      cloudEnabled: json['cloud_enabled'] as bool? ?? false,
      cloudProvider: json['cloud_provider'] as String?,
      cloudModel: json['cloud_model'] as String?,
      cloudBaseUrl: json['cloud_base_url'] as String?,
      cloudApiKeyConfigured: json['cloud_api_key_configured'] as bool? ?? false,
      processingMode: json['processing_mode'] as String? ?? 'server_only',
      allowStubMusicXml: json['allow_stub_musicxml'] as bool? ?? true,
      productionMode: json['production_mode'] as bool? ?? false,
      lastProcessingError: json['last_processing_error'] as String?,
      lastLlmProcessingError: json['last_llm_processing_error'] as String?,
      lastCloudProcessingError: json['last_cloud_processing_error'] as String?,
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class ProcessingExecutableStatus {
  const ProcessingExecutableStatus({
    required this.name,
    this.configuredPath,
    this.discoveredPath,
    required this.configured,
    required this.available,
    this.version,
    this.error,
  });

  final String name;
  final String? configuredPath;
  final String? discoveredPath;
  final bool configured;
  final bool available;
  final String? version;
  final String? error;

  factory ProcessingExecutableStatus.fromJson(Map<String, dynamic> json) {
    return ProcessingExecutableStatus(
      name: json['name'] as String,
      configuredPath: json['configured_path'] as String?,
      discoveredPath: json['discovered_path'] as String?,
      configured: json['configured'] as bool? ?? false,
      available: json['available'] as bool? ?? false,
      version: json['version'] as String?,
      error: json['error'] as String?,
    );
  }
}

class DeviceWorkerRegistration {
  const DeviceWorkerRegistration({
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.capabilities,
    required this.enabled,
    required this.registeredAt,
    required this.lastSeenAt,
  });

  final String deviceId;
  final String deviceName;
  final String platform;
  final List<String> capabilities;
  final bool enabled;
  final DateTime registeredAt;
  final DateTime lastSeenAt;

  factory DeviceWorkerRegistration.fromJson(Map<String, dynamic> json) {
    return DeviceWorkerRegistration(
      deviceId: json['device_id'] as String,
      deviceName: json['device_name'] as String,
      platform: json['platform'] as String,
      capabilities: (json['capabilities'] as List<dynamic>? ?? const [])
          .map((item) => item as String)
          .toList(),
      enabled: json['enabled'] as bool? ?? true,
      registeredAt: DateTime.parse(json['registered_at'] as String),
      lastSeenAt: DateTime.parse(json['last_seen_at'] as String),
    );
  }
}

class ProcessingCapabilities {
  const ProcessingCapabilities({
    required this.serverOnline,
    required this.settings,
    required this.audiveris,
    required this.homr,
    required this.musescore,
    required this.ocr,
    required this.localLlm,
    required this.cloudLlm,
    required this.deviceWorkersEnabled,
    required this.cloudWorkersEnabled,
    required this.deviceWorkers,
    required this.jobSummary,
    required this.warnings,
  });

  final bool serverOnline;
  final ProcessingSettings settings;
  final ProcessingExecutableStatus audiveris;
  final ProcessingExecutableStatus homr;
  final ProcessingExecutableStatus musescore;
  final ProcessingExecutableStatus ocr;
  final ProcessingExecutableStatus localLlm;
  final ProcessingExecutableStatus cloudLlm;
  final bool deviceWorkersEnabled;
  final bool cloudWorkersEnabled;
  final List<DeviceWorkerRegistration> deviceWorkers;
  final ProcessingJobSummary jobSummary;
  final List<String> warnings;

  factory ProcessingCapabilities.fromJson(Map<String, dynamic> json) {
    return ProcessingCapabilities(
      serverOnline: json['server_online'] as bool? ?? false,
      settings: ProcessingSettings.fromJson(
        json['settings'] as Map<String, dynamic>,
      ),
      audiveris: ProcessingExecutableStatus.fromJson(
        json['audiveris'] as Map<String, dynamic>,
      ),
      homr: ProcessingExecutableStatus.fromJson(
        json['homr'] as Map<String, dynamic>? ??
            const <String, dynamic>{
              'name': 'HOMR',
              'configured': false,
              'available': false,
            },
      ),
      musescore: ProcessingExecutableStatus.fromJson(
        json['musescore'] as Map<String, dynamic>,
      ),
      ocr: ProcessingExecutableStatus.fromJson(
        json['ocr'] as Map<String, dynamic>? ??
            const <String, dynamic>{
              'name': 'Tesseract OCR',
              'configured': false,
              'available': false,
            },
      ),
      localLlm: ProcessingExecutableStatus.fromJson(
        json['local_llm'] as Map<String, dynamic>? ??
            const <String, dynamic>{
              'name': 'Local LLM',
              'configured': false,
              'available': false,
            },
      ),
      cloudLlm: ProcessingExecutableStatus.fromJson(
        json['cloud_llm'] as Map<String, dynamic>? ??
            const <String, dynamic>{
              'name': 'Cloud LLM',
              'configured': false,
              'available': false,
            },
      ),
      deviceWorkersEnabled: json['device_workers_enabled'] as bool? ?? false,
      cloudWorkersEnabled: json['cloud_workers_enabled'] as bool? ?? false,
      deviceWorkers: (json['device_workers'] as List<dynamic>? ?? const [])
          .map(
            (item) => DeviceWorkerRegistration.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(),
      jobSummary: ProcessingJobSummary.fromJson(
        json['job_summary'] as Map<String, dynamic>? ??
            const <String, dynamic>{},
      ),
      warnings: (json['warnings'] as List<dynamic>? ?? const [])
          .map((item) => item as String)
          .toList(),
    );
  }
}

class ProcessingJobSummary {
  const ProcessingJobSummary({
    required this.queuedCount,
    required this.runningCount,
    required this.failedCount,
    required this.succeededCount,
    required this.canceledCount,
    this.lastFailedJob,
  });

  final int queuedCount;
  final int runningCount;
  final int failedCount;
  final int succeededCount;
  final int canceledCount;
  final ProcessingJobFailure? lastFailedJob;

  factory ProcessingJobSummary.fromJson(Map<String, dynamic> json) {
    final lastFailed = json['last_failed_job'];
    return ProcessingJobSummary(
      queuedCount: json['queued_count'] as int? ?? 0,
      runningCount: json['running_count'] as int? ?? 0,
      failedCount: json['failed_count'] as int? ?? 0,
      succeededCount: json['succeeded_count'] as int? ?? 0,
      canceledCount: json['canceled_count'] as int? ?? 0,
      lastFailedJob: lastFailed is Map<String, dynamic>
          ? ProcessingJobFailure.fromJson(lastFailed)
          : null,
    );
  }
}

class ProcessingJobFailure {
  const ProcessingJobFailure({
    required this.id,
    this.pieceId,
    required this.jobType,
    this.errorMessage,
    required this.updatedAt,
  });

  final String id;
  final String? pieceId;
  final String jobType;
  final String? errorMessage;
  final DateTime updatedAt;

  factory ProcessingJobFailure.fromJson(Map<String, dynamic> json) {
    return ProcessingJobFailure(
      id: json['id'] as String,
      pieceId: json['piece_id'] as String?,
      jobType: json['job_type'] as String,
      errorMessage: json['error_message'] as String?,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class ProcessingValidation {
  const ProcessingValidation({
    required this.valid,
    required this.audiveris,
    required this.homr,
    required this.musescore,
    required this.ocr,
    required this.warnings,
  });

  final bool valid;
  final ProcessingExecutableStatus audiveris;
  final ProcessingExecutableStatus homr;
  final ProcessingExecutableStatus musescore;
  final ProcessingExecutableStatus ocr;
  final List<String> warnings;

  factory ProcessingValidation.fromJson(Map<String, dynamic> json) {
    return ProcessingValidation(
      valid: json['valid'] as bool? ?? false,
      audiveris: ProcessingExecutableStatus.fromJson(
        json['audiveris'] as Map<String, dynamic>,
      ),
      homr: ProcessingExecutableStatus.fromJson(
        json['homr'] as Map<String, dynamic>? ??
            const <String, dynamic>{
              'name': 'HOMR',
              'configured': false,
              'available': false,
            },
      ),
      musescore: ProcessingExecutableStatus.fromJson(
        json['musescore'] as Map<String, dynamic>,
      ),
      ocr: ProcessingExecutableStatus.fromJson(
        json['ocr'] as Map<String, dynamic>? ??
            const <String, dynamic>{
              'name': 'Tesseract OCR',
              'configured': false,
              'available': false,
            },
      ),
      warnings: (json['warnings'] as List<dynamic>? ?? const [])
          .map((item) => item as String)
          .toList(),
    );
  }
}
