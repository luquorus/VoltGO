import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:shared_api/shared_api.dart';
import '../providers/loyalty_providers.dart';

/// Badge Collection Screen - Grid of badges with progress
class BadgeCollectionScreen extends ConsumerWidget {
  const BadgeCollectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earnedAsync = ref.watch(myBadgesProvider);
    final availableAsync = ref.watch(availableBadgesProvider);
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Badges'),
          bottom: TabBar(
            tabs: [
              Tab(text: 'Earned'),
              Tab(text: 'Available'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Earned tab
            earnedAsync.when(
              loading: () => const LoadingState(message: 'Loading badges...'),
              error: (e, _) => ErrorState(
                message: formatApiError(e),
                onRetry: () => ref.invalidate(myBadgesProvider),
              ),
              data: (badges) => _EarnedBadgesList(badges: badges),
            ),
            // Available tab
            availableAsync.when(
              loading: () => const LoadingState(message: 'Loading badges...'),
              error: (e, _) => ErrorState(
                message: formatApiError(e),
                onRetry: () => ref.invalidate(availableBadgesProvider),
              ),
              data: (badges) => _AvailableBadgesList(badges: badges),
            ),
          ],
        ),
      ),
    );
  }
}

/// Earned badges list
class _EarnedBadgesList extends StatelessWidget {
  final List<UserBadge> badges;

  const _EarnedBadgesList({required this.badges});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (badges.isEmpty) {
      return EmptyState(
        icon: FontAwesomeIcons.medal,
        title: 'No badges yet',
        message: 'Complete activities to earn badges and unlock rewards',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: badges.length,
      itemBuilder: (context, index) {
        final badge = badges[index];
        return _EarnedBadgeCard(badge: badge);
      },
    );
  }
}

class _EarnedBadgeCard extends StatelessWidget {
  final UserBadge badge;

  const _EarnedBadgeCard({required this.badge});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tierColor = _getTierColor(badge.tier);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: tierColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: tierColor.withOpacity(0.3), width: 2),
              ),
              child: Center(
                child: FaIcon(
                  _getBadgeIcon(badge.icon),
                  size: 28,
                  color: tierColor,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          badge.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: tierColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          badge.tier,
                          style: TextStyle(
                            color: tierColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    badge.description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      FaIcon(
                        FontAwesomeIcons.calendar,
                        size: 12,
                        color: theme.colorScheme.onSurface.withOpacity(0.4),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Earned on ${_formatDate(badge.earnedAt)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getTierColor(String tier) {
    switch (tier) {
      case 'GOLD': return Colors.amber.shade700;
      case 'SILVER': return Colors.blueGrey.shade400;
      case 'BRONZE': return Colors.brown.shade400;
      default: return Colors.grey;
    }
  }

  IconData _getBadgeIcon(String icon) {
    switch (icon) {
      case 'bolt': return FontAwesomeIcons.bolt;
      case 'explore': return FontAwesomeIcons.compass;
      case 'star': return FontAwesomeIcons.star;
      case 'battery_charging_full': return FontAwesomeIcons.batteryFull;
      case 'edit': return FontAwesomeIcons.pen;
      case 'military_tech': return FontAwesomeIcons.award;
      case 'rate_review': return FontAwesomeIcons.starHalfStroke;
      case 'reviews': return FontAwesomeIcons.star;
      case 'workspace_premium': return FontAwesomeIcons.crown;
      default: return FontAwesomeIcons.medal;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

/// Available badges list (with progress)
class _AvailableBadgesList extends StatelessWidget {
  final List<BadgeWithProgress> badges;

  const _AvailableBadgesList({required this.badges});

  @override
  Widget build(BuildContext context) {
    if (badges.isEmpty) {
      return EmptyState(
        icon: FontAwesomeIcons.medal,
        title: 'No available badges',
        message: 'Check back later for new achievements',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: badges.length,
      itemBuilder: (context, index) {
        final badge = badges[index];
        return _AvailableBadgeCard(badge: badge);
      },
    );
  }
}

class _AvailableBadgeCard extends StatelessWidget {
  final BadgeWithProgress badge;

  const _AvailableBadgeCard({required this.badge});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tierColor = _getTierColor(badge.tier);
    final progress = badge.progressPercent;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: badge.isEarned ? null : theme.colorScheme.surface,
      child: Opacity(
        opacity: badge.isEarned ? 1.0 : 0.8,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: tierColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: tierColor.withOpacity(badge.isEarned ? 0.5 : 0.2),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: badge.isEarned
                          ? FaIcon(
                              FontAwesomeIcons.check,
                              size: 24,
                              color: tierColor,
                            )
                          : FaIcon(
                              _getBadgeIcon(badge.icon),
                              size: 28,
                              color: tierColor,
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            badge.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (badge.pointsBonus > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '+${badge.pointsBonus} pts',
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      badge.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (!badge.isEarned) ...[
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 6,
                                backgroundColor: tierColor.withOpacity(0.1),
                                valueColor: AlwaysStoppedAnimation(tierColor),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${badge.currentValue}/${badge.targetValue}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: tierColor,
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Row(
                        children: [
                          FaIcon(
                            FontAwesomeIcons.checkCircle,
                            size: 14,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Earned',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getTierColor(String tier) {
    switch (tier) {
      case 'GOLD': return Colors.amber.shade700;
      case 'SILVER': return Colors.blueGrey.shade400;
      case 'BRONZE': return Colors.brown.shade400;
      default: return Colors.grey;
    }
  }

  IconData _getBadgeIcon(String icon) {
    switch (icon) {
      case 'bolt': return FontAwesomeIcons.bolt;
      case 'explore': return FontAwesomeIcons.compass;
      case 'star': return FontAwesomeIcons.star;
      case 'battery_charging_full': return FontAwesomeIcons.batteryFull;
      case 'edit': return FontAwesomeIcons.pen;
      case 'military_tech': return FontAwesomeIcons.award;
      case 'rate_review': return FontAwesomeIcons.starHalfStroke;
      case 'reviews': return FontAwesomeIcons.star;
      case 'workspace_premium': return FontAwesomeIcons.crown;
      default: return FontAwesomeIcons.medal;
    }
  }
}
