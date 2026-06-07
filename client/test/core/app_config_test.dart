import 'package:azmusic/core/config/app_config.dart';
import 'package:azmusic/domain/entities/profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    await AppConfig.initialize();
  });

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

      expect(port, 8795);
    });
  });

  group('AppConfig pairing resolution', () {
    test('compile-time server override does not count as pairing', () {
      final serverId = AppConfig.resolveServerId(
        compileTimeServerId: '',
      );
      final token = AppConfig.resolveServerPairingToken(
        compileTimeToken: '',
      );

      expect(serverId, isNull);
      expect(token, isNull);
    });

    test('explicit compile-time pairing token still supports dev pairing', () {
      final serverId = AppConfig.resolveServerId(
        compileTimeServerId: 'development-local-server',
      );
      final token = AppConfig.resolveServerPairingToken(
        compileTimeToken: 'development-paired-device',
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

  group('AppConfig parent PIN', () {
    test('stores and verifies a salted parent PIN hash', () async {
      await AppConfig.setParentPin('2468');

      expect(AppConfig.hasParentPin, isTrue);
      expect(AppConfig.verifyParentPin('2468'), isTrue);
      expect(AppConfig.verifyParentPin('1357'), isFalse);
    });

    test('validates parent PIN setup input', () {
      expect(AppConfig.isValidParentPinFormat('2468'), isTrue);
      expect(AppConfig.isValidParentPinFormat('abc1'), isFalse);
      expect(AppConfig.isValidParentPinFormat('123'), isFalse);
      expect(AppConfig.isDisallowedParentPin('0000'), isFalse);
    });
  });

  group('AppConfig student profiles', () {
    test('persists parent-created student profile maps', () async {
      final now = DateTime.utc(2026, 5, 28);
      final profile = Profile(
        id: 'student-kai',
        displayName: 'Kai',
        role: ProfileRole.student,
        instrument: InstrumentType.cello,
        createdAt: now,
        updatedAt: now,
      );

      await AppConfig.saveStudentProfileMaps([profile.toMap()]);

      final profiles = AppConfig.loadStudentProfileMaps();
      expect(profiles, hasLength(1));
      expect(profiles.single['id'], 'student-kai');
      expect(profiles.single['display_name'], 'Kai');
    });
  });
}
