import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_scaffold.dart';
import '../providers/dashboard_providers.dart';
import '../models/dashboard_stats.dart';
import '../utils/responsive_utils.dart';

class AnalyticsDashboardScreen extends ConsumerWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AdminScaffold(
      title: 'Analytics',
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardStatsProvider);
          ref.invalidate(bookingStatsProvider);
          ref.invalidate(issueStatsProvider);
        },
        child: SingleChildScrollView(
          padding: responsivePadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // KPI Cards Row
              _buildKpiCards(context, ref),
              const SizedBox(height: 32),

              // Charts Row 1
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 900;
                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildBookingTrendChart(context, ref)),
                        const SizedBox(width: 24),
                        Expanded(child: _buildIssuesByCategoryChart(context, ref)),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      _buildBookingTrendChart(context, ref),
                      const SizedBox(height: 24),
                      _buildIssuesByCategoryChart(context, ref),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),

              // Charts Row 2
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 900;
                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildStationStatusPieChart(context, ref)),
                        const SizedBox(width: 24),
                        Expanded(child: _buildTrustOverviewTable(context, ref)),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      _buildStationStatusPieChart(context, ref),
                      const SizedBox(height: 24),
                      _buildTrustOverviewTable(context, ref),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKpiCards(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);

    return statsAsync.when(
      data: (stats) => LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = constraints.maxWidth > 1000 ? 4 : constraints.maxWidth > 600 ? 2 : 1;
          final cardWidth = (constraints.maxWidth - (crossAxisCount - 1) * 16) / crossAxisCount;

          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildKpiCard(
                context,
                width: cardWidth,
                icon: Icons.ev_station,
                value: stats.stationCount.toString(),
                label: 'Total Stations',
                color: AdminTheme.primaryTeal,
              ),
              _buildKpiCard(
                context,
                width: cardWidth,
                icon: Icons.description_rounded,
                value: stats.pendingCRs.toString(),
                label: 'Pending CRs',
                color: const Color(0xFFF97316),
              ),
              _buildKpiCard(
                context,
                width: cardWidth,
                icon: Icons.report_problem_rounded,
                value: stats.openIssues.toString(),
                label: 'Open Issues',
                color: const Color(0xFFEF4444),
              ),
              _buildKpiCard(
                context,
                width: cardWidth,
                icon: Icons.warning_amber_rounded,
                value: stats.overdueTasks.toString(),
                label: 'Overdue Tasks',
                color: const Color(0xFFEAB308),
              ),
            ],
          );
        },
      ),
      loading: () => const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => ErrorState(
        message: 'Failed to load statistics',
        onRetry: () => ref.invalidate(dashboardStatsProvider),
      ),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookingTrendChart(BuildContext context, WidgetRef ref) {
    final trendsAsync = ref.watch(trendsProvider(30));

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
              '30-Day Booking Trend',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Daily booking counts over the past 30 days',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: trendsAsync.when(
                data: (trendsMap) => _buildLineChart(context, trendsMap['dailyBookings'] ?? []),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Text('Failed to load data: $error'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineChart(BuildContext context, List<TrendDataPoint> data) {
    if (data.isEmpty) {
      return const EmptyState(
        icon: Icons.show_chart,
        message: 'No trend data available',
      );
    }

    final spots = data.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.count.toDouble());
    }).toList();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 10,
          getDrawingHorizontalLine: (value) => FlLine(
            color: AdminTheme.outlineLight,
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: (data.length / 5).ceilToDouble(),
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= data.length) return const SizedBox();
                final date = data[index].date;
                if (date.length >= 5) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      date.substring(5),
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                }
                return const SizedBox();
              },
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
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AdminTheme.primaryTeal,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AdminTheme.primaryTeal.withOpacity(0.1),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.x.toInt();
                final date = index < data.length ? data[index].date : '';
                return LineTooltipItem(
                  '$date\n${spot.y.toInt()} bookings',
                  const TextStyle(color: Colors.white, fontSize: 12),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildIssuesByCategoryChart(BuildContext context, WidgetRef ref) {
    final issuesAsync = ref.watch(issueStatsProvider);

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
              'Issues by Category',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Distribution of issues across categories',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: issuesAsync.when(
                data: (data) => _buildBarChart(context, data),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Text('Failed to load data: $error'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart(BuildContext context, IssueStats data) {
    if (data.issuesByCategory.isEmpty) {
      return const EmptyState(
        icon: Icons.bar_chart,
        message: 'No issue data available',
      );
    }

    final maxCount = data.issuesByCategory.map((e) => e.count).reduce((a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxCount.toDouble() * 1.2,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final category = data.issuesByCategory[groupIndex];
              return BarTooltipItem(
                '${category.category}\n${category.count} issues',
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
                if (index < 0 || index >= data.issuesByCategory.length) return const SizedBox();
                final category = data.issuesByCategory[index].category;
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    category.length > 8 ? '${category.substring(0, 8)}...' : category,
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
              reservedSize: 40,
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
          horizontalInterval: maxCount > 10 ? (maxCount / 5).ceilToDouble() : 1,
          getDrawingHorizontalLine: (value) => FlLine(
            color: AdminTheme.outlineLight,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: data.issuesByCategory.asMap().entries.map((entry) {
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: entry.value.count.toDouble(),
                color: AdminTheme.primaryTeal,
                width: 20,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStationStatusPieChart(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);

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
              'Station Status Distribution',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Breakdown by workflow status',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: statsAsync.when(
                data: (stats) => _buildPieChart(context, stats),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Text('Failed to load data: $error'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChart(BuildContext context, DashboardStats stats) {
    final statuses = [
      {'status': 'Published', 'count': stats.stationCount ~/ 2, 'color': const Color(0xFF22C55E)},
      {'status': 'Pending', 'count': stats.pendingCRs, 'color': const Color(0xFFF97316)},
      {'status': 'Draft', 'count': stats.stationCount ~/ 4, 'color': const Color(0xFF64748B)},
      {'status': 'Archived', 'count': stats.stationCount ~/ 8, 'color': const Color(0xFFEF4444)},
    ];

    final total = statuses.map((s) => s['count'] as int).reduce((a, b) => a + b);

    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: statuses.map((status) {
                final count = status['count'] as int;
                final percentage = total > 0 ? (count / total * 100) : 0;
                return PieChartSectionData(
                  color: status['color'] as Color,
                  value: count.toDouble(),
                  title: '${percentage.toStringAsFixed(0)}%',
                  radius: 50,
                  titleStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: statuses.map((status) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: status['color'] as Color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${status['status']} (${status['count']})',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTrustOverviewTable(BuildContext context, WidgetRef ref) {
    final trustAsync = ref.watch(trustOverviewProvider(TrustOverviewParams()));

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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Trust Score Overview',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => context.push('/trust/charging'),
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            trustAsync.when(
              data: (response) {
                final items = (response['content'] as List<dynamic>? ?? [])
                    .map((e) => TrustOverviewItem.fromJson(e as Map<String, dynamic>))
                    .toList();

                if (items.isEmpty) {
                  return const EmptyState(
                    icon: Icons.verified_user,
                    message: 'No station data available',
                  );
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                      AdminTheme.primaryTeal.withOpacity(0.05),
                    ),
                    columns: const [
                      DataColumn(label: Text('Station Name')),
                      DataColumn(label: Text('Address')),
                      DataColumn(label: Text('Trust Score')),
                      DataColumn(label: Text('Service Type')),
                    ],
                    rows: items.take(5).map((item) {
                      return DataRow(
                        cells: [
                          DataCell(Text(item.name.isNotEmpty ? item.name : 'N/A')),
                          DataCell(Text(
                            item.address.isNotEmpty 
                                ? (item.address.length > 30 ? '${item.address.substring(0, 30)}...' : item.address)
                                : 'N/A',
                          )),
                          DataCell(_buildTrustScoreBadge(item.trustScore)),
                          DataCell(Text(item.serviceType)),
                        ],
                      );
                    }).toList(),
                  ),
                );
              },
              loading: () => const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => SizedBox(
                height: 200,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Failed to load data: $error'),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => ref.invalidate(trustOverviewProvider(TrustOverviewParams())),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrustScoreBadge(int score) {
    Color color;
    if (score >= 80) {
      color = const Color(0xFF22C55E);
    } else if (score >= 50) {
      color = const Color(0xFFF97316);
    } else {
      color = const Color(0xFFEF4444);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        score.toString(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
