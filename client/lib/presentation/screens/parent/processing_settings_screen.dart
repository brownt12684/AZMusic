import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_keys.dart';
import '../../../core/config/app_config.dart';
import '../../../domain/entities/processing_settings.dart';
import '../../providers/app_providers.dart';
import '../../providers/processing_settings_providers.dart';

class ProcessingSettingsScreen extends ConsumerStatefulWidget {
  const ProcessingSettingsScreen({super.key});

  @override
  ConsumerState<ProcessingSettingsScreen> createState() =>
      _ProcessingSettingsScreenState();
}

class _ProcessingSettingsScreenState
    extends ConsumerState<ProcessingSettingsScreen> {
  final TextEditingController _audiverisPathController =
      TextEditingController();
  final TextEditingController _musescorePathController =
      TextEditingController();
  final TextEditingController _ocrPathController = TextEditingController();
  final TextEditingController _ocrLanguageController = TextEditingController();
  final TextEditingController _localLlmProviderController =
      TextEditingController();
  final TextEditingController _localLlmModelController =
      TextEditingController();
  final TextEditingController _cloudProviderController =
      TextEditingController();
  final TextEditingController _cloudModelController = TextEditingController();
  final TextEditingController _cloudBaseUrlController = TextEditingController();
  final TextEditingController _cloudApiKeyController = TextEditingController();

  bool _hydrated = false;
  bool _allowStubMusicXml = true;
  bool _cloudEnabled = false;
  bool _showAdvancedSettings = false;
  String _processingMode = 'server_only';
  ProcessingValidation? _lastValidation;

  @override
  void dispose() {
    _audiverisPathController.dispose();
    _musescorePathController.dispose();
    _ocrPathController.dispose();
    _ocrLanguageController.dispose();
    _localLlmProviderController.dispose();
    _localLlmModelController.dispose();
    _cloudProviderController.dispose();
    _cloudModelController.dispose();
    _cloudBaseUrlController.dispose();
    _cloudApiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(processingSettingsProvider);
    final capabilities = ref.watch(processingCapabilitiesProvider);
    final serverHealth = ref.watch(serverHealthProvider);
    final theme = Theme.of(context);

    return Scaffold(
      key: AppKeys.parentProcessingSettingsScreen,
      appBar: AppBar(
        title: const Text('Server processing'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _hydrated = false;
          ref.invalidate(processingSettingsProvider);
          ref.invalidate(processingCapabilitiesProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ServerConnectionCard(serverHealth: serverHealth),
            const SizedBox(height: 16),
            const _PairingCard(),
            const SizedBox(height: 16),
            settings.when(
              data: (value) {
                _hydrate(value);
                return _SettingsForm(
                  audiverisPathController: _audiverisPathController,
                  musescorePathController: _musescorePathController,
                  ocrPathController: _ocrPathController,
                  ocrLanguageController: _ocrLanguageController,
                  localLlmProviderController: _localLlmProviderController,
                  localLlmModelController: _localLlmModelController,
                  cloudProviderController: _cloudProviderController,
                  cloudModelController: _cloudModelController,
                  cloudBaseUrlController: _cloudBaseUrlController,
                  cloudApiKeyController: _cloudApiKeyController,
                  showAdvancedSettings: _showAdvancedSettings,
                  allowStubMusicXml: _allowStubMusicXml,
                  productionMode: value.productionMode,
                  cloudEnabled: _cloudEnabled,
                  processingMode: _processingMode,
                  onShowAdvancedChanged: (value) {
                    setState(() {
                      _showAdvancedSettings = value;
                    });
                  },
                  onAllowStubChanged: (value) {
                    setState(() {
                      _allowStubMusicXml = value;
                    });
                  },
                  onCloudEnabledChanged: (value) {
                    setState(() {
                      _cloudEnabled = value;
                    });
                  },
                  onModeChanged: (value) {
                    setState(() {
                      _processingMode = value;
                    });
                  },
                  onValidate: () => _validate(value),
                  onSave: () => _save(value),
                );
              },
              error: (error, _) => _ErrorPanel(
                title: 'Unable to load processing settings',
                message: '$error',
              ),
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_lastValidation != null)
              _ValidationPanel(validation: _lastValidation!),
            const SizedBox(height: 16),
            capabilities.when(
              data: (value) => _CapabilitiesPanel(capabilities: value),
              error: (error, _) => _ErrorPanel(
                title: 'Unable to load processing capabilities',
                message: '$error',
              ),
              loading: () => Text(
                'Checking installed processing tools...',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _hydrate(ProcessingSettings settings) {
    if (_hydrated) {
      return;
    }
    _audiverisPathController.text = settings.audiverisCliPath ?? '';
    _musescorePathController.text = settings.musescoreCliPath ?? '';
    _ocrPathController.text = settings.ocrCliPath ?? '';
    _ocrLanguageController.text = settings.ocrLanguage;
    _localLlmProviderController.text = settings.localLlmProvider ?? '';
    _localLlmModelController.text = settings.localLlmModel ?? '';
    _cloudProviderController.text = settings.cloudProvider ?? '';
    _cloudModelController.text = settings.cloudModel ?? '';
    _cloudBaseUrlController.text = settings.cloudBaseUrl ?? '';
    _cloudApiKeyController.text = '';
    _allowStubMusicXml =
        settings.productionMode ? false : settings.allowStubMusicXml;
    _cloudEnabled = settings.cloudEnabled;
    _processingMode = settings.processingMode;
    _hydrated = true;
  }

  ProcessingSettings _editedSettings(ProcessingSettings base) {
    final audiverisPath = _audiverisPathController.text.trim();
    final musescorePath = _musescorePathController.text.trim();
    final ocrPath = _ocrPathController.text.trim();
    final ocrLanguage = _ocrLanguageController.text.trim();
    final localLlmProvider = _localLlmProviderController.text.trim();
    final localLlmModel = _localLlmModelController.text.trim();
    final cloudProvider = _cloudProviderController.text.trim();
    final cloudModel = _cloudModelController.text.trim();
    final cloudBaseUrl = _cloudBaseUrlController.text.trim();
    final cloudApiKey = _cloudApiKeyController.text.trim();
    return base.copyWith(
      audiverisCliPath: audiverisPath.isEmpty ? null : audiverisPath,
      musescoreCliPath: musescorePath.isEmpty ? null : musescorePath,
      ocrCliPath: ocrPath.isEmpty ? null : ocrPath,
      ocrLanguage: ocrLanguage.isEmpty ? 'eng' : ocrLanguage,
      localLlmProvider: localLlmProvider.isEmpty ? null : localLlmProvider,
      localLlmModel: localLlmModel.isEmpty ? null : localLlmModel,
      cloudEnabled: _cloudEnabled,
      cloudProvider: cloudProvider.isEmpty ? null : cloudProvider,
      cloudModel: cloudModel.isEmpty ? null : cloudModel,
      cloudBaseUrl: cloudBaseUrl.isEmpty ? null : cloudBaseUrl,
      cloudApiKey: cloudApiKey.isEmpty ? null : cloudApiKey,
      clearAudiverisPath: audiverisPath.isEmpty,
      clearMuseScorePath: musescorePath.isEmpty,
      clearOcrPath: ocrPath.isEmpty,
      clearLocalLlmProvider: localLlmProvider.isEmpty,
      clearLocalLlmModel: localLlmModel.isEmpty,
      clearCloudProvider: cloudProvider.isEmpty,
      clearCloudModel: cloudModel.isEmpty,
      clearCloudBaseUrl: cloudBaseUrl.isEmpty,
      clearCloudApiKey: cloudApiKey.isEmpty && !base.cloudApiKeyConfigured,
      processingMode: _processingMode,
      allowStubMusicXml: base.productionMode ? false : _allowStubMusicXml,
    );
  }

  Future<void> _validate(ProcessingSettings base) async {
    final validation = await ref
        .read(processingSettingsProvider.notifier)
        .validate(_editedSettings(base));
    if (!mounted) {
      return;
    }
    setState(() {
      _lastValidation = validation;
    });
  }

  Future<void> _save(ProcessingSettings base) async {
    try {
      await ref
          .read(processingSettingsProvider.notifier)
          .save(_editedSettings(base));
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Processing settings saved.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save settings: $error')),
      );
    }
  }
}

class _SettingsForm extends StatelessWidget {
  const _SettingsForm({
    required this.audiverisPathController,
    required this.musescorePathController,
    required this.ocrPathController,
    required this.ocrLanguageController,
    required this.localLlmProviderController,
    required this.localLlmModelController,
    required this.cloudProviderController,
    required this.cloudModelController,
    required this.cloudBaseUrlController,
    required this.cloudApiKeyController,
    required this.showAdvancedSettings,
    required this.allowStubMusicXml,
    required this.productionMode,
    required this.cloudEnabled,
    required this.processingMode,
    required this.onShowAdvancedChanged,
    required this.onAllowStubChanged,
    required this.onCloudEnabledChanged,
    required this.onModeChanged,
    required this.onValidate,
    required this.onSave,
  });

  final TextEditingController audiverisPathController;
  final TextEditingController musescorePathController;
  final TextEditingController ocrPathController;
  final TextEditingController ocrLanguageController;
  final TextEditingController localLlmProviderController;
  final TextEditingController localLlmModelController;
  final TextEditingController cloudProviderController;
  final TextEditingController cloudModelController;
  final TextEditingController cloudBaseUrlController;
  final TextEditingController cloudApiKeyController;
  final bool showAdvancedSettings;
  final bool allowStubMusicXml;
  final bool productionMode;
  final bool cloudEnabled;
  final String processingMode;
  final ValueChanged<bool> onShowAdvancedChanged;
  final ValueChanged<bool> onAllowStubChanged;
  final ValueChanged<bool> onCloudEnabledChanged;
  final ValueChanged<String> onModeChanged;
  final VoidCallback onValidate;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Processing setup',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'In the finished setup, AZMusic should install or discover the score-processing tools automatically. These low-level paths are available only for development and troubleshooting.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              key: AppKeys.advancedProcessingSettingsToggle,
              contentPadding: EdgeInsets.zero,
              value: showAdvancedSettings,
              onChanged: onShowAdvancedChanged,
              title: const Text('Show advanced engine paths'),
              subtitle: const Text(
                'Only needed when Audiveris or MuseScore was not found automatically.',
              ),
            ),
            if (showAdvancedSettings) ...[
              const SizedBox(height: 12),
              TextField(
                controller: audiverisPathController,
                decoration: const InputDecoration(
                  labelText: 'Audiveris CLI path',
                  helperText:
                      'Advanced: used for real OMR and MusicXML generation.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: musescorePathController,
                decoration: const InputDecoration(
                  labelText: 'MuseScore CLI path',
                  helperText:
                      'Advanced: used to render MusicXML into review PDFs.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ocrPathController,
                decoration: const InputDecoration(
                  labelText: 'Tesseract OCR path',
                  helperText:
                      'Advanced: used to read title/composer from scanned PDFs and images.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ocrLanguageController,
                decoration: const InputDecoration(
                  labelText: 'OCR language',
                  helperText: 'Tesseract language code, usually eng.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
            ],
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'server_only',
                  icon: Icon(Icons.dns_outlined),
                  label: Text('Server only'),
                ),
                ButtonSegment(
                  value: 'server_plus_device_workers',
                  icon: Icon(Icons.devices_other_outlined),
                  label: Text('Server + devices'),
                ),
                ButtonSegment(
                  value: 'server_plus_cloud_workers',
                  icon: Icon(Icons.cloud_queue_outlined),
                  label: Text('Server + cloud'),
                ),
                ButtonSegment(
                  value: 'server_plus_device_and_cloud_workers',
                  icon: Icon(Icons.hub_outlined),
                  label: Text('Devices + cloud'),
                ),
              ],
              selected: {processingMode},
              onSelectionChanged: (selection) {
                onModeChanged(selection.first);
              },
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: productionMode ? false : allowStubMusicXml,
              onChanged: productionMode ? null : onAllowStubChanged,
              title: const Text('Allow development stub MusicXML'),
              subtitle: Text(
                productionMode
                    ? 'Disabled in production mode. Audiveris, MuseScore, and Tesseract are required.'
                    : 'Keeps prototyping unblocked when Audiveris is not installed.',
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Experimental processing providers',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Device workers and cloud APIs are optional provider lanes for book classification, metadata suggestions, split validation, and reprocessing. They do not replace parent review or direct MusicXML generation.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: cloudEnabled,
              onChanged: onCloudEnabledChanged,
              title: const Text('Enable experimental cloud provider'),
              subtitle: const Text(
                'Cloud APIs are optional and receive compact page facts, not raw books by default.',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: cloudProviderController,
              decoration: const InputDecoration(
                labelText: 'Cloud provider',
                helperText: 'Examples: openai, gemini, anthropic, custom.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: cloudModelController,
              decoration: const InputDecoration(
                labelText: 'Cloud model',
                helperText: 'Optional model name for the selected provider.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: cloudBaseUrlController,
              decoration: const InputDecoration(
                labelText: 'Cloud base URL',
                helperText:
                    'Optional for custom or OpenAI-compatible endpoints.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: cloudApiKeyController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Cloud API key',
                helperText:
                    'Saved server-side. Leave blank to keep the existing key.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Experimental local LLM review',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This config is reserved for metadata validation and send-back review. The adapter boundary is present; runtime integrations such as Ollama or LM Studio still need to be implemented.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: localLlmProviderController,
              decoration: const InputDecoration(
                labelText: 'Local LLM provider',
                helperText: 'Examples for future adapters: ollama, lmstudio.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: localLlmModelController,
              decoration: const InputDecoration(
                labelText: 'Local LLM model',
                helperText:
                    'Optional model name used by the configured provider.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onValidate,
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('Validate'),
                ),
                FilledButton.icon(
                  onPressed: onSave,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PairingCard extends StatelessWidget {
  const _PairingCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final setupUrl = '${AppConfig.serverBaseUrl}/setup';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pair a device',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pairing is hosted by the AZMusic server setup page. Open this page on the server screen or another device on the same network, then scan the QR code from the device you want to pair.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              key: AppKeys.parentPairingQr,
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Server setup page',
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    setupUrl,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppConfig.isServerPaired
                        ? 'This development client is already paired with ${AppConfig.serverBaseUrl}.'
                        : 'This device is not paired yet.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.qr_code_2_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'The QR code itself is generated on the server setup page, not inside the parent app.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CapabilitiesPanel extends StatelessWidget {
  const _CapabilitiesPanel({required this.capabilities});

  final ProcessingCapabilities capabilities;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current server capability',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            _ExecutableStatusTile(status: capabilities.audiveris),
            const SizedBox(height: 8),
            _ExecutableStatusTile(status: capabilities.musescore),
            const SizedBox(height: 8),
            _ExecutableStatusTile(status: capabilities.ocr),
            const SizedBox(height: 8),
            _ExecutableStatusTile(status: capabilities.localLlm),
            const SizedBox(height: 8),
            _ExecutableStatusTile(status: capabilities.cloudLlm),
            const SizedBox(height: 12),
            _InfoRow(
              label: 'Server mode',
              value: capabilities.settings.productionMode
                  ? 'Production - real processing tools required'
                  : 'Development - stub fallback allowed when enabled',
            ),
            const SizedBox(height: 8),
            _InfoRow(
              label: 'Experimental device workers',
              value: capabilities.deviceWorkersEnabled
                  ? '${capabilities.deviceWorkers.length} registered'
                  : 'Disabled',
            ),
            const SizedBox(height: 8),
            _InfoRow(
              label: 'Experimental cloud workers',
              value: capabilities.cloudWorkersEnabled
                  ? (capabilities.cloudLlm.available
                      ? 'Configured'
                      : 'Enabled, needs configuration')
                  : 'Disabled',
            ),
            const SizedBox(height: 8),
            _InfoRow(
              label: 'Async queue',
              value: '${capabilities.jobSummary.queuedCount} queued, '
                  '${capabilities.jobSummary.runningCount} running, '
                  '${capabilities.jobSummary.failedCount} failed',
            ),
            if (capabilities.jobSummary.lastFailedJob != null) ...[
              const SizedBox(height: 8),
              _InfoRow(
                label: 'Latest job failure',
                value: capabilities.jobSummary.lastFailedJob!.errorMessage ??
                    capabilities.jobSummary.lastFailedJob!.jobType,
              ),
            ],
            if (capabilities.warnings.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...capabilities.warnings.map(
                (warning) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    warning,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
            if (capabilities.settings.lastProcessingError?.isNotEmpty ??
                false) ...[
              const SizedBox(height: 12),
              Text(
                'Last processing error',
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              Text(
                capabilities.settings.lastProcessingError!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            if (capabilities.settings.lastLlmProcessingError?.isNotEmpty ??
                false) ...[
              const SizedBox(height: 12),
              Text(
                'Last LLM review error',
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              Text(
                capabilities.settings.lastLlmProcessingError!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            if (capabilities.settings.lastCloudProcessingError?.isNotEmpty ??
                false) ...[
              const SizedBox(height: 12),
              Text(
                'Last cloud processing error',
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              Text(
                capabilities.settings.lastCloudProcessingError!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExecutableStatusTile extends StatelessWidget {
  const _ExecutableStatusTile({required this.status});

  final ProcessingExecutableStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color =
        status.available ? const Color(0xFF126B4A) : const Color(0xFF854F0B);
    final isLocalLlm = status.name.toLowerCase().contains('llm');
    final label = status.available
        ? 'Available'
        : isLocalLlm && status.configured
            ? 'Configured, adapter unavailable'
            : status.configured
                ? 'Configured path missing'
                : 'Not configured';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            status.available
                ? Icons.check_circle_outline
                : Icons.warning_amber_outlined,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${status.name}: $label',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  status.version ??
                      status.error ??
                      status.discoveredPath ??
                      'No executable discovered.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ValidationPanel extends StatelessWidget {
  const _ValidationPanel({required this.validation});

  final ProcessingValidation validation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              validation.valid ? 'Validation passed' : 'Validation needs work',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            _InfoRow(
              label: 'Audiveris',
              value: validation.audiveris.available
                  ? 'Available'
                  : validation.audiveris.error ?? 'Not configured',
            ),
            _InfoRow(
              label: 'MuseScore',
              value: validation.musescore.available
                  ? 'Available'
                  : validation.musescore.error ?? 'Not configured',
            ),
            _InfoRow(
              label: 'Tesseract OCR',
              value: validation.ocr.available
                  ? 'Available'
                  : validation.ocr.error ?? 'Not configured',
            ),
            if (validation.warnings.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...validation.warnings.map(
                (warning) => Text(
                  warning,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ServerConnectionCard extends StatelessWidget {
  const _ServerConnectionCard({required this.serverHealth});

  final AsyncValue<ServerHealthState> serverHealth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: serverHealth.when(
          data: (state) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                state.isOnline ? 'Server online' : 'Server offline',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(state.serverUrl),
              if (state.message != null) ...[
                const SizedBox(height: 4),
                Text(
                  state.message!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
          error: (error, _) => Text('Server health failed: $error'),
          loading: () => const Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 10),
              Text('Checking server'),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: theme.textTheme.labelMedium,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(message),
          ],
        ),
      ),
    );
  }
}
