import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:shared_api/shared_api.dart';
import 'package:shared_auth/shared_auth.dart';

class RegistrationFormScreen extends ConsumerStatefulWidget {
  const RegistrationFormScreen({super.key});

  @override
  ConsumerState<RegistrationFormScreen> createState() =>
      _RegistrationFormScreenState();
}

class _RegistrationFormScreenState extends ConsumerState<RegistrationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _idCardController = TextEditingController();
  final _bankAccountController = TextEditingController();
  final _bankNameController = TextEditingController();

  DateTime? _dateOfBirth;
  bool _isLoading = false;
  bool _contractAgreed = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _idCardController.dispose();
    _bankAccountController.dispose();
    _bankNameController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_contractAgreed) {
      if (mounted) {
        AppToast.showError(context, 'You must agree to the contract terms');
      }
      return;
    }

    if (_dateOfBirth == null) {
      if (mounted) {
        AppToast.showError(context, 'Please select your date of birth');
      }
      return;
    }

    // Validate age (must be 18+)
    final age = _calculateAge(_dateOfBirth!);
    if (age < 18) {
      if (mounted) {
        AppToast.showError(context, 'You must be at least 18 years old to register');
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final factory = ref.read(apiClientFactoryProvider);
      if (factory == null) throw Exception('API client not initialized');

      final response = await factory.public.submitRegistrationRequest(
        fullName: _fullNameController.text.trim(),
        phone: _phoneController.text.trim(),
        dateOfBirth: _formatDate(_dateOfBirth!),
        address: _addressController.text.trim(),
        idCardNumber: _idCardController.text.trim(),
        bankAccountNumber: _bankAccountController.text.trim(),
        bankName: _bankNameController.text.trim(),
      );

      if (mounted) {
        final requestId = response['id'] as String?;
        if (requestId != null) {
          // Mark registration as submitted so router allows task access after approval
          await ref.read(authStateNotifierProvider.notifier).markRegistrationSubmitted();
          context.go('/registration-pending', extra: requestId);
        } else {
          AppToast.showSuccess(context, 'Registration request submitted successfully');
          context.go('/charging-station');
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, 'Failed to submit: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _selectDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 25),
      firstDate: DateTime(1950),
      lastDate: DateTime(now.year - 18),
    );
    if (picked != null) {
      setState(() => _dateOfBirth = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Complete Registration',
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                Text(
                  'Please fill in your information to complete the registration',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Full Name
                AppTextField(
                  label: 'Full Name *',
                  controller: _fullNameController,
                  enabled: !_isLoading,
                  validator: (v) => v?.isEmpty ?? true ? 'Full name is required' : null,
                ),
                const SizedBox(height: 16),

                // Phone
                AppTextField(
                  label: 'Phone Number *',
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  enabled: !_isLoading,
                  validator: (v) {
                    if (v?.isEmpty ?? true) return 'Phone is required';
                    if (!RegExp(r'^\d{9,11}$').hasMatch(v!)) {
                      return 'Invalid phone format';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Date of Birth
                InkWell(
                  onTap: _isLoading ? null : _selectDateOfBirth,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Date of Birth *',
                      errorText: _dateOfBirth == null ? null : null,
                      suffixIcon: const Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      _dateOfBirth != null
                          ? _formatDate(_dateOfBirth!)
                          : 'Select date (must be 18+)',
                      style: TextStyle(
                        color: _dateOfBirth != null
                            ? Theme.of(context).textTheme.bodyLarge?.color
                            : Colors.grey,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Address
                AppTextField(
                  label: 'Address *',
                  controller: _addressController,
                  maxLines: 2,
                  enabled: !_isLoading,
                  validator: (v) => v?.isEmpty ?? true ? 'Address is required' : null,
                ),
                const SizedBox(height: 16),

                // ID Card Number
                AppTextField(
                  label: 'ID Card Number *',
                  controller: _idCardController,
                  keyboardType: TextInputType.number,
                  enabled: !_isLoading,
                  validator: (v) {
                    if (v?.isEmpty ?? true) return 'ID card number is required';
                    if (!RegExp(r'^\d{9,12}$').hasMatch(v!)) {
                      return 'ID card must be 9-12 digits';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Bank Name
                AppTextField(
                  label: 'Bank Name *',
                  controller: _bankNameController,
                  enabled: !_isLoading,
                  validator: (v) => v?.isEmpty ?? true ? 'Bank name is required' : null,
                ),
                const SizedBox(height: 16),

                // Bank Account Number
                AppTextField(
                  label: 'Bank Account Number *',
                  controller: _bankAccountController,
                  keyboardType: TextInputType.number,
                  enabled: !_isLoading,
                  validator: (v) {
                    if (v?.isEmpty ?? true) return 'Bank account is required';
                    if (!RegExp(r'^\d{6,20}$').hasMatch(v!)) {
                      return 'Invalid account number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                const SizedBox(height: 24),

                // Contract Agreement
                CheckboxListTile(
                  value: _contractAgreed,
                  onChanged: _isLoading
                      ? null
                      : (value) {
                          setState(() => _contractAgreed = value ?? false);
                        },
                  title: Text(
                    'I agree to the VoltGo Collaborator Contract Terms',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 8),

                // View Contract Button
                TextButton(
                  onPressed: _isLoading ? null : () => _showContractDialog(context),
                  child: const Text('View Contract Terms'),
                ),
                const SizedBox(height: 24),

                // Submit Button
                PrimaryButton(
                  label: 'Submit Registration',
                  onPressed: _isLoading ? null : _handleSubmit,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: 16),

                // Cancel Button
                SecondaryButton(
                  label: 'Cancel',
                  onPressed: _isLoading
                      ? null
                      : () {
                          // Sign out and go back
                          ref.read(authStateNotifierProvider.notifier).logout();
                          context.go('/login');
                        },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showContractDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('VoltGo Collaborator Contract'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'COLLABORATOR SERVICE AGREEMENT',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildContractSection(
                '1. SCOPE OF SERVICES',
                'As a VoltGo Collaborator, you agree to:\n'
                    '- Verify charging station information as assigned\n'
                    '- Provide accurate and timely reports\n'
                    '- Maintain professional conduct\n'
                    '- Protect company confidential information',
              ),
              _buildContractSection(
                '2. COMPENSATION',
                'You will receive compensation as per the task rates '
                    'established by VoltGo. Payment will be processed '
                    'according to the company\'s payment schedule.',
              ),
              _buildContractSection(
                '3. TERM AND TERMINATION',
                'This contract is effective for one (1) year from the '
                    'approval date, unless terminated earlier by either party '
                    'with 30 days written notice.',
              ),
              _buildContractSection(
                '4. CONFIDENTIALITY',
                'You agree to keep all information about charging stations, '
                    'users, and company operations confidential.',
              ),
              _buildContractSection(
                '5. INDEPENDENT CONTRACTOR',
                'You are an independent contractor, not an employee of VoltGo. '
                    'You are responsible for your own taxes and insurance.',
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildContractSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(content),
        ],
      ),
    );
  }
}
