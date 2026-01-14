import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/admin_theme.dart';

class AdminSidebar extends StatelessWidget {
  final String currentRoute;

  const AdminSidebar({
    super.key,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      width: 260,
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
            padding: const EdgeInsets.all(24),
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
            child: Row(
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
                  icon: Icons.dashboard_rounded,
                  label: 'Dashboard',
                  route: '/home',
                  isActive: currentRoute == '/home',
                ),
                _buildNavItem(
                  context,
                  theme,
                  icon: Icons.description_rounded,
                  label: 'Change Requests',
                  route: '/change-requests',
                  isActive: currentRoute.startsWith('/change-requests'),
                ),
                _buildNavItem(
                  context,
                  theme,
                  icon: Icons.report_problem_rounded,
                  label: 'Reported Issues',
                  route: '/issues',
                  isActive: currentRoute.startsWith('/issues'),
                ),
                _buildNavItem(
                  context,
                  theme,
                  icon: Icons.ev_station,
                  label: 'Stations',
                  route: '/stations',
                  isActive: currentRoute.startsWith('/stations') && !currentRoute.startsWith('/stations/trust'),
                ),
                _buildNavItem(
                  context,
                  theme,
                  icon: Icons.verified_user_rounded,
                  label: 'Station Trust',
                  route: '/stations/trust',
                  isActive: currentRoute.startsWith('/stations/trust'),
                ),
                _buildNavItem(
                  context,
                  theme,
                  icon: Icons.people_rounded,
                  label: 'Collaborators',
                  route: '/collaborators',
                  isActive: currentRoute.startsWith('/collaborators'),
                ),
                _buildNavItem(
                  context,
                  theme,
                  icon: Icons.assignment_rounded,
                  label: 'Verification Tasks',
                  route: '/verification-tasks',
                  isActive: currentRoute.startsWith('/verification-tasks'),
                ),
                _buildNavItem(
                  context,
                  theme,
                  icon: Icons.history_rounded,
                  label: 'Audit Logs',
                  route: '/audit',
                  isActive: currentRoute.startsWith('/audit'),
                ),
                const Divider(height: 32, indent: 16, endIndent: 16),
                _buildNavItem(
                  context,
                  theme,
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
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: AdminTheme.outlineLight,
                  width: 1,
                ),
              ),
            ),
            child: Row(
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
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.go(route),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            child: Row(
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

