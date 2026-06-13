import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';
import '../models/battery_swap_change_request.dart';
import '../providers/battery_swap_cr_providers.dart';
import '../theme/admin_theme.dart';
import '../utils/responsive_utils.dart';
import '../widgets/admin_scaffold.dart';

/// Battery Swap Change Requests List Screen
class BatterySwapCRListScreen extends ConsumerStatefulWidget {
  const BatterySwapCRListScreen({super.key});

  @override
  ConsumerState<BatterySwapCRListScreen> createState() =>
      _BatterySwapCRListScreenState();
}

class _BatterySwapCRListScreenState
    extends ConsumerState<BatterySwapCRListScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filters = ref.watch(batterySwapCRFiltersProvider);
    final crsAsync = ref.watch(batterySwapCRListProvider);

    return AdminScaffold(
      title: 'Battery Swap Change Requests',
      body: Padding(
        padding: EdgeInsets.all(responsivePadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filters
            _buildFilterPanel(theme, filters),
            const SizedBox(height: 24),

            // Stats Row
            _buildStatsRow(theme, crsAsync),
            const SizedBox(height: 24),

            // Change Requests Table
            Expanded(
              child: Card(
                margin: EdgeInsets.zero,
                child: crsAsync.when(
                  data: (crs) => _buildCRsTable(theme, crs),
                  loading: () => LoadingState(message: 'Loading change requests...'),
                  error: (error, stack) => ErrorState(
                    title: 'Could not load change requests',
                    message: formatApiError(error),
                    code: extractErrorCode(error),
                    traceId: extractTraceId(error),
                    onRetry: () {
                      ref.invalidate(batterySwapCRListProvider);
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

  Widget _buildFilterPanel(ThemeData theme, BatterySwapCRFilters filters) {
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
            'Filter:',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(width: 16),
          // Status Filter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.colorScheme.outline),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<BatterySwapCRStatus?>(
                value: filters.status,
                hint: Text('All Status', style: theme.textTheme.bodyMedium),
                items: [
                  const DropdownMenuItem<BatterySwapCRStatus?>(
                    value: null,
                    child: Text('All Status'),
                  ),
                  ...BatterySwapCRStatus.values.map((status) =>
                      DropdownMenuItem<BatterySwapCRStatus>(
                        value: status,
                        child: Text(status.displayName),
                      )),
                ],
                onChanged: (value) {
                  ref.read(batterySwapCRFiltersProvider.notifier).state =
                      filters.copyWith(status: value, clearStatus: value == null);
                },
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Risk Level Filter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.colorScheme.outline),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<BatterySwapRiskLevel?>(
                value: filters.riskLevel,
                hint: Text('All Risk Levels', style: theme.textTheme.bodyMedium),
                items: [
                  const DropdownMenuItem<BatterySwapRiskLevel?>(
                    value: null,
                    child: Text('All Risk Levels'),
                  ),
                  ...BatterySwapRiskLevel.values.map((level) =>
                      DropdownMenuItem<BatterySwapRiskLevel>(
                        value: level,
                        child: Text(level.displayName),
                      )),
                ],
                onChanged: (value) {
                  ref.read(batterySwapCRFiltersProvider.notifier).state =
                      filters.copyWith(riskLevel: value, clearRiskLevel: value == null);
                },
              ),
            ),
          ),
          const Spacer(),
          // Refresh Button
          IconButton(
            onPressed: () => ref.invalidate(batterySwapCRListProvider),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            color: AdminTheme.primaryTeal,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(ThemeData theme, AsyncValue<List<BatterySwapChangeRequest>> crsAsync) {
    int total = 0;
    int pending = 0;
    int approved = 0;
    int rejected = 0;
    int highRisk = 0;

    crsAsync.whenData((crs) {
      total = crs.length;
      for (final cr in crs) {
        switch (cr.status) {
          case BatterySwapCRStatus.pending:
            pending++;
            break;
          case BatterySwapCRStatus.approved:
            approved++;
            break;
          case BatterySwapCRStatus.rejected:
            rejected++;
            break;
          default:
            break;
        }
        if (cr.isHighRisk) highRisk++;
      }
    });

    return Row(
      children: [
        _buildStatCard(
          theme,
          icon: Icons.description,
          label: 'Total',
          value: total.toString(),
          color: AdminTheme.primaryTeal,
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          theme,
          icon: Icons.pending_actions,
          label: 'Pending',
          value: pending.toString(),
          color: Colors.orange,
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          theme,
          icon: Icons.check_circle,
          label: 'Approved',
          value: approved.toString(),
          color: Colors.green,
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          theme,
          icon: Icons.cancel,
          label: 'Rejected',
          value: rejected.toString(),
          color: Colors.red,
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          theme,
          icon: Icons.warning,
          label: 'High Risk',
          value: highRisk.toString(),
          color: Colors.deepOrange,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Card(
        margin: EdgeInsets.zero,
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 4),
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

  Widget _buildCRsTable(
      ThemeData theme, List<BatterySwapChangeRequest> crs) {
    if (crs.isEmpty) {
      return EmptyState(
        icon: Icons.description_outlined,
        message: 'No battery swap change requests found',
        action: OutlinedButton.icon(
          onPressed: () => ref.invalidate(batterySwapCRListProvider),
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
            color: AdminTheme.surfaceLight,
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outline.withOpacity(0.2),
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  'Station',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  'Type',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  'Status',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  'Risk',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Submitter',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  'Date',
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
            itemCount: crs.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: theme.colorScheme.outline.withOpacity(0.1),
            ),
            itemBuilder: (context, index) {
              final cr = crs[index];
              return _buildCRRow(theme, cr);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCRRow(ThemeData theme, BatterySwapChangeRequest cr) {
    return InkWell(
      onTap: () => context.push('/battery-swap/change-requests/${cr.id}'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cr.stationName ?? 'Unknown Station',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    cr.stationId.isNotEmpty
                        ? 'ID: ${cr.stationId.substring(0, 8)}...'
                        : 'ID: N/A',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: Chip(
                avatar: Icon(
                  _getTypeIcon(cr.type),
                  size: 16,
                ),
                label: Text(cr.type.displayName),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
            ),
            Expanded(
              flex: 1,
              child: StatusPill(
                label: cr.status.displayName,
                colorMapper: (label) {
                  switch (cr.status) {
                    case BatterySwapCRStatus.pending:
                      return Colors.orange;
                    case BatterySwapCRStatus.approved:
                      return Colors.green;
                    case BatterySwapCRStatus.rejected:
                      return Colors.red;
                    case BatterySwapCRStatus.published:
                      return AdminTheme.primaryTeal;
                    case BatterySwapCRStatus.draft:
                      return Colors.grey;
                  }
                },
              ),
            ),
            Expanded(
              flex: 1,
              child: _buildRiskBadge(theme, cr.riskScore),
            ),
            Expanded(
              flex: 2,
              child: Text(
                cr.submittedByEmail ?? cr.submittedBy ?? 'N/A',
                style: theme.textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                cr.submittedAt != null
                    ? _formatDateTime(cr.submittedAt!)
                    : 'N/A',
                style: theme.textTheme.bodySmall,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => context.push('/battery-swap/change-requests/${cr.id}'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRiskBadge(ThemeData theme, int? riskScore) {
    if (riskScore == null) {
      return Text(
        'N/A',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withOpacity(0.4),
        ),
      );
    }

    final color = _getRiskColor(riskScore);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        '$riskScore',
        style: theme.textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  IconData _getTypeIcon(BatterySwapCRType type) {
    switch (type) {
      case BatterySwapCRType.create:
        return Icons.add_circle;
      case BatterySwapCRType.update:
        return Icons.edit;
      case BatterySwapCRType.delete:
        return Icons.delete;
    }
  }

  Color _getRiskColor(int riskScore) {
    if (riskScore >= 60) return Colors.red;
    if (riskScore >= 30) return Colors.orange;
    if (riskScore >= 15) return Colors.yellow.shade700;
    return Colors.green;
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}
