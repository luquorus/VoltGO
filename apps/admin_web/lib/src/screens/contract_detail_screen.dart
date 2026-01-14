import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:shared_api/shared_api.dart';
import '../models/contract.dart';
import '../providers/contract_providers.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_scaffold.dart';

/// Contract Detail Screen
class ContractDetailScreen extends ConsumerStatefulWidget {
  final String id;

  const ContractDetailScreen({
    super.key,
    required this.id,
  });

  @override
  ConsumerState<ContractDetailScreen> createState() => _ContractDetailScreenState();
}

class _ContractDetailScreenState extends ConsumerState<ContractDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final contractAsync = ref.watch(contractProvider(widget.id));

    return AdminScaffold(
      title: 'Contract Details',
      body: contractAsync.when(
        data: (contract) => _buildContent(context, theme, contract),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => ErrorState(
          message: error.toString(),
          onRetry: () {
            ref.invalidate(contractProvider(widget.id));
          },
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ThemeData theme, Contract contract) {
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
                          Icons.description,
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
                              'Contract',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'ID: ${contract.id.substring(0, 8)}...',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      StatusPill(
                        label: contract.status.displayName,
                        colorMapper: (label) {
                          switch (contract.status) {
                            case ContractStatus.active:
                              return Colors.green;
                            case ContractStatus.terminated:
                              return Colors.red;
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Actions
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      if (contract.status == ContractStatus.active) ...[
                        ElevatedButton.icon(
                          onPressed: () => _showEditDialog(context, ref, contract),
                          icon: const Icon(Icons.edit),
                          label: const Text('Edit'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AdminTheme.primaryTeal,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _showTerminateDialog(context, ref, contract),
                          icon: const Icon(Icons.close),
                          label: const Text('Terminate'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                      OutlinedButton.icon(
                        onPressed: () => context.go('/collaborators/${contract.collaboratorId}'),
                        icon: const Icon(Icons.person),
                        label: const Text('View Collaborator'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Contract Information
          _buildContractInfoSection(context, theme, contract),
          const SizedBox(height: 24),

          // Dates
          _buildDatesSection(context, theme, contract),
        ],
      ),
    );
  }

  Widget _buildContractInfoSection(BuildContext context, ThemeData theme, Contract contract) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Contract Information',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              context,
              theme,
              'Collaborator ID',
              contract.collaboratorId,
              copyable: true,
            ),
            if (contract.collaboratorName != null)
              _buildInfoRow(
                context,
                theme,
                'Collaborator Name',
                contract.collaboratorName!,
              ),
            _buildInfoRow(
              context,
              theme,
              'Region',
              contract.region ?? 'N/A',
            ),
            _buildInfoRow(
              context,
              theme,
              'Status',
              contract.status.displayName,
            ),
            if (contract.isEffectivelyActive != null)
              _buildInfoRow(
                context,
                theme,
                'Effectively Active',
                contract.isEffectivelyActive! ? 'Yes' : 'No',
              ),
            if (contract.note != null && contract.note!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Note',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AdminTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.colorScheme.outline.withOpacity(0.2),
                        ),
                      ),
                      child: Text(
                        contract.note!,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatesSection(BuildContext context, ThemeData theme, Contract contract) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dates',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (contract.startDate != null)
              _buildInfoRow(
                context,
                theme,
                'Start Date',
                _formatDate(contract.startDate!),
              ),
            if (contract.endDate != null)
              _buildInfoRow(
                context,
                theme,
                'End Date',
                _formatDate(contract.endDate!),
              ),
            if (contract.createdAt != null)
              _buildInfoRow(
                context,
                theme,
                'Created At',
                _formatDateTime(contract.createdAt!),
              ),
            if (contract.terminatedAt != null)
              _buildInfoRow(
                context,
                theme,
                'Terminated At',
                _formatDateTime(contract.terminatedAt!),
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _showEditDialog(BuildContext context, WidgetRef ref, Contract contract) async {
    final regionController = TextEditingController(text: contract.region);
    final noteController = TextEditingController(text: contract.note);
    final startDateController = TextEditingController(
      text: contract.startDate != null ? _formatDateForInput(contract.startDate!) : null,
    );
    final endDateController = TextEditingController(
      text: contract.endDate != null ? _formatDateForInput(contract.endDate!) : null,
    );
    final formKey = GlobalKey<FormState>();

    DateTime? startDate = contract.startDate;
    DateTime? endDate = contract.endDate;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Contract'),
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
                  await _handleUpdate(
                    context,
                    ref,
                    contract.id,
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
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTerminateDialog(BuildContext context, WidgetRef ref, Contract contract) async {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terminate Contract'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to terminate this contract?',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason (optional)',
                  hintText: 'Enter termination reason',
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
            ElevatedButton(
              onPressed: () async {
                await _handleTerminate(
                  context,
                  ref,
                  contract.id,
                  contract.collaboratorId,
                  reasonController.text.trim().isEmpty ? null : reasonController.text.trim(),
                );
                if (context.mounted) Navigator.of(context).pop();
              },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Terminate'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleUpdate(
    BuildContext context,
    WidgetRef ref,
    String contractId,
    String? region,
    DateTime startDate,
    DateTime endDate,
    String? note,
  ) async {
    try {
      final factory = ref.read(apiClientFactoryProvider);
      if (factory == null) throw Exception('API client not initialized');

      await factory.admin.updateContract(
        contractId,
        UpdateContractDTO(
          region: region,
          startDate: startDate,
          endDate: endDate,
          note: note,
        ).toJson(),
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contract updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        ref.invalidate(contractProvider(contractId));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating contract: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleTerminate(
    BuildContext context,
    WidgetRef ref,
    String contractId,
    String collaboratorId,
    String? reason,
  ) async {
    try {
      final factory = ref.read(apiClientFactoryProvider);
      if (factory == null) throw Exception('API client not initialized');

      await factory.admin.terminateContract(contractId, reason: reason);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contract terminated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        ref.invalidate(contractProvider(contractId));
        ref.invalidate(contractsByCollaboratorProvider(collaboratorId));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error terminating contract: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDateForInput(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

