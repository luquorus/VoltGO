import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/admin_theme.dart';
import '../providers/registration_request_providers.dart';

/// Thin section header with label and optional divider.
class _SectionHeader extends StatelessWidget {
  final String label;
  final bool showDivider;
  final bool isCollapsed;

  const _SectionHeader({
    required this.label,
    this.showDivider = false,
    required this.isCollapsed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showDivider) const SizedBox(height: 12),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 12 : 16),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: Colors.black.withOpacity(0.35),
            ),
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }
}

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
          _SidebarLogo(isCollapsed: isCollapsed),

          // Scrollable nav + pinned footer
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    children: [
                      // ── OVERVIEW ──────────────────────────────────────────
                      _SectionHeader(label: 'OVERVIEW', isCollapsed: isCollapsed),
                      _NavItem(
                        currentRoute: currentRoute,
                        isCollapsed: isCollapsed,
                        icon: Icons.analytics,
                        label: 'Analytics',
                        route: '/dashboard',
                      ),

                      // ── STATIONS ────────────────────────────────────────
                      _SectionHeader(label: 'STATIONS', showDivider: true, isCollapsed: isCollapsed),
                      _NavItem(
                        currentRoute: currentRoute,
                        isCollapsed: isCollapsed,
                        icon: Icons.ev_station,
                        label: 'Charging Stations',
                        route: '/stations',
                        isActive: currentRoute.startsWith('/stations') &&
                            !currentRoute.startsWith('/trust/') &&
                            !currentRoute.startsWith('/battery-swap'),
                      ),
                      _NavItem(
                        currentRoute: currentRoute,
                        isCollapsed: isCollapsed,
                        icon: Icons.battery_charging_full,
                        label: 'Battery Swap Stations',
                        route: '/battery-swap/stations',
                      ),

                      // ── GOVERNANCE & TRUST ──────────────────────────────
                      _SectionHeader(label: 'GOVERNANCE & TRUST', showDivider: true, isCollapsed: isCollapsed),
                      _NavItem(
                        currentRoute: currentRoute,
                        isCollapsed: isCollapsed,
                        icon: Icons.description_rounded,
                        label: 'Change Requests',
                        route: '/change-requests',
                      ),
                      _NavItem(
                        currentRoute: currentRoute,
                        isCollapsed: isCollapsed,
                        icon: Icons.assignment_rounded,
                        label: 'Verification Tasks',
                        route: '/verification-tasks',
                      ),
                      _NavItem(
                        currentRoute: currentRoute,
                        isCollapsed: isCollapsed,
                        icon: Icons.report_problem_rounded,
                        label: 'Issue Reports',
                        route: '/issues',
                      ),
                      _NavItem(
                        currentRoute: currentRoute,
                        isCollapsed: isCollapsed,
                        icon: Icons.verified_user_rounded,
                        label: 'Charging Trust',
                        route: '/trust/charging',
                      ),
                      _NavItem(
                        currentRoute: currentRoute,
                        isCollapsed: isCollapsed,
                        icon: Icons.electric_bolt,
                        label: 'Swap Trust',
                        route: '/trust/battery-swap',
                      ),

                      // ── COLLABORATORS ───────────────────────────────────
                      _SectionHeader(label: 'COLLABORATORS', showDivider: true, isCollapsed: isCollapsed),
                      _SidebarNavItemWithBadge(
                        currentRoute: currentRoute,
                        isCollapsed: isCollapsed,
                        icon: Icons.people_rounded,
                        label: 'Collaborators',
                        route: '/collaborators',
                        isActive: currentRoute.startsWith('/collaborators') &&
                            !currentRoute.contains('/performance'),
                        badgeCount: pendingCount,
                      ),
                      _NavItem(
                        currentRoute: currentRoute,
                        isCollapsed: isCollapsed,
                        icon: Icons.trending_up,
                        label: 'Collaborator Performance',
                        route: '/collaborators/performance',
                      ),

                      // ── LOYALTY & REWARDS ───────────────────────────────
                      _SectionHeader(label: 'LOYALTY & REWARDS', showDivider: true, isCollapsed: isCollapsed),
                      _NavItem(
                        currentRoute: currentRoute,
                        isCollapsed: isCollapsed,
                        icon: Icons.card_giftcard,
                        label: 'Loyalty',
                        route: '/loyalty',
                      ),
                      _NavItem(
                        currentRoute: currentRoute,
                        isCollapsed: isCollapsed,
                        icon: Icons.local_offer,
                        label: 'Voucher Management',
                        route: '/loyalty/vouchers',
                      ),
                      _NavItem(
                        currentRoute: currentRoute,
                        isCollapsed: isCollapsed,
                        icon: Icons.receipt_long,
                        label: 'Redemptions',
                        route: '/loyalty/vouchers/redemptions',
                      ),

                      // ── SYSTEM ─────────────────────────────────────────
                      _SectionHeader(label: 'SYSTEM', showDivider: true, isCollapsed: isCollapsed),
                      _NavItem(
                        currentRoute: currentRoute,
                        isCollapsed: isCollapsed,
                        icon: Icons.history_rounded,
                        label: 'Audit Logs',
                        route: '/audit',
                      ),
                      _NavItem(
                        currentRoute: currentRoute,
                        isCollapsed: isCollapsed,
                        icon: Icons.person_rounded,
                        label: 'My Profile',
                        route: '/profile',
                      ),
                    ],
                  ),
                ),

                // Footer — pinned at the bottom when height allows
                _SidebarFooter(isCollapsed: isCollapsed, theme: theme),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarLogo extends StatelessWidget {
  final bool isCollapsed;

  const _SidebarLogo({required this.isCollapsed});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isCollapsed ? 12 : 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AdminTheme.primaryTeal, AdminTheme.primaryTealLight],
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
    );
  }
}

