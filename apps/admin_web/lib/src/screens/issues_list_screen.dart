import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';
import '../models/admin_issue.dart';
import '../providers/issue_providers.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_scaffold.dart';

/// Issues List Screen
class IssuesListScreen extends ConsumerStatefulWidget {
  const IssuesListScreen({super.key});

  @override
  ConsumerState<IssuesListScreen> createState() => _IssuesListScreenState();
}

class _IssuesListScreenState extends ConsumerState<IssuesListScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusFilter = ref.watch(issueStatusFilterProvider);
    final issuesAsync = ref.watch(issuesProvider);

    return AdminScaffold(
      title: 'Reported Issues',
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filters
            _buildFilterPanel(theme, statusFilter),
            const SizedBox(height: 24),

            // Stats Row
            _buildStatsRow(theme, issuesAsync),
            const SizedBox(height: 24),

            // Issues Table
            Expanded(
              child: Card(
                margin: EdgeInsets.zero,
                child: issuesAsync.when(
                  data: (issues) => _buildIssuesTable(context, theme, issues),
                  loading: () => LoadingState(message: 'Loading issues...'),
                  error: (error, stack) => ErrorState(
                    message: error.toString(),
                    onRetry: () {
                      ref.invalidate(issuesProvider);
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

  Widget _buildFilterPanel(ThemeData theme, IssueStatus? statusFilter) {
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.colorScheme.outline),
            ),
            child: DropdownButton<IssueStatus?>(
              value: statusFilter,
              underline: const SizedBox(),
              isDense: true,
              hint: const Text('All Statuses'),
              items: [
                const DropdownMenuItem<IssueStatus?>(
                  value: null,
                  child: Text('All Statuses'),
                ),
                ...IssueStatus.values.map((status) => DropdownMenuItem<IssueStatus?>(
                      value: status,
                      child: Text(status.displayName),
                    )),
              ],
              onChanged: (value) {
                ref.read(issueStatusFilterProvider.notifier).state = value;
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(ThemeData theme, AsyncValue<List<AdminIssue>> issuesAsync) {
    return issuesAsync.when(
      data: (issues) {
        final stats = {
          'Total': issues.length,
          'Open': issues.where((i) => i.status == IssueStatus.open).length,
          'Acknowledged': issues.where((i) => i.status == IssueStatus.acknowledged).length,
          'Resolved': issues.where((i) => i.status == IssueStatus.resolved).length,
          'Rejected': issues.where((i) => i.status == IssueStatus.rejected).length,
        };

        return Row(
          children: stats.entries.map((entry) {
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: entry.key == 'Rejected' ? 0 : 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AdminTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AdminTheme.primaryTeal.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.value.toString(),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AdminTheme.primaryTeal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.key,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
      loading: () => const SizedBox(height: 80),
      error: (_, __) => const SizedBox(height: 80),
    );
  }

  Widget _buildIssuesTable(BuildContext context, ThemeData theme, List<AdminIssue> issues) {
    if (issues.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.inbox,
                size: 64,
                color: theme.colorScheme.onSurface.withOpacity(0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'No issues found',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
              Expanded(flex: 2, child: Text('Category', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold))),
              Expanded(flex: 2, child: Text('Status', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold))),
              Expanded(flex: 3, child: Text('Station Name', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold))),
              Expanded(flex: 2, child: Text('Reporter', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold))),
              Expanded(flex: 2, child: Text('Created At', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold))),
              const SizedBox(width: 48), // For actions column
            ],
          ),
        ),
        // Issues List
        Expanded(
          child: ListView.separated(
            itemCount: issues.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: theme.colorScheme.outline.withOpacity(0.1),
            ),
            itemBuilder: (context, index) {
              final issue = issues[index];
              return _buildIssueRow(context, theme, issue);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildIssueRow(BuildContext context, ThemeData theme, AdminIssue issue) {
    return InkWell(
      onTap: () {
        context.push('/issues/${issue.id}');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: _buildCategoryPill(theme, issue.category),
            ),
            Expanded(
              flex: 2,
              child: StatusPill(
                label: issue.status.displayName,
                colorMapper: (label) => _getStatusColor(issue.status),
              ),
            ),
            Expanded(
              flex: 3,
              child: Tooltip(
                message: issue.stationName ?? 'N/A',
                child: Text(
                  issue.stationName ?? 'N/A',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                issue.reporterEmail,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                _formatDateTime(issue.createdAt),
                style: theme.textTheme.bodySmall,
              ),
            ),
            SizedBox(
              width: 48,
              child: IconButton(
                icon: const Icon(Icons.visibility, size: 20),
                onPressed: () {
                  context.push('/issues/${issue.id}');
                },
                tooltip: 'View Details',
                color: AdminTheme.primaryTeal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryPill(ThemeData theme, IssueCategory category) {
    final color = _getCategoryColor(category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        category.displayName,
        style: theme.textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Color _getCategoryColor(IssueCategory category) {
    switch (category) {
      case IssueCategory.locationWrong:
        return Colors.red;
      case IssueCategory.priceWrong:
        return Colors.orange;
      case IssueCategory.hoursWrong:
        return Colors.amber;
      case IssueCategory.portsWrong:
        return Colors.purple;
      case IssueCategory.other:
        return Colors.grey;
    }
  }

  Color _getStatusColor(IssueStatus status) {
    switch (status) {
      case IssueStatus.open:
        return Colors.blue;
      case IssueStatus.acknowledged:
        return Colors.orange;
      case IssueStatus.resolved:
        return Colors.green;
      case IssueStatus.rejected:
        return Colors.red;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

