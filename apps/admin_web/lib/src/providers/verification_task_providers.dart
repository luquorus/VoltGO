import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_api/shared_api.dart';
import '../models/admin_verification_task.dart';

/// Filter state for verification tasks
class VerificationTaskFilters {
  final VerificationTaskStatus? status;

  VerificationTaskFilters({this.status});

  VerificationTaskFilters copyWith({
    VerificationTaskStatus? status,
    bool clearStatus = false,
  }) {
    return VerificationTaskFilters(
      status: clearStatus ? null : (status ?? this.status),
    );
  }
}

/// Current page for verification tasks
final verificationTasksCurrentPageProvider = StateProvider<int>((ref) => 0);

/// Page size
const int verificationTasksPageSize = 20;

/// Provider for verification task filters
final verificationTaskFiltersProvider =
    StateProvider<VerificationTaskFilters>((ref) => VerificationTaskFilters());

/// Provider for verification tasks list (paginated)
final verificationTasksPageProvider = FutureProvider<PagedVerificationTasks>((ref) async {
  final factory = ref.watch(apiClientFactoryProvider);
  if (factory == null) throw Exception('API client not initialized');

  final filters = ref.watch(verificationTaskFiltersProvider);
  final page = ref.watch(verificationTasksCurrentPageProvider);
  
  final statusParam = filters.status?.name.toUpperCase();
  
  final response = await factory.admin.getVerificationTasks(
    status: statusParam,
    page: page,
    size: verificationTasksPageSize,
  );
  
  return PagedVerificationTasks.fromJson(response);
});

/// Provider for a single verification task by ID
final verificationTaskProvider =
    FutureProvider.family<AdminVerificationTask, String>((ref, id) async {
  final factory = ref.watch(apiClientFactoryProvider);
  if (factory == null) throw Exception('API client not initialized');

  final response = await factory.admin.getVerificationTask(id);
  return AdminVerificationTask.fromJson(response);
});

