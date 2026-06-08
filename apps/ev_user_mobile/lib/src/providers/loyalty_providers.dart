import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_api/shared_api.dart';

/// Provider for loyalty profile
final loyaltyProfileProvider = FutureProvider<LoyaltyUserProfile>((ref) async {
  final factory = ref.watch(apiClientFactoryProvider);
  if (factory == null) {
    throw Exception('ApiClientFactory not initialized');
  }
  final data = await factory.ev.getLoyaltyProfile();
  return LoyaltyUserProfile.fromJson(data);
});

/// Point history state
class PointHistoryState {
  final List<PointTransaction> transactions;
  final int page;
  final int totalPages;
  final bool isLoading;
  final bool hasMore;
  final String? error;

  PointHistoryState({
    this.transactions = const [],
    this.page = 0,
    this.totalPages = 0,
    this.isLoading = false,
    this.hasMore = false,
    this.error,
  });

  PointHistoryState copyWith({
    List<PointTransaction>? transactions,
    int? page,
    int? totalPages,
    bool? isLoading,
    bool? hasMore,
    String? error,
  }) {
    return PointHistoryState(
      transactions: transactions ?? this.transactions,
      page: page ?? this.page,
      totalPages: totalPages ?? this.totalPages,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error,
    );
  }
}

/// Point history notifier
class PointHistoryNotifier extends StateNotifier<PointHistoryState> {
  final ApiClientFactory _factory;

  PointHistoryNotifier(this._factory) : super(PointHistoryState()) {
    loadHistory();
  }