class _SidebarFooter extends StatelessWidget {
  final bool isCollapsed;
  final ThemeData theme;

  const _SidebarFooter({required this.isCollapsed, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isCollapsed ? 8 : 14),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AdminTheme.outlineLight, width: 1),
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
    );
  }
}

/// Navigation item widget.
class _NavItem extends StatelessWidget {
  final String currentRoute;
  final bool isCollapsed;
  final IconData icon;
  final String label;
  final String route;
  final bool isActive;

  const _NavItem({
    required this.currentRoute,
    required this.isCollapsed,
    required this.icon,
    required this.label,
    required this.route,
    bool? isActive,
  }) : isActive = isActive ?? false;

  bool get active => isActive || currentRoute == route;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final margin = EdgeInsets.symmetric(horizontal: isCollapsed ? 8 : 12, vertical: 2);

    if (isCollapsed) {
      return Container(
        margin: margin,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => GoRouter.of(context).go(route),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: active
                    ? AdminTheme.primaryTeal.withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: active
                    ? Border.all(color: AdminTheme.primaryTeal.withOpacity(0.3), width: 1)
                    : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    color: active
                        ? AdminTheme.primaryTeal
                        : theme.colorScheme.onSurface.withOpacity(0.6),
                    size: 22,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label.split(' ').first,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                      color: active
                          ? AdminTheme.primaryTeal
                          : theme.colorScheme.onSurface.withOpacity(0.8),
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: margin,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => GoRouter.of(context).go(route),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: active
                  ? AdminTheme.primaryTeal.withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: active
                  ? Border.all(color: AdminTheme.primaryTeal.withOpacity(0.3), width: 1)
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: active
                      ? AdminTheme.primaryTeal
                      : theme.colorScheme.onSurface.withOpacity(0.6),
                  size: 22,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                      color: active
                          ? AdminTheme.primaryTeal
                          : theme.colorScheme.onSurface.withOpacity(0.8),
                    ),
                  ),
                ),
                if (active)
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

/// Navigation item with optional badge count.
class _SidebarNavItemWithBadge extends StatelessWidget {
  final String currentRoute;
  final bool isCollapsed;
  final IconData icon;
  final String label;
  final String route;
  final bool isActive;
  final int badgeCount;

  const _SidebarNavItemWithBadge({
    required this.currentRoute,
    required this.isCollapsed,
    required this.icon,
    required this.label,
    required this.route,
    this.isActive = false,
    this.badgeCount = 0,
  });

  bool get active => isActive || currentRoute == route;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final margin = EdgeInsets.symmetric(horizontal: isCollapsed ? 8 : 12, vertical: 2);

    if (isCollapsed) {
      return Container(
        margin: margin,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => GoRouter.of(context).go(route),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: active
                    ? AdminTheme.primaryTeal.withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: active
                    ? Border.all(color: AdminTheme.primaryTeal.withOpacity(0.3), width: 1)
                    : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        icon,
                        color: active
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
                      fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                      color: active
                          ? AdminTheme.primaryTeal
                          : theme.colorScheme.onSurface.withOpacity(0.8),
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: margin,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => GoRouter.of(context).go(route),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: active
                  ? AdminTheme.primaryTeal.withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: active
                  ? Border.all(color: AdminTheme.primaryTeal.withOpacity(0.3), width: 1)
                  : null,
            ),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      icon,
                      color: active
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
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                      color: active
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
                else if (active)
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
