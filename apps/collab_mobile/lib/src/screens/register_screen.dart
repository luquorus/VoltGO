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
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Real-time validation states
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasSpecialChar = false;
  bool _passwordsMatch = false;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_onPasswordChanged);
    _confirmPasswordController.addListener(_onConfirmPasswordChanged);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onPasswordChanged() {
    final p = _passwordController.text;
    setState(() {
      _hasMinLength = p.length >= 8;
      _hasUppercase = p.runes.any((r) => r >= 65 && r <= 90);
      _hasSpecialChar = p.runes.any((r) =>
          (r >= 33 && r <= 47) ||
          (r >= 58 && r <= 64) ||
          (r >= 91 && r <= 96) ||
          (r >= 123 && r <= 126));
      _updatePasswordsMatch();
    });
  }

  void _onConfirmPasswordChanged() {
    setState(() {
      _updatePasswordsMatch();
    });
  }

  void _updatePasswordsMatch() {
    _passwordsMatch = _confirmPasswordController.text.isNotEmpty &&
        _confirmPasswordController.text == _passwordController.text;
  }

  bool get _isPasswordValid => _hasMinLength && _hasUppercase && _hasSpecialChar;

  Widget _buildRuleRow(String text, bool satisfied) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            satisfied ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: satisfied ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: satisfied ? Colors.green.shade700 : Colors.grey.shade600,
              fontWeight: satisfied ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isPasswordValid) return;
    if (_confirmPasswordController.text != _passwordController.text) return;

    setState(() => _isLoading = true);

    try {
      await ref.read(authStateNotifierProvider.notifier).register(
        _emailController.text.trim(),
        _passwordController.text,
        'COLLABORATOR',
      );
      if (mounted) context.go('/registration-form');
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
                  obscureText: _obscurePassword,
                  enabled: !_isLoading,
                  validator: (v) => (v?.length ?? 0) < 8 ? 'Min 8 characters' : null,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Password Requirements',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _buildRuleRow('At least 8 characters', _hasMinLength),
                      _buildRuleRow('Contains an uppercase letter', _hasUppercase),
                      _buildRuleRow('Contains a special character (!@#\$%^&*)', _hasSpecialChar),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Confirm Password',
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  enabled: !_isLoading,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (v != _passwordController.text) return 'Passwords do not match';
                    return null;
                  },
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_confirmPasswordController.text.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(
                            _passwordsMatch ? Icons.check_circle : Icons.cancel,
                            size: 20,
                            color: _passwordsMatch ? Colors.green : Colors.red,
                          ),
                        ),
                      IconButton(
                        icon: Icon(
                          _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                if (_confirmPasswordController.text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 12),
                    child: Text(
                      _passwordsMatch ? 'Passwords match' : 'Passwords do not match',
                      style: TextStyle(
                        fontSize: 13,
                        color: _passwordsMatch ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: 'Register',
                  onPressed: _isLoading || !_isPasswordValid
                      ? null
                      : _handleRegister,
                  isLoading: _isLoading,
                ),
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
