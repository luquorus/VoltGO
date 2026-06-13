import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_auth/shared_auth.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_scaffold.dart';
import '../utils/responsive_utils.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authState = ref.watch(authStateProvider);
    
    return AdminScaffold(
      title: 'Dashboard',
      body: SingleChildScrollView(
        padding: EdgeInsets.all(responsivePadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: AdminTheme.outlineLight,
                  width: 1,
                ),
              ),
              child: Container(
                padding: EdgeInsets.all(isMobile(context) ? 20 : 32),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AdminTheme.primaryTeal.withOpacity(0.08),
                      AdminTheme.primaryTealLight.withOpacity(0.04),
                    ],
                  ),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 500) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AdminTheme.primaryTeal,
                                  AdminTheme.primaryTealLight,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AdminTheme.primaryTeal.withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.dashboard_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Welcome back!',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.6),
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            authState.email ?? 'Administrator',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AdminTheme.primaryTealDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Ready to manage the system',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.5),
                            ),
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AdminTheme.primaryTeal,
                                AdminTheme.primaryTealLight,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AdminTheme.primaryTeal.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.dashboard_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome back!',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color:
                                      theme.colorScheme.onSurface.withOpacity(0.6),
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                authState.email ?? 'Administrator',
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AdminTheme.primaryTealDark,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Ready to manage the system',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color:
                                      theme.colorScheme.onSurface.withOpacity(0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            SizedBox(height: isMobile(context) ? 20 : 32),

            // Quick Actions
            Text(
              'Quick actions',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AdminTheme.primaryTealDark,
                fontSize: isMobile(context) ? 16 : null,
              ),
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                // Calculate number of columns based on screen width
                final crossAxisCount = constraints.maxWidth > 1200
                    ? 3
                    : constraints.maxWidth > 800
                        ? 2
                        : 1;
                final cardWidth = (constraints.maxWidth - (crossAxisCount - 1) * 20) / crossAxisCount;
                
                return Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  children: [
                    _buildActionCard(
                      context,
                      theme,
                      width: cardWidth,
                      icon: Icons.description_rounded,
                      title: 'Change Requests',
                      description:
                          'Review and process change requests submitted by partners',
                      color: AdminTheme.primaryTeal,
                      onTap: () => context.push('/change-requests'),
                    ),
                    _buildActionCard(
                      context,
                      theme,
                      width: cardWidth,
                      icon: Icons.report_problem_rounded,
                      title: 'Issue Reports',
                      description:
                          'Handle EV user reports about charging stations',
                      color: AdminTheme.primaryTeal,
                      onTap: () => context.push('/issues'),
                    ),
                    _buildActionCard(
                      context,
                      theme,
                      width: cardWidth,
                      icon: Icons.verified_user_rounded,
                      title: 'Station Trust Scores',
                      description:
                          'View and recalculate trust scores for each charging station',
                      color: AdminTheme.primaryTeal,
                      onTap: () => context.push('/stations/trust'),
                    ),
                    _buildActionCard(
                      context,
                      theme,
                      width: cardWidth,
                      icon: Icons.people_rounded,
                      title: 'Collaborators',
                      description:
                          'Manage collaborator profiles and associated contracts',
                      color: AdminTheme.primaryTeal,
                      onTap: () => context.push('/collaborators'),
                    ),
                    _buildActionCard(
                      context,
                      theme,
                      width: cardWidth,
                      icon: Icons.assignment_rounded,
                      title: 'Verification Tasks',
                      description:
                          'Create and assign verification tasks to collaborators',
                      color: AdminTheme.primaryTeal,
                      onTap: () => context.push('/verification-tasks'),
                    ),
                    _buildActionCard(
                      context,
                      theme,
                      width: cardWidth,
                      icon: Icons.history_rounded,
                      title: 'Audit Logs',
                      description:
                          'Search and view audit logs to track system changes',
                      color: AdminTheme.primaryTeal,
                      onTap: () => context.push('/audit'),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    ThemeData theme, {
    required double width,
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isMobileCard = isMobile(context);
    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: EdgeInsets.all(isMobileCard ? 16 : 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AdminTheme.outlineLight,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(isMobileCard ? 10 : 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        color.withOpacity(0.15),
                        color.withOpacity(0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: isMobileCard ? 22 : 28,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AdminTheme.primaryTealDark,
                    fontSize: isMobileCard ? 14 : null,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                    height: 1.4,
                    fontSize: isMobileCard ? 11 : null,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: isMobileCard ? 12 : 16),
                Row(
                  children: [
                    Text(
                      'Open',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: color,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

