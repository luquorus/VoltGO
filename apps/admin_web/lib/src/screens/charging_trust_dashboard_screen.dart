import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_api/shared_api.dart';
import 'package:shared_ui/shared_ui.dart';
import '../models/station_trust.dart';
import '../models/station_trust_summary.dart';
import '../providers/station_trust_providers.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_scaffold.dart';
import '../widgets/station_search_dropdown.dart';
import '../utils/responsive_utils.dart';

/// Charging Station Trust Dashboard
///
/// Shows aggregate trust metrics for charging stations and a per-station
/// trust score / breakdown view. Use `?stationId=<uuid>` in the URL to
/// land directly on a station's trust profile.
class ChargingTrustDashboardScreen extends ConsumerStatefulWidget {
  final String? stationId;

  const ChargingTrustDashboardScreen({super.key, this.stationId});

  @override
  ConsumerState<ChargingTrustDashboardScreen> createState() => _ChargingTrustDashboardScreenState();
}

class _ChargingTrustDashboardScreenState extends ConsumerState<ChargingTrustDashboardScreen> {
  String? _currentStationId;
  String? _selectedStationName;

  @override
  void initState() {
    super.initState();
    // Guard against non-UUID query params (e.g. ?stationId=) which would
    // otherwise fire a trust call rejected by the backend with EVS-0002.
    _currentStationId = _isValidUuid(widget.stationId) ? widget.stationId : null;
  }

  Future<void> _handleRecalculate(String stationId) async {
    final trimmed = stationId.trim();
    if (trimmed.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a station first.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

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
      await repository.recalculateStationTrust(trimmed);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trust score recalculated successfully'), backgroundColor: Colors.green),
        );
      }
      ref.invalidate(stationTrustProvider(trimmed));
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
    return AdminScaffold(
      title: 'Charging Trust Dashboard',
      body: Padding(
        padding: responsivePadding(context),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_currentStationId == null) ...[
                _buildStationIdInput(),
                const SizedBox(height: 24),
                _buildSummaryDashboard(),
              ] else ...[
                _buildStationSelector(),
                const SizedBox(height: 24),
                _buildTrustScoreDisplay(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStationIdInput() {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Search charging station', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Search a charging station by name to view its trust score and breakdown, '
              'or leave empty to view the overall trust summary.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6)),
            ),
            const SizedBox(height: 16),
            StationSearchDropdown(
              stationType: StationType.charging,
              preselectedStationName: _selectedStationName,
              onChanged: (item) {
                setState(() {
                  _currentStationId = item?.id;
                  _selectedStationName = item?.name;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStationSelector() {
    final theme = Theme.of(context);
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
                  Text(
                    _selectedStationName ?? 'Station',
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'ID: ${_currentStationId!.length > 8 ? _currentStationId!.substring(0, 8) : _currentStationId}...',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6)),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _currentStationId = null;
                  _selectedStationName = null;
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

  Widget _buildTrustScoreDisplay() {
    final trustAsync = ref.watch(stationTrustProvider(_currentStationId!));
    final theme = Theme.of(context);
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
                    final encoder = JsonEncoder.withIndent('  ');
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

  Widget _buildSummaryDashboard() {
    final summaryAsync = ref.watch(_chargingTrustSummaryProvider);
    final theme = Theme.of(context);
    return summaryAsync.when(
      data: (summary) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          isMobile(context)
              ? Column(
                  children: [
                    _buildOverviewStatCard(theme, icon: Icons.electric_bolt, label: 'Total Stations', value: summary.totalStations.toString(), color: AdminTheme.primaryTeal),
                    const SizedBox(height: 12),
                    _buildOverviewStatCard(theme, icon: Icons.trending_up, label: 'Average Score', value: summary.averageScore.toStringAsFixed(1), color: Colors.blue),
                  ],
                )
              : Row(
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
          isMobile(context)
              ? Column(
                  children: [
                    _buildTopStationsCard(theme, summary.topStations, true),
                    const SizedBox(height: 16),
                    _buildTopStationsCard(theme, summary.bottomStations, false),
                  ],
                )
              : Row(
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
        setState(() {
          _currentStationId = station.stationId;
          _selectedStationName = station.stationName;
        });
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
  final response = await factory.admin.getStationsTrustSummary();
  return StationTrustSummary.fromJson(response);
});

/// Loose UUID v1-v8 matcher. Used to guard against non-UUID values reaching
/// the trust REST endpoints (path variable `stationId` is typed `UUID` on
/// the backend, so empty / malformed values would be rejected with EVS-0002).
final RegExp _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

bool _isValidUuid(String? value) {
  if (value == null || value.isEmpty) return false;
  return _uuidPattern.hasMatch(value);
}
