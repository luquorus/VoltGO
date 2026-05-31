import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_ui/shared_ui.dart';
import '../models/verification_task.dart';
import '../services/file_viewer_service.dart';
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
                          'Task ID: ${task.id.length >= 8 ? '${task.id.substring(0, 8)}...' : task.id}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                        if (task.stationServiceTypes.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Chip(
                            avatar: Icon(
                              task.isBatterySwapStation
                                  ? Icons.battery_charging_full
                                  : Icons.ev_station,
                              size: 18,
                            ),
                            label: Text(task.primaryServiceLabel),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
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
                    _buildSection(
                      theme,
                      title: 'Basic information',
                      children: [
                        _buildInfoRow(theme, 'Station ID', task.stationId),
                        if (task.changeRequestId != null)
                          _buildInfoRow(
                            theme,
                            'Change request ID',
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
                          'Created at',
                          _formatDateTime(task.createdAt),
                          icon: Icons.calendar_today,
                        ),
                        if (task.slaDueAt != null)
                          _buildInfoRow(
                            theme,
                            'SLA deadline',
                            _formatDateTime(task.slaDueAt!),
                            icon: Icons.schedule,
                            iconColor: task.slaDueAt!.isBefore(DateTime.now())
                                ? theme.colorScheme.error
                                : null,
                          ),
                        if (task.assignedToEmail != null)
                          _buildInfoRow(
                            theme,
                            'Assignee',
                            task.assignedToEmail!,
                            icon: Icons.person,
                          ),
                      ],
                    ),

                    if (task.checkin != null) ...[
                      const SizedBox(height: 24),
                      _buildSection(
                        theme,
                        title: 'Check-in details',
                        children: [
                          _buildInfoRow(
                            theme,
                            'Location',
                            '${task.checkin!.lat.toStringAsFixed(6)}, ${task.checkin!.lng.toStringAsFixed(6)}',
                            icon: Icons.location_on,
                          ),
                          _buildInfoRow(
                            theme,
                            'Checked in at',
                            _formatDateTime(task.checkin!.checkedInAt),
                            icon: Icons.access_time,
                          ),
                          if (task.checkin!.distanceM != null)
                            _buildInfoRow(
                              theme,
                              'Distance',
                              '${task.checkin!.distanceM} m from station',
                              icon: Icons.straighten,
                            ),
                          if (task.checkin!.deviceNote != null)
                            _buildInfoRow(
                              theme,
                              'Device note',
                              task.checkin!.deviceNote!,
                              icon: Icons.note,
                            ),
                        ],
                      ),
                    ],

                    if (task.evidences.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildEvidenceSection(theme, task.evidences.first),
                    ],

                    if (task.review != null) ...[
                      const SizedBox(height: 24),
                      _buildSection(
                        theme,
                        title: 'Review result',
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

  Widget _buildEvidenceSection(ThemeData theme, Evidence evidence) {
    return _buildSection(
      theme,
      title: 'Evidence',
      children: [
        Consumer(
          builder: (context, ref, child) {
            final imageUrlAsync =
                ref.watch(_evidenceImageUrlProvider(evidence.photoObjectKey));
            return imageUrlAsync.when(
              data: (url) => InkWell(
                onTap: () => _showEvidencePreview(context, url),
                borderRadius: BorderRadius.circular(12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    url,
                    height: 260,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildEvidenceError(theme),
                  ),
                ),
              ),
              loading: () => Container(
                height: 260,
                alignment: Alignment.center,
                child: const CircularProgressIndicator(),
              ),
              error: (error, stackTrace) => _buildEvidenceError(theme),
            );
          },
        ),
        const SizedBox(height: 12),
        _buildInfoRow(
          theme,
          'Submitted at',
          _formatDateTime(evidence.submittedAt),
          icon: Icons.schedule,
        ),
        if (evidence.note != null && evidence.note!.isNotEmpty)
          _buildInfoRow(
            theme,
            'Note',
            evidence.note!,
            icon: Icons.note,
          ),
      ],
    );
  }

  Widget _buildEvidenceError(ThemeData theme) {
    return Container(
      height: 260,
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Could not load evidence photo',
        style: theme.textTheme.bodyMedium,
      ),
    );
  }

  void _showEvidencePreview(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.network(url, fit: BoxFit.contain),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton.filled(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
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

final _evidenceImageUrlProvider = FutureProvider.family<String, String>((ref, objectKey) {
  return ref.watch(fileViewerServiceProvider).getViewUrl(objectKey);
});

