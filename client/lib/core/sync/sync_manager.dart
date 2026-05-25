import 'dart:async';

import 'package:logger/logger.dart';

import '../di/service_locator.dart';
import '../error/errors.dart';

class SyncManager {
  final Logger _logger = Logger();
  Timer? _syncTimer;
  bool _isSyncing = false;

  bool get isSyncing => _isSyncing;

  void startAutoSync({Duration interval = const Duration(minutes: 5)}) {
    stopAutoSync();
    _syncTimer = Timer.periodic(interval, (_) => sync());
    _logger.d('Auto-sync started with interval: ${interval.inMinutes}m');
  }

  void stopAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
    _logger.d('Auto-sync stopped');
  }

  Future<void> sync() async {
    if (_isSyncing) {
      _logger.w('Sync already in progress, skipping');
      return;
    }

    final networkInfo = serviceLocator.networkInfo;
    if (!await networkInfo.isConnected) {
      _logger.w('No network connection, deferring sync');
      return;
    }

    _isSyncing = true;
    try {
      _logger.i('Starting sync...');
      // TODO: Implement actual sync logic
      // - Fetch remote changes
      // - Push local changes
      // - Resolve conflicts
      _logger.i('Sync completed successfully');
    } on NetworkError catch (e) {
      _logger.e('Network error during sync: $e');
    } on SyncError catch (e) {
      _logger.e('Sync error: $e');
    } catch (e) {
      _logger.e('Unexpected error during sync: $e');
    } finally {
      _isSyncing = false;
    }
  }

  void dispose() {
    stopAutoSync();
  }
}
