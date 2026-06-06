import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_ui/shared_ui.dart';
import '../providers/contracts_provider.dart';
import '../models/contract.dart';
import '../widgets/main_scaffold.dart';

/// Contracts Screen - view collaborator contracts in profile
class ContractsScreen extends ConsumerStatefulWidget {
  const ContractsScreen({super.key});

  @override
  ConsumerState<ContractsScreen> createState() => _ContractsScreenState();
}

class _ContractsScreenState extends ConsumerState<ContractsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(contractsProvider.notifier).loadContracts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final contractsState = ref.watch(contractsProvider);

    return CollabMainScaffold(
      title: 'My Contracts',
      showBottomNav: false,
      child: RefreshIndicator(
        onRefresh: () async {
          ref.read(contractsProvider.notifier).loadContracts();
        },
        child: _buildBody(context, contractsState),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ContractsState state) {
    if (state.isLoading) {
      return const SkeletonList(count: 3);
    }

    if (state.error != null) {
      return ErrorState(
        message: state.error!.message,
        code: state.error!.code,
        traceId: state.error!.traceId,
        onRetry: () => ref.read(contractsProvider.notifier).loadContracts(),
      );
    }

    if (state.contracts.isEmpty) {
      return const EmptyState(
        title: 'No contracts',
        message: 'You don\'t have any contracts yet. Contact your administrator.',
        icon: Icons.description_outlined,
      );
    }

    // Separate active and inactive
    final activeContracts =
        state.contracts.where((c) => c.status == ContractStatus.active).toList();
    final inactiveContracts =
        state.contracts.where((c) => c.status != ContractStatus.active).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (activeContracts.isNotEmpty) ...[
          _SectionHeader(title: 'Active', count: activeContracts.length),
          const SizedBox(height: 8),
          ...activeContracts.map((c) => _ContractCard(contract: c)),
          const SizedBox(height: 24),
        ],
        if (inactiveContracts.isNotEmpty) ...[
          _SectionHeader(
              title: 'Inactive / Past', count: inactiveContracts.length),
          const SizedBox(height: 8),
          ...inactiveContracts.map((c) => _ContractCard(contract: c)),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;

  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            count.toString(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

class _ContractCard extends StatelessWidget {
  final Contract contract;

  const _ContractCard({required this.contract});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = contract.isActive;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Contract #${contract.id.substring(0, 8).toUpperCase()}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                StatusPill(
                  label: contract.status.displayName,
                  colorMapper: (label) {
                    switch (contract.status) {
                      case ContractStatus.active:
                        return Colors.green;
                      case ContractStatus.expired:
                        return Colors.grey;
                      case ContractStatus.terminated:
                        return Colors.red;
                    }
                  },
                ),
              ],
            ),
            if (contract.region != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    contract.region!,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
                const SizedBox(width: 4),
                Text(
                  '${_formatDate(contract.startDate)} - ${_formatDate(contract.endDate)}',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
            if (isActive) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, size: 14, color: Colors.green),
                    const SizedBox(width: 4),
                    Text(
                      _daysRemaining(contract.endDate),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (contract.note != null && contract.note!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Note',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      contract.note!,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _daysRemaining(DateTime endDate) {
    final now = DateTime.now();
    if (endDate.isBefore(now)) return 'Expired';
    final days = endDate.difference(now).inDays;
    if (days == 0) return 'Expires today';
    if (days == 1) return '1 day remaining';
    return '$days days remaining';
  }
}
