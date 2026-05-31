import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_ui/shared_ui.dart';
import '../widgets/main_scaffold.dart';
import '../providers/profile_providers.dart';

/// Edit Profile Screen
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isChangingPassword = false;

  @override
  void initState() {
    super.initState();
    // Load profile when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfile();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    await ref.read(profileProvider.notifier).loadProfile();
    final profile = ref.read(profileProvider).profile;
    if (profile != null) {
      _nameController.text = profile['name'] as String? ?? '';
      _phoneController.text = profile['phone'] as String? ?? '';
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim().isEmpty 
        ? null 
        : _phoneController.text.trim();

    final success = await ref.read(profileProvider.notifier).updateProfile(
      name: name,
      phone: phone,
    );

    if (success && mounted) {
      AppToast.showSuccess(context, 'Profile updated successfully.');
      context.pop();
    } else if (mounted) {
      final error = ref.read(profileProvider).error;
      AppToast.showError(
          context, formatApiError(error, fallback: 'Failed to update profile.'));
    }
  }

  Future<void> _handleChangePassword() async {
    if (!_validatePasswordForm()) {
      return;
    }

    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;

    final success = await ref.read(profileProvider.notifier).changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );

    if (success && mounted) {
      AppToast.showSuccess(context, 'Password changed successfully.');
      setState(() {
        _isChangingPassword = false;
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      });
    } else if (mounted) {
      final error = ref.read(profileProvider).error;
      AppToast.showError(context,
          formatApiError(error, fallback: 'Failed to change password.'));
    }
  }

  bool _validatePasswordForm() {
    if (_currentPasswordController.text.isEmpty) {
      AppToast.showError(context, 'Please enter your current password.');
      return false;
    }
    if (_newPasswordController.text.isEmpty) {
      AppToast.showError(context, 'Please enter a new password.');
      return false;
    }
    if (_newPasswordController.text.length < 8) {
      AppToast.showError(
          context, 'New password must be at least 8 characters.');
      return false;
    }
    if (_newPasswordController.text != _confirmPasswordController.text) {
      AppToast.showError(context, 'Password confirmation does not match.');
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileProvider);
    final theme = Theme.of(context);
    final isLoading = profileState.isLoading;

    return MainScaffold(
      title: 'Edit profile',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Profile Information Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          FaIcon(
                            FontAwesomeIcons.user,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Profile information',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Name field
                      TextFormField(
                        controller: _nameController,
                        style: theme.textTheme.bodyLarge,
                        decoration: InputDecoration(
                          labelText: 'Full name *',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(left: 16, right: 12),
                            child: Align(
                              widthFactor: 1.0,
                              child: FaIcon(
                                FontAwesomeIcons.user,
                                color: Color(0xFF6B8E7F),
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                        enabled: !isLoading,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your full name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Phone field
                      TextFormField(
                        controller: _phoneController,
                        style: theme.textTheme.bodyLarge,
                        decoration: InputDecoration(
                          labelText: 'Phone number',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(left: 16, right: 12),
                            child: Align(
                              widthFactor: 1.0,
                              child: FaIcon(
                                FontAwesomeIcons.phone,
                                color: Color(0xFF6B8E7F),
                                size: 20,
                              ),
                            ),
                          ),
                          hintText: 'Optional',
                        ),
                        enabled: !isLoading,
                        keyboardType: TextInputType.phone,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Change Password Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          FaIcon(
                            FontAwesomeIcons.lock,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Change password',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      if (!_isChangingPassword) ...[
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _isChangingPassword = true;
                            });
                          },
                          icon: const FaIcon(FontAwesomeIcons.key, size: 16),
                          label: const Text('Change password'),
                        ),
                      ] else ...[
                        TextFormField(
                          controller: _currentPasswordController,
                          style: theme.textTheme.bodyLarge,
                          decoration: InputDecoration(
                            labelText: 'Current password *',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureCurrentPassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureCurrentPassword =
                                      !_obscureCurrentPassword;
                                });
                              },
                            ),
                          ),
                          obscureText: _obscureCurrentPassword,
                          enabled: !isLoading,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _newPasswordController,
                          style: theme.textTheme.bodyLarge,
                          decoration: InputDecoration(
                            labelText: 'New password *',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureNewPassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureNewPassword = !_obscureNewPassword;
                                });
                              },
                            ),
                            helperText: 'At least 8 characters',
                          ),
                          obscureText: _obscureNewPassword,
                          enabled: !isLoading,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _confirmPasswordController,
                          style: theme.textTheme.bodyLarge,
                          decoration: InputDecoration(
                            labelText: 'Confirm new password *',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.lock_clock),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword = !_obscureConfirmPassword;
                                });
                              },
                            ),
                          ),
                          obscureText: _obscureConfirmPassword,
                          enabled: !isLoading,
                        ),
                        const SizedBox(height: 16),
                        
                        // Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _isChangingPassword = false;
                                  _currentPasswordController.clear();
                                  _newPasswordController.clear();
                                  _confirmPasswordController.clear();
                                });
                              },
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed:
                                  isLoading ? null : _handleChangePassword,
                              child: isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Text('Update password'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Save button
              ElevatedButton(
                onPressed: isLoading ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save changes'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => context.pop(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

