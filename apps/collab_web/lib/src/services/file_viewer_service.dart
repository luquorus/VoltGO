import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_api/shared_api.dart';
import '../models/presign_view_response.dart';
import '../repositories/task_repository.dart';

/// Cached presigned URL entry
class _CachedUrl {
  final String viewUrl;
  final DateTime expiresAt;

  _CachedUrl({
    required this.viewUrl,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// FileViewer Service
/// Handles presigned URL fetching with in-memory caching
class FileViewerService {
  final CollaboratorWebApiClient apiClient;
  
  // In-memory cache: objectKey -> CachedUrl
  final Map<String, _CachedUrl> _cache = {};

  FileViewerService(this.apiClient);

  /// Get presigned view URL for an objectKey
  /// Returns cached URL if available and not expired, otherwise fetches new one
  Future<String> getViewUrl(String objectKey) async {
    // Check cache first
    final cached = _cache[objectKey];
    if (cached != null && !cached.isExpired) {
      return cached.viewUrl;
    }

    // Cache miss or expired - fetch new URL
    try {
      final response = await apiClient.presignView(objectKey: objectKey);
      final presignResponse = PresignViewResponse.fromJson(response);
      
      // Cache the result
      _cache[objectKey] = _CachedUrl(
        viewUrl: presignResponse.viewUrl,
        expiresAt: presignResponse.expiresAt,
      );
      
      return presignResponse.viewUrl;
    } catch (e) {
      // Re-throw to let caller handle (403, 401, etc.)
      rethrow;
    }
  }

  /// Clear cache for a specific objectKey
  void clearCache(String objectKey) {
    _cache.remove(objectKey);
  }

  /// Clear all cache
  void clearAllCache() {
    _cache.clear();
  }
}

/// FileViewer Service Provider
final fileViewerServiceProvider = Provider<FileViewerService>((ref) {
  final apiFactory = ref.watch(apiClientFactoryProvider);
  if (apiFactory == null) {
    throw Exception('ApiClientFactory not initialized');
  }
  return FileViewerService(apiFactory.collabWeb);
});

