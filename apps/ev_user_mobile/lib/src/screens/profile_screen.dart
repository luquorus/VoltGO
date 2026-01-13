import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:shared_auth/shared_auth.dart';
import '../widgets/main_scaffold.dart';
import '../providers/profile_providers.dart';

/// Profile Screen
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    // Load profile when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(profileProvider.notifier).loadProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final profileState = ref.watch(profileProvider);
    final theme = Theme.of(context);

    final displayName = profileState.profile?['name'] as String? ?? 
                       authState.email ?? 'User';

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
                                displayName,
                                style: theme.textTheme.titleLarge,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                authState.email ?? '',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                authState.role ?? 'EV_USER',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                                ),
                              ),
                              if (profileState.profile?['phone'] != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.phone_outlined,
                                      size: 14,
                                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      profileState.profile!['phone'] as String,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurface.withOpacity(0.5),
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
                        label: const Text('Edit Profile'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
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

