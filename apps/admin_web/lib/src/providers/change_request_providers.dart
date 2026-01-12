import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_api/shared_api.dart';
import '../models/admin_change_request.dart';

/// Filter state for change requests
class ChangeRequestFilters {
  final ChangeRequestStatus? status;

  ChangeRequestFilters({this.status});

  ChangeRequestFilters copyWith({
    ChangeRequestStatus? status,
    bool clearStatus = false,
  }) {
    return ChangeRequestFilters(
      status: clearStatus ? null : (status ?? this.status),
    );
  }
}

/// Provider for change request filters
final changeRequestFiltersProvider =
    StateProvider<ChangeRequestFilters>((ref) => ChangeRequestFilters());

/// Provider for change requests list
final changeRequestsProvider = FutureProvider<List<AdminChangeRequest>>((ref) async {
  final factory = ref.watch(apiClientFactoryProvider);
  if (factory == null) throw Exception('API client not initialized');

  final filters = ref.watch(changeRequestFiltersProvider);
  final statusParam = filters.status?.name.toUpperCase();

  final response = await factory.admin.getChangeRequests(status: statusParam);
  return (response as List<dynamic>)
      .map((json) => AdminChangeRequest.fromJson(json as Map<String, dynamic>))
      .toList();
});

/// Provider for a single change request by ID
final changeRequestProvider =
    FutureProvider.family<AdminChangeRequest, String>((ref, id) async {
  final factory = ref.watch(apiClientFactoryProvider);
  if (factory == null) throw Exception('API client not initialized');

  final response = await factory.admin.getChangeRequest(id);
  return AdminChangeRequest.fromJson(response);
});

