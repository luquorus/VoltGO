import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:shared_api/shared_api.dart';
import 'package:shared_ui/shared_ui.dart';
import '../models/admin_station.dart';
import '../models/battery_swap_station.dart';
import '../models/pagination_response.dart';
import '../providers/station_providers.dart';
import '../providers/battery_swap_station_providers.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_scaffold.dart';
import '../utils/responsive_utils.dart';

/// Unified Stations List Screen with subtabs for Charging and Battery Swap stations
class UnifiedStationsListScreen extends ConsumerStatefulWidget {
  final int initialTabIndex;
  const UnifiedStationsListScreen({super.key, this.initialTabIndex = 0});

  @override
  ConsumerState<UnifiedStationsListScreen> createState() => _UnifiedStationsListScreenState();
}

class _UnifiedStationsListScreenState extends ConsumerState<UnifiedStationsListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTabIndex);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Stations',
      body: Padding(
        padding: responsivePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSubtabBar(context),
            SizedBox(height: isMobile(context) ? 16 : 24),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  _ChargingStationsTab(),
                  _BatterySwapStationsTab(),
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
    final mobile = isMobile(context);
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
        labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: mobile ? 12 : 14),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.normal, fontSize: mobile ? 12 : 14),
        dividerColor: Colors.transparent,
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.ev_station, size: mobile ? 16 : 18),
                if (!mobile) ...[
                  const SizedBox(width: 8),
                  const Text('Charging Stations'),
                ],
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.battery_charging_full, size: mobile ? 16 : 18),
                if (!mobile) ...[
                  const SizedBox(width: 8),
                  const Text('Battery Swap'),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Charging Stations Tab
class _ChargingStationsTab extends ConsumerStatefulWidget {
  const _ChargingStationsTab();

  @override
  ConsumerState<_ChargingStationsTab> createState() => _ChargingStationsTabState();
}

class _ChargingStationsTabState extends ConsumerState<_ChargingStationsTab> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final page = ref.watch(stationsPageProvider);
    final pageSize = ref.watch(stationsPageSizeProvider);
    final search = ref.watch(stationsSearchProvider);
    final stationsAsync = ref.watch(stationsProvider((page: page, size: pageSize, search: search)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context, theme, stationsAsync),
        const SizedBox(height: 16),
        _buildSearchBar(context, ref, search),
        const SizedBox(height: 24),
        Expanded(
          child: Card(
            margin: EdgeInsets.zero,
            child: stationsAsync.when(
              data: (response) => _buildStationsTable(context, theme, ref, response),
              loading: () => const LoadingState(message: 'Loading stations...'),
              error: (error, stack) => ErrorState(
                title: 'Could not load stations',
                message: formatApiError(error),
                code: extractErrorCode(error),
                traceId: extractTraceId(error),
                onRetry: () {
                  ref.invalidate(stationsProvider((page: page, size: pageSize, search: search)));
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme, AsyncValue<PaginationResponse<AdminStation>> stationsAsync) {
    final mobile = isMobile(context);
    return mobile
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              stationsAsync.when(
                data: (response) => Text('Charging Stations', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                loading: () => Text('Charging Stations', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                error: (_, __) => Text('Charging Stations', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => context.push('/stations/import-csv'),
                    icon: const Icon(Icons.upload_file, size: 16),
                    label: const Text('Import'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/stations/create'),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Create'),
                  ),
                ],
              ),
            ],
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              stationsAsync.when(
                data: (response) => Row(
                  children: [
                    Text('Charging Stations', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AdminTheme.primaryTeal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AdminTheme.primaryTeal.withOpacity(0.3), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.ev_station, size: 18, color: AdminTheme.primaryTeal),
                          const SizedBox(width: 6),
                          Text('${response.totalElements} stations',
                              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: AdminTheme.primaryTeal)),
                        ],
                      ),
                    ),
                  ],
                ),
                loading: () => Text('Charging Stations', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                error: (_, __) => Text('Charging Stations', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => context.push('/stations/import-csv'),
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Import CSV'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/stations/create'),
                    icon: const Icon(Icons.add),
                    label: const Text('Create station'),
                  ),
                ],
              ),
            ],
          );
  }

  Widget _buildSearchBar(BuildContext context, WidgetRef ref, String? search) {
    return SizedBox(
      width: isMobile(context) ? double.infinity : 400,
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search by name or ID...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: search != null && search.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    ref.read(stationsSearchProvider.notifier).state = null;
                    ref.read(stationsPageProvider.notifier).state = 0;
                  },
                )
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: (value) {
          ref.read(stationsSearchProvider.notifier).state = value.isEmpty ? null : value;
          ref.read(stationsPageProvider.notifier).state = 0;
        },
        onSubmitted: (_) {
          ref.read(stationsPageProvider.notifier).state = 0;
        },
      ),
    );
  }

  Widget _buildStationsTable(BuildContext context, ThemeData theme, WidgetRef ref, PaginationResponse<AdminStation> response) {
    if (response.content.isEmpty) {
      return EmptyState(
        icon: Icons.ev_station,
        title: 'No charging stations yet',
        message: 'Create a new station or import data from CSV to get started.',
        action: ElevatedButton.icon(
          onPressed: () => context.push('/stations/create'),
          icon: const Icon(Icons.add),
          label: const Text('Create new station'),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Address')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Trust Score')),
                  DataColumn(label: Text('Versions')),
                  DataColumn(label: Text('Bookings')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: response.content.map((station) {
                  return DataRow(
                    cells: [
                      DataCell(Text(station.name ?? 'N/A')),
                      DataCell(SizedBox(width: 200, child: Text(station.address ?? 'N/A', overflow: TextOverflow.ellipsis))),
                      DataCell(_buildStatusChip(theme, station)),
                      DataCell(Text(station.trustScore?.toString() ?? 'N/A',
                          style: TextStyle(fontWeight: FontWeight.bold, color: _getTrustScoreColor(theme, station.trustScore)))),
                      DataCell(Text(station.totalVersions.toString())),
                      DataCell(Text(station.activeBookings.toString(),
                          style: TextStyle(color: station.hasActiveBookings ? theme.colorScheme.error : theme.colorScheme.onSurface))),
                      DataCell(Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: const Icon(Icons.visibility, size: 20),
                              onPressed: () => context.push('/stations/${station.stationId}'), tooltip: 'View Details'),
                          IconButton(icon: const Icon(Icons.edit, size: 20),
                              onPressed: () => context.push('/stations/${station.stationId}'), tooltip: 'View/Edit'),
                          IconButton(icon: const Icon(Icons.delete, size: 20),
                              onPressed: station.hasActiveBookings ? null : () => _showDeleteDialog(context, theme, ref, station),
                              tooltip: station.hasActiveBookings ? 'Cannot delete: has active bookings' : 'Delete',
                              color: station.hasActiveBookings ? theme.colorScheme.error.withOpacity(0.5) : theme.colorScheme.error),
                        ],
                      )),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        if (response.totalPages > 1) _buildPagination(context, theme, ref, response),
      ],
    );
  }

  Widget _buildPagination(BuildContext context, ThemeData theme, WidgetRef ref, PaginationResponse<AdminStation> response) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: theme.colorScheme.outline.withOpacity(0.2)))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Page ${response.page + 1} of ${response.totalPages} (${response.totalElements} total)', style: theme.textTheme.bodySmall),
          Row(
            children: [
              IconButton(icon: const Icon(Icons.chevron_left),
                  onPressed: response.first ? null : () => ref.read(stationsPageProvider.notifier).state--),
              Text('${response.page + 1}'),
              IconButton(icon: const Icon(Icons.chevron_right),
                  onPressed: response.last ? null : () => ref.read(stationsPageProvider.notifier).state++),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(ThemeData theme, AdminStation station) {
    if (station.workflowStatus == null) {
      return Chip(label: const Text('No Version'), backgroundColor: theme.colorScheme.surfaceContainerHighest, labelStyle: theme.textTheme.labelSmall);
    }
    final status = station.workflowStatus!;
    Color backgroundColor, textColor;
    switch (status) {
      case WorkflowStatus.published:
        backgroundColor = theme.colorScheme.primaryContainer; textColor = theme.colorScheme.onPrimaryContainer; break;
      case WorkflowStatus.draft:
        backgroundColor = theme.colorScheme.surfaceContainerHighest; textColor = theme.colorScheme.onSurfaceVariant; break;
      case WorkflowStatus.pending:
        backgroundColor = theme.colorScheme.tertiaryContainer; textColor = theme.colorScheme.onTertiaryContainer; break;
      case WorkflowStatus.rejected:
        backgroundColor = theme.colorScheme.errorContainer; textColor = theme.colorScheme.onErrorContainer; break;
      case WorkflowStatus.archived:
        backgroundColor = theme.colorScheme.surfaceContainerHighest; textColor = theme.colorScheme.onSurfaceVariant; break;
    }
    return Chip(label: Text(status.name.toUpperCase()), backgroundColor: backgroundColor, labelStyle: theme.textTheme.labelSmall?.copyWith(color: textColor));
  }

  Color _getTrustScoreColor(ThemeData theme, int? score) {
    if (score == null) return theme.colorScheme.onSurfaceVariant;
    if (score >= 80) return theme.colorScheme.primary;
    if (score >= 60) return theme.colorScheme.tertiary;
    return theme.colorScheme.error;
  }

  void _showDeleteDialog(BuildContext context, ThemeData theme, WidgetRef ref, AdminStation station) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Station'),
        content: Text('Are you sure you want to delete station "${station.name}"? This will archive all versions.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                final factory = ref.read(apiClientFactoryProvider);
                if (factory == null) throw Exception('API client not initialized');
                await factory.admin.deleteStation(station.stationId);
                ref.invalidate(stationsProvider((page: ref.read(stationsPageProvider), size: ref.read(stationsPageSizeProvider), search: ref.read(stationsSearchProvider))));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Station deleted successfully'), backgroundColor: Colors.green, duration: Duration(seconds: 3)),
                  );
                }
              } catch (e) {
                String errorMessage = 'Error deleting station';
                if (e is DioException && e.response?.data is Map<String, dynamic>) {
                  errorMessage = (e.response!.data as Map<String, dynamic>)['message'] as String? ?? 'Server error: ${e.response!.statusCode}';
                } else if (e is DioException) {
                  errorMessage = 'Connection error: ${e.message}';
                } else {
                  errorMessage = 'Error: $e';
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Row(children: [
                      const Icon(Icons.error_outline, color: Colors.white), const SizedBox(width: 12),
                      Expanded(child: Text(errorMessage, style: const TextStyle(fontWeight: FontWeight.bold))),
                    ]), backgroundColor: Colors.red, duration: const Duration(seconds: 5), behavior: SnackBarBehavior.floating),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

/// Battery Swap Stations Tab
class _BatterySwapStationsTab extends ConsumerStatefulWidget {
  const _BatterySwapStationsTab();

  @override
  ConsumerState<_BatterySwapStationsTab> createState() => _BatterySwapStationsTabState();
}

class _BatterySwapStationsTabState extends ConsumerState<_BatterySwapStationsTab> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final page = ref.watch(batterySwapStationsPageProvider);
    final pageSize = ref.watch(batterySwapStationsPageSizeProvider);
    final search = ref.watch(batterySwapStationsSearchProvider);
    final stationsAsync = ref.watch(batterySwapStationsProvider((page: page, size: pageSize, search: search)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context, theme, stationsAsync),
        const SizedBox(height: 16),
        _buildSearchBar(context, ref, search),
        const SizedBox(height: 24),
        Expanded(
          child: Card(
            margin: EdgeInsets.zero,
            child: stationsAsync.when(
              data: (response) => _buildStationsTable(context, theme, ref, response),
              loading: () => const LoadingState(message: 'Loading battery swap stations...'),
              error: (error, stack) => ErrorState(
                title: 'Could not load stations',
                message: formatApiError(error),
                code: extractErrorCode(error),
                traceId: extractTraceId(error),
                onRetry: () {
                  ref.invalidate(batterySwapStationsProvider((page: page, size: pageSize, search: search)));
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme, AsyncValue<PaginationResponse<BatterySwapStation>> stationsAsync) {
    final mobile = isMobile(context);
    return mobile
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              stationsAsync.when(
                data: (response) => Text('Battery Swap Stations', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                loading: () => Text('Battery Swap Stations', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                error: (_, __) => Text('Battery Swap Stations', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => context.push('/battery-swap/stations/import-csv'),
                    icon: const Icon(Icons.upload_file, size: 16),
                    label: const Text('Import'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/battery-swap/stations/create'),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Create'),
                  ),
                ],
              ),
            ],
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              stationsAsync.when(
                data: (response) => Row(
                  children: [
                    Text('Battery Swap Stations', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AdminTheme.primaryTeal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AdminTheme.primaryTeal.withOpacity(0.3), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.battery_charging_full, size: 18, color: AdminTheme.primaryTeal),
                          const SizedBox(width: 6),
                          Text('${response.totalElements} stations',
                              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: AdminTheme.primaryTeal)),
                        ],
                      ),
                    ),
                  ],
                ),
                loading: () => Text('Battery Swap Stations', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                error: (_, __) => Text('Battery Swap Stations', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => context.push('/battery-swap/stations/import-csv'),
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Import CSV'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/battery-swap/stations/create'),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Station'),
                  ),
                ],
              ),
            ],
          );
  }

  Widget _buildSearchBar(BuildContext context, WidgetRef ref, String? search) {
    return SizedBox(
      width: isMobile(context) ? double.infinity : 400,
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search by name or ID...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: search != null && search.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    ref.read(batterySwapStationsSearchProvider.notifier).state = null;
                    ref.read(batterySwapStationsPageProvider.notifier).state = 0;
                  },
                )
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: (value) {
          ref.read(batterySwapStationsSearchProvider.notifier).state = value.isEmpty ? null : value;
          ref.read(batterySwapStationsPageProvider.notifier).state = 0;
        },
        onSubmitted: (_) {
          ref.read(batterySwapStationsPageProvider.notifier).state = 0;
        },
      ),
    );
  }

  Widget _buildStationsTable(BuildContext context, ThemeData theme, WidgetRef ref, PaginationResponse<BatterySwapStation> response) {
    if (response.content.isEmpty) {
      return EmptyState(
        icon: Icons.battery_charging_full,
        title: 'No battery swap stations yet',
        message: 'Battery swap stations will appear here once they are created.',
      );
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Location')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Batteries')),
                  DataColumn(label: Text('Piles × Pins')),
                  DataColumn(label: Text('Trust')),
                  DataColumn(label: Text('Pending CRs')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: response.content.map((station) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(station.name ?? 'Unnamed', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                            if (station.pendingCRs > 0)
                              Container(
                                margin: const EdgeInsets.only(top: 2),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.orange, width: 1),
                                ),
                                child: Text('${station.pendingCRs} pending',
                                    style: theme.textTheme.labelSmall?.copyWith(color: Colors.orange.shade700, fontWeight: FontWeight.w600)),
                              ),
                          ],
                        ),
                      ),
                      DataCell(SizedBox(width: 180, child: Text(station.address ?? 'N/A', overflow: TextOverflow.ellipsis))),
                      DataCell(_buildStatusChip(theme, station)),
                      DataCell(Text(
                          station.totalBatteries != null ? '${station.availableBatteries ?? '?'}/${station.totalBatteries}' : 'N/A',
                          style: TextStyle(fontWeight: FontWeight.bold, color: _getBatteryColor(station.availableBatteries, station.totalBatteries)))),
                      DataCell(Text(
                          (station.totalPiles != null && station.totalSlots != null)
                              ? '${station.totalPiles} × ${station.totalSlots! ~/ station.totalPiles!}'
                              : 'N/A')),
                      DataCell(_buildTrustBadge(theme, station)),
                      DataCell(Text(station.pendingCRs.toString())),
                      DataCell(Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: const Icon(Icons.visibility, size: 20),
                              onPressed: () => context.push('/battery-swap/stations/${station.id}'), tooltip: 'View Details'),
                          IconButton(icon: const Icon(Icons.delete, size: 20),
                              onPressed: () => _showDeleteDialog(context, ref, station),
                              tooltip: 'Delete',
                              color: Colors.red),
                        ],
                      )),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        if (response.totalPages > 1) _buildPagination(context, theme, ref, response),
      ],
    );
  }

  Widget _buildPagination(BuildContext context, ThemeData theme, WidgetRef ref, PaginationResponse<BatterySwapStation> response) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: theme.colorScheme.outline.withOpacity(0.2)))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Page ${response.page + 1} of ${response.totalPages} (${response.totalElements} total)', style: theme.textTheme.bodySmall),
          Row(
            children: [
              IconButton(icon: const Icon(Icons.chevron_left),
                  onPressed: response.first ? null : () => ref.read(batterySwapStationsPageProvider.notifier).state--),
              Text('${response.page + 1}'),
              IconButton(icon: const Icon(Icons.chevron_right),
                  onPressed: response.last ? null : () => ref.read(batterySwapStationsPageProvider.notifier).state++),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(ThemeData theme, BatterySwapStation station) {
    final status = station.workflowStatus;
    if (status == null) {
      return Chip(label: const Text('No Version'), backgroundColor: theme.colorScheme.surfaceContainerHighest, labelStyle: theme.textTheme.labelSmall);
    }

    Color backgroundColor, textColor;
    switch (status.toUpperCase()) {
      case 'PUBLISHED':
        backgroundColor = Colors.green.shade50; textColor = Colors.green.shade700; break;
      case 'PENDING':
        backgroundColor = Colors.orange.shade50; textColor = Colors.orange.shade700; break;
      case 'DRAFT':
        backgroundColor = theme.colorScheme.surfaceContainerHighest; textColor = theme.colorScheme.onSurfaceVariant; break;
      case 'REJECTED':
        backgroundColor = Colors.red.shade50; textColor = Colors.red.shade700; break;
      default:
        backgroundColor = theme.colorScheme.surfaceContainerHighest; textColor = theme.colorScheme.onSurfaceVariant;
    }
    return Chip(label: Text(status.toUpperCase()), backgroundColor: backgroundColor, labelStyle: theme.textTheme.labelSmall?.copyWith(color: textColor));
  }

  Widget _buildTrustBadge(ThemeData theme, BatterySwapStation station) {
    final score = station.trustScore;
    if (score == null) {
      return Text('N/A', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant));
    }
    final color = score >= 70 ? Colors.green : score >= 40 ? Colors.orange : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color, width: 1)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$score', style: theme.textTheme.bodySmall?.copyWith(color: color, fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          Icon(Icons.star, size: 12, color: color),
        ],
      ),
    );
  }

  Color _getBatteryColor(int? available, int? total) {
    if (available == null || total == null) return Colors.grey;
    final ratio = available / total;
    if (ratio >= 0.5) return Colors.green;
    if (ratio >= 0.2) return Colors.orange;
    return Colors.red;
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, BatterySwapStation station) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Station'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${station.name ?? station.id}"?\n\n'
          'This will permanently remove the station and all related data (change requests, versions, piles, state, trust records). '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await _handleDelete(context, ref, station);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDelete(
    BuildContext context,
    WidgetRef ref,
    BatterySwapStation station,
  ) async {
    try {
      final factory = ref.read(apiClientFactoryProvider);
      if (factory == null) throw Exception('API client not initialized');

      await factory.admin.deleteBatterySwapStation(station.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Station deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        ref.invalidate(batterySwapStationsProvider((page: 0, size: 20, search: null)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
