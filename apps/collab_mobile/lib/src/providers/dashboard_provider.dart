import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_api/shared_api.dart';
import '../repositories/task_repository.dart';
import 'task_providers.dart';

/// Dashboard KPI State
class DashboardKpiState {
  final Map<String, dynamic>? kpi;
  final bool isLoading;
  final String? error;

  DashboardKpiState({
    this.kpi,
    this.isLoading = false,
    this.error,
  });

  int get totalReviewed => kpi?['reviewedCount'] as int? ?? 0;
  int get totalPassed => kpi?['passCount'] as int? ?? 0;
  int get totalFailed => kpi?['failCount'] as int? ?? 0;
  double get passRate => totalReviewed > 0 ? totalPassed / totalReviewed * 100 : 0;
}

/// Dashboard KPI Notifier
class DashboardKpiNotifier extends StateNotifier<DashboardKpiState> {
  final CollaboratorMobileApiClient _apiClient;

  DashboardKpiNotifier(this._apiClient) : super(DashboardKpiState());

  Future<void> loadKpi() async {
    state = DashboardKpiState(isLoading: true);
    try {
      final kpi = await _apiClient.getKpi();
      state = DashboardKpiState(kpi: kpi);
    } catch (e) {
      state = DashboardKpiState(error: e.toString());
    }
  }
}

/// Dashboard KPI Provider
final dashboardKpiProvider =
    StateNotifierProvider<DashboardKpiNotifier, DashboardKpiState>((ref) {
  final repository = ref.watch(taskRepositoryProvider);
  return DashboardKpiNotifier(repository.apiClient);
});
