class PairingPayload {
  const PairingPayload({
    required this.serverUrl,
    required this.pairingCode,
    this.alternateServerUrls = const <String>[],
    this.rawPayload,
  });

  final String serverUrl;
  final String pairingCode;
  final List<String> alternateServerUrls;
  final String? rawPayload;

  List<String> get serverUrls {
    final urls = <String>[];
    for (final url in [serverUrl, ...alternateServerUrls]) {
      final normalized = url.trim().replaceFirst(RegExp(r'/$'), '');
      if (normalized.isNotEmpty && !urls.contains(normalized)) {
        urls.add(normalized);
      }
    }
    return urls;
  }

  String get displayPayload {
    final raw = rawPayload?.trim();
    if (raw != null && raw.isNotEmpty) {
      return raw;
    }
    final parameters = <String, String>{
      'server_url': serverUrl,
      'code': pairingCode,
    };
    final query = [
      ...parameters.entries.map(
        (entry) =>
            '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}',
      ),
      ...alternateServerUrls.map(
        (url) =>
            'alt_server_url=${Uri.encodeQueryComponent(url.trim().replaceFirst(RegExp(r'/$'), ''))}',
      ),
    ].join('&');
    return Uri(scheme: 'azmusic', host: 'pair')
        .replace(query: query)
        .toString();
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

    final normalizedServerUrl = serverUrl.replaceFirst(RegExp(r'/$'), '');
    final alternateServerUrls = uri.queryParametersAll['alt_server_url'] ??
        uri.queryParametersAll['alternate_server_url'] ??
        const <String>[];

    return PairingPayload(
      serverUrl: normalizedServerUrl,
      alternateServerUrls: _validAlternateServerUrls(
        primaryServerUrl: normalizedServerUrl,
        values: alternateServerUrls,
      ),
      pairingCode: code,
      rawPayload: normalized,
    );
  }
}

List<String> _validAlternateServerUrls({
  required String primaryServerUrl,
  required List<String> values,
}) {
  final urls = <String>[];
  final seen = {primaryServerUrl};
  for (final value in values) {
    final normalized = value.trim().replaceFirst(RegExp(r'/$'), '');
    if (normalized.isEmpty || seen.contains(normalized)) {
      continue;
    }
    final parsed = Uri.tryParse(normalized);
    if (parsed == null || !parsed.hasScheme || parsed.host.isEmpty) {
      continue;
    }
    seen.add(normalized);
    urls.add(normalized);
  }
  return urls;
}
