import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_ui/shared_ui.dart';
import '../providers/task_providers.dart';
import '../models/verification_task.dart';
import '../widgets/main_scaffold.dart';

/// Task Detail Screen with GPS Check-in
class TaskDetailScreen extends ConsumerStatefulWidget {
  final String taskId;

  const TaskDetailScreen({
    super.key,
    required this.taskId,
  });

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  bool _isCheckingIn = false;
  bool _isSubmittingEvidence = false;
  Uint8List? _pickedEvidenceBytes;
  String? _pickedEvidenceName;
  String? _pickedEvidenceContentType;
  final _evidenceNoteController = TextEditingController();

  // Checklist answers: map from itemId to answer value and optional note
  final Map<String, ChecklistAnswerValue> _checklistAnswers = {};
  final Map<String, TextEditingController> _checklistNoteControllers = {};

  @override
  void dispose() {
    _evidenceNoteController.dispose();
    for (final controller in _checklistNoteControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final taskAsync = ref.watch(taskDetailProvider(widget.taskId));

    return CollabMainScaffold(
      title: 'Task details',
      showBottomNav: false,
      child: taskAsync.when(
        data: (task) => _buildTaskDetail(context, task),
        loading: () => const LoadingState(message: 'Loading task details...'),
        error: (error, stack) => ErrorState(
          message: formatApiError(error),
          code: extractErrorCode(error),
          traceId: extractTraceId(error),
          onRetry: () {
            ref.invalidate(taskDetailProvider(widget.taskId));
          },
        ),
      ),
    );
  }

  Widget _buildTaskDetail(BuildContext context, VerificationTask task) {
    final theme = Theme.of(context);
    final canCheckIn = task.status == VerificationTaskStatus.assigned;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Station Info Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.stationName,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 16,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Station ID: ${task.stationId}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  StatusPill(
                    label: task.status.displayName,
                    colorMapper: (label) {
                      switch (task.status) {
                        case VerificationTaskStatus.assigned:
                          return Colors.orange;
                        case VerificationTaskStatus.checkedIn:
                          return Colors.blue;
                        case VerificationTaskStatus.submitted:
                          return Colors.purple;
                        case VerificationTaskStatus.reviewed:
                          return Colors.green;
                        default:
                          return theme.colorScheme.primary;
                      }
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Task Info Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Task information',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  _InfoRow(
                    icon: Icons.flag,
                    label: 'Priority',
                    value: '${task.priority}',
                    color: _getPriorityColor(task.priority),
                  ),
                  if (task.slaDueAt != null) ...[
                    const SizedBox(height: 12),
                    _InfoRow(
                      icon: Icons.schedule,
                      label: 'SLA due',
                      value: _formatDateTime(task.slaDueAt!),
                      color: task.slaDueAt!.isBefore(DateTime.now())
                          ? theme.colorScheme.error
                          : null,
                    ),
                  ],
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.calendar_today,
                    label: 'Created',
                    value: _formatFullDateTime(task.createdAt),
                  ),
                ],
              ),
            ),
          ),

          // Checklist Card (shown when task has checklist and can check in)
          if (task.checklist != null && task.checklist!.isNotEmpty && canCheckIn) ...[
            const SizedBox(height: 16),
            _buildChecklistCard(context, task),
          ],

          // Check-in Card
          if (task.checkin != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Check-in details',
                          style: theme.textTheme.titleLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _InfoRow(
                      icon: Icons.location_on,
                      label: 'Coordinates',
                      value:
                          '${task.checkin!.lat.toStringAsFixed(6)}, ${task.checkin!.lng.toStringAsFixed(6)}',
                    ),
                    const SizedBox(height: 12),
                    _InfoRow(
                      icon: Icons.access_time,
                      label: 'Checked in at',
                      value: _formatFullDateTime(task.checkin!.checkedInAt),
                    ),
                    if (task.checkin!.distanceM != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.straighten,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Distance to station: ',
                              style: theme.textTheme.bodyMedium,
                            ),
                            Text(
                              '${task.checkin!.distanceM}m',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (task.checkin!.deviceNote != null) ...[
                      const SizedBox(height: 12),
                      _InfoRow(
                        icon: Icons.note,
                        label: 'Note',
                        value: task.checkin!.deviceNote!,
                      ),
                    ],
                    if (task.checkin!.checklistAnswers != null &&
                        task.checkin!.checklistAnswers!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(
                        'Checklist answers',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      ...task.checkin!.checklistAnswers!.map(
                        (answer) => _buildChecklistAnswerRow(context, answer),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Check-in Button
          if (canCheckIn)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isCheckingIn ? null : () => _handleCheckIn(context, task),
                icon: _isCheckingIn
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.location_on),
                label: Text(_isCheckingIn ? 'Checking in...' : 'Check in at location'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),

          if (task.status == VerificationTaskStatus.checkedIn) ...[
            const SizedBox(height: 16),
            _buildEvidenceSubmitSection(context, task),
          ] else if (task.evidences.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildEvidenceViewSection(context, task.evidences.first),
          ],

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildChecklistCard(BuildContext context, VerificationTask task) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.checklist, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Verification Checklist',
                  style: theme.textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Please answer all questions based on your observations at the station.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 16),
            ...task.checklist!.map((item) {
              if (!_checklistNoteControllers.containsKey(item.id)) {
                _checklistNoteControllers[item.id] = TextEditingController();
              }
              return _buildChecklistItem(context, item);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildChecklistItem(BuildContext context, ChecklistItem item) {
    final theme = Theme.of(context);
    final selectedAnswer = _checklistAnswers[item.id];
    final requiresNote = selectedAnswer == ChecklistAnswerValue.no ||
        selectedAnswer == ChecklistAnswerValue.unableToVerify;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.question,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          if (item.sourceCode == 'CHANGE_REQUEST') ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'From change request',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          SegmentedButton<ChecklistAnswerValue>(
            segments: const [
              ButtonSegment<ChecklistAnswerValue>(
                value: ChecklistAnswerValue.yes,
                label: Text('Yes'),
                icon: Icon(Icons.check_circle_outline, size: 18),
              ),
              ButtonSegment<ChecklistAnswerValue>(
                value: ChecklistAnswerValue.no,
                label: Text('No'),
                icon: Icon(Icons.cancel_outlined, size: 18),
              ),
              ButtonSegment<ChecklistAnswerValue>(
                value: ChecklistAnswerValue.unableToVerify,
                label: Text('Unable'),
                icon: Icon(Icons.help_outline, size: 18),
              ),
            ],
            selected: selectedAnswer != null ? {selectedAnswer} : {},
            onSelectionChanged: (selection) {
              if (selection.isEmpty) return;
              setState(() {
                _checklistAnswers[item.id] = selection.first;
              });
            },
            emptySelectionAllowed: true,
            showSelectedIcon: false,
          ),
          if (requiresNote) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _checklistNoteControllers[item.id],
              maxLines: 2,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: 'Supplementary note (required)',
                hintText: 'Please explain why...',
                border: const OutlineInputBorder(),
                counterText: '',
                isDense: true,
                fillColor: theme.colorScheme.errorContainer.withOpacity(0.1),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChecklistAnswerRow(BuildContext context, ChecklistAnswer answer) {
    final theme = Theme.of(context);
    final isNoOrUnable = answer.answer == ChecklistAnswerValue.no ||
        answer.answer == ChecklistAnswerValue.unableToVerify;

    Color answerColor;
    IconData answerIcon;
    switch (answer.answer) {
      case ChecklistAnswerValue.yes:
        answerColor = Colors.green;
        answerIcon = Icons.check_circle;
        break;
      case ChecklistAnswerValue.no:
        answerColor = Colors.red;
        answerIcon = Icons.cancel;
        break;
      case ChecklistAnswerValue.unableToVerify:
        answerColor = Colors.orange;
        answerIcon = Icons.help;
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(answerIcon, size: 18, color: answerColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  answer.question,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: answerColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  answer.answer.toString().replaceAll('ChecklistAnswerValue.', ''),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: answerColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEvidenceSubmitSection(BuildContext context, VerificationTask task) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.photo_camera, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Submit evidence',
                  style: theme.textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Upload one photo and an optional note to submit the task for admin review.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 16),
            if (_pickedEvidenceBytes != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  _pickedEvidenceBytes!,
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _pickedEvidenceName ?? 'Selected photo',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        _isSubmittingEvidence ? null : _pickEvidenceImage,
                    icon: const Icon(Icons.photo_library),
                    label: Text(_pickedEvidenceBytes == null
                        ? 'Choose photo'
                        : 'Change photo'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSubmittingEvidence
                        ? null
                        : () =>
                            _pickEvidenceImage(source: ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Take photo'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _evidenceNoteController,
              enabled: !_isSubmittingEvidence,
              maxLines: 3,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'Note',
                hintText: 'Add a description to help admin review',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSubmittingEvidence
                    ? null
                    : () => _handleSubmitEvidence(context, task),
                icon: _isSubmittingEvidence
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload),
                label: Text(_isSubmittingEvidence
                    ? 'Submitting...'
                    : 'Submit evidence'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEvidenceViewSection(BuildContext context, Evidence evidence) {
    final theme = Theme.of(context);
    final imageBytesAsync = ref.watch(evidenceViewBytesProvider(evidence.photoObjectKey));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Evidence submitted',
                  style: theme.textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            imageBytesAsync.when(
              data: (bytes) => ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  bytes,
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      _buildEvidenceImageError(theme),
                ),
              ),
              loading: () => Container(
                height: 220,
                alignment: Alignment.center,
                child: const CircularProgressIndicator(),
              ),
              error: (error, stackTrace) => _buildEvidenceImageError(theme),
            ),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.access_time,
              label: 'Submitted at',
              value: _formatFullDateTime(evidence.submittedAt),
            ),
            if (evidence.note != null && evidence.note!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _InfoRow(
                icon: Icons.note,
                label: 'Note',
                value: evidence.note!,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEvidenceImageError(ThemeData theme) {
    return Container(
      height: 220,
      width: double.infinity,
      alignment: Alignment.center,
      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
      child: Text(
        'Could not load evidence image',
        style: theme.textTheme.bodyMedium,
      ),
    );
  }

  Future<void> _pickEvidenceImage({ImageSource source = ImageSource.gallery}) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (image == null) return;

    final bytes = await image.readAsBytes();
    if (!mounted) return;

    setState(() {
      _pickedEvidenceBytes = bytes;
      _pickedEvidenceName = image.name;
      _pickedEvidenceContentType = _contentTypeForImage(image);
    });
  }

  Future<void> _handleSubmitEvidence(
      BuildContext context, VerificationTask task) async {
    if (_pickedEvidenceBytes == null) {
      AppToast.showError(context, 'Please select an evidence photo first.');
      return;
    }

    setState(() {
      _isSubmittingEvidence = true;
    });

    try {
      final params = SubmitEvidenceParams(
        taskId: task.id,
        imageBytes: _pickedEvidenceBytes!,
        contentType: _pickedEvidenceContentType ?? 'image/jpeg',
        note: _evidenceNoteController.text,
      );

      await ref.read(submitEvidenceProvider(params));
      ref.invalidate(taskDetailProvider(widget.taskId));
      ref.invalidate(tasksByStatusProvider(null));

      if (mounted) {
        setState(() {
          _pickedEvidenceBytes = null;
          _pickedEvidenceName = null;
          _pickedEvidenceContentType = null;
          _evidenceNoteController.clear();
        });
        AppToast.showSuccess(context, 'Evidence submitted successfully.');
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(
            context, 'Failed to submit evidence: ${formatApiError(e)}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingEvidence = false;
        });
      }
    }
  }

  String _contentTypeForImage(XFile image) {
    if (image.mimeType != null && image.mimeType!.isNotEmpty) {
      return image.mimeType!;
    }
    final lowerName = image.name.toLowerCase();
    if (lowerName.endsWith('.png')) {
      return 'image/png';
    }
    if (lowerName.endsWith('.webp')) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }

  Future<void> _handleCheckIn(BuildContext context, VerificationTask task) async {
    // Validate checklist if present
    if (task.checklist != null && task.checklist!.isNotEmpty) {
      for (final item in task.checklist!) {
        final answer = _checklistAnswers[item.id];
        if (answer == null) {
          AppToast.showError(context, 'Please answer all checklist questions.');
          return;
        }
        if (answer == ChecklistAnswerValue.no ||
            answer == ChecklistAnswerValue.unableToVerify) {
          final note = _checklistNoteControllers[item.id]?.text.trim() ?? '';
          if (note.isEmpty) {
            AppToast.showError(
              context,
              'Supplementary note is required when answer is "No" or "Unable to verify".',
            );
            return;
          }
        }
      }
    }

    setState(() {
      _isCheckingIn = true;
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            AppToast.showError(context, 'Location permission denied.');
          }
          setState(() => _isCheckingIn = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          AppToast.showError(
            context,
            'Location permission permanently denied. Open Settings to grant access.',
          );
        }
        setState(() => _isCheckingIn = false);
        return;
      }

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          AppToast.showError(
              context, 'Location is off. Turn on GPS and try again.');
        }
        setState(() => _isCheckingIn = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Build checklist answers
      List<ChecklistAnswer>? checklistAnswerList;
      if (task.checklist != null && task.checklist!.isNotEmpty) {
        checklistAnswerList = task.checklist!.map((item) {
          final answerValue = _checklistAnswers[item.id]!;
          return ChecklistAnswer(
            itemId: item.id,
            question: item.question,
            type: item.type,
            sourceCode: item.sourceCode,
            answer: answerValue,
          );
        }).toList();
      }

      final checkInParams = CheckInParams(
        taskId: task.id,
        lat: position.latitude,
        lng: position.longitude,
        checklistAnswers: checklistAnswerList,
      );

      await ref.read(checkInProvider(checkInParams));

      ref.invalidate(taskDetailProvider(widget.taskId));
      ref.invalidate(tasksByStatusProvider(null));

      if (mounted) {
        AppToast.showSuccess(context, 'Check-in successful.');
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(
            context, 'Check-in failed: ${formatApiError(e)}');
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingIn = false);
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = dateTime.difference(now);

    if (difference.inDays > 0) {
      return '${difference.inDays} days left';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours left';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes left';
    } else {
      return 'Overdue';
    }
  }

  String _formatFullDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Color _getPriorityColor(int priority) {
    switch (priority) {
      case 5:
        return Colors.red;
      case 4:
        return Colors.orange;
      case 3:
        return Colors.yellow.shade700;
      case 2:
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}

/// Info Row Widget
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: color ?? theme.colorScheme.onSurface.withOpacity(0.6),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: color != null ? FontWeight.bold : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

