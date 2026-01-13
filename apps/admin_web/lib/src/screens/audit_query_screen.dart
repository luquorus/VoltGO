import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_ui/shared_ui.dart';
import '../models/audit_log.dart';
import '../models/pagination_response.dart';
import '../providers/audit_log_providers.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_scaffold.dart';
import 'dart:convert';

/// Audit Query Screen
/// Main audit log query page with filters and pagination
class AuditQueryScreen extends ConsumerStatefulWidget {
  const AuditQueryScreen({super.key});

  @override
  ConsumerState<AuditQueryScreen> createState() => _AuditQueryScreenState();
}

class _AuditQueryScreenState extends ConsumerState<AuditQueryScreen> {
  String _entityType = '';
  final _entityIdController = TextEditingController();
  DateTime? _fromDate;
  DateTime? _toDate;
  final List<String> _entityTypeSuggestions = [
    'CHANGE_REQUEST',
    'STATION',
    'STATION_VERSION',
  ];
  AuditLogResponse? _selectedLog;

  @override
  void dispose() {
    _entityIdController.dispose();
    super.dispose();
  }

  void _handleApplyFilters() {
    final filters = ref.read(auditQueryFiltersProvider);
    ref.read(auditQueryFiltersProvider.notifier).state = AuditQueryFilters(
      entityType: _entityType.trim().isEmpty ? null : _entityType.trim(),
      entityId: _entityIdController.text.trim().isEmpty 
          ? null 
          : _entityIdController.text.trim(),
      from: _fromDate,
      to: _toDate,
      page: 0, // Reset to first page when applying filters
      size: filters.size,
    );
  }

  void _handleClearFilters() {
    setState(() {
      _entityType = '';
      _fromDate = null;
      _toDate = null;
    });
    _entityIdController.clear();
    ref.read(auditQueryFiltersProvider.notifier).state = AuditQueryFilters(
      page: 0,
      size: 20,
    );
  }

  void _handlePageChange(int newPage) {
    final filters = ref.read(auditQueryFiltersProvider);
    ref.read(auditQueryFiltersProvider.notifier).state = filters.copyWith(page: newPage);
  }

