import 'dart:io';

import '../../data/database/database.dart';
import '../network/api_client.dart';
import '../network/network_info.dart';
import '../sync/sync_manager.dart';

class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();

  // Core
  late final NetworkInfo networkInfo;
  late final ApiClient apiClient;

  // Database
  late final AppDatabase database;

  // App directory
  late final Directory appDirectory;

  // Sync
  late final SyncManager syncManager;

  bool _initialized = false;

  Future<void> initialize({
    required NetworkInfo networkInfo,
    required ApiClient apiClient,
    required AppDatabase database,
    required Directory appDirectory,
    required SyncManager syncManager,
  }) async {
    if (_initialized) return;

    this.networkInfo = networkInfo;
    this.apiClient = apiClient;
    this.database = database;
    this.appDirectory = appDirectory;
    this.syncManager = syncManager;
    _initialized = true;
  }

  void reset() {
    _initialized = false;
  }
}

ServiceLocator get serviceLocator => ServiceLocator();
