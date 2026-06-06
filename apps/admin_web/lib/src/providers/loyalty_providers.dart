import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_api/shared_api.dart';

/// Admin loyalty providers
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
