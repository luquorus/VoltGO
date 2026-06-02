import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_ui/shared_ui.dart';
import '../providers/battery_swap_task_providers.dart';
import '../models/battery_swap_verification_task.dart';
import '../widgets/main_scaffold.dart';

/// Evidence photo types for battery swap verification per design spec
enum EvidencePhotoType {
  pileOverview('PILE_OVERVIEW', 'Pile Overview', Icons.charging_station),
  batterySerialIn('BATTERY_SERIAL_IN', 'Battery Serial (In)', Icons.battery_full),
  batterySerialOut('BATTERY_SERIAL_OUT', 'Battery Serial (Out)', Icons.battery_charging_full),
  chargeDisplay('CHARGE_DISPLAY', 'Charge Display', Icons.display_settings),
  stationBoard('STATION_BOARD', 'Station Board', Icons.info_outline);

  final String value;
  final String label;
  final IconData icon;

  const EvidencePhotoType(this.value, this.label, this.icon);

  static EvidencePhotoType? fromString(String? value) {
    if (value == null) return null;
    return EvidencePhotoType.values.cast<EvidencePhotoType?>().firstWhere(
          (e) => e!.value == value,
          orElse: () => null,
        );
  }
}

/// Swap Verification Task Detail Screen with battery swap specific checkin form
class SwapVerificationTaskDetailScreen extends ConsumerStatefulWidget {
  final String taskId;

  const SwapVerificationTaskDetailScreen({
    super.key,
    required this.taskId,
  });

  @override
  ConsumerState<SwapVerificationTaskDetailScreen> createState() =>
      _SwapVerificationTaskDetailScreenState();
}

