import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:shared_api/shared_api.dart';
import '../models/battery_swap_change_request.dart';
import '../providers/battery_swap_cr_providers.dart';
import '../providers/battery_swap_trust_providers.dart';
import '../theme/admin_theme.dart';
import '../utils/responsive_utils.dart';
import '../widgets/admin_scaffold.dart';
import 'create_task_modal.dart';

/// Battery Swap Change Request Detail Screen
class BatterySwapCRDetailScreen extends ConsumerWidget {
  final String id;

  const BatterySwapCRDetailScreen({
    super.key,
    required this.id,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final crAsync = ref.watch(batterySwapCRProvider(id));

    return AdminScaffold(
      title: 'Battery Swap CR Details',
      body: crAsync.when(
        data: (cr) => _buildContent(context, theme, ref, cr),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => ErrorState(
          title: 'Could not load change request',
          message: formatApiError(error),
          code: extractErrorCode(error),
          traceId: extractTraceId(error),
          onRetry: () {
            ref.invalidate(batterySwapCRProvider(id));
          },
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ThemeData theme, WidgetRef ref,
      BatterySwapChangeRequest cr) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(responsivePadding(context)),
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
                            Row(
                              children: [
                                Icon(
                                  _getTypeIcon(cr.type),
                                  size: 28,
                                  color: AdminTheme.primaryTeal,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  cr.type.displayName,
                                  style: theme.textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'CR ID: ${cr.id.substring(0, 8)}...',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                            if (cr.stationName != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Station: ${cr.stationName}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      StatusPill(
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
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Actions
                  if (cr.canApprove || cr.canReject || cr.requiresVerification)
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        if (cr.canApprove)
                          ElevatedButton.icon(
                            onPressed: () => _showApproveDialog(context, ref, cr),
                            icon: const Icon(Icons.check_circle),
                            label: const Text('Approve'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        if (cr.canReject)
                          ElevatedButton.icon(
                            onPressed: () => _showRejectDialog(context, ref, cr),
                            icon: const Icon(Icons.cancel),
                            label: const Text('Reject'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        if (cr.status == BatterySwapCRStatus.approved && !cr.requiresVerification)
                          ElevatedButton.icon(
                            onPressed: () => _handlePublish(context, ref, cr),
                            icon: const Icon(Icons.publish),
                            label: const Text('Publish'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AdminTheme.primaryTeal,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        if (cr.requiresVerification)
                          Tooltip(
                            message: 'Create a verification task for this change request',
                            child: ElevatedButton.icon(
                              onPressed: () => _showCreateTaskModal(context, ref, cr),
                              icon: const Icon(Icons.add_task),
                              label: const Text('Create Verification Task'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AdminTheme.primaryTeal,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Trust Score Card (if available)
          _buildTrustScoreCard(context, theme, ref, cr),
          const SizedBox(height: 24),

          // Risk Assessment
          if (cr.riskScore != null || cr.riskReasons.isNotEmpty) ...[
            _buildRiskSection(theme, cr),
            const SizedBox(height: 24),
          ],

          // Station Version Info
          if (cr.versionId != null) ...[
            _buildVersionSection(context, theme, cr),
            const SizedBox(height: 24),
          ],

          // Pile/Slot Layout
          if (cr.pileTemplates != null && cr.pileTemplates!.isNotEmpty) ...[
            _buildPileLayoutSection(context, theme, cr),
            const SizedBox(height: 24),
          ],

          // Basic Info
          _buildBasicInfoSection(context, theme, cr),
        ],
      ),
    );
  }

  Widget _buildTrustScoreCard(BuildContext context, ThemeData theme, WidgetRef ref,
      BatterySwapChangeRequest cr) {
    if (cr.stationId.isEmpty) {
      return const SizedBox.shrink();
    }
    final trustAsync = ref.watch(batterySwapTrustProvider(cr.stationId));

    return Card(
      child: Padding(
        padding: EdgeInsets.all(responsivePadding(context) * 0.8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified_user, color: AdminTheme.primaryTeal),
                const SizedBox(width: 8),
                Text(
                  'Station Trust Score',
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
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                      context.push('/battery-swap/trust/${cr.stationId}');
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

  Widget _buildRiskSection(BuildContext context, ThemeData theme, BatterySwapChangeRequest cr) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(responsivePadding(context) * 0.8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Risk Assessment',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (cr.riskScore != null) ...[
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: _getRiskColor(cr.riskScore!).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getRiskColor(cr.riskScore!),
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getRiskIcon(cr.riskScore!),
                          color: _getRiskColor(cr.riskScore!),
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Risk Score: ${cr.riskScore}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: _getRiskColor(cr.riskScore!),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  if (cr.requiresVerification)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified, color: Colors.orange.shade700, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            'Requires Verification',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            if (cr.riskReasons.isNotEmpty) ...[
              Text(
                'Risk Reasons:',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ...cr.riskReasons.map((reason) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 16,
                          color: _getRiskColor(cr.riskScore ?? 0),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(reason, style: theme.textTheme.bodyMedium),
                        ),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVersionSection(BuildContext context, ThemeData theme, BatterySwapChangeRequest cr) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(responsivePadding(context) * 0.8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, color: AdminTheme.primaryTeal),
                const SizedBox(width: 8),
                Text(
                  'Station Version Info',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(context, theme, 'Version ID', cr.versionId ?? 'N/A', copyable: true),
            _buildInfoRow(context, theme, 'Version No.', cr.versionNo?.toString() ?? 'N/A'),
            _buildInfoRow(context, theme, 'Workflow Status', cr.workflowStatus ?? 'N/A'),
            _buildInfoRow(
              context, theme, 'Total Batteries', cr.totalBatteries?.toString() ?? 'N/A',
            ),
            _buildInfoRow(
              context, theme, 'Avg Charge Power',
              cr.avgChargePowerKw != null ? '${cr.avgChargePowerKw!.toStringAsFixed(1)} kW' : 'N/A',
            ),
            _buildInfoRow(context, theme, 'Operating Hours', cr.operatingHours ?? 'N/A'),
            _buildInfoRow(
              context, theme, 'Parking Fee',
              cr.parkingFee != null ? '${cr.parkingFee!.toStringAsFixed(2)}' : 'N/A',
            ),
            if (cr.note != null)
              _buildInfoRow(context, theme, 'Note', cr.note!),
          ],
        ),
      ),
    );
  }

  Widget _buildPileLayoutSection(BuildContext context, ThemeData theme, BatterySwapChangeRequest cr) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(responsivePadding(context) * 0.8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.grid_view, color: AdminTheme.primaryTeal),
                const SizedBox(width: 8),
                Text(
                  'Pile / Slot Layout',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '${cr.pileTemplates!.length} Piles, ${cr.pileTemplates!.fold<int>(0, (sum, p) => sum + p.slots.length)} Slots Total',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 16),
            ...cr.pileTemplates!.map((pile) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AdminTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.battery_charging_full, size: 20, color: AdminTheme.primaryTeal),
                          const SizedBox(width: 8),
                          Text(
                            'Pile ${pile.pileIndex + 1}',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: pile.slots.map((slot) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: theme.colorScheme.outline.withOpacity(0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Slot ${slot.slotIndex + 1}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (slot.batteryCapacityKwh != null)
                                  Text(
                                    '${slot.batteryCapacityKwh!.toStringAsFixed(1)} kWh',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontSize: 10,
                                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection(BuildContext context, ThemeData theme, BatterySwapChangeRequest cr) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(responsivePadding(context) * 0.8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Basic Information',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(context, theme, 'Station ID', cr.stationId.isNotEmpty ? cr.stationId : 'N/A', copyable: true),
            _buildInfoRow(
              context, theme, 'Submitter', cr.submittedByEmail ?? cr.submittedBy ?? 'N/A',
            ),
            _buildInfoRow(
              context, theme, 'Created At',
              cr.createdAt != null ? _formatDateTime(cr.createdAt) : 'N/A',
            ),
            if (cr.submittedAt != null)
              _buildInfoRow(
                context, theme, 'Submitted At', _formatDateTime(cr.submittedAt!),
              ),
            if (cr.decidedAt != null)
              _buildInfoRow(
                context, theme, 'Decided At', _formatDateTime(cr.decidedAt!),
              ),
            if (cr.adminNote != null)
              _buildInfoRow(context, theme, 'Admin Note', cr.adminNote!),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, ThemeData theme, String label, String value,
      {bool copyable = false}) {
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
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(value, style: theme.textTheme.bodyMedium),
                ),
                if (copyable) ...[
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Copy to clipboard',
                    child: IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: value));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$label copied to clipboard'),
                            duration: const Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      iconSize: 18,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
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
    return Colors.green;
  }

  IconData _getRiskIcon(int riskScore) {
    if (riskScore >= 60) return Icons.dangerous;
    if (riskScore >= 30) return Icons.warning;
    return Icons.check_circle;
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _showApproveDialog(BuildContext context, WidgetRef ref, BatterySwapChangeRequest cr) {
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Change Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Are you sure you want to approve this change request?'),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: 'Admin Note (Optional)',
                hintText: 'Add a note...',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _handleApprove(context, ref, cr, noteController.text);
              if (context.mounted) Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(BuildContext context, WidgetRef ref, BatterySwapChangeRequest cr) {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Change Request'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Please provide a reason for rejection:'),
              const SizedBox(height: 16),
              TextFormField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason *',
                  hintText: 'Enter rejection reason...',
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Reason is required';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                await _handleReject(context, ref, cr, reasonController.text);
                if (context.mounted) Navigator.of(context).pop();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  void _showCreateTaskModal(BuildContext context, WidgetRef ref, BatterySwapChangeRequest cr) {
    showDialog(
      context: context,
      builder: (dialogContext) => CreateTaskModal.withContext(
        preselectedStationId: cr.stationId,
        preselectedStationName: cr.stationName,
        preselectedChangeRequestId: cr.id,
        preselectedType: TaskCreationType.batterySwap,
      ),
    ).then((result) {
      if (result == true) {
        ref.invalidate(batterySwapCRProvider(cr.id));
      }
    });
  }

  Future<void> _handleApprove(BuildContext context, WidgetRef ref,
      BatterySwapChangeRequest cr, String? note) async {
    try {
      final factory = ref.read(apiClientFactoryProvider);
      if (factory == null) throw Exception('API client not initialized');

      await factory.admin.approveBatterySwapChangeRequest(cr.id, note: note);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Change request approved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        ref.invalidate(batterySwapCRProvider(cr.id));
        ref.invalidate(batterySwapCRListProvider);
        if (context.mounted) context.pop();
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

  Future<void> _handleReject(BuildContext context, WidgetRef ref,
      BatterySwapChangeRequest cr, String reason) async {
    try {
      final factory = ref.read(apiClientFactoryProvider);
      if (factory == null) throw Exception('API client not initialized');

      await factory.admin.rejectBatterySwapChangeRequest(cr.id, reason: reason);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Change request rejected successfully'),
            backgroundColor: Colors.red,
          ),
        );
        ref.invalidate(batterySwapCRProvider(cr.id));
        ref.invalidate(batterySwapCRListProvider);
        if (context.mounted) context.pop();
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

  Future<void> _handlePublish(BuildContext context, WidgetRef ref,
      BatterySwapChangeRequest cr) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Publish Change Request'),
        content: const Text(
          'Are you sure you want to publish this change request? '
          'This will make the station version publicly visible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminTheme.primaryTeal,
              foregroundColor: Colors.white,
            ),
            child: const Text('Publish'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final factory = ref.read(apiClientFactoryProvider);
      if (factory == null) throw Exception('API client not initialized');

      await factory.admin.publishBatterySwapChangeRequest(cr.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Change request published successfully'),
            backgroundColor: Colors.green,
          ),
        );
        ref.invalidate(batterySwapCRProvider(cr.id));
        ref.invalidate(batterySwapCRListProvider);
        if (context.mounted) context.pop();
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
