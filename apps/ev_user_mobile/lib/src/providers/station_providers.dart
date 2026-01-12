import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_api/shared_api.dart';
import 'package:shared_network/shared_network.dart';
import 'package:shared_auth/shared_auth.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../repositories/station_repository.dart';

/// Base URL Provider
final baseUrlProvider = Provider<String>((ref) {
  return dotenv.get('BASE_URL', fallback: 'http://localhost:8080');
});

/// Station Repository Provider
final stationRepositoryProvider = Provider<StationRepository>((ref) {
  final factory = ref.watch(apiClientFactoryProvider);
  if (factory == null) {
    throw Exception('ApiClientFactory not initialized');
  }
  final baseUrl = ref.watch(baseUrlProvider);
  final dio = ref.read(dioClientProvider(baseUrl));
  final authState = ref.watch(authStateProvider);
  
  return StationRepository(
    factory.ev,
    dio: dio,
    baseUrl: baseUrl,
    getToken: () => authState.token,
  );
});

/// Station Search Parameters
class StationSearchParams {
  final double lat;
  final double lng;
  final double radiusKm;
  final double? minPowerKw;
  final bool? hasAC;

  StationSearchParams({
    required this.lat,
    required this.lng,
    required this.radiusKm,
    this.minPowerKw,
    this.hasAC,
  });

  StationSearchParams copyWith({
    double? lat,
    double? lng,
    double? radiusKm,
    double? minPowerKw,
    bool? hasAC,
    bool clearMinPowerKw = false,
    bool clearHasAC = false,
  }) {
    return StationSearchParams(
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      radiusKm: radiusKm ?? this.radiusKm,
      minPowerKw: clearMinPowerKw ? null : (minPowerKw ?? this.minPowerKw),
      hasAC: clearHasAC ? null : (hasAC ?? this.hasAC),
    );
  }
}

/// Station Search State
class StationSearchState {
  final List<Map<String, dynamic>> stations;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool isLoading;
  final bool isLoadingMore;
  final ApiError? error;
  final bool hasMore;

  StationSearchState({
    this.stations = const [],
    this.page = 0,
    this.size = 20,
    this.totalElements = 0,
    this.totalPages = 0,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
  }) : hasMore = page < totalPages - 1;

