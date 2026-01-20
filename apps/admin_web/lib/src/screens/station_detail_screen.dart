import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:shared_api/shared_api.dart';
import 'package:shared_ui/shared_ui.dart';
import '../models/admin_station.dart';
import '../providers/station_providers.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_scaffold.dart';

/// Station Detail Screen
class StationDetailScreen extends ConsumerWidget {
  final String id;

  const StationDetailScreen({
    super.key,
    required this.id,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final stationAsync = ref.watch(stationProvider(id));

    return AdminScaffold(
      title: 'Station Details',
      body: stationAsync.when(
        data: (station) => _buildContent(context, theme, ref, station),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => ErrorState(
          message: error.toString(),
          onRetry: () {
            ref.invalidate(stationProvider(id));
          },
        ),
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, ThemeData theme, WidgetRef ref, AdminStation station) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
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
                              station.name ?? 'Unnamed Station',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                  'ID: ${station.stationId}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.copy, size: 18),
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: station.stationId));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Station ID copied to clipboard'),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                  tooltip: 'Copy ID',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  style: IconButton.styleFrom(
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (station.workflowStatus != null)
                        StatusPill(
                          label: station.workflowStatus!.name.toUpperCase(),
                          colorMapper: (label) {
                            switch (station.workflowStatus!) {
                              case WorkflowStatus.published:
                                return Colors.green;
                              case WorkflowStatus.draft:
                                return Colors.grey;
                              case WorkflowStatus.pending:
                                return Colors.orange;
                              case WorkflowStatus.rejected:
                                return Colors.red;
                              case WorkflowStatus.archived:
                                return Colors.grey;
                            }
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Actions
                  Wrap(
                    spacing: 12,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          // TODO: Navigate to edit screen (can reuse create screen with edit mode)
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Edit functionality - Coming soon')),
                          );
                        },
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit'),
                      ),
                      OutlinedButton.icon(
                        onPressed: station.hasActiveBookings
                            ? null
                            : () {
                                _showDeleteDialog(context, theme, ref, station);
                              },
                        icon: const Icon(Icons.delete),
                        label: const Text('Delete'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Station Info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Station Information',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRowWithCopy(theme, context, 'Station ID', station.stationId),
                  _buildInfoRow(theme, 'Address', station.address ?? 'N/A'),
                  _buildInfoRow(theme, 'Location', 
                      station.lat != null && station.lng != null
                          ? '${station.lat}, ${station.lng}'
                          : 'N/A'),
                  _buildInfoRow(theme, 'Operating Hours', station.operatingHours ?? 'N/A'),
                  _buildInfoRow(theme, 'Parking', station.parking?.name.toUpperCase() ?? 'N/A'),
                  _buildInfoRow(theme, 'Visibility', station.visibility?.name.toUpperCase() ?? 'N/A'),
                  _buildInfoRow(theme, 'Public Status', station.publicStatus?.name.toUpperCase() ?? 'N/A'),
                  _buildInfoRow(theme, 'Trust Score', station.trustScore?.toString() ?? 'N/A'),
                  _buildInfoRow(theme, 'Total Versions', station.totalVersions.toString()),
                  _buildInfoRow(theme, 'Active Bookings', station.activeBookings.toString()),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Services and Ports
          if (station.services.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Charging Ports',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...station.services.expand((service) => service.chargingPorts).map(
                          (port) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Text(
                                  '${port.powerType.name.toUpperCase()}',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (port.powerKw != null) ...[
                                  const SizedBox(width: 8),
                                  Text('${port.powerKw}kW'),
                                ],
                                const SizedBox(width: 8),
                                Text('× ${port.portCount} ports'),
                              ],
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRowWithCopy(ThemeData theme, BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: value));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$label copied to clipboard'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  tooltip: 'Copy $label',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  style: IconButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(
      BuildContext context, ThemeData theme, WidgetRef ref, AdminStation station) {
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
                ref.invalidate(stationsProvider((page: 0, size: 20)));
                
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Station deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  context.go('/stations');
                }
              } catch (e, stackTrace) {
                print('Delete station error: $e');
                print('Stack trace: $stackTrace');
                if (context.mounted) {
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

