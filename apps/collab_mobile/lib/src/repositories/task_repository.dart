import 'dart:typed_data';

import 'package:shared_api/shared_api.dart';
import 'package:shared_network/shared_network.dart';
import '../models/verification_task.dart';

/// Task Repository - re-throws ApiError to giữ nguyên code/traceId/message để UI map sang thông báo thân thiện.
class TaskRepository {
  final CollaboratorMobileApiClient apiClient;

  TaskRepository(this.apiClient);

  ApiError _wrap(Object error, {String? fallbackMessage}) {
    if (error is ApiError) return error;
    return ApiError(
      traceId: '',
      code: 'UNKNOWN_ERROR',
      message: fallbackMessage ?? error.toString(),
      timestamp: DateTime.now(),
    );
  }

  /// Lấy danh sách nhiệm vụ với bộ lọc trạng thái tuỳ chọn.
  Future<List<VerificationTask>> getTasks({
    List<VerificationTaskStatus>? statuses,
  }) async {
    try {
      final statusStrings = statuses?.map((s) => s.toString()).toList();
      final response = await apiClient.getTasks(status: statusStrings);

      return (response as List)
          .map((json) =>
              VerificationTask.fromJson(json as Map<String, dynamic>))
          .toList();
    } on ApiError {
      rethrow;
    } catch (e) {
      throw _wrap(e, fallbackMessage: 'Could not load task list.');
    }
  }

  /// Check-in tại vị trí của task.
  Future<VerificationTask> checkIn({
    required String taskId,
    required double lat,
    required double lng,
    String? deviceNote,
    List<ChecklistAnswer>? checklistAnswers,
  }) async {
    try {
      final checklistData = checklistAnswers?.map((e) => e.toJson()).toList();
      final response = await apiClient.checkIn(
        taskId: taskId,
        lat: lat,
        lng: lng,
        deviceNote: deviceNote,
        checklistAnswers: checklistData,
      );

      return VerificationTask.fromJson(response);
    } on ApiError {
      rethrow;
    } catch (e) {
      throw _wrap(e, fallbackMessage: 'Check-in failed.');
    }
  }

  /// Upload ảnh bằng chứng và gửi review.
  /// Dùng proxy upload qua backend thay vì presigned URL trực tiếp lên MinIO.
  /// Backend proxy giải quyết vấn đề IP cứng và network restriction.
  Future<VerificationTask> submitEvidence({
    required String taskId,
    required Uint8List imageBytes,
    required String contentType,
    String? note,
  }) async {
    try {
      final result = await apiClient.proxyUpload(
        fileBytes: imageBytes,
        fileName: 'evidence_${DateTime.now().millisecondsSinceEpoch}.jpg',
        contentType: contentType,
      );
      final objectKey = result['objectKey'] as String;

      final trimmedNote = note?.trim();
      final response = await apiClient.submitEvidence(
        taskId: taskId,
        photoObjectKey: objectKey,
        note: trimmedNote == null || trimmedNote.isEmpty ? null : trimmedNote,
      );

      return VerificationTask.fromJson(response);
    } on ApiError {
      rethrow;
    } catch (e) {
      throw _wrap(e, fallbackMessage: 'Failed to submit evidence.');
    }
  }

  Future<String> getEvidenceViewUrl(String objectKey) async {
    try {
      final response = await apiClient.presignView(objectKey: objectKey);
      return response['viewUrl'] as String;
    } on ApiError {
      rethrow;
    } catch (e) {
      throw _wrap(e, fallbackMessage: 'Could not load evidence image.');
    }
  }

  /// Fetch evidence image bytes via proxy endpoint (bypasses MinIO direct access).
  Future<Uint8List> getEvidenceViewBytes(String objectKey) async {
    try {
      return await apiClient.proxyViewBytes(objectKey: objectKey);
    } on ApiError {
      rethrow;
    } catch (e) {
      throw _wrap(e, fallbackMessage: 'Could not load evidence image.');
    }
  }
}
