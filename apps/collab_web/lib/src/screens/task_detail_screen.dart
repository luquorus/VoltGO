import 'package:flutter/material.dart';
import 'package:shared_ui/shared_ui.dart';
import '../models/verification_task.dart';
import '../theme/collab_theme.dart';

/// Task Detail Dialog - Shows full task details
/// Since OpenAPI doesn't have GET /api/collab/web/tasks/{id},
/// we use the task from the list content
class TaskDetailDialog extends StatelessWidget {
  final VerificationTask task;

  const TaskDetailDialog({
    super.key,
    required this.task,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 100 : 24,
        vertical: 40,
      ),
      child: Container(
        width: isDesktop ? 800 : double.infinity,
        constraints: const BoxConstraints(maxHeight: 800),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.stationName,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Task ID: ${task.id.substring(0, 8)}...',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusPill(
                    label: task.status.displayName,
                    colorMapper: (label) {
                      switch (task.status) {
                        case VerificationTaskStatus.assigned:
                          return Colors.orange;
                        case VerificationTaskStatus.checkedIn:
                          return Colors.blue;
                        case VerificationTaskStatus.submitted:
                          return Colors.purple;
                        case VerificationTaskStatus.reviewed:
                          return Colors.green;
                        default:
                          return CollabTheme.primaryGreen;
                      }
                    },
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Basic Info
                    _buildSection(
                      theme,
                      title: 'Basic Information',
                      children: [
                        _buildInfoRow(theme, 'Station ID', task.stationId),
                        if (task.changeRequestId != null)
                          _buildInfoRow(
                            theme,
                            'Change Request ID',
                            task.changeRequestId!,
                          ),
                        _buildInfoRow(
                          theme,
                          'Priority',
                          '${task.priority}',
                          icon: Icons.flag,
                          iconColor: _getPriorityColor(task.priority),
                        ),
                        _buildInfoRow(
                          theme,
                          'Status',
                          task.status.displayName,
                        ),
                        _buildInfoRow(
                          theme,
                          'Created At',
                          _formatDateTime(task.createdAt),
                          icon: Icons.calendar_today,
                        ),
                        if (task.slaDueAt != null)
                          _buildInfoRow(
                            theme,
                            'SLA Due At',
                            _formatDateTime(task.slaDueAt!),
                            icon: Icons.schedule,
                            iconColor: task.slaDueAt!.isBefore(DateTime.now())
                                ? theme.colorScheme.error
                                : null,
                          ),
                        if (task.assignedToEmail != null)
                          _buildInfoRow(
                            theme,
                            'Assigned To',
                            task.assignedToEmail!,
                            icon: Icons.person,
                          ),
                      ],
                    ),

                    // Check-in Info
                    if (task.checkin != null) ...[
                      const SizedBox(height: 24),
                      _buildSection(
                        theme,
                        title: 'Check-in Information',
                        children: [
                          _buildInfoRow(
                            theme,
                            'Location',
                            '${task.checkin!.lat.toStringAsFixed(6)}, ${task.checkin!.lng.toStringAsFixed(6)}',
                            icon: Icons.location_on,
                          ),
                          _buildInfoRow(
                            theme,
                            'Checked In At',
                            _formatDateTime(task.checkin!.checkedInAt),
                            icon: Icons.access_time,
                          ),
                          if (task.checkin!.distanceM != null)
                            _buildInfoRow(
                              theme,
                              'Distance',
                              '${task.checkin!.distanceM}m from station',
                              icon: Icons.straighten,
                            ),
                          if (task.checkin!.deviceNote != null)
                            _buildInfoRow(
                              theme,
                              'Device Note',
                              task.checkin!.deviceNote!,
                              icon: Icons.note,
                            ),
                        ],
                      ),
                    ],


                    // Review
                    if (task.review != null) ...[
                      const SizedBox(height: 24),
                      _buildSection(
                        theme,
                        title: 'Review Result',
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: task.review!.isPass
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: task.review!.isPass
                                    ? Colors.green
                                    : Colors.red,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      task.review!.isPass
                                          ? Icons.check_circle
                                          : Icons.cancel,
                                      color: task.review!.isPass
                                          ? Colors.green
                                          : Colors.red,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      task.review!.result,
                                      style: theme.textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: task.review!.isPass
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                                if (task.review!.adminNote != null) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    task.review!.adminNote!,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.schedule,
                                      size: 16,
                                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Reviewed: ${_formatDateTime(task.review!.reviewedAt)}',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    ThemeData theme, {
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow(
    ThemeData theme,
    String label,
    String value, {
    IconData? icon,
    Color? iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 20,
              color: iconColor ?? theme.colorScheme.onSurface.withOpacity(0.5),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: iconColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getPriorityColor(int priority) {
    if (priority >= 8) return Colors.red;
    if (priority >= 5) return Colors.orange;
    return Colors.blue;
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

