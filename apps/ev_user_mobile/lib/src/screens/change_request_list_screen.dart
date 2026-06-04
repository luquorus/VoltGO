import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_ui/shared_ui.dart';
import '../providers/change_request_providers.dart';
import '../widgets/main_scaffold.dart';

/// Change Request List Screen
class ChangeRequestListScreen extends ConsumerStatefulWidget {
  const ChangeRequestListScreen({super.key});

  @override
  ConsumerState<ChangeRequestListScreen> createState() => _ChangeRequestListScreenState();
}

class _ChangeRequestListScreenState extends ConsumerState<ChangeRequestListScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(changeRequestListProvider);
    final theme = Theme.of(context);

    return MainScaffold(
      title: 'Station edit proposals',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/change-requests/create'),
        backgroundColor: theme.colorScheme.primary,
        icon: const FaIcon(FontAwesomeIcons.plus, size: 14, color: Colors.white),
        label: const Text('Create new', style: TextStyle(color: Colors.white)),
      ),
      child: RefreshIndicator(
        onRefresh: () => ref.read(changeRequestListProvider.notifier).refresh(),
        child: _buildContent(context, ref, state, theme),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    ChangeRequestListState state,
    ThemeData theme,
  ) {
    if (state.isLoading && state.changeRequests.isEmpty) {
      return const SkeletonList(count: 4);
    }

    if (state.error != null && state.changeRequests.isEmpty) {
      return ErrorState(
        message: formatApiError(state.error),
        onRetry: () => ref.read(changeRequestListProvider.notifier).refresh(),
      );
    }

    if (state.changeRequests.isEmpty) {
      return EmptyState(
        icon: FontAwesomeIcons.filePen,
        title: 'No proposals yet',
        message:
            'You can propose creating or editing station information to improve our data.',
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
        final cr = state.changeRequests[index];
        return _ChangeRequestCard(cr: cr);
      },
    );
  }
}

class _ChangeRequestCard extends StatelessWidget {
  final ChangeRequestListItem cr;

  const _ChangeRequestCard({required this.cr});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          if (cr.kind == 'BATTERY_SWAP') {
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
                  // Station kind badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: cr.kind == 'BATTERY_SWAP'
                          ? Colors.orange.withOpacity(0.15)
                          : Colors.blue.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      cr.kind == 'BATTERY_SWAP' ? 'Battery Swap' : 'Charging',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cr.kind == 'BATTERY_SWAP' ? Colors.orange : Colors.blue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      cr.stationName,
                      style: theme.textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  StatusPill(
                    label: _statusLabel(cr.status),
                    colorMapper: (_) => _statusColor(cr.status),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  FaIcon(
                    FontAwesomeIcons.bolt,
                    size: 12,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${_typeLabel(cr.type)} • #${cr.id.length >= 8 ? cr.id.substring(0, 8) : cr.id}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const Spacer(),
                  if (cr.createdAt != null)
                    Row(
                      children: [
                        FaIcon(
                          FontAwesomeIcons.calendar,
                          size: 12,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDateTime(cr.createdAt!),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'CREATE':
        return 'Create';
      case 'UPDATE':
        return 'Update';
      case 'DELETE':
        return 'Delete';
      default:
        return type.replaceAll('_', ' ');
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'DRAFT':
        return 'Draft';
      case 'PENDING':
        return 'Pending review';
      case 'APPROVED':
        return 'Approved';
      case 'REJECTED':
        return 'Rejected';
      case 'PUBLISHED':
        return 'Published';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'DRAFT':
        return Colors.grey;
      case 'PENDING':
        return Colors.orange;
      case 'APPROVED':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      case 'PUBLISHED':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}

