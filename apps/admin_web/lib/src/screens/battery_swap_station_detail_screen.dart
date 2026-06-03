import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_api/shared_api.dart';
import 'package:shared_ui/shared_ui.dart';
import '../models/battery_swap_station.dart';
import '../providers/battery_swap_station_providers.dart';
import '../providers/battery_swap_trust_providers.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_scaffold.dart';

/// Battery Swap Station Detail Screen
class BatterySwapStationDetailScreen extends ConsumerWidget {
  final String id;

  const BatterySwapStationDetailScreen({
    super.key,
    required this.id,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final stationAsync = ref.watch(batterySwapStationProvider(id));

    return AdminScaffold(
      title: 'Battery Swap Station Details',
      body: stationAsync.when(
        data: (station) => _buildContent(context, theme, ref, station),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => ErrorState(
          title: 'Could not load station details',
          message: formatApiError(error),
          code: extractErrorCode(error),
          traceId: extractTraceId(error),
          onRetry: () {
            ref.invalidate(batterySwapStationProvider(id));
          },
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ThemeData theme, WidgetRef ref,
      BatterySwapStationDetail station) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          _buildHeaderCard(context, theme, station),
          const SizedBox(height: 24),

          // Trust Score Card
          _buildTrustScoreCard(context, theme, ref, station),
          const SizedBox(height: 24),

          // Station Info
          _buildStationInfoCard(theme, station),
          const SizedBox(height: 24),

          // Battery Swap Config
          _buildSwapConfigCard(theme, station),
          const SizedBox(height: 24),

          // Pile Layout
          if (station.pileTemplates != null && station.pileTemplates!.isNotEmpty) ...[
            _buildPileLayoutCard(theme, station),
            const SizedBox(height: 24),
          ],

          // Actions
          _buildActionsCard(context, theme, ref, station),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(
      BuildContext context, ThemeData theme, BatterySwapStationDetail station) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AdminTheme.primaryTeal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.battery_charging_full,
                    color: AdminTheme.primaryTeal,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
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
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            'ID: ${station.id.substring(0, 8)}...',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.6),
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 16),
                            onPressed: () {
                              Clipboard.setData(
                                  ClipboardData(text: station.id));
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
                      const SizedBox(height: 4),
                      Text(
                        station.address ?? 'No address',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(theme, station),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(ThemeData theme, BatterySwapStationDetail station) {
    final status = station.workflowStatus;
    if (status == null) return const SizedBox.shrink();

    Color color;
    switch (status.toUpperCase()) {
      case 'PUBLISHED':
        color = Colors.green;
        break;
      case 'PENDING':
        color = Colors.orange;
        break;
      case 'DRAFT':
        color = Colors.grey;
        break;
      case 'REJECTED':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return StatusPill(
      label: status.toUpperCase(),
      colorMapper: (_) => color,
    );
  }

  Widget _buildTrustScoreCard(BuildContext context, ThemeData theme, WidgetRef ref,
      BatterySwapStationDetail station) {
    final trustAsync = ref.watch(batterySwapTrustProvider(station.id));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified_user, color: AdminTheme.primaryTeal),
                const SizedBox(width: 8),
                Text(
                  'Trust Score',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            trustAsync.when(
              data: (trust) => Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: trust.scoreColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: trust.scoreColor, width: 2),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          trust.score.toString(),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: trust.scoreColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '/ 100',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: trust.scoreColor.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trust.levelLabel,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: trust.scoreColor,
                        ),
                      ),
                      Text(
                        'Level: ${trust.level}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: () {
                      context.push('/battery-swap/trust/${station.id}');
                    },
                    icon: const Icon(Icons.dashboard),
                    label: const Text('View Dashboard'),
                  ),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Text(
                'Could not load trust score',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStationInfoCard(
      ThemeData theme, BatterySwapStationDetail station) {
    return Card(
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _buildInfoRow(theme, 'Station ID', station.id),
                      _buildInfoRow(theme, 'Location',
                          station.lat != null && station.lng != null
                              ? '${station.lat!.toStringAsFixed(5)}, ${station.lng!.toStringAsFixed(5)}'
                              : 'N/A'),
                      _buildInfoRow(
                          theme, 'Operating Hours', station.operatingHours ?? 'N/A'),
                      _buildInfoRow(theme, 'Parking Fee',
                          station.parkingFee ?? 'N/A'),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      _buildInfoRow(theme, 'Published Version',
                          station.publishedVersionNo?.toString() ?? 'N/A'),
                      _buildInfoRow(theme, 'Total Versions',
                          station.totalVersions.toString()),
                      _buildInfoRow(theme, 'Public Status',
                          station.publicStatus ?? 'N/A'),
                      if (station.publishedAt != null)
                        _buildInfoRow(theme, 'Published At',
                            _formatDate(station.publishedAt!)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwapConfigCard(
      ThemeData theme, BatterySwapStationDetail station) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.battery_charging_full, color: AdminTheme.primaryTeal),
                const SizedBox(width: 8),
                Text(
                  'Battery Swap Configuration',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _buildStatItem(
                        theme,
                        icon: Icons.battery_full,
                        label: 'Total Batteries',
                        value: station.totalBatteries?.toString() ?? 'N/A',
                        color: AdminTheme.primaryTeal,
                      ),
                      const SizedBox(height: 12),
                      _buildStatItem(
                        theme,
                        icon: Icons.battery_5_bar,
                        label: 'Available',
                        value: station.availableBatteries?.toString() ?? 'N/A',
                        color: _getBatteryColor(
                            station.availableBatteries, station.totalBatteries),
                      ),
                      const SizedBox(height: 12),
                      _buildStatItem(
                        theme,
                        icon: Icons.bolt,
                        label: 'Avg Power',
                        value: station.avgChargePowerKw != null
                            ? '${station.avgChargePowerKw!.toStringAsFixed(1)} kW'
                            : 'N/A',
                        color: Colors.amber,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      _buildStatItem(
                        theme,
                        icon: Icons.grid_view,
                        label: 'Total Piles',
                        value: station.totalPiles?.toString() ?? 'N/A',
                        color: AdminTheme.primaryTeal,
                      ),
                      const SizedBox(height: 12),
                      _buildStatItem(
                        theme,
                        icon: Icons.grid_off,
                        label: 'Total Slots',
                        value: station.totalSlots?.toString() ?? 'N/A',
                        color: AdminTheme.primaryTeal,
                      ),
                      const SizedBox(height: 12),
                      _buildStatItem(
                        theme,
                        icon: Icons.attach_money,
                        label: 'Base Price',
                        value: station.basePriceVnd != null
                            ? '${station.basePriceVnd!.toStringAsFixed(0)} VND'
                            : 'N/A',
                        color: Colors.green,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (station.note != null && station.note!.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Note:',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(station.note!, style: theme.textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPileLayoutCard(
      ThemeData theme, BatterySwapStationDetail station) {
    final piles = station.pileTemplates!;
    final totalSlots = piles.fold<int>(0, (sum, p) => sum + p.slotsPerPile);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.grid_on, color: AdminTheme.primaryTeal),
                const SizedBox(width: 8),
                Text(
                  'Pile / Slot Layout',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AdminTheme.primaryTeal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${piles.length} Piles, $totalSlots Slots Total',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AdminTheme.primaryTeal,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: piles.map((pile) {
                return Container(
                  width: 180,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AdminTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.battery_charging_full,
                              size: 20, color: AdminTheme.primaryTeal),
                          const SizedBox(width: 8),
                          Text(
                            'Pile ${pile.pileIndex + 1}',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AdminTheme.primaryTeal.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${pile.slotsPerPile} slots',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AdminTheme.primaryTeal,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsCard(
      BuildContext context, ThemeData theme, WidgetRef ref, BatterySwapStationDetail station) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Actions',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    _showEditStationDialog(context, ref, station);
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit Station'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminTheme.primaryTeal,
                    foregroundColor: Colors.white,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    context.push('/battery-swap/trust/${station.id}');
                  },
                  icon: const Icon(Icons.analytics),
                  label: const Text('View Trust Dashboard'),
                ),
                OutlinedButton.icon(
                  onPressed: station.pendingCRs > 0
                      ? () {
                          context.push('/battery-swap/change-requests');
                        }
                      : null,
                  icon: const Icon(Icons.pending_actions),
                  label: Text('View Pending CRs (${station.pendingCRs})'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
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
            width: 140,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
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

  Widget _buildStatItem(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Color _getBatteryColor(int? available, int? total) {
    if (available == null || total == null) return Colors.grey;
    final ratio = available / total;
    if (ratio >= 0.5) return Colors.green;
    if (ratio >= 0.2) return Colors.orange;
    return Colors.red;
  }

  void _showEditStationDialog(BuildContext context, WidgetRef ref,
      BatterySwapStationDetail station) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: station.name ?? '');
    final addressController = TextEditingController(text: station.address ?? '');
    final latController = TextEditingController(
        text: station.lat?.toStringAsFixed(6) ?? '');
    final lngController = TextEditingController(
        text: station.lng?.toStringAsFixed(6) ?? '');
    final totalBatteriesController = TextEditingController(
        text: station.totalBatteries?.toString() ?? '');
    final avgPowerController = TextEditingController(
        text: station.avgChargePowerKw?.toStringAsFixed(1) ?? '');
    final operatingHoursController = TextEditingController(
        text: station.operatingHours ?? '07:00-22:00');
    final parkingFeeController = TextEditingController(
        text: station.parkingFee ?? '');
    final noteController = TextEditingController(text: station.note ?? '');

    bool publishImmediately = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.edit, color: AdminTheme.primaryTeal),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Edit Station: ${station.name ?? 'Station'}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 600,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader(context, 'Station Information'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Station Name *',
                        hintText: 'e.g. Battery Swap Hoan Kiem',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Name is required';
                        }
                        if (value.length < 3) {
                          return 'Name must be at least 3 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: addressController,
                      decoration: const InputDecoration(
                        labelText: 'Address *',
                        hintText: 'e.g. 123 Nguyen Chi Thanh, Hoan Kiem, Hanoi',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Address is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: latController,
                            decoration: const InputDecoration(
                              labelText: 'Latitude *',
                              hintText: 'e.g. 21.0285',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true, signed: true),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Latitude is required';
                              }
                              final v = double.tryParse(value);
                              if (v == null || v < -90 || v > 90) {
                                return 'Must be -90 to 90';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: lngController,
                            decoration: const InputDecoration(
                              labelText: 'Longitude *',
                              hintText: 'e.g. 105.8532',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true, signed: true),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Longitude is required';
                              }
                              final v = double.tryParse(value);
                              if (v == null || v < -180 || v > 180) {
                                return 'Must be -180 to 180';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _sectionHeader(context, 'Battery Swap Configuration'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: totalBatteriesController,
                            decoration: const InputDecoration(
                              labelText: 'Total Batteries *',
                              hintText: 'e.g. 48',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Required';
                              }
                              if (int.tryParse(value) == null ||
                                  int.parse(value) < 1) {
                                return 'Must be >= 1';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: avgPowerController,
                            decoration: const InputDecoration(
                              labelText: 'Avg Power (kW) *',
                              hintText: 'e.g. 22.5',
                            ),
                            keyboardType:
                                const TextInputType.numberWithOptions(decimal: true),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Required';
                              }
                              if (double.tryParse(value) == null ||
                                  double.parse(value) <= 0) {
                                return 'Must be > 0';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: operatingHoursController,
                      decoration: const InputDecoration(
                        labelText: 'Operating Hours *',
                        hintText: 'e.g. 07:00-23:00',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: parkingFeeController,
                      decoration: const InputDecoration(
                        labelText: 'Parking Fee (VND)',
                        hintText: 'e.g. 5000',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: noteController,
                      decoration: const InputDecoration(
                        labelText: 'Note',
                        hintText: 'Optional note...',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Publish immediately'),
                      subtitle: const Text(
                          'If ON, the new version will be published right away. '
                          'If OFF, it will be saved as DRAFT.'),
                      value: publishImmediately,
                      onChanged: (v) => setState(() => publishImmediately = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                final factory = ref.read(apiClientFactoryProvider);
                if (factory == null) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('API client not initialized'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                  return;
                }

                try {
                  final data = {
                    'stationData': {
                      'name': nameController.text,
                      'address': addressController.text,
                      'location': {
                        'lat': double.parse(latController.text),
                        'lng': double.parse(lngController.text),
                      },
                      'totalBatteries': int.parse(totalBatteriesController.text),
                      'avgChargePowerKw': double.parse(avgPowerController.text),
                      'operatingHours': operatingHoursController.text,
                      if (parkingFeeController.text.isNotEmpty)
                        'parkingFee':
                            double.parse(parkingFeeController.text),
                      if (noteController.text.isNotEmpty)
                        'note': noteController.text,
                    },
                    'publishImmediately': publishImmediately,
                  };

                  await factory.admin.updateBatterySwapStation(station.id, data);

                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(publishImmediately
                            ? 'Station updated and published successfully'
                            : 'Station updated (saved as DRAFT)'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    ref.invalidate(batterySwapStationsProvider(
                        (page: 0, size: 20, search: null)));
                    ref.invalidate(batterySwapStationProvider(station.id));
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
              },
              icon: const Icon(Icons.save),
              label: Text(publishImmediately ? 'Save & Publish' : 'Save as Draft'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminTheme.primaryTeal,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.bold,
        color: AdminTheme.primaryTeal,
      ),
    );
  }
}
