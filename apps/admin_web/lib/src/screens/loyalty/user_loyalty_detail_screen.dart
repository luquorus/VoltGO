import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/admin_theme.dart';
import '../../widgets/admin_scaffold.dart';

/// User Loyalty Detail Screen - View and manage a user's loyalty profile
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

    return AdminScaffold(
      title: 'User Loyalty Details',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
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
                            'user@example.com',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _InfoChip(label: 'Level 3', color: Colors.amber),
                              const SizedBox(width: 8),
                              _InfoChip(label: 'Silver Member', color: Colors.grey),
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
                    value: '850',
                    icon: Icons.stars,
                    color: AdminTheme.primaryTeal,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _StatCard(
                    title: 'Lifetime Points',
                    value: '1,250',
                    icon: Icons.timeline,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _StatCard(
                    title: 'Total Bookings',
                    value: '12',
                    icon: Icons.calendar_today,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _StatCard(
                    title: 'Total Swaps',
                    value: '5',
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
                    value: '8',
                    icon: Icons.star,
                    color: Colors.amber,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _StatCard(
                    title: 'Contributions',
                    value: '3',
                    icon: Icons.edit,
                    color: Colors.purple,
                  ),
                ),
                const SizedBox(width: 32),
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
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _BadgeChip(name: 'First Charge', tier: 'BRONZE'),
                        _BadgeChip(name: 'Explorer', tier: 'BRONZE'),
                        _BadgeChip(name: 'Swap Pilot', tier: 'BRONZE'),
                        _BadgeChip(name: 'Reviewer', tier: 'SILVER'),
                      ],
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
                    Text(
                      'Point History',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _TransactionRow(
                      source: 'Station Charging',
                      type: 'EARN',
                      points: '+30',
                      date: 'Today',
                      balance: '850',
                    ),
                    const Divider(),
                    _TransactionRow(
                      source: 'Station Rating',
                      type: 'EARN',
                      points: '+15',
                      date: 'Yesterday',
                      balance: '820',
                    ),
                    const Divider(),
                    _TransactionRow(
                      source: 'Battery Swap',
                      type: 'EARN',
                      points: '+30',
                      date: '3 days ago',
                      balance: '805',
                    ),
                    const Divider(),
                    _TransactionRow(
                      source: 'Admin Adjustment',
                      type: 'ADJUST',
                      points: '+50',
                      date: '1 week ago',
                      balance: '775',
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
                        // Type selector
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
                        // Points input
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
                    // Reason
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
                    ElevatedButton.icon(
                      onPressed: _submitAdjustment,
                      icon: const Icon(Icons.save),
                      label: const Text('Apply Adjustment'),
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
    );
  }

  void _submitAdjustment() {
    final delta = int.tryParse(_deltaController.text);
    if (delta == null || delta <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid point value')),
      );
      return;
    }

    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a reason for the adjustment')),
      );
      return;
    }

    final finalDelta = _isPositiveAdjustment ? delta : -delta;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Adjustment of ${_isPositiveAdjustment ? '+' : '-'}$delta points applied for ${widget.userId}',
        ),
      ),
    );

    _deltaController.clear();
    _reasonController.clear();
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
  final String points;
  final String date;
  final String balance;

  const _TransactionRow({
    required this.source,
    required this.type,
    required this.points,
    required this.date,
    required this.balance,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPositive = points.startsWith('+');

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
                  date,
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
              type,
              style: theme.textTheme.bodySmall,
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              points,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isPositive ? Colors.green : Colors.red,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '$balance pts',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
        ],
      ),
    );
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
