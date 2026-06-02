import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';
import '../models/battery_swap_trust.dart';
import '../providers/battery_swap_trust_providers.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_scaffold.dart';

/// Swap Trust Dashboard Screen
/// Shows battery swap trust score metrics and distribution
class SwapTrustDashboardScreen extends ConsumerStatefulWidget {
  final String? stationId;

  const SwapTrustDashboardScreen({
    super.key,
    this.stationId,
  });

  @override
  ConsumerState<SwapTrustDashboardScreen> createState() => _SwapTrustDashboardScreenState();
}

class _SwapTrustDashboardScreenState extends ConsumerState<SwapTrustDashboardScreen> {
  String? _currentStationId;

  @override
  void initState() {
    super.initState();
    if (widget.stationId != null) {
      _currentStationId = widget.stationId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AdminScaffold(
      title: 'Battery Swap Trust Dashboard',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Station ID Input (if no station selected)
            if (_currentStationId == null) ...[
              _buildStationIdInput(theme),
              const SizedBox(height: 24),
            ],

            // Station Selector
            if (_currentStationId != null) ...[
              _buildStationSelector(theme),
              const SizedBox(height: 24),
              _buildTrustScoreDisplay(theme),
            ] else ...[
              // Summary Dashboard
              _buildSummaryDashboard(theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStationIdInput(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter Station ID',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter a battery swap station ID to view its trust score and breakdown, '
              'or leave empty to view the overall trust summary.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: 'Station ID (UUID)',
                      hintText: 'Enter station UUID...',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.search),
                    ),
                    onSubmitted: (value) {
                      if (value.trim().isNotEmpty) {
                        setState(() {
                          _currentStationId = value.trim();
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStationSelector(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.battery_charging_full, color: AdminTheme.primaryTeal),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Station ID',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  Text(
                    _currentStationId!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _currentStationId = null;
                });
              },
              icon: const Icon(Icons.dashboard),
              label: const Text('View Summary'),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () {
                context.push('/battery-swap/change-requests');
              },
              icon: const Icon(Icons.list),
              tooltip: 'View Change Requests',
              color: AdminTheme.primaryTeal,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrustScoreDisplay(ThemeData theme) {
    final trustAsync = ref.watch(batterySwapTrustProvider(_currentStationId!));

    return trustAsync.when(
      data: (trust) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Score Overview Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Trust Score',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: trust.scoreColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: trust.scoreColor, width: 2),
                                  ),
                                  child: Text(
                                    trust.score.toString(),
                                    style: theme.textTheme.headlineMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: trust.scoreColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      trust.levelLabel,
                                      style: theme.textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: trust.scoreColor,
                                      ),
                                    ),
                                    Text(
                                      'Level: ${trust.levelLabel}',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          Icon(
                            trust.levelIcon,
                            size: 64,
                            color: trust.scoreColor,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            trust.levelLabel,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: trust.scoreColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Last updated: ${_formatDateTime(trust.updatedAt)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Dimension Breakdown
          _buildDimensionBreakdown(theme, trust),
        ],
      ),
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: LoadingState(message: 'Loading trust score...'),
        ),
      ),
      error: (error, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: ErrorState(
            title: 'Could not load trust score',
            message: formatApiError(error),
            code: extractErrorCode(error),
            traceId: extractTraceId(error),
            onRetry: () {
              ref.invalidate(batterySwapTrustProvider(_currentStationId!));
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryDashboard(ThemeData theme) {
    final summaryAsync = ref.watch(batterySwapTrustSummaryProvider);

    return summaryAsync.when(
      data: (summary) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overview Stats
          Row(
            children: [
              _buildOverviewStatCard(
                theme,
                icon: Icons.electric_bolt,
                label: 'Total Stations',
                value: summary.totalStations.toString(),
                color: AdminTheme.primaryTeal,
              ),
              const SizedBox(width: 16),
              _buildOverviewStatCard(
                theme,
                icon: Icons.trending_up,
                label: 'Average Score',
                value: summary.averageScore.toStringAsFixed(1),
                color: Colors.blue,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Distribution Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trust Score Distribution',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildDistributionChart(theme, summary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Top/Bottom Stations
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildTopStationsCard(theme, summary.topStations, true),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTopStationsCard(theme, summary.bottomStations, false),
              ),
            ],
          ),
        ],
      ),
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: LoadingState(message: 'Loading summary...'),
        ),
      ),
      error: (error, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: ErrorState(
            title: 'Could not load trust summary',
            message: formatApiError(error),
            code: extractErrorCode(error),
            traceId: extractTraceId(error),
            onRetry: () {
              ref.invalidate(batterySwapTrustSummaryProvider);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewStatCard(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 32),
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

  Widget _buildDistributionChart(ThemeData theme, BatterySwapTrustSummary summary) {
    final total = summary.totalStations;
    if (total == 0) {
      return Center(
        child: Text(
          'No data available',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      );
    }

    final highPercent = (summary.highCount / total * 100).toStringAsFixed(1);
    final mediumPercent = (summary.mediumCount / total * 100).toStringAsFixed(1);
    final lowPercent = (summary.lowCount / total * 100).toStringAsFixed(1);

    return Column(
      children: [
        // Bar chart representation
        Container(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              if (summary.highCount > 0)
                Expanded(
                  flex: summary.highCount,
                  child: Container(
                    color: Colors.green,
                    alignment: Alignment.center,
                    child: summary.highCount > 2
                        ? Text(
                            '${summary.highCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                ),
              if (summary.mediumCount > 0)
                Expanded(
                  flex: summary.mediumCount,
                  child: Container(
                    color: Colors.orange,
                    alignment: Alignment.center,
                    child: summary.mediumCount > 2
                        ? Text(
                            '${summary.mediumCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                ),
              if (summary.lowCount > 0)
                Expanded(
                  flex: summary.lowCount,
                  child: Container(
                    color: Colors.red,
                    alignment: Alignment.center,
                    child: summary.lowCount > 2
                        ? Text(
                            '${summary.lowCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildLegendItem(theme, 'High', summary.highCount, highPercent, Colors.green),
            _buildLegendItem(theme, 'Medium', summary.mediumCount, mediumPercent, Colors.orange),
            _buildLegendItem(theme, 'Low', summary.lowCount, lowPercent, Colors.red),
          ],
        ),
      ],
    );
  }

  Widget _buildLegendItem(ThemeData theme, String label, int count, String percent, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$label ($count)',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '$percent%',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTopStationsCard(
    ThemeData theme,
    List<BatterySwapTrustStationSummary> stations,
    bool isTop,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isTop ? Icons.arrow_upward : Icons.arrow_downward,
                  color: isTop ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  isTop ? 'Top Stations' : 'Bottom Stations',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (stations.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No data available',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ),
              )
            else
              ...stations.map((station) => _buildStationListItem(theme, station)),
          ],
        ),
      ),
    );
  }

  Widget _buildStationListItem(ThemeData theme, BatterySwapTrustStationSummary station) {
    final color = _getLevelColor(station.level);
    return InkWell(
      onTap: () {
        setState(() {
          _currentStationId = station.stationId;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: theme.colorScheme.outline.withOpacity(0.1),
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                station.score.toString(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    station.stationName ?? 'Unknown',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'ID: ${station.stationId.substring(0, 8)}...',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              _getLevelIcon(station.level),
              color: color,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDimensionBreakdown(ThemeData theme, BatterySwapTrust trust) {
    final weights = {
      'Verification': {'weight': '30%', 'icon': Icons.verified},
      'Completion': {'weight': '25%', 'icon': Icons.task_alt},
      'Quality': {'weight': '25%', 'icon': Icons.high_quality},
      'Satisfaction': {'weight': '20%', 'icon': Icons.sentiment_satisfied},
    };

    final components = trust.componentScores.entries
        .where((e) => e.value != null)
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: AdminTheme.primaryTeal),
                const SizedBox(width: 8),
                Text(
                  'Trust Component Breakdown',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Weighted scoring: Verification (30%) + Completion (25%) + Quality (25%) + Satisfaction (20%)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 24),
            if (components.isEmpty)
              Center(
                child: Text(
                  'No breakdown data available',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              )
            else
              ...components.map((entry) {
                final meta = weights[entry.key] ?? {'weight': '', 'icon': Icons.help};
                return _buildComponentBar(
                  theme,
                  entry.key,
                  entry.value!,
                  meta['weight']! as String,
                  meta['icon'] as IconData,
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildComponentBar(
    ThemeData theme,
    String component,
    int score,
    String weight,
    IconData icon,
  ) {
    final color = _getScoreColor(score);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  component,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  weight,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$score / 100',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 10,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(5),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: score / 100,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getLevelIcon(String level) {
    switch (level.toUpperCase()) {
      case 'EXCELLENT':
        return Icons.stars;
      case 'GOOD':
        return Icons.verified;
      case 'HIGH':
        return Icons.verified;
      case 'FAIR':
        return Icons.check_circle_outline;
      case 'MEDIUM':
        return Icons.check_circle_outline;
      case 'POOR':
        return Icons.warning;
      case 'LOW':
        return Icons.warning;
      case 'NEW':
      case 'NEW_ENTITY':
        return Icons.fiber_new;
      default:
        return Icons.help_outline;
    }
  }

  Color _getLevelColor(String level) {
    switch (level.toUpperCase()) {
      case 'EXCELLENT':
        return Colors.green.shade700;
      case 'GOOD':
      case 'HIGH':
        return Colors.green;
      case 'FAIR':
      case 'MEDIUM':
        return Colors.orange;
      case 'POOR':
      case 'LOW':
        return Colors.red;
      case 'NEW':
      case 'NEW_ENTITY':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Color _getScoreColor(int score) {
    if (score >= 70) return Colors.green;
    if (score >= 40) return Colors.orange;
    return Colors.red;
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
