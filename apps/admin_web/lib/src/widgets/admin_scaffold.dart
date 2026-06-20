import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_auth/shared_auth.dart';
import '../utils/responsive_utils.dart';
import 'admin_sidebar.dart';
import '../theme/admin_theme.dart';

class AdminScaffold extends ConsumerWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final bool showSidebar;

  const AdminScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.showSidebar = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final router = GoRouter.of(context);
    final currentRoute = router.routerDelegate.currentConfiguration.uri.path;
    final authState = ref.watch(authStateProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobileScreen = screenWidth < ResponsiveBreakpoints.mobile;
    final isTabletScreen = screenWidth >= ResponsiveBreakpoints.mobile &&
        screenWidth < ResponsiveBreakpoints.desktop;

    return Scaffold(
      backgroundColor: AdminTheme.surfaceLight,
      drawer: isMobileScreen ? Drawer(child: AdminSidebar(currentRoute: currentRoute)) : null,
      body: Row(
        children: [
          // Sidebar - hidden on mobile, collapsed on tablet, expanded on desktop
          if (showSidebar && !isMobileScreen)
            AdminSidebar(
              currentRoute: currentRoute,
              isCollapsed: isTabletScreen,
            ),

          // Main Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top App Bar
                Container(
                  height: isMobileScreen ? 60 : 70,
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: isMobileScreen ? 12 : 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Hamburger menu — mobile only
                      if (isMobileScreen)
                        IconButton(
                          icon: const Icon(Icons.menu),
                          onPressed: () => Scaffold.of(context).openDrawer(),
                          tooltip: 'Menu',
                        ),
                      // Title — takes all remaining space, pushes right-side items to far right
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            title,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: isMobileScreen ? 16 : null,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      // Account pill + logout + custom actions — always at far right
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Account pill — desktop/tablet only
                          if (!isMobileScreen)
                            _AccountPill(email: authState.email, theme: theme),
                          // Logout button — always visible
                          IconButton(
                            icon: Icon(
                              Icons.logout_rounded,
                              color: theme.colorScheme.onSurface.withOpacity(0.6),
                              size: 22,
                            ),
                            onPressed: () async {
                              await ref.read(authStateNotifierProvider.notifier).logout();
                              if (context.mounted) context.go('/login');
                            },
                            tooltip: 'Logout',
                          ),
                          // Custom actions
                          if (actions != null) ...actions!,
                        ],
                      ),
                    ],
                  ),
                ),

                // Body Content
                Expanded(
                  child: body,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountPill extends StatelessWidget {
  final String? email;
  final ThemeData theme;

  const _AccountPill({required this.email, required this.theme});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 180),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AdminTheme.primaryTeal.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_rounded,
              color: AdminTheme.primaryTeal,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    email ?? 'Admin',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Administrator',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

