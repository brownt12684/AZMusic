import 'package:azmusic/core/pairing/pairing_payload.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PairingPayload.tryParse', () {
    test('parses server setup QR payloads', () {
      final payload = PairingPayload.tryParse(
        'azmusic://pair?server_url=http%3A%2F%2F192.168.1.10%3A8795&code=ABC123',
      );

      expect(payload, isNotNull);
      expect(payload!.serverUrl, 'http://192.168.1.10:8795');
      expect(payload.serverUrls, ['http://192.168.1.10:8795']);
      expect(payload.pairingCode, 'ABC123');
    });

    test('parses alternate server URLs for retrying pairing', () {
      final payload = PairingPayload.tryParse(
        'azmusic://pair?server_url=http%3A%2F%2F10.0.0.5%3A8795&'
        'alt_server_url=http%3A%2F%2F192.168.1.25%3A8795&'
        'alt_server_url=server&'
        'alt_server_url=http%3A%2F%2F10.0.0.5%3A8795%2F&code=ABC123',
      );

      expect(payload, isNotNull);
      expect(payload!.serverUrl, 'http://10.0.0.5:8795');
      expect(payload.alternateServerUrls, ['http://192.168.1.25:8795']);
      expect(payload.serverUrls, [
        'http://10.0.0.5:8795',
        'http://192.168.1.25:8795',
      ]);
    });

    test('trims a trailing server URL slash', () {
      final payload = PairingPayload.tryParse(
        'azmusic://pair?server_url=http%3A%2F%2Flocalhost%3A8795%2F&code=PAIR',
      );

      expect(payload!.serverUrl, 'http://localhost:8795');
    });

    test('rejects non-pairing text and incomplete payloads', () {
      expect(PairingPayload.tryParse('not a url'), isNull);
      expect(PairingPayload.tryParse('azmusic://pair?code=ABC123'), isNull);
      expect(
        PairingPayload.tryParse('azmusic://pair?server_url=server&code=ABC123'),
        isNull,
      );
    });
  });
}
