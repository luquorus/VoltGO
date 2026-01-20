import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:shared_auth/shared_auth.dart';
import '../providers/change_request_providers.dart';
import '../widgets/main_scaffold.dart';

/// Change Request List Screen
class ChangeRequestListScreen extends ConsumerStatefulWidget {
  const ChangeRequestListScreen({super.key});

  @override
  ConsumerState<ChangeRequestListScreen> createState() => _ChangeRequestListScreenState();
}

class _ChangeRequestListScreenState extends ConsumerState<ChangeRequestListScreen> {
  String? _lastUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = ref.read(authStateProvider);
      _lastUserId = authState.userId;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(changeRequestListProvider);
    final authState = ref.watch(authStateProvider);
    final theme = Theme.of(context);

    // Refresh list if userId changed
    if (_lastUserId != null && _lastUserId != authState.userId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(changeRequestListProvider.notifier).refresh();
      });
      _lastUserId = authState.userId;
    } else if (_lastUserId == null) {
      _lastUserId = authState.userId;
    }

    return MainScaffold(
      title: 'Station Proposals',
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/change-requests/create'),
        backgroundColor: theme.colorScheme.primary,
        child: const FaIcon(
          FontAwesomeIcons.plus,
          color: Colors.white,
        ),
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
      return const LoadingState();
    }

    if (state.error != null && state.changeRequests.isEmpty) {
      return ErrorState(
        message: state.error!,
        onRetry: () => ref.read(changeRequestListProvider.notifier).refresh(),
      );
    }

    if (state.changeRequests.isEmpty) {
      return const EmptyState(message: 'No station proposals found');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: state.changeRequests.length,
      itemBuilder: (context, index) {
        final cr = state.changeRequests[index];
        return _ChangeRequestCard(changeRequest: cr);
      },
    );
  }
}

class _ChangeRequestCard extends StatelessWidget {
  final Map<String, dynamic> changeRequest;

  const _ChangeRequestCard({required this.changeRequest});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final id = changeRequest['id'] as String? ?? '';
    final type = changeRequest['type'] as String? ?? 'UNKNOWN';
    final status = changeRequest['status'] as String? ?? 'UNKNOWN';
    final createdAt = _parseDateTime(changeRequest['createdAt'] as String?);
    final stationData = changeRequest['stationData'] as Map<String, dynamic>?;
    final stationName = stationData?['name'] as String? ?? 'Unknown Station';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/change-requests/$id'),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                          stationName,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${type.replaceAll('_', ' ')} • #${id.substring(0, 8)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusPill(
                    label: status,
                    colorMapper: (status) {
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
                    },
                  ),
                ],
              ),
              if (createdAt != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    FaIcon(
                      FontAwesomeIcons.calendar,
                      size: 12,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDateTime(createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
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

