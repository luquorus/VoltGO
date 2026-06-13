import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_api/shared_api.dart';
import '../../providers/loyalty_providers.dart';
import '../../theme/admin_theme.dart';
import '../../utils/responsive_utils.dart';
import '../../widgets/admin_scaffold.dart';

/// User Loyalty Detail Screen - View and manage a user's loyalty profile with real data
class UserLoyaltyDetailScreen extends ConsumerStatefulWidget {
  final String userId;

  const UserLoyaltyDetailScreen({
    super.key,
    required this.userId,
  });

  @override
  ConsumerState<UserLoyaltyDetailScreen> createState() => _UserLoyaltyDetailScreenState();
}

class _UserLoyaltyDetailScreenState extends ConsumerState<UserLoyaltyDetailScreen> {
  final _deltaController = TextEditingController();
  final _reasonController = TextEditingController();
  bool _isPositiveAdjustment = true;

  @override
  void dispose() {
    _deltaController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(adminLoyaltyProfileProvider(widget.userId));
    final historyState = ref.watch(adminPointHistoryProvider(widget.userId));
    final badgesAsync = ref.watch(adminBadgesProvider);
    final adjustState = ref.watch(adjustPointsProvider);

    return AdminScaffold(
      title: 'User Loyalty Details',
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(adminLoyaltyProfileProvider(widget.userId));
          ref.invalidate(adminPointHistoryProvider(widget.userId));
          ref.invalidate(adminBadgesProvider);
        },
        child: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text('Lỗi tải profile: $e'),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => ref.invalidate(adminLoyaltyProfileProvider(widget.userId)),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
          data: (profile) => SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back button
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => context.go('/loyalty/users'),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Back to Users'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Profile card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: AdminTheme.primaryTeal.withOpacity(0.1),
                          child: Icon(
                            Icons.person,
                            size: 40,
                            color: AdminTheme.primaryTeal,
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile.userId.substring(0, 16) + '...',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  _InfoChip(label: 'Level ${profile.level}', color: _getLevelColor(profile.level)),
                                  const SizedBox(width: 8),
                                  _InfoChip(label: profile.levelName, color: Colors.grey),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Stats cards
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Current Points',
                        value: _formatNumber(profile.currentPoints),
                        icon: Icons.stars,
                        color: AdminTheme.primaryTeal,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _StatCard(
                        title: 'Lifetime Points',
                        value: _formatNumber(profile.lifetimePoints),
                        icon: Icons.timeline,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _StatCard(
                        title: 'Total Bookings',
                        value: '${profile.totalBookings}',
                        icon: Icons.calendar_today,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _StatCard(
                        title: 'Total Swaps',
                        value: '${profile.totalSwaps}',
                        icon: Icons.battery_charging_full,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Total Ratings',
                        value: '${profile.totalRatings}',
                        icon: Icons.star,
                        color: Colors.amber,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _StatCard(
                        title: 'Contributions',
                        value: '${profile.totalContributions}',
                        icon: Icons.edit,
                        color: Colors.purple,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _StatCard(
                        title: 'Points to Next Level',
                        value: '${profile.pointsToNextLevel}',
                        icon: Icons.trending_up,
                        color: Colors.teal,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(child: SizedBox()),
                  ],
                ),
                const SizedBox(height: 24),
                // Badges section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Earned Badges',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        badgesAsync.when(
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (e, _) => Text('Lỗi: $e', style: TextStyle(color: Colors.red[600])),
                          data: (allBadges) {
                            final earned = allBadges.where((b) => b.isEarned).toList();
                            if (earned.isEmpty) {
                              return Text(
                                'Chưa có badge nào được earn',
                                style: TextStyle(color: Colors.grey[600]),
                              );
                            }
                            return Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: earned.map((badge) => _BadgeChip(
                                name: badge.name,
                                tier: badge.tier,
                              )).toList(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Point history
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Point History',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (historyState.isLoading)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (historyState.error != null)
                          Text('Lỗi: ${historyState.error}', style: TextStyle(color: Colors.red[600]))
                        else if (historyState.transactions.isEmpty)
                          Text('Chưa có transaction nào', style: TextStyle(color: Colors.grey[600]))
                        else
                          Column(
                            children: historyState.transactions.map((tx) => Column(
                              children: [
                                _TransactionRow(
                                  source: tx.sourceDisplayName,
                                  type: tx.type,
                                  points: tx.points,
                                  balanceAfter: tx.balanceAfter,
                                  createdAt: tx.createdAt,
                                ),
                                const Divider(),
                              ],
                            )).toList(),
                          ),
                        if (historyState.hasMore)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Center(
                              child: TextButton(
                                onPressed: () => ref.read(adminPointHistoryProvider(widget.userId).notifier).loadMore(),
                                child: const Text('Load more'),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Manual adjustment
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Manual Point Adjustment',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: AdminTheme.outlineLight),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  _AdjustmentTypeButton(
                                    label: 'Add',
                                    isSelected: _isPositiveAdjustment,
                                    color: Colors.green,
                                    onTap: () => setState(() => _isPositiveAdjustment = true),
                                  ),
                                  _AdjustmentTypeButton(
                                    label: 'Deduct',
                                    isSelected: !_isPositiveAdjustment,
                                    color: Colors.red,
                                    onTap: () => setState(() => _isPositiveAdjustment = false),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            SizedBox(
                              width: 150,
                              child: TextField(
                                controller: _deltaController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Points',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _reasonController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Reason',
                            border: OutlineInputBorder(),
                            hintText: 'Enter reason for adjustment...',
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (adjustState.success)
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle, color: Colors.green, size: 20),
                                const SizedBox(width: 8),
                                const Expanded(child: Text('Điều chỉnh thành công!', style: TextStyle(color: Colors.green))),
                              ],
                            ),
                          )
                        else if (adjustState.error != null)
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: Colors.red, size: 20),
                                const SizedBox(width: 8),
                                Expanded(child: Text('Lỗi: ${adjustState.error}', style: const TextStyle(color: Colors.red))),
                              ],
                            ),
                          ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: adjustState.isLoading ? null : _submitAdjustment,
                          icon: adjustState.isLoading
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.save),
                          label: Text(adjustState.isLoading ? 'Đang xử lý...' : 'Apply Adjustment'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AdminTheme.primaryTeal,
                            foregroundColor: Colors.white,
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
    );
  }

  Future<void> _submitAdjustment() async {
    final delta = int.tryParse(_deltaController.text);
    if (delta == null || delta <= 0) {
      _showSnackBar('Vui lòng nhập giá trị điểm hợp lệ (> 0)');
      return;
    }

    if (_reasonController.text.trim().isEmpty) {
      _showSnackBar('Vui lòng nhập lý do điều chỉnh');
      return;
    }

    final finalDelta = _isPositiveAdjustment ? delta : -delta;
    ref.read(adjustPointsProvider.notifier).reset();

    final success = await ref.read(adjustPointsProvider.notifier).adjustPoints(
      widget.userId,
      finalDelta,
      _reasonController.text.trim(),
    );

    if (success) {
      ref.invalidate(adminLoyaltyProfileProvider(widget.userId));
      ref.invalidate(adminPointHistoryProvider(widget.userId));
      _deltaController.clear();
      _reasonController.clear();
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _formatNumber(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  Color _getLevelColor(int level) {
    switch (level) {
      case 5: return Colors.purple.shade700;
      case 4: return Colors.amber.shade700;
      case 3: return Colors.amber.shade600;
      case 2: return Colors.blueGrey.shade400;
      default: return Colors.brown.shade400;
    }
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color color;

  const _InfoChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
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

class _BadgeChip extends StatelessWidget {
  final String name;
  final String tier;

  const _BadgeChip({required this.name, required this.tier});

  @override
  Widget build(BuildContext context) {
    final color = _getTierColor(tier);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.military_tech, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            name,
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

  Color _getTierColor(String tier) {
    switch (tier) {
      case 'GOLD': return Colors.amber.shade700;
      case 'SILVER': return Colors.blueGrey.shade400;
      case 'BRONZE': return Colors.brown.shade400;
      default: return Colors.grey;
    }
  }
}

class _TransactionRow extends StatelessWidget {
  final String source;
  final String type;
  final int points;
  final int balanceAfter;
  final DateTime createdAt;

  const _TransactionRow({
    required this.source,
    required this.type,
    required this.points,
    required this.balanceAfter,
    required this.createdAt,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPositive = points > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  source,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _formatDate(createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              type == 'EARN' ? 'Earned' : (type == 'REDEEM' ? 'Redeemed' : type),
              style: theme.textTheme.bodySmall,
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '${isPositive ? '+' : ''}$points pts',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isPositive ? Colors.green : Colors.red,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '$balanceAfter pts',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _AdjustmentTypeButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _AdjustmentTypeButton({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? color : Colors.grey,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
