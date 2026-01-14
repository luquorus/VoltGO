import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:shared_api/shared_api.dart';
import '../models/collaborator_profile.dart';
import '../models/contract.dart';
import '../providers/collaborator_providers.dart';
import '../providers/contract_providers.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_scaffold.dart';

/// Collaborator Detail Screen
class CollaboratorDetailScreen extends ConsumerStatefulWidget {
  final String id;

  const CollaboratorDetailScreen({
    super.key,
    required this.id,
  });

  @override
  ConsumerState<CollaboratorDetailScreen> createState() => _CollaboratorDetailScreenState();
}

class _CollaboratorDetailScreenState extends ConsumerState<CollaboratorDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final collaboratorAsync = ref.watch(collaboratorProvider(widget.id));

    return AdminScaffold(
      title: 'Collaborator Details',
      body: collaboratorAsync.when(
        data: (collaborator) => _buildContent(context, theme, collaborator),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading collaborator',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  ref.invalidate(collaboratorProvider(widget.id));
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ThemeData theme, CollaboratorProfile collaborator) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AdminTheme.primaryTeal,
                              AdminTheme.primaryTealLight,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              collaborator.fullName ?? 'N/A',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'ID: ${collaborator.id.substring(0, 8)}...',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (collaborator.hasActiveContract == true)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.green,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Active Contract',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Basic Information
          _buildBasicInfoSection(context, theme, collaborator),
          const SizedBox(height: 24),

          // Location Information
          if (collaborator.location != null) ...[
            _buildLocationSection(context, theme, collaborator.location!),
            const SizedBox(height: 24),
          ],

          // Contracts Section
          _buildContractsSection(context, theme, collaborator),
        ],
      ),
    );
  }

  Widget _buildBasicInfoSection(
    BuildContext context,
    ThemeData theme,
    CollaboratorProfile collaborator,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Basic Information',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              context,
              theme,
              'User Account ID',
              collaborator.userAccountId,
              copyable: true,
            ),
            _buildInfoRow(
              context,
              theme,
              'Email',
              collaborator.email ?? 'N/A',
            ),
            _buildInfoRow(
              context,
              theme,
              'Full Name',
              collaborator.fullName ?? 'N/A',
            ),
            _buildInfoRow(
              context,
              theme,
              'Phone',
              collaborator.phone ?? 'N/A',
            ),
            _buildInfoRow(
              context,
              theme,
              'Contract Status',
              collaborator.hasActiveContract == true
                  ? 'Active'
                  : collaborator.hasActiveContract == false
                      ? 'No Active Contract'
                      : 'Unknown',
            ),
            if (collaborator.createdAt != null)
              _buildInfoRow(
                context,
                theme,
                'Created At',
                _formatDateTime(collaborator.createdAt!),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSection(
    BuildContext context,
    ThemeData theme,
    CollaboratorLocation location,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Location Information',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (location.lat != null && location.lng != null)
              _buildInfoRow(
                context,
                theme,
                'Coordinates',
                '${location.lat!.toStringAsFixed(6)}, ${location.lng!.toStringAsFixed(6)}',
                copyable: true,
              ),
            if (location.updatedAt != null)
              _buildInfoRow(
                context,
                theme,
                'Last Updated',
                _formatDateTime(location.updatedAt!),
              ),
            if (location.source != null)
              _buildInfoRow(
                context,
                theme,
                'Source',
                location.source!,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    ThemeData theme,
    String label,
    String value, {
    bool copyable = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                if (copyable) ...[
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Copy to clipboard',
                    child: IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: value));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$label copied to clipboard'),
                            duration: const Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      iconSize: 18,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContractsSection(
    BuildContext context,
    ThemeData theme,
    CollaboratorProfile collaborator,
  ) {
    final contractsAsync = ref.watch(contractsByCollaboratorProvider(collaborator.id));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Contracts',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showCreateContractDialog(context, ref, collaborator),
                  icon: const Icon(Icons.add),
                  label: const Text('Create Contract'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminTheme.primaryTeal,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            contractsAsync.when(
              data: (contracts) {
                if (contracts.isEmpty) {
                  return EmptyState(
                    icon: Icons.description_outlined,
                    message: 'No contracts found',
                    action: OutlinedButton.icon(
                      onPressed: () => _showCreateContractDialog(context, ref, collaborator),
                      icon: const Icon(Icons.add),
                      label: const Text('Create First Contract'),
                    ),
                  );
                }
                return _buildContractsTable(context, theme, contracts);
              },
              loading: () => const Center(child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(),
              )),
              error: (error, stack) => ErrorState(
                message: error.toString(),
                onRetry: () {
                  ref.invalidate(contractsByCollaboratorProvider(collaborator.id));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContractsTable(
    BuildContext context,
    ThemeData theme,
    List<Contract> contracts,
  ) {
    return Column(
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  'Period',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Region',
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
                  'Created',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 80),
            ],
          ),
        ),
        // Table Rows
        ...contracts.map((contract) => _buildContractRow(context, theme, contract)),
      ],
    );
  }

  Widget _buildContractRow(
    BuildContext context,
    ThemeData theme,
    Contract contract,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.1),
          ),
        ),
      ),
      child: InkWell(
        onTap: () => context.go('/contracts/${contract.id}'),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contract.startDate != null && contract.endDate != null
                        ? '${_formatDate(contract.startDate!)} - ${_formatDate(contract.endDate!)}'
                        : 'N/A',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                contract.region ?? 'N/A',
                style: theme.textTheme.bodyMedium,
              ),
            ),
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: contract.status == ContractStatus.active
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: contract.status == ContractStatus.active
                        ? Colors.green
                        : Colors.red,
                    width: 1,
                  ),
                ),
                child: Text(
                  contract.status.displayName,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: contract.status == ContractStatus.active
                        ? Colors.green
                        : Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                contract.createdAt != null
                    ? _formatDate(contract.createdAt!)
                    : 'N/A',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ),
            SizedBox(
              width: 80,
              child: IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => context.go('/contracts/${contract.id}'),
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateContractDialog(
    BuildContext context,
    WidgetRef ref,
    CollaboratorProfile collaborator,
  ) {
    final regionController = TextEditingController();
    final noteController = TextEditingController();
    final startDateController = TextEditingController();
    final endDateController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    DateTime? startDate;
    DateTime? endDate;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create Contract'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: regionController,
                    decoration: const InputDecoration(
                      labelText: 'Region',
                      hintText: 'Enter region (optional)',
                    ),
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
                        setState(() {
                          startDate = picked;
                          startDateController.text = _formatDateForInput(picked);
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
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Start date is required';
                          }
                          return null;
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: endDate ?? DateTime.now(),
                        firstDate: startDate ?? DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() {
                          endDate = picked;
                          endDateController.text = _formatDateForInput(picked);
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
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'End date is required';
                          }
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
                    decoration: const InputDecoration(
                      labelText: 'Note',
                      hintText: 'Enter note (optional)',
                    ),
                    maxLines: 3,
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
                if (formKey.currentState!.validate() && startDate != null && endDate != null) {
                  await _handleCreateContract(
                    context,
                    ref,
                    collaborator.id,
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
              child: const Text('Create'),
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
            content: Text('Contract created successfully'),
            backgroundColor: Colors.green,
          ),
        );
        ref.invalidate(contractsByCollaboratorProvider(collaboratorId));
        ref.invalidate(collaboratorProvider(widget.id));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating contract: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateForInput(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

