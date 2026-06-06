import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';
import '../models/notification_model.dart';
import '../providers/notification_provider.dart';
import '../widgets/main_scaffold.dart';
import '../widgets/notification_list_item.dart';

/// Notifications screen
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
    // Navigate based on reference type
    if (notification.referenceType != null && notification.referenceId != null) {
      switch (notification.referenceType) {
        case 'TASK':
        case 'VERIFICATION_TASK':
          context.push('/charging-station/${notification.referenceId}');
          break;
        case 'BATTERY_SWAP_TASK':
          context.push('/swap-station/${notification.referenceId}');
          break;
        case 'CONTRACT':
          // Contracts are handled differently in collab app
          // Could navigate to a contracts list or detail screen
          context.push('/profile');
          break;
        case 'STATION':
          // Station details - could use existing station detail if available
          context.push('/charging-station');
          break;
        default:
          // Just mark as read, no navigation
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationsProvider);
    final theme = Theme.of(context);

    return CollabMainScaffold(
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
      return const SkeletonList(count: 5);
    }

    if (state.error != null && state.notifications.isEmpty) {
      return ErrorState(
        message: state.error,
        onRetry: () {
          ref.read(notificationsProvider.notifier).loadNotifications();
        },
      );
    }

    if (state.notifications.isEmpty) {
      return const EmptyState(
        title: 'No notifications',
        message: 'You have no notifications yet.',
        icon: Icons.notifications_none,
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
                label: Text(category.name),
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
      case NotificationCategory.TASK:
        return Colors.blue;
      case NotificationCategory.CONTRACT:
        return Colors.green;
      case NotificationCategory.STATION:
        return Colors.orange;
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
