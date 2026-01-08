import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:shared_auth/shared_auth.dart';
import 'package:shared_network/shared_network.dart';

/// Register screen
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String _selectedRole = 'EV_USER';
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authNotifier = ref.read(authStateNotifierProvider.notifier);
      await authNotifier.register(
        _emailController.text.trim(),
        _passwordController.text,
        _selectedRole,
      );
      
      if (mounted) {
        context.go('/home');
      }
    } on ApiError catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
      if (mounted) {
        AppToast.showError(context, e.message);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
      if (mounted) {
        AppToast.showError(context, 'Registration failed: ${e.toString()}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Register',
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                AppTextField(
                  label: 'Email',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  enabled: !_isLoading,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Password',
                  controller: _passwordController,
                  obscureText: true,
                  enabled: !_isLoading,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    if (value.length < 8) {
                      return 'Password must be at least 8 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Confirm Password',
                  controller: _confirmPasswordController,
                  obscureText: true,
                  enabled: !_isLoading,
                  validator: (value) {
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  decoration: InputDecoration(
                    labelText: 'Role',
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'EV_USER', child: Text('EV User')),
                    DropdownMenuItem(value: 'PROVIDER', child: Text('Provider')),
                  ],
                  onChanged: _isLoading
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _selectedRole = value);
                          }
                        },
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 24),
                PrimaryButton(
                  label: 'Register',
                  onPressed: _isLoading ? null : _handleRegister,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: 16),
                SecondaryButton(
                  label: 'Back to Login',
                  onPressed: _isLoading ? null : () => context.pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

