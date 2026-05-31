import 'dart:typed_data';

import 'package:dio/dio.dart';
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
  }) async {
    try {
      final response = await apiClient.checkIn(
        taskId: taskId,
        lat: lat,
        lng: lng,
        deviceNote: deviceNote,
      );

      return VerificationTask.fromJson(response);
    } on ApiError {
      rethrow;
    } catch (e) {
      throw _wrap(e, fallbackMessage: 'Check-in failed.');
    }
  }

  /// Upload ảnh bằng chứng và gửi review.
  Future<VerificationTask> submitEvidence({
    required String taskId,
    required Uint8List imageBytes,
    required String contentType,
    String? note,
  }) async {
    try {
      final presign = await apiClient.presignUpload(contentType: contentType);
      final objectKey = presign['objectKey'] as String;
      final uploadUrl = presign['uploadUrl'] as String;

      try {
        await Dio().put<dynamic>(
          uploadUrl,
          data: imageBytes,
          options: Options(
            headers: {
              'Content-Type': contentType,
            },
          ),
        );
      } on DioException catch (e) {
        throw ApiError(
          traceId: '',
          code: 'UPLOAD_FAILED',
          message:
              'Image upload failed. Check your connection and try again. (${e.message ?? "unknown error"})',
          timestamp: DateTime.now(),
        );
      }

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
}
