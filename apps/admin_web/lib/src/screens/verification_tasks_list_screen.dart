import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';
import '../models/admin_verification_task.dart';
import '../providers/verification_task_providers.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_scaffold.dart';
import 'create_task_modal.dart';
import 'assign_task_modal.dart';

/// Verification Tasks List Screen
class VerificationTasksListScreen extends ConsumerStatefulWidget {
  const VerificationTasksListScreen({super.key});

  @override
  ConsumerState<VerificationTasksListScreen> createState() =>
      _VerificationTasksListScreenState();
}

class _VerificationTasksListScreenState
    extends ConsumerState<VerificationTasksListScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filters = ref.watch(verificationTaskFiltersProvider);
    final tasksPageAsync = ref.watch(verificationTasksPageProvider);

    return AdminScaffold(
      title: 'Verification Tasks',
      actions: [
        ElevatedButton.icon(
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => const CreateTaskModal(),
            ).then((_) {
              ref.invalidate(verificationTasksPageProvider);
            });
          },
          icon: const Icon(Icons.add),
          label: const Text('Create Task'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AdminTheme.primaryTeal,
            foregroundColor: Colors.white,
          ),
        ),
      ],
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filters
            _buildFilterPanel(theme, filters),
            const SizedBox(height: 24),

            // Stats Row
            _buildStatsRow(theme, tasksPageAsync),
            const SizedBox(height: 24),

            // Tasks Table
            Expanded(
              child: Card(
                margin: EdgeInsets.zero,
                child: tasksPageAsync.when(
                  data: (page) => _buildTasksTable(theme, page),
                  loading: () => LoadingState(
                      message: 'Loading verification tasks...'),
                  error: (error, stack) => ErrorState(
                    message: error.toString(),
                    onRetry: () {
                      ref.invalidate(verificationTasksPageProvider);
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

  Widget _buildFilterPanel(
      ThemeData theme, VerificationTaskFilters filters) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Text(
            'Filter by Status:',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
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
                  ref.read(verificationTaskFiltersProvider.notifier).state =
                      filters.copyWith(status: value, clearStatus: value == null);
                  ref.read(verificationTasksCurrentPageProvider.notifier).state = 0;
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(
      ThemeData theme, AsyncValue<PagedVerificationTasks> tasksPageAsync) {
    int total = 0;
    int open = 0;
    int assigned = 0;
    int submitted = 0;
    int reviewed = 0;

    tasksPageAsync.whenData((page) {
      total = page.totalElements;
      for (final task in page.content) {
        switch (task.status) {
          case VerificationTaskStatus.open:
            open++;
            break;
          case VerificationTaskStatus.assigned:
          case VerificationTaskStatus.checkedIn:
            assigned++;
            break;
          case VerificationTaskStatus.submitted:
            submitted++;
            break;
          case VerificationTaskStatus.reviewed:
            reviewed++;
            break;
        }
      }
    });

    return Row(
      children: [
        _buildStatCard(theme, icon: Icons.assignment, label: 'Total', value: total.toString(), color: AdminTheme.primaryTeal),
        const SizedBox(width: 16),
        _buildStatCard(theme, icon: Icons.fiber_new, label: 'Open', value: open.toString(), color: Colors.blue),
        const SizedBox(width: 16),
        _buildStatCard(theme, icon: Icons.person, label: 'Assigned', value: assigned.toString(), color: Colors.orange),
        const SizedBox(width: 16),
        _buildStatCard(theme, icon: Icons.pending, label: 'Submitted', value: submitted.toString(), color: Colors.purple),
        const SizedBox(width: 16),
        _buildStatCard(theme, icon: Icons.check_circle, label: 'Reviewed', value: reviewed.toString(), color: Colors.green),
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

  Widget _buildTasksTable(ThemeData theme, PagedVerificationTasks page) {
    if (page.content.isEmpty) {
      return EmptyState(
        icon: Icons.assignment_outlined,
        message: 'No verification tasks found',
        action: OutlinedButton.icon(
          onPressed: () {
            ref.invalidate(verificationTasksPageProvider);
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
            color: AdminTheme.surfaceLight,
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
              Expanded(
                flex: 2,
                child: Text(
                  'Assigned To',
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

  Widget _buildTaskRow(ThemeData theme, AdminVerificationTask task) {
    final now = DateTime.now();
    final isOverdue = task.slaDueAt != null &&
        task.slaDueAt!.isBefore(now) &&
        task.status != VerificationTaskStatus.reviewed;

    return InkWell(
      onTap: () {
        context.push('/verification-tasks/${task.id}');
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
                    case VerificationTaskStatus.open:
                      return Colors.blue;
                    case VerificationTaskStatus.assigned:
                      return Colors.orange;
                    case VerificationTaskStatus.checkedIn:
                      return Colors.purple;
                    case VerificationTaskStatus.submitted:
                      return Colors.purple;
                    case VerificationTaskStatus.reviewed:
                      return Colors.green;
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
            Expanded(
              flex: 2,
              child: Text(
                task.assignedToEmail ?? 'Unassigned',
                style: theme.textTheme.bodySmall,
              ),
            ),
            if (task.canAssign)
              IconButton(
                icon: const Icon(Icons.person_add),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AssignTaskModal(taskId: task.id),
                  ).then((_) {
                    ref.invalidate(verificationTasksPageProvider);
                  });
                },
                tooltip: 'Assign task',
              )
            else
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  context.push('/verification-tasks/${task.id}');
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPagination(ThemeData theme, PagedVerificationTasks page) {
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
                        ref.read(verificationTasksCurrentPageProvider.notifier).state = 0;
                      },
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: page.first
                    ? null
                    : () {
                        ref.read(verificationTasksCurrentPageProvider.notifier).state = page.page - 1;
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
                        ref.read(verificationTasksCurrentPageProvider.notifier).state = page.page + 1;
                      },
              ),
              IconButton(
                icon: const Icon(Icons.last_page),
                onPressed: page.last
                    ? null
                    : () {
                        ref.read(verificationTasksCurrentPageProvider.notifier).state = page.totalPages - 1;
                      },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getPriorityColor(int priority) {
    if (priority >= 5) return Colors.red;
    if (priority >= 4) return Colors.orange;
    if (priority >= 3) return Colors.yellow;
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