  Future<void> _selectFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_fromDate ?? DateTime.now()),
      );
      if (time != null) {
        setState(() {
          // Create DateTime in local timezone, will be converted to UTC when formatting
          _fromDate = DateTime(
            picked.year,
            picked.month,
            picked.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _selectToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate ?? DateTime.now(),
      firstDate: _fromDate ?? DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_toDate ?? DateTime.now()),
      );
      if (time != null) {
        setState(() {
          // Create DateTime in local timezone, will be converted to UTC when formatting
          _toDate = DateTime(
            picked.year,
            picked.month,
            picked.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filters = ref.watch(auditQueryFiltersProvider);
    final auditLogsAsync = ref.watch(auditLogsQueryProvider(filters));

    return AdminScaffold(
      title: 'Audit Logs',
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            // Main content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Filter Panel
                  _buildFilterPanel(theme),
                  const SizedBox(height: 24),

                  // Audit Logs Table
                  Expanded(
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: auditLogsAsync.when(
                        data: (pagination) => _buildAuditLogsTable(theme, pagination),
                        loading: () => LoadingState(message: 'Loading audit logs...'),
                        error: (error, stack) => ErrorState(
                          message: error.toString(),
                          onRetry: () {
                            ref.invalidate(auditLogsQueryProvider(filters));
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Metadata Drawer
            if (_selectedLog != null)
              Container(
                width: 400,
                margin: const EdgeInsets.only(left: 16),
                child: Card(
                  margin: EdgeInsets.zero,
                  child: _buildMetadataDrawer(theme, _selectedLog!),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPanel(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filters',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Entity Type
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Entity Type',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Autocomplete<String>(
                      optionsBuilder: (textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return _entityTypeSuggestions;
                        }
                        return _entityTypeSuggestions.where((suggestion) =>
                            suggestion.toLowerCase().contains(
                                  textEditingValue.text.toLowerCase(),
                                ));
                      },
                      onSelected: (value) {
                        setState(() {
                          _entityType = value;
                        });
                      },
                      fieldViewBuilder: (
                        context,
                        textEditingController,
                        focusNode,
                        onFieldSubmitted,
                      ) {
                        // Only set initial value if different
                        if (textEditingController.text != _entityType) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (textEditingController.text != _entityType) {
                              textEditingController.text = _entityType;
                            }
                          });
                        }
                        return TextField(
                          controller: textEditingController,
                          focusNode: focusNode,
                          onChanged: (value) {
                            setState(() {
                              _entityType = value;
                            });
                          },
                          decoration: const InputDecoration(
                            hintText: 'e.g., CHANGE_REQUEST, STATION',
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Entity ID
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Entity ID (UUID)',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _entityIdController,
                      decoration: const InputDecoration(
                        hintText: 'Enter UUID',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // From Date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'From Date',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _selectFromDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: theme.colorScheme.outline.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 20,
                              color: theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _fromDate != null
                                    ? DateFormat('yyyy-MM-dd HH:mm').format(_fromDate!)
                                    : 'Select date',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                            if (_fromDate != null)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  setState(() {
                                    _fromDate = null;
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // To Date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'To Date',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _selectToDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: theme.colorScheme.outline.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 20,
                              color: theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _toDate != null
                                    ? DateFormat('yyyy-MM-dd HH:mm').format(_toDate!)
                                    : 'Select date',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                            if (_toDate != null)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  setState(() {
                                    _toDate = null;
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: _handleClearFilters,
                icon: const Icon(Icons.clear),
                label: const Text('Clear'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _handleApplyFilters,
                icon: const Icon(Icons.search),
                label: const Text('Apply Filters'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminTheme.primaryTeal,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAuditLogsTable(
    ThemeData theme,
    PaginationResponse<AuditLogResponse> pagination,
  ) {
    final logs = pagination.content;

    if (logs.isEmpty) {
      return EmptyState(
        icon: Icons.history_outlined,
        message: 'No audit logs found',
        action: OutlinedButton.icon(
          onPressed: () {
            ref.invalidate(auditLogsQueryProvider(ref.read(auditQueryFiltersProvider)));
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
        ),
      );
    }

    return Column(
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: AdminTheme.surfaceLight,
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
                  'Created At',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Action',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Actor Role',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Entity Type',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Entity ID',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Table Body
        Expanded(
          child: ListView.separated(
            itemCount: logs.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: theme.colorScheme.outline.withOpacity(0.1),
            ),
            itemBuilder: (context, index) {
              final log = logs[index];
              return _buildAuditLogRow(theme, log);
            },
          ),
        ),

        // Pagination
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AdminTheme.surfaceLight,
            border: Border(
              top: BorderSide(
                color: theme.colorScheme.outline.withOpacity(0.2),
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Showing ${logs.length} of ${pagination.totalElements} entries',
                style: theme.textTheme.bodySmall,
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: pagination.first
                        ? null
                        : () => _handlePageChange(pagination.page - 1),
                  ),
                  Text(
                    'Page ${pagination.page + 1} of ${pagination.totalPages}',
                    style: theme.textTheme.bodyMedium,
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: pagination.last
                        ? null
                        : () => _handlePageChange(pagination.page + 1),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAuditLogRow(ThemeData theme, AuditLogResponse log) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    return InkWell(
      onTap: () {
        setState(() {
          _selectedLog = log;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        color: _selectedLog?.id == log.id
            ? theme.colorScheme.primaryContainer.withOpacity(0.3)
            : null,
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                dateFormat.format(log.createdAt),
                style: theme.textTheme.bodyMedium,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                log.action,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                log.actorRole,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                log.entityType,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                log.entityId ?? '-',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataDrawer(ThemeData theme, AuditLogResponse log) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AdminTheme.surfaceLight,
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outline.withOpacity(0.2),
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Audit Log Details',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _selectedLog = null;
                  });
                },
              ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow(theme, 'ID', log.id, isMonospace: true),
                _buildDetailRow(theme, 'Created At', dateFormat.format(log.createdAt)),
                _buildDetailRow(theme, 'Action', log.action),
                _buildDetailRow(theme, 'Entity Type', log.entityType),
                _buildDetailRow(
                  theme,
                  'Entity ID',
                  log.entityId ?? '-',
                  isMonospace: true,
                ),
                _buildDetailRow(theme, 'Actor ID', log.actorId, isMonospace: true),
                _buildDetailRow(theme, 'Actor Role', log.actorRole),
                if (log.actorEmail != null)
                  _buildDetailRow(theme, 'Actor Email', log.actorEmail!),
                const SizedBox(height: 16),
                Divider(color: theme.colorScheme.outline.withOpacity(0.2)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Metadata',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy),
                      tooltip: 'Copy JSON',
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: log.formattedMetadata),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Metadata copied to clipboard')),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AdminTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  child: SelectableText(
                    log.formattedMetadata,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(
    ThemeData theme,
    String label,
    String value, {
    bool isMonospace = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: isMonospace
                ? theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                  )
                : theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

