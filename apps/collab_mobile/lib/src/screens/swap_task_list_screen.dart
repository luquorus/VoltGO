import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';
import '../providers/battery_swap_task_providers.dart';
import '../models/verification_task.dart' show VerificationTaskStatus;
import '../models/battery_swap_verification_task.dart';
import '../widgets/main_scaffold.dart';

/// Swap Task List Screen with Filter by Status
class SwapTaskListScreen extends ConsumerStatefulWidget {
  const SwapTaskListScreen({super.key});

  @override
  ConsumerState<SwapTaskListScreen> createState() => _SwapTaskListScreenState();
}

class _SwapTaskListScreenState extends ConsumerState<SwapTaskListScreen> {
  VerificationTaskStatus? _selectedStatus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CollabMainScaffold(
      title: 'Swap Station Verification Tasks',
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
                        'All statuses',
                        style: theme.textTheme.bodyMedium,
                      ),
                      items: [
                        const DropdownMenuItem<VerificationTaskStatus?>(
                          value: null,
                          child: Text('All statuses'),
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
            child: _SwapTaskTab(
              statuses: _selectedStatus != null ? [_selectedStatus!] : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Swap Task Tab Widget
class _SwapTaskTab extends ConsumerWidget {
  final List<VerificationTaskStatus>? statuses;

  const _SwapTaskTab({
    this.statuses,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(swapTasksProvider);

    return tasksAsync.when(
      data: (tasks) {
        // Apply filter
        final filteredTasks = statuses != null && statuses!.isNotEmpty
            ? tasks.where((t) => statuses!.contains(t.status)).toList()
            : tasks;

        if (filteredTasks.isEmpty) {
          return const EmptyState(
            title: 'No swap station tasks',
            message:
                'You have no swap station verification tasks assigned.',
            icon: Icons.battery_charging_full_outlined,
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(swapTasksProvider);
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredTasks.length,
            itemBuilder: (context, index) {
              final task = filteredTasks[index];
              return _SwapTaskCard(task: task);
            },
          ),
        );
      },
      loading: () => const SkeletonList(count: 4),
      error: (error, stack) => ErrorState(
        message: formatApiError(error),
        code: extractErrorCode(error),
        traceId: extractTraceId(error),
        onRetry: () {
          ref.invalidate(swapTasksProvider);
        },
      ),
    );
  }
}

/// Swap Task Card Widget
class _SwapTaskCard extends StatelessWidget {
  final BatterySwapVerificationTask task;

  const _SwapTaskCard({
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
          context.push('/swap-station/${task.id}');
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.battery_charging_full,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.stationName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Station ID: ${task.stationId.length >= 8 ? task.stationId.substring(0, 8) : task.stationId}...',
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
                          return theme.colorScheme.primary;
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (task.slaDueAt != null) ...[
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
                      'SLA due: ${_formatDateTime(task.slaDueAt!)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isUrgent
                            ? theme.colorScheme.error
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
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
                  const Spacer(),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: theme.colorScheme.onSurface.withOpacity(0.4),
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
      return '${difference.inDays} days left';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours left';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes left';
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
