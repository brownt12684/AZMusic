import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_keys.dart';
import '../../../app/launch_options.dart';
import '../../../app/routes/app_router.dart';
import '../../../domain/entities/library_entry.dart';
import '../../providers/piece_providers.dart';
import '../../providers/profile_providers.dart';

class SandboxLauncherScreen extends ConsumerStatefulWidget {
  const SandboxLauncherScreen({super.key});

  @override
  ConsumerState<SandboxLauncherScreen> createState() =>
      _SandboxLauncherScreenState();
}

class _SandboxLauncherScreenState extends ConsumerState<SandboxLauncherScreen> {
  bool _bootstrapping = true;
  bool _busy = false;
  bool _hasAutoNavigated = false;
  String _statusMessage = 'Preparing sandbox...';
  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepareSandbox());
  }

  Future<void> _prepareSandbox() async {
    final launchOptions = ref.read(launchOptionsProvider);

    try {
      final notifier = ref.read(allPiecesProvider.notifier);
      if (launchOptions.resetLibraryOnLaunch) {
        await notifier.clearLibrary();
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _bootstrapping = false;
        _statusMessage = 'Sandbox ready.';
        _error = null;
      });

      if (launchOptions.initialSurface != AppLaunchSurface.sandbox) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }

          _openSurface(launchOptions.initialSurface, replace: true);
        });
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _bootstrapping = false;
        _statusMessage = 'Sandbox setup failed.';
        _error = error;
      });
    }
  }

  Future<void> _performAction(
    String statusMessage,
    Future<void> Function() action,
  ) async {
    if (_busy) {
      return;
    }

    setState(() {
      _busy = true;
      _statusMessage = statusMessage;
      _error = null;
    });

    try {
      await action();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error;
        _statusMessage = 'Sandbox action failed.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _resetSandboxLibrary() async {
    await _performAction('Resetting sandbox library...', () async {
      await ref.read(allPiecesProvider.notifier).clearLibrary();
      if (!mounted) {
        return;
      }

      setState(() {
        _statusMessage = 'Sandbox library reset.';
      });
    });
  }

  Future<void> _openSurface(
    AppLaunchSurface surface, {
    bool replace = false,
  }) async {
    if (_hasAutoNavigated && replace) {
      return;
    }

    final navigator = Navigator.of(context);
    LibraryEntry? entry;

    if (surface == AppLaunchSurface.pieceDetail ||
        surface == AppLaunchSurface.reader) {
      final entries =
          ref.read(allPiecesProvider).valueOrNull ?? const <LibraryEntry>[];
      if (entries.isEmpty) {
        if (mounted) {
          setState(() {
            _statusMessage =
                'Import or select a piece before opening that surface.';
          });
        }
        surface = AppLaunchSurface.library;
      } else {
        entry = entries.first;
      }
    }

    void open(String routeName, {Object? arguments}) {
      if (replace) {
        _hasAutoNavigated = true;
        navigator.pushNamedAndRemoveUntil(
          routeName,
          (route) => false,
          arguments: arguments,
        );
      } else {
        navigator.pushNamed(routeName, arguments: arguments);
      }
    }

    switch (surface) {
      case AppLaunchSurface.login:
        open(AppRouter.login);
        return;
      case AppLaunchSurface.library:
        open(AppRouter.library);
        return;
      case AppLaunchSurface.parentHome:
        ref.read(selectedProfileIdProvider.notifier).state = 'parent-main';
        open(AppRouter.parentHome);
        return;
      case AppLaunchSurface.sandbox:
        return;
      case AppLaunchSurface.pieceDetail:
        open(AppRouter.pieceDetail, arguments: entry!.piece.id);
        return;
      case AppLaunchSurface.reader:
        open(
          AppRouter.reader,
          arguments: {
            'pieceId': entry!.piece.id,
            'scoreVersionId': entry.primaryScore.id,
          },
        );
        return;
      case AppLaunchSurface.reviewQueue:
        ref.read(selectedProfileIdProvider.notifier).state = 'parent-main';
        open(AppRouter.parentHome);
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final launchOptions = ref.watch(launchOptionsProvider);
    final libraryState = ref.watch(allPiecesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      key: AppKeys.sandboxLauncherScreen,
      appBar: AppBar(
        title: const Text('Prototype Sandbox'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_busy || _bootstrapping) const LinearProgressIndicator(),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Launch mode',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Initial target: ${launchOptions.surfaceLabel}',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  launchOptions.resetLibraryOnLaunch
                      ? 'Reset-on-launch is enabled for this sandbox run.'
                      : 'Reset-on-launch is disabled for this sandbox run.',
                ),
                const SizedBox(height: 8),
                Text(_statusMessage),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Last error: $_error',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Local sandbox data',
            child: libraryState.when(
              data: (entries) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${entries.length} local entr${entries.length == 1 ? 'y' : 'ies'}',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Use the library or parent intake import actions to add real music.',
                    ),
                  ],
                );
              },
              error: (error, _) => Text(
                'Unable to inspect the local library.\n$error',
              ),
              loading: () => const Text('Reading local sandbox library...'),
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Prototype actions',
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  key: AppKeys.sandboxResetLibraryButton,
                  onPressed: _busy ? null : _resetSandboxLibrary,
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: const Text('Reset sandbox library'),
                ),
                OutlinedButton.icon(
                  key: AppKeys.sandboxOpenLibraryButton,
                  onPressed: _busy
                      ? null
                      : () => _openSurface(AppLaunchSurface.library),
                  icon: const Icon(Icons.library_music_outlined),
                  label: const Text('Open library'),
                ),
                OutlinedButton.icon(
                  key: AppKeys.sandboxOpenPieceDetailButton,
                  onPressed: _busy
                      ? null
                      : () => _openSurface(AppLaunchSurface.pieceDetail),
                  icon: const Icon(Icons.queue_music_outlined),
                  label: const Text('Open first piece detail'),
                ),
                OutlinedButton.icon(
                  key: AppKeys.sandboxOpenReaderButton,
                  onPressed: _busy
                      ? null
                      : () => _openSurface(AppLaunchSurface.reader),
                  icon: const Icon(Icons.menu_book_outlined),
                  label: const Text('Open first score reader'),
                ),
                OutlinedButton.icon(
                  key: AppKeys.sandboxOpenReviewQueueButton,
                  onPressed: _busy
                      ? null
                      : () => _openSurface(AppLaunchSurface.reviewQueue),
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('Open review queue'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
