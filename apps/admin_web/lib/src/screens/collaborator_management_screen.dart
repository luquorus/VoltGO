import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:shared_api/shared_api.dart' hide RegistrationRequest, RegistrationRequestStatus;
import '../models/contract.dart';
import '../models/registration_request.dart';
import '../models/pagination_response.dart';
import '../providers/registration_request_providers.dart';
import '../providers/contract_providers.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_scaffold.dart';

export '../providers/contract_providers.dart' show CollaboratorWithContracts, NoContractReason;

/// Tab definitions for the unified Collaborator Management screen
enum CollaboratorTab {
  registrationRequests('Registration Requests', Icons.pending_actions_rounded, 0),
  activeContracts('Active Contracts', Icons.description_rounded, 1),
  noContract('No Contract', Icons.warning_amber_rounded, 2);

  final String label;
  final IconData icon;
  final int tabIndex;

  const CollaboratorTab(this.label, this.icon, this.tabIndex);
}

/// Unified Collaborator Management Screen
/// Combines Registration Requests, Active Contracts, and No Contract tabs
class CollaboratorManagementScreen extends ConsumerStatefulWidget {
  const CollaboratorManagementScreen({super.key});

  @override
  ConsumerState<CollaboratorManagementScreen> createState() => _CollaboratorManagementScreenState();
}

class _CollaboratorManagementScreenState extends ConsumerState<CollaboratorManagementScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final Map<String, String> _searchQueries = {
    'registration': '',
    'active': '',
    'noContract': '',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pendingCount = ref.watch(pendingRequestsCountProvider);

