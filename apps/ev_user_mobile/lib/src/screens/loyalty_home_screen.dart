import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_ui/shared_ui.dart';
import '../providers/loyalty_providers.dart';
import '../widgets/main_scaffold.dart';
import 'package:shared_api/shared_api.dart';

/// Loyalty Home Screen - Main rewards hub
class LoyaltyHomeScreen extends ConsumerWidget {
  const LoyaltyHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(loyaltyProfileProvider);
    final eligibleAsync = ref.watch(eligibleStationsForRatingProvider);
    final badgesAsync = ref.watch(myBadgesProvider);

    return MainScaffold(
      title: 'Rewards',
      actions: [
        IconButton(
          icon: const FaIcon(FontAwesomeIcons.clockRotateLeft),
          onPressed: () => context.push('/loyalty/points'),
          tooltip: 'Point History',
        ),
      ],
      child: profileAsync.when(
        loading: () => const LoadingState(message: 'Loading your rewards...'),
        error: (e, _) => ErrorState(
          message: formatApiError(e),
          onRetry: () => ref.invalidate(loyaltyProfileProvider),
        ),
        data: (profile) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(loyaltyProfileProvider);
            ref.invalidate(eligibleStationsForRatingProvider);
            ref.invalidate(myBadgesProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _PointsCard(profile: profile),
              const SizedBox(height: 16),
              _LevelProgressCard(profile: profile),
              const SizedBox(height: 16),
              _EligibleRatingSection(eligibleStations: eligibleAsync),
              const SizedBox(height: 16),
              _BadgeSection(badges: badgesAsync, earnedBadges: profile.badges),
              const SizedBox(height: 16),
              _QuickActions(profile: profile),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// Points display card
class _PointsCard extends StatelessWidget {
  final LoyaltyUserProfile profile;

  const _PointsCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Current Points',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const FaIcon(FontAwesomeIcons.crown, color: Colors.amber, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'Level ${profile.level}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${profile.currentPoints}',
                style: theme.textTheme.displayMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'pts',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _StatItem(
                icon: FontAwesomeIcons.bolt,
                label: 'Lifetime',
                value: '${profile.lifetimePoints}',
              ),
              const SizedBox(width: 24),
              _StatItem(
                icon: FontAwesomeIcons.star,
                label: 'Ratings',
                value: '${profile.totalRatings}',
              ),
              const SizedBox(width: 24),
              _StatItem(
                icon: FontAwesomeIcons.calendarCheck,
                label: 'Bookings',
                value: '${profile.totalBookings}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            FaIcon(icon, size: 12, color: Colors.white.withOpacity(0.7)),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Level progress card
class _LevelProgressCard extends StatelessWidget {
  final LoyaltyUserProfile profile;

  const _LevelProgressCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = _calcProgress(profile.lifetimePoints, profile.level);
    final ptsEarned = profile.lifetimePoints;
    final ptsNeeded = profile.pointsNeededForNextLevel;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Next Level: ${_getNextLevelName(profile.level)}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${profile.pointsToNextLevel} pts to go',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$ptsEarned / $ptsNeeded pts',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getNextLevelName(int currentLevel) {
    switch (currentLevel) {
      case 1: return 'Silver';
      case 2: return 'Gold';
      case 3: return 'Platinum';
      case 4: return 'Diamond';
      case 5: return 'Master';
      default: return 'Max Level';
    }
  }
}

/// Level progress bar helper
double _calcProgress(int lifetimePoints, int level) {
  // LEVEL_THRESHOLDS: [0, 100, 500, 1500, 5000, 15000]
  // Level 1 = 0-99 pts, Level 2 = 100-499, Level 3 = 500-1499, ...
  const thresholds = [0, 100, 500, 1500, 5000, 15000];
  if (level <= 0 || level >= thresholds.length) return 0.0;
  final current = thresholds[level - 1];
  final next = thresholds[level];
  final range = next - current;
  if (range <= 0) return 0.0;
  final earned = lifetimePoints - current;
  return (earned / range).clamp(0.0, 1.0);
}

/// Eligible stations for rating section
class _EligibleRatingSection extends StatelessWidget {
  final AsyncValue<List<EligibleStationForRating>> eligibleStations;

  const _EligibleRatingSection({required this.eligibleStations});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Rate Stations',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (eligibleStations.hasValue && eligibleStations.value!.isNotEmpty)
              TextButton(
                onPressed: () {},
                child: const Text('See all'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        eligibleStations.when(
          loading: () => const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Could not load stations: ${formatApiError(e)}'),
            ),
          ),
          data: (stations) {
            if (stations.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      FaIcon(
                        FontAwesomeIcons.checkCircle,
                        size: 40,
                        color: theme.colorScheme.primary.withOpacity(0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No stations to rate yet',
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Complete a charging session to earn ratings',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            return SizedBox(
              height: 140,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: stations.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final station = stations[index];
                  return _EligibleStationCard(station: station);
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

class _EligibleStationCard extends StatelessWidget {
  final EligibleStationForRating station;

  const _EligibleStationCard({required this.station});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: FaIcon(
                  FontAwesomeIcons.chargingStation,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  station.sourceDisplayName,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            station.stationName,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.push(
                '/loyalty/rate/${station.stationId}',
                extra: {'eligibilityId': station.eligibilityId},
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              child: const Text('Rate'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge section
class _BadgeSection extends StatelessWidget {
  final AsyncValue<List<UserBadge>> badges;
  final List<UserBadge> earnedBadges;

  const _BadgeSection({
    required this.badges,
    required this.earnedBadges,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'My Badges',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            TextButton(
              onPressed: () => context.push('/loyalty/badges'),
              child: const Text('See all'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        badges.when(
          loading: () => const SizedBox(
            height: 80,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Could not load badges: ${formatApiError(e)}'),
            ),
          ),
          data: (badgeList) {
            if (badgeList.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      FaIcon(
                        FontAwesomeIcons.medal,
                        size: 24,
                        color: theme.colorScheme.onSurface.withOpacity(0.3),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No badges earned yet. Keep using VoltGo!',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: badgeList.length > 6 ? 6 : badgeList.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final badge = badgeList[index];
                  return _BadgeItem(badge: badge);
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

class _BadgeItem extends StatelessWidget {
  final UserBadge badge;

  const _BadgeItem({required this.badge});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tierColor = _getTierColor(badge.tier);

    return Container(
      width: 70,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: tierColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tierColor.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FaIcon(
            _getBadgeIcon(badge.icon),
            size: 24,
            color: tierColor,
          ),
          const SizedBox(height: 4),
          Text(
            badge.name,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Color _getTierColor(String tier) {
    switch (tier) {
      case 'GOLD': return Colors.amber;
      case 'SILVER': return Colors.grey;
      case 'BRONZE': return Colors.brown;
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

/// Quick actions section
class _QuickActions extends StatelessWidget {
  final LoyaltyUserProfile profile;

  const _QuickActions({required this.profile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        _ActionCard(
          icon: FontAwesomeIcons.clockRotateLeft,
          title: 'Point History',
          subtitle: 'View all your point transactions',
          onTap: () => context.push('/loyalty/points'),
        ),
        const SizedBox(height: 8),
        _ActionCard(
          icon: FontAwesomeIcons.medal,
          title: 'Badge Collection',
          subtitle: '${profile.badges.length} badges earned',
          onTap: () => context.push('/loyalty/badges'),
        ),
        const SizedBox(height: 8),
        _ActionCard(
          icon: FontAwesomeIcons.userPlus,
          title: 'Refer a Friend',
          subtitle: 'Earn 50 points per referral',
          onTap: () => context.push('/loyalty/referral'),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: FaIcon(icon, color: theme.colorScheme.primary),
        ),
        title: Text(title),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        trailing: FaIcon(
          FontAwesomeIcons.chevronRight,
          size: 14,
          color: theme.colorScheme.onSurface.withOpacity(0.4),
        ),
        onTap: onTap,
      ),
    );
  }
}
