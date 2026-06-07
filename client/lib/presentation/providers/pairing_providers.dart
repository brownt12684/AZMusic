import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/network/server_connection_error.dart';
import '../../domain/entities/server_pairing.dart';
import 'review_providers.dart';

final serverPairingCodeProvider = FutureProvider<ServerPairingCode>((ref) {
  if (!AppConfig.isServerPaired) {
    throw const ServerNotPairedException();
  }
  return ref.read(serverPieceSyncRepositoryProvider).fetchPairingCode();
});
