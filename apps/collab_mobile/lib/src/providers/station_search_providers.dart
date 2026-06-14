import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_api/shared_api.dart';
import '../repositories/station_search_repository.dart';

/// Provider for the station search repository (used by the create-CR form).
final stationSearchRepositoryProvider =
    Provider<StationSearchRepository>((ref) {
  final factory = ref.watch(apiClientFactoryProvider);
  if (factory == null) {
    throw Exception('API client factory not initialized');
  }
  return StationSearchRepository(factory.collabMobile);
});

/// Provider that holds the current search results for charging stations.
final chargingStationSearchProvider =
    StateNotifierProvider.autoDispose<ChargingStationSearchNotifier,
        ChargingStationSearchState>((ref) {
  final repo = ref.watch(stationSearchRepositoryProvider);
  return ChargingStationSearchNotifier(repo);
});

class ChargingStationSearchState {
  final List<StationSearchItem> results;
  final bool isLoading;
  final String? error;
  final String query;

  const ChargingStationSearchState({
    this.results = const [],
    this.isLoading = false,
    this.error,
    this.query = '',
  });

  ChargingStationSearchState copyWith({
    List<StationSearchItem>? results,
    bool? isLoading,
    String? error,
    String? query,
  }) {
    return ChargingStationSearchState(
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      query: query ?? this.query,
    );
  }
}

class ChargingStationSearchNotifier
    extends StateNotifier<ChargingStationSearchState> {
  final StationSearchRepository _repo;

  ChargingStationSearchNotifier(this._repo)
      : super(const ChargingStationSearchState());

  Future<void> search(String name) async {
    if (name.trim().length < 2) {
      state = const ChargingStationSearchState();
      return;
    }
    state = state.copyWith(isLoading: true, query: name);
    try {
      final results = await _repo.searchChargingStations(name);
      state = state.copyWith(
        results: results,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void clear() {
    state = const ChargingStationSearchState();
  }
}

final batterySwapStationSearchProvider = StateNotifierProvider.autoDispose<
    BatterySwapStationSearchNotifier, BatterySwapStationSearchState>((ref) {
  final repo = ref.watch(stationSearchRepositoryProvider);
  return BatterySwapStationSearchNotifier(repo);
});

class BatterySwapStationSearchState {
  final List<BatterySwapStationSearchItem> results;
  final bool isLoading;
  final String? error;
  final String query;

  const BatterySwapStationSearchState({
    this.results = const [],
    this.isLoading = false,
    this.error,
    this.query = '',
  });

  BatterySwapStationSearchState copyWith({
    List<BatterySwapStationSearchItem>? results,
    bool? isLoading,
    String? error,
    String? query,
  }) {
    return BatterySwapStationSearchState(
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      query: query ?? this.query,
    );
  }
}

class BatterySwapStationSearchNotifier
    extends StateNotifier<BatterySwapStationSearchState> {
  final StationSearchRepository _repo;

  BatterySwapStationSearchNotifier(this._repo)
      : super(const BatterySwapStationSearchState());

  Future<void> search(String name) async {
    if (name.trim().length < 2) {
      state = const BatterySwapStationSearchState();
      return;
    }
    state = state.copyWith(isLoading: true, query: name);
    try {
      final results = await _repo.searchBatterySwapStations(name);
      state = state.copyWith(results: results, isLoading: false, error: null);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void clear() {
    state = const BatterySwapStationSearchState();
  }
}

/// Auto-fill provider — fetches full station detail by ID.
/// Returns null when [stationId] is empty so the consumer can `if (data != null)`.
final chargingStationDetailProvider = FutureProvider.autoDispose
    .family<StationAutoFillData?, String>((ref, stationId) async {
  if (stationId.trim().isEmpty) return null;
  final repo = ref.watch(stationSearchRepositoryProvider);
  return repo.getChargingStationDetail(stationId);
});

final batterySwapStationDetailProvider = FutureProvider.autoDispose
    .family<BatterySwapStationAutoFillData?, String>((ref, stationId) async {
  if (stationId.trim().isEmpty) return null;
  final repo = ref.watch(stationSearchRepositoryProvider);
  return repo.getBatterySwapStationDetail(stationId);
});
