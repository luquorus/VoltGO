import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_api/shared_api.dart';
import '../models/verification_task.dart';
import '../models/collaborator_kpi.dart';
import '../models/collaborator_profile.dart';
import '../models/contract.dart';
import '../repositories/task_repository.dart';

/// Task Repository Provider
final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  final apiFactory = ref.watch(apiClientFactoryProvider);
  if (apiFactory == null) {
    throw Exception('ApiClientFactory not initialized');
  }
  return TaskRepository(apiFactory.collabWeb);
});

/// Task Filters
class TaskFilters {
  final VerificationTaskStatus? status;
  final int? priority;
  final DateTime? slaDueBefore;

  const TaskFilters({
    this.status,
    this.priority,
    this.slaDueBefore,
  });

  TaskFilters copyWith({
    VerificationTaskStatus? status,
    int? priority,
    DateTime? slaDueBefore,
    bool clearStatus = false,
    bool clearPriority = false,
    bool clearSlaDueBefore = false,
  }) {
    return TaskFilters(
      status: clearStatus ? null : (status ?? this.status),
      priority: clearPriority ? null : (priority ?? this.priority),
      slaDueBefore: clearSlaDueBefore ? null : (slaDueBefore ?? this.slaDueBefore),
    );
  }
}

/// Tasks Page Provider
final tasksPageProvider = FutureProvider.family<PagedResponse<VerificationTask>, ({
  TaskFilters filters,
  int page,
  int size,
})>((ref, params) async {
  final repository = ref.watch(taskRepositoryProvider);
  return repository.getTasks(
    status: params.filters.status,
    priority: params.filters.priority,
    slaDueBefore: params.filters.slaDueBefore,
    page: params.page,
    size: params.size,
  );
});

/// Current Task Filters Provider
final taskFiltersProvider = StateProvider<TaskFilters>((ref) => const TaskFilters());

/// Current Page Provider
final tasksCurrentPageProvider = StateProvider<int>((ref) => 0);

/// Page Size Provider
final tasksPageSizeProvider = StateProvider<int>((ref) => 20);

/// Combined Tasks Provider
/// Automatically refetches when filters, page, or size change
final tasksProvider = Provider<AsyncValue<PagedResponse<VerificationTask>>>((ref) {
  final filters = ref.watch(taskFiltersProvider);
  final page = ref.watch(tasksCurrentPageProvider);
  final size = ref.watch(tasksPageSizeProvider);

  return ref.watch(tasksPageProvider((
    filters: filters,
    page: page,
    size: size,
  )));
});

// ============================================
// Task History Providers
// ============================================

/// Task History Page Provider
final taskHistoryPageProvider = FutureProvider.family<PagedResponse<VerificationTask>, ({
  int page,
  int size,
})>((ref, params) async {
  final repository = ref.watch(taskRepositoryProvider);
  return repository.getTaskHistory(
    page: params.page,
    size: params.size,
  );
});

/// Current History Page Provider
final historyCurrentPageProvider = StateProvider<int>((ref) => 0);

/// History Page Size Provider
final historyPageSizeProvider = StateProvider<int>((ref) => 20);

/// Combined Task History Provider
/// Automatically refetches when page or size change
final taskHistoryProvider = Provider<AsyncValue<PagedResponse<VerificationTask>>>((ref) {
  final page = ref.watch(historyCurrentPageProvider);
  final size = ref.watch(historyPageSizeProvider);

  return ref.watch(taskHistoryPageProvider((
    page: page,
    size: size,
  )));
});

// ============================================
// KPI Providers
// ============================================

/// KPI Provider
final kpiProvider = FutureProvider<CollaboratorKpi>((ref) async {
  final repository = ref.watch(taskRepositoryProvider);
  return repository.getKpi();
});

// ============================================
// Profile Providers
// ============================================

/// Profile Provider
final profileProvider = FutureProvider<CollaboratorProfile>((ref) async {
  final repository = ref.watch(taskRepositoryProvider);
  return repository.getProfile();
});

// ============================================
// Contracts Providers
// ============================================

/// Contracts Provider
final contractsProvider = FutureProvider<List<Contract>>((ref) async {
  final repository = ref.watch(taskRepositoryProvider);
  return repository.getContracts();
});

