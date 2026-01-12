import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';
import '../providers/task_providers.dart';
import '../models/verification_task.dart';
import '../widgets/main_scaffold.dart';

/// Task List Screen with Filter by Status
class TaskListScreen extends ConsumerStatefulWidget {
  const TaskListScreen({super.key});

  @override
  ConsumerState<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends ConsumerState<TaskListScreen> {
  VerificationTaskStatus? _selectedStatus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return CollabMainScaffold(
      title: 'Tasks',
      child: Column(
        children: [
          // Filter Section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outline.withOpacity(0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.filter_list,
                  size: 20,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
                const SizedBox(width: 8),
                Text(
                  'Filter:',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<VerificationTaskStatus?>(
                      value: _selectedStatus,
                      isExpanded: true,
                      hint: Text(
                        'All Status',
                        style: theme.textTheme.bodyMedium,
                      ),
                      items: [
                        const DropdownMenuItem<VerificationTaskStatus?>(
                          value: null,
                          child: Text('All Status'),
                        ),
                        DropdownMenuItem<VerificationTaskStatus>(
                          value: VerificationTaskStatus.assigned,
                          child: Text(VerificationTaskStatus.assigned.displayName),
                        ),
                        DropdownMenuItem<VerificationTaskStatus>(
                          value: VerificationTaskStatus.checkedIn,
                          child: Text(VerificationTaskStatus.checkedIn.displayName),
                        ),
                        DropdownMenuItem<VerificationTaskStatus>(
                          value: VerificationTaskStatus.submitted,
                          child: Text(VerificationTaskStatus.submitted.displayName),
                        ),
                        DropdownMenuItem<VerificationTaskStatus>(
                          value: VerificationTaskStatus.reviewed,
                          child: Text(VerificationTaskStatus.reviewed.displayName),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedStatus = value;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Task List
          Expanded(
            child: _TaskTab(
              statuses: _selectedStatus != null ? [_selectedStatus!] : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Task Tab Widget
class _TaskTab extends ConsumerWidget {
  final List<VerificationTaskStatus>? statuses;

  const _TaskTab({
    this.statuses,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksByStatusProvider(statuses));

    return tasksAsync.when(
      data: (tasks) {
        if (tasks.isEmpty) {
          return const EmptyState(
            message: 'No tasks found',
            icon: Icons.assignment_outlined,
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(tasksByStatusProvider(statuses));
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              return _TaskCard(task: task);
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => ErrorState(
        message: error.toString(),
        onRetry: () {
          ref.invalidate(tasksByStatusProvider(statuses));
        },
      ),
    );
  }
}

/// Task Card Widget
class _TaskCard extends StatelessWidget {
  final VerificationTask task;

  const _TaskCard({
    required this.task,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUrgent = task.slaDueAt != null &&
        task.slaDueAt!.isBefore(DateTime.now().add(const Duration(days: 1)));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          context.push('/tasks/${task.id}');
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      task.stationName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
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
                          return theme.colorScheme.primary;
                      }
                    },
                  ),
                ],
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
                      'Station ID: ${task.stationId.substring(0, 8)}...',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              if (task.slaDueAt != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 16,
                      color: isUrgent
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'SLA: ${_formatDateTime(task.slaDueAt!)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isUrgent
                            ? theme.colorScheme.error
                            : null,
                      ),
                    ),
                  ],
                ),
              ],
              if (task.checkin != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Checked in: ${_formatDateTime(task.checkin!.checkedInAt)}',
                        style: theme.textTheme.bodySmall,
                      ),
                      if (task.checkin!.distanceM != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          '• ${task.checkin!.distanceM}m away',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.flag,
                    size: 16,
                    color: _getPriorityColor(task.priority),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Priority: ${task.priority}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = dateTime.difference(now);

    if (difference.inDays > 0) {
      return '${difference.inDays}d remaining';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h remaining';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m remaining';
    } else {
      return 'Overdue';
    }
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

