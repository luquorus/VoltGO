import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:shared_api/shared_api.dart';
import '../models/collaborator_profile.dart';
import '../models/pagination_response.dart';
import '../providers/collaborator_providers.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_scaffold.dart';

/// Collaborators List Screen
class CollaboratorsListScreen extends ConsumerStatefulWidget {
  const CollaboratorsListScreen({super.key});

  @override
  ConsumerState<CollaboratorsListScreen> createState() =>
      _CollaboratorsListScreenState();
}

class _CollaboratorsListScreenState extends ConsumerState<CollaboratorsListScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pagination = ref.watch(collaboratorPaginationProvider);
    final collaboratorsAsync = ref.watch(collaboratorsProvider);

    return AdminScaffold(
      title: 'Collaborators',
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Create Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Collaborator Management',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AdminTheme.primaryTealDark,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showCreateDialog(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('Create Collaborator'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminTheme.primaryTeal,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Collaborators Table
            Expanded(
              child: Card(
                margin: EdgeInsets.zero,
                child: collaboratorsAsync.when(
                  data: (paginationResponse) => _buildCollaboratorsTable(
                    theme,
                    paginationResponse,
                    pagination,
                  ),
                  loading: () => const LoadingState(message: 'Loading collaborators...'),
                  error: (error, stack) => ErrorState(
                    message: error.toString(),
                    onRetry: () {
                      ref.invalidate(collaboratorsProvider);
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

  Widget _buildCollaboratorsTable(
    ThemeData theme,
    PaginationResponse<CollaboratorProfile> paginationResponse,
    CollaboratorPagination pagination,
  ) {
    final collaborators = paginationResponse.content;

    if (collaborators.isEmpty && paginationResponse.page == 0) {
      return EmptyState(
        icon: Icons.people_outline,
        message: 'No collaborators found',
        action: OutlinedButton.icon(
          onPressed: () => _showCreateDialog(context, ref),
          icon: const Icon(Icons.add),
          label: const Text('Create First Collaborator'),
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
                  'Full Name',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
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
                  'Phone',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Contract Status',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Created At',
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
            itemCount: collaborators.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: theme.colorScheme.outline.withOpacity(0.1),
            ),
            itemBuilder: (context, index) {
              final collaborator = collaborators[index];
              return _buildCollaboratorRow(theme, collaborator);
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
                'Showing ${collaborators.length} of ${paginationResponse.totalElements} collaborators',
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
                            ref.read(collaboratorPaginationProvider.notifier).state =
                                pagination.copyWith(page: pagination.page - 1);
                            ref.invalidate(collaboratorsProvider);
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
                            ref.read(collaboratorPaginationProvider.notifier).state =
                                pagination.copyWith(page: pagination.page + 1);
                            ref.invalidate(collaboratorsProvider);
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

  Widget _buildCollaboratorRow(ThemeData theme, CollaboratorProfile collaborator) {
    return InkWell(
      onTap: () {
        context.push('/collaborators/${collaborator.id}');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                collaborator.fullName ?? 'N/A',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                collaborator.email ?? 'N/A',
                style: theme.textTheme.bodyMedium,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                collaborator.phone ?? 'N/A',
                style: theme.textTheme.bodyMedium,
              ),
            ),
            Expanded(
              flex: 2,
              child: StatusPill(
                label: collaborator.hasActiveContract == true ? 'Active' : 'No Contract',
                colorMapper: (label) {
                  return collaborator.hasActiveContract == true
                      ? Colors.green
                      : Colors.grey;
                },
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                collaborator.createdAt != null
                    ? _formatDateTime(collaborator.createdAt!)
                    : 'N/A',
                style: theme.textTheme.bodySmall,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () {
                context.push('/collaborators/${collaborator.id}');
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final userAccountIdController = TextEditingController();
    final fullNameController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Collaborator Profile'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: userAccountIdController,
                  decoration: const InputDecoration(
                    labelText: 'User Account ID *',
                    hintText: 'Enter user account UUID with COLLABORATOR role',
                    helperText: 'The user account must have COLLABORATOR role',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'User Account ID is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: fullNameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    hintText: 'Enter full name (optional)',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                    hintText: 'Enter phone number (optional)',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                await _handleCreate(
                  context,
                  ref,
                  userAccountIdController.text.trim(),
                  fullNameController.text.trim().isEmpty
                      ? null
                      : fullNameController.text.trim(),
                  phoneController.text.trim().isEmpty
                      ? null
                      : phoneController.text.trim(),
                );
                if (context.mounted) Navigator.of(context).pop();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminTheme.primaryTeal,
              foregroundColor: Colors.white,
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCreate(
    BuildContext context,
    WidgetRef ref,
    String userAccountId,
    String? fullName,
    String? phone,
  ) async {
    try {
      final factory = ref.read(apiClientFactoryProvider);
      if (factory == null) throw Exception('API client not initialized');

      await factory.admin.createCollaborator(
        userAccountId: userAccountId,
        fullName: fullName,
        phone: phone,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Collaborator profile created successfully'),
            backgroundColor: Colors.green,
          ),
        );
        ref.invalidate(collaboratorsProvider);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

