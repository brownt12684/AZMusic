import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../core/di/service_locator.dart';
import '../core/network/api_client.dart';
import '../core/network/network_info.dart';
import '../core/sync/sync_manager.dart';
import '../data/database/database.dart';

// Provider for the app directory
final appDirectoryProvider = Provider<Directory>((ref) {
  throw UnimplementedError('appDirectory must be overridden in main()');
});

/// Initialize the service locator and return the SyncManager instance.
Future<SyncManager> initServiceLocator(String dbPath) async {
  final appDir = await getApplicationDocumentsDirectory();

  final networkInfo = NetworkInfoImpl();
  final apiClient = ApiClient();
  final database = AppDatabase(
    dbPath: dbPath.isEmpty ? defaultDatabasePath(appDir) : dbPath,
  );
  final syncManager = SyncManager();

  await serviceLocator.initialize(
    networkInfo: networkInfo,
    apiClient: apiClient,
    database: database,
    appDirectory: appDir,
    syncManager: syncManager,
  );

  return syncManager;
}
