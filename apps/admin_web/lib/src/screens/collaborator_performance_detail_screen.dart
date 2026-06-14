import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_scaffold.dart';
import '../providers/collaborator_performance_providers.dart';
import '../models/collaborator_performance.dart';
import '../utils/responsive_utils.dart';

class CollaboratorPerformanceDetailScreen extends ConsumerWidget {
  final String collaboratorId;

  const CollaboratorPerformanceDetailScreen({
    super.key,
    required this.collaboratorId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(collaboratorPerformanceDetailProvider(collaboratorId));

    return AdminScaffold(
      title: 'Performance Details',
      actions: [
        IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
          tooltip: 'Back',
        ),
      ],
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(collaboratorPerformanceDetailProvider(collaboratorId));
        },
        child: detailAsync.when(
          data: (detail) => _buildContent(context, detail),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Failed to load: $error'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(collaboratorPerformanceDetailProvider(collaboratorId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, CollaboratorPerformanceDetail detail) {
    return SingleChildScrollView(
      padding: responsivePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Header
          _buildProfileHeader(context, detail),
          SizedBox(height: isMobile(context) ? 20 : 32),

          // KPIs
          _buildKpiCards(context, detail),
          SizedBox(height: isMobile(context) ? 20 : 32),

          // Monthly Breakdown Chart
          _buildMonthlyChart(context, detail),
          SizedBox(height: isMobile(context) ? 20 : 32),

          // Task History
          _buildTaskHistory(context, detail),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, CollaboratorPerformanceDetail detail) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AdminTheme.outlineLight),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile(context) ? 16 : 24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 400) {
              return Column(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: AdminTheme.primaryTeal.withOpacity(0.1),
                    child: Text(
                      detail.fullName.isNotEmpty ? detail.fullName[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AdminTheme.primaryTeal,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    detail.fullName.isNotEmpty ? detail.fullName : 'Unknown Collaborator',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ID: ${detail.collaboratorId}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AdminTheme.primaryTeal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 16, color: AdminTheme.primaryTeal),
                        const SizedBox(width: 4),
                        Text(
                          '${detail.passRate.toStringAsFixed(0)}% Pass Rate',
                          style: TextStyle(color: AdminTheme.primaryTeal, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }
            return Row(
              children: [
                CircleAvatar(
                  radius: isMobile(context) ? 32 : 40,
                  backgroundColor: AdminTheme.primaryTeal.withOpacity(0.1),
                  child: Text(
                    detail.fullName.isNotEmpty ? detail.fullName[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: isMobile(context) ? 24 : 32,
                      fontWeight: FontWeight.bold,
                      color: AdminTheme.primaryTeal,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        detail.fullName.isNotEmpty ? detail.fullName : 'Unknown Collaborator',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: isMobile(context) ? 16 : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ID: ${detail.collaboratorId}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AdminTheme.primaryTeal.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, size: 16, color: AdminTheme.primaryTeal),
                            const SizedBox(width: 4),
                            Text(
                              '${detail.passRate.toStringAsFixed(0)}% Pass Rate',
                              style: TextStyle(color: AdminTheme.primaryTeal, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildKpiCards(BuildContext context, CollaboratorPerformanceDetail detail) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 800 ? 4 : constraints.maxWidth > 400 ? 2 : 1;
        final cardWidth = (constraints.maxWidth - (crossAxisCount - 1) * 16) / crossAxisCount;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _buildKpiCard(
              context,
              width: cardWidth,
              icon: Icons.assignment,
              value: detail.totalTasks.toString(),
              label: 'Total Tasks',
              color: AdminTheme.primaryTeal,
            ),
            _buildKpiCard(
              context,
              width: cardWidth,
              icon: Icons.check_circle,
              value: '${detail.passRate.toStringAsFixed(1)}%',
              label: 'Pass Rate',
              color: const Color(0xFF22C55E),
            ),
            _buildKpiCard(
              context,
              width: cardWidth,
              icon: Icons.timer,
              value: '${detail.avgCompletionTimeHours.toStringAsFixed(1)}h',
              label: 'Avg Completion Time',
              color: const Color(0xFFF97316),
            ),
            _buildKpiCard(
              context,
              width: cardWidth,
              icon: Icons.speed,
              value: '${detail.slaComplianceRate.toStringAsFixed(1)}%',
              label: 'SLA Compliance',
              color: const Color(0xFF8B5CF6),
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard(
    BuildContext context, {
    required double width,
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return SizedBox(
      width: width,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AdminTheme.outlineLight),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 16),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AdminTheme.primaryTealDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthlyChart(BuildContext context, CollaboratorPerformanceDetail detail) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AdminTheme.outlineLight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Monthly Task Breakdown',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildChartLegend(const Color(0xFF22C55E), 'Pass'),
                const SizedBox(width: 16),
                _buildChartLegend(const Color(0xFFEF4444), 'Fail'),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: detail.monthlyBreakdown.isEmpty
                  ? const EmptyState(
                      icon: Icons.bar_chart,
                      message: 'No monthly data available',
                    )
                  : _buildBarChart(detail.monthlyBreakdown),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartLegend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildBarChart(List<MonthlyBreakdown> monthlyData) {
    if (monthlyData.isEmpty) {
      return const Center(child: Text('No data'));
    }

    final maxTotalTasks = monthlyData.map((m) => m.totalTasks).reduce((a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxTotalTasks > 0 ? maxTotalTasks.toDouble() * 1.2 : 10.0,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final month = monthlyData[groupIndex];
              return BarTooltipItem(
                '${month.displayMonth}\n${month.totalTasks} tasks (${month.passedTasks} pass, ${month.failedTasks} fail)\n${month.passRate.toStringAsFixed(0)}% pass',
                const TextStyle(color: Colors.white, fontSize: 12),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= monthlyData.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    monthlyData[index].displayMonth,
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
              reservedSize: 30,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: AdminTheme.outlineLight,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: monthlyData.map((month) {
          return BarChartGroupData(
            x: monthlyData.indexOf(month),
            barRods: [
              BarChartRodData(
                toY: month.totalTasks.toDouble(),
                width: 24,
                rodStackItems: [
                  BarChartRodStackItem(0, month.passedTasks.toDouble(), const Color(0xFF22C55E)),
                  BarChartRodStackItem(month.passedTasks.toDouble(), month.totalTasks.toDouble(), const Color(0xFFEF4444)),
                ],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTaskHistory(BuildContext context, CollaboratorPerformanceDetail detail) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AdminTheme.outlineLight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Task History',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            // Simulated task history
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 10, // Show last 10 tasks
              itemBuilder: (context, index) {
                final isPass = index % 3 != 0; // Simulate pass/fail
                final daysAgo = index * 3;
                
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isPass 
                        ? const Color(0xFF22C55E).withOpacity(0.1)
                        : const Color(0xFFEF4444).withOpacity(0.1),
                    child: Icon(
                      isPass ? Icons.check : Icons.close,
                      color: isPass ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                      size: 20,
                    ),
                  ),
                  title: Text('Verification Task #${1000 + index}'),
                  subtitle: Text('$daysAgo days ago'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isPass 
                          ? const Color(0xFF22C55E).withOpacity(0.1)
                          : const Color(0xFFEF4444).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isPass ? 'PASS' : 'FAIL',
                      style: TextStyle(
                        color: isPass ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
