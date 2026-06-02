import 'package:flutter/material.dart';
import 'package:shared_ui/shared_ui.dart';
import '../theme/collab_theme.dart';
import '../models/battery_swap_verification_task.dart';

/// Swap Verification Task Detail Dialog
class SwapVerificationTaskDetailDialog extends StatelessWidget {
  final BatterySwapVerificationTask task;

  const SwapVerificationTaskDetailDialog({
    super.key,
    required this.task,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: CollabTheme.primaryGreen,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.battery_charging_full,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Battery Swap Verification',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          task.stationName,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Badge
                    StatusPill(
                      label: task.status.displayName,
                      colorMapper: (label) {
                        switch (task.status) {
                          case VerificationTaskStatus.assigned:
                            return Colors.orange;
                          case VerificationTaskStatus.checkedIn:
                            return Colors.blue;
                          case VerificationTaskStatus.submitted:
                            return Colors.purple;
                          case VerificationTaskStatus.reviewed:
                            return Colors.green;
                          default:
                            return CollabTheme.primaryGreen;
                        }
                      },
                    ),
                    const SizedBox(height: 20),

                    // Station Info
                    _buildSection(
                      theme,
                      title: 'Station Information',
                      children: [
                        _buildInfoRow(theme, 'Station ID', task.stationId),
                        _buildInfoRow(
                            theme, 'Priority', 'Level ${task.priority}'),
                        if (task.slaDueAt != null)
                          _buildInfoRow(
                            theme,
                            'SLA Due',
                            _formatDateTime(task.slaDueAt!),
                          ),
                        _buildInfoRow(
                          theme,
                          'Created',
                          _formatDateTime(task.createdAt),
                        ),
                      ],
                    ),

                    // Inventory Data
                    if (task.inventoryData != null) ...[
                      const SizedBox(height: 20),
                      _buildSection(
                        theme,
                        title: 'Inventory Data',
                        children: [
                          _buildInfoRow(
                            theme,
                            'Battery Count',
                            task.inventoryData!.batteryInventoryCount.toString(),
                          ),
                          _buildInfoRow(
                            theme,
                            'Pile Count',
                            task.inventoryData!.pileCount.toString(),
                          ),
                          _buildInfoRow(
                            theme,
                            'Slot Count',
                            task.inventoryData!.slotCount.toString(),
                          ),
                          _buildInfoRow(
                            theme,
                            'Operating Hours Accurate',
                            task.inventoryData!.isOperatingHoursAccurate
                                ? 'Yes'
                                : 'No',
                          ),
                          if (task.inventoryData!.parkingFee != null)
                            _buildInfoRow(
                              theme,
                              'Parking Fee',
                              '${task.inventoryData!.parkingFee} VND',
                            ),
                          if (task.inventoryData!.notes != null &&
                              task.inventoryData!.notes!.isNotEmpty)
                            _buildInfoRow(
                              theme,
                              'Notes',
                              task.inventoryData!.notes!,
                            ),
                        ],
                      ),
                    ],

                    // Evidence
                    if (task.evidences.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildSection(
                        theme,
                        title: 'Submitted Evidence',
                        children: [
                          ...task.evidences.map((e) => _buildEvidenceRow(
                                theme,
                                e,
                              )),
                        ],
                      ),
                    ],

                    // Review Result
                    if (task.review != null) ...[
                      const SizedBox(height: 20),
                      _buildSection(
                        theme,
                        title: 'Review Result',
                        children: [
                          _buildInfoRow(
                            theme,
                            'Result',
                            task.review!.isPass ? 'PASSED' : 'FAILED',
                            valueColor:
                                task.review!.isPass ? Colors.green : Colors.red,
                          ),
                          _buildInfoRow(
                            theme,
                            'Reviewed At',
                            _formatDateTime(task.review!.reviewedAt),
                          ),
                          _buildInfoRow(theme, 'Reviewed By', task.review!.reviewedBy),
                          if (task.review!.adminNote != null)
                            _buildInfoRow(
                              theme,
                              'Admin Note',
                              task.review!.adminNote!,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outline.withOpacity(0.2),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    ThemeData theme, {
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    ThemeData theme,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
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
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: valueColor,
                fontWeight: valueColor != null ? FontWeight.bold : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvidenceRow(
    ThemeData theme,
    BatterySwapEvidence evidence,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            Icons.photo,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  evidence.photoObjectKey.split('/').last,
                  style: theme.textTheme.bodyMedium,
                ),
                if (evidence.evidenceType != null)
                  Text(
                    evidence.evidenceType!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
              ],
            ),
          ),
          Text(
            _formatDateTime(evidence.submittedAt),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
