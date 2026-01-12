import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_ui/shared_ui.dart';
import '../widgets/dashboard_shell.dart';
import '../theme/collab_theme.dart';
import '../models/verification_task.dart';
import '../providers/task_providers.dart';
import 'task_detail_screen.dart';

/// Task History Screen - Shows completed/reviewed tasks history
class TaskHistoryScreen extends ConsumerWidget {
  const TaskHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final historyAsync = ref.watch(taskHistoryProvider);

    return DashboardShell(
      title: 'Task History',
      searchSlot: SearchField(
        hint: 'Search history...',
        onChanged: (value) {
          // Search functionality - to be implemented
        },
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // History Table
            Expanded(
              child: Card(
                margin: EdgeInsets.zero,
                child: historyAsync.when(
                  data: (page) => _buildHistoryTable(context, theme, page, ref),
                  loading: () => const LoadingState(message: 'Loading history...'),
                  error: (error, stack) => ErrorState(
                    message: error.toString(),
                    onRetry: () {
                      ref.invalidate(taskHistoryPageProvider);
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

  Widget _buildHistoryTable(
    BuildContext context,
    ThemeData theme,
    PagedResponse<VerificationTask> page,
    WidgetRef ref,
  ) {
    if (page.content.isEmpty) {
      return EmptyState(
        icon: Icons.history_outlined,
        message: 'No task history found',
        action: OutlinedButton.icon(
          onPressed: () {
            ref.invalidate(taskHistoryPageProvider);
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
                  'Result',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Reviewed At',
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
              return _buildHistoryRow(context, theme, task);
            },
          ),
        ),

        // Pagination
        _buildPagination(context, theme, page, ref),
      ],
    );
  }

  Widget _buildHistoryRow(
    BuildContext context,
    ThemeData theme,
    VerificationTask task,
  ) {
    final review = task.review;
    final hasReview = review != null;

    return InkWell(
      onTap: () {
        // Open detail dialog
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
              child: hasReview
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: review.isPass
                            ? Colors.green.withOpacity(0.1)
                            : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: review.isPass ? Colors.green : Colors.red,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            review.isPass
                                ? Icons.check_circle
                                : Icons.cancel,
                            size: 16,
                            color: review.isPass ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            review.result,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: review.isPass ? Colors.green : Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Text(
                      'N/A',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.4),
                      ),
                    ),
            ),
            Expanded(
              flex: 2,
              child: hasReview
                  ? Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 16,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _formatDateTime(review!.reviewedAt),
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      'N/A',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.4),
                      ),
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

  Widget _buildPagination(
    BuildContext context,
    ThemeData theme,
    PagedResponse<VerificationTask> page,
    WidgetRef ref,
  ) {
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
                        ref.read(historyCurrentPageProvider.notifier).state = 0;
                      },
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: page.first
                    ? null
                    : () {
                        ref.read(historyCurrentPageProvider.notifier).state =
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
                        ref.read(historyCurrentPageProvider.notifier).state =
                            page.page + 1;
                      },
              ),
              IconButton(
                icon: const Icon(Icons.last_page),
                onPressed: page.last
                    ? null
                    : () {
                        ref.read(historyCurrentPageProvider.notifier).state =
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

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
