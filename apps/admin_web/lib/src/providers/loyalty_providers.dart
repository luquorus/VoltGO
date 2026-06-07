import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_api/shared_api.dart';

/// Admin loyalty dashboard stats provider
final adminLoyaltyDashboardProvider = FutureProvider<AdminLoyaltyDashboard>((ref) async {
  final factory = ref.watch(apiClientFactoryProvider);
  if (factory == null) {
    throw Exception('ApiClientFactory not initialized');
  }
  final data = await factory.admin.getLoyaltyDashboard();
  return AdminLoyaltyDashboard.fromJson(data);
});

/// Admin loyalty users list state
class AdminLoyaltyUsersState {
  final List<AdminLoyaltyUser> users;
  final int page;
  final int totalPages;
  final bool isLoading;
  final bool hasMore;
  final String? error;

  AdminLoyaltyUsersState({
    this.users = const [],
    this.page = 0,
    this.totalPages = 0,
    this.isLoading = false,
    this.hasMore = false,
    this.error,
  });

  AdminLoyaltyUsersState copyWith({
    List<AdminLoyaltyUser>? users,
    int? page,
    int? totalPages,
    bool? isLoading,
    bool? hasMore,
    String? error,
  }) {
    return AdminLoyaltyUsersState(
      users: users ?? this.users,
      page: page ?? this.page,
      totalPages: totalPages ?? this.totalPages,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error,
    );
  }
}

/// Admin loyalty users list notifier
class AdminLoyaltyUsersNotifier extends StateNotifier<AdminLoyaltyUsersState> {
  final ApiClientFactory _factory;

  AdminLoyaltyUsersNotifier(this._factory) : super(AdminLoyaltyUsersState()) {
    loadUsers();
  }

