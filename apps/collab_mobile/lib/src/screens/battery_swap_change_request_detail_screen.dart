import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_ui/shared_ui.dart';
import '../providers/change_request_providers.dart';
import '../widgets/main_scaffold.dart';

/// Battery-Swap Change Request Detail Screen for collaborators.
class CollabBatterySwapChangeRequestDetailScreen extends ConsumerStatefulWidget {
  final String changeRequestId;
  const CollabBatterySwapChangeRequestDetailScreen({
    super.key,
    required this.changeRequestId,
  });

  @override
  ConsumerState<CollabBatterySwapChangeRequestDetailScreen> createState() =>
      _CollabBatterySwapChangeRequestDetailScreenState();
}

class _CollabBatterySwapChangeRequestDetailScreenState
    extends ConsumerState<CollabBatterySwapChangeRequestDetailScreen> {
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final asyncCr = ref.watch(
        batterySwapChangeRequestDetailProvider(widget.changeRequestId));

    return CollabMainScaffold(
      title: 'Battery-swap CR',
      showBottomNav: false,
      child: asyncCr.when(
        loading: () => const SkeletonList(count: 3),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(
              batterySwapChangeRequestDetailProvider(widget.changeRequestId)),
        ),
        data: (cr) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(theme, cr),
                const SizedBox(height: 16),
                _buildConfig(theme, cr),
                const SizedBox(height: 16),
                _buildTimeline(theme, cr),
                if (cr.adminNote != null && cr.adminNote!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildAdminNote(theme, cr),
                ],
                const SizedBox(height: 24),
                if (cr.isDraft)
                  PrimaryButton(
                    label: 'Submit for review',
                    isLoading: _isSubmitting,
                    onPressed: _isSubmitting
                        ? null
                        : () => _handleSubmit(cr.id),
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
                                ? 'Awaiting admin review.'
                                : cr.isPublished
                                    ? 'Published and live.'
                                    : cr.isRejected
                                        ? 'Rejected by admin.'
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
                Icon(Icons.battery_charging_full,
                    color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    cr.type.replaceAll('_', ' '),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                _buildStatusChip(theme, cr.status),
              ],
            ),
            const SizedBox(height: 8),
            if (cr.riskScore != null && cr.riskScore! > 0)
              Text(
                'Risk score: ${cr.riskScore}',
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfig(ThemeData theme, dynamic cr) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Configuration', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            _row(theme, 'Total batteries', cr.totalBatteries?.toString() ?? '—'),
            _row(theme, 'Avg charge power',
                cr.avgChargePowerKw != null ? '${cr.avgChargePowerKw} kW' : '—'),
            _row(theme, 'Operating hours', cr.operatingHours ?? '—'),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeline(ThemeData theme, dynamic cr) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Timeline', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            _row(theme, 'Created', _fmt(cr.createdAt)),
            if (cr.submittedAt != null)
              _row(theme, 'Submitted', _fmt(cr.submittedAt)),
            if (cr.decidedAt != null)
              _row(theme, 'Decided', _fmt(cr.decidedAt)),
          ],
        ),
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
            Text('Admin note', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Text(cr.adminNote!, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  Widget _row(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: theme.textTheme.bodySmall),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodyMedium),
          ),
        ],
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

  String _fmt(DateTime? dt) {
    if (dt == null) return '—';
    final l = dt.toLocal();
    return '${l.year}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')} '
        '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _handleSubmit(String id) async {
    setState(() => _isSubmitting = true);
    try {
      final repo = ref.read(batterySwapChangeRequestRepositoryProvider);
      await repo.submitChangeRequest(id);
      if (!mounted) return;
      AppToast.showSuccess(context, 'Submitted for review');
      ref.invalidate(batterySwapChangeRequestDetailProvider(id));
      ref.invalidate(changeRequestListProvider);
    } catch (e) {
      if (!mounted) return;
      AppToast.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
