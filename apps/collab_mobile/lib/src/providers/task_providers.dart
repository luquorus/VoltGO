import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_api/shared_api.dart';
import 'package:shared_network/shared_network.dart';
import '../repositories/task_repository.dart';
import '../models/verification_task.dart';

/// Task Repository Provider
final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  final apiFactory = ref.watch(apiClientFactoryProvider);
  if (apiFactory == null) {
    throw Exception('API client factory not initialized');
  }
  return TaskRepository(apiFactory.collabMobile);
});

/// Tasks by Status Provider
final tasksByStatusProvider = FutureProvider.family<List<VerificationTask>, List<VerificationTaskStatus>?>((ref, statuses) async {
  final repository = ref.watch(taskRepositoryProvider);
  return repository.getTasks(statuses: statuses);
});

/// Task Detail Provider
///
/// Backend hiện chưa có GET /tasks/{id}, nên tạm fetch toàn bộ rồi lọc theo id.
/// Trả về `ApiError(NOT_FOUND)` để UI hiển thị thông báo thân thiện thay cho
/// `StateError` khó hiểu khi không tìm thấy.
final taskDetailProvider =
    FutureProvider.family<VerificationTask, String>((ref, taskId) async {
  final repository = ref.watch(taskRepositoryProvider);
  final allTasks = await repository.getTasks();
  final task = allTasks
      .cast<VerificationTask?>()
      .firstWhere((t) => t?.id == taskId, orElse: () => null);
  if (task == null) {
    throw ApiError(
      traceId: '',
      code: 'NOT_FOUND',
      message: 'Task not found. It may have been cancelled or you are no longer assigned.',
      timestamp: DateTime.now(),
    );
  }
  return task;
});

/// Check-in Provider (for performing check-in)
final checkInProvider = Provider.family<Future<VerificationTask>, CheckInParams>((ref, params) async {
  final repository = ref.watch(taskRepositoryProvider);
  return repository.checkIn(
    taskId: params.taskId,
    lat: params.lat,
    lng: params.lng,
    deviceNote: params.deviceNote,
  );
});

/// Submit Evidence Provider
final submitEvidenceProvider = Provider.family<Future<VerificationTask>, SubmitEvidenceParams>((ref, params) async {
  final repository = ref.watch(taskRepositoryProvider);
  return repository.submitEvidence(
    taskId: params.taskId,
    imageBytes: params.imageBytes,
    contentType: params.contentType,
    note: params.note,
  );
});

/// Evidence image URL provider
final evidenceViewUrlProvider = FutureProvider.family<String, String>((ref, objectKey) async {
  final repository = ref.watch(taskRepositoryProvider);
  return repository.getEvidenceViewUrl(objectKey);
});

/// Check-in Parameters
class CheckInParams {
  final String taskId;
  final double lat;
  final double lng;
  final String? deviceNote;

  CheckInParams({
    required this.taskId,
    required this.lat,
    required this.lng,
    this.deviceNote,
  });
}

class SubmitEvidenceParams {
  final String taskId;
  final Uint8List imageBytes;
  final String contentType;
  final String? note;

  SubmitEvidenceParams({
    required this.taskId,
    required this.imageBytes,
    required this.contentType,
    this.note,
  });
}

