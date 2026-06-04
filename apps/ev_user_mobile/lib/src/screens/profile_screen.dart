import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:shared_auth/shared_auth.dart';
import '../widgets/main_scaffold.dart';
import '../providers/profile_providers.dart';

/// Hồ sơ người dùng EV.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(profileProvider.notifier).loadProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final profileState = ref.watch(profileProvider);
    final theme = Theme.of(context);

    final displayName =
        profileState.profile?['name'] as String? ?? authState.email ?? 'You';

    return MainScaffold(
      title: 'Profile',
      child: RefreshIndicator(
        onRefresh: () async =>
            await ref.read(profileProvider.notifier).loadProfile(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (profileState.error != null)
                _ProfileErrorBanner(
                  message: formatApiError(profileState.error),
                  onRetry: () =>
                      ref.read(profileProvider.notifier).loadProfile(),
                ),
              _buildProfileCard(context, theme, displayName, authState,
                  profileState.profile),
              const SizedBox(height: 24),
              _buildMenuItem(
                context,
                theme,
                FontAwesomeIcons.book,
                'My bookings',
                () => context.go('/bookings'),
              ),
              _buildMenuItem(
                context,
                theme,
                FontAwesomeIcons.filePen,
                'Station edit proposals',
                () => context.go('/change-requests'),
              ),
              _buildMenuItem(
                context,
                theme,
                FontAwesomeIcons.triangleExclamation,
                'My reports',
                () => context.push('/issues/mine'),
              ),
              _buildMenuItem(
                context,
                theme,
                FontAwesomeIcons.gear,
                'Settings',
                () => _openSettings(context, theme),
              ),
              _buildMenuItem(
                context,
                theme,
                FontAwesomeIcons.circleQuestion,
                'Help & support',
                () => _openHelp(context, theme),
              ),
              const SizedBox(height: 24),
              DestructiveButton(
                label: 'Log out',
                onPressed: () => _logout(context, ref),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  'VoltGo • EV User',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(
    BuildContext context,
    ThemeData theme,
    String displayName,
    AuthState authState,
    Map<String, dynamic>? profile,
  ) {
    final phone = profile?['phone'] as String?;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: theme.colorScheme.primary,
                  child: const FaIcon(
                    FontAwesomeIcons.user,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(displayName, style: theme.textTheme.titleLarge),
                      const SizedBox(height: 4),
                      if ((authState.email ?? '').isNotEmpty)
                        Text(
                          authState.email!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color:
                                theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        _roleLabel(authState.role),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                      if (phone != null && phone.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.phone_outlined,
                              size: 14,
                              color: theme.colorScheme.onSurface
                                  .withOpacity(0.5),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              phone,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.push('/profile/edit'),
                icon: const FaIcon(FontAwesomeIcons.pen, size: 14),
                label: const Text('Edit profile'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _roleLabel(String? role) {
    switch (role) {
      case 'EV_USER':
        return 'EV user';
      case 'ADMIN':
        return 'Administrator';
      case 'COLLABORATOR':
        return 'Collaborator';
      default:
        return role ?? '—';
    }
  }

  Widget _buildMenuItem(
    BuildContext context,
    ThemeData theme,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: FaIcon(icon, color: theme.colorScheme.primary),
        title: Text(label),
        trailing: const FaIcon(FontAwesomeIcons.chevronRight, size: 16),
        onTap: onTap,
      ),
    );
  }

  Future<void> _openSettings(BuildContext context, ThemeData theme) async {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const FaIcon(FontAwesomeIcons.gear, size: 18),
                  const SizedBox(width: 10),
                  Text('Settings',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      )),
                ],
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const FaIcon(FontAwesomeIcons.bell, size: 18),
                title: const Text('Push notifications'),
                subtitle:
                    const Text('Manage in your device system settings'),
                trailing: const FaIcon(FontAwesomeIcons.upRightFromSquare,
                    size: 14),
                onTap: () {
                  Navigator.pop(ctx);
                  AppToast.showInfo(
                    context,
                    'Open system settings to enable or disable VoltGo notifications.',
                  );
                },
              ),
              ListTile(
                leading:
                    const FaIcon(FontAwesomeIcons.locationCrosshairs, size: 18),
                title: const Text('Location permission'),
                subtitle: const Text(
                    'Required to find nearby stations and optimized suggestions'),
                trailing: const FaIcon(FontAwesomeIcons.upRightFromSquare,
                    size: 14),
                onTap: () {
                  Navigator.pop(ctx);
                  AppToast.showInfo(
                    context,
                    'Go to System settings > Apps > VoltGo to grant location access.',
                  );
                },
              ),
              ListTile(
                leading: const FaIcon(FontAwesomeIcons.shieldHalved, size: 18),
                title: const Text('Security & privacy'),
                subtitle: const Text(
                    'Your data is stored securely under the VoltGo policy'),
                onTap: () => Navigator.pop(ctx),
              ),
              ListTile(
                leading: const FaIcon(FontAwesomeIcons.code, size: 18),
                title: const Text('App version'),
                subtitle: const Text('VoltGo EV User • 1.0.0'),
                onTap: () {
                  Clipboard.setData(const ClipboardData(text: 'VoltGo 1.0.0'));
                  AppToast.showInfo(context, 'Version copied.');
                },
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openHelp(BuildContext context, ThemeData theme) async {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Row(
            children: const [
              FaIcon(FontAwesomeIcons.circleQuestion, size: 18),
              SizedBox(width: 8),
              Text('Help & support'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Need help? Contact the VoltGo team:',
              ),
              const SizedBox(height: 12),
              _HelpRow(
                icon: FontAwesomeIcons.envelope,
                label: 'Email',
                value: 'support@voltgo.vn',
                copyValue: 'support@voltgo.vn',
              ),
              const SizedBox(height: 6),
              _HelpRow(
                icon: FontAwesomeIcons.phone,
                label: 'Hotline',
                value: '1900 1234',
                copyValue: '19001234',
              ),
              const SizedBox(height: 12),
              const Text(
                'Quick tips:\n• Enable location to find nearby stations.\n• Check your network if data fails to load.\n• Log out and log in again if your session expires.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(authStateNotifierProvider.notifier).logout();
        if (context.mounted) context.go('/login');
      } catch (e) {
        if (context.mounted) {
          AppToast.showError(
              context, 'Log out failed: ${formatApiError(e)}');
        }
      }
    }
  }
}

class _HelpRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String copyValue;

  const _HelpRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.copyValue,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        FaIcon(icon, size: 14),
        const SizedBox(width: 8),
        Text('$label: '),
        Expanded(child: SelectableText(value)),
        IconButton(
          tooltip: 'Copy',
          iconSize: 14,
          onPressed: () {
            Clipboard.setData(ClipboardData(text: copyValue));
            AppToast.showInfo(context, 'Copied $label.');
          },
          icon: const FaIcon(FontAwesomeIcons.copy),
        ),
      ],
    );
  }
}

class _ProfileErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ProfileErrorBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.error.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          FaIcon(FontAwesomeIcons.triangleExclamation,
              color: theme.colorScheme.error, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: theme.textTheme.bodySmall),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
