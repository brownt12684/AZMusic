import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Application configuration loaded at startup.
class AppConfig {
  static late SharedPreferences _prefs;
  static const String _serverHostOverride = String.fromEnvironment(
    'AZMUSIC_SERVER_HOST',
    defaultValue: '',
  );
  static const String _serverPortOverride = String.fromEnvironment(
    'AZMUSIC_SERVER_PORT',
    defaultValue: '',
  );
  static const String _serverPairingTokenOverride = String.fromEnvironment(
    'AZMUSIC_SERVER_PAIRING_TOKEN',
    defaultValue: '',
  );
  static const String _serverIdOverride = String.fromEnvironment(
    'AZMUSIC_SERVER_ID',
    defaultValue: '',
  );
  static const bool isProductionBuild = bool.fromEnvironment(
    'AZMUSIC_PRODUCTION',
  );
  static const bool showExperimentalFeatures = bool.fromEnvironment(
    'AZMUSIC_SHOW_EXPERIMENTAL',
    defaultValue: false,
  );
  static const String _pairedProfileNameOverride = String.fromEnvironment(
    'AZMUSIC_PAIRED_PROFILE_NAME',
    defaultValue: '',
  );
  static const String _defaultServerHost = '192.168.1.100';
  static const int _defaultServerPort = 8795;
  static const String _parentPinSaltKey = 'parent_pin_salt';
  static const String _parentPinHashKey = 'parent_pin_hash';
  static const String _studentProfilesKey = 'local_student_profiles';

  /// Server host (LAN IP or localhost).
  static String get serverHost => _serverHost;
  static late String _serverHost;

  /// Server port.
  static int get serverPort => _serverPort;
  static late int _serverPort;

  /// Base URL for the FastAPI server.
  static String get serverBaseUrl => 'http://$_serverHost:$_serverPort';

  static bool get isServerPaired => _isServerPaired;
  static bool _isServerPaired = false;

  static String? get serverId => _serverId;
  static String? _serverId;

  static String? get serverPairingToken => _serverPairingToken;
  static String? _serverPairingToken;

  static String? get pairedProfileId => _pairedProfileId;
  static String? _pairedProfileId;

  static String? get pairedProfileRole => _pairedProfileRole;
  static String? _pairedProfileRole;

  static String? get pairedProfileName => _pairedProfileName;
  static String? _pairedProfileName;

  static bool get hasParentPin {
    final salt = _prefs.getString(_parentPinSaltKey);
    final hash = _prefs.getString(_parentPinHashKey);
    return (salt?.isNotEmpty ?? false) && (hash?.isNotEmpty ?? false);
  }

  /// Maximum retry attempts for network requests.
  static int get maxRetries => _maxRetries;
  static late int _maxRetries;

  /// Connect timeout in seconds.
  static int get connectTimeoutSeconds => _connectTimeoutSeconds;
  static late int _connectTimeoutSeconds;

  /// Receive timeout in seconds.
  static int get receiveTimeoutSeconds => _receiveTimeoutSeconds;
  static late int _receiveTimeoutSeconds;

  /// Whether AI features are enabled.
  static bool get aiEnabled => _aiEnabled;
  static late bool _aiEnabled;

  /// Enable verbose request logging during development.
  static bool get debugLogging => _debugLogging;
  static late bool _debugLogging;

