class PairingPayload {
  const PairingPayload({
    required this.serverUrl,
    required this.pairingCode,
    this.rawPayload,
  });

  final String serverUrl;
  final String pairingCode;
  final String? rawPayload;

  String get displayPayload {
    final raw = rawPayload?.trim();
    if (raw != null && raw.isNotEmpty) {
      return raw;
    }
    return Uri(
      scheme: 'azmusic',
      host: 'pair',
      queryParameters: {
        'server_url': serverUrl,
        'code': pairingCode,
      },
    ).toString();
  }

  static PairingPayload? tryParse(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(normalized);
    if (uri == null) {
      return null;
    }
    if (uri.scheme != 'azmusic' || uri.host != 'pair') {
      return null;
    }

    final serverUrl = uri.queryParameters['server_url']?.trim();
    final code = uri.queryParameters['code']?.trim();
    if (serverUrl == null ||
        serverUrl.isEmpty ||
        code == null ||
        code.isEmpty) {
      return null;
    }

    final parsedServer = Uri.tryParse(serverUrl);
    if (parsedServer == null ||
        !parsedServer.hasScheme ||
        parsedServer.host.isEmpty) {
      return null;
    }

    return PairingPayload(
      serverUrl: serverUrl.replaceFirst(RegExp(r'/$'), ''),
      pairingCode: code,
      rawPayload: normalized,
    );
  }
}
