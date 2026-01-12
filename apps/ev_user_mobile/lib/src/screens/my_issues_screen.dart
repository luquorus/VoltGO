import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';
import '../providers/issue_providers.dart';
import '../widgets/report_issue_bottom_sheet.dart';

/// My Issues Screen
class MyIssuesScreen extends ConsumerStatefulWidget {
  const MyIssuesScreen({super.key});

  @override
  ConsumerState<MyIssuesScreen> createState() => _MyIssuesScreenState();
}

class _MyIssuesScreenState extends ConsumerState<MyIssuesScreen> {
  String? _selectedStatusFilter;

  @override
  void initState() {
    super.initState();
    // Load issues on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(myIssuesProvider.notifier).loadIssues();
    });
  }

  Future<void> _onRefresh() async {
    await ref.read(myIssuesProvider.notifier).refresh();
  }

  List<Map<String, dynamic>> _getFilteredIssues(
      List<Map<String, dynamic>> issues) {
    if (_selectedStatusFilter == null) {
      return issues;
    }
    return issues
        .where((issue) => issue['status'] == _selectedStatusFilter)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myIssuesProvider);
    final theme = Theme.of(context);
    final filteredIssues = _getFilteredIssues(state.issues);

    return AppScaffold(
      title: 'My Issues',
      actions: [
        IconButton(
          icon: const FaIcon(FontAwesomeIcons.xmark),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/profile');
            }
          },
          tooltip: 'Close',
        ),
      ],
      body: Column(
        children: [
          // Filter Section
          if (state.issues.isNotEmpty) _buildFilterSection(context, theme),

          // Content
          Expanded(
            child: RefreshIndicator(
              onRefresh: _onRefresh,
              child: _buildContent(context, state, theme, filteredIssues),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection(BuildContext context, ThemeData theme) {
    final tealColor = Colors.teal[800] ?? Colors.green[900] ?? Colors.teal;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          FaIcon(
            FontAwesomeIcons.filter,
            size: 16,
            color: tealColor,
          ),
          const SizedBox(width: 8),
          Text(
            'Filter:',
            style: theme.textTheme.labelLarge?.copyWith(
              color: tealColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButton<String>(
              value: _selectedStatusFilter,
              isExpanded: true,
              hint: Text(
                'All Statuses',
                style: TextStyle(color: Colors.grey[600]),
              ),
              icon: FaIcon(
                FontAwesomeIcons.chevronDown,
                size: 16,
                color: tealColor,
              ),
              iconSize: 16,
              style: TextStyle(color: tealColor),
              dropdownColor: Colors.white,
              underline: Container(
                height: 1,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey[300]!,
                      width: 1,
                    ),
                  ),
                ),
              ),
              items: [
                DropdownMenuItem<String>(
                  value: null,
                  child: Text(
                    'All Statuses',
                    style: TextStyle(color: tealColor),
                  ),
                ),
                ...IssueStatusLabels.labels.keys.map((status) {
                  return DropdownMenuItem<String>(
                    value: status,
                    child: Text(
                      IssueStatusLabels.getLabel(status),
                      style: TextStyle(color: tealColor),
                    ),
                  );
                }),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedStatusFilter = value;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    MyIssuesState state,
    ThemeData theme,
    List<Map<String, dynamic>> filteredIssues,
  ) {
    if (state.isLoading) {
      return const Center(child: LoadingState());
    }

    if (state.error != null) {
      return Center(
        child: ErrorState(
          message: state.error!.message,
          onRetry: () => _onRefresh(),
        ),
      );
    }

    if (filteredIssues.isEmpty) {
      return Center(
        child: EmptyState(
          message: _selectedStatusFilter == null
              ? 'No issues reported yet'
              : 'No issues with selected status',
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredIssues.length,
      itemBuilder: (context, index) {
        final issue = filteredIssues[index];
        return _buildIssueCard(context, theme, issue);
      },
    );
  }

  Widget _buildIssueCard(
    BuildContext context,
    ThemeData theme,
    Map<String, dynamic> issue,
  ) {
    final id = issue['id'] as String? ?? '';
    final stationName = issue['stationName'] as String? ?? 'Unknown Station';
    final category = issue['category'] as String? ?? 'OTHER';
    final description = issue['description'] as String? ?? '';
    final status = issue['status'] as String? ?? 'OPEN';
    final createdAt = issue['createdAt'] as String?;

    DateTime? createdAtDate;
    if (createdAt != null) {
      try {
        createdAtDate = DateTime.parse(createdAt);
      } catch (e) {
        // Ignore parse errors
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          // Could navigate to issue detail if needed
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Status + Category
              Row(
                children: [
                  StatusPill(
                    label: IssueStatusLabels.getLabel(status),
                    color: IssueStatusLabels.getStatusColor(status),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      IssueCategoryLabels.getLabel(category),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ),
                  if (createdAtDate != null)
                    Text(
                      _formatDate(createdAtDate),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 12),

              // Station Name
              Row(
                children: [
                  FaIcon(
                    FontAwesomeIcons.locationDot,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      stationName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Description
              Text(
                description,
                style: theme.textTheme.bodyMedium,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

