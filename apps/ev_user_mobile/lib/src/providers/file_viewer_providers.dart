import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/file_viewer_service.dart';

final presignedUrlProvider = FutureProvider.family<String, String>((ref, objectKey) async {
  final fileViewerService = ref.watch(fileViewerServiceProvider);
  return await fileViewerService.getViewUrl(objectKey);
});
