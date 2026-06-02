import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_ui/shared_ui.dart';
import '../widgets/dashboard_shell.dart';
import '../theme/collab_theme.dart';
import '../providers/battery_swap_task_providers.dart';

/// Swap KPI Screen - Battery swap verification KPIs
class SwapKPIScreen extends ConsumerWidget {
  const SwapKPIScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final kpiAsync = ref.watch(swapKpiProvider);

    return DashboardShell(
      title: 'Battery Swap KPIs',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info Card
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
                        'Battery swap verification KPI metrics for current month',
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
                  // Summary Cards
                  Row(
                    children: [
                      _buildKPICard(
                        theme,
                        title: 'Completed',
                        value: kpi.completedCount.toString(),
                        subtitle: 'Tasks completed',
                        icon: Icons.check_circle,
                        color: CollabTheme.primaryGreen,
                      ),
                      const SizedBox(width: 16),
                      _buildKPICard(
                        theme,
                        title: 'Passed',
                        value: kpi.passedCount.toString(),
                        subtitle: kpi.completedCount > 0
                            ? '${kpi.passRate.toStringAsFixed(1)}% pass rate'
                            : 'N/A',
                        icon: Icons.thumb_up,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 16),
                      _buildKPICard(
                        theme,
                        title: 'Failed',
                        value: kpi.failedCount.toString(),
                        subtitle: kpi.completedCount > 0
                            ? '${kpi.failRate.toStringAsFixed(1)}% fail rate'
                            : 'N/A',
                        icon: Icons.thumb_down,
                        color: Colors.red,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Row(
                    children: [
                      _buildKPICard(
                        theme,
                        title: 'Avg Time',
                        value: kpi.formattedAvgTime,
                        subtitle: 'Completion time',
                        icon: Icons.timer,
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 16),
                      _buildKPICard(
                        theme,
                        title: 'Accuracy',
                        value: '${kpi.accuracyRate.toStringAsFixed(1)}%',
                        subtitle: 'Verification accuracy',
                        icon: Icons.verified,
                        color: Colors.purple,
                      ),
                      const SizedBox(width: 16),
                      _buildKPICard(
                        theme,
                        title: 'Month',
                        value: kpi.formattedMonth.split(' ').first,
                        subtitle: kpi.formattedMonth.split(' ').length > 1
                            ? kpi.formattedMonth.split(' ').last
                            : '',
                        icon: Icons.calendar_month,
                        color: Colors.orange,
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
                      Expanded(
                        child: _buildKPICard(
                          theme,
                          title: 'Completed',
                          value: '--',
                          subtitle: 'Loading...',
                          icon: Icons.check_circle,
                          color: CollabTheme.primaryGreen,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildKPICard(
                          theme,
                          title: 'Passed',
                          value: '--',
                          subtitle: 'Loading...',
                          icon: Icons.thumb_up,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildKPICard(
                          theme,
                          title: 'Failed',
                          value: '--',
                          subtitle: 'Loading...',
                          icon: Icons.thumb_down,
                          color: Colors.red,
                        ),
                      ),
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
                      Expanded(
                        child: _buildKPICard(
                          theme,
                          title: 'Completed',
                          value: '--',
                          subtitle: 'Error',
                          icon: Icons.check_circle,
                          color: CollabTheme.primaryGreen,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildKPICard(
                          theme,
                          title: 'Passed',
                          value: '--',
                          subtitle: 'Error',
                          icon: Icons.thumb_up,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildKPICard(
                          theme,
                          title: 'Failed',
                          value: '--',
                          subtitle: 'Error',
                          icon: Icons.thumb_down,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ErrorState(
                    message: error.toString(),
                    onRetry: () {
                      ref.invalidate(swapKpiProvider);
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

  Widget _buildBarChart(ThemeData theme, dynamic kpi) {
    final maxValue = [
      kpi.completedCount,
      kpi.passedCount,
      kpi.failedCount,
      1
    ].reduce((a, b) => a > b ? a : b);
    final chartHeight = 200.0;
    final barWidth = 80.0;
    final spacing = 40.0;
    final labelHeight = 60.0;

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

    return SizedBox(
      height: chartHeight + labelHeight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildBarItem(
            theme,
            barWidth: barWidth,
            barHeight: (kpi.completedCount / maxValue) * chartHeight,
            value: kpi.completedCount.toString(),
            label: 'Completed',
            color: CollabTheme.primaryGreen,
            labelHeight: labelHeight,
          ),
          SizedBox(width: spacing),
          _buildBarItem(
            theme,
            barWidth: barWidth,
            barHeight: (kpi.passedCount / maxValue) * chartHeight,
            value: kpi.passedCount.toString(),
            label: 'Passed',
            color: Colors.green,
            labelHeight: labelHeight,
          ),
          SizedBox(width: spacing),
          _buildBarItem(
            theme,
            barWidth: barWidth,
            barHeight: (kpi.failedCount / maxValue) * chartHeight,
            value: kpi.failedCount.toString(),
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