  StationSearchState copyWith({
    List<Map<String, dynamic>>? stations,
    int? page,
    int? size,
    int? totalElements,
    int? totalPages,
    bool? isLoading,
    bool? isLoadingMore,
    ApiError? error,
    bool clearError = false,
    bool clearStations = false,
  }) {
    return StationSearchState(
      stations: clearStations ? [] : (stations ?? this.stations),
      page: page ?? this.page,
      size: size ?? this.size,
      totalElements: totalElements ?? this.totalElements,
      totalPages: totalPages ?? this.totalPages,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Station Search Notifier
class StationSearchNotifier extends StateNotifier<StationSearchState> {
  final StationRepository _repository;
  StationSearchParams? _currentParams;

  StationSearchNotifier(this._repository) : super(StationSearchState());

  /// Search stations with new parameters (resets pagination)
  Future<void> search(StationSearchParams params) async {
    _currentParams = params;
    state = state.copyWith(isLoading: true, clearError: true, clearStations: true);

    try {
      final response = await _repository.searchStations(
        lat: params.lat,
        lng: params.lng,
        radiusKm: params.radiusKm,
        minPowerKw: params.minPowerKw,
        hasAC: params.hasAC,
        page: 0,
        size: state.size,
      );

      final content = (response['content'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [];

      state = state.copyWith(
        stations: content,
        page: response['page'] as int? ?? 0,
        size: response['size'] as int? ?? 20,
        totalElements: response['totalElements'] as int? ?? 0,
        totalPages: response['totalPages'] as int? ?? 0,
        isLoading: false,
      );
    } on ApiError catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: ApiError(
          traceId: '',
          code: 'UNKNOWN_ERROR',
          message: e.toString(),
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  /// Load more stations (next page)
  Future<void> loadMore() async {
    if (_currentParams == null || state.isLoadingMore || !state.hasMore) {
      return;
    }

    state = state.copyWith(isLoadingMore: true);

    try {
      final nextPage = state.page + 1;
      final response = await _repository.searchStations(
        lat: _currentParams!.lat,
        lng: _currentParams!.lng,
        radiusKm: _currentParams!.radiusKm,
        minPowerKw: _currentParams!.minPowerKw,
        hasAC: _currentParams!.hasAC,
        page: nextPage,
        size: state.size,
      );

      final content = (response['content'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [];

      state = state.copyWith(
        stations: [...state.stations, ...content],
        page: nextPage,
        totalElements: response['totalElements'] as int? ?? state.totalElements,
        totalPages: response['totalPages'] as int? ?? state.totalPages,
        isLoadingMore: false,
      );
    } on ApiError catch (e) {
      state = state.copyWith(
        isLoadingMore: false,
        error: e,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingMore: false,
        error: ApiError(
          traceId: '',
          code: 'UNKNOWN_ERROR',
          message: e.toString(),
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  /// Update filters (triggers new search)
  Future<void> updateFilters(StationSearchParams params) async {
    await search(params);
  }

  /// Search stations by name
  Future<void> searchByName(String nameQuery) async {
    state = state.copyWith(isLoading: true, clearError: true, clearStations: true);

    try {
      final response = await _repository.searchStationsByName(
        name: nameQuery,
        page: 0,
        size: state.size,
      );

      final content = (response['content'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [];

      state = state.copyWith(
        stations: content,
        page: response['page'] as int? ?? 0,
        size: response['size'] as int? ?? 20,
        totalElements: response['totalElements'] as int? ?? 0,
        totalPages: response['totalPages'] as int? ?? 0,
        isLoading: false,
      );
    } on ApiError catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: ApiError(
          traceId: '',
          code: 'UNKNOWN_ERROR',
          message: e.toString(),
          timestamp: DateTime.now(),
        ),
      );
    }
  }
}

/// Station Search Provider
final stationSearchProvider =
    StateNotifierProvider<StationSearchNotifier, StationSearchState>((ref) {
  final repository = ref.watch(stationRepositoryProvider);
  return StationSearchNotifier(repository);
});

/// Station Detail State
class StationDetailState {
  final Map<String, dynamic>? station;
  final bool isLoading;
  final ApiError? error;

  StationDetailState({
    this.station,
    this.isLoading = false,
    this.error,
  });

  StationDetailState copyWith({
    Map<String, dynamic>? station,
    bool? isLoading,
    ApiError? error,
    bool clearError = false,
    bool clearStation = false,
  }) {
    return StationDetailState(
      station: clearStation ? null : (station ?? this.station),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Station Detail Notifier
class StationDetailNotifier extends StateNotifier<StationDetailState> {
  final StationRepository _repository;

  StationDetailNotifier(this._repository) : super(StationDetailState());

  /// Load station detail by stationId
  Future<void> loadStation(String stationId) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final station = await _repository.getStationDetail(stationId);
      state = state.copyWith(
        station: station,
        isLoading: false,
      );
    } on ApiError catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: ApiError(
          traceId: '',
          code: 'UNKNOWN_ERROR',
          message: e.toString(),
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  /// Refresh station detail
  Future<void> refresh(String stationId) async {
    await loadStation(stationId);
  }
}

/// Station Detail Provider
final stationDetailProvider =
    StateNotifierProvider<StationDetailNotifier, StationDetailState>((ref) {
  final repository = ref.watch(stationRepositoryProvider);
  return StationDetailNotifier(repository);
});

/// Future Provider for station detail (for use in booking detail, etc.)
final stationDetailFutureProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, stationId) async {
  final repository = ref.watch(stationRepositoryProvider);
  return repository.getStationDetail(stationId);
});

/// Recommendation Request Parameters
class RecommendationParams {
  final double lat;
  final double lng;
  final double radiusKm;
  final int batteryPercent;
  final double batteryCapacityKwh;
  final int? targetPercent;
  final double? consumptionKwhPerKm;
  final double? averageSpeedKmph;
  final double? vehicleMaxChargeKw;
  final int? limit;

  RecommendationParams({
    required this.lat,
    required this.lng,
    required this.radiusKm,
    required this.batteryPercent,
    required this.batteryCapacityKwh,
    this.targetPercent,
    this.consumptionKwhPerKm,
    this.averageSpeedKmph,
    this.vehicleMaxChargeKw,
    this.limit,
  });
}

/// Recommendation State
class RecommendationState {
  final Map<String, dynamic>? response;
  final bool isLoading;
  final ApiError? error;

  RecommendationState({
    this.response,
    this.isLoading = false,
    this.error,
  });

  RecommendationState copyWith({
    Map<String, dynamic>? response,
    bool? isLoading,
    ApiError? error,
    bool clearError = false,
    bool clearResponse = false,
  }) {
    return RecommendationState(
      response: clearResponse ? null : (response ?? this.response),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  List<Map<String, dynamic>> get results {
    if (response == null) return [];
    final results = response!['results'] as List<dynamic>?;
    return results?.map((e) => e as Map<String, dynamic>).toList() ?? [];
  }
}

/// Recommendation Notifier
class RecommendationNotifier extends StateNotifier<RecommendationState> {
  final StationRepository _repository;

  RecommendationNotifier(this._repository) : super(RecommendationState());

  /// Get recommendations
  Future<void> getRecommendations(RecommendationParams params) async {
    state = state.copyWith(isLoading: true, clearError: true, clearResponse: true);

    try {
      final response = await _repository.getRecommendations(
        lat: params.lat,
        lng: params.lng,
        radiusKm: params.radiusKm,
        batteryPercent: params.batteryPercent,
        batteryCapacityKwh: params.batteryCapacityKwh,
        targetPercent: params.targetPercent,
        consumptionKwhPerKm: params.consumptionKwhPerKm,
        averageSpeedKmph: params.averageSpeedKmph,
        vehicleMaxChargeKw: params.vehicleMaxChargeKw,
        limit: params.limit,
      );

      state = state.copyWith(
        response: response,
        isLoading: false,
      );
    } on ApiError catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: ApiError(
          traceId: '',
          code: 'UNKNOWN_ERROR',
          message: e.toString(),
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  /// Clear recommendations
  void clear() {
    state = RecommendationState();
  }
}

/// Recommendation Provider
final recommendationProvider =
    StateNotifierProvider<RecommendationNotifier, RecommendationState>((ref) {
  final repository = ref.watch(stationRepositoryProvider);
  return RecommendationNotifier(repository);
});

