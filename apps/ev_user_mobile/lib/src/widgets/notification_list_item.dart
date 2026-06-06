import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/notification_model.dart';

/// Notification list item widget for EV user mobile app
class NotificationListItem extends StatelessWidget {
  final NotificationItem notification;
  final VoidCallback? onTap;
  final VoidCallback? onMarkAsRead;

  const NotificationListItem({
    super.key,
    required this.notification,
    this.onTap,
    this.onMarkAsRead,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoryColor = _getCategoryColor(notification.category);

    return Dismissible(
      key: Key(notification.id),
      direction: notification.isRead
          ? DismissDirection.none
          : DismissDirection.startToEnd,
      background: Container(
        color: Colors.green,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(Icons.check, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        if (!notification.isRead && onMarkAsRead != null) {
          onMarkAsRead!();
        }
        return false; // Don't actually dismiss, just mark as read
      },
      child: Material(
        color: notification.isRead
            ? Colors.transparent
            : theme.colorScheme.primary.withOpacity(0.05),
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outline.withOpacity(0.1),
                ),
              ),
            ),
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
                const SizedBox(width: 12),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Unread indicator
                          if (!notification.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
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
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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

  IconData _getTypeIcon(NotificationType type) {
    switch (type) {
      // BOOKING
      case NotificationType.BOOKING_CONFIRMED:
        return Icons.check_circle;
      case NotificationType.BOOKING_EXPIRED:
        return Icons.timer_off;
      case NotificationType.BOOKING_CANCELLED:
        return Icons.cancel;
      case NotificationType.BOOKING_REMINDER:
        return Icons.alarm;
      case NotificationType.PAYMENT_SUCCESS:
        return Icons.payments;
      case NotificationType.PAYMENT_FAILED:
        return Icons.error;

      // BATTERY_SWAP
      case NotificationType.SWAP_RESERVED:
        return Icons.book_online;
      case NotificationType.SWAP_ARRIVED:
        return Icons.location_on;
      case NotificationType.SWAP_CODE_GENERATED:
        return Icons.qr_code;
      case NotificationType.SWAP_COMPLETED:
        return Icons.battery_charging_full;
      case NotificationType.SWAP_REMINDER:
        return Icons.alarm;
      case NotificationType.SWAP_EXPIRED:
        return Icons.timer_off;

      // STATION
      case NotificationType.ISSUE_REPORTED:
        return Icons.report_problem;
      case NotificationType.ISSUE_ACKNOWLEDGED:
        return Icons.done_all;
      case NotificationType.ISSUE_RESOLVED:
        return Icons.check_circle;
      case NotificationType.CR_SUBMITTED:
        return Icons.send;
      case NotificationType.CR_APPROVED:
        return Icons.thumb_up;
      case NotificationType.CR_REJECTED:
        return Icons.thumb_down;
      case NotificationType.CR_PUBLISHED:
        return Icons.publish;
      case NotificationType.STATION_TRUST_LOW:
        return Icons.warning;

      // SYSTEM
      case NotificationType.SYSTEM_ANNOUNCEMENT:
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

/// Helper function to navigate based on notification reference type
void navigateFromNotification(BuildContext context, NotificationItem notification) {
  final referenceType = notification.referenceType?.toUpperCase();
  final referenceId = notification.referenceId;

  if (referenceType == null || referenceId == null) return;

  switch (referenceType) {
    case 'BOOKING':
      context.push('/bookings/$referenceId');
      break;
    case 'STATION':
      context.push('/stations/$referenceId');
      break;
    case 'CHANGE_REQUEST':
      context.push('/change-requests/$referenceId');
      break;
    case 'BATTERY_SWAP_RESERVATION':
      context.push('/battery-swap/reservations?reservationId=$referenceId');
      break;
    case 'ISSUE':
      context.push('/issues/mine');
      break;
    default:
      // No specific navigation for this type
      break;
  }
}
