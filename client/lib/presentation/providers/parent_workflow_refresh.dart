import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_providers.dart';
import 'piece_providers.dart';
import 'processing_settings_providers.dart';
import 'review_providers.dart';

final parentWorkflowRefreshSchedulerProvider =
    Provider<ParentWorkflowRefreshScheduler>((ref) {
  final scheduler = ParentWorkflowRefreshScheduler();
  ref.onDispose(scheduler.cancel);
  return scheduler;
});

class ParentWorkflowRefreshScheduler {
  final List<Timer> _timers = <Timer>[];

  void schedule(
    WidgetRef ref, {
    SyncTrigger trigger = SyncTrigger.manualRefresh,
    bool Function()? isActive,
  }) {
    cancel();

    bool active() => isActive?.call() ?? true;
    if (!active()) {
      return;
    }

    refreshParentWorkflowInBackground(ref, trigger: trigger);
    for (final delay in const [
      Duration(seconds: 1),
      Duration(seconds: 3),
      Duration(seconds: 7),
    ]) {
      _timers.add(
        Timer(delay, () {
          if (active()) {
            refreshParentWorkflowInBackground(ref, trigger: trigger);
          }
        }),
      );
    }
  }

  void cancel() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
  }
}

void refreshParentWorkflowInBackground(
  WidgetRef ref, {
  SyncTrigger trigger = SyncTrigger.manualRefresh,
}) {
  unawaited(refreshParentWorkflow(ref, trigger: trigger));
}

Future<void> refreshParentWorkflow(
  WidgetRef ref, {
  SyncTrigger trigger = SyncTrigger.manualRefresh,
}) async {
  await Future.wait([
    ref.read(allPiecesProvider.notifier).refreshInBackground(trigger: trigger),
    ref.read(processingCapabilitiesProvider.notifier).refreshInBackground(),
    ref.read(parentReviewQueueProvider.notifier).refreshInBackground(),
    ref.read(parentSyncedPiecesProvider.notifier).refreshInBackground(),
  ]);
  ref.invalidate(serverHealthProvider);
}

void scheduleParentWorkflowRefreshBurst(
  WidgetRef ref, {
  SyncTrigger trigger = SyncTrigger.manualRefresh,
  bool Function()? isActive,
}) {
  ref.read(parentWorkflowRefreshSchedulerProvider).schedule(
        ref,
        trigger: trigger,
        isActive: isActive,
      );
}
