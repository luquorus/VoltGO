import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:shared_auth/shared_auth.dart';
import '../widgets/main_scaffold.dart';

/// Profile Screen
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final theme = Theme.of(context);

    return MainScaffold(
      title: 'Profile',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User info card
            Card(
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
                          child: FaIcon(
                            FontAwesomeIcons.user,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                authState.email ?? 'User',
                                style: theme.textTheme.titleLarge,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                authState.role ?? 'EV_USER',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Menu items
            _buildMenuItem(
              context,
              theme,
              FontAwesomeIcons.book,
              'My Bookings',
              () => context.go('/bookings'),
            ),
            _buildMenuItem(
              context,
              theme,
              FontAwesomeIcons.filePen,
              'Station Proposals',
              () => context.go('/change-requests'),
            ),
            _buildMenuItem(
              context,
              theme,
              FontAwesomeIcons.triangleExclamation,
              'My Issues',
              () => context.push('/issues/mine'),
            ),
            _buildMenuItem(
              context,
              theme,
              FontAwesomeIcons.gear,
              'Settings',
              () {
                AppToast.showInfo(context, 'Settings coming soon!');
              },
            ),
            _buildMenuItem(
              context,
              theme,
              FontAwesomeIcons.circleQuestion,
              'Help & Support',
              () {
                AppToast.showInfo(context, 'Help & Support coming soon!');
              },
            ),
            const SizedBox(height: 24),

            // Logout button
            DestructiveButton(
              label: 'Logout',
              onPressed: () => _logout(context, ref),
            ),
          ],
        ),
      ),
    );
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

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authStateNotifierProvider.notifier).logout();
      if (context.mounted) {
        context.go('/login');
      }
    }
  }
}

