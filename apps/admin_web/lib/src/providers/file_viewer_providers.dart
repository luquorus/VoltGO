import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/file_viewer_service.dart';

/// Provider for fetching presigned view URL for a specific objectKey
/// Returns AsyncValue<String> with the view URL
final presignedUrlProvider = FutureProvider.family<String, String>((ref, objectKey) async {
  final fileViewerService = ref.watch(fileViewerServiceProvider);
  return await fileViewerService.getViewUrl(objectKey);
});