  /// Initialize configuration from SharedPreferences and environment.
  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _serverHost = resolveServerHost(
      storedHost: _prefs.getString('server_host'),
      compileTimeHost: _serverHostOverride,
    );
    _serverPort = resolveServerPort(
      storedPort: _prefs.getInt('server_port'),
      compileTimePort: _serverPortOverride,
    );
    _serverId = resolveServerId(
      storedServerId: _prefs.getString('server_id'),
      compileTimeServerId: _serverIdOverride,
    );
    _serverPairingToken = resolveServerPairingToken(
      storedToken: _prefs.getString('server_pairing_token'),
      compileTimeToken: _serverPairingTokenOverride,
    );
    _pairedProfileId = _prefs.getString('paired_profile_id');
    _pairedProfileRole = _prefs.getString('paired_profile_role');
    _pairedProfileName = _resolveOptionalText(
      storedValue: _prefs.getString('paired_profile_name'),
      compileTimeValue: _pairedProfileNameOverride,
    );
    _isServerPaired = _serverPairingToken?.isNotEmpty ?? false;
    _maxRetries = _prefs.getInt('max_retries') ?? 3;
    _connectTimeoutSeconds = _prefs.getInt('connect_timeout_seconds') ?? 10;
    _receiveTimeoutSeconds = _prefs.getInt('receive_timeout_seconds') ?? 30;
    _aiEnabled = _prefs.getBool('ai_enabled') ?? true;
    _debugLogging = _prefs.getBool('debug_logging') ?? false;
  }

  @visibleForTesting
  static String? resolveServerId({
    String? storedServerId,
    String compileTimeServerId = '',
  }) {
    final normalizedOverride = compileTimeServerId.trim();
    if (normalizedOverride.isNotEmpty) {
      return normalizedOverride;
    }

    final normalizedStoredServerId = storedServerId?.trim();
    if (normalizedStoredServerId != null &&
        normalizedStoredServerId.isNotEmpty) {
      return normalizedStoredServerId;
    }

    return null;
  }

  @visibleForTesting
  static String? resolveServerPairingToken({
    String? storedToken,
    String compileTimeToken = '',
  }) {
    final normalizedOverride = compileTimeToken.trim();
    if (normalizedOverride.isNotEmpty) {
      return normalizedOverride;
    }

    final normalizedStoredToken = storedToken?.trim();
    if (normalizedStoredToken != null && normalizedStoredToken.isNotEmpty) {
      return normalizedStoredToken;
    }

    return null;
  }

  @visibleForTesting
  static String resolveServerHost({
    String? storedHost,
    String compileTimeHost = '',
  }) {
    final normalizedOverride = compileTimeHost.trim();
    if (normalizedOverride.isNotEmpty) {
      return normalizedOverride;
    }

    final normalizedStoredHost = storedHost?.trim();
    if (normalizedStoredHost != null && normalizedStoredHost.isNotEmpty) {
      return normalizedStoredHost;
    }

    return _defaultServerHost;
  }

  @visibleForTesting
  static int resolveServerPort({
    int? storedPort,
    String compileTimePort = '',
  }) {
    final overridePort = int.tryParse(compileTimePort.trim());
    if (_isValidPort(overridePort)) {
      return overridePort!;
    }

    if (_isValidPort(storedPort)) {
      return storedPort!;
    }

    return _defaultServerPort;
  }

  /// Update server host.
  static Future<void> setServerHost(String host) async {
    _serverHost = host;
    await _prefs.setString('server_host', host);
  }

  /// Update server port.
  static Future<void> setServerPort(int port) async {
    _serverPort = port;
    await _prefs.setInt('server_port', port);
  }

  static Future<void> applyServerPairing({
    required String serverUrl,
    required String serverId,
    required String pairingToken,
    String? profileId,
    String? profileRole,
    String? profileName,
  }) async {
    final uri = Uri.parse(serverUrl);
    final host = uri.host;
    final port = uri.hasPort ? uri.port : _defaultServerPort;
    await setServerHost(host);
    await setServerPort(port);
    _serverId = serverId;
    _serverPairingToken = pairingToken;
    _pairedProfileId = profileId;
    _pairedProfileRole = profileRole;
    _pairedProfileName = profileName;
    _isServerPaired = pairingToken.isNotEmpty;
    await _prefs.setString('server_id', serverId);
    await _prefs.setString('server_pairing_token', pairingToken);
    if (profileId != null && profileId.isNotEmpty) {
      await _prefs.setString('paired_profile_id', profileId);
    } else {
      await _prefs.remove('paired_profile_id');
    }
    if (profileRole != null && profileRole.isNotEmpty) {
      await _prefs.setString('paired_profile_role', profileRole);
    } else {
      await _prefs.remove('paired_profile_role');
    }
    if (profileName != null && profileName.isNotEmpty) {
      await _prefs.setString('paired_profile_name', profileName);
    } else {
      await _prefs.remove('paired_profile_name');
    }
  }

  static Future<void> setParentPin(String pin) async {
    final trimmed = pin.trim();
    final salt = _generateSalt();
    await _prefs.setString(_parentPinSaltKey, salt);
    await _prefs.setString(_parentPinHashKey, _hashPin(trimmed, salt));
  }

  static bool verifyParentPin(String pin) {
    final salt = _prefs.getString(_parentPinSaltKey);
    final storedHash = _prefs.getString(_parentPinHashKey);
    if (salt == null ||
        salt.isEmpty ||
        storedHash == null ||
        storedHash.isEmpty) {
      return false;
    }
    return _hashPin(pin.trim(), salt) == storedHash;
  }

  static bool isValidParentPinFormat(String pin) {
    return RegExp(r'^\d{4,}$').hasMatch(pin.trim());
  }

  static bool isDisallowedParentPin(String pin) {
    return false;
  }

  static List<Map<String, dynamic>> loadStudentProfileMaps() {
    final rawProfiles = _prefs.getString(_studentProfilesKey);
    if (rawProfiles == null || rawProfiles.isEmpty) {
      return const <Map<String, dynamic>>[];
    }

    try {
      final decoded = jsonDecode(rawProfiles);
      if (decoded is! List) {
        return const <Map<String, dynamic>>[];
      }
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  static Future<void> saveStudentProfileMaps(
    List<Map<String, dynamic>> profiles,
  ) async {
    await _prefs.setString(_studentProfilesKey, jsonEncode(profiles));
  }

  /// Toggle AI features.
  static Future<void> setAiEnabled(bool enabled) async {
    _aiEnabled = enabled;
    await _prefs.setBool('ai_enabled', enabled);
  }

  static bool _isValidPort(int? value) {
    return value != null && value > 0 && value <= 65535;
  }

  static String? _resolveOptionalText({
    String? storedValue,
    String compileTimeValue = '',
  }) {
    final normalizedOverride = compileTimeValue.trim();
    if (normalizedOverride.isNotEmpty) {
      return normalizedOverride;
    }
    final normalizedStored = storedValue?.trim();
    if (normalizedStored != null && normalizedStored.isNotEmpty) {
      return normalizedStored;
    }
    return null;
  }

  static String _generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  static String _hashPin(String pin, String salt) {
    return sha256.convert(utf8.encode('$salt:$pin')).toString();
  }
}
