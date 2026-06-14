import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:shared_api/shared_api.dart';
import '../models/collaborator_profile.dart';
import '../models/pagination_response.dart';
import '../providers/collaborator_providers.dart';
import '../theme/admin_theme.dart';
import '../utils/responsive_utils.dart';
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
        padding: responsivePadding(context),
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
                    title: 'Could not load list',
                    message: formatApiError(error),
                    code: extractErrorCode(error),
                    traceId: extractTraceId(error),
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
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Delete collaborator',
              onPressed: () => _showDeleteDialog(context, ref, collaborator),
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
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final fullNameController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create Collaborator'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email *',
                      hintText: 'e.g. collab@example.com',
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Email is required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Password *',
                      hintText: 'Min 8 characters',
                    ),
                    obscureText: true,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Password is required';
                      if (v.length < 8) return 'Min 8 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: fullNameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name *',
                      hintText: 'e.g. John Doe',
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Full name is required' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (formKey.currentState!.validate()) {
                        setDialogState(() => isLoading = true);
                        await _handleCreateWithAccount(
                          context,
                          ref,
                          emailController.text.trim(),
                          passwordController.text,
                          fullNameController.text.trim(),
                        );
                        if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminTheme.primaryTeal,
                foregroundColor: Colors.white,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleCreateWithAccount(
    BuildContext context,
    WidgetRef ref,
    String email,
    String password,
    String fullName,
  ) async {
    try {
      final factory = ref.read(apiClientFactoryProvider);
      if (factory == null) throw Exception('API client not initialized');

      await factory.admin.createCollaboratorWithAccount(
        email: email,
        password: password,
        fullName: fullName,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Collaborator account created successfully'),
            backgroundColor: Colors.green,
          ),
        );
        ref.invalidate(collaboratorsProvider);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${formatApiError(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, CollaboratorProfile collaborator) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Collaborator'),
        content: Text(
          'Are you sure you want to delete "${collaborator.fullName ?? collaborator.email}"?\n\nThis will permanently remove the collaborator account and their profile. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await _handleDelete(context, ref, collaborator);
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

  Future<void> _handleDelete(
    BuildContext context,
    WidgetRef ref,
    CollaboratorProfile collaborator,
  ) async {
    try {
      final factory = ref.read(apiClientFactoryProvider);
      if (factory == null) throw Exception('API client not initialized');

      await factory.admin.deleteCollaborator(collaborator.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Collaborator deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        ref.invalidate(collaboratorsProvider);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${formatApiError(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

