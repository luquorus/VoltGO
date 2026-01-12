import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/collab_theme.dart';

/// Sidebar navigation item
class SidebarItem {
  final String path;
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const SidebarItem({
    required this.path,
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}

/// Sidebar widget for desktop navigation
class CollabSidebar extends StatelessWidget {
  final String currentPath;
  final VoidCallback? onLogout;

  const CollabSidebar({
    super.key,
    required this.currentPath,
    this.onLogout,
  });

  static const List<SidebarItem> _taskItems = [
    SidebarItem(
      path: '/tasks',
      label: 'Tasks',
      icon: Icons.assignment_outlined,
      activeIcon: Icons.assignment,
    ),
    SidebarItem(
      path: '/tasks/history',
      label: 'History',
      icon: Icons.history_outlined,
      activeIcon: Icons.history,
    ),
    SidebarItem(
      path: '/tasks/kpi',
      label: 'KPI',
      icon: Icons.analytics_outlined,
      activeIcon: Icons.analytics,
    ),
  ];

  static const List<SidebarItem> _profileItems = [
    SidebarItem(
      path: '/me/profile',
      label: 'Profile',
      icon: Icons.person_outline,
      activeIcon: Icons.person,
    ),
    SidebarItem(
      path: '/me/contracts',
      label: 'Contracts',
      icon: Icons.description_outlined,
      activeIcon: Icons.description,
    ),
  ];

  bool _isActive(String path) {
    if (path == '/tasks') {
      return currentPath == '/tasks' || 
          (currentPath.startsWith('/tasks/') && 
           currentPath != '/tasks/history' && 
           currentPath != '/tasks/kpi');
    }
    return currentPath == path || currentPath.startsWith('$path/');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: CollabTheme.sidebarBackground,
        border: Border(
          right: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.3),
          ),
        ),
      ),
      child: Column(
        children: [
          // Logo & Title
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: CollabTheme.primaryGreenLight.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.bolt,
                    color: CollabTheme.primaryGreen,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'VoltGo',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: CollabTheme.primaryGreen,
                        ),
                      ),
                      Text(
                        'Collaborator',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Navigation Items
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tasks Section
                  _buildSectionHeader(context, 'TASKS'),
                  ..._taskItems.map((item) => _buildNavItem(context, item)),
                  
                  const SizedBox(height: 20),
                  
                  // Profile Section
                  _buildSectionHeader(context, 'ACCOUNT'),
                  ..._profileItems.map((item) => _buildNavItem(context, item)),
                ],
              ),
            ),
          ),

          // Logout Button
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onLogout,
                icon: const Icon(Icons.logout, size: 20),
                label: const Text('Logout'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                  side: BorderSide(color: theme.colorScheme.error.withOpacity(0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Text(
        title,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurface.withOpacity(0.5),
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, SidebarItem item) {
    final theme = Theme.of(context);
    final isActive = _isActive(item.path);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: isActive
            ? CollabTheme.sidebarActiveBackground
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () => context.go(item.path),
          borderRadius: BorderRadius.circular(10),
          hoverColor: CollabTheme.primaryGreenLight.withOpacity(0.08),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(
                  isActive ? item.activeIcon : item.icon,
                  size: 22,
                  color: isActive
                      ? CollabTheme.primaryGreen
                      : theme.colorScheme.onSurface.withOpacity(0.7),
                ),
                const SizedBox(width: 12),
                Text(
                  item.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    color: isActive
                        ? CollabTheme.primaryGreen
                        : theme.colorScheme.onSurface.withOpacity(0.85),
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

