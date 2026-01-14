import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:shared_api/shared_api.dart';
import 'package:shared_ui/shared_ui.dart';
import '../models/admin_station.dart';
import '../models/pagination_response.dart';
import '../providers/station_providers.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_scaffold.dart';

/// Stations List Screen
class StationsListScreen extends ConsumerStatefulWidget {
  const StationsListScreen({super.key});

  @override
  ConsumerState<StationsListScreen> createState() => _StationsListScreenState();
}

class _StationsListScreenState extends ConsumerState<StationsListScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final page = ref.watch(stationsPageProvider);
    final pageSize = ref.watch(stationsPageSizeProvider);
    final stationsAsync = ref.watch(stationsProvider((page: page, size: pageSize)));

    return AdminScaffold(
      title: 'Stations',
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Create Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Title with total count
                stationsAsync.when(
                  data: (response) => Row(
                    children: [
                      Text(
                        'All Stations',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                              Icons.ev_station,
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
                    'All Stations',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  error: (_, __) => Text(
                    'All Stations',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        context.push('/stations/import-csv');
                      },
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Import CSV'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        context.push('/stations/create');
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Create Station'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Stations Table
            Expanded(
              child: Card(
                margin: EdgeInsets.zero,
                child: stationsAsync.when(
                  data: (response) => _buildStationsTable(theme, response),
                  loading: () => const LoadingState(message: 'Loading stations...'),
                  error: (error, stack) => ErrorState(
                    message: error.toString(),
                    onRetry: () {
                      ref.invalidate(stationsProvider((page: page, size: pageSize)));
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

  Widget _buildStationsTable(ThemeData theme, PaginationResponse<AdminStation> response) {
    if (response.content.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.ev_station, size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              'No stations found',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Table
        Expanded(
          child: SingleChildScrollView(
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
                    DataCell(
                      SizedBox(
                        width: 200,
                        child: Text(
                          station.address ?? 'N/A',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(_buildStatusChip(theme, station)),
                    DataCell(Text(
                      station.trustScore?.toString() ?? 'N/A',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _getTrustScoreColor(theme, station.trustScore),
                      ),
                    )),
                    DataCell(Text(station.totalVersions.toString())),
                    DataCell(Text(
                      station.activeBookings.toString(),
                      style: TextStyle(
                        color: station.hasActiveBookings
                            ? theme.colorScheme.error
                            : theme.colorScheme.onSurface,
                      ),
                    )),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.visibility, size: 20),
                            onPressed: () {
                              // TODO: Navigate to station detail
                              context.push('/admin/stations/${station.stationId}');
                            },
                            tooltip: 'View Details',
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            onPressed: () {
                              // Navigate to detail screen (can add edit mode later)
                              context.push('/stations/${station.stationId}');
                            },
                            tooltip: 'View/Edit',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 20),
                            onPressed: station.hasActiveBookings
                                ? null
                                : () {
                                    _showDeleteDialog(context, theme, station);
                                  },
                            tooltip: station.hasActiveBookings
                                ? 'Cannot delete: has active bookings'
                                : 'Delete',
                            color: station.hasActiveBookings
                                ? theme.colorScheme.error.withOpacity(0.5)
                                : theme.colorScheme.error,
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
                top: BorderSide(color: theme.colorScheme.outline.withOpacity(0.2)),
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
                              ref.read(stationsPageProvider.notifier).state--;
                            },
                    ),
                    Text('${response.page + 1}'),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: response.last
                          ? null
                          : () {
                              ref.read(stationsPageProvider.notifier).state++;
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

  Widget _buildStatusChip(ThemeData theme, AdminStation station) {
    if (station.workflowStatus == null) {
      return Chip(
        label: const Text('No Version'),
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        labelStyle: theme.textTheme.labelSmall,
      );
    }

    final status = station.workflowStatus!;
    Color backgroundColor;
    Color textColor;

    switch (status) {
      case WorkflowStatus.published:
        backgroundColor = theme.colorScheme.primaryContainer;
        textColor = theme.colorScheme.onPrimaryContainer;
        break;
      case WorkflowStatus.draft:
        backgroundColor = theme.colorScheme.surfaceContainerHighest;
        textColor = theme.colorScheme.onSurfaceVariant;
        break;
      case WorkflowStatus.pending:
        backgroundColor = theme.colorScheme.tertiaryContainer;
        textColor = theme.colorScheme.onTertiaryContainer;
        break;
      case WorkflowStatus.rejected:
        backgroundColor = theme.colorScheme.errorContainer;
        textColor = theme.colorScheme.onErrorContainer;
        break;
      case WorkflowStatus.archived:
        backgroundColor = theme.colorScheme.surfaceContainerHighest;
        textColor = theme.colorScheme.onSurfaceVariant;
        break;
    }

    return Chip(
      label: Text(status.name.toUpperCase()),
      backgroundColor: backgroundColor,
      labelStyle: theme.textTheme.labelSmall?.copyWith(color: textColor),
    );
  }

  Color _getTrustScoreColor(ThemeData theme, int? score) {
    if (score == null) return theme.colorScheme.onSurfaceVariant;
    if (score >= 80) return theme.colorScheme.primary;
    if (score >= 60) return theme.colorScheme.tertiary;
    return theme.colorScheme.error;
  }

  void _showDeleteDialog(BuildContext context, ThemeData theme, AdminStation station) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Station'),
        content: Text('Are you sure you want to delete station "${station.name}"? This will archive all versions.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                final factory = ref.read(apiClientFactoryProvider);
                if (factory == null) {
                  throw Exception('API client not initialized');
                }
                
                print('Deleting station: ${station.stationId}');
                await factory.admin.deleteStation(station.stationId);
                print('Delete successful');
                
                // Invalidate stations provider to refresh the list
                ref.invalidate(stationsProvider((page: ref.read(stationsPageProvider), size: ref.read(stationsPageSizeProvider))));
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Station deleted successfully'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 3),
                    ),
                  );
                }
              } catch (e, stackTrace) {
                print('Delete station error: $e');
                print('Stack trace: $stackTrace');
                if (mounted) {
                  String errorMessage = 'Error deleting station';
                  if (e is DioException) {
                    if (e.response != null) {
                      final errorData = e.response!.data;
                      if (errorData is Map<String, dynamic>) {
                        errorMessage = errorData['message'] as String? ?? 
                                      'Lỗi từ server: ${e.response!.statusCode}';
                      } else {
                        errorMessage = 'Lỗi từ server: ${e.response!.statusCode}';
                      }
                    } else {
                      errorMessage = 'Lỗi kết nối: ${e.message}';
                    }
                  } else {
                    errorMessage = 'Lỗi: $e';
                  }
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.white),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              errorMessage,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 5),
                      behavior: SnackBarBehavior.floating,
                    ),
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

