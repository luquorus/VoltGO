import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_scaffold.dart';
import '../providers/collaborator_performance_providers.dart';
import '../models/collaborator_performance.dart';

class CollaboratorPerformanceScreen extends ConsumerStatefulWidget {
  const CollaboratorPerformanceScreen({super.key});

  @override
  ConsumerState<CollaboratorPerformanceScreen> createState() => _CollaboratorPerformanceScreenState();
}

class _CollaboratorPerformanceScreenState extends ConsumerState<CollaboratorPerformanceScreen> {
  int _sortColumnIndex = 0;
  bool _sortAscending = false;
  String _sortBy = 'totalTasks';

  @override
  Widget build(BuildContext context) {
    final params = CollaboratorPerformanceParams(
      page: 0,
      size: 20,
      sortBy: _sortBy,
      sortDir: _sortAscending ? 'asc' : 'desc',
    );

    final performanceAsync = ref.watch(collaboratorPerformanceListProvider(params));
    final statsAsync = ref.watch(aggregatedPerformanceStatsProvider);

    return AdminScaffold(
      title: 'Collaborator Performance',
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(collaboratorPerformanceListProvider(params));
          ref.invalidate(aggregatedPerformanceStatsProvider);
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Leaderboard Header
              _buildLeaderboardHeader(performanceAsync),
              const SizedBox(height: 32),

              // Stats Cards
              _buildStatsCards(statsAsync),
              const SizedBox(height: 32),

              // Monthly Performance Chart
              _buildMonthlyPerformanceChart(performanceAsync),
              const SizedBox(height: 32),

              // Performance Table
              _buildPerformanceTable(performanceAsync),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeaderboardHeader(AsyncValue<Map<String, dynamic>> asyncData) {
    return asyncData.when(
      data: (data) {
        final collaborators = (data['content'] as List<dynamic>? ?? [])
            .map((e) => CollaboratorPerformance.fromJson(e as Map<String, dynamic>))
            .toList();

        if (collaborators.isEmpty) {
          return const SizedBox.shrink();
        }

        // Sort by pass rate to get top performers
        collaborators.sort((a, b) => b.passRate.compareTo(a.passRate));
        final top3 = collaborators.take(3).toList();

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AdminTheme.outlineLight),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Top Performers',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final itemWidth = constraints.maxWidth > 600 
                        ? (constraints.maxWidth - 48) / 3 
                        : constraints.maxWidth;

                    return Wrap(
                      spacing: 24,
                      runSpacing: 16,
                      children: top3.asMap().entries.map((entry) {
                        final index = entry.key;
                        final collab = entry.value;
                        return _buildLeaderboardCard(collab, index);
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Failed to load leaderboard: $error'),
        ),
      ),
    );
  }

  Widget _buildLeaderboardCard(CollaboratorPerformance collab, int rank) {
    final medals = [
      const Color(0xFFFFD700), // Gold
      const Color(0xFFC0C0C0), // Silver
      const Color(0xFFCD7F32), // Bronze
    ];

    final medal = medals[rank.clamp(0, 2)];

    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            medal.withOpacity(0.1),
            medal.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: medal.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.topRight,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: AdminTheme.primaryTeal.withOpacity(0.1),
                child: Text(
                  collab.fullName.isNotEmpty 
                      ? collab.fullName[0].toUpperCase() 
                      : '?',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AdminTheme.primaryTeal,
                  ),
                ),
              ),
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: medal,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: medal.withOpacity(0.4),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '${rank + 1}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            collab.fullName.isNotEmpty ? collab.fullName : 'Unknown',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '${collab.totalTasks} tasks',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AdminTheme.primaryTeal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${(collab.passRate * 100).toStringAsFixed(0)}% pass',
              style: TextStyle(
                color: AdminTheme.primaryTeal,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards(AsyncValue<AggregatedPerformanceStats> asyncData) {
    return asyncData.when(
      data: (stats) => LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = constraints.maxWidth > 800 ? 4 : constraints.maxWidth > 400 ? 2 : 1;
          final cardWidth = (constraints.maxWidth - (crossAxisCount - 1) * 16) / crossAxisCount;

          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildStatCard(
                width: cardWidth,
                icon: Icons.assignment,
                value: stats.totalTasks.toString(),
                label: 'Total Tasks',
                color: AdminTheme.primaryTeal,
              ),
              _buildStatCard(
                width: cardWidth,
                icon: Icons.check_circle,
                value: '${(stats.avgPassRate * 100).toStringAsFixed(1)}%',
                label: 'Avg Pass Rate',
                color: const Color(0xFF22C55E),
              ),
              _buildStatCard(
                width: cardWidth,
                icon: Icons.timer,
                value: '${stats.avgCompletionTime.toStringAsFixed(1)}h',
                label: 'Avg Completion Time',
                color: const Color(0xFFF97316),
              ),
              _buildStatCard(
                width: cardWidth,
                icon: Icons.speed,
                value: '${(stats.slaComplianceRate * 100).toStringAsFixed(1)}%',
                label: 'SLA Compliance',
                color: const Color(0xFF8B5CF6),
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
        onRetry: () => ref.invalidate(aggregatedPerformanceStatsProvider),
      ),
    );
  }

  Widget _buildStatCard({
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
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
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

  Widget _buildMonthlyPerformanceChart(AsyncValue<Map<String, dynamic>> asyncData) {
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
              'Monthly Task Completion',
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
              child: asyncData.when(
                data: (data) => _buildBarChart(data),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text('Failed to load: $error')),
              ),
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

  Widget _buildBarChart(Map<String, dynamic> data) {
    // Aggregate monthly data from all collaborators
    final monthlyData = <String, Map<String, int>>{};
    
    final collaborators = (data['content'] as List<dynamic>? ?? [])
        .map((e) => CollaboratorPerformance.fromJson(e as Map<String, dynamic>))
        .toList();

    for (final collab in collaborators) {
      // Simulate monthly breakdown data
      for (int i = 5; i >= 0; i--) {
        final now = DateTime.now();
        final month = DateTime(now.year, now.month - i, 1);
        final monthKey = '${month.year}-${month.month.toString().padLeft(2, '0')}';
        
        monthlyData.putIfAbsent(monthKey, () => {'pass': 0, 'fail': 0});
        
        // Distribute tasks across months
        final tasksPerMonth = collab.totalTasks ~/ 6;
        final passTasks = (tasksPerMonth * collab.passRate).round();
        final failTasks = tasksPerMonth - passTasks;
        
        monthlyData[monthKey]!['pass'] = monthlyData[monthKey]!['pass']! + passTasks;
        monthlyData[monthKey]!['fail'] = monthlyData[monthKey]!['fail']! + failTasks;
      }
    }

    final sortedMonths = monthlyData.keys.toList()..sort();
    if (sortedMonths.isEmpty) {
      return const EmptyState(
        icon: Icons.bar_chart,
        message: 'No performance data available',
      );
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 100,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final month = sortedMonths[groupIndex];
              final rodType = rodIndex == 0 ? 'Pass' : 'Fail';
              return BarTooltipItem(
                '$month\n$rodType: ${rod.toY.toInt()}',
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
                if (index < 0 || index >= sortedMonths.length) return const SizedBox();
                final month = sortedMonths[index];
                final parts = month.split('-');
                if (parts.length == 2) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${parts[1]}/${parts[0].substring(2)}',
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                }
                return const SizedBox();
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
        barGroups: sortedMonths.asMap().entries.map((entry) {
          final pass = monthlyData[entry.value]!['pass']!.toDouble();
          final fail = monthlyData[entry.value]!['fail']!.toDouble();
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: pass,
                color: const Color(0xFF22C55E),
                width: 16,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: pass + fail,
                  color: AdminTheme.outlineLight.withOpacity(0.5),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPerformanceTable(AsyncValue<Map<String, dynamic>> asyncData) {
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
                  'Performance Details',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                DropdownButton<String>(
                  value: _sortBy,
                  items: const [
                    DropdownMenuItem(value: 'totalTasks', child: Text('Sort by Tasks')),
                    DropdownMenuItem(value: 'passRate', child: Text('Sort by Pass Rate')),
                    DropdownMenuItem(value: 'avgCompletionTimeHours', child: Text('Sort by Avg Time')),
                    DropdownMenuItem(value: 'slaComplianceRate', child: Text('Sort by SLA')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _sortBy = value;
                      });
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            asyncData.when(
              data: (data) {
                final collaborators = (data['content'] as List<dynamic>? ?? [])
                    .map((e) => CollaboratorPerformance.fromJson(e as Map<String, dynamic>))
                    .toList();

                if (collaborators.isEmpty) {
                  return const EmptyState(
                    icon: Icons.people,
                    message: 'No collaborator data available',
                  );
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                      AdminTheme.primaryTeal.withOpacity(0.05),
                    ),
                    sortColumnIndex: _sortColumnIndex,
                    sortAscending: _sortAscending,
                    columns: [
                      DataColumn(
                        label: const Text('Collaborator'),
                        onSort: (_, __) {
                          setState(() {
                            _sortColumnIndex = 0;
                            _sortAscending = !_sortAscending;
                          });
                        },
                      ),
                      const DataColumn(label: Text('Total Tasks'), numeric: true),
                      const DataColumn(label: Text('Pass Rate')),
                      const DataColumn(label: Text('Avg Time'), numeric: true),
                      const DataColumn(label: Text('Avg Distance'), numeric: true),
                      const DataColumn(label: Text('SLA Compliance')),
                    ],
                    rows: collaborators.map((collab) {
                      return DataRow(
                        cells: [
                          DataCell(
                            InkWell(
                              onTap: () => context.push('/collaborators/${collab.collaboratorId}/performance'),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: AdminTheme.primaryTeal.withOpacity(0.1),
                                    child: Text(
                                      collab.fullName.isNotEmpty 
                                          ? collab.fullName[0].toUpperCase() 
                                          : '?',
                                      style: TextStyle(
                                        color: AdminTheme.primaryTeal,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(collab.fullName.isNotEmpty ? collab.fullName : 'Unknown'),
                                ],
                              ),
                            ),
                          ),
                          DataCell(Text(collab.totalTasks.toString())),
                          DataCell(_buildPassRateCell(collab.passRate)),
                          DataCell(Text('${collab.avgCompletionTimeHours.toStringAsFixed(1)}h')),
                          DataCell(Text('${collab.avgDistanceMeters.toStringAsFixed(0)}m')),
                          DataCell(_buildSlaComplianceBadge(collab.slaComplianceRate)),
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
                      Text('Failed to load: $error'),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          ref.invalidate(collaboratorPerformanceListProvider(
                            CollaboratorPerformanceParams(),
                          ));
                        },
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

  Widget _buildPassRateCell(double passRate) {
    final percentage = (passRate * 100).toStringAsFixed(0);
    Color color;
    if (passRate >= 0.8) {
      color = const Color(0xFF22C55E);
    } else if (passRate >= 0.5) {
      color = const Color(0xFFF97316);
    } else {
      color = const Color(0xFFEF4444);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 60,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: passRate,
              backgroundColor: AdminTheme.outlineLight,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$percentage%',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildSlaComplianceBadge(double slaRate) {
    final percentage = (slaRate * 100).toStringAsFixed(0);
    Color color;
    if (slaRate >= 0.9) {
      color = const Color(0xFF22C55E);
    } else if (slaRate >= 0.7) {
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
        '$percentage%',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
