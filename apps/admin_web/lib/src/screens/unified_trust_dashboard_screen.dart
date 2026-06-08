import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_api/shared_api.dart';
import 'package:shared_ui/shared_ui.dart';
import '../models/station_trust.dart';
import '../models/station_trust_summary.dart';
import '../models/battery_swap_trust.dart';
import '../providers/station_trust_providers.dart';
import '../providers/battery_swap_trust_providers.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_scaffold.dart';

/// Unified Trust Dashboard Screen with subtabs for Charging and Battery Swap stations
class UnifiedTrustDashboardScreen extends ConsumerStatefulWidget {
  final String? stationId;
  final String? batterySwapStationId;

  const UnifiedTrustDashboardScreen({
    super.key,
    this.stationId,
    this.batterySwapStationId,
  });

  @override
  ConsumerState<UnifiedTrustDashboardScreen> createState() => _UnifiedTrustDashboardScreenState();
}

class _UnifiedTrustDashboardScreenState extends ConsumerState<UnifiedTrustDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _chargingStationId;
  String? _batterySwapStationId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _chargingStationId = widget.stationId;
    _batterySwapStationId = widget.batterySwapStationId;
    if (_chargingStationId != null || _batterySwapStationId != null) {
      _tabController.addListener(_handleTabSwitch);
    }
  }

  void _handleTabSwitch() {
    if (!_tabController.indexIsChanging) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSwitch);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Trust Dashboard',
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSubtabBar(context),
            const SizedBox(height: 24),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _ChargingStationTrustTab(
                    initialStationId: _chargingStationId,
                    onStationIdChanged: (id) => setState(() => _chargingStationId = id),
                  ),
                  _BatterySwapTrustTab(
                    initialStationId: _batterySwapStationId,
                    onStationIdChanged: (id) => setState(() => _batterySwapStationId = id),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubtabBar(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AdminTheme.primaryTeal,
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.7),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 14),
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.ev_station, size: 18),
                SizedBox(width: 8),
                Text('Charging Stations'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.battery_charging_full, size: 18),
                SizedBox(width: 8),
                Text('Battery Swap'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Charging Station Trust Tab
class _ChargingStationTrustTab extends ConsumerStatefulWidget {
  final String? initialStationId;
  final void Function(String?) onStationIdChanged;

  const _ChargingStationTrustTab({
    this.initialStationId,
    required this.onStationIdChanged,
  });

  @override
  ConsumerState<_ChargingStationTrustTab> createState() => _ChargingStationTrustTabState();
}

class _ChargingStationTrustTabState extends ConsumerState<_ChargingStationTrustTab> {
  late String? _currentStationId;

  @override
  void initState() {
    super.initState();
    _currentStationId = widget.initialStationId;
  }

  Future<void> _handleRecalculate(String stationId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Recalculate Trust Score'),
        content: const Text(
          'Are you sure you want to recalculate the trust score for this station? '
          'This will update the score and breakdown based on current data.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.primaryTeal, foregroundColor: Colors.white),
            child: const Text('Recalculate'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final repository = ref.read(stationTrustRepositoryProvider);
      await repository.recalculateStationTrust(stationId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trust score recalculated successfully'), backgroundColor: Colors.green),
        );
      }
      ref.invalidate(stationTrustProvider(stationId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${formatApiError(e)}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_currentStationId == null) ...[
            _buildStationIdInput(theme),
            const SizedBox(height: 24),
            _buildSummaryDashboard(theme),
          ] else ...[
            _buildStationSelector(theme),
            const SizedBox(height: 24),
            _buildTrustScoreDisplay(theme),
          ],
        ],
      ),
    );
  }

  Widget _buildStationIdInput(ThemeData theme) {
    final controller = TextEditingController();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter Station ID', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Enter a charging station ID to view its trust score and breakdown, '
              'or leave empty to view the overall trust summary.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Station ID (UUID)',
                hintText: 'Enter station UUID...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  setState(() => _currentStationId = value.trim());
                  widget.onStationIdChanged(_currentStationId);
                }
              },
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
            Icon(Icons.electric_bolt, color: AdminTheme.primaryTeal),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Station ID', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6))),
                  Text(_currentStationId!, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _currentStationId = null;
                  widget.onStationIdChanged(null);
                });
              },
              icon: const Icon(Icons.dashboard),
              label: const Text('View Summary'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrustScoreDisplay(ThemeData theme) {
    final trustAsync = ref.watch(stationTrustProvider(_currentStationId!));
    return trustAsync.when(
      data: (trust) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildScoreOverviewCard(theme, trust),
          const SizedBox(height: 24),
          _buildDimensionBreakdown(theme, trust),
        ],
      ),
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(48), child: LoadingState(message: 'Loading trust score...'))),
      error: (error, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: ErrorState(
            title: 'Could not load trust score',
            message: formatApiError(error),
            code: extractErrorCode(error),
            traceId: extractTraceId(error),
            onRetry: () => ref.invalidate(stationTrustProvider(_currentStationId!)),
          ),
        ),
      ),
    );
  }

  Widget _buildScoreOverviewCard(ThemeData theme, StationTrust trust) {
    return Card(
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
                      Text('Trust Score', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
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
                            child: Text(trust.score.toStringAsFixed(1),
                                style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: trust.scoreColor)),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(trust.levelLabel, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: trust.scoreColor)),
                              Text('Level: ${trust.levelLabel}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6))),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Icon(trust.levelIcon, size: 64, color: trust.scoreColor),
                    const SizedBox(height: 8),
                    Text(trust.levelLabel, style: theme.textTheme.titleMedium?.copyWith(color: trust.scoreColor, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('Last updated: ${_formatDateTime(trust.updatedAt)}',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6))),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => _handleRecalculate(_currentStationId!),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Recalculate Trust'),
                  style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.primaryTeal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDimensionBreakdown(ThemeData theme, StationTrust trust) {
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
                Text('Trust Breakdown', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    const encoder = JsonEncoder.withIndent('  ');
                    Clipboard.setData(ClipboardData(text: encoder.convert(trust.breakdown)));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Breakdown JSON copied to clipboard'), duration: Duration(seconds: 2), behavior: SnackBarBehavior.floating),
                    );
                  },
                  tooltip: 'Copy JSON to clipboard',
                  color: AdminTheme.primaryTeal,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildBreakdownView(theme, trust.breakdown),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownView(ThemeData theme, Map<String, dynamic> breakdown) {
    if (breakdown.isEmpty) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('No breakdown data available', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6), fontStyle: FontStyle.italic))));
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AdminTheme.surfaceLight, borderRadius: BorderRadius.circular(8), border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2))),
      child: _buildBreakdownTree(theme, breakdown, 0),
    );
  }

  Widget _buildBreakdownTree(ThemeData theme, Map<String, dynamic> data, int indentLevel) {
    final entries = data.entries.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: entries.map((entry) {
        final indent = indentLevel * 24.0;
        return Padding(
          padding: EdgeInsets.only(left: indent, bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 200, child: Text(entry.key, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
              const SizedBox(width: 16),
              Expanded(child: _buildValueWidget(theme, entry.value, indentLevel + 1)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildValueWidget(ThemeData theme, dynamic value, int indentLevel) {
    if (value is Map<String, dynamic>) return _buildBreakdownTree(theme, value, indentLevel);
    if (value is List) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: value.asMap().entries.map((entry) {
          return Padding(
            padding: EdgeInsets.only(left: indentLevel * 24.0, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${entry.key}:', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface.withOpacity(0.6))),
                const SizedBox(width: 8),
                Expanded(child: _buildValueWidget(theme, entry.value, indentLevel + 1)),
              ],
            ),
          );
        }).toList(),
      );
    }
    return Text(value.toString(), style: theme.textTheme.bodyMedium);
  }

  Widget _buildSummaryDashboard(ThemeData theme) {
    final summaryAsync = ref.watch(_chargingTrustSummaryProvider);
    return summaryAsync.when(
      data: (summary) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildOverviewStatCard(theme, icon: Icons.electric_bolt, label: 'Total Stations', value: summary.totalStations.toString(), color: AdminTheme.primaryTeal),
              const SizedBox(width: 16),
              _buildOverviewStatCard(theme, icon: Icons.trending_up, label: 'Average Score', value: summary.averageScore.toStringAsFixed(1), color: Colors.blue),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Trust Score Distribution', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  _buildDistributionChart(theme, summary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildTopStationsCard(theme, summary.topStations, true)),
              const SizedBox(width: 16),
              Expanded(child: _buildTopStationsCard(theme, summary.bottomStations, false)),
            ],
          ),
        ],
      ),
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(48), child: LoadingState(message: 'Loading summary...'))),
      error: (error, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: ErrorState(
            title: 'Could not load trust summary',
            message: formatApiError(error),
            code: extractErrorCode(error),
            traceId: extractTraceId(error),
            onRetry: () => ref.invalidate(_chargingTrustSummaryProvider),
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewStatCard(ThemeData theme, {required IconData icon, required String label, required String value, required Color color}) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 32)),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6))),
                  Text(value, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDistributionChart(ThemeData theme, StationTrustSummary summary) {
    final total = summary.totalStations;
    if (total == 0) {
      return Center(child: Text('No data available', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6))));
    }
    final highPercent = (summary.highCount / total * 100).toStringAsFixed(1);
    final mediumPercent = (summary.mediumCount / total * 100).toStringAsFixed(1);
    final lowPercent = (summary.lowCount / total * 100).toStringAsFixed(1);

    return Column(
      children: [
        Container(
          height: 48,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
          child: Row(
            children: [
              if (summary.highCount > 0)
                Expanded(flex: summary.highCount, child: Container(color: Colors.green, alignment: Alignment.center,
                    child: summary.highCount > 2 ? Text('${summary.highCount}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)) : null)),
              if (summary.mediumCount > 0)
                Expanded(flex: summary.mediumCount, child: Container(color: Colors.orange, alignment: Alignment.center,
                    child: summary.mediumCount > 2 ? Text('${summary.mediumCount}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)) : null)),
              if (summary.lowCount > 0)
                Expanded(flex: summary.lowCount, child: Container(color: Colors.red, alignment: Alignment.center,
                    child: summary.lowCount > 2 ? Text('${summary.lowCount}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)) : null)),
            ],
          ),
        ),
        const SizedBox(height: 16),
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
        Container(width: 16, height: 16, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$label ($count)', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
            Text('$percent%', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6))),
          ],
        ),
      ],
    );
  }

  Widget _buildTopStationsCard(ThemeData theme, List<StationTrustStationSummary> stations, bool isTop) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isTop ? Icons.arrow_upward : Icons.arrow_downward, color: isTop ? Colors.green : Colors.red),
                const SizedBox(width: 8),
                Text(isTop ? 'Top Stations' : 'Bottom Stations', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            if (stations.isEmpty)
              Center(child: Padding(padding: const EdgeInsets.all(16), child: Text('No data available', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6)))))
            else
              ...stations.map((station) => _buildStationListItem(theme, station)),
          ],
        ),
      ),
    );
  }

  Widget _buildStationListItem(ThemeData theme, StationTrustStationSummary station) {
    final color = _getLevelColor(station.level);
    return InkWell(
      onTap: () {
        setState(() => _currentStationId = station.stationId);
        widget.onStationIdChanged(station.stationId);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.colorScheme.outline.withOpacity(0.1)))),
        child: Row(
          children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                alignment: Alignment.center, child: Text(station.score.toStringAsFixed(1), style: theme.textTheme.bodyMedium?.copyWith(color: color, fontWeight: FontWeight.bold))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(station.stationName ?? 'Unknown', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                  Text('ID: ${station.stationId.length > 8 ? station.stationId.substring(0, 8) : station.stationId}...', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6))),
                ],
              ),
            ),
            Icon(_getLevelIcon(station.level), color: color, size: 20),
          ],
        ),
      ),
    );
  }

  IconData _getLevelIcon(String level) {
    switch (level.toUpperCase()) {
      case 'GOOD': return Icons.verified;
      case 'FAIR': return Icons.check_circle_outline;
      case 'POOR': case 'VERY POOR': return Icons.warning;
      default: return Icons.help_outline;
    }
  }

  Color _getLevelColor(String level) {
    switch (level.toUpperCase()) {
      case 'GOOD': return Colors.green;
      case 'FAIR': return Colors.orange;
      case 'POOR': case 'VERY POOR': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

final _chargingTrustSummaryProvider = FutureProvider<StationTrustSummary>((ref) async {
  final factory = ref.watch(apiClientFactoryProvider);
  if (factory == null) throw Exception('API client not initialized');
  try {
    final response = await factory.admin.getStationsTrustSummary();
    return StationTrustSummary.fromJson(response);
  } catch (e) {
    throw Exception('Failed to get trust summary: $e');
  }
});

/// Battery Swap Trust Tab
class _BatterySwapTrustTab extends ConsumerStatefulWidget {
  final String? initialStationId;
  final void Function(String?) onStationIdChanged;

  const _BatterySwapTrustTab({
    this.initialStationId,
    required this.onStationIdChanged,
  });

  @override
  ConsumerState<_BatterySwapTrustTab> createState() => _BatterySwapTrustTabState();
}

class _BatterySwapTrustTabState extends ConsumerState<_BatterySwapTrustTab> {
  late String? _currentStationId;

  @override
  void initState() {
    super.initState();
    _currentStationId = widget.initialStationId;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_currentStationId == null) ...[
            _buildStationIdInput(theme),
            const SizedBox(height: 24),
            _buildSummaryDashboard(theme),
          ] else ...[
            _buildStationSelector(theme),
            const SizedBox(height: 24),
            _buildTrustScoreDisplay(theme),
          ],
        ],
      ),
    );
  }

  Widget _buildStationIdInput(ThemeData theme) {
    final controller = TextEditingController();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter Station ID', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Enter a battery swap station ID to view its trust score and breakdown, '
              'or leave empty to view the overall trust summary.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Station ID (UUID)',
                hintText: 'Enter station UUID...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  setState(() => _currentStationId = value.trim());
                  widget.onStationIdChanged(_currentStationId);
                }
              },
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
                  Text('Station ID', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6))),
                  Text(_currentStationId!, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _currentStationId = null;
                  widget.onStationIdChanged(null);
                });
              },
              icon: const Icon(Icons.dashboard),
              label: const Text('View Summary'),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => context.push('/battery-swap/change-requests'),
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
                            Text('Trust Score', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
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
                                  child: Text(trust.score.toString(), style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: trust.scoreColor)),
                                ),
                                const SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(trust.levelLabel, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: trust.scoreColor)),
                                    Text('Level: ${trust.levelLabel}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6))),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          Icon(trust.levelIcon, size: 64, color: trust.scoreColor),
                          const SizedBox(height: 8),
                          Text(trust.levelLabel, style: theme.textTheme.titleMedium?.copyWith(color: trust.scoreColor, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Last updated: ${_formatDate(trust.updatedAt)}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildDimensionBreakdown(theme, trust),
        ],
      ),
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(48), child: LoadingState(message: 'Loading trust score...'))),
      error: (error, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: ErrorState(
            title: 'Could not load trust score',
            message: formatApiError(error),
            code: extractErrorCode(error),
            traceId: extractTraceId(error),
            onRetry: () => ref.invalidate(batterySwapTrustProvider(_currentStationId!)),
          ),
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
    final components = trust.componentScores.entries.where((e) => e.value != null).toList();

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
                Text('Trust Component Breakdown', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text('Weighted scoring: Verification (30%) + Completion (25%) + Quality (25%) + Satisfaction (20%)',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.5))),
            const SizedBox(height: 24),
            if (components.isEmpty)
              Center(child: Text('No breakdown data available', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6))))
            else
              ...components.map((entry) {
                final meta = weights[entry.key] ?? {'weight': '', 'icon': Icons.help};
                return _buildComponentBar(theme, entry.key, entry.value!, (meta['weight'] as String), (meta['icon'] as IconData));
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildComponentBar(ThemeData theme, String component, int score, String weight, IconData icon) {
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
              Expanded(child: Text(component, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(4)),
                child: Text(weight, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6), fontWeight: FontWeight.w500)),
              ),
              const SizedBox(width: 12),
              Text('$score / 100', style: theme.textTheme.bodyMedium?.copyWith(color: color, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 10,
            decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(5)),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: score / 100,
              child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryDashboard(ThemeData theme) {
    final summaryAsync = ref.watch(batterySwapTrustSummaryProvider);
    return summaryAsync.when(
      data: (summary) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildOverviewStatCard(theme, icon: Icons.electric_bolt, label: 'Total Stations', value: summary.totalStations.toString(), color: AdminTheme.primaryTeal),
              const SizedBox(width: 16),
              _buildOverviewStatCard(theme, icon: Icons.trending_up, label: 'Average Score', value: summary.averageScore.toStringAsFixed(1), color: Colors.blue),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Trust Score Distribution', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  _buildDistributionChart(theme, summary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildTopStationsCard(theme, summary.topStations, true)),
              const SizedBox(width: 16),
              Expanded(child: _buildTopStationsCard(theme, summary.bottomStations, false)),
            ],
          ),
        ],
      ),
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(48), child: LoadingState(message: 'Loading summary...'))),
      error: (error, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: ErrorState(
            title: 'Could not load trust summary',
            message: formatApiError(error),
            code: extractErrorCode(error),
            traceId: extractTraceId(error),
            onRetry: () => ref.invalidate(batterySwapTrustSummaryProvider),
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewStatCard(ThemeData theme, {required IconData icon, required String label, required String value, required Color color}) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 32)),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6))),
                  Text(value, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
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
      return Center(child: Text('No data available', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6))));
    }
    final highPercent = (summary.highCount / total * 100).toStringAsFixed(1);
    final mediumPercent = (summary.mediumCount / total * 100).toStringAsFixed(1);
    final lowPercent = (summary.lowCount / total * 100).toStringAsFixed(1);

    return Column(
      children: [
        Container(
          height: 48,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
          child: Row(
            children: [
              if (summary.highCount > 0)
                Expanded(flex: summary.highCount, child: Container(color: Colors.green, alignment: Alignment.center,
                    child: summary.highCount > 2 ? Text('${summary.highCount}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)) : null)),
              if (summary.mediumCount > 0)
                Expanded(flex: summary.mediumCount, child: Container(color: Colors.orange, alignment: Alignment.center,
                    child: summary.mediumCount > 2 ? Text('${summary.mediumCount}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)) : null)),
              if (summary.lowCount > 0)
                Expanded(flex: summary.lowCount, child: Container(color: Colors.red, alignment: Alignment.center,
                    child: summary.lowCount > 2 ? Text('${summary.lowCount}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)) : null)),
            ],
          ),
        ),
        const SizedBox(height: 16),
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
        Container(width: 16, height: 16, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$label ($count)', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
            Text('$percent%', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6))),
          ],
        ),
      ],
    );
  }

  Widget _buildTopStationsCard(ThemeData theme, List<BatterySwapTrustStationSummary> stations, bool isTop) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isTop ? Icons.arrow_upward : Icons.arrow_downward, color: isTop ? Colors.green : Colors.red),
                const SizedBox(width: 8),
                Text(isTop ? 'Top Stations' : 'Bottom Stations', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            if (stations.isEmpty)
              Center(child: Padding(padding: const EdgeInsets.all(16), child: Text('No data available', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6)))))
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
        setState(() => _currentStationId = station.stationId);
        widget.onStationIdChanged(station.stationId);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.colorScheme.outline.withOpacity(0.1)))),
        child: Row(
          children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                alignment: Alignment.center, child: Text(station.score.toString(), style: theme.textTheme.bodyMedium?.copyWith(color: color, fontWeight: FontWeight.bold))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(station.stationName ?? 'Unknown', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                  Text('ID: ${station.stationId.length > 8 ? station.stationId.substring(0, 8) : station.stationId}...', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6))),
                ],
              ),
            ),
            Icon(_getLevelIcon(station.level), color: color, size: 20),
          ],
        ),
      ),
    );
  }

  IconData _getLevelIcon(String level) {
    switch (level.toUpperCase()) {
      case 'EXCELLENT': return Icons.stars;
      case 'GOOD': case 'HIGH': return Icons.verified;
      case 'FAIR': case 'MEDIUM': return Icons.check_circle_outline;
      case 'POOR': case 'LOW': return Icons.warning;
      case 'NEW': case 'NEW_ENTITY': return Icons.fiber_new;
      default: return Icons.help_outline;
    }
  }

  Color _getLevelColor(String level) {
    switch (level.toUpperCase()) {
      case 'EXCELLENT': return Colors.green.shade700;
      case 'GOOD': case 'HIGH': return Colors.green;
      case 'FAIR': case 'MEDIUM': return Colors.orange;
      case 'POOR': case 'LOW': return Colors.red;
      case 'NEW': case 'NEW_ENTITY': return Colors.blue;
      default: return Colors.grey;
    }
  }

  Color _getScoreColor(int score) {
    if (score >= 70) return Colors.green;
    if (score >= 40) return Colors.orange;
    return Colors.red;
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
