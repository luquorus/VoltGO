import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_ui/shared_ui.dart';
import '../providers/battery_swap_change_request_providers.dart';
import '../widgets/main_scaffold.dart';

class BatterySwapChangeRequestDetailScreen extends ConsumerWidget {
  final String changeRequestId;

  const BatterySwapChangeRequestDetailScreen({
    super.key,
    required this.changeRequestId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncValue = ref.watch(batterySwapChangeRequestDetailProvider(changeRequestId));
    final theme = Theme.of(context);

    return MainScaffold(
      title: 'Battery Swap Proposal',
      child: asyncValue.when(
        data: (data) => _buildContent(context, ref, data, theme),
        loading: () => const LoadingState(message: 'Loading proposal...'),
        error: (error, stack) => ErrorState(
          title: 'Could not load proposal',
          message: formatApiError(error),
          code: extractErrorCode(error),
          traceId: extractTraceId(error),
          onRetry: () =>
              ref.invalidate(batterySwapChangeRequestDetailProvider(changeRequestId)),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> cr,
    ThemeData theme,
  ) {
    final status = cr['status'] as String? ?? 'UNKNOWN';
    final createdAt = _parseDateTime(cr['createdAt'] as String?);
    final submittedAt = _parseDateTime(cr['submittedAt'] as String?);
    final decidedAt = _parseDateTime(cr['decidedAt'] as String?);
    final adminNote = cr['adminNote'] as String?;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusTimeline(theme, status, createdAt, submittedAt, decidedAt),
          const SizedBox(height: 24),
          _buildStationInfoSection(theme, cr),
          const SizedBox(height: 24),
          _buildBatterySwapConfigSection(theme, cr),
          const SizedBox(height: 24),
          if (adminNote != null && adminNote.isNotEmpty) ...[
            _buildAdminNoteSection(theme, adminNote),
            const SizedBox(height: 24),
          ],
          if (status == 'DRAFT')
            PrimaryButton(
              label: 'Submit for Review',
              onPressed: () => _handleSubmit(context, ref),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusTimeline(
    ThemeData theme,
    String status,
    DateTime? createdAt,
    DateTime? submittedAt,
    DateTime? decidedAt,
  ) {
    final isRejected = status == 'REJECTED';
    final decidedStatus = isRejected ? 'REJECTED' : 'APPROVED';
    final isPublished = status == 'PUBLISHED';
    final statuses = [
      'DRAFT',
      'PENDING',
      decidedStatus,
      if (isPublished) 'PUBLISHED',
    ];

    final currentIndex = statuses.indexOf(status);
    if (currentIndex == -1) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Status Timeline',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            ...statuses.asMap().entries.map((entry) {
              final index = entry.key;
              final statusName = entry.value;
              final isCompleted = index <= currentIndex;
              final isCurrent = index == currentIndex;

              DateTime? timestamp;
              if (statusName == 'DRAFT' && createdAt != null) {
                timestamp = createdAt;
              } else if (statusName == 'PENDING' && submittedAt != null) {
                timestamp = submittedAt;
              } else if ((statusName == 'APPROVED' || statusName == 'REJECTED' || statusName == 'PUBLISHED') && decidedAt != null) {
                timestamp = decidedAt;
              }

              return _buildTimelineItem(theme, statusName, isCompleted, isCurrent, timestamp);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem(
    ThemeData theme,
    String status,
    bool isCompleted,
    bool isCurrent,
    DateTime? timestamp,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted
                  ? (isCurrent ? theme.colorScheme.primary : Colors.green)
                  : Colors.grey.shade300,
            ),
            child: isCompleted
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status.replaceAll('_', ' '),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    color: isCurrent ? theme.colorScheme.primary : null,
                  ),
                ),
                if (timestamp != null)
                  Text(
                    _formatDateTime(timestamp),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStationInfoSection(ThemeData theme, Map<String, dynamic> cr) {
    final stationName = cr['stationName'] as String? ?? 'Unnamed station';
    final operatingHours = cr['operatingHours'] as String?;
    final parkingFee = cr['parkingFee'];
    final note = cr['note'] as String?;
    final versionNo = cr['versionNo'] as int?;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                FaIcon(
                  FontAwesomeIcons.bolt,
                  size: 20,
                  color: Colors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    stationName,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (versionNo != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'v$versionNo',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const Divider(height: 24),
            if (operatingHours != null && operatingHours.isNotEmpty) ...[
              _buildInfoRow(theme, FontAwesomeIcons.clock, 'Operating Hours', operatingHours),
              const SizedBox(height: 12),
            ],
            if (parkingFee != null) ...[
              _buildInfoRow(theme, FontAwesomeIcons.car, 'Parking Fee',
                  '${(parkingFee as num).toStringAsFixed(0)} VND'),
              const SizedBox(height: 12),
            ],
            if (note != null && note.isNotEmpty) ...[
              _buildInfoRow(theme, FontAwesomeIcons.noteSticky, 'Note', note),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBatterySwapConfigSection(ThemeData theme, Map<String, dynamic> cr) {
    final totalBatteries = cr['totalBatteries'] as int?;
    final avgPowerKw = cr['avgChargePowerKw'] as num?;
    final piles = cr['pileTemplates'] as List<dynamic>? ?? [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Battery Swap Configuration',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    theme,
                    icon: FontAwesomeIcons.batteryFull,
                    label: 'Total Batteries',
                    value: totalBatteries?.toString() ?? '-',
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    theme,
                    icon: FontAwesomeIcons.bolt,
                    label: 'Avg Power',
                    value: avgPowerKw != null ? '${avgPowerKw.toStringAsFixed(1)} kW' : '-',
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            if (piles.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Pile Layout',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              ...piles.asMap().entries.map((entry) {
                final pileIndex = entry.key;
                final pile = entry.value as Map<String, dynamic>;
                final slots = pile['slots'] as List<dynamic>? ?? [];
                final slotsPerPile = pile['slotsPerPile'] as int? ?? 0;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pile ${pileIndex + 1} ($slotsPerPile slots)',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (slots.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: slots.map<Widget>((slot) {
                            final cap = slot['batteryCapacityKwh'] as num?;
                            return Chip(
                              label: Text(
                                cap != null
                                    ? '${cap.toStringAsFixed(1)} kWh'
                                    : 'Slot',
                                style: theme.textTheme.bodySmall,
                              ),
                              backgroundColor: theme.colorScheme.surfaceContainerHighest,
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FaIcon(icon, size: 20, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminNoteSection(ThemeData theme, String adminNote) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Admin Note',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(adminNote, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(ThemeData theme, IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FaIcon(icon, size: 16, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              Text(value, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _handleSubmit(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit Battery Swap Proposal'),
        content: const Text('Are you sure you want to submit this proposal for review?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final repository = ref.read(batterySwapChangeRequestRepositoryProvider);
        await repository.submitChangeRequest(changeRequestId);

        if (context.mounted) {
          AppToast.showSuccess(context, 'Proposal submitted successfully');
          ref.invalidate(batterySwapChangeRequestDetailProvider(changeRequestId));
        }
      } catch (e) {
        if (context.mounted) {
          AppToast.showError(context, 'Submit failed: ${formatApiError(e)}');
        }
      }
    }
  }

  DateTime? _parseDateTime(String? dateStr) {
    if (dateStr == null) return null;
    try {
      return DateTime.parse(dateStr).toLocal();
    } catch (e) {
      return null;
    }
  }

  String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
