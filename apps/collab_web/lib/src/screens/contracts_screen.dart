import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_ui/shared_ui.dart';
import '../widgets/dashboard_shell.dart';
import '../theme/collab_theme.dart';
import '../providers/task_providers.dart';
import '../models/contract.dart';

/// Contracts Screen - Shows collaborator contracts
class ContractsScreen extends ConsumerWidget {
  const ContractsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final contractsAsync = ref.watch(contractsProvider);

    return DashboardShell(
      title: 'Contracts',
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: contractsAsync.when(
          data: (contracts) {
            if (contracts.isEmpty) {
              return _buildEmptyState(theme);
            }
            return _buildContractsTable(context, theme, contracts);
          },
          loading: () => const LoadingState(message: 'Loading contracts...'),
          error: (error, stack) => ErrorState(
            message: error.toString(),
            onRetry: () {
              ref.invalidate(contractsProvider);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildContractsTable(
    BuildContext context,
    ThemeData theme,
    List<Contract> contracts,
  ) {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
            decoration: BoxDecoration(
              color: CollabTheme.surfaceLight,
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outline.withOpacity(0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Date Range',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Status',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Contracts List
          Expanded(
            child: ListView.separated(
              itemCount: contracts.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                color: theme.colorScheme.outline.withOpacity(0.2),
              ),
              itemBuilder: (context, index) {
                final contract = contracts[index];
                return _buildContractRow(context, theme, contract);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContractRow(
    BuildContext context,
    ThemeData theme,
    Contract contract,
  ) {
    final isActive = contract.active;
    
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 16,
      ),
      color: isActive
          ? CollabTheme.primaryGreenLight.withOpacity(0.1)
          : null,
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contract.dateRange,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatDate(contract.startDate)} - ${_formatDate(contract.endDate)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: StatusPill(
              label: isActive ? 'ACTIVE' : 'INACTIVE',
              color: isActive ? CollabTheme.primaryGreen : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: EmptyState(
        icon: Icons.description_outlined,
        message: 'No contracts found\n\nYou don\'t have any contracts yet.\nContact admin to create a contract.',
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
