import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_ui/shared_ui.dart';
import '../providers/booking_providers.dart';

/// Create Booking Screen
class CreateBookingScreen extends ConsumerStatefulWidget {
  final String stationId;
  final String? stationName;

  const CreateBookingScreen({
    super.key,
    required this.stationId,
    this.stationName,
  });

  @override
  ConsumerState<CreateBookingScreen> createState() => _CreateBookingScreenState();
}

class _CreateBookingScreenState extends ConsumerState<CreateBookingScreen> {
  final _formKey = GlobalKey<FormState>();
  DateTime? _startTime;
  DateTime? _endTime;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppScaffold(
      title: 'Book a Slot',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Station info
              if (widget.stationName != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        FaIcon(
                          FontAwesomeIcons.locationDot,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.stationName!,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Start time
              Text(
                'Start Time',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _isLoading ? null : _selectStartTime,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.outline),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      FaIcon(
                        FontAwesomeIcons.calendar,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _startTime != null
                              ? '${_formatDate(_startTime!)} ${_formatTime(_startTime!)}'
                              : 'Select start time',
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                      const FaIcon(FontAwesomeIcons.chevronRight, size: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // End time
              Text(
                'End Time',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _isLoading ? null : _selectEndTime,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.outline),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      FaIcon(
                        FontAwesomeIcons.calendar,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _endTime != null
                              ? '${_formatDate(_endTime!)} ${_formatTime(_endTime!)}'
                              : 'Select end time',
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                      const FaIcon(FontAwesomeIcons.chevronRight, size: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Submit button
              PrimaryButton(
                label: 'Create Booking',
                onPressed: _isLoading ? null : _createBooking,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectStartTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _startTime ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: _startTime != null
          ? TimeOfDay.fromDateTime(_startTime!)
          : TimeOfDay.now(),
    );
    if (time == null) return;

    setState(() {
      _startTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      // Reset end time if it's before start time
      if (_endTime != null && _endTime!.isBefore(_startTime!)) {
        _endTime = null;
      }
    });
  }

  Future<void> _selectEndTime() async {
    if (_startTime == null) {
      AppToast.showError(context, 'Please select start time first');
      return;
    }

    final date = await showDatePicker(
      context: context,
      initialDate: _endTime ?? _startTime!,
      firstDate: _startTime!,
      lastDate: _startTime!.add(const Duration(days: 365)),
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: _endTime != null
          ? TimeOfDay.fromDateTime(_endTime!)
          : TimeOfDay.fromDateTime(_startTime!.add(const Duration(hours: 1))),
    );
    if (time == null) return;

    final endTime = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    if (endTime.isBefore(_startTime!) || endTime.isAtSameMomentAs(_startTime!)) {
      AppToast.showError(context, 'End time must be after start time');
      return;
    }

    setState(() {
      _endTime = endTime;
    });
  }

  Future<void> _createBooking() async {
    if (_startTime == null || _endTime == null) {
      AppToast.showError(context, 'Please select both start and end time');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // NOTE: This screen is deprecated. Use CreateBookingWithChargerUnitScreen instead.
      throw UnimplementedError('CreateBookingScreen is deprecated. Use CreateBookingWithChargerUnitScreen.');
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, 'Failed to create booking: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