  Future<void> loadUsers({bool refresh = false}) async {
    if (state.isLoading) return;

    final page = refresh ? 0 : state.page;
    state = state.copyWith(isLoading: true, error: null);

    try {
      final data = await _factory.admin.getLoyaltyUsers(page: page);
      final content = (data['content'] as List<dynamic>?)
              ?.map((e) => AdminLoyaltyUser.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      final totalPages = data['totalPages'] as int? ?? 0;

      state = state.copyWith(
        users: refresh ? content : [...state.users, ...content],
        page: page,
        totalPages: totalPages,
        hasMore: page < totalPages - 1,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoading) return;
    state = state.copyWith(page: state.page + 1);
    await loadUsers();
  }

  Future<void> refresh() => loadUsers(refresh: true);
}

final adminLoyaltyUsersProvider =
    StateNotifierProvider<AdminLoyaltyUsersNotifier, AdminLoyaltyUsersState>((ref) {
  final factory = ref.watch(apiClientFactoryProvider);
  if (factory == null) {
    throw Exception('ApiClientFactory not initialized');
  }
  return AdminLoyaltyUsersNotifier(factory);
});

/// Admin ratings list state
class AdminRatingsState {
  final List<AdminStationRating> ratings;
  final int page;
  final int totalPages;
  final bool isLoading;
  final bool hasMore;
  final String? error;
  final String? statusFilter;
  final String? stationFilter;

  AdminRatingsState({
    this.ratings = const [],
    this.page = 0,
    this.totalPages = 0,
    this.isLoading = false,
    this.hasMore = false,
    this.error,
    this.statusFilter,
    this.stationFilter,
  });

  AdminRatingsState copyWith({
    List<AdminStationRating>? ratings,
    int? page,
    int? totalPages,
    bool? isLoading,
    bool? hasMore,
    String? error,
    String? statusFilter,
    String? stationFilter,
  }) {
    return AdminRatingsState(
      ratings: ratings ?? this.ratings,
      page: page ?? this.page,
      totalPages: totalPages ?? this.totalPages,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error,
      statusFilter: statusFilter ?? this.statusFilter,
      stationFilter: stationFilter ?? this.stationFilter,
    );
  }
}

/// Admin ratings list notifier
class AdminRatingsNotifier extends StateNotifier<AdminRatingsState> {
  final ApiClientFactory _factory;

  AdminRatingsNotifier(this._factory) : super(AdminRatingsState()) {
    loadRatings();
  }

  Future<void> loadRatings({bool refresh = false}) async {
    if (state.isLoading) return;

    final page = refresh ? 0 : state.page;
    state = state.copyWith(isLoading: true, error: null);

    try {
      final data = await _factory.admin.getLoyaltyRatings(
        page: page,
        status: state.statusFilter,
        stationId: state.stationFilter,
      );
      final content = (data['content'] as List<dynamic>?)
              ?.map((e) => AdminStationRating.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      final totalPages = data['totalPages'] as int? ?? 0;

      state = state.copyWith(
        ratings: refresh ? content : [...state.ratings, ...content],
        page: page,
        totalPages: totalPages,
        hasMore: page < totalPages - 1,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoading) return;
    state = state.copyWith(page: state.page + 1);
    await loadRatings();
  }

  Future<void> refresh() => loadRatings(refresh: true);

  void setFilters({String? status, String? station}) {
    state = state.copyWith(
      statusFilter: status,
      stationFilter: station,
      page: 0,
      ratings: [],
      hasMore: false,
    );
    loadRatings(refresh: true);
  }

  Future<void> hideRating(String ratingId) async {
    try {
      await _factory.admin.hideRating(ratingId);
      state = state.copyWith(
        ratings: state.ratings.where((r) => r.id != ratingId).toList(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

final adminRatingsProvider =
    StateNotifierProvider<AdminRatingsNotifier, AdminRatingsState>((ref) {
  final factory = ref.watch(apiClientFactoryProvider);
  if (factory == null) {
    throw Exception('ApiClientFactory not initialized');
  }
  return AdminRatingsNotifier(factory);
});
final adminApiClientProvider = Provider<AdminWebApiClient?>((ref) {
  return null; // Will be provided from the app's provider setup
});

/// Provider for admin loyalty profile
final adminLoyaltyProfileProvider =
    FutureProvider.family<LoyaltyUserProfile, String>((ref, userId) async {
  final factory = ref.watch(apiClientFactoryProvider);
  if (factory == null) {
    throw Exception('ApiClientFactory not initialized');
  }
  final data = await factory.admin.getUserLoyaltyProfile(userId);
  return LoyaltyUserProfile.fromJson(data);
});

/// Admin point history state
class AdminPointHistoryState {
  final List<PointTransaction> transactions;
  final int page;
  final int totalPages;
  final bool isLoading;
  final bool hasMore;
  final String? error;

  AdminPointHistoryState({
    this.transactions = const [],
    this.page = 0,
    this.totalPages = 0,
    this.isLoading = false,
    this.hasMore = false,
    this.error,
  });

  AdminPointHistoryState copyWith({
    List<PointTransaction>? transactions,
    int? page,
    int? totalPages,
    bool? isLoading,
    bool? hasMore,
    String? error,
  }) {
    return AdminPointHistoryState(
      transactions: transactions ?? this.transactions,
      page: page ?? this.page,
      totalPages: totalPages ?? this.totalPages,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error,
    );
  }
}

/// Admin point history notifier
class AdminPointHistoryNotifier extends StateNotifier<AdminPointHistoryState> {
  final ApiClientFactory _factory;
  final String _userId;

  AdminPointHistoryNotifier(this._factory, this._userId)
      : super(AdminPointHistoryState()) {
    loadHistory();
  }

  Future<void> loadHistory({bool refresh = false}) async {
    if (state.isLoading) return;

    final page = refresh ? 0 : state.page;
    state = state.copyWith(isLoading: true, error: null);

    try {
      final data = await _factory.admin.getUserPointHistory(_userId, page: page);
      final content = (data['content'] as List<dynamic>?)
              ?.map((e) => PointTransaction.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      final totalPages = data['totalPages'] as int? ?? 0;

      state = state.copyWith(
        transactions: refresh ? content : [...state.transactions, ...content],
        page: page,
        totalPages: totalPages,
        hasMore: page < totalPages - 1,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoading) return;
    state = state.copyWith(page: state.page + 1);
    await loadHistory();
  }

  Future<void> refresh() => loadHistory(refresh: true);
}

/// Provider for admin point history
final adminPointHistoryProvider = StateNotifierProvider.family<
    AdminPointHistoryNotifier, AdminPointHistoryState, String>((ref, userId) {
  final factory = ref.watch(apiClientFactoryProvider);
  if (factory == null) {
    throw Exception('ApiClientFactory not initialized');
  }
  return AdminPointHistoryNotifier(factory, userId);
});

/// Adjust points state
class AdjustPointsState {
  final bool isLoading;
  final String? error;
  final bool success;

  AdjustPointsState({
    this.isLoading = false,
    this.error,
    this.success = false,
  });

  AdjustPointsState copyWith({
    bool? isLoading,
    String? error,
    bool? success,
  }) {
    return AdjustPointsState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      success: success ?? this.success,
    );
  }
}

/// Adjust points notifier
class AdjustPointsNotifier extends StateNotifier<AdjustPointsState> {
  final Ref _ref;

  AdjustPointsNotifier(this._ref) : super(AdjustPointsState());

  Future<bool> adjustPoints(String userId, int delta, String reason) async {
    state = state.copyWith(isLoading: true, error: null, success: false);

    try {
      final factory = _ref.read(apiClientFactoryProvider);
      if (factory == null) {
        throw Exception('ApiClientFactory not initialized');
      }
      await factory.admin.adjustUserPoints(userId, delta: delta, reason: reason);
      state = state.copyWith(isLoading: false, success: true);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  void reset() {
    state = AdjustPointsState();
  }
}

/// Provider for adjust points
final adjustPointsProvider =
    StateNotifierProvider<AdjustPointsNotifier, AdjustPointsState>((ref) {
  return AdjustPointsNotifier(ref);
});

/// Admin badge list provider
final adminBadgesProvider = FutureProvider<List<BadgeWithProgress>>((ref) async {
  final factory = ref.watch(apiClientFactoryProvider);
  if (factory == null) {
    throw Exception('ApiClientFactory not initialized');
  }
  final data = await factory.admin.getAllBadges();
  return (data as List<dynamic>)
      .map((e) => BadgeWithProgress.fromJson(e as Map<String, dynamic>))
      .toList();
});
