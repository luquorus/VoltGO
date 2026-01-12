import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:shared_api/shared_api.dart';
import '../services/upload_service.dart';
import '../models/verification_task.dart';

/// Upload Service Provider
final uploadServiceProvider = Provider<UploadService>((ref) {
  final apiFactory = ref.watch(apiClientFactoryProvider);
  if (apiFactory == null) {
    throw Exception('API client factory not initialized');
  }
  
  // Create a separate Dio instance for direct uploads (without auth interceptor)
  final dio = Dio();
  
  return UploadService(
    apiClient: apiFactory.collabMobile,
    dio: dio,
  );
});

/// Submit Evidence Provider
final submitEvidenceProvider = Provider.family<Future<VerificationTask>, SubmitEvidenceParams>((ref, params) async {
  final uploadService = ref.watch(uploadServiceProvider);
  return uploadService.submitEvidence(
    taskId: params.taskId,
    photoObjectKey: params.photoObjectKey,
    note: params.note,
  );
});

/// Submit Evidence Parameters
class SubmitEvidenceParams {
  final String taskId;
  final String photoObjectKey;
  final String? note;

  SubmitEvidenceParams({
    required this.taskId,
    required this.photoObjectKey,
    this.note,
  });
}

