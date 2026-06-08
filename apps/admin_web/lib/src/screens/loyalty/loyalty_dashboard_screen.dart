import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/loyalty_providers.dart';
import '../../theme/admin_theme.dart';
import '../../widgets/admin_scaffold.dart';

/// Loyalty Dashboard Screen - Overview of loyalty system stats from real data
class LoyaltyDashboardScreen extends ConsumerWidget {
  const LoyaltyDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dashboardAsync = ref.watch(adminLoyaltyDashboardProvider);
    final usersState = ref.watch(adminLoyaltyUsersProvider);
    final ratingsState = ref.watch(adminRatingsProvider);

    return AdminScaffold(
      title: 'Loyalty Dashboard',
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(adminLoyaltyDashboardProvider);
          ref.read(adminLoyaltyUsersProvider.notifier).refresh();
          ref.read(adminRatingsProvider.notifier).refresh();
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stats row
              dashboardAsync.when(
                loading: () => Row(
                  children: [
                    for (int i = 0; i < 4; i++) ...[
                      Expanded(
                        child: Card(
                          child: Container(
                            height: 140,
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  width: 60,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  width: 100,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (i < 3) const SizedBox(width: 16),
                    ],
                  ],
                ),
                error: (e, _) => Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 12),
                      Expanded(child: Text('Lỗi tải dashboard: $e', style: const TextStyle(color: Colors.red))),
                    ],
                  ),
                ),
                data: (stats) => Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Total Points Issued',
                        value: _formatNumber(stats.totalPointsIssued),
                        icon: Icons.stars,
                        color: AdminTheme.primaryTeal,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _StatCard(
                        title: 'Active Users (30d)',
                        value: _formatNumber(stats.activeUsers),
                        icon: Icons.people,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _StatCard(
                        title: 'Active Ratings',
                        value: _formatNumber(stats.totalRatings),
                        icon: Icons.star,
                        color: Colors.amber,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _StatCard(
                        title: 'Total Users',
                        value: _formatNumber(usersState.users.length) + (usersState.hasMore ? '+' : ''),
                        //             ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ int  + String
                        icon: Icons.person,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Charts and tables row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Points trend placeholder (chart coming soon)
                  Expanded(
                    flex: 2,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Points Earned (Last 30 Days)',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Live',
                                    style: TextStyle(
                                      color: Colors.amber.shade700,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              height: 200,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.show_chart, size: 48, color: theme.colorScheme.onSurface.withOpacity(0.2)),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Chart coming soon',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Top users
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Top Users by Points',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => context.go('/loyalty/users'),
                                  child: const Text('View All'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (usersState.isLoading && usersState.users.isEmpty)
                              const Center(child: Padding(
                                padding: EdgeInsets.all(32),
                                child: CircularProgressIndicator(),
                              ))
                            else if (usersState.users.isEmpty)
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Column(
                                    children: [
                                      Icon(Icons.people_outline, size: 40, color: Colors.grey[400]),
                                      const SizedBox(height: 8),
                                      Text('Chưa có user nào', style: TextStyle(color: Colors.grey[600])),
                                    ],
                                  ),
                                ),
                              )
                            else
                              ...usersState.users.take(5).map((user) => Column(
                                children: [
                                  _TopUserRow(
                                    rank: usersState.users.indexOf(user) + 1,
                                    email: user.userId.substring(0, 8) + '...',
                                    points: user.currentPoints,
                                    onTap: () => context.go('/loyalty/users/${user.userId}'),
                                  ),
                                  const Divider(height: 1),
                                ],
                              )),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Recent ratings
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Recent Ratings',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.go('/loyalty/ratings'),
                            child: const Text('Moderate All'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (ratingsState.isLoading && ratingsState.ratings.isEmpty)
                        const Center(child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(),
                        ))
                      else if (ratingsState.ratings.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              children: [
                                Icon(Icons.rate_review_outlined, size: 40, color: Colors.grey[400]),
                                const SizedBox(height: 8),
                                Text('Chưa có rating nào', style: TextStyle(color: Colors.grey[600])),
                              ],
                            ),
                          ),
                        )
                      else
                        Column(
                          children: ratingsState.ratings.take(5).map((rating) {
                            return _RecentRatingRow(
                              station: rating.stationName,
                              userId: rating.id.substring(0, 8),
                              rating: rating.rating,
                              comment: rating.comment,
                              createdAt: rating.createdAt,
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopUserRow extends StatelessWidget {
  final int rank;
  final String email;
  final int points;
  final VoidCallback? onTap;

  const _TopUserRow({
    required this.rank,
    required this.email,
    required this.points,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: _getRankColor(rank).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$rank',
                  style: TextStyle(
                    color: _getRankColor(rank),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                email,
                style: theme.textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '$points pts',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1: return Colors.amber.shade700;
      case 2: return Colors.grey.shade600;
      case 3: return Colors.brown.shade400;
      default: return Colors.grey;
    }
  }
}

class _RecentRatingRow extends StatelessWidget {
  final String station;
  final String userId;
  final int rating;
  final String? comment;
  final DateTime createdAt;

  const _RecentRatingRow({
    required this.station,
    required this.userId,
    required this.rating,
    this.comment,
    required this.createdAt,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  station,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  userId,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return Icon(
                  index < rating ? Icons.star : Icons.star_border,
                  size: 16,
                  color: Colors.amber,
                );
              }),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              comment ?? 'No comment',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            _formatRelativeTime(createdAt),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  String _formatRelativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
