import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_api/shared_api.dart';
import '../../providers/loyalty_providers.dart';
import '../../theme/admin_theme.dart';
import '../../utils/responsive_utils.dart';
import '../../widgets/admin_scaffold.dart';

/// Re-export so widgets in this file can reference AdminLoyaltyUser
export '../../providers/loyalty_providers.dart' show AdminLoyaltyUser;

/// User Loyalty List Screen - Paginated list of all users with real loyalty data
class UserLoyaltyListScreen extends ConsumerStatefulWidget {
  const UserLoyaltyListScreen({super.key});

  @override
  ConsumerState<UserLoyaltyListScreen> createState() => _UserLoyaltyListScreenState();
}

class _UserLoyaltyListScreenState extends ConsumerState<UserLoyaltyListScreen> {
  String _searchQuery = '';
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(adminLoyaltyUsersProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final usersState = ref.watch(adminLoyaltyUsersProvider);
    final filteredUsers = _searchQuery.isEmpty
        ? usersState.users
        : usersState.users.where((u) {
            return u.userId.toLowerCase().contains(_searchQuery.toLowerCase());
          }).toList();

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
                      hintText: 'Search by user ID...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                if (usersState.isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                const SizedBox(width: 8),
                Text(
                  '${usersState.users.length}${usersState.hasMore ? '+' : ''} users',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => ref.read(adminLoyaltyUsersProvider.notifier).refresh(),
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ),
          // Table
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
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
                          children: const [
                            Expanded(
                              flex: 3,
                              child: _HeaderCell(text: 'User ID'),
                            ),
                            Expanded(
                              flex: 1,
                              child: _HeaderCell(text: 'Level'),
                            ),
                            Expanded(
                              flex: 2,
                              child: _HeaderCell(text: 'Current Points'),
                            ),
                            Expanded(
                              flex: 2,
                              child: _HeaderCell(text: 'Lifetime Points'),
                            ),
                            Expanded(
                              flex: 1,
                              child: _HeaderCell(text: 'Ratings'),
                            ),
                            Expanded(
                              flex: 1,
                              child: _HeaderCell(text: 'Bookings'),
                            ),
                            Expanded(
                              flex: 1,
                              child: _HeaderCell(text: 'Swaps'),
                            ),
                            SizedBox(width: 100, child: _HeaderCell(text: 'Actions')),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      // Loading indicator
                      if (usersState.isLoading && usersState.users.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(),
                        )
                      // Error
                      else if (usersState.error != null && usersState.users.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Icon(Icons.error_outline, size: 40, color: Colors.red[300]),
                              const SizedBox(height: 8),
                              Text('Lỗi: ${usersState.error}'),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () => ref.read(adminLoyaltyUsersProvider.notifier).refresh(),
                                child: const Text('Thử lại'),
                              ),
                            ],
                          ),
                        )
                      // Empty
                      else if (filteredUsers.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Icon(Icons.people_outline, size: 40, color: Colors.grey[400]),
                              const SizedBox(height: 8),
                              Text(
                                _searchQuery.isEmpty
                                    ? 'Chưa có user loyalty nào'
                                    : 'Không tìm thấy user',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        )
                      // Rows
                      else
                        ...filteredUsers.map((user) => _UserRow(
                          user: user,
                          onViewDetails: () => context.go('/loyalty/users/${user.userId}'),
                        )),
                      // Load more indicator
                      if (usersState.hasMore)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        ),
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
}

class _HeaderCell extends StatelessWidget {
  final String text;

  const _HeaderCell({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _UserRow extends StatelessWidget {
  final AdminLoyaltyUser user;
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
              user.userId,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                fontSize: 12,
              ),
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
          SizedBox(
            width: 100,
            child: TextButton(
              onPressed: onViewDetails,
              child: const Text('Details'),
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