  Future<void> loadHistory({bool refresh = false}) async {
    if (state.isLoading) return;

    final page = refresh ? 0 : state.page;
    state = state.copyWith(isLoading: true, error: null);

    try {
      final data = await _factory.ev.getPointHistory(page: page);
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

/// Provider for point history
final pointHistoryProvider =
    StateNotifierProvider<PointHistoryNotifier, PointHistoryState>((ref) {
  final factory = ref.watch(apiClientFactoryProvider);
  if (factory == null) {
    throw Exception('ApiClientFactory not initialized');
  }
  return PointHistoryNotifier(factory);
});

/// Provider for eligible stations for rating
final eligibleStationsForRatingProvider =
    FutureProvider<List<EligibleStationForRating>>((ref) async {
  final factory = ref.watch(apiClientFactoryProvider);
  if (factory == null) {
    throw Exception('ApiClientFactory not initialized');
  }
  final data = await factory.ev.getEligibleStationsForRating();
  return (data as List<dynamic>)
      .map((e) => EligibleStationForRating.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Provider for my ratings
final myRatingsProvider = FutureProvider<List<MyRating>>((ref) async {
  final factory = ref.watch(apiClientFactoryProvider);
  if (factory == null) {
    throw Exception('ApiClientFactory not initialized');
  }
  final data = await factory.ev.getMyRatings();
  return (data as List<dynamic>)
      .map((e) => MyRating.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Submit rating state
class SubmitRatingState {
  final bool isSubmitting;
  final String? error;

  SubmitRatingState({
    this.isSubmitting = false,
    this.error,
  });

  SubmitRatingState copyWith({
    bool? isSubmitting,
    String? error,
  }) {
    return SubmitRatingState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error,
    );
  }
}

/// Submit rating notifier
class SubmitRatingNotifier extends StateNotifier<SubmitRatingState> {
  final Ref _ref;

  SubmitRatingNotifier(this._ref) : super(SubmitRatingState());

  Future<MyRating> submit(SubmitRatingRequest request) async {
    state = state.copyWith(isSubmitting: true, error: null);
    try {
      final factory = _ref.read(apiClientFactoryProvider);
      if (factory == null) {
        throw Exception('ApiClientFactory not initialized');
      }
      final data = await factory.ev.submitRating(request.toJson());
      final rating = MyRating.fromJson(data);
      
      // Invalidate related providers
      _ref.invalidate(loyaltyProfileProvider);
      _ref.invalidate(eligibleStationsForRatingProvider);
      _ref.invalidate(myRatingsProvider);
      _ref.invalidate(stationRatingsProvider(request.stationId));
      _ref.invalidate(stationRatingSummaryProvider(request.stationId));
      
      state = state.copyWith(isSubmitting: false);
      return rating;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> markHelpful(String ratingId) async {
    try {
      final factory = _ref.read(apiClientFactoryProvider);
      if (factory == null) return;
      await factory.ev.markRatingHelpful(ratingId);
      _ref.invalidate(myRatingsProvider);
    } catch (e) {
      // Silent fail for helpful marking
    }
  }
}

/// Provider for submit rating
final submitRatingProvider =
    StateNotifierProvider<SubmitRatingNotifier, SubmitRatingState>((ref) {
  return SubmitRatingNotifier(ref);
});

/// Provider for my badges
final myBadgesProvider = FutureProvider<List<UserBadge>>((ref) async {
  final factory = ref.watch(apiClientFactoryProvider);
  if (factory == null) {
    throw Exception('ApiClientFactory not initialized');
  }
  final data = await factory.ev.getMyBadges();
  return (data as List<dynamic>)
      .map((e) => UserBadge.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Provider for available badges with progress
final availableBadgesProvider = FutureProvider<List<BadgeWithProgress>>((ref) async {
  final factory = ref.watch(apiClientFactoryProvider);
  if (factory == null) {
    throw Exception('ApiClientFactory not initialized');
  }
  final data = await factory.ev.getAvailableBadges();
  return (data as List<dynamic>)
      .map((e) => BadgeWithProgress.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Station ratings (public) state
class StationRatingsState {
  final List<StationRating> ratings;
  final int page;
  final int totalPages;
  final bool isLoading;
  final bool hasMore;

  StationRatingsState({
    this.ratings = const [],
    this.page = 0,
    this.totalPages = 0,
    this.isLoading = false,
    this.hasMore = false,
  });

  StationRatingsState copyWith({
    List<StationRating>? ratings,
    int? page,
    int? totalPages,
    bool? isLoading,
    bool? hasMore,
  }) {
    return StationRatingsState(
      ratings: ratings ?? this.ratings,
      page: page ?? this.page,
      totalPages: totalPages ?? this.totalPages,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

/// Station ratings notifier
class StationRatingsNotifier extends StateNotifier<StationRatingsState> {
  final ApiClientFactory _factory;
  final String _stationId;

  StationRatingsNotifier(this._factory, this._stationId)
      : super(StationRatingsState()) {
    loadRatings();
  }

  Future<void> loadRatings({bool refresh = false}) async {
    if (state.isLoading) return;

    final page = refresh ? 0 : state.page;
    state = state.copyWith(isLoading: true);

    try {
      final data = await _factory.ev.getStationRatings(_stationId, page: page);
      final content = (data['content'] as List<dynamic>?)
              ?.map((e) => StationRating.fromJson(e as Map<String, dynamic>))
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
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoading) return;
    state = state.copyWith(page: state.page + 1);
    await loadRatings();
  }

  Future<void> refresh() => loadRatings(refresh: true);
}

/// Provider for station ratings
final stationRatingsProvider = StateNotifierProvider.family<
    StationRatingsNotifier, StationRatingsState, String>((ref, stationId) {
  final factory = ref.watch(apiClientFactoryProvider);
  if (factory == null) {
    throw Exception('ApiClientFactory not initialized');
  }
  return StationRatingsNotifier(factory, stationId);
});

/// Provider for station rating summary
final stationRatingSummaryProvider =
    FutureProvider.family<StationRatingSummary, String>((ref, stationId) async {
  final factory = ref.watch(apiClientFactoryProvider);
  if (factory == null) {
    throw Exception('ApiClientFactory not initialized');
  }
  final data = await factory.ev.getStationRatingSummary(stationId);
  return StationRatingSummary.fromJson(data);
});

/// Referral code state
class ReferralCodeState {
  final ReferralCode? code;
  final bool isLoading;
  final String? error;

  ReferralCodeState({
    this.code,
    this.isLoading = false,
    this.error,
  });

  ReferralCodeState copyWith({
    ReferralCode? code,
    bool? isLoading,
    String? error,
  }) {
    return ReferralCodeState(
      code: code ?? this.code,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Referral code notifier
class ReferralCodeNotifier extends StateNotifier<ReferralCodeState> {
  final Ref _ref;

  ReferralCodeNotifier(this._ref) : super(ReferralCodeState());

  Future<void> loadCode() async {
    if (state.code != null || state.isLoading) return;
    state = state.copyWith(isLoading: true, error: null);

    try {
      final factory = _ref.read(apiClientFactoryProvider);
      if (factory == null) {
        throw Exception('ApiClientFactory not initialized');
      }
      final data = await factory.ev.generateReferralCode();
      final code = ReferralCode.fromJson(data);
      state = state.copyWith(code: code, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(code: null);
    await loadCode();
  }
}

/// Provider for referral code
final referralCodeProvider =
    StateNotifierProvider<ReferralCodeNotifier, ReferralCodeState>((ref) {
  return ReferralCodeNotifier(ref);
});

// ===== VOUCHER PROVIDERS =====

/// Provider for available vouchers to redeem
final availableVouchersProvider = FutureProvider<List<VoucherDefinition>>((ref) async {
  final factory = ref.watch(apiClientFactoryProvider);
  if (factory == null) {
    throw Exception('ApiClientFactory not initialized');
  }
  final data = await factory.ev.getAvailableVouchers();
  if (data is List) {
    return data.map((e) => VoucherDefinition.fromJson(e as Map<String, dynamic>)).toList();
  }
  return [];
});

/// Provider for user's redeemed vouchers (backend returns Page, so parse content array)
final myVouchersProvider = FutureProvider.family<List<VoucherRedemption>, String?>((ref, status) async {
  final factory = ref.watch(apiClientFactoryProvider);
  if (factory == null) {
    throw Exception('ApiClientFactory not initialized');
  }
  final data = await factory.ev.getMyVouchers(status: status);
  // Backend returns Page object with 'content' array
  if (data is Map) {
    final content = data['content'];
    if (content is List) {
      return content.map((e) => VoucherRedemption.fromJson(e as Map<String, dynamic>)).toList();
    }
  }
  return [];
});

/// Redeem voucher state
class RedeemVoucherState {
  final bool isLoading;
  final VoucherRedemption? redemption;
  final String? error;

  RedeemVoucherState({
    this.isLoading = false,
    this.redemption,
    this.error,
  });

  RedeemVoucherState copyWith({
    bool? isLoading,
    VoucherRedemption? redemption,
    String? error,
  }) {
    return RedeemVoucherState(
      isLoading: isLoading ?? this.isLoading,
      redemption: redemption ?? this.redemption,
      error: error,
    );
  }
}

/// Redeem voucher notifier
class RedeemVoucherNotifier extends StateNotifier<RedeemVoucherState> {
  final Ref _ref;

  RedeemVoucherNotifier(this._ref) : super(RedeemVoucherState());

  Future<VoucherRedemption?> redeem(String definitionId) async {
    state = RedeemVoucherState(isLoading: true);
    try {
      final factory = _ref.read(apiClientFactoryProvider);
      if (factory == null) {
        throw Exception('ApiClientFactory not initialized');
      }
      final data = await factory.ev.redeemVoucher(definitionId);
      final redemption = VoucherRedemption.fromJson(data);
      state = RedeemVoucherState(redemption: redemption);
      // Invalidate related providers
      _ref.invalidate(availableVouchersProvider);
      _ref.invalidate(myVouchersProvider(null));
      _ref.invalidate(myVouchersProvider('REDEEMED'));
      _ref.invalidate(myVouchersProvider('USED'));
      _ref.invalidate(myVouchersProvider('EXPIRED'));
      _ref.invalidate(loyaltyProfileProvider);
      return redemption;
    } catch (e) {
      state = RedeemVoucherState(error: e.toString());
      rethrow;
    }
  }

  void reset() => state = RedeemVoucherState();
}

/// Provider for redeem voucher
final redeemVoucherProvider =
    StateNotifierProvider<RedeemVoucherNotifier, RedeemVoucherState>((ref) {
  return RedeemVoucherNotifier(ref);
});

/// Apply voucher to booking state
class ApplyVoucherState {
  final bool isLoading;
  final VoucherRedemption? redemption;
  final String? error;

  ApplyVoucherState({
    this.isLoading = false,
    this.redemption,
    this.error,
  });

  ApplyVoucherState copyWith({
    bool? isLoading,
    VoucherRedemption? redemption,
    String? error,
  }) {
    return ApplyVoucherState(
      isLoading: isLoading ?? this.isLoading,
      redemption: redemption ?? this.redemption,
      error: error,
    );
  }
}

/// Apply voucher notifier
class ApplyVoucherNotifier extends StateNotifier<ApplyVoucherState> {
  final Ref _ref;

  ApplyVoucherNotifier(this._ref) : super(ApplyVoucherState());

  Future<VoucherRedemption?> applyToBooking(String redemptionId, String bookingId) async {
    state = ApplyVoucherState(isLoading: true);
    try {
      final factory = _ref.read(apiClientFactoryProvider);
      if (factory == null) {
        throw Exception('ApiClientFactory not initialized');
      }
      final data = await factory.ev.applyVoucherToBooking(redemptionId, bookingId);
      final redemption = VoucherRedemption.fromJson(data);
      state = ApplyVoucherState(redemption: redemption);
      _ref.invalidate(myVouchersProvider(null));
      _ref.invalidate(myVouchersProvider('REDEEMED'));
      _ref.invalidate(myVouchersProvider('USED'));
      _ref.invalidate(myVouchersProvider('EXPIRED'));
      return redemption;
    } catch (e) {
      state = ApplyVoucherState(error: e.toString());
      rethrow;
    }
  }

  Future<VoucherRedemption?> applyToSwap(String redemptionId, String reservationId) async {
    state = ApplyVoucherState(isLoading: true);
    try {
      final factory = _ref.read(apiClientFactoryProvider);
      if (factory == null) {
        throw Exception('ApiClientFactory not initialized');
      }
      final data = await factory.ev.applyVoucherToSwap(redemptionId, reservationId);
      final redemption = VoucherRedemption.fromJson(data);
      state = ApplyVoucherState(redemption: redemption);
      _ref.invalidate(myVouchersProvider(null));
      _ref.invalidate(myVouchersProvider('REDEEMED'));
      _ref.invalidate(myVouchersProvider('USED'));
      _ref.invalidate(myVouchersProvider('EXPIRED'));
      return redemption;
    } catch (e) {
      state = ApplyVoucherState(error: e.toString());
      rethrow;
    }
  }

  void reset() => state = ApplyVoucherState();
}

/// Provider for apply voucher
final applyVoucherProvider =
    StateNotifierProvider<ApplyVoucherNotifier, ApplyVoucherState>((ref) {
  return ApplyVoucherNotifier(ref);
});

/// Provider for voucher redemption detail
final voucherRedemptionDetailProvider =
    FutureProvider.family<VoucherRedemption, String>((ref, redemptionId) async {
  final factory = ref.watch(apiClientFactoryProvider);
  if (factory == null) {
    throw Exception('ApiClientFactory not initialized');
  }
  final data = await factory.ev.getVoucherRedemptionDetail(redemptionId);
  return VoucherRedemption.fromJson(data);
});
