import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_ui/shared_ui.dart';
import '../models/audit_log.dart';
import '../providers/audit_log_providers.dart';
import '../theme/admin_theme.dart';
import '../utils/responsive_utils.dart';
import '../widgets/admin_scaffold.dart';

/// Change Request Audit Screen
/// Shows audit logs for a specific change request
class ChangeRequestAuditScreen extends ConsumerStatefulWidget {
  const ChangeRequestAuditScreen({super.key});

  @override
  ConsumerState<ChangeRequestAuditScreen> createState() => _ChangeRequestAuditScreenState();
}

class _ChangeRequestAuditScreenState extends ConsumerState<ChangeRequestAuditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _changeRequestIdController = TextEditingController();
  String? _currentChangeRequestId;
  AuditLogResponse? _selectedLog;

  @override
  void dispose() {
    _changeRequestIdController.dispose();
    super.dispose();
  }

  void _handleLoadAuditLogs() {
    if (!_formKey.currentState!.validate()) return;

    final changeRequestId = _changeRequestIdController.text.trim();
    setState(() {
      _currentChangeRequestId = changeRequestId;
    });

    // Invalidate to trigger fetch
    if (_currentChangeRequestId != null) {
      ref.invalidate(changeRequestAuditLogsProvider(_currentChangeRequestId!));
    }
  }

  void _handleClear() {
    _changeRequestIdController.clear();
    setState(() {
      _currentChangeRequestId = null;
      _selectedLog = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AdminScaffold(
      title: 'Change Request Audit Logs',
      body: Padding(
        padding: EdgeInsets.all(responsivePadding(context)),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 800;
            return isNarrow
                ? Column(
                    children: [
                      _buildFormCard(theme),
                      const SizedBox(height: 16),
                      Expanded(child: _buildAuditContent(theme)),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(flex: 2, child: _buildFormCard(theme)),
                      const SizedBox(width: 16),
                      Expanded(flex: 3, child: _buildAuditContent(theme)),
                    ],
                  );
          },
        ),
      ),
    );
  }

  Widget _buildFormCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(responsivePadding(context) * 0.8),
        child: Form(
          key: _formKey,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Change Request ID (UUID)',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _changeRequestIdController,
                    decoration: const InputDecoration(
                      hintText: 'Enter change request UUID',
                      prefixIcon: Icon(Icons.description),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a change request ID';
                      }
                      // Basic UUID validation
                      final uuidRegex = RegExp(
                        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
                        caseSensitive: false,
                      );
                      if (!uuidRegex.hasMatch(value.trim())) {
                        return 'Please enter a valid UUID';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: _currentChangeRequestId != null
                      ? _handleClear
                      : null,
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _handleLoadAuditLogs,
                  icon: const Icon(Icons.search),
                  label: const Text('Load Audit Logs'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminTheme.primaryTeal,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            if (_currentChangeRequestId != null) ...[
              const SizedBox(height: 16),
              Text(
                'Note: To view a different change request, clear the current ID first.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAuditContent(ThemeData theme) {
    if (_currentChangeRequestId == null) {
      return Card(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.description_outlined,
                size: 64,
                color: theme.colorScheme.onSurface.withOpacity(0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'Enter a change request ID to view audit logs',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: Card(
            margin: EdgeInsets.zero,
            child: ref
                .watch(changeRequestAuditLogsProvider(_currentChangeRequestId!))
                .when(
              data: (logs) => _buildAuditLogsTable(context, theme, logs),
              loading: () => LoadingState(
                message: 'Loading audit logs...',
              ),
              error: (error, stack) => ErrorState(
                title: 'Could not load audit log',
                message: formatApiError(error),
                code: extractErrorCode(error),
                traceId: extractTraceId(error),
                onRetry: () {
                  ref.invalidate(
                    changeRequestAuditLogsProvider(_currentChangeRequestId!),
                  );
                },
              ),
            ),
          ),
        ),
        if (_selectedLog != null) ...[
          const SizedBox(height: 16),
          Container(
            height: 300,
            child: Card(
              margin: EdgeInsets.zero,
              child: _buildMetadataDrawer(theme, _selectedLog!),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAuditLogsTable(BuildContext context, ThemeData theme, List<AuditLogResponse> logs) {
    if (logs.isEmpty) {
      return EmptyState(
        icon: Icons.history_outlined,
        message: 'No audit logs found for this change request',
        action: OutlinedButton.icon(
          onPressed: () {
            if (_currentChangeRequestId != null) {
              ref.invalidate(
                changeRequestAuditLogsProvider(_currentChangeRequestId!),
              );
            }
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
        ),
      );
    }

    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

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
              return _buildAuditLogRow(theme, log, dateFormat);
            },
          ),
        ),

        // Footer
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
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Total: ${logs.length} audit log${logs.length != 1 ? 's' : ''}',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAuditLogRow(
    ThemeData theme,
    AuditLogResponse log,
    DateFormat dateFormat,
  ) {
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

