import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_api/shared_api.dart';
import 'package:shared_network/shared_network.dart';
import 'package:shared_auth/shared_auth.dart';
import '../repositories/change_request_repository.dart';

/// Provider for ChangeRequestRepository
final changeRequestRepositoryProvider = Provider<ChangeRequestRepository>((ref) {
  final factory = ref.watch(apiClientFactoryProvider);
  if (factory == null) {
    throw Exception('ApiClientFactory not initialized');
  }
  return ChangeRequestRepository(factory.ev);
});

/// Change request list state
class ChangeRequestListState {
  final List<Map<String, dynamic>> changeRequests;
  final bool isLoading;
  final String? error;

  ChangeRequestListState({
    this.changeRequests = const [],
    this.isLoading = false,
    this.error,
  });

  ChangeRequestListState copyWith({
    List<Map<String, dynamic>>? changeRequests,
    bool? isLoading,
    String? error,
  }) {
    return ChangeRequestListState(
      changeRequests: changeRequests ?? this.changeRequests,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Change request list notifier
class ChangeRequestListNotifier extends StateNotifier<ChangeRequestListState> {
  final ChangeRequestRepository _repository;

  ChangeRequestListNotifier(this._repository) : super(ChangeRequestListState()) {
    loadChangeRequests();
  }

  Future<void> loadChangeRequests() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final list = await _repository.getChangeRequests();
      state = state.copyWith(
        changeRequests: list,
        isLoading: false,
        error: null,
      );
    } on ApiError catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> refresh() => loadChangeRequests();
}

/// Provider for change request list
final changeRequestListProvider =
    StateNotifierProvider.autoDispose<ChangeRequestListNotifier, ChangeRequestListState>((ref) {
  final repository = ref.watch(changeRequestRepositoryProvider);
  final authState = ref.watch(authStateProvider);
  
  // Invalidate provider when userId changes
  ref.listen(authStateProvider, (previous, next) {
    if (previous?.userId != next.userId) {
      Future.microtask(() {
        ref.invalidateSelf();
      });
    }
  });
  
  return ChangeRequestListNotifier(repository);
});

/// Provider for single change request detail
final changeRequestDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, changeRequestId) async {
  final repository = ref.watch(changeRequestRepositoryProvider);
  return repository.getChangeRequest(changeRequestId);
});

