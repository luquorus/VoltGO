import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_ui/shared_ui.dart';
import '../widgets/dashboard_shell.dart';
import '../theme/collab_theme.dart';
import '../providers/task_providers.dart';
import '../models/collaborator_profile.dart';

/// Profile Screen - Shows user profile and settings
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(profileProvider);

    return DashboardShell(
      title: 'Profile',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: profileAsync.when(
              data: (profile) => _buildProfileCard(context, theme, profile),
              loading: () => const LoadingState(message: 'Loading profile...'),
              error: (error, stack) {
                // Check if 404 - profile not found
                final errorStr = error.toString().toLowerCase();
                if (errorStr.contains('404') || errorStr.contains('not found')) {
                  return _buildNotFoundState(theme);
                }
                return ErrorState(
                  message: error.toString(),
                  onRetry: () {
                    ref.invalidate(profileProvider);
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(
    BuildContext context,
    ThemeData theme,
    CollaboratorProfile profile,
  ) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            // Avatar
            CircleAvatar(
              radius: 60,
              backgroundColor: CollabTheme.primaryGreenLight,
              child: Text(
                profile.initial,
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Name
            Text(
              profile.displayName,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // Status Pill
            StatusPill(
              label: 'COLLABORATOR',
              color: CollabTheme.primaryGreen,
            ),
            const SizedBox(height: 32),

            // Info Card
            _buildInfoCard(context, theme, profile),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context,
    ThemeData theme,
    CollaboratorProfile profile,
  ) {
    return Card(
      margin: EdgeInsets.zero,
      color: CollabTheme.surfaceLight,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Personal Information',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // Name
            _buildInfoRow(
              context,
              theme,
              icon: Icons.person_outline,
              label: 'Name',
              value: profile.name ?? 'Not provided',
              canCopy: false,
            ),
            const SizedBox(height: 16),

            // Email
            _buildInfoRow(
              context,
              theme,
              icon: Icons.email_outlined,
              label: 'Email',
              value: profile.email,
              canCopy: true,
            ),
            const SizedBox(height: 16),

            // Phone
            _buildInfoRow(
              context,
              theme,
              icon: Icons.phone_outlined,
              label: 'Phone',
              value: profile.phone ?? 'Not provided',
              canCopy: profile.phone != null,
            ),
            const SizedBox(height: 16),

            // Location
            const Divider(),
            const SizedBox(height: 16),
            _buildLocationSection(context, theme, profile),

            // User Account ID (optional, small text)
            if (profile.userAccountId.isNotEmpty) ...[
              const Divider(),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.badge_outlined,
                    size: 18,
                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'User Account ID',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          profile.userAccountId,
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
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSection(
    BuildContext context,
    ThemeData theme,
    CollaboratorProfile profile,
  ) {
    final location = profile.location;
    final hasLocation = location != null && location.hasLocation;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.location_on_outlined,
              size: 20,
              color: hasLocation ? CollabTheme.primaryGreen : theme.colorScheme.onSurface.withOpacity(0.5),
            ),
            const SizedBox(width: 12),
            Text(
              'Current Location',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (hasLocation)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: CollabTheme.primaryGreenLight.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  location.source ?? 'MOBILE',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: CollabTheme.primaryGreen,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (hasLocation) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: CollabTheme.primaryGreenLight.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: CollabTheme.primaryGreen.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.gps_fixed, size: 16, color: CollabTheme.primaryGreen),
                    const SizedBox(width: 8),
                    Text(
                      '${location.lat!.toStringAsFixed(6)}, ${location.lng!.toStringAsFixed(6)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                if (location.updatedAt != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 14, color: theme.colorScheme.onSurface.withOpacity(0.5)),
                      const SizedBox(width: 6),
                      Text(
                        'Updated: ${_formatDateTime(location.updatedAt!)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.colorScheme.onSurface.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                Icon(Icons.location_off, size: 18, color: theme.colorScheme.onSurface.withOpacity(0.4)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No location set. Update your location from the mobile app.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildInfoRow(
    BuildContext context,
    ThemeData theme, {
    required IconData icon,
    required String label,
    required String value,
    required bool canCopy,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: theme.colorScheme.onSurface.withOpacity(0.5),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        if (canCopy)
          IconButton(
            icon: const Icon(Icons.copy_outlined, size: 20),
            tooltip: 'Copy to clipboard',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$label copied to clipboard'),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildNotFoundState(ThemeData theme) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_off_outlined,
              size: 64,
              color: theme.colorScheme.onSurface.withOpacity(0.4),
            ),
            const SizedBox(height: 24),
            Text(
              'Profile Not Found',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Profile not found, contact admin',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
