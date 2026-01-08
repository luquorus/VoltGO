import 'package:flutter/material.dart';

/// Task card with status pill, priority, and SLA
class TaskCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget statusPill;
  final int? priority;
  final DateTime? slaDueAt;
  final VoidCallback? onTap;

  const TaskCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.statusPill,
    this.priority,
    this.slaDueAt,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final isOverdue = slaDueAt != null && slaDueAt!.isBefore(now);
    
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.7),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  statusPill,
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  if (priority != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.flag,
                          size: 16,
                          color: _getPriorityColor(priority!),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Priority $priority',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  if (slaDueAt != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 16,
                          color: isOverdue
                              ? theme.colorScheme.error
                              : theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatSla(slaDueAt!, isOverdue),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isOverdue
                                ? theme.colorScheme.error
                                : null,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getPriorityColor(int priority) {
    if (priority >= 8) return Colors.red;
    if (priority >= 5) return Colors.orange;
    return Colors.blue;
  }

  String _formatSla(DateTime slaDueAt, bool isOverdue) {
    final now = DateTime.now();
    final difference = slaDueAt.difference(now);
    
    if (isOverdue) {
      if (difference.inDays.abs() > 0) {
        return 'Overdue ${difference.inDays.abs()}d';
      }
      if (difference.inHours.abs() > 0) {
        return 'Overdue ${difference.inHours.abs()}h';
      }
      return 'Overdue ${difference.inMinutes.abs()}m';
    }
    
    if (difference.inDays > 0) {
      return 'Due in ${difference.inDays}d';
    }
    if (difference.inHours > 0) {
      return 'Due in ${difference.inHours}h';
    }
    if (difference.inMinutes > 0) {
      return 'Due in ${difference.inMinutes}m';
    }
    return 'Due soon';
  }
}

