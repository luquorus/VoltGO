import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_api/shared_api.dart' hide RegistrationRequest, RegistrationRequestStatus;
import '../models/registration_request.dart';
import '../models/pagination_response.dart';
import '../providers/registration_request_providers.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_scaffold.dart';

class RegistrationRequestsListScreen extends ConsumerStatefulWidget {
  const RegistrationRequestsListScreen({super.key});

  @override
  ConsumerState<RegistrationRequestsListScreen> createState() =>
      _RegistrationRequestsListScreenState();
}

class _RegistrationRequestsListScreenState
    extends ConsumerState<RegistrationRequestsListScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pagination = ref.watch(registrationRequestPaginationProvider);
    final requestsAsync = ref.watch(registrationRequestsProvider);

    return AdminScaffold(
      title: 'Registration Requests',
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Collaborator Registration Requests',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AdminTheme.primaryTealDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Status Filter Tabs
            _buildStatusTabs(theme, pagination),
            const SizedBox(height: 16),

            // Table
            Expanded(
              child: Card(
                margin: EdgeInsets.zero,
                child: requestsAsync.when(
                  data: (paginationResponse) =>
                      _buildRequestsTable(theme, paginationResponse, pagination),
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  error: (error, stack) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Failed to load requests',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () =>
                              ref.invalidate(registrationRequestsProvider),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTabs(
      ThemeData theme, RegistrationRequestPagination pagination) {
    return Container(
      decoration: BoxDecoration(
        color: AdminTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildTab(
            theme,
            'All',
            null,
            pagination.statusFilter == null,
            pagination,
          ),
          _buildTab(
            theme,
            'Pending',
            RegistrationRequestStatus.pending,
            pagination.statusFilter == RegistrationRequestStatus.pending,
            pagination,
          ),
          _buildTab(
            theme,
            'Rejected',
            RegistrationRequestStatus.rejected,
            pagination.statusFilter == RegistrationRequestStatus.rejected,
            pagination,
          ),
        ],
      ),
    );
  }

  Widget _buildTab(
    ThemeData theme,
    String label,
    RegistrationRequestStatus? status,
    bool isActive,
    RegistrationRequestPagination pagination,
  ) {
    return Expanded(
      child: InkWell(
        onTap: () {
          ref.read(registrationRequestPaginationProvider.notifier).state =
              pagination.copyWith(
            page: 0,
            statusFilter: status,
            clearStatusFilter: status == null,
          );
          ref.invalidate(registrationRequestsProvider);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? AdminTheme.primaryTeal : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              color: isActive ? Colors.white : Colors.grey[600],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequestsTable(
    ThemeData theme,
    PaginationResponse<RegistrationRequest> paginationResponse,
    RegistrationRequestPagination pagination,
  ) {
    final requests = paginationResponse.content;

    if (requests.isEmpty && paginationResponse.page == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.assignment_outlined,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'No registration requests found',
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
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
                  'Email',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Full Name',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Phone',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  'Status',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  'Submitted',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 48),
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
              final request = requests[index];
              return _buildRequestRow(theme, request);
            },
          ),
        ),

        // Pagination Controls
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: theme.colorScheme.outline.withOpacity(0.2),
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Showing ${requests.length} of ${paginationResponse.totalElements} requests',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: paginationResponse.first
                        ? null
                        : () {
                            ref
                                .read(registrationRequestPaginationProvider.notifier)
                                .state = pagination.copyWith(
                              page: pagination.page - 1,
                            );
                            ref.invalidate(registrationRequestsProvider);
                          },
                  ),
                  Text(
                    'Page ${paginationResponse.page + 1} of ${paginationResponse.totalPages}',
                    style: theme.textTheme.bodyMedium,
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: paginationResponse.last
                        ? null
                        : () {
                            ref
                                .read(registrationRequestPaginationProvider.notifier)
                                .state = pagination.copyWith(
                              page: pagination.page + 1,
                            );
                            ref.invalidate(registrationRequestsProvider);
                          },
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRequestRow(ThemeData theme, RegistrationRequest request) {
    return InkWell(
      onTap: () {
        context.push('/registration-requests/${request.id}');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                request.email,
                style: theme.textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                request.fullName,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                request.phone ?? 'N/A',
                style: theme.textTheme.bodyMedium,
              ),
            ),
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: request.status.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  request.status.displayName,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: request.status.color,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                _formatDate(request.createdAt),
                style: theme.textTheme.bodySmall,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () {
                context.push('/registration-requests/${request.id}');
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
