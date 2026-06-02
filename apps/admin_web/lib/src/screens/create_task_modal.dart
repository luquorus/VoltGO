import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:shared_api/shared_api.dart';
import '../theme/admin_theme.dart';
import '../providers/battery_swap_trust_providers.dart';

/// Task type for create modal
enum TaskCreationType {
  chargingStation,
  batterySwap;

  String get displayName {
    switch (this) {
      case TaskCreationType.chargingStation:
        return 'Charging Station';
      case TaskCreationType.batterySwap:
        return 'Battery Swap';
    }
  }

  IconData get icon {
    switch (this) {
      case TaskCreationType.chargingStation:
        return Icons.ev_station;
      case TaskCreationType.batterySwap:
        return Icons.battery_charging_full;
    }
  }
}

/// Create Task Modal
class CreateTaskModal extends ConsumerStatefulWidget {
  const CreateTaskModal({super.key});

  @override
  ConsumerState<CreateTaskModal> createState() => _CreateTaskModalState();
}

class _CreateTaskModalState extends ConsumerState<CreateTaskModal> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _stationIdController = TextEditingController();
  final _changeRequestIdController = TextEditingController();
  double _priority = 3.0;
  DateTime? _slaDueAt;
  bool _isLoading = false;
  late TabController _tabController;
  TaskCreationType _selectedType = TaskCreationType.chargingStation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedType = _tabController.index == 0
              ? TaskCreationType.chargingStation
              : TaskCreationType.batterySwap;
        });
      }
    });
  }

  @override
  void dispose() {
    _stationIdController.dispose();
    _changeRequestIdController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _selectSlaDateTime() async {
    final now = DateTime.now();
    
    // Select date first
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _slaDueAt ?? now.add(const Duration(hours: 24)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'Select SLA Due Date',
    );
    
    if (pickedDate == null) return;
    
    // Then select time
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _slaDueAt != null
          ? TimeOfDay.fromDateTime(_slaDueAt!)
          : TimeOfDay.fromDateTime(now.add(const Duration(hours: 24))),
      helpText: 'Select SLA Due Time',
    );
    
    if (pickedTime == null) return;
    
    // Combine date and time
    final combinedDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    
    // Validate: cannot be in the past
    if (combinedDateTime.isBefore(now)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SLA due date cannot be in the past'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    
    setState(() {
      _slaDueAt = combinedDateTime;
    });
  }

  String _formatRemainingTime() {
    if (_slaDueAt == null) return '';
    
    final now = DateTime.now();
    final difference = _slaDueAt!.difference(now);
    
    if (difference.isNegative) return 'Overdue';
    
    final days = difference.inDays;
    final hours = difference.inHours.remainder(24);
    final minutes = difference.inMinutes.remainder(60);
    
    if (days > 0) {
      return '$days day${days > 1 ? 's' : ''}, $hours hour${hours != 1 ? 's' : ''} remaining';
    } else if (hours > 0) {
      return '$hours hour${hours != 1 ? 's' : ''}, $minutes minute${minutes != 1 ? 's' : ''} remaining';
    } else {
      return '$minutes minute${minutes != 1 ? 's' : ''} remaining';
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final factory = ref.read(apiClientFactoryProvider);
      if (factory == null) throw Exception('API client not initialized');

      // Format slaDueAt to ISO 8601 string
      String? slaDueAtString;
      if (_slaDueAt != null) {
        slaDueAtString = _slaDueAt!.toUtc().toIso8601String();
      }

      // Determine verification type based on selected tab
      final verificationType = _selectedType == TaskCreationType.batterySwap
          ? 'BATTERY_SWAP'
          : 'CHARGING';

      await factory.admin.createVerificationTask(
        stationId: _stationIdController.text.trim(),
        changeRequestId: _changeRequestIdController.text.trim().isEmpty
            ? null
            : _changeRequestIdController.text.trim(),
        priority: _priority.round(),
        slaDueAt: slaDueAtString,
        verificationType: verificationType,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task created successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${formatApiError(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      child: Container(
        width: 550,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title
            Row(
              children: [
                Icon(Icons.add_task, color: AdminTheme.primaryTeal),
                const SizedBox(width: 12),
                Text(
                  'Create Verification Task',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Type Tabs
            Container(
              decoration: BoxDecoration(
                color: AdminTheme.surfaceLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: AdminTheme.primaryTeal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: AdminTheme.primaryTeal,
                unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.6),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.ev_station, size: 18),
                        const SizedBox(width: 8),
                        const Text('Charging Station'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.battery_charging_full, size: 18),
                        const SizedBox(width: 8),
                        const Text('Battery Swap'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Form content in TabBarView
            Expanded(
              child: Form(
                key: _formKey,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Charging Station Tab
                    _buildChargingStationForm(theme),
                    // Battery Swap Tab
                    _buildBatterySwapForm(theme),
                  ],
                ),
              ),
            ),

            // Actions
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminTheme.primaryTeal,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Create'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChargingStationForm(ThemeData theme) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            label: 'Station ID *',
            controller: _stationIdController,
            enabled: !_isLoading,
            hint: 'Enter station UUID',
            validator: (v) => v?.isEmpty ?? true ? 'Station ID is required' : null,
          ),
          const SizedBox(height: 8),
          Text(
            'Applies to charging station verification tasks.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.65),
            ),
          ),
          const SizedBox(height: 16),

          AppTextField(
            label: 'Change Request ID (Optional)',
            controller: _changeRequestIdController,
            enabled: !_isLoading,
            hint: 'Enter change request UUID',
          ),
          const SizedBox(height: 16),

          _buildPrioritySection(theme),
          const SizedBox(height: 16),

          _buildSlaSection(theme),
        ],
      ),
    );
  }

  Widget _buildBatterySwapForm(ThemeData theme) {
    final stationId = _stationIdController.text.trim();
    final isValidId = stationId.length > 5;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            label: 'Battery Swap Station ID *',
            controller: _stationIdController,
            enabled: !_isLoading,
            hint: 'Enter battery swap station UUID',
            onChanged: (_) => setState(() {}),
            validator: (v) => v?.isEmpty ?? true ? 'Station ID is required' : null,
          ),
          const SizedBox(height: 8),
          Text(
            'Applies to battery swap station verification tasks. '
            'Trust score will be displayed for the selected station.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.65),
            ),
          ),
          const SizedBox(height: 16),

          AppTextField(
            label: 'Change Request ID (Optional)',
            controller: _changeRequestIdController,
            enabled: !_isLoading,
            hint: 'Enter battery swap change request UUID',
          ),
          const SizedBox(height: 16),

          // Info box for battery swap
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.amber.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Battery swap verification includes checks for battery inventory, '
                    'pile count, and slot count.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.amber.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Station snapshot preview
          if (isValidId) _buildStationSnapshotPreview(theme, stationId),
          if (isValidId) const SizedBox(height: 16),

          _buildPrioritySection(theme),
          const SizedBox(height: 16),

          _buildSlaSection(theme),
        ],
      ),
    );
  }

  Widget _buildStationSnapshotPreview(ThemeData theme, String stationId) {
    final trustAsync = ref.watch(batterySwapTrustProvider(stationId));

    return trustAsync.when(
      data: (trust) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified, color: Colors.green.shade700, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Station Trust Preview',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: trust.scoreColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: trust.scoreColor),
                  ),
                  child: Text(
                    '${trust.score} / 100',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: trust.scoreColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: trust.scoreColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(trust.levelIcon, size: 14, color: trust.scoreColor),
                      const SizedBox(width: 4),
                      Text(
                        trust.levelLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: trust.scoreColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (trust.verificationScore != null ||
                trust.completionScore != null ||
                trust.qualityScore != null ||
                trust.satisfactionScore != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (trust.verificationScore != null)
                    _buildComponentChip(theme, 'Verification', trust.verificationScore!),
                  if (trust.completionScore != null)
                    _buildComponentChip(theme, 'Completion', trust.completionScore!),
                  if (trust.qualityScore != null)
                    _buildComponentChip(theme, 'Quality', trust.qualityScore!),
                  if (trust.satisfactionScore != null)
                    _buildComponentChip(theme, 'Satisfaction', trust.satisfactionScore!),
                ],
              ),
            ],
          ],
        ),
      ),
      loading: () => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Text(
              'Loading station trust preview...',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
      error: (_, __) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.grey.shade600, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Station trust info unavailable (station may not have been verified yet)',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComponentChip(ThemeData theme, String label, int score) {
    final color = score >= 70
        ? Colors.green
        : score >= 40
            ? Colors.orange
            : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$label: $score',
        style: theme.textTheme.bodySmall?.copyWith(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildPrioritySection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Priority: ${_priority.round()}',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Slider(
          value: _priority,
          min: 1,
          max: 5,
          divisions: 4,
          label: _priority.round().toString(),
          onChanged: _isLoading
              ? null
              : (value) {
                  setState(() {
                    _priority = value;
                  });
                },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('1 (Low)', style: theme.textTheme.bodySmall),
            Text('5 (High)', style: theme.textTheme.bodySmall),
          ],
        ),
      ],
    );
  }

  Widget _buildSlaSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SLA Due Date & Time (Optional)',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _selectSlaDateTime,
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(
                  _slaDueAt == null
                      ? 'Select Date & Time'
                      : '${_slaDueAt!.day}/${_slaDueAt!.month}/${_slaDueAt!.year} ${_slaDueAt!.hour.toString().padLeft(2, '0')}:${_slaDueAt!.minute.toString().padLeft(2, '0')}',
                  style: theme.textTheme.bodyMedium,
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  side: BorderSide(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
            ),
            if (_slaDueAt != null) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.clear, size: 20),
                onPressed: _isLoading
                    ? null
                    : () {
                        setState(() {
                          _slaDueAt = null;
                        });
                      },
                tooltip: 'Clear',
                color: theme.colorScheme.error,
              ),
            ],
          ],
        ),
        if (_slaDueAt != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AdminTheme.surfaceLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AdminTheme.primaryTeal.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: AdminTheme.primaryTeal,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _formatRemainingTime(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AdminTheme.primaryTeal,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

