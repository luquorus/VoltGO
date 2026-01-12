import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_ui/shared_ui.dart';
import '../providers/task_providers.dart';
import '../models/verification_task.dart';
import '../widgets/main_scaffold.dart';
import '../widgets/evidence_upload_stepper.dart';

/// Task Detail Screen with GPS Check-in
class TaskDetailScreen extends ConsumerStatefulWidget {
  final String taskId;

  const TaskDetailScreen({
    super.key,
    required this.taskId,
  });

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  bool _isCheckingIn = false;

  @override
  Widget build(BuildContext context) {
    final taskAsync = ref.watch(taskDetailProvider(widget.taskId));

    return CollabMainScaffold(
      title: 'Task Details',
      showBottomNav: false,
      child: taskAsync.when(
        data: (task) => _buildTaskDetail(context, task),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => ErrorState(
          message: error.toString(),
          onRetry: () {
            ref.invalidate(taskDetailProvider(widget.taskId));
          },
        ),
      ),
    );
  }

  Widget _buildTaskDetail(BuildContext context, VerificationTask task) {
    final theme = Theme.of(context);
    final canCheckIn = task.status == VerificationTaskStatus.assigned;
    final canSubmitEvidence = task.status == VerificationTaskStatus.checkedIn;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Station Info Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.stationName,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 16,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Station ID: ${task.stationId}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
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
                          return theme.colorScheme.primary;
                      }
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Task Info Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Task Information',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  _InfoRow(
                    icon: Icons.flag,
                    label: 'Priority',
                    value: '${task.priority}',
                    color: _getPriorityColor(task.priority),
                  ),
                  if (task.slaDueAt != null) ...[
                    const SizedBox(height: 12),
                    _InfoRow(
                      icon: Icons.schedule,
                      label: 'SLA Due',
                      value: _formatDateTime(task.slaDueAt!),
                      color: task.slaDueAt!.isBefore(DateTime.now())
                          ? theme.colorScheme.error
                          : null,
                    ),
                  ],
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.calendar_today,
                    label: 'Created',
                    value: _formatFullDateTime(task.createdAt),
                  ),
                ],
              ),
            ),
          ),

          // Check-in Card
          if (task.checkin != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Check-in Information',
                          style: theme.textTheme.titleLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _InfoRow(
                      icon: Icons.location_on,
                      label: 'Location',
                      value: '${task.checkin!.lat.toStringAsFixed(6)}, ${task.checkin!.lng.toStringAsFixed(6)}',
                    ),
                    const SizedBox(height: 12),
                    _InfoRow(
                      icon: Icons.access_time,
                      label: 'Checked in at',
                      value: _formatFullDateTime(task.checkin!.checkedInAt),
                    ),
                    if (task.checkin!.distanceM != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.straighten,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Distance from station: ',
                              style: theme.textTheme.bodyMedium,
                            ),
                            Text(
                              '${task.checkin!.distanceM}m',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (task.checkin!.deviceNote != null) ...[
                      const SizedBox(height: 12),
                      _InfoRow(
                        icon: Icons.note,
                        label: 'Note',
                        value: task.checkin!.deviceNote!,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],

          // Evidence Upload Section
          if (canSubmitEvidence) ...[
            const SizedBox(height: 16),
            EvidenceUploadStepper(
              task: task,
              onSuccess: () {
                // Task will be refreshed automatically
              },
            ),
          ],

          // Evidences List
          if (task.evidences.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.photo_library,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Submitted Evidences',
                          style: theme.textTheme.titleLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ...task.evidences.map((evidence) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.image,
                                  size: 20,
                                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Photo: ${evidence.photoObjectKey.split('/').last}',
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                      if (evidence.note != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          evidence.note!,
                                          style: theme.textTheme.bodySmall,
                                        ),
                                      ],
                                      const SizedBox(height: 4),
                                      Text(
                                        'Submitted: ${_formatFullDateTime(evidence.submittedAt)}',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Check-in Button
          if (canCheckIn)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isCheckingIn ? null : () => _handleCheckIn(context, task),
                icon: _isCheckingIn
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.location_on),
                label: Text(_isCheckingIn ? 'Checking in...' : 'Check-in at Location'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _handleCheckIn(BuildContext context, VerificationTask task) async {
    setState(() {
      _isCheckingIn = true;
    });

    try {
      // Request location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            AppToast.showError(context, 'Location permission denied');
          }
          setState(() {
            _isCheckingIn = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          AppToast.showError(
            context,
            'Location permission permanently denied. Please enable it in settings.',
          );
        }
        setState(() {
          _isCheckingIn = false;
        });
        return;
      }

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          AppToast.showError(context, 'Location services are disabled');
        }
        setState(() {
          _isCheckingIn = false;
        });
        return;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Perform check-in
      final checkInParams = CheckInParams(
        taskId: task.id,
        lat: position.latitude,
        lng: position.longitude,
      );

      await ref.read(checkInProvider(checkInParams));

      // Refresh task detail
      ref.invalidate(taskDetailProvider(widget.taskId));
      ref.invalidate(tasksByStatusProvider(null));

      if (mounted) {
        AppToast.showSuccess(context, 'Check-in successful!');
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, 'Failed to check-in: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingIn = false;
        });
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = dateTime.difference(now);

    if (difference.inDays > 0) {
      return '${difference.inDays} days remaining';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours remaining';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes remaining';
    } else {
      return 'Overdue';
    }
  }

  String _formatFullDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Color _getPriorityColor(int priority) {
    switch (priority) {
      case 5:
        return Colors.red;
      case 4:
        return Colors.orange;
      case 3:
        return Colors.yellow.shade700;
      case 2:
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}

/// Info Row Widget
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: color ?? theme.colorScheme.onSurface.withOpacity(0.6),
        ),
        const SizedBox(width: 12),
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
                  color: color,
                  fontWeight: color != null ? FontWeight.bold : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

