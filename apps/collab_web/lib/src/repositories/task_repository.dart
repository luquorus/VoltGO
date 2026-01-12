import 'package:shared_api/shared_api.dart';
import '../models/verification_task.dart';
import '../models/collaborator_kpi.dart';
import '../models/collaborator_profile.dart';
import '../models/contract.dart';

/// Task Repository for Collaborator Web
class TaskRepository {
  final CollaboratorWebApiClient apiClient;

  TaskRepository(this.apiClient);

  /// Get tasks with filters and pagination
  Future<PagedResponse<VerificationTask>> getTasks({
    VerificationTaskStatus? status,
    int? priority,
    DateTime? slaDueBefore,
    int page = 0,
    int size = 20,
  }) async {
    try {
      final response = await apiClient.getTasks(
        status: status?.toString(),
        priority: priority,
        slaDueBefore: slaDueBefore != null 
            ? slaDueBefore.toUtc().toIso8601String()
            : null,
        page: page,
        size: size,
      );

      // Debug: log response structure
      if (response is Map<String, dynamic>) {
        print('API Response keys: ${response.keys.toList()}');
        print('Content type: ${response['content']?.runtimeType}');
        print('Page: ${response['page']}, Type: ${response['page']?.runtimeType}');
      }

      return PagedResponse.fromJson(
        response as Map<String, dynamic>,
        (json) => VerificationTask.fromJson(json),
      );
    } catch (e, stackTrace) {
      print('Error fetching tasks: $e');
      print('Stack trace: $stackTrace');
      throw Exception('Failed to fetch tasks: $e');
    }
  }

  /// Get task history (reviewed tasks)
  Future<PagedResponse<VerificationTask>> getTaskHistory({
    int page = 0,
    int size = 20,
  }) async {
    try {
      final response = await apiClient.getTaskHistory(
        page: page,
        size: size,
      );

      return PagedResponse.fromJson(
        response as Map<String, dynamic>,
        (json) => VerificationTask.fromJson(json),
      );
    } catch (e, stackTrace) {
      print('Error fetching task history: $e');
      print('Stack trace: $stackTrace');
      throw Exception('Failed to fetch task history: $e');
    }
  }

  /// Get KPI summary
  Future<CollaboratorKpi> getKpi() async {
    try {
      final response = await apiClient.getKpi();
      return CollaboratorKpi.fromJson(response as Map<String, dynamic>);
    } catch (e, stackTrace) {
      print('Error fetching KPI: $e');
      print('Stack trace: $stackTrace');
      throw Exception('Failed to fetch KPI: $e');
    }
  }

  /// Get collaborator profile
  Future<CollaboratorProfile> getProfile() async {
    try {
      final response = await apiClient.getProfile();
      return CollaboratorProfile.fromJson(response as Map<String, dynamic>);
    } catch (e, stackTrace) {
      print('Error fetching profile: $e');
      print('Stack trace: $stackTrace');
      throw Exception('Failed to fetch profile: $e');
    }
  }

  /// Get contracts
  Future<List<Contract>> getContracts() async {
    try {
      final response = await apiClient.getContracts();
      final List<dynamic> contractsList = response;
      return contractsList
          .map((json) => Contract.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e, stackTrace) {
      print('Error fetching contracts: $e');
      print('Stack trace: $stackTrace');
      throw Exception('Failed to fetch contracts: $e');
    }
  }
}

