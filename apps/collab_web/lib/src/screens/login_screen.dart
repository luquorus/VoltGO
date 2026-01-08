import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:shared_auth/shared_auth.dart';
import 'package:shared_network/shared_network.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await ref.read(authStateNotifierProvider.notifier).login(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (mounted) context.go('/home');
    } on ApiError catch (e) {
      if (mounted) AppToast.showError(context, e.message);
    } catch (e) {
      if (mounted) AppToast.showError(context, 'Login failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 48),
                    Text('VoltGo Collaborator Web', style: Theme.of(context).textTheme.headlineLarge, textAlign: TextAlign.center),
                    const SizedBox(height: 48),
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
                      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 24),
                    PrimaryButton(label: 'Login', onPressed: _isLoading ? null : _handleLogin, isLoading: _isLoading),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

