import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:shared_api/shared_api.dart';
import '../models/admin_change_request.dart';
import '../providers/change_request_providers.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_scaffold.dart';

/// Change Request Detail Screen
class ChangeRequestDetailScreen extends ConsumerWidget {
  final String id;

  const ChangeRequestDetailScreen({
    super.key,
    required this.id,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final changeRequestAsync = ref.watch(changeRequestProvider(id));

    return AdminScaffold(
      title: 'Change Request Details',
      body: changeRequestAsync.when(
        data: (cr) => _buildContent(context, theme, ref, cr),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => ErrorState(
          message: error.toString(),
          onRetry: () {
            ref.invalidate(changeRequestProvider(id));
          },
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ThemeData theme, WidgetRef ref,
      AdminChangeRequest cr) {
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
                              cr.type.displayName,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'ID: ${cr.id.substring(0, 8)}...',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      StatusPill(
                        label: cr.status.displayName,
                        colorMapper: (label) {
                          switch (cr.status) {
                            case ChangeRequestStatus.pending:
                              return Colors.orange;
                            case ChangeRequestStatus.approved:
                              return Colors.green;
                            case ChangeRequestStatus.rejected:
                              return Colors.red;
                            case ChangeRequestStatus.published:
                              return AdminTheme.primaryTeal;
                            case ChangeRequestStatus.draft:
                              return Colors.grey;
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Actions
                  if (cr.canApprove || cr.canReject || cr.canPublish)
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
                        if (cr.isApproved)
                          Tooltip(
                            message: cr.canPublish 
                                ? 'Publish this change request' 
                                : 'High-risk change requests require verification task PASS before publishing',
                            child: ElevatedButton.icon(
                              onPressed: cr.canPublish ? () => _handlePublish(context, ref, cr) : null,
                              icon: const Icon(Icons.publish),
                              label: Text(cr.canPublish ? 'Publish' : 'Publish (Verification Required)'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: cr.canPublish ? AdminTheme.primaryTeal : Colors.grey,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.grey,
                                disabledForegroundColor: Colors.white70,
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

          // High Risk Warning Banner
          if (cr.isHighRisk && !cr.canPublish) ...[
            _buildHighRiskWarningBanner(context, theme, cr),
            const SizedBox(height: 24),
          ],

          // Risk Breakdown
          if (cr.riskScore != null || cr.riskReasons.isNotEmpty) ...[
            _buildRiskSection(theme, cr),
            const SizedBox(height: 24),
          ],

          // Station Data
          if (cr.stationData != null) ...[
            _buildStationDataSection(context, theme, cr.stationData!),
            const SizedBox(height: 24),
          ],

          // Basic Info
          _buildBasicInfoSection(context, theme, cr),
          const SizedBox(height: 24),

          // Audit Logs
          if (cr.auditLogs.isNotEmpty) ...[
            _buildAuditLogsSection(theme, cr.auditLogs),
          ],
        ],
      ),
    );
  }

  Widget _buildHighRiskWarningBanner(BuildContext context, ThemeData theme, AdminChangeRequest cr) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        border: Border.all(color: Colors.orange.shade300, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange.shade700,
            size: 32,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'High Risk Change Request',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This change request requires verification task PASS before publishing.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.orange.shade800,
                  ),
                ),
                if (cr.verificationStatusMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    cr.verificationStatusMessage!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.w600,
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

  Widget _buildRiskSection(ThemeData theme, AdminChangeRequest cr) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: _getRiskColor(cr.riskScore!)
                          .withOpacity(0.1),
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
                          child: Text(
                            reason,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
            // Verification Status (only for high-risk)
            if (cr.isHighRisk) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getVerificationStatusColor(cr).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _getVerificationStatusColor(cr),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getVerificationStatusIcon(cr),
                      color: _getVerificationStatusColor(cr),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        cr.verificationStatusMessage ?? 'Verification status unknown',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: _getVerificationStatusColor(cr),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStationDataSection(BuildContext context, ThemeData theme, StationData stationData) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Station Data',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(context, theme, 'Name', stationData.name ?? 'N/A'),
            _buildInfoRow(context, theme, 'Address', stationData.address ?? 'N/A'),
            if (stationData.lat != null && stationData.lng != null)
              _buildInfoRow(
                context,
                theme,
                'Location',
                '${stationData.lat!.toStringAsFixed(6)}, ${stationData.lng!.toStringAsFixed(6)}',
              ),
            _buildInfoRow(
                context, theme, 'Operating Hours', stationData.operatingHours ?? 'N/A'),
            _buildInfoRow(context, theme, 'Parking', stationData.parking ?? 'N/A'),
            _buildInfoRow(
                context, theme, 'Visibility', stationData.visibility ?? 'N/A'),
            _buildInfoRow(
                context, theme, 'Public Status', stationData.publicStatus ?? 'N/A'),
            if (stationData.services.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Services:',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ...stationData.services.map((service) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AdminTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Service: ${service.type}',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (service.chargingPorts.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            ...service.chargingPorts.map((port) => Padding(
                                  padding: const EdgeInsets.only(left: 16, top: 4),
                                  child: Text(
                                    '${port.powerType ?? "N/A"}: ${port.powerKw?.toStringAsFixed(1) ?? "N/A"} kW x ${port.count ?? 0}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                )),
                          ],
                        ],
                      ),
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection(BuildContext context, ThemeData theme, AdminChangeRequest cr) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
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
            _buildInfoRow(context, theme, 'Submitter Email', cr.submitterEmail ?? 'N/A'),
            if (cr.stationId != null)
              _buildInfoRow(context, theme, 'Station ID', cr.stationId!, copyable: true),
            if (cr.createdAt != null)
              _buildInfoRow(
                  context, theme, 'Created At', _formatDateTime(cr.createdAt!)),
            if (cr.submittedAt != null)
              _buildInfoRow(
                  context, theme, 'Submitted At', _formatDateTime(cr.submittedAt!)),
            if (cr.decidedAt != null)
              _buildInfoRow(
                  context, theme, 'Decided At', _formatDateTime(cr.decidedAt!)),
            if (cr.adminNote != null)
              _buildInfoRow(context, theme, 'Admin Note', cr.adminNote!),
          ],
        ),
      ),
    );
  }

  Widget _buildAuditLogsSection(ThemeData theme, List<AuditLog> auditLogs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Audit Logs',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...auditLogs.map((log) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AdminTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: theme.colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                log.action,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (log.createdAt != null)
                              Text(
                                _formatDateTime(log.createdAt!),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6),
                                ),
                              ),
                          ],
                        ),
                        if (log.actorRole != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'By: ${log.actorRole}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, ThemeData theme, String label, String value, {bool copyable = false}) {
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
                  child: Text(
                    value,
                    style: theme.textTheme.bodyMedium,
                  ),
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

  Color _getVerificationStatusColor(AdminChangeRequest cr) {
    if (cr.hasPassedVerification == true) return Colors.green;
    if (cr.hasVerificationTask == true) return Colors.orange;
    return Colors.red;
  }

  IconData _getVerificationStatusIcon(AdminChangeRequest cr) {
    if (cr.hasPassedVerification == true) return Icons.check_circle;
    if (cr.hasVerificationTask == true) return Icons.hourglass_empty;
    return Icons.error_outline;
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _showApproveDialog(
      BuildContext context, WidgetRef ref, AdminChangeRequest cr) {
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

  void _showRejectDialog(
      BuildContext context, WidgetRef ref, AdminChangeRequest cr) {
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

  Future<void> _handleApprove(BuildContext context, WidgetRef ref,
      AdminChangeRequest cr, String? note) async {
    try {
      final factory = ref.read(apiClientFactoryProvider);
      if (factory == null) throw Exception('API client not initialized');

      await factory.admin.approveChangeRequest(cr.id, note: note);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Change request approved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        ref.invalidate(changeRequestProvider(cr.id));
        ref.invalidate(changeRequestsProvider);
        if (context.mounted) context.pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleReject(BuildContext context, WidgetRef ref,
      AdminChangeRequest cr, String reason) async {
    try {
      final factory = ref.read(apiClientFactoryProvider);
      if (factory == null) throw Exception('API client not initialized');

      await factory.admin.rejectChangeRequest(cr.id, reason: reason);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Change request rejected successfully'),
            backgroundColor: Colors.red,
          ),
        );
        ref.invalidate(changeRequestProvider(cr.id));
        ref.invalidate(changeRequestsProvider);
        if (context.mounted) context.pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handlePublish(
      BuildContext context, WidgetRef ref, AdminChangeRequest cr) async {
    // Safety check: prevent publish if not allowed
    if (!cr.canPublish) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              cr.isHighRisk && cr.hasPassedVerification != true
                  ? 'Cannot publish: High-risk change requests require verification task PASS'
                  : 'Cannot publish this change request',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Publish Change Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Are you sure you want to publish this change request? This will make the station version publicly visible.'),
            if (cr.isHighRisk && cr.hasPassedVerification != true) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This high-risk change request requires verification task PASS before publishing.',
                        style: TextStyle(color: Colors.red.shade900, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
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

      await factory.admin.publishChangeRequest(cr.id);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Change request published successfully'),
            backgroundColor: Colors.green,
          ),
        );
        ref.invalidate(changeRequestProvider(cr.id));
        ref.invalidate(changeRequestsProvider);
        if (context.mounted) context.pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

