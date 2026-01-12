import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_ui/shared_ui.dart';
import '../widgets/dashboard_shell.dart';
import '../theme/collab_theme.dart';
import '../providers/task_providers.dart';
import '../models/collaborator_kpi.dart';

/// Task KPI Screen - Shows performance metrics and KPIs
class TaskKPIScreen extends ConsumerWidget {
  const TaskKPIScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final kpiAsync = ref.watch(kpiProvider);

    return DashboardShell(
      title: 'KPI Dashboard',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info Text
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: CollabTheme.primaryGreen,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'KPI metrics for current month',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // KPI Cards
            kpiAsync.when(
              data: (kpi) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // KPI Summary Cards
                  Row(
                    children: [
                      _buildKPICard(
                        theme,
                        title: 'Reviewed Tasks',
                        value: kpi.reviewedCount.toString(),
                        subtitle: kpi.formattedMonth,
                        icon: Icons.check_circle,
                        color: CollabTheme.primaryGreen,
                      ),
                      const SizedBox(width: 16),
                      _buildKPICard(
                        theme,
                        title: 'Passed',
                        value: kpi.passCount.toString(),
                        subtitle: kpi.reviewedCount > 0
                            ? '${kpi.passRate.toStringAsFixed(1)}% pass rate'
                            : 'N/A',
                        icon: Icons.thumb_up,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 16),
                      _buildKPICard(
                        theme,
                        title: 'Failed',
                        value: kpi.failCount.toString(),
                        subtitle: kpi.reviewedCount > 0
                            ? '${kpi.failRate.toStringAsFixed(1)}% fail rate'
                            : 'N/A',
                        icon: Icons.thumb_down,
                        color: Colors.red,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Bar Chart
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Performance Overview - ${kpi.formattedMonth}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            height: 250,
                            child: _buildBarChart(theme, kpi),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              loading: () => Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildKPICard(theme, title: 'Reviewed Tasks', value: '--', subtitle: 'Loading...', icon: Icons.check_circle, color: CollabTheme.primaryGreen)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildKPICard(theme, title: 'Passed', value: '--', subtitle: 'Loading...', icon: Icons.thumb_up, color: Colors.green)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildKPICard(theme, title: 'Failed', value: '--', subtitle: 'Loading...', icon: Icons.thumb_down, color: Colors.red)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const LoadingState(message: 'Loading KPI data...'),
                ],
              ),
              error: (error, stack) => Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildKPICard(theme, title: 'Reviewed Tasks', value: '--', subtitle: 'Error', icon: Icons.check_circle, color: CollabTheme.primaryGreen)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildKPICard(theme, title: 'Passed', value: '--', subtitle: 'Error', icon: Icons.thumb_up, color: Colors.green)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildKPICard(theme, title: 'Failed', value: '--', subtitle: 'Error', icon: Icons.thumb_down, color: Colors.red)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ErrorState(
                    message: error.toString(),
                    onRetry: () {
                      ref.invalidate(kpiProvider);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKPICard(
    ThemeData theme, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                value,
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBarChart(ThemeData theme, CollaboratorKpi kpi) {
    final maxValue = [kpi.reviewedCount, kpi.passCount, kpi.failCount]
        .reduce((a, b) => a > b ? a : b);
    final chartHeight = 200.0;
    final barWidth = 80.0;
    final spacing = 40.0;
    final labelHeight = 60.0; // Space for value + label text

    if (maxValue == 0) {
      return Center(
        child: Text(
          'No data available',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      );
    }

    // Use fixed height container with Stack approach
    return SizedBox(
      height: chartHeight + labelHeight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Reviewed Count Bar
          _buildBarItem(
            theme,
            barWidth: barWidth,
            barHeight: (kpi.reviewedCount / maxValue) * chartHeight,
            value: kpi.reviewedCount.toString(),
            label: 'Reviewed',
            color: CollabTheme.primaryGreen,
            labelHeight: labelHeight,
          ),
          SizedBox(width: spacing),
          // Pass Count Bar
          _buildBarItem(
            theme,
            barWidth: barWidth,
            barHeight: (kpi.passCount / maxValue) * chartHeight,
            value: kpi.passCount.toString(),
            label: 'Passed',
            color: Colors.green,
            labelHeight: labelHeight,
          ),
          SizedBox(width: spacing),
          // Fail Count Bar
          _buildBarItem(
            theme,
            barWidth: barWidth,
            barHeight: (kpi.failCount / maxValue) * chartHeight,
            value: kpi.failCount.toString(),
            label: 'Failed',
            color: Colors.red,
            labelHeight: labelHeight,
          ),
        ],
      ),
    );
  }

  Widget _buildBarItem(
    ThemeData theme, {
    required double barWidth,
    required double barHeight,
    required String value,
    required String label,
    required Color color,
    required double labelHeight,
  }) {
    return SizedBox(
      width: barWidth,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Labels at bottom (fixed position)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          // Bar positioned above labels
          Positioned(
            bottom: labelHeight,
            left: 0,
            right: 0,
            child: Container(
              width: barWidth,
              height: barHeight,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
