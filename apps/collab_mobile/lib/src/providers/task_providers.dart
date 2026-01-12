import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_api/shared_api.dart';
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
final taskDetailProvider = FutureProvider.family<VerificationTask, String>((ref, taskId) async {
  final repository = ref.watch(taskRepositoryProvider);
  // For now, we'll fetch all tasks and filter by ID
  // In the future, we might have a GET /tasks/{id} endpoint
  final allTasks = await repository.getTasks();
  final task = allTasks.firstWhere((t) => t.id == taskId);
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

