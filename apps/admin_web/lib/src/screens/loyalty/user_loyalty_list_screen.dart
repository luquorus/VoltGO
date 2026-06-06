import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/admin_theme.dart';
import '../../widgets/admin_scaffold.dart';

/// User Loyalty List Screen - List of all users with their loyalty profiles
class UserLoyaltyListScreen extends ConsumerStatefulWidget {
  const UserLoyaltyListScreen({super.key});

  @override
  ConsumerState<UserLoyaltyListScreen> createState() => _UserLoyaltyListScreenState();
}

class _UserLoyaltyListScreenState extends ConsumerState<UserLoyaltyListScreen> {
  String _searchQuery = '';

  final List<_UserLoyaltyItem> _users = [
    _UserLoyaltyItem(
      userId: '1',
      email: 'user1@example.com',
      currentPoints: 1250,
      lifetimePoints: 1800,
      level: 3,
      totalRatings: 15,
      totalBookings: 25,
      totalSwaps: 8,
      lastActivity: 'Today',
    ),
    _UserLoyaltyItem(
      userId: '2',
      email: 'user2@example.com',
      currentPoints: 980,
      lifetimePoints: 1200,
      level: 2,
      totalRatings: 12,
      totalBookings: 18,
      totalSwaps: 5,
      lastActivity: 'Yesterday',
    ),
    _UserLoyaltyItem(
      userId: '3',
      email: 'user3@example.com',
      currentPoints: 750,
      lifetimePoints: 900,
      level: 2,
      totalRatings: 8,
      totalBookings: 12,
      totalSwaps: 3,
      lastActivity: '3 days ago',
    ),
    _UserLoyaltyItem(
      userId: '4',
      email: 'user4@example.com',
      currentPoints: 520,
      lifetimePoints: 600,
      level: 1,
      totalRatings: 5,
      totalBookings: 8,
      totalSwaps: 2,
      lastActivity: '1 week ago',
    ),
    _UserLoyaltyItem(
      userId: '5',
      email: 'user5@example.com',
      currentPoints: 300,
      lifetimePoints: 350,
      level: 1,
      totalRatings: 3,
      totalBookings: 5,
      totalSwaps: 1,
      lastActivity: '2 weeks ago',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AdminScaffold(
      title: 'User Points',
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                bottom: BorderSide(color: AdminTheme.outlineLight),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search by email...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                  ),
                ),
              ],
            ),
          ),
          // Table
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  child: Column(
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AdminTheme.primaryTeal.withOpacity(0.05),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: _HeaderCell(text: 'User', sortable: true),
                            ),
                            const Expanded(
                              flex: 1,
                              child: _HeaderCell(text: 'Level', sortable: true),
                            ),
                            const Expanded(
                              flex: 2,
                              child: _HeaderCell(text: 'Current Points', sortable: true),
                            ),
                            const Expanded(
                              flex: 2,
                              child: _HeaderCell(text: 'Lifetime Points', sortable: true),
                            ),
                            const Expanded(
                              flex: 1,
                              child: _HeaderCell(text: 'Ratings', sortable: true),
                            ),
                            const Expanded(
                              flex: 1,
                              child: _HeaderCell(text: 'Bookings', sortable: true),
                            ),
                            const Expanded(
                              flex: 1,
                              child: _HeaderCell(text: 'Swaps', sortable: true),
                            ),
                            const Expanded(
                              flex: 1,
                              child: _HeaderCell(text: 'Last Active', sortable: true),
                            ),
                            const SizedBox(width: 120, child: _HeaderCell(text: 'Actions')),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      // Rows
                      ..._filteredUsers().map((user) => _UserRow(
                        user: user,
                        onViewDetails: () => context.go('/loyalty/users/${user.userId}'),
                      )),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_UserLoyaltyItem> _filteredUsers() {
    if (_searchQuery.isEmpty) return _users;
    return _users.where((user) {
      return user.email.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }
}

class _UserLoyaltyItem {
  final String userId;
  final String email;
  final int currentPoints;
  final int lifetimePoints;
  final int level;
  final int totalRatings;
  final int totalBookings;
  final int totalSwaps;
  final String lastActivity;

  _UserLoyaltyItem({
    required this.userId,
    required this.email,
    required this.currentPoints,
    required this.lifetimePoints,
    required this.level,
    required this.totalRatings,
    required this.totalBookings,
    required this.totalSwaps,
    required this.lastActivity,
  });
}

class _HeaderCell extends StatelessWidget {
  final String text;
  final bool sortable;

  const _HeaderCell({required this.text, this.sortable = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        if (sortable) ...[
          const SizedBox(width: 4),
          const Icon(Icons.unfold_more, size: 16, color: Colors.grey),
        ],
      ],
    );
  }
}

class _UserRow extends StatelessWidget {
  final _UserLoyaltyItem user;
  final VoidCallback onViewDetails;

  const _UserRow({
    required this.user,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AdminTheme.outlineLight.withOpacity(0.5)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              user.email,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Expanded(
            flex: 1,
            child: _LevelBadge(level: user.level),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${user.currentPoints}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AdminTheme.primaryTeal,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${user.lifetimePoints}',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Expanded(
            flex: 1,
            child: Text('${user.totalRatings}'),
          ),
          Expanded(
            flex: 1,
            child: Text('${user.totalBookings}'),
          ),
          Expanded(
            flex: 1,
            child: Text('${user.totalSwaps}'),
          ),
          Expanded(
            flex: 1,
            child: Text(
              user.lastActivity,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
          SizedBox(
            width: 120,
            child: Row(
              children: [
                TextButton(
                  onPressed: onViewDetails,
                  child: const Text('Details'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  final int level;

  const _LevelBadge({required this.level});

  @override
  Widget build(BuildContext context) {
    final color = _getLevelColor(level);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            'Lv.$level',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Color _getLevelColor(int level) {
    switch (level) {
      case 3: return Colors.amber.shade700;
      case 2: return Colors.blueGrey.shade400;
      default: return Colors.brown.shade400;
    }
  }
}