class _SwapVerificationTaskDetailScreenState
    extends ConsumerState<SwapVerificationTaskDetailScreen> {
  bool _isCheckingIn = false;
  bool _isSubmittingEvidence = false;

  // Form controllers for battery swap checkin
  final _batteryCountController = TextEditingController();
  final _pileCountController = TextEditingController();
  final _slotCountController = TextEditingController();
  final _parkingFeeController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isOperatingHoursAccurate = true;

  // Evidence photos
  final List<Uint8List> _evidencePhotos = [];
  final List<String> _evidencePhotoNames = [];
  final List<EvidencePhotoType> _evidencePhotoTypes = [];
  final _evidenceNoteController = TextEditingController();

  @override
  void dispose() {
    _batteryCountController.dispose();
    _pileCountController.dispose();
    _slotCountController.dispose();
    _parkingFeeController.dispose();
    _notesController.dispose();
    _evidenceNoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final taskAsync = ref.watch(swapTaskDetailProvider(widget.taskId));

    return CollabMainScaffold(
      title: 'Battery Swap Verification',
      showBottomNav: false,
      child: taskAsync.when(
        data: (task) => _buildTaskDetail(context, task),
        loading: () => const LoadingState(message: 'Loading task details...'),
        error: (error, stack) => ErrorState(
          message: formatApiError(error),
          code: extractErrorCode(error),
          traceId: extractTraceId(error),
          onRetry: () {
            ref.invalidate(swapTaskDetailProvider(widget.taskId));
          },
        ),
      ),
    );
  }

  Widget _buildTaskDetail(BuildContext context, BatterySwapVerificationTask task) {
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
                  Row(
                    children: [
                      Icon(
                        Icons.battery_charging_full,
                        color: theme.colorScheme.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          task.stationName,
                          style: theme.textTheme.headlineSmall,
                        ),
                      ),
                    ],
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
                  _buildInfoRow(
                    theme,
                    Icons.flag,
                    'Priority',
                    '${task.priority}',
                    color: _getPriorityColor(task.priority),
                  ),
                  if (task.slaDueAt != null) ...[
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      theme,
                      Icons.schedule,
                      'SLA due',
                      _formatDateTime(task.slaDueAt!),
                      color: task.slaDueAt!.isBefore(DateTime.now())
                          ? theme.colorScheme.error
                          : null,
                    ),
                  ],
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    theme,
                    Icons.calendar_today,
                    'Created',
                    _formatFullDateTime(task.createdAt),
                  ),
                ],
              ),
            ),
          ),

          // Check-in Card with battery swap form
          if (canCheckIn) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.edit_note, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Battery Swap Check-in Form',
                          style: theme.textTheme.titleLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please fill in the following information at the station:',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Battery inventory count
                    TextField(
                      controller: _batteryCountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Battery inventory count *',
                        hintText: 'Total number of batteries on site',
                        prefixIcon: Icon(Icons.battery_full),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Pile count
                    TextField(
                      controller: _pileCountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Pile count *',
                        hintText: 'Number of swap piles',
                        prefixIcon: Icon(Icons.charging_station),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Slot count
                    TextField(
                      controller: _slotCountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Slot count *',
                        hintText: 'Total slots available',
                        prefixIcon: Icon(Icons.grid_view),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Operating hours accurate
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Operating hours accurate?',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment<bool>(
                              value: true,
                              label: Text('Yes'),
                              icon: Icon(Icons.check),
                            ),
                            ButtonSegment<bool>(
                              value: false,
                              label: Text('No'),
                              icon: Icon(Icons.close),
                            ),
                          ],
                          selected: {_isOperatingHoursAccurate},
                          onSelectionChanged: (selection) {
                            setState(() {
                              _isOperatingHoursAccurate = selection.first;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Parking fee (optional)
                    TextField(
                      controller: _parkingFeeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Parking fee (optional)',
                        hintText: 'Enter 0 if free',
                        prefixIcon: Icon(Icons.attach_money),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Notes
                    TextField(
                      controller: _notesController,
                      maxLines: 3,
                      maxLength: 500,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        hintText: 'Any additional observations...',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Check-in button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed:
                            _isCheckingIn ? null : () => _handleCheckIn(context, task),
                        icon: _isCheckingIn
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.location_on),
                        label: Text(
                            _isCheckingIn ? 'Checking in...' : 'Check in at location'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Check-in details (if already checked in)
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
                        Icon(Icons.check_circle,
                            color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Check-in details',
                          style: theme.textTheme.titleLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow(
                      theme,
                      Icons.location_on,
                      'Coordinates',
                      '${task.checkin!.lat.toStringAsFixed(6)}, ${task.checkin!.lng.toStringAsFixed(6)}',
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      theme,
                      Icons.access_time,
                      'Checked in at',
                      _formatFullDateTime(task.checkin!.checkedInAt),
                    ),
                    if (task.checkin!.distanceM != null) ...[
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        theme,
                        Icons.straighten,
                        'Distance to station',
                        '${task.checkin!.distanceM}m',
                      ),
                    ],
                    if (task.checkin!.batteryInventoryCount != null) ...[
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        theme,
                        Icons.battery_full,
                        'Battery count',
                        '${task.checkin!.batteryInventoryCount}',
                      ),
                    ],
                    if (task.checkin!.pileCount != null) ...[
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        theme,
                        Icons.charging_station,
                        'Pile count',
                        '${task.checkin!.pileCount}',
                      ),
                    ],
                    if (task.checkin!.slotCount != null) ...[
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        theme,
                        Icons.grid_view,
                        'Slot count',
                        '${task.checkin!.slotCount}',
                      ),
                    ],
                    if (task.checkin!.isOperatingHoursAccurate != null) ...[
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        theme,
                        Icons.schedule,
                        'Hours accurate',
                        task.checkin!.isOperatingHoursAccurate! ? 'Yes' : 'No',
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],

          // Evidence submission section
          if (task.status == VerificationTaskStatus.checkedIn) ...[
            const SizedBox(height: 16),
            _buildEvidenceSection(context, task),
          ] else if (task.evidences.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildEvidenceViewSection(context, task.evidences.first),
          ],

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildEvidenceSection(
      BuildContext context, BatterySwapVerificationTask task) {
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
                  'Submit evidence photos',
                  style: theme.textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Take photos of the battery swap station as evidence:',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 16),

            // Evidence photos grid
            if (_evidencePhotos.isNotEmpty) ...[
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _evidencePhotos.length,
                  itemBuilder: (context, index) {
                    final photoType = _evidencePhotoTypes[index];
                    return Stack(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: MemoryImage(_evidencePhotos[index]),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 4,
                          left: 4,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              photoType.label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 12,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _evidencePhotos.removeAt(index);
                                _evidencePhotoNames.removeAt(index);
                                _evidencePhotoTypes.removeAt(index);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Photo buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSubmittingEvidence
                        ? null
                        : () => _pickEvidenceImage(source: ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSubmittingEvidence
                        ? null
                        : () => _pickEvidenceImage(source: ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Note field
            TextField(
              controller: _evidenceNoteController,
              enabled: !_isSubmittingEvidence,
              maxLines: 3,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'Note',
                hintText: 'Add a description of the evidence...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSubmittingEvidence || _evidencePhotos.isEmpty
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

  Widget _buildEvidenceViewSection(
      BuildContext context, BatterySwapEvidence evidence) {
    final theme = Theme.of(context);
    final imageUrlAsync = ref.watch(evidenceViewUrlProvider(evidence.photoObjectKey));

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
            imageUrlAsync.when(
              data: (url) => ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  url,
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
            _buildInfoRow(
              theme,
              Icons.access_time,
              'Submitted at',
              _formatFullDateTime(evidence.submittedAt),
            ),
            if (evidence.note != null && evidence.note!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                theme,
                Icons.note,
                'Note',
                evidence.note!,
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

  Widget _buildInfoRow(
    ThemeData theme,
    IconData icon,
    String label,
    String value, {
    Color? color,
  }) {
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

  Future<void> _pickEvidenceImage({ImageSource source = ImageSource.gallery}) async {
    final picked = await _showPhotoTypePicker();
    if (picked == null) return;

    final EvidencePhotoType selectedType = picked;

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
      _evidencePhotos.add(bytes);
      _evidencePhotoNames.add(image.name);
      _evidencePhotoTypes.add(selectedType);
    });
  }

  Future<EvidencePhotoType?> _showPhotoTypePicker() async {
    return showModalBottomSheet<EvidencePhotoType>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Select photo type',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                const SizedBox(height: 8),
                ...EvidencePhotoType.values.map((type) {
                  return ListTile(
                    leading: Icon(type.icon),
                    title: Text(type.label),
                    onTap: () => Navigator.of(context).pop(type),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleCheckIn(
      BuildContext context, BatterySwapVerificationTask task) async {
    // Validate required fields
    if (_batteryCountController.text.isEmpty ||
        _pileCountController.text.isEmpty ||
        _slotCountController.text.isEmpty) {
      AppToast.showError(
          context, 'Please fill in all required fields (battery, pile, slot count).');
      return;
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

      final checkInParams = BatterySwapCheckInParams(
        taskId: task.id,
        lat: position.latitude,
        lng: position.longitude,
        batteryInventoryCount: int.tryParse(_batteryCountController.text) ?? 0,
        pileCount: int.tryParse(_pileCountController.text) ?? 0,
        slotCount: int.tryParse(_slotCountController.text) ?? 0,
        isOperatingHoursAccurate: _isOperatingHoursAccurate,
        parkingFee: int.tryParse(_parkingFeeController.text),
        notes: _notesController.text.isEmpty ? null : _notesController.text,
      );

      await ref.read(batterySwapCheckInProvider(checkInParams));
      ref.invalidate(swapTaskDetailProvider(widget.taskId));
      ref.invalidate(swapTasksProvider);

      if (mounted) {
        AppToast.showSuccess(context, 'Check-in successful. Now you can submit evidence photos.');
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(
            context, 'Check-in failed: ${formatApiError(e)}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingIn = false;
        });
      }
    }
  }

  Future<void> _handleSubmitEvidence(
      BuildContext context, BatterySwapVerificationTask task) async {
    if (_evidencePhotos.isEmpty) {
      AppToast.showError(context, 'Please add at least one evidence photo.');
      return;
    }

    setState(() {
      _isSubmittingEvidence = true;
    });

    try {
      // Submit each evidence photo with its specific type
      for (int i = 0; i < _evidencePhotos.length; i++) {
        final params = BatterySwapSubmitEvidenceParams(
          taskId: task.id,
          imageBytes: _evidencePhotos[i],
          contentType: 'image/jpeg',
          evidenceType: _evidencePhotoTypes[i].value,
          note: i == 0 ? _evidenceNoteController.text : null,
        );
        await ref.read(batterySwapSubmitEvidenceProvider(params));
      }

      ref.invalidate(swapTaskDetailProvider(widget.taskId));
      ref.invalidate(swapTasksProvider);

      if (mounted) {
        setState(() {
          _evidencePhotos.clear();
          _evidencePhotoNames.clear();
          _evidencePhotoTypes.clear();
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
