import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:shared_api/shared_api.dart';
import '../theme/admin_theme.dart';

/// Create Task Modal
class CreateTaskModal extends ConsumerStatefulWidget {
  const CreateTaskModal({super.key});

  @override
  ConsumerState<CreateTaskModal> createState() => _CreateTaskModalState();
}

class _CreateTaskModalState extends ConsumerState<CreateTaskModal> {
  final _formKey = GlobalKey<FormState>();
  final _stationIdController = TextEditingController();
  final _changeRequestIdController = TextEditingController();
  double _priority = 3.0;
  DateTime? _slaDueAt;
  bool _isLoading = false;

  @override
  void dispose() {
    _stationIdController.dispose();
    _changeRequestIdController.dispose();
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

      await factory.admin.createVerificationTask(
        stationId: _stationIdController.text.trim(),
        changeRequestId: _changeRequestIdController.text.trim().isEmpty
            ? null
            : _changeRequestIdController.text.trim(),
        priority: _priority.round(),
        slaDueAt: slaDueAtString,
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
            content: Text('Error: ${e.toString()}'),
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
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Create Verification Task',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              
              AppTextField(
                label: 'Station ID *',
                controller: _stationIdController,
                enabled: !_isLoading,
                hint: 'Enter station UUID',
                validator: (v) => v?.isEmpty ?? true ? 'Station ID is required' : null,
              ),
              const SizedBox(height: 16),
              
              AppTextField(
                label: 'Change Request ID (Optional)',
                controller: _changeRequestIdController,
                enabled: !_isLoading,
                hint: 'Enter change request UUID',
              ),
              const SizedBox(height: 16),
              
              // Priority Slider (1-5 as per backend)
              Column(
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
              ),
              const SizedBox(height: 16),
              
              // SLA Due Date & Time Picker
              Column(
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
              ),
              const SizedBox(height: 24),
              
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
      ),
    );
  }
}

