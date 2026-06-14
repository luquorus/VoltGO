import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_api/shared_api.dart';
import '../repositories/change_request_repository.dart';
import '../repositories/battery_swap_change_request_repository.dart';

/// Repository providers
final changeRequestRepositoryProvider = Provider<ChangeRequestRepository>((ref) {
  final factory = ref.watch(apiClientFactoryProvider);
  if (factory == null) {
    throw Exception('API client factory not initialized');
  }
  return ChangeRequestRepository(factory.collabMobile);
});

final batterySwapChangeRequestRepositoryProvider =
    Provider<BatterySwapChangeRequestRepository>((ref) {
  final factory = ref.watch(apiClientFactoryProvider);
  if (factory == null) {
    throw Exception('API client factory not initialized');
  }
  return BatterySwapChangeRequestRepository(factory.collabMobile);
});

// ============================================
// State + Notifier
// ============================================

class ChangeRequestListState {
  final List<UnifiedChangeRequest> changeRequests;
  final bool isLoading;
  final String? error;

  const ChangeRequestListState({
    this.changeRequests = const [],
    this.isLoading = false,
    this.error,
  });

  ChangeRequestListState copyWith({
    List<UnifiedChangeRequest>? changeRequests,
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

class ChangeRequestListNotifier extends StateNotifier<ChangeRequestListState> {
  final ChangeRequestRepository _repo;
  final BatterySwapChangeRequestRepository _swapRepo;

  ChangeRequestListNotifier(this._repo, this._swapRepo)
      : super(const ChangeRequestListState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    try {
      final charging = await _repo.getMyChangeRequests();
      final swap = await _swapRepo.getMyChangeRequests();
      final unified = <UnifiedChangeRequest>[
        ...charging.map(UnifiedChangeRequest.fromCharging),
        ...swap.map(UnifiedChangeRequest.fromBatterySwap),
      ]..sort((a, b) {
          final aT = a.createdAt;
          final bT = b.createdAt;
          if (aT == null && bT == null) return 0;
          if (aT == null) return 1;
          if (bT == null) return -1;
          return bT.compareTo(aT);
        });
      state = ChangeRequestListState(changeRequests: unified);
    } catch (e) {
      state = ChangeRequestListState(error: e.toString());
    }
  }

  Future<void> refresh() => load();
}

final changeRequestListProvider =
    StateNotifierProvider<ChangeRequestListNotifier, ChangeRequestListState>((ref) {
  final repo = ref.watch(changeRequestRepositoryProvider);
  final swapRepo = ref.watch(batterySwapChangeRequestRepositoryProvider);
  return ChangeRequestListNotifier(repo, swapRepo);
});

// ============================================
// Detail providers
// ============================================

final chargingChangeRequestDetailProvider =
    FutureProvider.family<ChangeRequestItem, String>((ref, id) async {
  final repo = ref.watch(changeRequestRepositoryProvider);
  return repo.getChangeRequest(id);
});

final batterySwapChangeRequestDetailProvider =
    FutureProvider.family<BatterySwapChangeRequestItem, String>((ref, id) async {
  final repo = ref.watch(batterySwapChangeRequestRepositoryProvider);
  return repo.getChangeRequest(id);
});
