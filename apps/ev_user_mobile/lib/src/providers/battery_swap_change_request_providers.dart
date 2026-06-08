import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_api/shared_api.dart';
import 'package:shared_network/shared_network.dart';
import 'package:shared_auth/shared_auth.dart';
import '../repositories/battery_swap_change_request_repository.dart';

/// Provider for BatterySwapChangeRequestRepository
final batterySwapChangeRequestRepositoryProvider =
    Provider<BatterySwapChangeRequestRepository>((ref) {
  final factory = ref.watch(apiClientFactoryProvider);
  if (factory == null) {
    throw Exception('ApiClientFactory not initialized');
  }
  return BatterySwapChangeRequestRepository(factory.ev);
});

/// Battery swap change request list state
class BatterySwapChangeRequestListState {
  final List<Map<String, dynamic>> changeRequests;
  final bool isLoading;
  final String? error;

  BatterySwapChangeRequestListState({
    this.changeRequests = const [],
    this.isLoading = false,
    this.error,
  });

  BatterySwapChangeRequestListState copyWith({
    List<Map<String, dynamic>>? changeRequests,
    bool? isLoading,
    String? error,
  }) {
    return BatterySwapChangeRequestListState(
      changeRequests: changeRequests ?? this.changeRequests,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Battery swap change request list notifier
class BatterySwapChangeRequestListNotifier extends StateNotifier<BatterySwapChangeRequestListState> {
  final BatterySwapChangeRequestRepository _repository;

  BatterySwapChangeRequestListNotifier(this._repository)
      : super(BatterySwapChangeRequestListState()) {
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

/// Provider for battery swap change request list
final batterySwapChangeRequestListProvider =
    StateNotifierProvider.autoDispose<BatterySwapChangeRequestListNotifier,
        BatterySwapChangeRequestListState>((ref) {
  final repository = ref.watch(batterySwapChangeRequestRepositoryProvider);
  // watch authState to trigger the listener below
  ref.watch(authStateProvider);
  ref.listen(authStateProvider, (previous, next) {
    if (previous?.userId != next.userId) {
      Future.microtask(() {
        ref.invalidateSelf();
      });
    }
  });

  return BatterySwapChangeRequestListNotifier(repository);
});

/// Provider for single battery swap change request detail
final batterySwapChangeRequestDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, changeRequestId) async {
  final repository = ref.watch(batterySwapChangeRequestRepositoryProvider);
  return repository.getChangeRequest(changeRequestId);
});
