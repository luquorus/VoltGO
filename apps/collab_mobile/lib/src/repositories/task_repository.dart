import 'package:shared_api/shared_api.dart';
import '../models/verification_task.dart';

/// Task Repository
class TaskRepository {
  final CollaboratorMobileApiClient apiClient;

  TaskRepository(this.apiClient);

  /// Get tasks with optional status filter
  Future<List<VerificationTask>> getTasks({
    List<VerificationTaskStatus>? statuses,
  }) async {
    try {
      final statusStrings = statuses?.map((s) => s.toString()).toList();
      final response = await apiClient.getTasks(status: statusStrings);
      
      return (response as List)
          .map((json) => VerificationTask.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch tasks: $e');
    }
  }

  /// Check-in at task location
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
    } catch (e) {
      throw Exception('Failed to check-in: $e');
    }
  }
}

