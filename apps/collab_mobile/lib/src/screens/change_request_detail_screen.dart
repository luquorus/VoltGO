import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_ui/shared_ui.dart';
import '../providers/change_request_providers.dart';
import '../widgets/main_scaffold.dart';

/// Change Request Detail Screen (charging-station) for collaborators.
class CollabChangeRequestDetailScreen extends ConsumerStatefulWidget {
  final String changeRequestId;
  const CollabChangeRequestDetailScreen({
    super.key,
    required this.changeRequestId,
  });

  @override
  ConsumerState<CollabChangeRequestDetailScreen> createState() =>
      _CollabChangeRequestDetailScreenState();
}

class _CollabChangeRequestDetailScreenState
    extends ConsumerState<CollabChangeRequestDetailScreen> {
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final asyncCr =
        ref.watch(chargingChangeRequestDetailProvider(widget.changeRequestId));

    return CollabMainScaffold(
      title: 'Change request',
      showBottomNav: false,
      child: asyncCr.when(
        loading: () => const SkeletonList(count: 3),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () =>
              ref.invalidate(chargingChangeRequestDetailProvider(widget.changeRequestId)),
        ),
        data: (cr) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(theme, cr),
                const SizedBox(height: 16),
                _buildDetails(theme, cr),
                if (cr.adminNote != null && cr.adminNote!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildAdminNote(theme, cr),
                ],
                const SizedBox(height: 24),
                if (cr.isDraft)
                  PrimaryButton(
                    label: 'Submit for review',
                    isLoading: _isSubmitting,
                    onPressed: _isSubmitting ? null : () => _handleSubmit(cr.id),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const FaIcon(FontAwesomeIcons.infoCircle, size: 14),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            cr.isPending
                                ? 'This change request is awaiting admin review.'
                                : cr.isPublished
                                    ? 'This proposal has been published and is now live.'
                                    : cr.isRejected
                                        ? 'This proposal was rejected. You can create a new one if needed.'
                                        : 'No further action available.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, dynamic cr) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  cr.type == 'CREATE_STATION'
                      ? Icons.add_circle_outline
                      : Icons.edit_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  cr.type.replaceAll('_', ' '),
                  style: theme.textTheme.titleMedium,
                ),
                const Spacer(),
                _buildStatusChip(theme, cr.status),
              ],
            ),
            const SizedBox(height: 12),
            if (cr.stationName != null)
              Text(
                cr.stationName!,
                style: theme.textTheme.titleLarge,
              ),
            if (cr.riskScore != null && cr.riskScore! > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const FaIcon(FontAwesomeIcons.gaugeHigh, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    'Risk score: ${cr.riskScore}'
                    '${cr.riskLevel != null ? ' • ${cr.riskLevel}' : ''}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetails(ThemeData theme, dynamic cr) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Timeline', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            _buildTimelineRow(theme, 'Created', cr.createdAt),
            if (cr.submittedAt != null)
              _buildTimelineRow(theme, 'Submitted', cr.submittedAt),
            if (cr.decidedAt != null)
              _buildTimelineRow(theme, 'Decided', cr.decidedAt),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineRow(ThemeData theme, String label, dynamic value) {
    final dt = value as DateTime?;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: theme.textTheme.bodySmall),
          ),
          Text(
            dt != null ? _formatDateTime(dt) : '—',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildAdminNote(ThemeData theme, dynamic cr) {
    return Card(
      color: theme.colorScheme.errorContainer.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.comment_outlined,
                    color: theme.colorScheme.error, size: 18),
                const SizedBox(width: 8),
                Text('Admin note', style: theme.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 8),
            Text(cr.adminNote!, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(ThemeData theme, String status) {
    Color color;
    switch (status) {
      case 'PENDING':
        color = Colors.amber.shade800;
        break;
      case 'APPROVED':
        color = Colors.blue;
        break;
      case 'REJECTED':
        color = Colors.red;
        break;
      case 'PUBLISHED':
        color = Colors.green;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _handleSubmit(String id) async {
    setState(() => _isSubmitting = true);
    try {
      final repo = ref.read(changeRequestRepositoryProvider);
      await repo.submitChangeRequest(id);
      if (!mounted) return;
      AppToast.showSuccess(context, 'Submitted for review');
      ref.invalidate(chargingChangeRequestDetailProvider(id));
      ref.invalidate(changeRequestListProvider);
    } catch (e) {
      if (!mounted) return;
      AppToast.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
