import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:shared_api/shared_api.dart';
import '../providers/loyalty_providers.dart';

/// Point History Screen - Paginated list of transactions
class PointHistoryScreen extends ConsumerStatefulWidget {
  const PointHistoryScreen({super.key});

  @override
  ConsumerState<PointHistoryScreen> createState() => _PointHistoryScreenState();
}

class _PointHistoryScreenState extends ConsumerState<PointHistoryScreen> {
  String? _selectedFilter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(pointHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Point History'),
      ),
      body: Column(
        children: [
          // Filter tabs
          _FilterTabs(
            selectedFilter: _selectedFilter,
            onFilterChanged: (filter) {
              setState(() => _selectedFilter = filter);
            },
          ),
          // Transaction list
          Expanded(
            child: _buildContent(state, theme),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(PointHistoryState state, ThemeData theme) {
    final filteredTransactions = _selectedFilter == null
        ? state.transactions
        : state.transactions
            .where((t) => t.source == _selectedFilter)
            .toList();

    if (state.isLoading && state.transactions.isEmpty) {
      return const LoadingState(message: 'Loading transactions...');
    }

    if (state.error != null && state.transactions.isEmpty) {
      return ErrorState(
        message: formatApiError(state.error!),
        onRetry: () => ref.read(pointHistoryProvider.notifier).refresh(),
      );
    }

    if (filteredTransactions.isEmpty) {
      return EmptyState(
        icon: FontAwesomeIcons.receipt,
        title: 'No transactions',
        message: _selectedFilter == null
            ? 'Your point history will appear here'
            : 'No ${_getFilterName(_selectedFilter!)} transactions',
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(pointHistoryProvider.notifier).refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filteredTransactions.length + (state.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == filteredTransactions.length) {
            // Load more trigger
            if (!state.isLoading) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ref.read(pointHistoryProvider.notifier).loadMore();
              });
            }
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final transaction = filteredTransactions[index];
          return _TransactionItem(transaction: transaction);
        },
      ),
    );
  }

  String _getFilterName(String filter) {
    switch (filter) {
      case 'BOOKING': return 'Charging';
      case 'BATTERY_SWAP': return 'Swap';
      case 'RATING':
      case 'RATING_WITH_COMMENT': return 'Rating';
      case 'CR_SUBMIT':
      case 'CR_PUBLISH': return 'Contribution';
      case 'REFERRAL': return 'Referral';
      case 'BADGE': return 'Badge';
      case 'ADMIN_ADJUST': return 'Admin';
      default: return filter;
    }
  }
}

/// Filter tabs
class _FilterTabs extends StatelessWidget {
  final String? selectedFilter;
  final ValueChanged<String?> onFilterChanged;

  const _FilterTabs({
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final filters = [
      (null, 'All'),
      ('BOOKING', 'Charging'),
      ('BATTERY_SWAP', 'Swap'),
      ('RATING', 'Ratings'),
      ('CR_SUBMIT', 'CRs'),
      ('REFERRAL', 'Referral'),
    ];

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (filter, label) = filters[index];
          final isSelected = selectedFilter == filter;

          return FilterChip(
            label: Text(label),
            selected: isSelected,
            onSelected: (_) => onFilterChanged(filter),
            selectedColor: theme.colorScheme.primary.withOpacity(0.2),
            checkmarkColor: theme.colorScheme.primary,
            labelStyle: TextStyle(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          );
        },
      ),
    );
  }
}

/// Transaction list item
class _TransactionItem extends StatelessWidget {
  final PointTransaction transaction;

  const _TransactionItem({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPositive = transaction.points > 0;
    final color = isPositive ? Colors.green : Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: FaIcon(
                _getIcon(transaction.source),
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.sourceDisplayName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    transaction.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(transaction.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isPositive ? '+' : ''}${transaction.points}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${transaction.balanceAfter} pts',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIcon(String source) {
    switch (source) {
      case 'BOOKING': return FontAwesomeIcons.bolt;
      case 'BATTERY_SWAP': return FontAwesomeIcons.batteryFull;
      case 'RATING':
      case 'RATING_WITH_COMMENT': return FontAwesomeIcons.star;
      case 'CR_SUBMIT': return FontAwesomeIcons.pen;
      case 'CR_PUBLISH': return FontAwesomeIcons.check;
      case 'REFERRAL': return FontAwesomeIcons.userPlus;
      case 'BADGE': return FontAwesomeIcons.medal;
      case 'ADMIN_ADJUST': return FontAwesomeIcons.userShield;
      default: return FontAwesomeIcons.coins;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return '${diff.inMinutes}m ago';
      }
      return '${diff.inHours}h ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
