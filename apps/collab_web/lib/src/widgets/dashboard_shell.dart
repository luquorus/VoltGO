import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_auth/shared_auth.dart';
import '../theme/collab_theme.dart';
import 'sidebar.dart';

/// Dashboard Shell with Sidebar + Topbar + Content area
/// Desktop-first responsive layout
class DashboardShell extends ConsumerWidget {
  final Widget child;
  final String title;
  final Widget? filterSlot;
  final Widget? searchSlot;
  final List<Widget>? actions;

  const DashboardShell({
    super.key,
    required this.child,
    required this.title,
    this.filterSlot,
    this.searchSlot,
    this.actions,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentPath = GoRouterState.of(context).uri.path;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;
    final isTablet = screenWidth >= 768 && screenWidth < 1024;

    return Scaffold(
      drawer: isDesktop
          ? null
          : Drawer(
              child: CollabSidebar(
                currentPath: currentPath,
                onLogout: () => _handleLogout(context, ref),
              ),
            ),
      body: Row(
        children: [
          // Sidebar - only on desktop
          if (isDesktop)
            CollabSidebar(
              currentPath: currentPath,
              onLogout: () => _handleLogout(context, ref),
            ),

          // Main Content Area
          Expanded(
            child: Column(
              children: [
                // Topbar
                Container(
                  height: 72,
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 32 : 16,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    border: Border(
                      bottom: BorderSide(
                        color: theme.colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Menu button for tablet/mobile
                      if (!isDesktop)
                        IconButton(
                          icon: const Icon(Icons.menu),
                          onPressed: () {
                            Scaffold.of(context).openDrawer();
                          },
                        ),

                      // Title
                      Text(
                        title,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const Spacer(),

                      // Filter slot
                      if (filterSlot != null) ...[
                        filterSlot!,
                        const SizedBox(width: 16),
                      ],

                      // Search slot
                      if (searchSlot != null) ...[
                        SizedBox(
                          width: isDesktop ? 300 : (isTablet ? 200 : 150),
                          child: searchSlot,
                        ),
                        const SizedBox(width: 16),
                      ],

                      // Actions
                      if (actions != null) ...actions!,

                      // User Avatar
                      _buildUserAvatar(context, ref),
                    ],
                  ),
                ),

                // Content Area
                Expanded(
                  child: Container(
                    color: CollabTheme.surfaceLight,
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserAvatar(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final theme = Theme.of(context);
    final email = authState.email ?? 'User';
    final initial = email.isNotEmpty ? email[0].toUpperCase() : 'U';

    return PopupMenuButton<String>(
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: CollabTheme.primaryGreenLight.withOpacity(0.1),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: CollabTheme.primaryGreenLight,
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  email,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Collaborator',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: CollabTheme.primaryGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              size: 18,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ],
        ),
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'profile',
          child: ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Profile'),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'logout',
          child: ListTile(
            leading: Icon(Icons.logout, color: theme.colorScheme.error),
            title: Text('Logout', style: TextStyle(color: theme.colorScheme.error)),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
      ],
      onSelected: (value) {
        if (value == 'profile') {
          context.go('/me/profile');
        } else if (value == 'logout') {
          _handleLogout(context, ref);
        }
      },
    );
  }

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    await ref.read(authStateNotifierProvider.notifier).logout();
    if (context.mounted) context.go('/login');
  }
}

