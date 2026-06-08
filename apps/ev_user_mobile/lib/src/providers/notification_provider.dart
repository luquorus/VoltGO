import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_api/shared_api.dart';
import '../models/notification_model.dart';

/// Notification state
class NotificationState {
  final List<NotificationItem> notifications;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int unreadCount;
  final String? error;
  final NotificationCategory categoryFilter;
  final bool? readFilter;

  const NotificationState({
    this.notifications = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.unreadCount = 0,
    this.error,
    this.categoryFilter = NotificationCategory.ALL,
    this.readFilter,
  });

  NotificationState copyWith({
    List<NotificationItem>? notifications,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? unreadCount,
    String? error,
    NotificationCategory? categoryFilter,
    bool? readFilter,
    bool clearError = false,
    bool clearReadFilter = false,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      unreadCount: unreadCount ?? this.unreadCount,
      error: clearError ? null : (error ?? this.error),
      categoryFilter: categoryFilter ?? this.categoryFilter,
      readFilter: clearReadFilter ? null : (readFilter ?? this.readFilter),
    );
  }
}

/// Notification state notifier
class NotificationNotifier extends StateNotifier<NotificationState> {
  final Ref ref;

  NotificationNotifier(this.ref) : super(const NotificationState());

  /// Get the API client
  EvUserMobileApiClient get _api => ref.read(apiClientFactoryProvider)!.ev;

  /// Load notifications (initial load)
  Future<void> loadNotifications({bool refresh = false}) async {
    if (state.isLoading) return;

    if (refresh) {
      state = state.copyWith(
        isLoading: true,
        clearError: true,
        notifications: [],
      );
    } else {
      state = state.copyWith(isLoading: true, clearError: true);
    }

    try {
      final response = await _api.getNotifications(
        category: state.categoryFilter == NotificationCategory.ALL 
            ? null 
            : state.categoryFilter.value,
        isRead: state.readFilter,
        page: 0,
        size: 20,
      );

      final page = NotificationPage.fromJson(response);

      state = state.copyWith(
        notifications: page.notifications,
        hasMore: page.hasMore,
        isLoading: false,
        unreadCount: page.unreadCount,
      );

      // Invalidate the unread count provider to keep bell badge in sync
      ref.invalidate(unreadNotificationCountProvider);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Load more notifications (pagination)
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final currentPage = (state.notifications.length / 20).floor();

      final response = await _api.getNotifications(
        category: state.categoryFilter == NotificationCategory.ALL 
            ? null 
            : state.categoryFilter.value,
        isRead: state.readFilter,
        page: currentPage,
        size: 20,
      );

      final page = NotificationPage.fromJson(response);

      state = state.copyWith(
        notifications: [...state.notifications, ...page.notifications],
        hasMore: page.hasMore,
        isLoadingMore: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingMore: false,
        error: e.toString(),
      );
    }
  }

  /// Refresh notifications
  Future<void> refresh() => loadNotifications(refresh: true);

  /// Mark a notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _api.markNotificationAsRead(notificationId);

      // Update local state
      final updatedNotifications = state.notifications.map((n) {
        if (n.id == notificationId) {
          return n.copyWith(isRead: true);
        }
        return n;
      }).toList();

      state = state.copyWith(
        notifications: updatedNotifications,
        unreadCount: state.unreadCount > 0 ? state.unreadCount - 1 : 0,
      );

      // Invalidate the unread count provider to refresh the bell badge
      ref.invalidate(unreadNotificationCountProvider);
    } catch (e) {
      // Silently fail - notification will remain unread
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      await _api.markAllNotificationsAsRead();

      // Update local state
      final updatedNotifications = state.notifications.map((n) {
        return n.copyWith(isRead: true);
      }).toList();

      state = state.copyWith(
        notifications: updatedNotifications,
        unreadCount: 0,
      );

      // Invalidate the unread count provider to refresh the bell badge
      ref.invalidate(unreadNotificationCountProvider);
    } catch (e) {
      // Silently fail
    }
  }

  /// Filter by category
  Future<void> filterByCategory(NotificationCategory category) async {
    if (state.categoryFilter == category) return;

    state = state.copyWith(
      categoryFilter: category,
      clearReadFilter: true,
    );

    await loadNotifications(refresh: true);
  }

  /// Filter by read status
  Future<void> filterByReadStatus(bool? isRead) async {
    state = state.copyWith(
      readFilter: isRead,
      clearReadFilter: isRead == null,
    );

    await loadNotifications(refresh: true);
  }

  /// Load unread count only
  Future<void> loadUnreadCount() async {
    try {
      final count = await _api.getUnreadNotificationCount();
      state = state.copyWith(unreadCount: count);
    } catch (e) {
      // Silently fail
    }
  }
}

/// Main notification provider
final notificationsProvider =
    StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
  return NotificationNotifier(ref);
});

/// Provider for unread count only (lighter weight)
final unreadNotificationCountProvider = FutureProvider<int>((ref) async {
  final factory = ref.read(apiClientFactoryProvider);
  if (factory == null) return 0;

  try {
    return await factory.ev.getUnreadNotificationCount();
  } catch (e) {
    return 0;
  }
});
