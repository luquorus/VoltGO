import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/admin_theme.dart';
import '../providers/registration_request_providers.dart';

class AdminSidebar extends ConsumerWidget {
  final String currentRoute;
  final bool isCollapsed;

  const AdminSidebar({
    super.key,
    required this.currentRoute,
    this.isCollapsed = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final pendingCountAsync = ref.watch(pendingRequestsCountProvider);
    final pendingCount = pendingCountAsync.maybeWhen(
      data: (count) => count,
      orElse: () => 0,
    );

    final sidebarWidth = isCollapsed ? 72.0 : 260.0;

    return Container(
      width: sidebarWidth,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Logo/Header
          Container(
            padding: EdgeInsets.all(isCollapsed ? 12 : 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AdminTheme.primaryTeal,
                  AdminTheme.primaryTealLight,
                ],
              ),
            ),
            child: isCollapsed
                ? Center(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.electric_bolt,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  )
                : Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.electric_bolt,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'VoltGo',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
          ),

          // Navigation Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                _buildNavItem(
                  context,
                  theme,
                  isCollapsed: isCollapsed,
                  icon: Icons.dashboard_rounded,
                  label: 'Dashboard',
                  route: '/home',
                  isActive: currentRoute == '/home',
                ),
                _buildNavItem(
                  context,
                  theme,
                  isCollapsed: isCollapsed,
                  icon: Icons.analytics,
                  label: 'Analytics',
                  route: '/dashboard',
                  isActive: currentRoute == '/dashboard',
                ),
                _buildNavItem(
                  context,
                  theme,
                  isCollapsed: isCollapsed,
                  icon: Icons.description_rounded,
                  label: 'Change Requests',
                  route: '/change-requests',
                  isActive: currentRoute.startsWith('/change-requests'),
                ),
                _buildNavItem(
                  context,
                  theme,
                  isCollapsed: isCollapsed,
                  icon: Icons.report_problem_rounded,
                  label: 'Issue Reports',
                  route: '/issues',
                  isActive: currentRoute.startsWith('/issues'),
                ),
                _buildNavItem(
                  context,
                  theme,
                  isCollapsed: isCollapsed,
                  icon: Icons.ev_station,
                  label: 'Charging Stations',
                  route: '/stations',
                  isActive: currentRoute.startsWith('/stations') &&
                      !currentRoute.startsWith('/trust/') &&
                      !currentRoute.startsWith('/battery-swap'),
                ),
                _buildNavItem(
                  context,
                  theme,
                  isCollapsed: isCollapsed,
                  icon: Icons.battery_charging_full,
                  label: 'Battery Swap Stations',
                  route: '/battery-swap/stations',
                  isActive: currentRoute.startsWith('/battery-swap/stations'),
                ),
                _buildNavItem(
                  context,
                  theme,
                  isCollapsed: isCollapsed,
                  icon: Icons.verified_user_rounded,
                  label: 'Charging Trust',
                  route: '/trust/charging',
                  isActive: currentRoute.startsWith('/trust/charging'),
                ),
                _buildNavItem(
                  context,
                  theme,
                  isCollapsed: isCollapsed,
                  icon: Icons.electric_bolt,
                  label: 'Swap Trust',
                  route: '/trust/battery-swap',
                  isActive: currentRoute.startsWith('/trust/battery-swap'),
                ),
                _SidebarNavItem(
                  context: context,
                  theme: theme,
                  isCollapsed: isCollapsed,
                  icon: Icons.people_rounded,
                  label: 'Collaborators',
                  route: '/collaborators',
                  isActive: currentRoute.startsWith('/collaborators') &&
                      !currentRoute.contains('/performance'),
                  badgeCount: pendingCount,
                ),
                _buildNavItem(
                  context,
                  theme,
                  isCollapsed: isCollapsed,
                  icon: Icons.trending_up,
                  label: 'Collaborator Performance',
                  route: '/collaborators/performance',
                  isActive: currentRoute.startsWith('/collaborators/performance'),
                ),
                _buildNavItem(
                  context,
                  theme,
                  isCollapsed: isCollapsed,
                  icon: Icons.assignment_rounded,
                  label: 'Verification Tasks',
                  route: '/verification-tasks',
                  isActive: currentRoute.startsWith('/verification-tasks'),
                ),
                _buildNavItem(
                  context,
                  theme,
                  isCollapsed: isCollapsed,
                  icon: Icons.history_rounded,
                  label: 'Audit Logs',
                  route: '/audit',
                  isActive: currentRoute.startsWith('/audit'),
                ),
                Divider(height: 32, indent: isCollapsed ? 8 : 16, endIndent: isCollapsed ? 8 : 16),
                _buildNavItem(
                  context,
                  theme,
                  isCollapsed: isCollapsed,
                  icon: Icons.card_giftcard,
                  label: 'Loyalty',
                  route: '/loyalty',
                  isActive: currentRoute.startsWith('/loyalty'),
                ),
                _buildNavItem(
                  context,
                  theme,
                  isCollapsed: isCollapsed,
                  icon: Icons.local_offer,
                  label: 'Quản lý Voucher',
                  route: '/loyalty/vouchers',
                  isActive: currentRoute == '/loyalty/vouchers',
                ),
                _buildNavItem(
                  context,
                  theme,
                  isCollapsed: isCollapsed,
                  icon: Icons.receipt_long,
                  label: 'Redemptions',
                  route: '/loyalty/vouchers/redemptions',
                  isActive: currentRoute == '/loyalty/vouchers/redemptions',
                ),
                Divider(height: 32, indent: isCollapsed ? 8 : 16, endIndent: isCollapsed ? 8 : 16),
                _buildNavItem(
                  context,
                  theme,
                  isCollapsed: isCollapsed,
                  icon: Icons.person_rounded,
                  label: 'My Profile',
                  route: '/profile',
                  isActive: currentRoute.startsWith('/profile'),
                ),
              ],
            ),
          ),

          // Footer
          Container(
            padding: EdgeInsets.all(isCollapsed ? 8 : 16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: AdminTheme.outlineLight,
                  width: 1,
                ),
              ),
            ),
            child: isCollapsed
                ? Center(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AdminTheme.primaryTeal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.admin_panel_settings_rounded,
                        color: AdminTheme.primaryTeal,
                        size: 20,
                      ),
                    ),
                  )
                : Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AdminTheme.primaryTeal.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.admin_panel_settings_rounded,
                          color: AdminTheme.primaryTeal,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Admin Portal',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'v1.0.0',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.5),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    ThemeData theme, {
    required IconData icon,
    required String label,
    required String route,
    required bool isActive,
    bool isCollapsed = false,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isCollapsed ? 8 : 12, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.go(route),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 12 : 16, vertical: 14),
            decoration: BoxDecoration(
              color: isActive
                  ? AdminTheme.primaryTeal.withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isActive
                  ? Border.all(
                      color: AdminTheme.primaryTeal.withOpacity(0.3),
                      width: 1,
                    )
                  : null,
            ),
            child: isCollapsed
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        color: isActive
                            ? AdminTheme.primaryTeal
                            : theme.colorScheme.onSurface.withOpacity(0.6),
                        size: 22,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label.split(' ').first,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                          color: isActive
                              ? AdminTheme.primaryTeal
                              : theme.colorScheme.onSurface.withOpacity(0.8),
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Icon(
                        icon,
                        color: isActive
                            ? AdminTheme.primaryTeal
                            : theme.colorScheme.onSurface.withOpacity(0.6),
                        size: 22,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          label,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                            color: isActive
                                ? AdminTheme.primaryTeal
                                : theme.colorScheme.onSurface.withOpacity(0.8),
                          ),
                        ),
                      ),
                      if (isActive)
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AdminTheme.primaryTeal,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Sidebar nav item with optional badge count
class _SidebarNavItem extends StatelessWidget {
  final BuildContext context;
  final ThemeData theme;
  final bool isCollapsed;
  final IconData icon;
  final String label;
  final String route;
  final bool isActive;
  final int badgeCount;

