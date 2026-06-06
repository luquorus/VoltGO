import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_api/shared_api.dart';
import '../models/notification_model.dart';
import '../repositories/notification_repository.dart';

// ============================================
// Notification Repository Provider
// ============================================

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final apiFactory = ref.watch(apiClientFactoryProvider);
  if (apiFactory == null) {
    throw Exception('ApiClientFactory not initialized');
  }
  return NotificationRepository(apiFactory.collabWeb);
});

// ============================================
// Notification Filters
// ============================================

class NotificationFilters {
  final NotificationCategory category;
  final bool? isRead;

  const NotificationFilters({
    this.category = NotificationCategory.all,
    this.isRead,
  });

  NotificationFilters copyWith({
    NotificationCategory? category,
    bool? isRead,
    bool clearIsRead = false,
  }) {
    return NotificationFilters(
      category: category ?? this.category,
      isRead: clearIsRead ? null : (isRead ?? this.isRead),
    );
  }
}

final notificationFiltersProvider = StateProvider<NotificationFilters>(
  (ref) => const NotificationFilters(),
);

final notificationPageParamsProvider = StateProvider<({int page, int size})>(
  (ref) => (page: 0, size: 20),
);

final notificationPageProvider = FutureProvider.family<NotificationPage, ({
  NotificationFilters filters,
  int page,
  int size,
})>((ref, params) async {
  final repository = ref.watch(notificationRepositoryProvider);
  return repository.getNotifications(
    category: params.filters.category,
    isRead: params.filters.isRead,
    page: params.page,
    size: params.size,
  );
});

final notificationsProvider = Provider<AsyncValue<NotificationPage>>((ref) {
  final filters = ref.watch(notificationFiltersProvider);
  final pageParams = ref.watch(notificationPageParamsProvider);
  return ref.watch(notificationPageProvider((
    filters: filters,
    page: pageParams.page,
    size: pageParams.size,
  )));
});

// ============================================
// Unread Count
// ============================================

class UnreadCountNotifier extends StateNotifier<int> {
  final NotificationRepository _repository;

  UnreadCountNotifier(this._repository) : super(0) {
    _load();
  }

  Future<void> _load() async {
    try {
      state = await _repository.getUnreadCount();
    } catch (_) {
      state = 0;
    }
  }

  Future<void> refresh() async {
    await _load();
  }

  void decrement() {
    if (state > 0) state = state - 1;
  }

  void setCount(int count) {
    state = count;
  }
}

final unreadCountNotifierProvider =
    StateNotifierProvider<UnreadCountNotifier, int>((ref) {
  final repository = ref.watch(notificationRepositoryProvider);
  return UnreadCountNotifier(repository);
});

// ============================================
// Notification Actions
// ============================================

class NotificationActionsNotifier extends StateNotifier<AsyncValue<void>> {
  final NotificationRepository _repository;
  final Ref _ref;

  NotificationActionsNotifier(this._repository, this._ref)
      : super(const AsyncValue.data(null));

  Future<void> markAsRead(String id) async {
    state = const AsyncValue.loading();
    try {
      await _repository.markAsRead(id);
      state = const AsyncValue.data(null);
      _ref.invalidate(notificationsProvider);
      _ref.read(unreadCountNotifierProvider.notifier).decrement();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> markAllAsRead() async {
    state = const AsyncValue.loading();
    try {
      await _repository.markAllAsRead();
      state = const AsyncValue.data(null);
      _ref.invalidate(notificationsProvider);
      _ref.read(unreadCountNotifierProvider.notifier).setCount(0);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final notificationActionsProvider =
    StateNotifierProvider<NotificationActionsNotifier, AsyncValue<void>>((ref) {
  final repository = ref.watch(notificationRepositoryProvider);
  return NotificationActionsNotifier(repository, ref);
});

// ============================================
// Preferences
// ============================================

final notificationPreferencesProvider =
    FutureProvider<List<NotificationPreferenceItem>>((ref) async {
  final repository = ref.watch(notificationRepositoryProvider);
  return repository.getPreferences();
});
