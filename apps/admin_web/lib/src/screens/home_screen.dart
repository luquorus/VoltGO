import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:shared_auth/shared_auth.dart';
import '../theme/admin_theme.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authState = ref.watch(authStateProvider);
    
    return AppScaffold(
      title: 'Admin Dashboard',
      actions: [
        IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () async {
            await ref.read(authStateNotifierProvider.notifier).logout();
            if (context.mounted) context.go('/login');
          },
        ),
      ],
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, ${authState.email ?? 'Admin'}!',
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Role: ${authState.role ?? 'Unknown'}',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Quick Actions
            Text(
              'Quick Actions',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildActionCard(
                  context,
                  theme,
                  icon: Icons.description,
                  title: 'Change Requests',
                  description: 'Review and manage change requests',
                  color: AdminTheme.primaryTeal,
                  onTap: () => context.push('/change-requests'),
                ),
                _buildActionCard(
                  context,
                  theme,
                  icon: Icons.assignment,
                  title: 'Verification Tasks',
                  description: 'Create and manage verification tasks',
                  color: AdminTheme.primaryTeal,
                  onTap: () => context.push('/verification-tasks'),
                ),
                _buildActionCard(
                  context,
                  theme,
                  icon: Icons.report_problem,
                  title: 'Reported Issues',
                  description: 'Manage EV user reported issues',
                  color: AdminTheme.primaryTeal,
                  onTap: () => context.push('/issues'),
                ),
                _buildActionCard(
                  context,
                  theme,
                  icon: Icons.verified_user,
                  title: 'Station Trust',
                  description: 'View and recalculate station trust scores',
                  color: AdminTheme.primaryTeal,
                  onTap: () => context.push('/stations/trust'),
                ),
                _buildActionCard(
                  context,
                  theme,
                  icon: Icons.history,
                  title: 'Audit Logs',
                  description: 'Query and view system audit logs',
                  color: AdminTheme.primaryTeal,
                  onTap: () => context.push('/audit'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

