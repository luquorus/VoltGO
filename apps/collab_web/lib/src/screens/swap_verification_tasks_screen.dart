import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_ui/shared_ui.dart';
import '../widgets/dashboard_shell.dart';
import '../theme/collab_theme.dart';
import '../models/battery_swap_verification_task.dart';
import '../providers/battery_swap_task_providers.dart';
import 'swap_verification_task_detail_screen.dart';

/// Swap Verification Tasks Screen - Lists battery swap verification tasks
class SwapVerificationTasksScreen extends ConsumerStatefulWidget {
  const SwapVerificationTasksScreen({super.key});

  @override
  ConsumerState<SwapVerificationTasksScreen> createState() =>
      _SwapVerificationTasksScreenState();
}

class _SwapVerificationTasksScreenState
    extends ConsumerState<SwapVerificationTasksScreen> {
  VerificationTaskStatus? _selectedStatus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DashboardShell(
      title: 'Swap Station',
      filterSlot: _buildFilterPanel(theme),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatsRow(theme),
            const SizedBox(height: 24),
            Expanded(
              child: Card(
                margin: EdgeInsets.zero,
                child: _buildTasksList(theme),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPanel(ThemeData theme) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: theme.colorScheme.outline),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<VerificationTaskStatus?>(
              value: _selectedStatus,
              hint: Text(
                'All statuses',
                style: theme.textTheme.bodyMedium,
              ),
              items: [
                const DropdownMenuItem<VerificationTaskStatus?>(
                  value: null,
                  child: Text('All statuses'),
                ),
                ...VerificationTaskStatus.values.map((status) =>
                    DropdownMenuItem<VerificationTaskStatus>(
                      value: status,
                      child: Text(status.displayName),
                    )),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedStatus = value;
                });
              },
            ),
          ),
        ),
        const SizedBox(width: 12),
        if (_selectedStatus != null)
          IconButton(
            icon: const Icon(Icons.clear, size: 18),
            onPressed: () {
              setState(() => _selectedStatus = null);
            },
            tooltip: 'Clear filter',
          ),
      ],
    );
  }

  Widget _buildStatsRow(ThemeData theme) {
    final tasksAsync = ref.watch(swapTasksProvider);

    return tasksAsync.when(
      data: (tasks) {
        int totalTasks = tasks.length;
        int pendingTasks = 0;
        int completedTasks = 0;
        int inProgressTasks = 0;

        final now = DateTime.now();
        for (final task in tasks) {
          if (task.status == VerificationTaskStatus.reviewed) {
            completedTasks++;
          } else if (task.status == VerificationTaskStatus.checkedIn ||
              task.status == VerificationTaskStatus.submitted) {
            inProgressTasks++;
          } else if (task.status == VerificationTaskStatus.assigned) {
            pendingTasks++;
          }
        }

        return Row(
          children: [
            _buildStatCard(
              theme,
              icon: Icons.battery_charging_full,
              label: 'Total tasks',
              value: totalTasks.toString(),
              color: CollabTheme.primaryGreen,
            ),
            const SizedBox(width: 16),
            _buildStatCard(
              theme,
              icon: Icons.pending_actions,
              label: 'Pending',
              value: pendingTasks.toString(),
              color: Colors.orange,
            ),
            const SizedBox(width: 16),
            _buildStatCard(
              theme,
              icon: Icons.play_circle,
              label: 'In progress',
              value: inProgressTasks.toString(),
              color: Colors.blue,
            ),
            const SizedBox(width: 16),
            _buildStatCard(
              theme,
              icon: Icons.check_circle,
              label: 'Completed',
              value: completedTasks.toString(),
              color: Colors.green,
            ),
          ],
        );
      },
      loading: () => Row(
        children: [
          _buildStatCard(theme,
              icon: Icons.battery_charging_full,
              label: 'Total tasks',
              value: '--',
              color: CollabTheme.primaryGreen),
          const SizedBox(width: 16),
          _buildStatCard(theme,
              icon: Icons.pending_actions,
              label: 'Pending',
              value: '--',
              color: Colors.orange),
          const SizedBox(width: 16),
          _buildStatCard(theme,
              icon: Icons.play_circle,
              label: 'In progress',
              value: '--',
              color: Colors.blue),
          const SizedBox(width: 16),
          _buildStatCard(theme,
              icon: Icons.check_circle,
              label: 'Completed',
              value: '--',
              color: Colors.green),
        ],
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildStatCard(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTasksList(ThemeData theme) {
    final tasksAsync = ref.watch(swapTasksProvider);

    return tasksAsync.when(
      data: (tasks) {
        final filteredTasks = _selectedStatus != null
            ? tasks.where((t) => t.status == _selectedStatus).toList()
            : tasks;

        if (filteredTasks.isEmpty) {
          return EmptyState(
            icon: Icons.battery_charging_full_outlined,
            title: 'No swap station tasks',
            message: _selectedStatus != null
                ? 'No tasks match the selected status.'
                : 'You have no swap station verification tasks assigned.',
            action: OutlinedButton.icon(
              onPressed: () {
                ref.invalidate(swapTasksProvider);
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(swapTasksProvider);
          },
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: filteredTasks.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: theme.colorScheme.outline.withOpacity(0.1),
            ),
            itemBuilder: (context, index) {
              final task = filteredTasks[index];
              return _buildTaskRow(theme, task);
            },
          ),
        );
      },
      loading: () => const LoadingState(message: 'Loading tasks...'),
      error: (error, stack) => ErrorState(
        title: 'Could not load list',
        message: formatApiError(error),
        code: extractErrorCode(error),
        traceId: extractTraceId(error),
        onRetry: () {
          ref.invalidate(swapTasksProvider);
        },
      ),
    );
  }

  Widget _buildTaskRow(ThemeData theme, BatterySwapVerificationTask task) {
    final now = DateTime.now();
    final isOverdue = task.slaDueAt != null &&
        task.slaDueAt!.isBefore(now) &&
        task.status != VerificationTaskStatus.reviewed;

    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) =>
              SwapVerificationTaskDetailDialog(task: task),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: CollabTheme.primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.battery_charging_full,
                color: CollabTheme.primaryGreen,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.stationName,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ID: ${task.stationId.length >= 8 ? '${task.stationId.substring(0, 8)}...' : task.stationId}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: StatusPill(
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
            ),
            Expanded(
              flex: 1,
              child: Row(
                children: [
                  Icon(
                    Icons.flag,
                    size: 16,
                    color: _getPriorityColor(task.priority),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    task.priority.toString(),
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: task.slaDueAt != null
                  ? Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 16,
                          color: isOverdue
                              ? theme.colorScheme.error
                              : theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _formatSla(task.slaDueAt!, isOverdue),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color:
                                  isOverdue ? theme.colorScheme.error : null,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Text(
                      'No SLA',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.4),
                      ),
                    ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) =>
                      SwapVerificationTaskDetailDialog(task: task),
                );
              },
            ),
          ],
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
        return 'Overdue by ${difference.inDays.abs()} days';
      }
      if (difference.inHours.abs() > 0) {
        return 'Overdue by ${difference.inHours.abs()} hours';
      }
      return 'Overdue';
    }

    if (difference.inDays > 0) {
      return '${difference.inDays} days left';
    }
    if (difference.inHours > 0) {
      return '${difference.inHours} hours left';
    }
    return 'Due soon';
  }
}
