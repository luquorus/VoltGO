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

    final effectiveSidebarWidth = sidebarWidth(context);

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
              children: [
                // Top App Bar
                Container(
                  height: isMobileScreen ? 60 : 70,
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
                      if (isMobileScreen)
                        IconButton(
                          icon: const Icon(Icons.menu),
                          onPressed: () => Scaffold.of(context).openDrawer(),
                          tooltip: 'Menu',
                        ),
                      // Title
                      Flexible(
                        child: Text(
                          title,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: isMobileScreen ? 16 : null,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Spacer(),
                      // User Info - hide labels on small screens
                      if (!isMobileScreen)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AdminTheme.primaryTeal.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.person_rounded,
                                color: AdminTheme.primaryTeal,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  authState.email ?? 'Admin',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Administrator',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 16),
                          ],
                        ),
                      // Logout Button
                      IconButton(
                        icon: Icon(
                          Icons.logout_rounded,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                          size: isMobileScreen ? 22 : null,
                        ),
                        onPressed: () async {
                          await ref.read(authStateNotifierProvider.notifier).logout();
                          if (context.mounted) context.go('/login');
                        },
                        tooltip: 'Logout',
                      ),
                      // Custom Actions
                      if (actions != null) ...actions!,
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

