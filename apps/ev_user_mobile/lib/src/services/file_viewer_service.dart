import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_api/shared_api.dart';

class _CachedUrl {
  final String viewUrl;
  final DateTime expiresAt;

  _CachedUrl({
    required this.viewUrl,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class FileViewerService {
  final EvUserMobileApiClient apiClient;
  
  final Map<String, _CachedUrl> _cache = {};

  FileViewerService(this.apiClient);

  Future<String> getViewUrl(String objectKey) async {
    final cached = _cache[objectKey];
    if (cached != null && !cached.isExpired) {
      return cached.viewUrl;
    }

    try {
      final response = await apiClient.presignView(objectKey, expiresInMinutes: 60);
      final viewUrl = response['viewUrl'] as String;
      final expiresAtStr = response['expiresAt'] as String;
      final expiresAt = DateTime.parse(expiresAtStr);
      
      _cache[objectKey] = _CachedUrl(
        viewUrl: viewUrl,
        expiresAt: expiresAt,
      );
      
      return viewUrl;
    } catch (e) {
      rethrow;
    }
  }

  void clearCache(String objectKey) {
    _cache.remove(objectKey);
  }

  void clearAllCache() {
    _cache.clear();
  }
}

final fileViewerServiceProvider = Provider<FileViewerService>((ref) {
  final apiFactory = ref.watch(apiClientFactoryProvider);
  if (apiFactory == null) {
    throw Exception('ApiClientFactory not initialized');
  }
  return FileViewerService(apiFactory.ev);
});
