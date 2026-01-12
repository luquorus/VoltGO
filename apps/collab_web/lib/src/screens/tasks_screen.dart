import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';
import '../widgets/dashboard_shell.dart';
import '../theme/collab_theme.dart';
import '../models/verification_task.dart';
import '../providers/task_providers.dart';
import 'task_detail_screen.dart';

/// Tasks Screen - Main tasks list for collaborator
class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  DateTime? _selectedSlaDate;
  int? _priorityFilter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filters = ref.watch(taskFiltersProvider);
    final tasksAsync = ref.watch(tasksProvider);

    return DashboardShell(
      title: 'Tasks',
      filterSlot: _buildFilterPanel(theme, filters),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats Row
            _buildStatsRow(theme, tasksAsync),
            const SizedBox(height: 24),

            // Tasks Table
            Expanded(
              child: Card(
                margin: EdgeInsets.zero,
                child: tasksAsync.when(
                  data: (page) => _buildTasksTable(theme, page),
                  loading: () => const LoadingState(message: 'Loading tasks...'),
                  error: (error, stack) => ErrorState(
                    message: error.toString(),
                    onRetry: () {
                      ref.invalidate(tasksPageProvider);
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPanel(ThemeData theme, TaskFilters filters) {
    return Row(
      children: [
        // Status Filter
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: theme.colorScheme.outline),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<VerificationTaskStatus?>(
              value: filters.status,
              hint: Text(
                'All Status',
                style: theme.textTheme.bodyMedium,
              ),
              items: [
                const DropdownMenuItem<VerificationTaskStatus?>(
                  value: null,
                  child: Text('All Status'),
                ),
                ...VerificationTaskStatus.values.map((status) =>
                    DropdownMenuItem<VerificationTaskStatus>(
                      value: status,
                      child: Text(status.displayName),
                    )),
              ],
              onChanged: (value) {
              ref.read(taskFiltersProvider.notifier).state =
                  filters.copyWith(status: value, clearStatus: value == null);
              ref.read(tasksCurrentPageProvider.notifier).state = 0;
              },
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Priority Filter
        SizedBox(
          width: 120,
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Priority',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            keyboardType: TextInputType.number,
            onChanged: (value) {
              final priority = value.isEmpty ? null : int.tryParse(value);
              ref.read(taskFiltersProvider.notifier).state =
                  filters.copyWith(priority: priority, clearPriority: priority == null);
              ref.read(tasksCurrentPageProvider.notifier).state = 0;
            },
          ),
        ),
        const SizedBox(width: 12),

        // SLA Due Before Date Picker
        SizedBox(
          width: 180,
          child: OutlinedButton.icon(
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _selectedSlaDate ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (date != null) {
                setState(() => _selectedSlaDate = date);
                ref.read(taskFiltersProvider.notifier).state =
                    filters.copyWith(slaDueBefore: date);
                ref.read(tasksCurrentPageProvider.notifier).state = 0;
              }
            },
            icon: const Icon(Icons.calendar_today, size: 18),
            label: Text(
              _selectedSlaDate != null
                  ? '${_selectedSlaDate!.day}/${_selectedSlaDate!.month}/${_selectedSlaDate!.year}'
                  : 'SLA Due Before',
              style: theme.textTheme.bodySmall,
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
        ),
        if (_selectedSlaDate != null) ...[
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.clear, size: 18),
            onPressed: () {
              setState(() => _selectedSlaDate = null);
              ref.read(taskFiltersProvider.notifier).state =
                  filters.copyWith(clearSlaDueBefore: true);
              ref.read(tasksCurrentPageProvider.notifier).state = 0;
            },
            tooltip: 'Clear date filter',
          ),
        ],
      ],
    );
  }

  Widget _buildStatsRow(ThemeData theme, AsyncValue<PagedResponse<VerificationTask>> tasksAsync) {
    int totalTasks = 0;
    int pendingTasks = 0;
    int completedTasks = 0;
    int overdueTasks = 0;

    tasksAsync.whenData((page) {
      totalTasks = page.totalElements;
      final now = DateTime.now();
      for (final task in page.content) {
        if (task.status == VerificationTaskStatus.reviewed) {
          completedTasks++;
        } else if (task.status != VerificationTaskStatus.reviewed) {
          pendingTasks++;
        }
        if (task.slaDueAt != null && task.slaDueAt!.isBefore(now) &&
            task.status != VerificationTaskStatus.reviewed) {
          overdueTasks++;
        }
      }
    });

    return Row(
      children: [
        _buildStatCard(
          theme,
          icon: Icons.assignment,
          label: 'Total Tasks',
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
          icon: Icons.check_circle,
          label: 'Completed',
          value: completedTasks.toString(),
          color: Colors.green,
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          theme,
          icon: Icons.warning,
          label: 'Overdue',
          value: overdueTasks.toString(),
          color: Colors.red,
        ),
      ],
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
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
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
                    style: theme.textTheme.headlineMedium?.copyWith(
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

  Widget _buildTasksTable(ThemeData theme, PagedResponse<VerificationTask> page) {
    if (page.content.isEmpty) {
      return EmptyState(
        icon: Icons.assignment_outlined,
        message: 'No tasks found',
        action: OutlinedButton.icon(
          onPressed: () {
            ref.invalidate(tasksPageProvider);
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
        ),
      );
    }

    return Column(
      children: [
        // Table Header
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
              Expanded(
                flex: 3,
                child: Text(
                  'Station Name',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Status',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  'Priority',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'SLA Due',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 48), // Action column
            ],
          ),
        ),

        // Table Body
        Expanded(
          child: ListView.separated(
            itemCount: page.content.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: theme.colorScheme.outline.withOpacity(0.1),
            ),
            itemBuilder: (context, index) {
              final task = page.content[index];
              return _buildTaskRow(theme, task);
            },
          ),
        ),

        // Pagination
        _buildPagination(theme, page),
      ],
    );
  }

  Widget _buildTaskRow(ThemeData theme, VerificationTask task) {
    final now = DateTime.now();
    final isOverdue = task.slaDueAt != null &&
        task.slaDueAt!.isBefore(now) &&
        task.status != VerificationTaskStatus.reviewed;

    return InkWell(
      onTap: () {
        // Open detail drawer
        showDialog(
          context: context,
          builder: (context) => TaskDetailDialog(task: task),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
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
                    'ID: ${task.stationId.substring(0, 8)}...',
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
                              color: isOverdue
                                  ? theme.colorScheme.error
                                  : null,
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
                  builder: (context) => TaskDetailDialog(task: task),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPagination(ThemeData theme, PagedResponse<VerificationTask> page) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing ${page.content.length} of ${page.totalElements} tasks',
            style: theme.textTheme.bodySmall,
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.first_page),
                onPressed: page.first
                    ? null
                    : () {
                        ref.read(tasksCurrentPageProvider.notifier).state = 0;
                      },
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: page.first
                    ? null
                    : () {
                        ref.read(tasksCurrentPageProvider.notifier).state =
                            page.page - 1;
                      },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Page ${page.page + 1} of ${page.totalPages}',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: page.last
                    ? null
                    : () {
                        ref.read(tasksCurrentPageProvider.notifier).state =
                            page.page + 1;
                      },
              ),
              IconButton(
                icon: const Icon(Icons.last_page),
                onPressed: page.last
                    ? null
                    : () {
                        ref.read(tasksCurrentPageProvider.notifier).state =
                            page.totalPages - 1;
                      },
              ),
            ],
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
