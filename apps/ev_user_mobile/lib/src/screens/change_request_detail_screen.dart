import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_ui/shared_ui.dart';
import '../providers/change_request_providers.dart';
import '../widgets/main_scaffold.dart';

/// Change Request Detail Screen
class ChangeRequestDetailScreen extends ConsumerWidget {
  final String changeRequestId;

  const ChangeRequestDetailScreen({
    super.key,
    required this.changeRequestId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncValue = ref.watch(changeRequestDetailProvider(changeRequestId));
    final theme = Theme.of(context);

    return MainScaffold(
      title: 'Station Proposal',
      child: asyncValue.when(
        data: (data) => _buildContent(context, ref, data, theme),
        loading: () => const LoadingState(),
        error: (error, stack) => ErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(changeRequestDetailProvider(changeRequestId)),
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
    final riskScore = cr['riskScore'] as int?;
    final riskReasons = (cr['riskReasons'] as List<dynamic>?)?.cast<String>() ?? [];
    final stationData = cr['stationData'] as Map<String, dynamic>? ?? {};
    final createdAt = _parseDateTime(cr['createdAt'] as String?);
    final submittedAt = _parseDateTime(cr['submittedAt'] as String?);
    final decidedAt = _parseDateTime(cr['decidedAt'] as String?);
    final adminNote = cr['adminNote'] as String?;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Timeline
          _buildStatusTimeline(theme, status, createdAt, submittedAt, decidedAt),
          const SizedBox(height: 24),

          // Risk Score & Reasons
          if (riskScore != null || riskReasons.isNotEmpty) ...[
            _buildRiskSection(theme, riskScore, riskReasons),
            const SizedBox(height: 24),
          ],

          // Station Data
          _buildStationDataSection(theme, stationData),
          const SizedBox(height: 24),

          // Images
          _buildImagesSection(context, theme, cr),
          const SizedBox(height: 24),

          // Admin Note
          if (adminNote != null && adminNote.isNotEmpty) ...[
            _buildAdminNoteSection(theme, adminNote),
            const SizedBox(height: 24),
          ],

          // Submit Button (only for DRAFT)
          if (status == 'DRAFT') ...[
            PrimaryButton(
              label: 'Submit for Review',
              onPressed: () => _handleSubmit(context, ref),
            ),
          ],
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
    final statuses = ['DRAFT', 'PENDING', 'APPROVED', 'REJECTED', 'PUBLISHED'];
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

              return _buildTimelineItem(
                theme,
                statusName,
                isCompleted,
                isCurrent,
                timestamp,
              );
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
                ? Icon(
                    Icons.check,
                    size: 16,
                    color: Colors.white,
                  )
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

  Widget _buildRiskSection(ThemeData theme, int? riskScore, List<String> riskReasons) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Risk Assessment',
              style: theme.textTheme.titleMedium,
            ),
            if (riskScore != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _getRiskColor(riskScore).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _getRiskColor(riskScore),
                    width: 2,
                  ),
                ),
                child: Text(
                  'Risk Score: $riskScore',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: _getRiskColor(riskScore),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            if (riskReasons.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: riskReasons.map((reason) {
                  return Chip(
                    label: Text(reason),
                    backgroundColor: Colors.orange.withOpacity(0.1),
                    labelStyle: TextStyle(
                      color: Colors.orange.shade700,
                      fontSize: 12,
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStationDataSection(ThemeData theme, Map<String, dynamic> stationData) {
    final name = stationData['name'] as String? ?? '';
    final address = stationData['address'] as String? ?? '';
    final location = stationData['location'] as Map<String, dynamic>?;
    final lat = location?['lat'] as double?;
    final lng = location?['lng'] as double?;
    final operatingHours = stationData['operatingHours'] as String?;
    final parking = stationData['parking'] as String?;
    final visibility = stationData['visibility'] as String?;
    final publicStatus = stationData['publicStatus'] as String?;
    final services = (stationData['services'] as List<dynamic>?) ?? [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Station Information',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            _buildInfoRow(theme, FontAwesomeIcons.building, 'Name', name),
            if (address.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildInfoRow(theme, FontAwesomeIcons.locationDot, 'Address', address),
            ],
            if (lat != null && lng != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow(theme, FontAwesomeIcons.mapLocationDot, 'Location', 'Lat: $lat, Lng: $lng'),
            ],
            if (operatingHours != null && operatingHours.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildInfoRow(theme, FontAwesomeIcons.clock, 'Operating Hours', operatingHours),
            ],
            if (parking != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow(theme, FontAwesomeIcons.car, 'Parking', parking.replaceAll('_', ' ')),
            ],
            if (visibility != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow(theme, FontAwesomeIcons.eye, 'Visibility', visibility.replaceAll('_', ' ')),
            ],
            if (publicStatus != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow(theme, FontAwesomeIcons.globe, 'Public Status', publicStatus.replaceAll('_', ' ')),
            ],
            if (services.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Services',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              ...services.map((service) {
                final type = (service as Map<String, dynamic>)['type'] as String? ?? '';
                final chargingPorts = (service['chargingPorts'] as List<dynamic>?) ?? [];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildServiceItem(theme, type, chargingPorts),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildServiceItem(ThemeData theme, String type, List<dynamic> chargingPorts) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            type.replaceAll('_', ' '),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          if (chargingPorts.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...chargingPorts.map((port) {
              final powerType = (port as Map<String, dynamic>)['powerType'] as String? ?? '';
              final powerKw = port['powerKw'] as double?;
              final count = port['count'] as int? ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '  • $powerType: $count port${count > 1 ? 's' : ''}${powerKw != null ? ' @ ${powerKw}kW' : ''}',
                  style: theme.textTheme.bodySmall,
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildImagesSection(BuildContext context, ThemeData theme, Map<String, dynamic> cr) {
    final imageUrls = (cr['imageUrls'] as List<dynamic>?)?.cast<String>() ?? [];
    
    if (imageUrls.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Photos',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: imageUrls.map((objectKey) {
                return _buildImageThumbnail(context, theme, objectKey);
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageThumbnail(BuildContext context, ThemeData theme, String objectKey) {
    return GestureDetector(
      onTap: () {
        // TODO: Open image viewer with presigned URL
        AppToast.showInfo(context, 'Image: $objectKey');
      },
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(
              FontAwesomeIcons.image,
              color: theme.colorScheme.primary,
              size: 32,
            ),
            const SizedBox(height: 4),
            Text(
              'Photo',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
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
            Text(
              adminNote,
              style: theme.textTheme.bodyMedium,
            ),
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
              Text(
                value,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getRiskColor(int riskScore) {
    if (riskScore >= 70) return Colors.red;
    if (riskScore >= 40) return Colors.orange;
    return Colors.green;
  }

  Future<void> _handleSubmit(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit Station Proposal'),
        content: const Text('Are you sure you want to submit this station proposal for review?'),
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
        final repository = ref.read(changeRequestRepositoryProvider);
        await repository.submitChangeRequest(changeRequestId);
        
        if (context.mounted) {
          AppToast.showSuccess(context, 'Station proposal submitted successfully');
          ref.invalidate(changeRequestDetailProvider(changeRequestId));
          ref.invalidate(changeRequestListProvider);
        }
      } catch (e) {
        if (context.mounted) {
          AppToast.showError(context, 'Failed to submit: ${e.toString()}');
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

