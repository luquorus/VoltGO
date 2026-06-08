import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';
import '../providers/dashboard_provider.dart';
import '../providers/task_providers.dart';
import '../providers/battery_swap_task_providers.dart';
import '../models/verification_task.dart';
import '../models/battery_swap_verification_task.dart' show BatterySwapVerificationTask;
import '../widgets/main_scaffold.dart';

/// Dashboard Overview Screen - shows KPI summary and recent activity
class DashboardOverviewScreen extends ConsumerStatefulWidget {
  const DashboardOverviewScreen({super.key});

  @override
  ConsumerState<DashboardOverviewScreen> createState() =>
      _DashboardOverviewScreenState();
}

class _DashboardOverviewScreenState
    extends ConsumerState<DashboardOverviewScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(dashboardKpiProvider.notifier).loadKpi();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CollabMainScaffold(
      title: 'Dashboard',
      child: RefreshIndicator(
        onRefresh: () async {
          ref.read(dashboardKpiProvider.notifier).loadKpi();
        },
        child: ListView(
          shrinkWrap: true,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            // Welcome card
            _WelcomeCard(),
            const SizedBox(height: 16),

            // KPI Summary Section
            Text(
              'Performance Overview',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const _KpiSection(),
            const SizedBox(height: 24),

            // Quick Actions
            Text(
              'Quick Actions',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _QuickActionsSection(),
            const SizedBox(height: 24),

            // Recent Charging Tasks
            Text(
              'Charging Station Tasks',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _RecentTasksSection(taskType: TaskType.charging),
            const SizedBox(height: 24),

            // Recent Swap Tasks
            Text(
              'Battery Swap Tasks',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _RecentTasksSection(taskType: TaskType.swap),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

enum TaskType { charging, swap }

class _WelcomeCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt, color: Colors.white, size: 28),
              const SizedBox(width: 8),
              Text(
                'VoltGo',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Welcome back, Collaborator!',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Here\'s your work summary for this month.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withOpacity(0.85),
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiSection extends ConsumerWidget {
  const _KpiSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpiState = ref.watch(dashboardKpiProvider);
    final assignedCountAsync = ref.watch(assignedTasksCountProvider);

    if (kpiState.isLoading) {
      return const SkeletonList(count: 4);
    }

    if (kpiState.error != null) {
      return _ErrorCard(
        message: 'Could not load KPI data.',
        onRetry: () {},
      );
    }

    final assignedCount = assignedCountAsync.when(
      data: (count) => count,
      loading: () => 0,
      error: (_, __) => 0,
    );

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _KpiCard(label: 'Assigned', value: assignedCount.toString(), icon: Icons.assignment_ind_outlined, color: Colors.blue)),
            const SizedBox(width: 8),
            Expanded(child: _KpiCard(label: 'Passed', value: kpiState.passCount.toString(), icon: Icons.check_circle, color: Colors.green)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _KpiCard(label: 'Failed', value: kpiState.failCount.toString(), icon: Icons.cancel_outlined, color: Colors.red)),
            const SizedBox(width: 8),
            Expanded(child: _KpiCard(label: 'Pass Rate', value: '${kpiState.passRate.toStringAsFixed(0)}%', icon: Icons.trending_up, color: Colors.orange)),
          ],
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = (screenWidth - 32 - 24) / 3; // 32 padding + 24 gaps

    return Row(
      children: [
        SizedBox(
          width: cardWidth,
          child: _QuickActionCard(
            label: 'Charging Tasks',
            icon: Icons.electric_car,
            color: Colors.blue,
            onTap: () => context.go('/charging-station'),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: cardWidth,
          child: _QuickActionCard(
            label: 'Swap Tasks',
            icon: Icons.battery_charging_full,
            color: Colors.green,
            onTap: () => context.go('/swap-station'),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: cardWidth,
          child: _QuickActionCard(
            label: 'My Profile',
            icon: Icons.person,
            color: Colors.purple,
            onTap: () => context.go('/profile'),
          ),
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentTasksSection extends ConsumerWidget {
  final TaskType taskType;

  const _RecentTasksSection({required this.taskType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (taskType == TaskType.charging) {
      final tasksAsync = ref.watch(tasksByStatusProvider(null));

      return tasksAsync.when(
        data: (tasks) {
          final incomplete = tasks
              .where((t) =>
                  t.status == VerificationTaskStatus.assigned ||
                  t.status == VerificationTaskStatus.checkedIn)
              .toList()
            ..sort((a, b) {
              if (a.slaDueAt == null && b.slaDueAt == null) return 0;
              if (a.slaDueAt == null) return 1;
              if (b.slaDueAt == null) return -1;
              return a.slaDueAt!.compareTo(b.slaDueAt!);
            });
          if (incomplete.isEmpty) {
            return _EmptyTasksCard(
              message: 'No active charging tasks.',
              onViewAll: () => context.go('/charging-station'),
            );
          }
          return _TasksList(
            tasks: incomplete.take(2).toList(),
            onViewAll: () => context.go('/charging-station'),
            basePath: '/charging-station',
          );
        },
        loading: () => const SkeletonList(count: 2),
        error: (e, _) => _ErrorCard(
          message: 'Could not load tasks.',
          onRetry: () => ref.invalidate(tasksByStatusProvider(null)),
        ),
      );
    } else {
      final tasksAsync = ref.watch(swapTasksProvider);

      return tasksAsync.when(
        data: (tasks) {
          final incomplete = tasks
              .where((t) =>
                  t.status.toString() == 'ASSIGNED' ||
                  t.status.toString() == 'CHECKED_IN')
              .toList()
            ..sort((a, b) {
              if (a.slaDueAt == null && b.slaDueAt == null) return 0;
              if (a.slaDueAt == null) return 1;
              if (b.slaDueAt == null) return -1;
              return a.slaDueAt!.compareTo(b.slaDueAt!);
            });
          if (incomplete.isEmpty) {
            return _EmptyTasksCard(
              message: 'No active swap tasks.',
              onViewAll: () => context.go('/swap-station'),
            );
          }
          return _SwapTasksList(
            tasks: incomplete.take(2).toList(),
            onViewAll: () => context.go('/swap-station'),
          );
        },
        loading: () => const SkeletonList(count: 2),
        error: (e, _) => _ErrorCard(
          message: 'Could not load swap tasks.',
          onRetry: () => ref.invalidate(swapTasksProvider),
        ),
      );
    }
  }
}

class _TasksList extends StatelessWidget {
  final List<VerificationTask> tasks;
  final VoidCallback onViewAll;
  final String basePath;

  const _TasksList({
    required this.tasks,
    required this.onViewAll,
    required this.basePath,
  });

  String _formatDeadline(DateTime? deadline) {
    if (deadline == null) return 'No deadline';
    final now = DateTime.now();
    final diff = deadline.difference(now);
    if (diff.isNegative) {
      return 'Overdue';
    } else if (diff.inDays == 0) {
      return 'Due today';
    } else if (diff.inDays == 1) {
      return 'Due tomorrow';
    } else if (diff.inDays < 7) {
      return 'Due in ${diff.inDays} days';
    } else {
      return 'Due ${deadline.day}/${deadline.month}/${deadline.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Column(
        children: [
          ...tasks.map((task) => ListTile(
                leading: Icon(
                  Icons.location_on,
                  color: theme.colorScheme.primary,
                ),
                title: Text(
                  task.stationName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.status.displayName,
                      style: theme.textTheme.bodySmall,
                    ),
                    Text(
                      _formatDeadline(task.slaDueAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _isOverdue(task.slaDueAt)
                            ? Colors.red
                            : theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('$basePath/${task.id}'),
              )),
          const Divider(height: 1),
          TextButton(
            onPressed: onViewAll,
            child: const Text('View all tasks'),
          ),
        ],
      ),
    );
  }

  bool _isOverdue(DateTime? deadline) {
    if (deadline == null) return false;
    return deadline.isBefore(DateTime.now());
  }
}

class _SwapTasksList extends StatelessWidget {
  final List<BatterySwapVerificationTask> tasks;
  final VoidCallback onViewAll;

  const _SwapTasksList({
    required this.tasks,
    required this.onViewAll,
  });

  String _formatDeadline(DateTime? deadline) {
    if (deadline == null) return 'No deadline';
    final now = DateTime.now();
    final diff = deadline.difference(now);
    if (diff.isNegative) {
      return 'Overdue';
    } else if (diff.inDays == 0) {
      return 'Due today';
    } else if (diff.inDays == 1) {
      return 'Due tomorrow';
    } else if (diff.inDays < 7) {
      return 'Due in ${diff.inDays} days';
    } else {
      return 'Due ${deadline.day}/${deadline.month}/${deadline.year}';
    }
  }

  bool _isOverdue(DateTime? deadline) {
    if (deadline == null) return false;
    return deadline.isBefore(DateTime.now());
  }

  String _statusDisplayName(BatterySwapVerificationTask task) {
    final s = task.status.toString();
    switch (s) {
      case 'ASSIGNED':
        return 'Assigned';
      case 'CHECKED_IN':
        return 'Checked in';
      case 'SUBMITTED':
        return 'Submitted';
      case 'REVIEWED':
        return 'Reviewed';
      default:
        return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Column(
        children: [
          ...tasks.map((task) => ListTile(
                leading: Icon(
                  Icons.battery_charging_full,
                  color: Colors.green,
                ),
                title: Text(
                  task.stationName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _statusDisplayName(task),
                      style: theme.textTheme.bodySmall,
                    ),
                    Text(
                      _formatDeadline(task.slaDueAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _isOverdue(task.slaDueAt)
                            ? Colors.red
                            : theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/swap-station/${task.id}'),
              )),
          const Divider(height: 1),
          TextButton(
            onPressed: onViewAll,
            child: const Text('View all tasks'),
          ),
        ],
      ),
    );
  }
}

class _EmptyTasksCard extends StatelessWidget {
  final String message;
  final VoidCallback onViewAll;

  const _EmptyTasksCard({required this.message, required this.onViewAll});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 40,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
