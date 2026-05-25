import 'dart:async';
import 'dart:io';

abstract class NetworkInfo {
  Future<bool> get isConnected;
  Stream<bool> get onConnectivityChanged;
}

class NetworkInfoImpl implements NetworkInfo {
  NetworkInfoImpl({
    this.probeHost = 'example.com',
    this.lookupTimeout = const Duration(seconds: 2),
  });

  final String probeHost;
  final Duration lookupTimeout;

  @override
  Future<bool> get isConnected async {
    try {
      final results = await InternetAddress.lookup(probeHost).timeout(
        lookupTimeout,
      );
      return results.any((result) => result.rawAddress.isNotEmpty);
    } on SocketException {
      return false;
    } on TimeoutException {
      return false;
    }
  }

  @override
  Stream<bool> get onConnectivityChanged {
    return Stream<bool>.multi((controller) {
      bool? lastValue;
      Timer? timer;
      var canceled = false;

      Future<void> emitLatest() async {
        final nextValue = await isConnected;
        if (canceled || nextValue == lastValue) {
          return;
        }
        lastValue = nextValue;
        controller.add(nextValue);
      }

      unawaited(emitLatest());
      timer = Timer.periodic(const Duration(seconds: 5), (_) {
        unawaited(emitLatest());
      });
      controller.onCancel = () {
        canceled = true;
        timer?.cancel();
      };
    });
  }
}