  const _SidebarNavItem({
    required this.context,
    required this.theme,
    required this.isCollapsed,
    required this.icon,
    required this.label,
    required this.route,
    required this.isActive,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isCollapsed ? 8 : 12, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => GoRouter.of(context).go(route),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 12 : 16, vertical: 14),
            decoration: BoxDecoration(
              color: isActive
                  ? AdminTheme.primaryTeal.withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isActive
                  ? Border.all(
                      color: AdminTheme.primaryTeal.withOpacity(0.3),
                      width: 1,
                    )
                  : null,
            ),
            child: isCollapsed
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            icon,
                            color: isActive
                                ? AdminTheme.primaryTeal
                                : theme.colorScheme.onSurface.withOpacity(0.6),
                            size: 22,
                          ),
                          if (badgeCount > 0)
                            Positioned(
                              right: -6,
                              top: -4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                constraints: const BoxConstraints(minWidth: 14),
                                child: Text(
                                  badgeCount > 9 ? '9+' : badgeCount.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label.split(' ').first,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                          color: isActive
                              ? AdminTheme.primaryTeal
                              : theme.colorScheme.onSurface.withOpacity(0.8),
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Icon(
                        icon,
                        color: isActive
                            ? AdminTheme.primaryTeal
                            : theme.colorScheme.onSurface.withOpacity(0.6),
                        size: 22,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          label,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                            color: isActive
                                ? AdminTheme.primaryTeal
                                : theme.colorScheme.onSurface.withOpacity(0.8),
                          ),
                        ),
                      ),
                      if (badgeCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(minWidth: 18),
                          child: Text(
                            badgeCount > 99 ? '99+' : badgeCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        )
                      else if (isActive)
                        Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: AdminTheme.primaryTeal,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
