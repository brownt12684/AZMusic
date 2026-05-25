import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/server_pairing.dart';
import 'review_providers.dart';

final serverPairingCodeProvider = FutureProvider<ServerPairingCode>((ref) {
  return ref.read(serverPieceSyncRepositoryProvider).fetchPairingCode();
});
