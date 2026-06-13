import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:shared_api/shared_api.dart';
import '../models/admin_verification_task.dart';
import '../providers/verification_task_providers.dart';
import '../providers/battery_swap_trust_providers.dart';
import '../providers/file_viewer_providers.dart';
import '../services/file_viewer_service.dart';
import '../theme/admin_theme.dart';
import '../utils/responsive_utils.dart';
import '../widgets/admin_scaffold.dart';
import 'assign_task_modal.dart';

/// Verification Task Detail Screen
class VerificationTaskDetailScreen extends ConsumerWidget {
  final String id;

  const VerificationTaskDetailScreen({
    super.key,
    required this.id,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final taskAsync = ref.watch(verificationTaskProvider(id));

    return AdminScaffold(
      title: 'Verification task details',
      body: taskAsync.when(
        data: (task) => _buildContent(context, theme, ref, task),
        loading: () =>
            const LoadingState(message: 'Loading task details...'),
        error: (error, stack) => ErrorState(
          title: 'Could not load task',
          message: formatApiError(error),
          code: extractErrorCode(error),
          traceId: extractTraceId(error),
          onRetry: () {
            ref.invalidate(verificationTaskProvider(id));
          },
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ThemeData theme, WidgetRef ref,
      AdminVerificationTask task) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(responsivePadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task.stationName,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Task ID: ${task.id.substring(0, 8)}...',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                            if (task.stationServiceTypes.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  Chip(
                                    avatar: Icon(
                                      task.isBatterySwapStation
                                          ? Icons.battery_charging_full
                                          : Icons.ev_station,
                                      size: 18,
                                    ),
                                    label: Text(task.primaryServiceLabel),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  ...task.stationServiceTypes.map(
                                    (t) => Chip(
                                      label: Text(t.replaceAll('_', ' ')),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      StatusPill(
                        label: task.status.displayName,
                        colorMapper: (label) {
                          switch (task.status) {
                            case VerificationTaskStatus.open:
                              return Colors.blue;
                            case VerificationTaskStatus.assigned:
                              return Colors.orange;
                            case VerificationTaskStatus.checkedIn:
                              return Colors.purple;
                            case VerificationTaskStatus.submitted:
                              return Colors.purple;
                            case VerificationTaskStatus.reviewed:
                              return Colors.green;
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Actions
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      if (task.canAssign)
                        ElevatedButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AssignTaskModal(taskId: task.id),
                            ).then((_) {
                              ref.invalidate(verificationTaskProvider(id));
                              ref.invalidate(verificationTasksPageProvider);
                            });
                          },
                          icon: const Icon(Icons.person_add),
                          label: const Text('Assign Task'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      if (task.canReview)
                        ElevatedButton.icon(
                          onPressed: () => _showReviewDialog(context, ref, task),
                          icon: const Icon(Icons.rate_review),
                          label: const Text('Review Task'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AdminTheme.primaryTeal,
                            foregroundColor: Colors.white,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Status Timeline
          _buildStatusTimeline(theme, task),
          const SizedBox(height: 24),

          // Basic Info
          _buildBasicInfoSection(context, theme, task),
          const SizedBox(height: 24),

          // Battery Swap Specific Info
          if (task.isBatterySwapStation) ...[
            _buildBatterySwapInfoSection(context, theme, ref, task),
            const SizedBox(height: 24),
          ],

          // Check-in Info
          if (task.checkin != null) ...[
            _buildCheckinSection(context, theme, task.checkin!),
            const SizedBox(height: 24),
          ],

          // Checklist Section
          if (task.checklist != null && task.checklist!.isNotEmpty) ...[
            _buildChecklistSection(context, theme, task),
            const SizedBox(height: 24),
          ],

          // Evidences
          if (task.evidences.isNotEmpty) ...[
            _buildEvidencesSection(context, theme, ref, task.evidences),
            const SizedBox(height: 24),
          ],

          // Review Info
          if (task.review != null) ...[
            _buildReviewSection(theme, task.review!),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusTimeline(BuildContext context, ThemeData theme, AdminVerificationTask task) {
    final statuses = VerificationTaskStatus.values;
    final currentIndex = statuses.indexOf(task.status);

    return Card(
      child: Padding(
        padding: EdgeInsets.all(responsivePadding(context) * 0.8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Status Timeline',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...statuses.asMap().entries.map((entry) {
              final index = entry.key;
              final status = entry.value;
              final isCompleted = index <= currentIndex;
              final isCurrent = index == currentIndex;

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCompleted
                            ? (isCurrent ? AdminTheme.primaryTeal : Colors.green)
                            : Colors.grey[300],
                        border: Border.all(
                          color: isCompleted
                              ? (isCurrent ? AdminTheme.primaryTeal : Colors.green)
                              : Colors.grey[400]!,
                          width: 2,
                        ),
                      ),
                      child: isCompleted
                          ? Icon(
                              isCurrent ? Icons.radio_button_checked : Icons.check,
                              size: 16,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            status.displayName,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                              color: isCompleted
                                  ? theme.colorScheme.onSurface
                                  : theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                          if (isCurrent && task.status == VerificationTaskStatus.submitted)
                            Text(
                              'Pending review',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection(BuildContext context, ThemeData theme, AdminVerificationTask task) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(responsivePadding(context) * 0.8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Basic Information',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(context, theme, 'Station ID', task.stationId, copyable: true),
            _buildInfoRow(context, theme, 'Station name', task.stationName),
            if (task.changeRequestId != null)
              _buildInfoRow(context, theme, 'Change Request ID', task.changeRequestId!, copyable: true),
            _buildInfoRow(
              context,
              theme,
              'Priority',
              '${task.priority}',
              icon: Icons.flag,
              iconColor: _getPriorityColor(task.priority),
            ),
            _buildInfoRow(context, theme, 'Status', task.status.displayName),
            _buildInfoRow(
                context, theme, 'Created At', _formatDateTime(task.createdAt)),
            if (task.slaDueAt != null)
              _buildInfoRow(
                context,
                theme,
                'SLA Due At',
                _formatDateTime(task.slaDueAt!),
                icon: Icons.schedule,
                iconColor: task.slaDueAt!.isBefore(DateTime.now())
                    ? theme.colorScheme.error
                    : null,
              ),
            if (task.assignedToEmail != null)
              _buildInfoRow(context, theme, 'Assigned To', task.assignedToEmail!,
                  icon: Icons.person),
          ],
        ),
      ),
    );
  }

  Widget _buildBatterySwapInfoSection(BuildContext context, ThemeData theme, WidgetRef ref, AdminVerificationTask task) {
    final trustAsync = ref.watch(batterySwapTrustProvider(task.stationId));

    return Card(
      child: Padding(
        padding: EdgeInsets.all(responsivePadding(context) * 0.8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.battery_charging_full, color: Colors.amber),
                const SizedBox(width: 8),
                Text(
                  'Battery Swap Station Info',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Snapshot comparison (expected vs actual)
            if (task.batterySwapStationSnapshot != null) ...[
              _buildSnapshotComparison(theme, task),
              const SizedBox(height: 16),
            ],

            trustAsync.when(
              data: (trust) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: trust.scoreColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: trust.scoreColor.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          trust.levelIcon,
                          color: trust.scoreColor,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Trust Score',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                              Text(
                                '${trust.score} / 100 (${trust.levelLabel})',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: trust.scoreColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () {
                            context.push('/battery-swap/trust/${task.stationId}');
                          },
                          icon: const Icon(Icons.dashboard, size: 16),
                          label: const Text('Details'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AdminTheme.primaryTeal,
                            side: BorderSide(color: AdminTheme.primaryTeal),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'This verification task is for a battery swap station. During verification, '
                    'ensure that the battery inventory, pile count, and slot count match the expected values.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, stack) => Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: theme.colorScheme.error, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Could not load trust score',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckinSection(BuildContext context, ThemeData theme, CheckinInfo checkin) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(responsivePadding(context) * 0.8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Check-in Information',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              context,
              theme,
              'Location',
              '${checkin.lat.toStringAsFixed(6)}, ${checkin.lng.toStringAsFixed(6)}',
              icon: Icons.location_on,
            ),
            _buildInfoRow(
              context,
              theme,
              'Checked In At',
              _formatDateTime(checkin.checkedInAt),
              icon: Icons.access_time,
            ),
            if (checkin.distanceM != null)
              _buildInfoRow(
                context,
                theme,
                'Distance',
                '${checkin.distanceM}m from station',
                icon: Icons.straighten,
              ),
            if (checkin.deviceNote != null)
              _buildInfoRow(
                context,
                theme,
                'Device Note',
                checkin.deviceNote!,
                icon: Icons.note,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChecklistSection(BuildContext context, ThemeData theme, AdminVerificationTask task) {
    final submittedAnswers = task.checkin?.checklistAnswers ?? [];
    final answerMap = {for (var a in submittedAnswers) a.itemId: a};

    return Card(
      child: Padding(
        padding: EdgeInsets.all(responsivePadding(context) * 0.8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.checklist, color: AdminTheme.primaryTeal),
                const SizedBox(width: 8),
                Text(
                  'Verification Checklist',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...task.checklist!.map((item) {
              final answer = answerMap[item.id];
              return _buildChecklistItemRow(theme, item, answer, task.stationSnapshot);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildChecklistItemRow(
    ThemeData theme,
    ChecklistItem item,
    ChecklistAnswer? answer,
    AdminStationSnapshotDTO? stationSnapshot,
  ) {
    final hasNoOrUnable = answer?.answer == ChecklistAnswerValue.no ||
        answer?.answer == ChecklistAnswerValue.unableToVerify;

    Color answerColor;
    IconData answerIcon;
    if (answer == null) {
      answerColor = Colors.grey;
      answerIcon = Icons.help_outline;
    } else {
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
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasNoOrUnable
            ? Colors.yellow.shade50
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasNoOrUnable
              ? Colors.yellow.shade300
              : theme.colorScheme.outline.withOpacity(0.2),
          width: hasNoOrUnable ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(answerIcon, size: 20, color: answerColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.question,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (item.sourceCode == 'CHANGE_REQUEST')
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.purple.shade200),
                            ),
                            child: Text(
                              'Change Request',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.purple.shade700,
                              ),
                            ),
                          )
                        else if (item.sourceCode == 'DEFAULT')
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AdminTheme.primaryTeal.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Default',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AdminTheme.primaryTeal,
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        if (answer != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: answerColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: answerColor.withOpacity(0.3)),
                            ),
                            child: Text(
                              answer.answer.toString().replaceAll('ChecklistAnswerValue.', ''),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: answerColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        else
                          Text(
                            'Not answered',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasNoOrUnable) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber,
                      size: 16, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hasNoOrUnable
                          ? 'Answer is "${answer!.answer.toString().replaceAll('ChecklistAnswerValue.', '')}" - requires attention'
                          : 'No supplementary note provided',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEvidencesSection(BuildContext context, ThemeData theme, WidgetRef ref, List<Evidence> evidences) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(responsivePadding(context) * 0.8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Evidences (${evidences.length})',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...evidences.map((evidence) => Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AdminTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Photo thumbnail
                      _buildPhotoThumbnail(context, theme, ref, evidence),
                      const SizedBox(height: 12),
                      // Note
                      if (evidence.note != null) ...[
                        Text(
                          evidence.note!,
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                      ],
                      // Metadata
                      Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 14,
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Submitted: ${_formatDateTime(evidence.submittedAt)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Icon(
                            Icons.person,
                            size: 14,
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'By: ${evidence.submittedBy.substring(0, 8)}...',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 18),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: evidence.photoObjectKey));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Object key copied to clipboard'),
                                  duration: const Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            tooltip: 'Copy object key',
                            color: AdminTheme.primaryTeal,
                          ),
                        ],
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoThumbnail(BuildContext context, ThemeData theme, WidgetRef ref, Evidence evidence) {
    final urlAsync = ref.watch(presignedUrlProvider(evidence.photoObjectKey));
    final fileViewerService = ref.read(fileViewerServiceProvider);

    return urlAsync.when(
          data: (viewUrl) => GestureDetector(
            onTap: () => _showImageLightbox(context, viewUrl),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                viewUrl,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    width: double.infinity,
                    height: 200,
                    color: AdminTheme.surfaceLight,
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                            : null,
                        color: AdminTheme.primaryTeal,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      color: AdminTheme.surfaceLight,
                      border: Border.all(color: theme.colorScheme.error.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Failed to load image',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () {
                            fileViewerService.clearCache(evidence.photoObjectKey);
                            ref.invalidate(presignedUrlProvider(evidence.photoObjectKey));
                          },
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Retry'),
                          style: TextButton.styleFrom(
                            foregroundColor: AdminTheme.primaryTeal,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          loading: () => Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              color: AdminTheme.surfaceLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AdminTheme.primaryTeal),
                  const SizedBox(height: 12),
                  Text(
                    'Loading image...',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
          error: (error, stackTrace) => Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              color: AdminTheme.surfaceLight,
              border: Border.all(color: theme.colorScheme.error.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 8),
                Text(
                  'Could not load evidence image',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatApiError(error),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    fileViewerService.clearCache(evidence.photoObjectKey);
                    ref.invalidate(presignedUrlProvider(evidence.photoObjectKey));
                  },
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Retry'),
                  style: TextButton.styleFrom(
                    foregroundColor: AdminTheme.primaryTeal,
                  ),
                ),
              ],
            ),
          ),
    );
  }

  void _showImageLightbox(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      width: MediaQuery.of(context).size.width * 0.9,
                      height: MediaQuery.of(context).size.height * 0.9,
                      color: Colors.black87,
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                              : null,
                          color: Colors.white,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: MediaQuery.of(context).size.width * 0.9,
                      height: MediaQuery.of(context).size.height * 0.9,
                      color: Colors.black87,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 64, color: Colors.white70),
                            const SizedBox(height: 16),
                            Text(
                              'Failed to load image',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(dialogContext).pop(),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                  padding: const EdgeInsets.all(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewSection(BuildContext context, ThemeData theme, Review review) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(responsivePadding(context) * 0.8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Review Result',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: review.isPass
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: review.isPass ? Colors.green : Colors.red,
                  width: 2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        review.isPass ? Icons.check_circle : Icons.cancel,
                        color: review.isPass ? Colors.green : Colors.red,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        review.result,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: review.isPass ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                  if (review.adminNote != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      review.adminNote!,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 16,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Reviewed: ${_formatDateTime(review.reviewedAt)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.person,
                        size: 16,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'By: ${review.reviewedBy}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    ThemeData theme,
    String label,
    String value, {
    IconData? icon,
    Color? iconColor,
    bool copyable = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 20,
              color: iconColor ?? theme.colorScheme.onSurface.withOpacity(0.5),
            ),
            const SizedBox(width: 12),
          ],
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: iconColor,
                    ),
                  ),
                ),
                if (copyable) ...[
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Copy to clipboard',
                    child: IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: value));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$label copied to clipboard'),
                            duration: const Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      iconSize: 18,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getPriorityColor(int priority) {
    if (priority >= 5) return Colors.red;
    if (priority >= 4) return Colors.orange;
    if (priority >= 3) return Colors.yellow;
    return Colors.blue;
  }

  Widget _buildSnapshotComparison(ThemeData theme, AdminVerificationTask task) {
    final snapshot = task.batterySwapStationSnapshot!;
    final checkin = task.checkin;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.compare_arrows, color: AdminTheme.primaryTeal, size: 18),
              const SizedBox(width: 8),
              Text(
                'Inventory Snapshot',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildComparisonRow(
            theme,
            'Total Batteries',
            snapshot.totalBatteries,
            checkin?.actualTotalBatteries,
          ),
          const SizedBox(height: 8),
          _buildComparisonRow(
            theme,
            'Available Batteries',
            null,
            checkin?.actualAvailableBatteries,
            subtitle: 'Expected: N/A (dynamic)',
          ),
          const SizedBox(height: 8),
          _buildComparisonRow(
            theme,
            'Pile Count',
            snapshot.pileCount,
            null,
            subtitle: checkin != null ? null : 'Collab submits at site',
          ),
          const SizedBox(height: 8),
          _buildComparisonRow(
            theme,
            'Slot Count',
            snapshot.slotCount,
            null,
            subtitle: checkin != null ? null : 'Collab submits at site',
          ),
          const SizedBox(height: 8),
          _buildComparisonRow(
            theme,
            'Avg Charge Power',
            null,
            null,
            subtitle: snapshot.avgChargePowerKw > 0
                ? '${snapshot.avgChargePowerKw.toStringAsFixed(1)} kW (expected)'
                : 'N/A',
          ),
          const SizedBox(height: 8),
          _buildComparisonRow(
            theme,
            'Base Price',
            null,
            null,
            subtitle: snapshot.basePriceVnd > 0
                ? '${snapshot.basePriceVnd} VND'
                : 'N/A',
          ),
          if (task.riskReasons.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'Risk Reasons:',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 4),
            ...task.riskReasons.map((r) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber, size: 14,
                          color: Colors.orange.shade700),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          r,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildComparisonRow(
    ThemeData theme,
    String label,
    int? expected,
    int? actual, {
    String? subtitle,
  }) {
    final bool showMismatch = expected != null && actual != null && expected != actual;
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: theme.textTheme.bodySmall,
          ),
        ),
        if (expected != null) ...[
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AdminTheme.primaryTeal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Text(
                '$expected',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AdminTheme.primaryTeal,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.arrow_forward, size: 14, color: theme.colorScheme.onSurface.withOpacity(0.4)),
          const SizedBox(width: 8),
          Expanded(
            flex: 1,
            child: actual != null
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: showMismatch
                          ? Colors.red.shade50
                          : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: showMismatch
                          ? Border.all(color: Colors.red.shade200)
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$actual',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: showMismatch ? Colors.red : Colors.green,
                      ),
                    ),
                  )
                : Text(
                    subtitle ?? '—',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
          ),
        ] else ...[
          Expanded(
            flex: 3,
            child: Text(
              subtitle ?? '—',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _showReviewDialog(
      BuildContext context, WidgetRef ref, AdminVerificationTask task) {
    String? selectedResult;
    final noteController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final bool isBatterySwap = task.isBatterySwapStation;
    bool swapStationVerified = true;
    bool inventoryAccurate = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Review Task'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Select review result:'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedResult,
                    decoration: const InputDecoration(
                      labelText: 'Result *',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'PASS', child: Text('PASS')),
                      DropdownMenuItem(value: 'FAIL', child: Text('FAIL')),
                    ],
                    validator: (value) =>
                        value == null ? 'Result is required' : null,
                    onChanged: (value) {
                      selectedResult = value;
                    },
                  ),
                  if (isBatterySwap) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(
                      'Battery Swap Verification Assessment:',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      value: swapStationVerified,
                      onChanged: (v) {
                        setDialogState(() => swapStationVerified = v ?? true);
                      },
                      title: const Text('Swap station verified'),
                      subtitle: const Text(
                          'Collab confirmed station is operational'),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    CheckboxListTile(
                      value: inventoryAccurate,
                      onChanged: (v) {
                        setDialogState(() => inventoryAccurate = v ?? true);
                      },
                      title: const Text('Inventory accurate'),
                      subtitle: const Text(
                          'Battery count matches expected snapshot'),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: noteController,
                    decoration: const InputDecoration(
                      labelText: 'Admin Note (Optional)',
                      hintText: 'Add a note...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate() && selectedResult != null) {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Confirm Review'),
                      content: Text(
                        'Are you sure you want to mark this task as $selectedResult?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AdminTheme.primaryTeal,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Confirm'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true) {
                    await _handleReview(
                      context,
                      ref,
                      task,
                      selectedResult!,
                      noteController.text.trim().isEmpty
                          ? null
                          : noteController.text.trim(),
                      isBatterySwap ? swapStationVerified : null,
                      isBatterySwap ? inventoryAccurate : null,
                    );
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminTheme.primaryTeal,
                foregroundColor: Colors.white,
              ),
              child: const Text('Submit Review'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleReview(BuildContext context, WidgetRef ref,
      AdminVerificationTask task, String result, String? adminNote,
      [bool? swapStationVerified, bool? inventoryAccurate]) async {
    try {
      final factory = ref.read(apiClientFactoryProvider);
      if (factory == null) throw Exception('API client not initialized');

      await factory.admin.reviewVerificationTask(
        id: task.id,
        result: result,
        adminNote: adminNote,
        swapStationVerified: swapStationVerified,
        inventoryAccurate: inventoryAccurate,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Task review submitted ($result) successfully'),
            backgroundColor: Colors.green,
          ),
        );
        ref.invalidate(verificationTaskProvider(task.id));
        ref.invalidate(verificationTasksPageProvider);
        if (context.mounted) context.pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${formatApiError(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

