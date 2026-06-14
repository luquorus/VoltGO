import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_ui/shared_ui.dart';
import '../providers/change_request_providers.dart';
import '../repositories/battery_swap_change_request_repository.dart';
import '../widgets/main_scaffold.dart';

/// Change Request List Screen for Collaborators.
///
/// Shows BOTH charging-station and battery-swap change requests owned by the
/// current collaborator in a single unified list. Users tap a row to drill
/// into the appropriate detail screen.
class CollabChangeRequestListScreen extends ConsumerStatefulWidget {
  const CollabChangeRequestListScreen({super.key});

  @override
  ConsumerState<CollabChangeRequestListScreen> createState() =>
      _CollabChangeRequestListScreenState();
}

class _CollabChangeRequestListScreenState
    extends ConsumerState<CollabChangeRequestListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(changeRequestListProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(changeRequestListProvider);
    final theme = Theme.of(context);

    return CollabMainScaffold(
      title: 'My change requests',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/change-requests/create'),
        backgroundColor: theme.colorScheme.primary,
        icon: const FaIcon(FontAwesomeIcons.plus, size: 14, color: Colors.white),
        label: const Text('New', style: TextStyle(color: Colors.white)),
      ),
      child: RefreshIndicator(
        onRefresh: () => ref.read(changeRequestListProvider.notifier).refresh(),
        child: _buildContent(context, state, theme),
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, ChangeRequestListState state, ThemeData theme) {
    if (state.isLoading && state.changeRequests.isEmpty) {
      return const SkeletonList(count: 4);
    }
    if (state.error != null && state.changeRequests.isEmpty) {
      return ErrorState(
        message: state.error!,
        onRetry: () => ref.read(changeRequestListProvider.notifier).refresh(),
      );
    }
    if (state.changeRequests.isEmpty) {
      return EmptyState(
        icon: FontAwesomeIcons.filePen,
        title: 'No change requests yet',
        message:
            'You can propose edits to stations after on-site verification. Admins will review your proposal.',
        action: ElevatedButton.icon(
          onPressed: () => context.push('/change-requests/create'),
          icon: const FaIcon(FontAwesomeIcons.plus, size: 14),
          label: const Text('Create proposal'),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: state.changeRequests.length,
      itemBuilder: (context, index) {
        return _ChangeRequestCard(cr: state.changeRequests[index]);
      },
    );
  }
}

class _ChangeRequestCard extends StatelessWidget {
  final UnifiedChangeRequest cr;
  const _ChangeRequestCard({required this.cr});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSwap = cr.kind == 'BATTERY_SWAP';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          if (isSwap) {
            context.push('/change-requests/battery-swap/${cr.id}');
          } else {
            context.push('/change-requests/${cr.id}');
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isSwap
                          ? Colors.orange.withOpacity(0.15)
                          : Colors.blue.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isSwap ? 'Battery Swap' : 'Charging',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isSwap ? Colors.orange : Colors.blue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusChip(status: cr.status),
                  const Spacer(),
                  if (cr.riskScore != null && cr.riskScore! > 0)
                    Text(
                      'Risk ${cr.riskScore}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                cr.displayName ??
                    (cr.type == 'CREATE_STATION' ||
                            cr.type == 'CREATE_BATTERY_SWAP_STATION'
                        ? 'New station proposal'
                        : 'Station update proposal'),
                style: theme.textTheme.titleMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                cr.type.replaceAll('_', ' ').toLowerCase(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              if (cr.adminNote != null && cr.adminNote!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const FaIcon(FontAwesomeIcons.commentDots, size: 12),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          cr.adminNote!,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'DRAFT':
        return Colors.grey;
      case 'PENDING':
        return Colors.amber.shade800;
      case 'APPROVED':
        return Colors.blue;
      case 'REJECTED':
        return Colors.red;
      case 'PUBLISHED':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
