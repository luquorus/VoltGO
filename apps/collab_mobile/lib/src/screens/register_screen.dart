import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:shared_auth/shared_auth.dart';
import 'package:shared_network/shared_network.dart';

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
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await ref.read(authStateNotifierProvider.notifier).register(
        _emailController.text.trim(),
        _passwordController.text,
        'COLLABORATOR',
      );
      if (mounted) context.go('/home');
    } on ApiError catch (e) {
      if (mounted) AppToast.showError(context, e.message);
    } catch (e) {
      if (mounted) AppToast.showError(context, 'Registration failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
                  validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Password',
                  controller: _passwordController,
                  obscureText: true,
                  enabled: !_isLoading,
                  validator: (v) => (v?.length ?? 0) < 8 ? 'Min 8 chars' : null,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Confirm Password',
                  controller: _confirmPasswordController,
                  obscureText: true,
                  enabled: !_isLoading,
                  validator: (v) => v != _passwordController.text ? 'Mismatch' : null,
                ),
                const SizedBox(height: 24),
                PrimaryButton(label: 'Register', onPressed: _isLoading ? null : _handleRegister, isLoading: _isLoading),
                const SizedBox(height: 16),
                SecondaryButton(label: 'Back', onPressed: _isLoading ? null : () => context.pop()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

