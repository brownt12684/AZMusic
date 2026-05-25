import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/network/network_info.dart';

enum SyncTrigger {
  appLaunch,
  appForeground,
  manualRefresh,
  postImport,
  parentPush,
  reviewApproval,
  connectivityReturn,
}

enum LibrarySyncStatus {
  offlineReady,
  syncing,
  synced,
  failedUsable,
}

class LibrarySyncBannerState {
  const LibrarySyncBannerState({
    required this.status,
    required this.message,
    this.trigger,
  });

  LibrarySyncBannerState.offlineReady({
    SyncTrigger? trigger,
  }) : this(
          status: LibrarySyncStatus.offlineReady,
          message: 'Offline. Local scores stay available from this device.',
          trigger: trigger,
        );

  LibrarySyncBannerState.syncing({
    SyncTrigger? trigger,
  }) : this(
          status: LibrarySyncStatus.syncing,
          message: _syncingMessage(trigger),
          trigger: trigger,
        );

  LibrarySyncBannerState.synced({
    SyncTrigger? trigger,
  }) : this(
          status: LibrarySyncStatus.synced,
          message: _syncedMessage(trigger),
          trigger: trigger,
        );

  LibrarySyncBannerState.failedUsable({
    SyncTrigger? trigger,
  }) : this(
          status: LibrarySyncStatus.failedUsable,
          message: 'Sync failed, but local music stays readable.',
          trigger: trigger,
        );

  final LibrarySyncStatus status;
  final String message;
  final SyncTrigger? trigger;

  static String _syncingMessage(SyncTrigger? trigger) {
    switch (trigger) {
      case SyncTrigger.postImport:
        return 'Saving the new import locally and syncing in the background...';
      case SyncTrigger.parentPush:
      case SyncTrigger.reviewApproval:
        return 'Updating assignments and approved score versions...';
      case SyncTrigger.manualRefresh:
        return 'Refreshing the local library and server assignments...';
      case SyncTrigger.connectivityReturn:
        return 'Connection restored. Catching up on library updates...';
      case SyncTrigger.appForeground:
      case SyncTrigger.appLaunch:
      case null:
        return 'Checking for library and score updates...';
    }
  }

  static String _syncedMessage(SyncTrigger? trigger) {
    switch (trigger) {
      case SyncTrigger.postImport:
        return 'Import saved locally. Sync is caught up for now.';
      case SyncTrigger.parentPush:
        return 'Assignments updated. The local library is current.';
      case SyncTrigger.reviewApproval:
        return 'Approved updates are now available locally.';
      case SyncTrigger.manualRefresh:
      case SyncTrigger.connectivityReturn:
      case SyncTrigger.appForeground:
      case SyncTrigger.appLaunch:
      case null:
        return 'Library sync completed. Local content is current.';
    }
  }
}

final networkInfoProvider = Provider<NetworkInfo>(
  (ref) {
    try {
      return NetworkInfoImpl(probeHost: AppConfig.serverHost);
    } catch (_) {
      return NetworkInfoImpl();
    }
  },
);

final librarySyncBannerProvider = StateProvider<LibrarySyncBannerState>(
  (ref) => LibrarySyncBannerState.offlineReady(),
);

final syncStatusProvider = Provider<bool>((ref) {
  return ref.watch(librarySyncBannerProvider).status ==
      LibrarySyncStatus.syncing;
});

final connectionStatusProvider = Provider<String>((ref) {
  return switch (ref.watch(librarySyncBannerProvider).status) {
    LibrarySyncStatus.offlineReady => 'offline-ready',
    LibrarySyncStatus.syncing => 'syncing',
    LibrarySyncStatus.synced => 'synced',
    LibrarySyncStatus.failedUsable => 'failed-usable',
  };
});

enum ServerHealthStatus {
  checking,
  online,
  offline,
}

class ServerHealthState {
  const ServerHealthState({
    required this.status,
    required this.serverUrl,
    this.message,
  });

  final ServerHealthStatus status;
  final String serverUrl;
  final String? message;

  bool get isOnline => status == ServerHealthStatus.online;
}

final serverHealthProvider = FutureProvider<ServerHealthState>((ref) async {
  final serverUrl = AppConfig.serverBaseUrl;
  final dio = Dio(
    BaseOptions(
      baseUrl: serverUrl,
      connectTimeout: const Duration(seconds: 2),
      receiveTimeout: const Duration(seconds: 2),
      sendTimeout: const Duration(seconds: 2),
    ),
  );

  try {
    final response = await dio.get<Map<String, dynamic>>('/health');
    final payload = response.data ?? const <String, dynamic>{};
    final status = payload['status'] as String?;
    if (response.statusCode == 200 && status == 'ok') {
      return ServerHealthState(
        status: ServerHealthStatus.online,
        serverUrl: serverUrl,
        message: payload['server'] as String? ?? 'AZMusic server',
      );
    }
    return ServerHealthState(
      status: ServerHealthStatus.offline,
      serverUrl: serverUrl,
      message: 'Unexpected health response',
    );
  } catch (error) {
    return ServerHealthState(
      status: ServerHealthStatus.offline,
      serverUrl: serverUrl,
      message: error.toString(),
    );
  }
});
