import 'package:azmusic/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppConfig.resolveServerHost', () {
    test('prefers compile-time override when present', () {
      final host = AppConfig.resolveServerHost(
        storedHost: '192.168.1.100',
        compileTimeHost: '127.0.0.1',
      );

      expect(host, '127.0.0.1');
    });

    test('uses stored host when override is blank', () {
      final host = AppConfig.resolveServerHost(
        storedHost: '192.168.1.50',
        compileTimeHost: '   ',
      );

      expect(host, '192.168.1.50');
    });

    test('falls back to the checked-in LAN default', () {
      final host = AppConfig.resolveServerHost();

      expect(host, '192.168.1.100');
    });
  });

  group('AppConfig.resolveServerPort', () {
    test('prefers compile-time override when it is a valid port', () {
      final port = AppConfig.resolveServerPort(
        storedPort: 9000,
        compileTimePort: '8001',
      );

      expect(port, 8001);
    });

    test('falls back to the stored port when override is invalid', () {
      final port = AppConfig.resolveServerPort(
        storedPort: 9100,
        compileTimePort: 'not-a-port',
      );

      expect(port, 9100);
    });

    test('falls back to the checked-in default when both inputs are invalid',
        () {
      final port = AppConfig.resolveServerPort(
        storedPort: 0,
        compileTimePort: '70000',
      );

      expect(port, 8000);
    });
  });

  group('AppConfig pairing resolution', () {
    test('compile-time server override counts as development pairing', () {
      final serverId = AppConfig.resolveServerId(
        compileTimeHost: '127.0.0.1',
      );
      final token = AppConfig.resolveServerPairingToken(
        compileTimeHost: '127.0.0.1',
      );

      expect(serverId, 'development-local-server');
      expect(token, 'development-paired-device');
    });

    test('stored pairing wins when no development override is present', () {
      final serverId = AppConfig.resolveServerId(
        storedServerId: 'family-server',
      );
      final token = AppConfig.resolveServerPairingToken(
        storedToken: 'paired-token',
      );

      expect(serverId, 'family-server');
      expect(token, 'paired-token');
    });

    test('unpaired devices have no server id or token by default', () {
      expect(AppConfig.resolveServerId(), isNull);
      expect(AppConfig.resolveServerPairingToken(), isNull);
    });
  });
}
