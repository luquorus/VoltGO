import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_api/shared_api.dart';
import '../models/verification_task.dart';
import '../repositories/task_repository.dart';
import 'task_providers.dart';

/// Dashboard KPI State
class DashboardKpiState {
  final Map<String, dynamic>? kpi;
  final int assignedCount;
  final bool isLoading;
  final String? error;

  DashboardKpiState({
    this.kpi,
    this.assignedCount = 0,
    this.isLoading = false,
    this.error,
  });

  int get totalReviewed => kpi?['totalReviewed'] as int? ?? 0;
  int get passCount => kpi?['passCount'] as int? ?? 0;
  int get failCount => kpi?['failCount'] as int? ?? 0;
  double get passRate => totalReviewed > 0 ? (passCount / totalReviewed * 100) : 0;
}

/// Dashboard KPI Notifier
class DashboardKpiNotifier extends StateNotifier<DashboardKpiState> {
  final CollaboratorMobileApiClient _apiClient;

  DashboardKpiNotifier(this._apiClient) : super(DashboardKpiState());

  Future<void> loadKpi() async {
    state = DashboardKpiState(isLoading: true, assignedCount: state.assignedCount);
    try {
      final kpi = await _apiClient.getKpi();
      state = DashboardKpiState(kpi: kpi, assignedCount: state.assignedCount);
    } catch (e) {
      state = DashboardKpiState(error: e.toString(), assignedCount: state.assignedCount);
    }
  }

  void setAssignedCount(int count) {
    state = DashboardKpiState(
      kpi: state.kpi,
      assignedCount: count,
      isLoading: state.isLoading,
      error: state.error,
    );
  }
}

/// Dashboard KPI Provider
final dashboardKpiProvider =
    StateNotifierProvider<DashboardKpiNotifier, DashboardKpiState>((ref) {
  final repository = ref.watch(taskRepositoryProvider);
  return DashboardKpiNotifier(repository.apiClient);
});

/// Assigned tasks count provider (for KPI display)
final assignedTasksCountProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(taskRepositoryProvider);
  final tasks = await repository.getTasks(
    statuses: [VerificationTaskStatus.assigned, VerificationTaskStatus.checkedIn],
  );
  return tasks.length;
});
