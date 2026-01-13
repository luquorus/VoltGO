import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:shared_api/shared_api.dart';
import '../models/admin_issue.dart';
import '../providers/issue_providers.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_scaffold.dart';

/// Issue Detail Screen
class IssueDetailScreen extends ConsumerWidget {
  final String id;

  const IssueDetailScreen({
    super.key,
    required this.id,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final issueAsync = ref.watch(issueProvider(id));

    return AdminScaffold(
      title: 'Issue Details',
      body: issueAsync.when(
        data: (issue) => _buildContent(context, theme, ref, issue),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => ErrorState(
          message: error.toString(),
          onRetry: () {
            ref.invalidate(issueProvider(id));
          },
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ThemeData theme, WidgetRef ref, AdminIssue issue) {
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _buildCategoryPill(theme, issue.category),
                                const SizedBox(width: 12),
                                StatusPill(
                                  label: issue.status.displayName,
                                  colorMapper: (label) => _getStatusColor(issue.status),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              issue.stationName ?? 'Unknown Station',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Issue ID: ${issue.id.substring(0, 8)}...',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Actions
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      if (issue.canAcknowledge)
                        ElevatedButton.icon(
                          onPressed: () => _showAcknowledgeDialog(context, ref, issue),
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Acknowledge'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      if (issue.canResolve)
                        ElevatedButton.icon(
                          onPressed: () => _showResolveDialog(context, ref, issue),
                          icon: const Icon(Icons.verified),
                          label: const Text('Resolve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      if (issue.canReject)
                        ElevatedButton.icon(
                          onPressed: () => _showRejectDialog(context, ref, issue),
                          icon: const Icon(Icons.cancel_outlined),
                          label: const Text('Reject'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
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
          _buildBasicInfoSection(context, theme, issue),
          const SizedBox(height: 24),

          // Description
          _buildDescriptionSection(theme, issue),
          const SizedBox(height: 24),

          // Admin Note (if exists)
          if (issue.adminNote != null || issue.decidedAt != null)
            _buildAdminSection(context, theme, issue),
        ],
      ),
    );
  }

  Widget _buildBasicInfoSection(BuildContext context, ThemeData theme, AdminIssue issue) {
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
            _buildInfoRow(context, theme, 'Station ID', issue.stationId, copyable: true),
            _buildInfoRow(context, theme, 'Reporter Email', issue.reporterEmail),
            _buildInfoRow(context, theme, 'Category', issue.category.displayName),
            _buildInfoRow(context, theme, 'Status', issue.status.displayName),
            _buildInfoRow(context, theme, 'Created At', _formatDateTime(issue.createdAt)),
            if (issue.decidedAt != null)
              _buildInfoRow(context, theme, 'Decided At', _formatDateTime(issue.decidedAt!)),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionSection(ThemeData theme, AdminIssue issue) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Description',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AdminTheme.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: Text(
                issue.description,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminSection(BuildContext context, ThemeData theme, AdminIssue issue) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Admin Information',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (issue.adminNote != null)
              _buildInfoRow(context, theme, 'Admin Note', issue.adminNote!),
            if (issue.decidedAt != null)
              _buildInfoRow(
                context,
                theme,
                'Decision Date',
                _formatDateTime(issue.decidedAt!),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryPill(ThemeData theme, IssueCategory category) {
    final color = _getCategoryColor(category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        category.displayName,
        style: theme.textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
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

  Color _getCategoryColor(IssueCategory category) {
    switch (category) {
      case IssueCategory.locationWrong:
        return Colors.red;
      case IssueCategory.priceWrong:
        return Colors.orange;
      case IssueCategory.hoursWrong:
        return Colors.amber;
      case IssueCategory.portsWrong:
        return Colors.purple;
      case IssueCategory.other:
        return Colors.grey;
    }
  }

  Color _getStatusColor(IssueStatus status) {
    switch (status) {
      case IssueStatus.open:
        return Colors.blue;
      case IssueStatus.acknowledged:
        return Colors.orange;
      case IssueStatus.resolved:
        return Colors.green;
      case IssueStatus.rejected:
        return Colors.red;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _showAcknowledgeDialog(BuildContext context, WidgetRef ref, AdminIssue issue) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Acknowledge Issue'),
        content: const Text(
          'Are you sure you want to acknowledge this issue? This marks it as seen and under investigation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await _handleAcknowledge(context, ref, issue);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Acknowledge'),
          ),
        ],
      ),
    );
  }

  void _showResolveDialog(BuildContext screenContext, WidgetRef ref, AdminIssue issue) {
    showDialog(
      context: screenContext,
      builder: (dialogContext) {
        final noteController = TextEditingController();
        final formKey = GlobalKey<FormState>();
        var isConfirmStep = false;
        var savedNote = '';

        return StatefulBuilder(
          builder: (_, setState) {
            if (isConfirmStep) {
              return AlertDialog(
                title: const Text('Confirm Resolution'),
                content: const Text(
                  'Are you sure you want to mark this issue as resolved?',
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        isConfirmStep = false;
                      });
                    },
                    child: const Text('Back'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      _handleResolve(screenContext, ref, issue, savedNote);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Confirm'),
                  ),
                ],
              );
            }

            return AlertDialog(
              title: const Text('Resolve Issue'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Please provide a note explaining how this issue was resolved.',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: noteController,
                      decoration: const InputDecoration(
                        labelText: 'Resolution Note *',
                        hintText: 'Enter resolution details...',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 4,
                      validator: (v) => v?.isEmpty ?? true ? 'Note is required' : null,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;
                    savedNote = noteController.text.trim();
                    setState(() {
                      isConfirmStep = true;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Resolve'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showRejectDialog(BuildContext screenContext, WidgetRef ref, AdminIssue issue) {
    showDialog(
      context: screenContext,
      builder: (dialogContext) {
        final noteController = TextEditingController();
        final formKey = GlobalKey<FormState>();
        var isConfirmStep = false;
        var savedNote = '';

        return StatefulBuilder(
          builder: (_, setState) {
            if (isConfirmStep) {
              return AlertDialog(
                title: const Text('Confirm Rejection'),
                content: const Text(
                  'Are you sure you want to reject this issue? This marks it as invalid.',
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        isConfirmStep = false;
                      });
                    },
                    child: const Text('Back'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      _handleReject(screenContext, ref, issue, savedNote);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Confirm'),
                  ),
                ],
              );
            }

            return AlertDialog(
              title: const Text('Reject Issue'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Please provide a reason for rejecting this issue.',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: noteController,
                      decoration: const InputDecoration(
                        labelText: 'Rejection Reason *',
                        hintText: 'Enter rejection reason...',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 4,
                      validator: (v) => v?.isEmpty ?? true ? 'Reason is required' : null,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;
                    savedNote = noteController.text.trim();
                    setState(() {
                      isConfirmStep = true;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Reject'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handleAcknowledge(BuildContext context, WidgetRef ref, AdminIssue issue) async {
    try {
      final factory = ref.read(apiClientFactoryProvider);
      if (factory == null) throw Exception('API client not initialized');

      await factory.admin.acknowledgeIssue(issue.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Issue acknowledged successfully'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Refresh data (don't pop, just refresh to show new status)
        ref.invalidate(issueProvider(id));
        ref.invalidate(issuesProvider);
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

  Future<void> _handleResolve(BuildContext context, WidgetRef ref, AdminIssue issue, String note) async {
    try {
      final factory = ref.read(apiClientFactoryProvider);
      if (factory == null) throw Exception('API client not initialized');

      await factory.admin.resolveIssue(issue.id, note: note);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Issue resolved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Refresh data
        ref.invalidate(issueProvider(id));
        ref.invalidate(issuesProvider);
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

  Future<void> _handleReject(BuildContext context, WidgetRef ref, AdminIssue issue, String note) async {
    try {
      final factory = ref.read(apiClientFactoryProvider);
      if (factory == null) throw Exception('API client not initialized');

      await factory.admin.rejectIssue(issue.id, note: note);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Issue rejected successfully'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Refresh data
        ref.invalidate(issueProvider(id));
        ref.invalidate(issuesProvider);
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

