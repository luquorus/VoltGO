import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_api/shared_api.dart' hide RegistrationRequest, RegistrationRequestStatus;
import '../models/registration_request.dart';
import '../models/pagination_response.dart';
import '../providers/contract_providers.dart';

/// Pagination state for registration requests
class RegistrationRequestPagination {
  final int page;
  final int size;
  final RegistrationRequestStatus? statusFilter;

  RegistrationRequestPagination({
    this.page = 0,
    this.size = 20,
    this.statusFilter,
  });

  RegistrationRequestPagination copyWith({
    int? page,
    int? size,
    RegistrationRequestStatus? statusFilter,
    bool clearStatusFilter = false,
  }) {
    return RegistrationRequestPagination(
      page: page ?? this.page,
      size: size ?? this.size,
      statusFilter: clearStatusFilter ? null : (statusFilter ?? this.statusFilter),
    );
  }
}

/// Provider for registration request pagination state
final registrationRequestPaginationProvider =
    StateProvider<RegistrationRequestPagination>((ref) {
  return RegistrationRequestPagination();
});

/// Provider for registration requests list with pagination
final registrationRequestsProvider =
    FutureProvider<PaginationResponse<RegistrationRequest>>((ref) async {
  final factory = ref.watch(apiClientFactoryProvider);
  if (factory == null) throw Exception('API client not initialized');

  final pagination = ref.watch(registrationRequestPaginationProvider);

  final response = await factory.admin.getRegistrationRequests(
    page: pagination.page,
    size: pagination.size,
    status: pagination.statusFilter?.value,
  );

  return PaginationResponse<RegistrationRequest>.fromJson(
    response,
    (json) => RegistrationRequest.fromJson(json as Map<String, dynamic>),
  );
});

/// Provider for a single registration request by ID
final registrationRequestProvider =
    FutureProvider.family<RegistrationRequest, String>((ref, id) async {
  final factory = ref.watch(apiClientFactoryProvider);
  if (factory == null) throw Exception('API client not initialized');

  final response = await factory.admin.getRegistrationRequest(id);
  return RegistrationRequest.fromJson(response);
});

/// Provider for pending requests count
final pendingRequestsCountProvider = FutureProvider<int>((ref) async {
  final factory = ref.watch(apiClientFactoryProvider);
  if (factory == null) throw Exception('API client not initialized');

  return await factory.admin.getRegistrationRequestsPendingCount();
});

/// Notifier for approving a registration request
class ApproveRegistrationNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref ref;

  ApproveRegistrationNotifier(this.ref) : super(const AsyncValue.data(null));

  Future<void> approve(String id, {required String region, String? note}) async {
    state = const AsyncValue.loading();
    try {
      final factory = ref.read(apiClientFactoryProvider);
      if (factory == null) throw Exception('API client not initialized');

      await factory.admin.approveRegistrationRequest(id, region: region, note: note);

      // Invalidate the list and detail providers
      ref.invalidate(registrationRequestsProvider);
      ref.invalidate(registrationRequestProvider(id));
      ref.invalidate(pendingRequestsCountProvider);

      // Give backend time to create the collaborator record before refreshing
      await Future.delayed(const Duration(milliseconds: 500));
      ref.invalidate(allCollaboratorsProvider);

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final approveRegistrationProvider =
    StateNotifierProvider<ApproveRegistrationNotifier, AsyncValue<void>>((ref) {
  return ApproveRegistrationNotifier(ref);
});

/// Notifier for rejecting a registration request
class RejectRegistrationNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref ref;

  RejectRegistrationNotifier(this.ref) : super(const AsyncValue.data(null));

  Future<void> reject(String id, {required String reason}) async {
    state = const AsyncValue.loading();
    try {
      final factory = ref.read(apiClientFactoryProvider);
      if (factory == null) throw Exception('API client not initialized');

      await factory.admin.rejectRegistrationRequest(id, reason: reason);

      // Invalidate the list and detail providers
      ref.invalidate(registrationRequestsProvider);
      ref.invalidate(registrationRequestProvider(id));
      ref.invalidate(pendingRequestsCountProvider);

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final rejectRegistrationProvider =
    StateNotifierProvider<RejectRegistrationNotifier, AsyncValue<void>>((ref) {
  return RejectRegistrationNotifier(ref);
});
