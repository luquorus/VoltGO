import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';
import '../models/notification_model.dart';
import '../providers/notification_provider.dart';
import '../theme/collab_theme.dart';
import '../widgets/dashboard_shell.dart';

/// Notifications Screen - Full page notification list
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
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  void _loadMore() {
    final pageParams = ref.read(notificationPageParamsProvider);
    final notificationsAsync = ref.read(notificationsProvider);

    notificationsAsync.whenData((page) {
      if (!page.isLast && !pageParams.page.eq(page.totalPages - 1)) {
        ref.read(notificationPageParamsProvider.notifier).state = (
          page: page.totalPages > pageParams.page ? pageParams.page + 1 : pageParams.page,
          size: pageParams.size,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filters = ref.watch(notificationFiltersProvider);
    final notificationsAsync = ref.watch(notificationsProvider);

    return DashboardShell(
      title: 'Notifications',
      actions: [
        // Mark all as read button
        TextButton.icon(
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Mark All as Read'),
                content: const Text('Are you sure you want to mark all notifications as read?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Mark All Read'),
                  ),
                ],
              ),
            );

            if (confirmed == true) {
              ref.read(notificationActionsProvider.notifier).markAllAsRead();
            }
          },
          icon: const Icon(Icons.done_all, size: 18),
          label: const Text('Mark all read'),
          style: TextButton.styleFrom(
            foregroundColor: CollabTheme.primaryGreen,
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filter Row
            _buildFilterRow(theme, filters),
            const SizedBox(height: 20),

            // Notifications List
            Expanded(
              child: Card(
                margin: EdgeInsets.zero,
                child: notificationsAsync.when(
                  data: (page) => _buildNotificationsList(theme, page),
                  loading: () => const Center(
                    child: LoadingState(message: 'Loading notifications...'),
                  ),
                  error: (error, stack) => Center(
                    child: ErrorState(
                      title: 'Could not load notifications',
                      message: formatApiError(error),
                      code: extractErrorCode(error),
                      traceId: extractTraceId(error),
                      onRetry: () {
                        ref.invalidate(notificationsProvider);
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterRow(ThemeData theme, NotificationFilters filters) {
    return Row(
      children: [
        // Category Tabs
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: NotificationCategory.values.map((category) {
              final isSelected = filters.category == category;
              return Padding(
                padding: const EdgeInsets.all(4),
                child: Material(
                  color: isSelected
                      ? CollabTheme.primaryGreen.withOpacity(0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    onTap: () {
                      ref.read(notificationFiltersProvider.notifier).state =
                          filters.copyWith(category: category);
                      ref.read(notificationPageParamsProvider.notifier).state = (
                        page: 0,
                        size: ref.read(notificationPageParamsProvider).size,
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _getCategoryIcon(category),
                            size: 18,
                            color: isSelected
                                ? CollabTheme.primaryGreen
                                : theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            category.displayName,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              color: isSelected
                                  ? CollabTheme.primaryGreen
                                  : theme.colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(width: 16),

        // Read/Unread Filter
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<bool?>(
              value: filters.isRead,
              hint: Text(
                'All',
                style: theme.textTheme.bodyMedium,
              ),
              items: const [
                DropdownMenuItem<bool?>(
                  value: null,
                  child: Text('All'),
                ),
                DropdownMenuItem<bool?>(
                  value: false,
                  child: Text('Unread'),
                ),
                DropdownMenuItem<bool?>(
                  value: true,
                  child: Text('Read'),
                ),
              ],
              onChanged: (value) {
                ref.read(notificationFiltersProvider.notifier).state =
                    filters.copyWith(isRead: value, clearIsRead: value == null);
                ref.read(notificationPageParamsProvider.notifier).state = (
                  page: 0,
                  size: ref.read(notificationPageParamsProvider).size,
                );
              },
            ),
          ),
        ),

        const Spacer(),

        // Refresh button
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed: () {
            ref.invalidate(notificationsProvider);
            ref.read(unreadCountNotifierProvider.notifier).refresh();
          },
        ),
      ],
    );
  }

  Widget _buildNotificationsList(ThemeData theme, NotificationPage page) {
    if (page.notifications.isEmpty) {
      return _buildEmptyState(theme);
    }

    return Column(
      children: [
        // List Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: CollabTheme.surfaceLight,
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outline.withOpacity(0.2),
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.notifications_outlined,
                size: 20,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              const SizedBox(width: 8),
              Text(
                '${page.totalElements} notification${page.totalElements == 1 ? '' : 's'}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const Spacer(),
              if (page.unreadCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${page.unreadCount} unread',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Notification List
        Expanded(
          child: ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: page.notifications.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: theme.colorScheme.outline.withOpacity(0.1),
            ),
            itemBuilder: (context, index) {
              final notification = page.notifications[index];
              return _NotificationListItem(
                notification: notification,
                onTap: () => _handleNotificationTap(notification),
                onMarkRead: () {
                  ref.read(notificationActionsProvider.notifier).markAsRead(notification.id);
                },
              );
            },
          ),
        ),

        // Loading indicator
        if (!page.isLast)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: TextButton.icon(
                onPressed: _loadMore,
                icon: const Icon(Icons.expand_more, size: 20),
                label: const Text('Load more'),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
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
            'You\'re all caught up!',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () {
              ref.invalidate(notificationsProvider);
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  void _handleNotificationTap(NotificationItem notification) {
    // Mark as read if unread
    if (!notification.isRead) {
      ref.read(notificationActionsProvider.notifier).markAsRead(notification.id);
    }

    // Navigate based on reference type
    if (notification.referenceType != null && notification.referenceId != null) {
      switch (notification.referenceType!.toUpperCase()) {
        case 'TASK':
        case 'VERIFICATION_TASK':
          context.go('/charging-station');
          break;
        case 'BATTERY_SWAP_TASK':
          context.go('/swap-station');
          break;
        case 'CONTRACT':
          context.go('/me/contracts');
          break;
        case 'STATION':
        case 'CHANGE_REQUEST':
          context.go('/charging-station');
          break;
        default:
          // No specific navigation
          break;
      }
    }
  }

  IconData _getCategoryIcon(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.all:
        return Icons.grid_view;
      case NotificationCategory.task:
        return Icons.assignment;
      case NotificationCategory.contract:
        return Icons.description;
      case NotificationCategory.station:
        return Icons.ev_station;
    }
  }
}

/// Single notification list item
class _NotificationListItem extends StatelessWidget {
  final NotificationItem notification;
  final VoidCallback onTap;
  final VoidCallback onMarkRead;

  const _NotificationListItem({
    required this.notification,
    required this.onTap,
    required this.onMarkRead,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoryColor = _getCategoryColor(notification.category);

    return Material(
      color: notification.isRead
          ? Colors.transparent
          : CollabTheme.primaryGreen.withOpacity(0.03),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: categoryColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getTypeIcon(notification.type),
                  color: categoryColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Title
                        Expanded(
                          child: Text(
                            notification.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: notification.isRead
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        // Unread indicator
                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 8),
                            decoration: BoxDecoration(
                              color: CollabTheme.primaryGreen,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Body
                    Text(
                      notification.body,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    // Meta row
                    Row(
                      children: [
                        // Category badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: categoryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            notification.category.displayName,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: categoryColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Timestamp
                        Icon(
                          Icons.schedule,
                          size: 14,
                          color: theme.colorScheme.onSurface.withOpacity(0.4),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatTimestamp(notification.createdAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),

                        const Spacer(),

                        // Mark as read button (if unread)
                        if (!notification.isRead)
                          TextButton(
                            onPressed: onMarkRead,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Mark read',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: CollabTheme.primaryGreen,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Chevron
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurface.withOpacity(0.3),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.all:
        return Colors.grey;
      case NotificationCategory.task:
        return Colors.blue;
      case NotificationCategory.contract:
        return Colors.green;
      case NotificationCategory.station:
        return Colors.orange;
    }
  }

  IconData _getTypeIcon(NotificationType type) {
    switch (type) {
      // TASK
      case NotificationType.taskAssigned:
        return Icons.assignment_ind;
      case NotificationType.taskCheckedIn:
        return Icons.login;
      case NotificationType.taskSubmitted:
        return Icons.check_circle_outline;
      case NotificationType.taskReviewedPass:
        return Icons.verified;
      case NotificationType.taskReviewedFail:
        return Icons.cancel;
      case NotificationType.taskSlaApproaching:
        return Icons.schedule;
      case NotificationType.taskSlaOverdue:
        return Icons.warning;

      // CONTRACT
      case NotificationType.contractApproved:
        return Icons.verified;
      case NotificationType.contractCreated:
        return Icons.add_circle_outline;
      case NotificationType.contractUpdated:
        return Icons.edit;
      case NotificationType.contractTerminated:
        return Icons.cancel;
      case NotificationType.contractExpiring:
        return Icons.schedule;
      case NotificationType.contractExpired:
        return Icons.event_busy;

      // STATION
      case NotificationType.stationIssueReported:
        return Icons.report_problem;
      case NotificationType.stationIssueResolved:
        return Icons.check_circle;
      case NotificationType.stationChangeRequestSubmitted:
        return Icons.send;
      case NotificationType.stationChangeRequestPublished:
        return Icons.publish;

      // SYSTEM
      case NotificationType.systemAnnouncement:
        return Icons.campaign;
    }
  }

  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}

// Extension for page comparison
extension IntExtension on int {
  bool eq(int other) => this == other;
}