    return AdminScaffold(
      title: 'Collaborator Management',
      body: Column(
        children: [
          // Tab Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Row(
                    children: [
                      Text(
                        'Collaborator Management',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AdminTheme.primaryTealDark,
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
                TabBar(
                  controller: _tabController,
                  isScrollable: false,
                  labelColor: AdminTheme.primaryTeal,
                  unselectedLabelColor: Colors.grey[600],
                  indicatorColor: AdminTheme.primaryTeal,
                  indicatorWeight: 3,
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelStyle: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  tabs: [
                    // Tab 1: Registration Requests with pending badge
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.pending_actions_rounded, size: 20),
                          const SizedBox(width: 8),
                          const Text('Registration Requests'),
                          const SizedBox(width: 8),
                          pendingCount.when(
                            data: (count) => count > 0
                                ? _Badge(
                                    count: count,
                                    color: Colors.red,
                                  )
                                : const SizedBox.shrink(),
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                    // Tab 2: Active Contracts
                    const Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.description_rounded, size: 20),
                          SizedBox(width: 8),
                          Text('Active Contracts'),
                        ],
                      ),
                    ),
                    // Tab 3: No Contract
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 20, color: Colors.orange[700]),
                          const SizedBox(width: 8),
                          const Text('No Contract'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _RegistrationRequestsTab(
                  searchQuery: _searchQueries['registration']!,
                  onSearchChanged: (q) => setState(() => _searchQueries['registration'] = q),
                ),
                _ActiveContractsTab(
                  searchQuery: _searchQueries['active']!,
                  onSearchChanged: (q) => setState(() => _searchQueries['active'] = q),
                ),
                _NoContractTab(
                  searchQuery: _searchQueries['noContract']!,
                  onSearchChanged: (q) => setState(() => _searchQueries['noContract'] = q),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Red badge widget for counts
class _Badge extends StatelessWidget {
  final int count;
  final Color color;

  const _Badge({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      constraints: const BoxConstraints(minWidth: 18),
      child: Text(
        count > 99 ? '99+' : count.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// =============================================================================
// TAB 1: REGISTRATION REQUESTS
// =============================================================================

class _RegistrationRequestsTab extends ConsumerStatefulWidget {
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;

  const _RegistrationRequestsTab({
    required this.searchQuery,
    required this.onSearchChanged,
  });

  @override
  ConsumerState<_RegistrationRequestsTab> createState() => _RegistrationRequestsTabState();
}

class _RegistrationRequestsTabState extends ConsumerState<_RegistrationRequestsTab> {
  RegistrationRequestStatus? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pagination = ref.watch(registrationRequestPaginationProvider);
    final requestsAsync = ref.watch(registrationRequestsProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Search and Filter Row
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by email, name, or phone...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: widget.searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => widget.onSearchChanged(''),
                          )
                        : null,
                  ),
                  onChanged: widget.onSearchChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Status Filter Tabs
          _buildStatusFilter(theme, pagination),
          const SizedBox(height: 16),

          // Table
          Expanded(
            child: Card(
              margin: EdgeInsets.zero,
              child: requestsAsync.when(
                data: (paginationResponse) => _buildTable(theme, paginationResponse, pagination),
                loading: () => const LoadingState(message: 'Loading requests...'),
                error: (error, stack) => ErrorState(
                  title: 'Could not load requests',
                  message: formatApiError(error),
                  code: extractErrorCode(error),
                  traceId: extractTraceId(error),
                  onRetry: () => ref.invalidate(registrationRequestsProvider),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilter(ThemeData theme, RegistrationRequestPagination pagination) {
    return Container(
      decoration: BoxDecoration(
        color: AdminTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildFilterTab(theme, 'All', null, pagination),
          _buildFilterTab(theme, 'Pending', RegistrationRequestStatus.pending, pagination),
          _buildFilterTab(theme, 'Rejected', RegistrationRequestStatus.rejected, pagination),
        ],
      ),
    );
  }

  Widget _buildFilterTab(
    ThemeData theme,
    String label,
    RegistrationRequestStatus? status,
    RegistrationRequestPagination pagination,
  ) {
    final isActive = _statusFilter == status;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() => _statusFilter = status);
          ref.read(registrationRequestPaginationProvider.notifier).state =
              pagination.copyWith(page: 0, statusFilter: status, clearStatusFilter: status == null);
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

  Widget _buildTable(
    ThemeData theme,
    PaginationResponse<RegistrationRequest> paginationResponse,
    RegistrationRequestPagination pagination,
  ) {
    var requests = paginationResponse.content;

    // Apply search filter
    if (widget.searchQuery.isNotEmpty) {
      final q = widget.searchQuery.toLowerCase();
      requests = requests.where((r) {
        return r.fullName.toLowerCase().contains(q) ||
            r.email.toLowerCase().contains(q) ||
            (r.phone?.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    if (requests.isEmpty && paginationResponse.page == 0) {
      return EmptyState(
        icon: Icons.assignment_outlined,
        message: 'No registration requests found',
      );
    }

    return Column(
      children: [
        // Table Header
        _buildTableHeader(theme),
        Expanded(
          child: ListView.separated(
            itemCount: requests.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) => _buildRequestRow(theme, requests[index]),
          ),
        ),
        _buildPaginationFooter(theme, paginationResponse, pagination),
      ],
    );
  }

  Widget _buildTableHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AdminTheme.surfaceLight,
        border: Border(bottom: BorderSide(color: theme.colorScheme.outline.withOpacity(0.2))),
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('Full Name', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600))),
          Expanded(flex: 2, child: Text('Email', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600))),
          Expanded(flex: 1, child: Text('Phone', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600))),
          Expanded(flex: 1, child: Text('Status', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600))),
          Expanded(flex: 1, child: Text('Submitted', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600))),
          const SizedBox(width: 48),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildRequestRow(ThemeData theme, RegistrationRequest request) {
    return InkWell(
      onTap: () => context.push('/registration-requests/${request.id}'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(request.fullName, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
            ),
            Expanded(
              flex: 2,
              child: Text(request.email, style: theme.textTheme.bodyMedium, overflow: TextOverflow.ellipsis),
            ),
            Expanded(
              flex: 1,
              child: Text(request.phone ?? 'N/A', style: theme.textTheme.bodyMedium),
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
                  style: theme.textTheme.bodySmall?.copyWith(color: request.status.color, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(_formatDate(request.createdAt), style: theme.textTheme.bodySmall),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => context.push('/registration-requests/${request.id}'),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _showDeleteRequestDialog(theme, request),
              tooltip: 'Delete request',
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteRequestDialog(ThemeData theme, RegistrationRequest request) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Registration Request'),
        content: Text(
          'Are you sure you want to delete the registration request from "${request.fullName}"?\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await _handleDeleteRequest(request.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteRequest(String requestId) async {
    try {
      final factory = ref.read(apiClientFactoryProvider);
      if (factory == null) throw Exception('API client not initialized');

      await factory.admin.delete<void>('/api/admin/registration-requests/$requestId');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration request deleted successfully.'),
            backgroundColor: Colors.green,
          ),
        );
        ref.invalidate(registrationRequestsProvider);
        ref.invalidate(pendingRequestsCountProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete request: ${formatApiError(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildPaginationFooter(
    ThemeData theme,
    PaginationResponse<RegistrationRequest> paginationResponse,
    RegistrationRequestPagination pagination,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.colorScheme.outline.withOpacity(0.2))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing ${paginationResponse.content.length} of ${paginationResponse.totalElements} requests',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6)),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: paginationResponse.first
                    ? null
                    : () {
                        ref.read(registrationRequestPaginationProvider.notifier).state =
                            pagination.copyWith(page: pagination.page - 1);
                        ref.invalidate(registrationRequestsProvider);
                      },
              ),
              Text('Page ${paginationResponse.page + 1} of ${paginationResponse.totalPages}', style: theme.textTheme.bodyMedium),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: paginationResponse.last
                    ? null
                    : () {
                        ref.read(registrationRequestPaginationProvider.notifier).state =
                            pagination.copyWith(page: pagination.page + 1);
                        ref.invalidate(registrationRequestsProvider);
                      },
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
}

// =============================================================================
// TAB 2: ACTIVE CONTRACTS
// =============================================================================

class _ActiveContractsTab extends ConsumerStatefulWidget {
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;

  const _ActiveContractsTab({required this.searchQuery, required this.onSearchChanged});

  @override
  ConsumerState<_ActiveContractsTab> createState() => _ActiveContractsTabState();
}

class _ActiveContractsTabState extends ConsumerState<_ActiveContractsTab> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allCollabAsync = ref.watch(allCollaboratorsProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Search Row
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by name, email, or region...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: widget.searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => widget.onSearchChanged(''),
                          )
                        : null,
                  ),
                  onChanged: widget.onSearchChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Table
          Expanded(
            child: Card(
              margin: EdgeInsets.zero,
              child: allCollabAsync.when(
                data: (collaborators) {
                  final active = _filterActive(collaborators, widget.searchQuery);
                  return _buildTable(context, theme, active);
                },
                loading: () => const LoadingState(message: 'Loading active contracts...'),
                error: (error, stack) => ErrorState(
                  title: 'Could not load data',
                  message: formatApiError(error),
                  code: extractErrorCode(error),
                  traceId: extractTraceId(error),
                  onRetry: () => ref.invalidate(allCollaboratorsProvider),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<CollaboratorWithContracts> _filterActive(List<CollaboratorWithContracts> all, String query) {
    var filtered = all.where((c) => c.hasActiveContract).toList();
    if (query.isEmpty) return filtered;
    final q = query.toLowerCase();
    return filtered.where((c) {
      final p = c.profile;
      final contractRegion = c.latestActiveContract?.region?.toLowerCase() ?? '';
      return (p.fullName?.toLowerCase().contains(q) ?? false) ||
          (p.email?.toLowerCase().contains(q) ?? false) ||
          contractRegion.contains(q);
    }).toList();
  }

  Widget _buildTable(BuildContext context, ThemeData theme, List<CollaboratorWithContracts> collaborators) {
    if (collaborators.isEmpty) {
      return EmptyState(
        icon: Icons.description_outlined,
        message: widget.searchQuery.isNotEmpty
            ? 'No active contracts match your search'
            : 'No collaborators with active contracts',
      );
    }

    return Column(
      children: [
        _buildHeader(theme),
        Expanded(
          child: ListView.separated(
            itemCount: collaborators.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) => _buildRow(context, theme, collaborators[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AdminTheme.surfaceLight,
        border: Border(bottom: BorderSide(color: theme.colorScheme.outline.withOpacity(0.2))),
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('Full Name', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600))),
          Expanded(flex: 2, child: Text('Email', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600))),
          Expanded(flex: 2, child: Text('Region', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600))),
          Expanded(flex: 2, child: Text('Contract Period', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600))),
          Expanded(flex: 1, child: Text('Status', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600))),
          const SizedBox(width: 48),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, ThemeData theme, CollaboratorWithContracts collab) {
    final activeContract = collab.latestActiveContract;
    return InkWell(
      onTap: () => context.push('/collaborators/${collab.profile.id}'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(collab.profile.fullName ?? 'N/A', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
            ),
            Expanded(
              flex: 2,
              child: Text(collab.profile.email ?? 'N/A', style: theme.textTheme.bodyMedium),
            ),
            Expanded(
              flex: 2,
              child: Text(activeContract?.region ?? 'N/A', style: theme.textTheme.bodyMedium),
            ),
            Expanded(
              flex: 2,
              child: Text(
                activeContract?.startDate != null && activeContract?.endDate != null
                    ? '${_fmt(activeContract!.startDate!)} - ${_fmt(activeContract.endDate!)}'
                    : 'N/A',
                style: theme.textTheme.bodySmall,
              ),
            ),
            Expanded(
              flex: 1,
              child: _buildStatusPill(theme, 'Active', Colors.green),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => context.push('/collaborators/${collab.profile.id}'),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _showDeleteDialog(context, collab),
              tooltip: 'Delete collaborator',
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, CollaboratorWithContracts collab) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Collaborator'),
        content: Text(
          'Are you sure you want to delete collaborator "${collab.profile.fullName ?? collab.profile.email}"?\n\n'
          'This will delete the collaborator profile and associated user account. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await _handleDelete(context, collab.profile.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDelete(BuildContext context, String collaboratorId) async {
    try {
      final factory = ref.read(apiClientFactoryProvider);
      if (factory == null) throw Exception('API client not initialized');

      await factory.admin.deleteCollaborator(collaboratorId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Collaborator deleted successfully.'),
            backgroundColor: Colors.green,
          ),
        );
        ref.invalidate(allCollaboratorsProvider);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete collaborator: ${formatApiError(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildStatusPill(ThemeData theme, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(label, style: theme.textTheme.bodySmall?.copyWith(color: color, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
    );
  }

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';
}

// =============================================================================
// TAB 3: NO CONTRACT
// =============================================================================

class _NoContractTab extends ConsumerStatefulWidget {
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;

  const _NoContractTab({required this.searchQuery, required this.onSearchChanged});

  @override
  ConsumerState<_NoContractTab> createState() => _NoContractTabState();
}

class _NoContractTabState extends ConsumerState<_NoContractTab> {
  NoContractReason? _reasonFilter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allCollabAsync = ref.watch(allCollaboratorsProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Search Row
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by name or email...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: widget.searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => widget.onSearchChanged(''),
                          )
                        : null,
                  ),
                  onChanged: widget.onSearchChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Reason Filter
          _buildReasonFilter(theme),
          const SizedBox(height: 16),

          // Table
          Expanded(
            child: Card(
              margin: EdgeInsets.zero,
              child: allCollabAsync.when(
                data: (collaborators) {
                  final noContract = _filterNoContract(collaborators, widget.searchQuery);
                  return _buildTable(context, theme, noContract);
                },
                loading: () => const LoadingState(message: 'Loading collaborators...'),
                error: (error, stack) => ErrorState(
                  title: 'Could not load data',
                  message: formatApiError(error),
                  code: extractErrorCode(error),
                  traceId: extractTraceId(error),
                  onRetry: () => ref.invalidate(allCollaboratorsProvider),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReasonFilter(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: AdminTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildReasonTab(theme, 'All', null),
          _buildReasonTab(theme, 'Chưa có HD', NoContractReason.neverHadContract),
          _buildReasonTab(theme, 'Hết hạn', NoContractReason.contractExpired),
          _buildReasonTab(theme, 'Hủy HD', NoContractReason.contractTerminated),
        ],
      ),
    );
  }

  Widget _buildReasonTab(ThemeData theme, String label, NoContractReason? reason) {
    final isActive = _reasonFilter == reason;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _reasonFilter = reason),
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

  List<CollaboratorWithContracts> _filterNoContract(
    List<CollaboratorWithContracts> all,
    String query,
  ) {
    var filtered = all.where((c) => !c.hasActiveContract).toList();
    if (_reasonFilter != null) {
      filtered = filtered.where((c) => c.noContractReason == _reasonFilter).toList();
    }
    if (query.isEmpty) return filtered;
    final q = query.toLowerCase();
    return filtered.where((c) {
      final p = c.profile;
      return (p.fullName?.toLowerCase().contains(q) ?? false) ||
          (p.email?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  Widget _buildTable(BuildContext context, ThemeData theme, List<CollaboratorWithContracts> collaborators) {
    if (collaborators.isEmpty) {
      return EmptyState(
        icon: Icons.warning_amber_outlined,
        message: widget.searchQuery.isNotEmpty || _reasonFilter != null
            ? 'No collaborators match your filters'
            : 'No collaborators without active contracts',
      );
    }

    return Column(
      children: [
        _buildHeader(theme),
        Expanded(
          child: ListView.separated(
            itemCount: collaborators.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) => _buildRow(context, theme, collaborators[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AdminTheme.surfaceLight,
        border: Border(bottom: BorderSide(color: theme.colorScheme.outline.withOpacity(0.2))),
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('Full Name', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600))),
          Expanded(flex: 2, child: Text('Email', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600))),
          Expanded(flex: 1, child: Text('Phone', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600))),
          Expanded(flex: 2, child: Text('Reason', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600))),
          Expanded(flex: 2, child: Text('Last Contract', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600))),
          const SizedBox(width: 120),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, ThemeData theme, CollaboratorWithContracts collab) {
    final reason = collab.noContractReason;
    final latest = collab.latestContract;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: InkWell(
              onTap: () => context.push('/collaborators/${collab.profile.id}'),
              child: Text(collab.profile.fullName ?? 'N/A', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500, color: AdminTheme.primaryTeal)),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(collab.profile.email ?? 'N/A', style: theme.textTheme.bodyMedium),
          ),
          Expanded(
            flex: 1,
            child: Text(collab.profile.phone ?? 'N/A', style: theme.textTheme.bodyMedium),
          ),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (reason?.color ?? Colors.grey).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: reason?.color ?? Colors.grey),
              ),
              child: Text(
                reason?.label ?? 'Unknown',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: reason?.color ?? Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              latest != null
                  ? '${_fmt(latest.startDate ?? latest.createdAt!)} - ${latest.endDate != null ? _fmt(latest.endDate!) : ' ongoing'}'
                      '\n${latest.status.displayName}'
                  : 'Never',
              style: theme.textTheme.bodySmall,
            ),
          ),
          SizedBox(
            width: 120,
            child: ElevatedButton.icon(
              onPressed: () => _showCreateContractDialog(context, collab),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Create Contract'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminTheme.primaryTeal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                textStyle: const TextStyle(fontSize: 12),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => _showDeleteDialogNoContract(context, ref, collab),
            tooltip: 'Delete collaborator',
          ),
        ],
      ),
    );
  }

  void _showDeleteDialogNoContract(BuildContext context, WidgetRef ref, CollaboratorWithContracts collab) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Collaborator'),
        content: Text(
          'Are you sure you want to delete collaborator "${collab.profile.fullName ?? collab.profile.email}"?\n\n'
          'This will delete the collaborator profile and associated user account. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await _handleDeleteNoContract(context, ref, collab.profile.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteNoContract(BuildContext context, WidgetRef ref, String collaboratorId) async {
    try {
      final factory = ref.read(apiClientFactoryProvider);
      if (factory == null) throw Exception('API client not initialized');

      await factory.admin.deleteCollaborator(collaboratorId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Collaborator deleted successfully.'),
            backgroundColor: Colors.green,
          ),
        );
        ref.invalidate(allCollaboratorsProvider);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete collaborator: ${formatApiError(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showCreateContractDialog(BuildContext context, CollaboratorWithContracts collab) {
    final regionController = TextEditingController();
    final noteController = TextEditingController();
    final startDateController = TextEditingController();
    final endDateController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    DateTime? startDate;
    DateTime? endDate;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Create Contract for ${collab.profile.fullName ?? collab.profile.email}'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (collab.noContractReason != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (collab.noContractReason!.color).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: collab.noContractReason!.color.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: collab.noContractReason!.color, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Reason: ${collab.noContractReason!.label}',
                              style: TextStyle(color: collab.noContractReason!.color, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  TextFormField(
                    controller: regionController,
                    decoration: const InputDecoration(labelText: 'Region', hintText: 'Enter region (optional)'),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: startDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          startDate = picked;
                          startDateController.text = _fmtForInput(picked);
                        });
                      }
                    },
                    child: AbsorbPointer(
                      child: TextFormField(
                        controller: startDateController,
                        decoration: const InputDecoration(
                          labelText: 'Start Date *',
                          hintText: 'Select start date',
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        validator: (v) => v == null || v.isEmpty ? 'Start date is required' : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: endDate ?? DateTime.now().add(const Duration(days: 365)),
                        firstDate: startDate ?? DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          endDate = picked;
                          endDateController.text = _fmtForInput(picked);
                        });
                      }
                    },
                    child: AbsorbPointer(
                      child: TextFormField(
                        controller: endDateController,
                        decoration: const InputDecoration(
                          labelText: 'End Date *',
                          hintText: 'Select end date',
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'End date is required';
                          if (startDate != null && endDate != null && endDate!.isBefore(startDate!)) {
                            return 'End date must be after start date';
                          }
                          return null;
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: noteController,
                    decoration: const InputDecoration(labelText: 'Note', hintText: 'Enter note (optional)'),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (formKey.currentState!.validate() && startDate != null && endDate != null) {
                        setDialogState(() => isLoading = true);
                        await _handleCreateContract(
                          context,
                          ref,
                          collab.profile.id,
                          regionController.text.trim().isEmpty ? null : regionController.text.trim(),
                          startDate!,
                          endDate!,
                          noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                        );
                        if (context.mounted) Navigator.of(context).pop();
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminTheme.primaryTeal,
                foregroundColor: Colors.white,
              ),
              child: isLoading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleCreateContract(
    BuildContext context,
    WidgetRef ref,
    String collaboratorId,
    String? region,
    DateTime startDate,
    DateTime endDate,
    String? note,
  ) async {
    try {
      final factory = ref.read(apiClientFactoryProvider);
      if (factory == null) throw Exception('API client not initialized');

      await factory.admin.createContract(
        CreateContractDTO(
          collaboratorId: collaboratorId,
          region: region,
          startDate: startDate,
          endDate: endDate,
          note: note,
        ).toJson(),
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contract created successfully. Notification sent to collaborator.'),
            backgroundColor: Colors.green,
          ),
        );
        // Invalidate all collaborator data to refresh the tabs
        ref.invalidate(allCollaboratorsProvider);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create contract: ${formatApiError(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';
  String _fmtForInput(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
