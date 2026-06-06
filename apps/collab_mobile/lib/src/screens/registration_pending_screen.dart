import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:shared_api/shared_api.dart';
import 'package:shared_auth/shared_auth.dart';

class RegistrationPendingScreen extends ConsumerStatefulWidget {
  final String requestId;

  const RegistrationPendingScreen({super.key, required this.requestId});

  @override
  ConsumerState<RegistrationPendingScreen> createState() =>
      _RegistrationPendingScreenState();
}

class _RegistrationPendingScreenState
    extends ConsumerState<RegistrationPendingScreen> {
  bool _isLoading = false;
  String? _status;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final factory = ref.read(apiClientFactoryProvider);
      if (factory == null) {
        setState(() {
          _errorMessage = 'API client not initialized';
          _isLoading = false;
        });
        return;
      }

      final response = await factory.public.getRegistrationRequestStatus(widget.requestId);
      setState(() {
        _status = response['status'] as String?;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _handleCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Registration'),
        content: const Text(
          'Are you sure you want to cancel your registration request? '
          'You can submit a new request later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No, Keep It'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // Sign out and go to login
      ref.read(authStateNotifierProvider.notifier).logout();
      if (mounted) {
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Registration Pending',
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              _buildStatusIcon(),
              const SizedBox(height: 32),
              Text(
                _getStatusTitle(),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                _getStatusMessage(),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[600],
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              _buildStatusDetails(),
              const Spacer(),
              if (_status == 'PENDING') ...[
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _handleCancel,
                  icon: const Icon(Icons.close),
                  label: const Text('Cancel Registration'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextButton(
                onPressed: _isLoading ? null : _checkStatus,
                child: const Text('Refresh Status'),
              ),
              const SizedBox(height: 16),
              if (_status == 'APPROVED')
                PrimaryButton(
                  label: 'Go to Login',
                  onPressed: () {
                    ref.read(authStateNotifierProvider.notifier).logout();
                    context.go('/login');
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    if (_isLoading) {
      return const CircularProgressIndicator();
    }

    IconData icon;
    Color color;

    switch (_status) {
      case 'APPROVED':
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case 'REJECTED':
        icon = Icons.cancel;
        color = Colors.red;
        break;
      case 'PENDING':
      default:
        icon = Icons.hourglass_empty;
        color = Colors.orange;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 64,
        color: color,
      ),
    );
  }

  String _getStatusTitle() {
    switch (_status) {
      case 'APPROVED':
        return 'Registration Approved!';
      case 'REJECTED':
        return 'Registration Not Approved';
      case 'PENDING':
      default:
        return 'Registration Under Review';
    }
  }

  String _getStatusMessage() {
    switch (_status) {
      case 'APPROVED':
        return 'Congratulations! Your registration has been approved.\n'
            'You can now login to VoltGo Collaborator app.';
      case 'REJECTED':
        return 'Unfortunately, your registration was not approved.\n'
            'You may submit a new request if eligible.';
      case 'PENDING':
      default:
        return 'Your registration request has been submitted\n'
            'and is waiting for admin review.\n'
            'You will receive an email once reviewed.';
    }
  }

  Widget _buildStatusDetails() {
    if (_errorMessage != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              'Error checking status',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.red,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _buildDetailRow('Request ID', widget.requestId),
          const SizedBox(height: 8),
          _buildDetailRow('Status', _status ?? 'Loading...'),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }
}
