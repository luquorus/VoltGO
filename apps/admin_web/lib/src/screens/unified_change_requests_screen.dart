import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';
import '../models/admin_change_request.dart';
import '../models/battery_swap_change_request.dart';
import '../providers/change_request_providers.dart';
import '../providers/battery_swap_cr_providers.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_scaffold.dart';
import '../utils/responsive_utils.dart';

/// Unified Change Requests Screen with subtabs for Charging and Battery Swap stations
class UnifiedChangeRequestsScreen extends ConsumerStatefulWidget {
  const UnifiedChangeRequestsScreen({super.key});

  @override
  ConsumerState<UnifiedChangeRequestsScreen> createState() => _UnifiedChangeRequestsScreenState();
}

class _UnifiedChangeRequestsScreenState extends ConsumerState<UnifiedChangeRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Change Requests',
      body: Padding(
        padding: EdgeInsets.all(responsivePadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSubtabBar(context),
            SizedBox(height: isMobile(context) ? 16 : 24),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  _ChargingChangeRequestsTab(),
                  _BatterySwapChangeRequestsTab(),
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
    final showLabels = !isMobile(context);
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
        labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: isMobile(context) ? 12 : 14),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.normal, fontSize: isMobile(context) ? 12 : 14),
        dividerColor: Colors.transparent,
        tabs: [
          Tab(
            child: showLabels
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.ev_station, size: 18),
                      SizedBox(width: 8),
                      Text('Charging Stations'),
                    ],
                  )
                : const Icon(Icons.ev_station, size: 18),
          ),
          Tab(
            child: showLabels
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.battery_charging_full, size: 18),
                      SizedBox(width: 8),
                      Text('Battery Swap'),
                    ],
                  )
                : const Icon(Icons.battery_charging_full, size: 18),
          ),
        ],
      ),
    );
  }
}

