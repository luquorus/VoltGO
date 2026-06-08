import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';
import '../models/notification_model.dart';
import '../providers/notification_provider.dart';
import '../widgets/main_scaffold.dart';
import '../widgets/notification_list_item.dart';

/// Notifications screen for EV user mobile app
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // Load notifications on first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationsProvider.notifier).loadNotifications();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(notificationsProvider.notifier).loadMore();
    }
  }

  void _onNotificationTap(NotificationItem notification) {
    // Mark as read if unread
    if (!notification.isRead) {
      ref.read(notificationsProvider.notifier).markAsRead(notification.id);
    }

    // Navigate based on reference type
    navigateFromNotification(context, notification);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationsProvider);
    final theme = Theme.of(context);

    return MainScaffold(
      title: 'Notifications',
      actions: [
        if (state.unreadCount > 0)
          TextButton.icon(
            onPressed: () {
              ref.read(notificationsProvider.notifier).markAllAsRead();
            },
            icon: const Icon(Icons.done_all, size: 18),
            label: const Text('Mark all read'),
          ),
      ],
      child: Column(
        children: [
          // Category filter chips
          _CategoryFilterChips(
            selectedCategory: state.categoryFilter,
            onCategorySelected: (category) {
              ref.read(notificationsProvider.notifier).filterByCategory(category);
            },
          ),

          // Read/Unread filter
          _ReadFilterRow(
            readFilter: state.readFilter,
            onFilterChanged: (isRead) {
              ref.read(notificationsProvider.notifier).filterByReadStatus(isRead);
            },
          ),

          // Notification list
          Expanded(
            child: _buildContent(state, theme),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(NotificationState state, ThemeData theme) {
    if (state.isLoading && state.notifications.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (state.error != null && state.notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load notifications',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              state.error ?? 'Unknown error',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.read(notificationsProvider.notifier).loadNotifications();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state.notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none,
              size: 80,
              color: theme.colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No notifications',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "You're all caught up!",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(notificationsProvider.notifier).refresh(),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(top: 8, bottom: 16),
        itemCount: state.notifications.length + (state.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == state.notifications.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final notification = state.notifications[index];
          return NotificationListItem(
            notification: notification,
            onTap: () => _onNotificationTap(notification),
            onMarkAsRead: () {
              ref.read(notificationsProvider.notifier).markAsRead(notification.id);
            },
          );
        },
      ),
    );
  }
}

/// Category filter chips row
class _CategoryFilterChips extends StatelessWidget {
  final NotificationCategory selectedCategory;
  final ValueChanged<NotificationCategory> onCategorySelected;

  const _CategoryFilterChips({
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.1),
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: NotificationCategory.values.map((category) {
            final isSelected = selectedCategory == category;
            final color = _getCategoryColor(category);

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(category.displayName),
                selected: isSelected,
                onSelected: (_) => onCategorySelected(category),
                selectedColor: color.withOpacity(0.2),
                checkmarkColor: color,
                labelStyle: TextStyle(
                  color: isSelected ? color : theme.colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                side: BorderSide(
                  color: isSelected ? color : theme.colorScheme.outline.withOpacity(0.3),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Color _getCategoryColor(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.ALL:
        return Colors.grey;
      case NotificationCategory.BOOKING:
        return Colors.blue;
      case NotificationCategory.BATTERY_SWAP:
        return Colors.purple;
      case NotificationCategory.STATION:
        return Colors.orange;
      case NotificationCategory.SYSTEM:
        return Colors.grey;
    }
  }
}

/// Read/Unread filter row
class _ReadFilterRow extends StatelessWidget {
  final bool? readFilter;
  final ValueChanged<bool?> onFilterChanged;

  const _ReadFilterRow({
    required this.readFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            'Show:',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('All'),
            selected: readFilter == null,
            onSelected: (_) => onFilterChanged(null),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 4),
          ChoiceChip(
            label: const Text('Unread'),
            selected: readFilter == false,
            onSelected: (_) => onFilterChanged(false),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 4),
          ChoiceChip(
            label: const Text('Read'),
            selected: readFilter == true,
            onSelected: (_) => onFilterChanged(true),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
