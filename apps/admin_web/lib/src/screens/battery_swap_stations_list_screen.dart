import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_api/shared_api.dart';
import 'package:shared_ui/shared_ui.dart';
import '../models/battery_swap_station.dart';
import '../models/pagination_response.dart';
import '../providers/battery_swap_station_providers.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_scaffold.dart';

/// Battery Swap Stations List Screen
class BatterySwapStationsListScreen extends ConsumerStatefulWidget {
  const BatterySwapStationsListScreen({super.key});

  @override
  ConsumerState<BatterySwapStationsListScreen> createState() => _BatterySwapStationsListScreenState();
}

class _BatterySwapStationsListScreenState extends ConsumerState<BatterySwapStationsListScreen> {
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
    final stationsAsync =
        ref.watch(batterySwapStationsProvider((page: page, size: pageSize, search: search)));

    return AdminScaffold(
      title: 'Battery Swap Stations',
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: stationsAsync.when(
                    data: (response) => Row(
                      children: [
                        Text(
                          'Battery Swap Stations',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AdminTheme.primaryTeal.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AdminTheme.primaryTeal.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.battery_charging_full,
                                size: 18,
                                color: AdminTheme.primaryTeal,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${response.totalElements} stations',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AdminTheme.primaryTeal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    loading: () => Text(
                      'Battery Swap Stations',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    error: (_, __) => Text(
                      'Battery Swap Stations',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                stationsAsync.when(
                  data: (response) => response.content.isNotEmpty
                      ? PopupMenuButton<String>(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          tooltip: 'Delete Station',
                          onSelected: (stationId) {
                            final station = response.content.firstWhere(
                              (s) => s.id == stationId,
                            );
                            _showDeleteDialog(context, ref, station);
                          },
                          itemBuilder: (context) => response.content.map((station) {
                            return PopupMenuItem<String>(
                              value: station.id,
                              child: Row(
                                children: [
                                  const Icon(Icons.delete_outline,
                                      size: 18, color: Colors.red),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      station.name ?? station.id.substring(0, 8),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        )
                      : const SizedBox.shrink(),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search bar
            SizedBox(
              width: 400,
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
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
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
            ),
            const SizedBox(height: 24),

            // Stations Table
            Expanded(
              child: Card(
                margin: EdgeInsets.zero,
                child: stationsAsync.when(
                  data: (response) =>
                      _buildStationsTable(context, ref, theme, response),
                  loading: () => const LoadingState(
                      message: 'Loading battery swap stations...'),
                  error: (error, stack) => ErrorState(
                    title: 'Could not load stations',
                    message: formatApiError(error),
                    code: extractErrorCode(error),
                    traceId: extractTraceId(error),
                    onRetry: () {
                      ref.invalidate(
                          batterySwapStationsProvider((page: page, size: pageSize, search: search)));
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

  Widget _buildStationsTable(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    PaginationResponse<BatterySwapStation> response,
  ) {
    if (response.content.isEmpty) {
      return EmptyState(
        icon: Icons.battery_charging_full,
        title: 'No battery swap stations yet',
        message:
            'Battery swap stations will appear here once they are created.',
      );
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Name')),
                DataColumn(label: Text('Location')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Batteries')),
                DataColumn(label: Text('Piles')),
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
                          Text(
                            station.name ?? 'Unnamed',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (station.pendingCRs > 0)
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border:
                                    Border.all(color: Colors.orange, width: 1),
                              ),
                              child: Text(
                                '${station.pendingCRs} pending',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: Colors.orange.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 180,
                        child: Text(
                          station.address ?? 'N/A',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(_buildStatusChip(theme, station)),
                    DataCell(Text(
                      station.totalBatteries != null
                          ? '${station.availableBatteries ?? '?'}/${station.totalBatteries}'
                          : 'N/A',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _getBatteryColor(
                            station.availableBatteries, station.totalBatteries),
                      ),
                    )),
                    DataCell(Text(station.totalPiles?.toString() ?? 'N/A')),
                    DataCell(_buildTrustBadge(theme, station)),
                    DataCell(Text(station.pendingCRs.toString())),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.visibility, size: 20),
                            onPressed: () {
                              context.push('/battery-swap/stations/${station.id}');
                            },
                            tooltip: 'View Details',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                            onPressed: () {
                              _showDeleteDialog(context, ref, station);
                            },
                            tooltip: 'Delete Station',
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),

        // Pagination
        if (response.totalPages > 1)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                    color: theme.colorScheme.outline.withOpacity(0.2)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Page ${response.page + 1} of ${response.totalPages} (${response.totalElements} total)',
                  style: theme.textTheme.bodySmall,
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: response.first
                          ? null
                          : () {
                              ref.read(batterySwapStationsPageProvider.notifier).state--;
                            },
                    ),
                    Text('${response.page + 1}'),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: response.last
                          ? null
                          : () {
                              ref.read(batterySwapStationsPageProvider.notifier).state++;
                            },
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildStatusChip(ThemeData theme, BatterySwapStation station) {
    final status = station.workflowStatus;
    if (status == null) {
      return Chip(
        label: const Text('No Version'),
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        labelStyle: theme.textTheme.labelSmall,
      );
    }

    Color backgroundColor;
    Color textColor;

    switch (status.toUpperCase()) {
      case 'PUBLISHED':
        backgroundColor = Colors.green.shade50;
        textColor = Colors.green.shade700;
        break;
      case 'PENDING':
        backgroundColor = Colors.orange.shade50;
        textColor = Colors.orange.shade700;
        break;
      case 'DRAFT':
        backgroundColor = theme.colorScheme.surfaceContainerHighest;
        textColor = theme.colorScheme.onSurfaceVariant;
        break;
      case 'REJECTED':
        backgroundColor = Colors.red.shade50;
        textColor = Colors.red.shade700;
        break;
      default:
        backgroundColor = theme.colorScheme.surfaceContainerHighest;
        textColor = theme.colorScheme.onSurfaceVariant;
    }

    return Chip(
      label: Text(status.toUpperCase()),
      backgroundColor: backgroundColor,
      labelStyle: theme.textTheme.labelSmall?.copyWith(color: textColor),
    );
  }

  Widget _buildTrustBadge(ThemeData theme, BatterySwapStation station) {
    final score = station.trustScore;
    if (score == null) {
      return Text(
        'N/A',
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      );
    }

    final color = score >= 70
        ? Colors.green
        : score >= 40
            ? Colors.orange
            : Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$score',
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
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
            content: Text('Error: ${formatApiError(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
