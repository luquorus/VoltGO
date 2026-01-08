import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:shared_auth/shared_auth.dart';
import 'package:shared_network/shared_network.dart';

/// Login screen
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
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authNotifier = ref.read(authStateNotifierProvider.notifier);
      await authNotifier.login(
        _emailController.text.trim(),
        _passwordController.text,
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
        AppToast.showError(context, 'Login failed: ${e.toString()}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 48),
                Text(
                  'Welcome to VoltGo',
                  style: Theme.of(context).textTheme.headlineLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'EV User Mobile',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
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
                      return 'Please enter your password';
                    }
                    return null;
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
                  label: 'Login',
                  onPressed: _isLoading ? null : _handleLogin,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: 16),
                SecondaryButton(
                  label: 'Register',
                  onPressed: _isLoading ? null : () => context.push('/register'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

