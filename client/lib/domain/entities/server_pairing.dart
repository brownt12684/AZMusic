class ServerPairingCode {
  const ServerPairingCode({
    required this.serverId,
    required this.serverName,
    required this.serverUrl,
    required this.pairingCode,
    required this.pairingUri,
    required this.qrPngUrl,
    required this.expiresAt,
    required this.purpose,
    this.profileId,
    this.profileName,
    this.role,
  });

  final String serverId;
  final String serverName;
  final String serverUrl;
  final String pairingCode;
  final String pairingUri;
  final String qrPngUrl;
  final DateTime expiresAt;
  final String purpose;
  final String? profileId;
  final String? profileName;
  final String? role;

  factory ServerPairingCode.fromJson(Map<String, dynamic> json) {
    return ServerPairingCode(
      serverId: json['server_id'] as String,
      serverName: json['server_name'] as String? ?? 'AZMusic',
      serverUrl: json['server_url'] as String,
      pairingCode: json['pairing_code'] as String,
      pairingUri: json['pairing_uri'] as String,
      qrPngUrl: json['qr_png_url'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      purpose: json['purpose'] as String? ?? 'student_device',
      profileId: json['profile_id'] as String?,
      profileName: json['profile_name'] as String?,
      role: json['role'] as String?,
    );
  }
}

class ServerPairingClaim {
  const ServerPairingClaim({
    required this.serverId,
    required this.serverName,
    required this.serverUrl,
    required this.deviceId,
    required this.deviceToken,
    required this.pairedAt,
    required this.purpose,
    this.profileId,
    this.profileName,
    this.role,
  });

  final String serverId;
  final String serverName;
  final String serverUrl;
  final String deviceId;
  final String deviceToken;
  final DateTime pairedAt;
  final String purpose;
  final String? profileId;
  final String? profileName;
  final String? role;

  factory ServerPairingClaim.fromJson(Map<String, dynamic> json) {
    return ServerPairingClaim(
      serverId: json['server_id'] as String,
      serverName: json['server_name'] as String? ?? 'AZMusic',
      serverUrl: json['server_url'] as String,
      deviceId: json['device_id'] as String,
      deviceToken: json['device_token'] as String,
      pairedAt: DateTime.parse(json['paired_at'] as String),
      purpose: json['purpose'] as String? ?? 'student_device',
      profileId: json['profile_id'] as String?,
      profileName: json['profile_name'] as String?,
      role: json['role'] as String?,
    );
  }
}
