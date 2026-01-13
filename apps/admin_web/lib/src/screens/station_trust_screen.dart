import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';
import '../models/station_trust.dart';
import '../providers/station_trust_providers.dart';
import '../repositories/station_trust_repository.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_scaffold.dart';

/// Station Trust Screen
/// 
/// Note: This page requires a stationId to be provided either via:
/// - Deep link: /stations/{stationId}/trust
/// - Manual input: Enter stationId in the input field
/// 
/// OpenAPI limitation: There is no endpoint to list stations for admin,
/// so this page operates only with a specific stationId.
class StationTrustScreen extends ConsumerStatefulWidget {
  final String? stationId; // Optional: from deep link

  const StationTrustScreen({
    super.key,
    this.stationId,
  });

  @override
  ConsumerState<StationTrustScreen> createState() => _StationTrustScreenState();
}

class _StationTrustScreenState extends ConsumerState<StationTrustScreen> {
  final _formKey = GlobalKey<FormState>();
  final _stationIdController = TextEditingController();
  String? _currentStationId;

  @override
  void initState() {
    super.initState();
    // If stationId provided via deep link, set it
    if (widget.stationId != null) {
      _currentStationId = widget.stationId;
      _stationIdController.text = widget.stationId!;
    }
  }

  @override
  void dispose() {
    _stationIdController.dispose();
    super.dispose();
  }

  void _handleLoadTrust() {
    if (!_formKey.currentState!.validate()) return;

    final stationId = _stationIdController.text.trim();
    setState(() {
      _currentStationId = stationId;
    });
    
    // Invalidate to trigger fetch
    ref.invalidate(stationTrustProvider(stationId));
  }

  Future<void> _handleRecalculate(String stationId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Recalculate Trust Score'),
        content: const Text(
          'Are you sure you want to recalculate the trust score for this station? '
          'This will update the score and breakdown based on current data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminTheme.primaryTeal,
              foregroundColor: Colors.white,
            ),
            child: const Text('Recalculate'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final repository = ref.read(stationTrustRepositoryProvider);
      await repository.recalculateStationTrust(stationId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trust score recalculated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Refresh data
      ref.invalidate(stationTrustProvider(stationId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AdminScaffold(
      title: 'Station Trust Score',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Input Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Station ID',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _stationIdController,
                              enabled: _currentStationId == null,
                              decoration: InputDecoration(
                                labelText: 'Station ID (UUID) *',
                                hintText: 'Enter station UUID...',
                                border: const OutlineInputBorder(),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Station ID is required';
                                }
                                // Basic UUID validation
                                final uuidPattern = RegExp(
                                  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
                                );
                                if (!uuidPattern.hasMatch(v.trim())) {
                                  return 'Please enter a valid UUID format';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: _currentStationId == null ? _handleLoadTrust : null,
                            icon: const Icon(Icons.search),
                            label: const Text('Load Trust'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AdminTheme.primaryTeal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_currentStationId != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Note: To view a different station, clear the current station ID first.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _currentStationId = null;
                              _stationIdController.clear();
                            });
                          },
                          icon: const Icon(Icons.clear),
                          label: const Text('Clear & Enter New Station ID'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Trust Score Display
            if (_currentStationId != null)
              _buildTrustScoreDisplay(theme, _currentStationId!),
          ],
        ),
      ),
    );
  }

  Widget _buildTrustScoreDisplay(ThemeData theme, String stationId) {
    final trustAsync = ref.watch(stationTrustProvider(stationId));

    return trustAsync.when(
      data: (trust) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Score Badge & Actions
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Trust Score',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _buildScoreBadge(theme, trust),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  trust.scoreLabel,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: _getScoreColor(theme, trust.score),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Last updated: ${_formatDateTime(trust.updatedAt)}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _handleRecalculate(stationId),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Recalculate Trust'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminTheme.primaryTeal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Breakdown Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Breakdown',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () {
                          final jsonStr = _formatBreakdownJson(trust.breakdown);
                          Clipboard.setData(ClipboardData(text: jsonStr));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Breakdown JSON copied to clipboard'),
                              duration: Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        tooltip: 'Copy JSON to clipboard',
                        color: AdminTheme.primaryTeal,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildBreakdownView(theme, trust.breakdown),
                ],
              ),
            ),
          ),
        ],
      ),
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: LoadingState(message: 'Loading trust score...'),
        ),
      ),
      error: (error, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: ErrorState(
            message: error.toString(),
            onRetry: () {
              ref.invalidate(stationTrustProvider(stationId));
            },
          ),
        ),
      ),
    );
  }

  Widget _buildScoreBadge(ThemeData theme, StationTrust trust) {
    final color = _getScoreColor(theme, trust.score);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 2),
      ),
      child: Text(
        trust.score.toStringAsFixed(1),
        style: theme.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Color _getScoreColor(ThemeData theme, double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    if (score >= 40) return Colors.deepOrange;
    return Colors.red;
  }

  Widget _buildBreakdownView(ThemeData theme, Map<String, dynamic> breakdown) {
    if (breakdown.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No breakdown data available',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminTheme.surfaceLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: _buildBreakdownTree(theme, breakdown, 0),
    );
  }

  Widget _buildBreakdownTree(ThemeData theme, Map<String, dynamic> data, int indentLevel) {
    final entries = data.entries.toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: entries.map((entry) {
        final key = entry.key;
        final value = entry.value;
        final indent = indentLevel * 24.0;

        return Padding(
          padding: EdgeInsets.only(left: indent, bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 200,
                child: Text(
                  key,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildValueWidget(theme, value, indentLevel + 1),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildValueWidget(ThemeData theme, dynamic value, int indentLevel) {
    if (value is Map<String, dynamic>) {
      return _buildBreakdownTree(theme, value, indentLevel);
    } else if (value is List) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: value.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return Padding(
            padding: EdgeInsets.only(left: indentLevel * 24.0, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '[$index]:',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildValueWidget(theme, item, indentLevel + 1),
                ),
              ],
            ),
          );
        }).toList(),
      );
    } else {
      return Text(
        value.toString(),
        style: theme.textTheme.bodyMedium,
      );
    }
  }

  String _formatBreakdownJson(Map<String, dynamic> breakdown) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(breakdown);
  }

  String _formatDateTime(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year;
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final second = dateTime.second.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute:$second';
  }
}