/// Charging Stations Change Requests Tab
class _ChargingChangeRequestsTab extends ConsumerWidget {
  const _ChargingChangeRequestsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final filters = ref.watch(changeRequestFiltersProvider);
    final changeRequestsAsync = ref.watch(changeRequestsProvider);
    final pad = responsiveHPadding(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFilterPanel(context, theme, ref, filters),
        SizedBox(height: isMobile(context) ? 12 : 24),
        _buildStatsRow(context, theme, changeRequestsAsync),
        SizedBox(height: isMobile(context) ? 12 : 24),
        Expanded(
          child: Card(
            margin: EdgeInsets.zero,
            child: changeRequestsAsync.when(
              data: (requests) => _buildChangeRequestsTable(context, theme, ref, requests),
              loading: () => LoadingState(message: 'Loading change requests...'),
              error: (error, stack) => ErrorState(
                title: 'Could not load change requests',
                message: formatApiError(error),
                code: extractErrorCode(error),
                traceId: extractTraceId(error),
                onRetry: () {
                  ref.invalidate(changeRequestsProvider);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterPanel(BuildContext context, ThemeData theme, WidgetRef ref, ChangeRequestFilters filters) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Text('Filter by Status:', style: theme.textTheme.titleSmall),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.colorScheme.outline),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<ChangeRequestStatus?>(
                value: filters.status,
                hint: Text('All Status', style: theme.textTheme.bodyMedium),
                items: [
                  const DropdownMenuItem<ChangeRequestStatus?>(
                    value: null,
                    child: Text('All Status'),
                  ),
                  ...ChangeRequestStatus.values.map((status) =>
                      DropdownMenuItem<ChangeRequestStatus>(
                        value: status,
                        child: Text(status.displayName),
                      )),
                ],
                onChanged: (value) {
                  ref.read(changeRequestFiltersProvider.notifier).state =
                      filters.copyWith(status: value, clearStatus: value == null);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context, ThemeData theme, AsyncValue<List<AdminChangeRequest>> changeRequestsAsync) {
    int total = 0, pending = 0, approved = 0, rejected = 0;
    changeRequestsAsync.whenData((requests) {
      total = requests.length;
      for (final cr in requests) {
        switch (cr.status) {
          case ChangeRequestStatus.pending:
            pending++;
            break;
          case ChangeRequestStatus.approved:
            approved++;
            break;
          case ChangeRequestStatus.rejected:
            rejected++;
            break;
          default:
            break;
        }
      }
    });

    if (isMobile(context)) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _buildStatCard(theme, icon: Icons.description, label: 'Total', value: total.toString(), color: AdminTheme.primaryTeal),
          _buildStatCard(theme, icon: Icons.pending_actions, label: 'Pending', value: pending.toString(), color: Colors.orange),
          _buildStatCard(theme, icon: Icons.check_circle, label: 'Approved', value: approved.toString(), color: Colors.green),
          _buildStatCard(theme, icon: Icons.cancel, label: 'Rejected', value: rejected.toString(), color: Colors.red),
        ],
      );
    }

    return Row(
      children: [
        _buildStatCard(theme, icon: Icons.description, label: 'Total', value: total.toString(), color: AdminTheme.primaryTeal),
        const SizedBox(width: 16),
        _buildStatCard(theme, icon: Icons.pending_actions, label: 'Pending', value: pending.toString(), color: Colors.orange),
        const SizedBox(width: 16),
        _buildStatCard(theme, icon: Icons.check_circle, label: 'Approved', value: approved.toString(), color: Colors.green),
        const SizedBox(width: 16),
        _buildStatCard(theme, icon: Icons.cancel, label: 'Rejected', value: rejected.toString(), color: Colors.red),
      ],
    );
  }

  Widget _buildStatCard(ThemeData theme, {required IconData icon, required String label, required String value, required Color color}) {
    if (isMobile(context)) {
      return SizedBox(
        width: (MediaQuery.of(context).size.width - 48 - 24) / 2,
        child: Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Icon(icon, color: color, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6))),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      );
    }
    return Expanded(
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6))),
                  const SizedBox(height: 4),
                  Text(value, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChangeRequestsTable(BuildContext context, ThemeData theme, WidgetRef ref, List<AdminChangeRequest> requests) {
    if (requests.isEmpty) {
      return EmptyState(
        icon: Icons.description_outlined,
        message: 'No change requests found',
        action: OutlinedButton.icon(
          onPressed: () => ref.invalidate(changeRequestsProvider),
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
        ),
      );
    }

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: AdminTheme.surfaceLight,
              border: Border(bottom: BorderSide(color: theme.colorScheme.outline.withOpacity(0.2))),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: isMobile(context) ? 100 : null,
                  child: Text('Type', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                ),
                SizedBox(width: isMobile(context) ? 12 : 0),
                SizedBox(
                  width: isMobile(context) ? 100 : null,
                  child: Text('Status', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                ),
                SizedBox(width: isMobile(context) ? 12 : 0),
                SizedBox(
                  width: isMobile(context) ? 120 : null,
                  child: Text('Submitter', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                ),
                SizedBox(width: isMobile(context) ? 12 : 0),
                SizedBox(
                  width: isMobile(context) ? 80 : null,
                  child: Text('Risk', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                ),
                SizedBox(width: isMobile(context) ? 12 : 0),
                SizedBox(
                  width: isMobile(context) ? 100 : null,
                  child: Text('Submitted', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: requests.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: theme.colorScheme.outline.withOpacity(0.1)),
            itemBuilder: (context, index) => _buildChangeRequestRow(context, theme, requests[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildChangeRequestRow(BuildContext context, ThemeData theme, AdminChangeRequest cr) {
    return InkWell(
      onTap: () => context.push('/change-requests/${cr.id}'),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              SizedBox(
                width: isMobile(context) ? 100 : null,
                child: Text(cr.type.displayName, style: theme.textTheme.bodyMedium),
              ),
              SizedBox(width: isMobile(context) ? 12 : 0),
              SizedBox(
                width: isMobile(context) ? 100 : null,
                child: StatusPill(
                  label: cr.status.displayName,
                  colorMapper: (label) {
                    switch (cr.status) {
                      case ChangeRequestStatus.pending: return Colors.orange;
                      case ChangeRequestStatus.approved: return Colors.green;
                      case ChangeRequestStatus.rejected: return Colors.red;
                      case ChangeRequestStatus.published: return AdminTheme.primaryTeal;
                      case ChangeRequestStatus.draft: return Colors.grey;
                    }
                  },
                ),
              ),
              SizedBox(width: isMobile(context) ? 12 : 0),
              SizedBox(
                width: isMobile(context) ? 120 : null,
                child: Text(cr.submitterEmail ?? 'N/A', style: theme.textTheme.bodyMedium, overflow: TextOverflow.ellipsis),
              ),
              SizedBox(width: isMobile(context) ? 12 : 0),
              SizedBox(
                width: isMobile(context) ? 80 : null,
                child: Row(children: [
                  if (cr.riskScore != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getRiskColor(cr.riskScore!).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _getRiskColor(cr.riskScore!), width: 1),
                      ),
                      child: Text('${cr.riskScore}', style: theme.textTheme.bodySmall?.copyWith(color: _getRiskColor(cr.riskScore!), fontWeight: FontWeight.w600)),
                    )
                  else
                    Text('N/A', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.4))),
                ]),
              ),
              SizedBox(width: isMobile(context) ? 12 : 0),
              SizedBox(
                width: isMobile(context) ? 100 : null,
                child: Text(cr.submittedAt != null ? _formatDateTime(cr.submittedAt!) : 'N/A', style: theme.textTheme.bodySmall),
              ),
              IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => context.push('/change-requests/${cr.id}')),
            ],
          ),
        ),
      ),
    );
  }

  Color _getRiskColor(int riskScore) {
    if (riskScore >= 60) return Colors.red;
    if (riskScore >= 30) return Colors.orange;
    return Colors.green;
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

/// Battery Swap Change Requests Tab
class _BatterySwapChangeRequestsTab extends ConsumerWidget {
  const _BatterySwapChangeRequestsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final filters = ref.watch(batterySwapCRFiltersProvider);
    final crsAsync = ref.watch(batterySwapCRListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFilterPanel(context, theme, ref, filters),
        SizedBox(height: isMobile(context) ? 12 : 24),
        _buildStatsRow(context, theme, crsAsync),
        SizedBox(height: isMobile(context) ? 12 : 24),
        Expanded(
          child: Card(
            margin: EdgeInsets.zero,
            child: crsAsync.when(
              data: (crs) => _buildCRsTable(context, theme, ref, crs),
              loading: () => LoadingState(message: 'Loading change requests...'),
              error: (error, stack) => ErrorState(
                title: 'Could not load change requests',
                message: formatApiError(error),
                code: extractErrorCode(error),
                traceId: extractTraceId(error),
                onRetry: () => ref.invalidate(batterySwapCRListProvider),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterPanel(BuildContext context, ThemeData theme, WidgetRef ref, BatterySwapCRFilters filters) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Text('Filter:', style: theme.textTheme.titleSmall),
          const SizedBox(width: 16),
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
                  const DropdownMenuItem<BatterySwapCRStatus?>(value: null, child: Text('All Status')),
                  ...BatterySwapCRStatus.values.map((status) =>
                      DropdownMenuItem<BatterySwapCRStatus>(value: status, child: Text(status.displayName))),
                ],
                onChanged: (value) {
                  ref.read(batterySwapCRFiltersProvider.notifier).state =
                      filters.copyWith(status: value, clearStatus: value == null);
                },
              ),
            ),
          ),
          const SizedBox(width: 16),
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
                  const DropdownMenuItem<BatterySwapRiskLevel?>(value: null, child: Text('All Risk Levels')),
                  ...BatterySwapRiskLevel.values.map((level) =>
                      DropdownMenuItem<BatterySwapRiskLevel>(value: level, child: Text(level.displayName))),
                ],
                onChanged: (value) {
                  ref.read(batterySwapCRFiltersProvider.notifier).state =
                      filters.copyWith(riskLevel: value, clearRiskLevel: value == null);
                },
              ),
            ),
          ),
          const Spacer(),
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

  Widget _buildStatsRow(BuildContext context, ThemeData theme, AsyncValue<List<BatterySwapChangeRequest>> crsAsync) {
    int total = 0, pending = 0, approved = 0, rejected = 0, highRisk = 0;
    crsAsync.whenData((crs) {
      total = crs.length;
      for (final cr in crs) {
        switch (cr.status) {
          case BatterySwapCRStatus.pending: pending++; break;
          case BatterySwapCRStatus.approved: approved++; break;
          case BatterySwapCRStatus.rejected: rejected++; break;
          default: break;
        }
        if (cr.isHighRisk) highRisk++;
      }
    });

    if (isMobile(context)) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _buildStatCard(theme, icon: Icons.description, label: 'Total', value: total.toString(), color: AdminTheme.primaryTeal),
          _buildStatCard(theme, icon: Icons.pending_actions, label: 'Pending', value: pending.toString(), color: Colors.orange),
          _buildStatCard(theme, icon: Icons.check_circle, label: 'Approved', value: approved.toString(), color: Colors.green),
          _buildStatCard(theme, icon: Icons.cancel, label: 'Rejected', value: rejected.toString(), color: Colors.red),
          _buildStatCard(theme, icon: Icons.warning, label: 'High Risk', value: highRisk.toString(), color: Colors.deepOrange),
        ],
      );
    }

    return Row(
      children: [
        _buildStatCard(theme, icon: Icons.description, label: 'Total', value: total.toString(), color: AdminTheme.primaryTeal),
        const SizedBox(width: 16),
        _buildStatCard(theme, icon: Icons.pending_actions, label: 'Pending', value: pending.toString(), color: Colors.orange),
        const SizedBox(width: 16),
        _buildStatCard(theme, icon: Icons.check_circle, label: 'Approved', value: approved.toString(), color: Colors.green),
        const SizedBox(width: 16),
        _buildStatCard(theme, icon: Icons.cancel, label: 'Rejected', value: rejected.toString(), color: Colors.red),
        const SizedBox(width: 16),
        _buildStatCard(theme, icon: Icons.warning, label: 'High Risk', value: highRisk.toString(), color: Colors.deepOrange),
      ],
    );
  }

  Widget _buildStatCard(ThemeData theme, {required IconData icon, required String label, required String value, required Color color}) {
    if (isMobile(context)) {
      return SizedBox(
        width: (MediaQuery.of(context).size.width - 48 - 24) / 2,
        child: Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Icon(icon, color: color, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6))),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      );
    }
    return Expanded(
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6))),
                  const SizedBox(height: 4),
                  Text(value, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCRsTable(BuildContext context, ThemeData theme, WidgetRef ref, List<BatterySwapChangeRequest> crs) {
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: AdminTheme.surfaceLight,
            border: Border(bottom: BorderSide(color: theme.colorScheme.outline.withOpacity(0.2))),
          ),
          child: Row(
            children: [
              Expanded(flex: 2, child: Text('Station', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600))),
              Expanded(flex: 1, child: Text('Type', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600))),
              Expanded(flex: 1, child: Text('Status', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600))),
              Expanded(flex: 1, child: Text('Risk', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600))),
              Expanded(flex: 2, child: Text('Submitter', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600))),
              Expanded(flex: 1, child: Text('Date', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600))),
              const SizedBox(width: 48),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: crs.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: theme.colorScheme.outline.withOpacity(0.1)),
            itemBuilder: (context, index) => _buildCRRow(context, theme, crs[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildCRRow(BuildContext context, ThemeData theme, BatterySwapChangeRequest cr) {
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
                  Text(cr.stationName ?? 'Unknown Station', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(
                    cr.stationId.isNotEmpty ? 'ID: ${cr.stationId.substring(0, 8)}...' : 'ID: N/A',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6)),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: Chip(
                avatar: Icon(_getTypeIcon(cr.type), size: 16),
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
                    case BatterySwapCRStatus.pending: return Colors.orange;
                    case BatterySwapCRStatus.approved: return Colors.green;
                    case BatterySwapCRStatus.rejected: return Colors.red;
                    case BatterySwapCRStatus.published: return AdminTheme.primaryTeal;
                    case BatterySwapCRStatus.draft: return Colors.grey;
                  }
                },
              ),
            ),
            Expanded(flex: 1, child: _buildRiskBadge(theme, cr.riskScore)),
            Expanded(flex: 2, child: Text(cr.submittedByEmail ?? cr.submittedBy ?? 'N/A', style: theme.textTheme.bodyMedium, overflow: TextOverflow.ellipsis)),
            Expanded(flex: 1, child: Text(cr.submittedAt != null ? _formatDate(cr.submittedAt!) : 'N/A', style: theme.textTheme.bodySmall)),
            IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => context.push('/battery-swap/change-requests/${cr.id}')),
          ],
        ),
      ),
    );
  }

  Widget _buildRiskBadge(ThemeData theme, int? riskScore) {
    if (riskScore == null) {
      return Text('N/A', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.4)));
    }
    final color = _getRiskColor(riskScore);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1),
      ),
      child: Text('$riskScore', style: theme.textTheme.bodySmall?.copyWith(color: color, fontWeight: FontWeight.w600)),
    );
  }

  IconData _getTypeIcon(BatterySwapCRType type) {
    switch (type) {
      case BatterySwapCRType.create: return Icons.add_circle;
      case BatterySwapCRType.update: return Icons.edit;
      case BatterySwapCRType.delete: return Icons.delete;
    }
  }

  Color _getRiskColor(int riskScore) {
    if (riskScore >= 60) return Colors.red;
    if (riskScore >= 30) return Colors.orange;
    if (riskScore >= 15) return Colors.yellow.shade700;
    return Colors.green;
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}
