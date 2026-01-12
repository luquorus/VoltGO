import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';
import '../models/admin_change_request.dart';
import '../providers/change_request_providers.dart';
import '../theme/admin_theme.dart';

/// Change Requests List Screen
class ChangeRequestsScreen extends ConsumerStatefulWidget {
  const ChangeRequestsScreen({super.key});

  @override
  ConsumerState<ChangeRequestsScreen> createState() =>
      _ChangeRequestsScreenState();
}

class _ChangeRequestsScreenState extends ConsumerState<ChangeRequestsScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filters = ref.watch(changeRequestFiltersProvider);
    final changeRequestsAsync = ref.watch(changeRequestsProvider);

    return AppScaffold(
      title: 'Change Requests',
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filters
            _buildFilterPanel(theme, filters),
            const SizedBox(height: 24),

            // Stats Row
            _buildStatsRow(theme, changeRequestsAsync),
            const SizedBox(height: 24),

            // Change Requests Table
            Expanded(
              child: Card(
                margin: EdgeInsets.zero,
                child: changeRequestsAsync.when(
                  data: (requests) => _buildChangeRequestsTable(theme, requests),
                  loading: () => const LoadingState(message: 'Loading change requests...'),
                  error: (error, stack) => ErrorState(
                    message: error.toString(),
                    onRetry: () {
                      ref.invalidate(changeRequestsProvider);
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

  Widget _buildFilterPanel(ThemeData theme, ChangeRequestFilters filters) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Text(
            'Filter by Status:',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.colorScheme.outline),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<ChangeRequestStatus?>(
                value: filters.status,
                hint: Text(
                  'All Status',
                  style: theme.textTheme.bodyMedium,
                ),
                items: [
                  const DropdownMenuItem<ChangeRequestStatus?>(
                    value: null,
                    child: Text('All Status'),
                  ),
                  ...ChangeRequestStatus.values.map((status) =>
                      DropdownMenuItem<ChangeRequestStatus>(
                        value: status,
                        child: Text(status.displayName),
                      )),
                ],
                onChanged: (value) {
                  ref.read(changeRequestFiltersProvider.notifier).state =
                      filters.copyWith(status: value, clearStatus: value == null);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(
      ThemeData theme, AsyncValue<List<AdminChangeRequest>> changeRequestsAsync) {
    int total = 0;
    int pending = 0;
    int approved = 0;
    int rejected = 0;

    changeRequestsAsync.whenData((requests) {
      total = requests.length;
      for (final cr in requests) {
        switch (cr.status) {
          case ChangeRequestStatus.pending:
            pending++;
            break;
          case ChangeRequestStatus.approved:
            approved++;
            break;
          case ChangeRequestStatus.rejected:
            rejected++;
            break;
          default:
            break;
        }
      }
    });

    return Row(
      children: [
        _buildStatCard(
          theme,
          icon: Icons.description,
          label: 'Total',
          value: total.toString(),
          color: AdminTheme.primaryTeal,
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          theme,
          icon: Icons.pending_actions,
          label: 'Pending',
          value: pending.toString(),
          color: Colors.orange,
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          theme,
          icon: Icons.check_circle,
          label: 'Approved',
          value: approved.toString(),
          color: Colors.green,
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          theme,
          icon: Icons.cancel,
          label: 'Rejected',
          value: rejected.toString(),
          color: Colors.red,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChangeRequestsTable(
      ThemeData theme, List<AdminChangeRequest> requests) {
    if (requests.isEmpty) {
      return EmptyState(
        icon: Icons.description_outlined,
        message: 'No change requests found',
        action: OutlinedButton.icon(
          onPressed: () {
            ref.invalidate(changeRequestsProvider);
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
        ),
      );
    }

    return Column(
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: AdminTheme.surfaceLight,
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outline.withOpacity(0.2),
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  'Type',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Status',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Submitter',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Risk Score',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Submitted',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 48), // Action column
            ],
          ),
        ),

        // Table Body
        Expanded(
          child: ListView.separated(
            itemCount: requests.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: theme.colorScheme.outline.withOpacity(0.1),
            ),
            itemBuilder: (context, index) {
              final cr = requests[index];
              return _buildChangeRequestRow(theme, cr);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildChangeRequestRow(
      ThemeData theme, AdminChangeRequest cr) {
    return InkWell(
      onTap: () {
        context.push('/change-requests/${cr.id}');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                cr.type.displayName,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            Expanded(
              flex: 2,
              child: StatusPill(
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
                      return AppTheme.primaryGreen;
                    case ChangeRequestStatus.draft:
                      return Colors.grey;
                  }
                },
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                cr.submitterEmail ?? 'N/A',
                style: theme.textTheme.bodyMedium,
              ),
            ),
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  if (cr.riskScore != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getRiskColor(cr.riskScore!)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _getRiskColor(cr.riskScore!),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '${cr.riskScore}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _getRiskColor(cr.riskScore!),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ] else
                    Text(
                      'N/A',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.4),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                cr.submittedAt != null
                    ? _formatDateTime(cr.submittedAt!)
                    : 'N/A',
                style: theme.textTheme.bodySmall,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () {
                context.push('/change-requests/${cr.id}');
              },
            ),
          ],
        ),
      ),
    );
  }

  Color _getRiskColor(int riskScore) {
    if (riskScore >= 60) return Colors.red;
    if (riskScore >= 30) return Colors.orange;
    return Colors.green;
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

