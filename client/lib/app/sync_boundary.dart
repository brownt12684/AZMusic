import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../presentation/providers/app_providers.dart';
import '../presentation/providers/piece_providers.dart';
import '../presentation/providers/review_providers.dart';

class SyncBoundary extends ConsumerStatefulWidget {
  const SyncBoundary({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  ConsumerState<SyncBoundary> createState() => _SyncBoundaryState();
}

class _SyncBoundaryState extends ConsumerState<SyncBoundary>
    with WidgetsBindingObserver {
  StreamSubscription<bool>? _connectivitySubscription;
  bool? _lastConnectivityState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _triggerSync(SyncTrigger.appLaunch);
      _connectivitySubscription =
          ref.read(networkInfoProvider).onConnectivityChanged.listen(
        (isConnected) {
          final previous = _lastConnectivityState;
          _lastConnectivityState = isConnected;
          if (previous == false && isConnected) {
            _triggerSync(SyncTrigger.connectivityReturn);
          }
        },
      );
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _triggerSync(SyncTrigger.appForeground);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_connectivitySubscription?.cancel());
    super.dispose();
  }

  void _triggerSync(SyncTrigger trigger) {
    unawaited(
        ref.read(allPiecesProvider.notifier).loadPieces(trigger: trigger));
    ref.invalidate(parentReviewQueueProvider);
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
