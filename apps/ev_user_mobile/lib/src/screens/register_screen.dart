import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:shared_auth/shared_auth.dart';
import 'package:shared_network/shared_network.dart';
import 'package:shared_api/shared_api.dart';

/// Password strength levels
enum PasswordStrength { empty, weak, medium, strong }

/// Evaluate password strength
PasswordStrength _evaluateStrength(String password) {
  if (password.isEmpty) return PasswordStrength.empty;
  int score = 0;
  if (password.length >= 8) score++;
  if (password.length >= 12) score++;
  if (RegExp(r'[A-Z]').hasMatch(password)) score++;
  if (RegExp(r'[a-z]').hasMatch(password)) score++;
  if (RegExp(r'[0-9]').hasMatch(password)) score++;
  if (RegExp(r'[!@#$%^&*()_+\-=\[\]{}|;:,.<>?]').hasMatch(password)) score++;
  if (score <= 2) return PasswordStrength.weak;
  if (score <= 4) return PasswordStrength.medium;
  return PasswordStrength.strong;
}

/// Strong password validator
String? _strongPasswordValidator(String? value) {
  if (value == null || value.isEmpty) return 'Password is required';
  if (value.length < 8) return 'At least 8 characters required';
  if (!RegExp(r'^[A-Za-z0-9!@#$%^&*()_+\-=\[\]{}|;:,.<>?/\\`~^<>]+$').hasMatch(value)) {
    return 'Only English letters, numbers, and symbols allowed';
  }
  if (!RegExp(r'[A-Z]').hasMatch(value)) return 'At least one uppercase letter (A-Z) required';
  if (!RegExp(r'[a-z]').hasMatch(value)) return 'At least one lowercase letter (a-z) required';
  if (!RegExp(r'[0-9]').hasMatch(value)) return 'At least one number (0-9) required';
  if (!RegExp(r'[!@#$%^&*()_+\-=\[\]{}|;:,.<>?]').hasMatch(value)) {
    return 'At least one special character (!@#\$%^&*) required';
  }
  return null;
}

/// Referral strength indicator widget
class _PasswordStrengthIndicator extends StatelessWidget {
  final String password;

  const _PasswordStrengthIndicator({required this.password});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strength = _evaluateStrength(password);
    if (strength == PasswordStrength.empty) return const SizedBox.shrink();

    final (Color color, String label) = switch (strength) {
      PasswordStrength.weak => (Colors.red, 'Weak'),
      PasswordStrength.medium => (Colors.orange, 'Medium'),
      PasswordStrength.strong => (Colors.green, 'Strong'),
      PasswordStrength.empty => (Colors.grey, ''),
    };

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: switch (strength) {
                  PasswordStrength.weak => 0.33,
                  PasswordStrength.medium => 0.66,
                  PasswordStrength.strong => 1.0,
                  PasswordStrength.empty => 0,
                },
                backgroundColor: theme.colorScheme.outline.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 4,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Referral requirements checklist widget
class _PasswordRequirementsList extends StatelessWidget {
  final String password;

  const _PasswordRequirementsList({required this.password});

  @override
  Widget build(BuildContext context) {
    final reqs = [
      ('At least 8 characters', password.length >= 8),
      ('Uppercase letter (A-Z)', RegExp(r'[A-Z]').hasMatch(password)),
      ('Lowercase letter (a-z)', RegExp(r'[a-z]').hasMatch(password)),
      ('Number (0-9)', RegExp(r'[0-9]').hasMatch(password)),
      ('Special character (!@#\$%...)', RegExp(r'[!@#$%^&*()_+\-=\[\]{}|;:,.<>?]').hasMatch(password)),
      ('English letters only', RegExp(r'^[A-Za-z0-9!@#$%^&*()_+\-=\[\]{}|;:,.<>?/\\`~^<>]+$').hasMatch(password)),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Password must meet all requirements:',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          ...reqs.map((req) => _RequirementRow(label: req.$1, met: req.$2)),
        ],
      ),
    );
  }
}

class _RequirementRow extends StatelessWidget {
  final String label;
  final bool met;

  const _RequirementRow({required this.label, required this.met});

  @override
  Widget build(BuildContext context) {
    final color = met ? Colors.green : Theme.of(context).colorScheme.outline;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          FaIcon(
            met ? FontAwesomeIcons.checkCircle : FontAwesomeIcons.circle,
            size: 10,
            color: color,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
  final _referralCodeController = TextEditingController();
  String _selectedRole = 'EV_USER';
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;
  bool _showPasswordReqs = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _referralCodeController.dispose();
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
      final factory = ref.read(apiClientFactoryProvider);

      if (factory != null) {
        await authNotifier.registerWithApiClient(
          factory.auth,
          _emailController.text.trim(),
          _passwordController.text,
          _selectedRole,
          referralCode: _referralCodeController.text.trim().isEmpty
              ? null
              : _referralCodeController.text.trim(),
        );
      } else {
        await authNotifier.register(
          _emailController.text.trim(),
          _passwordController.text,
          _selectedRole,
        );
      }

      if (mounted) {
        context.go('/home');
      }
    } catch (e) {
      final friendly = formatApiError(e, fallback: 'Registration failed');
      setState(() {
        _errorMessage = friendly;
        _isLoading = false;
      });
      if (mounted) AppToast.showError(context, friendly);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final password = _passwordController.text;
    final strength = _evaluateStrength(password);

    return AppScaffold(
      title: 'Sign up',
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
                    if (value == null || value.isEmpty) return 'Please enter your email';
                    if (!value.contains('@')) return 'Invalid email address';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Focus(
                  onFocusChange: (hasFocus) {
                    if (hasFocus || password.isNotEmpty) {
                      setState(() => _showPasswordReqs = true);
                    } else {
                      setState(() => _showPasswordReqs = false);
                    }
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppTextField(
                        label: 'Password',
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        enabled: !_isLoading,
                        validator: _strongPasswordValidator,
                        onChanged: (_) => setState(() {}),
                        suffixIcon: IconButton(
                          icon: FaIcon(
                            _obscurePassword
                                ? FontAwesomeIcons.eye
                                : FontAwesomeIcons.eyeSlash,
                          ),
                          onPressed: () {
                            setState(() => _obscurePassword = !_obscurePassword);
                          },
                        ),
                      ),
                      if (strength != PasswordStrength.empty) ...[
                        const SizedBox(height: 4),
                        _PasswordStrengthIndicator(password: password),
                      ],
                      if (_showPasswordReqs) _PasswordRequirementsList(password: password),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Confirm password',
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  enabled: !_isLoading,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                  suffixIcon: IconButton(
                    icon: FaIcon(
                      _obscureConfirmPassword
                          ? FontAwesomeIcons.eye
                          : FontAwesomeIcons.eyeSlash,
                    ),
                    onPressed: () {
                      setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                    },
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  decoration: InputDecoration(
                    labelText: 'Role',
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'EV_USER', child: Text('EV user')),
                  ],
                  onChanged: _isLoading
                      ? null
                      : (value) {
                          if (value != null) setState(() => _selectedRole = value);
                        },
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Referral Code (optional)',
                  controller: _referralCodeController,
                  enabled: !_isLoading,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _handleRegister(),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        FaIcon(FontAwesomeIcons.circleExclamation,
                            color: theme.colorScheme.error, size: 14),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onErrorContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                PrimaryButton(
                  label: 'Sign up',
                  onPressed: _isLoading ? null : _handleRegister,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: 12),
                SecondaryButton(
                  label: 'Back to log in',
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

