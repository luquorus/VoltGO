import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:shared_api/shared_api.dart' hide RegistrationRequest, RegistrationRequestStatus;
import '../models/registration_request.dart';
import '../providers/registration_request_providers.dart';
import '../providers/contract_providers.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_scaffold.dart';

class RegistrationRequestDetailScreen extends ConsumerStatefulWidget {
  final String id;

  const RegistrationRequestDetailScreen({super.key, required this.id});

  @override
  ConsumerState<RegistrationRequestDetailScreen> createState() =>
      _RegistrationRequestDetailScreenState();
}

class _RegistrationRequestDetailScreenState
    extends ConsumerState<RegistrationRequestDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final requestAsync = ref.watch(registrationRequestProvider(widget.id));

    return AdminScaffold(
      title: 'Registration Request Details',
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: requestAsync.when(
          data: (request) => _buildContent(theme, request),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text('Failed to load request', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => ref.invalidate(registrationRequestProvider(widget.id)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme, RegistrationRequest request) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button and title
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              ),
              const SizedBox(width: 8),
              Text(
                'Registration Request Details',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AdminTheme.primaryTealDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Status and Actions Card
          _buildStatusCard(theme, request),
          const SizedBox(height: 24),

          // Personal Information Card
          _buildPersonalInfoCard(theme, request),
          const SizedBox(height: 24),

          // Bank Information Card
          _buildBankInfoCard(theme, request),
          const SizedBox(height: 24),

          // Timeline Card
          _buildTimelineCard(theme, request),
        ],
      ),
    );
  }

  Widget _buildStatusCard(ThemeData theme, RegistrationRequest request) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Status',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: request.status.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: request.status.color.withOpacity(0.3)),
                  ),
                  child: Text(
                    request.status.displayName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: request.status.color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (request.status == RegistrationRequestStatus.pending) ...[
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showApproveDialog(context, request),
                      icon: const Icon(Icons.check),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showRejectDialog(context, request),
                      icon: const Icon(Icons.close),
                      label: const Text('Reject'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (request.status == RegistrationRequestStatus.rejected &&
                request.rejectionReason != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rejection Reason',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.red[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      request.rejectionReason!,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalInfoCard(ThemeData theme, RegistrationRequest request) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Personal Information',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildInfoRow(theme, 'Full Name', request.fullName),
            _buildInfoRow(theme, 'Email', request.email),
            _buildInfoRow(theme, 'Phone', request.phone ?? 'N/A'),
            _buildInfoRow(theme, 'Date of Birth', request.dateOfBirth ?? 'N/A'),
            _buildInfoRow(theme, 'Age', request.age != null ? '${request.age} years old' : 'N/A'),
            _buildInfoRow(theme, 'Address', request.address ?? 'N/A'),
            _buildInfoRow(theme, 'ID Card Number', request.idCardNumber ?? 'N/A'),
            if (request.referralCode != null && request.referralCode!.isNotEmpty)
              _buildInfoRow(theme, 'Referral Code', request.referralCode!),
          ],
        ),
      ),
    );
  }

  Widget _buildBankInfoCard(ThemeData theme, RegistrationRequest request) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bank Information',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildInfoRow(theme, 'Bank Name', request.bankName ?? 'N/A'),
            _buildInfoRow(theme, 'Bank Account Number', request.bankAccountNumber ?? 'N/A'),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineCard(ThemeData theme, RegistrationRequest request) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Timeline',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildTimelineItem(
              theme,
              Icons.calendar_today,
              'Submitted',
              _formatDateTime(request.createdAt),
              Colors.blue,
            ),
            if (request.reviewedAt != null)
              _buildTimelineItem(
                theme,
                request.status == RegistrationRequestStatus.approved
                    ? Icons.check_circle
                    : Icons.cancel,
                request.status == RegistrationRequestStatus.approved
                    ? 'Approved'
                    : 'Rejected',
                _formatDateTime(request.reviewedAt!),
                request.status.color,
              ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AdminTheme.surfaceLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.refresh, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    'Submission Count: ${request.submissionCount}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    request.canResubmit ? Icons.check_circle : Icons.cancel,
                    size: 16,
                    color: request.canResubmit ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    request.canResubmit ? 'Can resubmit' : 'Resubmission limit reached',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: request.canResubmit ? Colors.green : Colors.orange,
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

  Widget _buildInfoRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(
    ThemeData theme,
    IconData icon,
    String title,
    String time,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                time,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showApproveDialog(BuildContext context, RegistrationRequest request) {
    final noteController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? selectedRegion;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Registration Request'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Approve registration for ${request.fullName}?',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Region *',
                  hintText: 'Select region',
                ),
                value: selectedRegion,
                items: const [
                  DropdownMenuItem(value: 'Ha Noi', child: Text('Ha Noi')),
                  DropdownMenuItem(value: 'Ho Chi Minh City', child: Text('Ho Chi Minh City')),
                ],
                onChanged: (value) => selectedRegion = value,
                validator: (v) => v == null ? 'Region is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  hintText: 'Add any notes about this approval',
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context);
                await _handleApprove(
                  request.id,
                  selectedRegion!,
                  noteController.text.isEmpty ? null : noteController.text,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(BuildContext context, RegistrationRequest request) {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Registration Request'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Reject registration for ${request.fullName}?',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason *',
                  hintText: 'Explain why this request is rejected',
                ),
                maxLines: 3,
                validator: (v) => v?.isEmpty ?? true ? 'Reason is required' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context);
                await _handleReject(request.id, reasonController.text);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleApprove(String id, String region, String? note) async {
    try {
      await ref.read(approveRegistrationProvider.notifier).approve(
            id,
            region: region,
            note: note,
          );
      if (mounted) {
        ref.invalidate(allCollaboratorsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration request approved successfully. Collaborator moved to No Contract tab.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleReject(String id, String reason) async {
    try {
      await ref.read(rejectRegistrationProvider.notifier).reject(
            id,
            reason: reason,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration request rejected'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
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
