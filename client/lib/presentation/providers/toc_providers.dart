import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../domain/entities/toc_entry.dart';

/// Provider that fetches the table of contents for a score version.
///
/// The TOC is fetched from the server on first access and cached in memory
/// for the lifetime of the provider.
final tocProvider = FutureProvider.family<TocResult, String>((ref, scoreVersionId) {
  return _fetchToc(scoreVersionId);
});

Future<TocResult> _fetchToc(String scoreVersionId) async {
  final apiClient = ApiClient();
  final response = await apiClient.get('/api/v1/score-toc/$scoreVersionId');
  final data = response.data as Map<String, dynamic>;
  return TocResult.fromJson(data);
}
