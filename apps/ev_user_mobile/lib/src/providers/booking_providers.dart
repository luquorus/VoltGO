import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_api/shared_api.dart';
import 'package:shared_network/shared_network.dart';
import 'package:shared_auth/shared_auth.dart';
import '../repositories/booking_repository.dart';

/// Provider for BookingRepository
final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  final factory = ref.watch(apiClientFactoryProvider);
  if (factory == null) {
    throw Exception('ApiClientFactory not initialized');
  }
  return BookingRepository(factory.ev);
});

/// Booking list state
class BookingListState {
  final List<Map<String, dynamic>> bookings;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool isLoading;
  final bool hasMore;
  final String? error;

  BookingListState({
    this.bookings = const [],
    this.page = 0,
    this.size = 20,
    this.totalElements = 0,
    this.totalPages = 0,
    this.isLoading = false,
    this.hasMore = false,
    this.error,
  });

  BookingListState copyWith({
    List<Map<String, dynamic>>? bookings,
    int? page,
    int? size,
    int? totalElements,
    int? totalPages,
    bool? isLoading,
    bool? hasMore,
    String? error,
  }) {
    return BookingListState(
      bookings: bookings ?? this.bookings,
      page: page ?? this.page,
      size: size ?? this.size,
      totalElements: totalElements ?? this.totalElements,
      totalPages: totalPages ?? this.totalPages,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error,
    );
  }
}

/// Booking list notifier
class BookingListNotifier extends StateNotifier<BookingListState> {
  final BookingRepository _repository;

  BookingListNotifier(this._repository) : super(BookingListState()) {
    loadBookings();
  }

  Future<void> loadBookings({bool refresh = false}) async {
    if (state.isLoading) return;

    final page = refresh ? 0 : state.page;
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _repository.getBookings(page: page, size: state.size);
      final content = (response['content'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [];
      final totalElements = response['totalElements'] as int? ?? 0;
      final totalPages = response['totalPages'] as int? ?? 0;

      state = state.copyWith(
        bookings: refresh ? content : [...state.bookings, ...content],
        page: page,
        totalElements: totalElements,
        totalPages: totalPages,
        hasMore: page < totalPages - 1,
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

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoading) return;
    await loadBookings();
  }

  Future<void> refresh() => loadBookings(refresh: true);
}

/// Provider for booking list
/// Auto-disposes when userId changes to ensure fresh data for each user
final bookingListProvider =
    StateNotifierProvider.autoDispose<BookingListNotifier, BookingListState>((ref) {
  final repository = ref.watch(bookingRepositoryProvider);
  final authState = ref.watch(authStateProvider);
  
  // Invalidate provider when userId changes (user logs in/out or switches account)
  // This ensures booking list is reset and reloaded for the new user
  ref.listen(authStateProvider, (previous, next) {
    if (previous?.userId != next.userId) {
      // User changed - schedule invalidation on next frame to avoid issues during build
      Future.microtask(() {
        ref.invalidateSelf();
      });
    }
  });
  
  return BookingListNotifier(repository);
});

/// Provider for single booking detail
final bookingDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, bookingId) async {
  final repository = ref.watch(bookingRepositoryProvider);
  final booking = await repository.getBooking(bookingId);
  
  // Try to get payment intent if booking is HOLD
  final status = booking['status'] as String? ?? '';
  if (status == 'HOLD') {
    try {
      // Note: There's no GET endpoint for payment intent by bookingId in backend
      // So we'll manage it via local state when created
      // This will be handled by paymentIntentProvider
    } catch (e) {
      // Payment intent might not exist yet, ignore
    }
  }
  
  return booking;
});

/// Provider for payment intent by booking ID (stored in local state)
final paymentIntentProvider = StateProvider.family<Map<String, dynamic>?, String>((ref, bookingId) => null);

