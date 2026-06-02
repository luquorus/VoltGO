import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_api/shared_api.dart';
import '../models/battery_swap_verification_task.dart';
import '../models/battery_swap_kpi.dart';

/// Battery Swap Task Repository Provider
final batterySwapTaskRepositoryProvider =
    Provider<BatterySwapTaskRepository>((ref) {
  final apiFactory = ref.watch(apiClientFactoryProvider);
  if (apiFactory == null) {
    throw Exception('ApiClientFactory not initialized');
  }
  return BatterySwapTaskRepository(apiFactory.collabWeb);
});

/// Battery Swap Tasks Provider
final swapTasksProvider =
    FutureProvider<List<BatterySwapVerificationTask>>((ref) async {
  final repository = ref.watch(batterySwapTaskRepositoryProvider);
  return repository.getSwapTasks();
});

/// Battery Swap KPI Provider
final swapKpiProvider =
    FutureProvider<BatterySwapKpi>((ref) async {
  final repository = ref.watch(batterySwapTaskRepositoryProvider);
  return repository.getSwapKpi();
});

/// Battery Swap Task Repository
class BatterySwapTaskRepository {
  final CollaboratorWebApiClient apiClient;

  BatterySwapTaskRepository(this.apiClient);

  /// Get battery swap verification tasks
  Future<List<BatterySwapVerificationTask>> getSwapTasks({
    String? status,
    int page = 0,
    int size = 50,
  }) async {
    try {
      final response = await apiClient.getBatterySwapTasks(
        status: status,
        page: page,
        size: size,
      );

      final List<dynamic> content = response['content'] ?? response as List<dynamic>;
      return content
          .map((json) =>
              BatterySwapVerificationTask.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching battery swap tasks: $e');
      throw Exception('Failed to fetch battery swap tasks: $e');
    }
  }

  /// Get battery swap KPI summary
  Future<BatterySwapKpi> getSwapKpi() async {
    try {
      final response = await apiClient.getBatterySwapKpi();
      return BatterySwapKpi.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      print('Error fetching battery swap KPI: $e');
      throw Exception('Failed to fetch battery swap KPI: $e');
    }
  }
}
