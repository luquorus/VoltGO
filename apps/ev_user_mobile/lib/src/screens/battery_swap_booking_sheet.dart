import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../models/battery_swap_models.dart';

/// Result of the booking sheet
class BatterySwapBookingResult {
  final DateTime expectedArrivalAt;
  final int requestedBatteryPercent;
  final double batteryCapacityKwh;
  final String? pileId;
  final String? slotId;
  final String? note;

  BatterySwapBookingResult({
    required this.expectedArrivalAt,
    required this.requestedBatteryPercent,
    required this.batteryCapacityKwh,
    this.pileId,
    this.slotId,
    this.note,
  });
}

/// Bottom sheet for booking a battery swap.
class BatterySwapBookingSheet extends ConsumerStatefulWidget {
  final BatterySwapStationDetailModel station;
  final bool hasActiveAtStation;

  const BatterySwapBookingSheet({
    super.key,
    required this.station,
    required this.hasActiveAtStation,
  });

  @override
  ConsumerState<BatterySwapBookingSheet> createState() =>
      _BatterySwapBookingSheetState();
}

class _BatterySwapBookingSheetState
    extends ConsumerState<BatterySwapBookingSheet> {
  late int requested;
  late double capacity;
  late TextEditingController _capacityController;
  DateTime? selectedArrivalTime;
  final TextEditingController _noteController = TextEditingController();
  String? selectedPileId;
  String? selectedSlotId;

  @override
  void initState() {
    super.initState();
    requested = 20;
    capacity = 60.0;
    _capacityController = TextEditingController(text: capacity.toString());

    // Default select first available slot
    for (final pile in widget.station.piles) {
      for (final slot in pile.slots) {
        if (slot.status == BatterySlotStatus.available) {
          selectedPileId = pile.pileId;
          selectedSlotId = slot.slotId;
          break;
        }
      }
      if (selectedSlotId != null) break;
    }
  }

  @override
  void dispose() {
    _capacityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  bool _canSelectSlot(BatterySlotModel slot) {
    if (slot.status == BatterySlotStatus.available) return true;
    if (slot.status == BatterySlotStatus.charging ||
        slot.status == BatterySlotStatus.swappedOut) {
      if (slot.estimatedFullAt != null && selectedArrivalTime != null) {
        return !slot.estimatedFullAt!.isAfter(selectedArrivalTime!);
      }
    }
    return false;
  }

  bool _isReadyByArrival(BatterySlotModel slot) {
    if (slot.status == BatterySlotStatus.available) return true;
    if ((slot.status == BatterySlotStatus.charging ||
            slot.status == BatterySlotStatus.swappedOut) &&
        slot.estimatedFullAt != null &&
        selectedArrivalTime != null) {
      return !slot.estimatedFullAt!.isAfter(selectedArrivalTime!);
    }
    return false;
  }

  String _formatSlotEta(DateTime utcTime) {
    final local = utcTime.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  String _buildSlotTooltip(BatterySlotModel slot) {
    switch (slot.status) {
      case BatterySlotStatus.available:
        return 'Slot ${slot.slotIndex}: Ready (100%)';
      case BatterySlotStatus.charging:
      case BatterySlotStatus.swappedOut:
        if (slot.estimatedFullAt == null) {
          return 'Slot ${slot.slotIndex}: Charging ${slot.batteryChargePercent}%';
        }
        final willBeReady = selectedArrivalTime != null &&
            !slot.estimatedFullAt!.isAfter(selectedArrivalTime!);
        return willBeReady
            ? 'Slot ${slot.slotIndex}: Will be 100% at ${_formatSlotEta(slot.estimatedFullAt!)} — selectable'
            : 'Slot ${slot.slotIndex}: Not ready by your arrival (${_formatSlotEta(slot.estimatedFullAt!)})';
      case BatterySlotStatus.reserved:
        return 'Slot ${slot.slotIndex}: Reserved by another user';
      case BatterySlotStatus.occupied:
        return 'Slot ${slot.slotIndex}: Occupied';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDuplicate = widget.hasActiveAtStation;

    return DraggableScrollableSheet(
      initialChildSize: 0.90,
      minChildSize: 0.5,
      maxChildSize: 0.98,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Book battery swap',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.station.name ?? 'Station'} · ${widget.station.basePriceVnd} VND/session',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              if (isDuplicate) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: Row(
                    children: [
                      FaIcon(FontAwesomeIcons.triangleExclamation,
                          color: Colors.orange.shade700, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You already have an active reservation at this station.',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: Colors.orange.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              // Arrival time — REQUIRED
              Text(
                'Arrival time (required)',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'We will hold your slot for 15 minutes from this time.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  selectedArrivalTime == null
                      ? 'Tap to select arrival time'
                      : 'Arrive at: ${_formatDateTimeLocal(selectedArrivalTime!)}',
                  style: selectedArrivalTime == null
                      ? theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.error)
                      : null,
                ),
                trailing: FaIcon(
                  selectedArrivalTime == null
                      ? FontAwesomeIcons.circleExclamation
                      : FontAwesomeIcons.clock,
                  size: 16,
                  color: selectedArrivalTime == null
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
                onTap: _pickArrivalTime,
              ),
              if (selectedArrivalTime != null)
                TextButton(
                  onPressed: () => setState(() => selectedArrivalTime = null),
                  child: const Text('Clear'),
                ),
              const SizedBox(height: 16),
              Text(
                'Select swap pile & slot',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (selectedArrivalTime == null) ...[
                const SizedBox(height: 8),
                Text(
                  'Select arrival time above to see which slots will be ready.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              _buildPileSlotGrid(theme),
              const SizedBox(height: 20),
              Text('Current battery: $requested%', style: theme.textTheme.bodyMedium),
              Slider(
                value: requested.toDouble(),
                min: 0,
                max: 100,
                divisions: 20,
                label: '$requested%',
                onChanged: (v) => setState(() => requested = v.round()),
              ),
              const SizedBox(height: 8),
              TextField(
                decoration:
                    const InputDecoration(labelText: 'Battery capacity (kWh)'),
                keyboardType: TextInputType.number,
                controller: _capacityController,
                onChanged: (v) {
                  final parsed = double.tryParse(v);
                  if (parsed != null && parsed > 0) capacity = parsed;
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  hintText: 'e.g. need a quick swap before 6:00 PM',
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: selectedArrivalTime == null ||
                              selectedSlotId == null ||
                              isDuplicate
                          ? null
                          : () => Navigator.pop(
                                context,
                                BatterySwapBookingResult(
                                  expectedArrivalAt: selectedArrivalTime!,
                                  requestedBatteryPercent: requested,
                                  batteryCapacityKwh: capacity,
                                  pileId: selectedPileId,
                                  slotId: selectedSlotId,
                                  note: _noteController.text.trim().isEmpty
                                      ? null
                                      : _noteController.text.trim(),
                                ),
                              ),
                      child: Text(
                        selectedArrivalTime == null
                            ? 'Select arrival time first'
                            : 'Confirm booking',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickArrivalTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: selectedArrivalTime ?? now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null) return;
    final tod = await showTimePicker(
      context: context,
      initialTime: selectedArrivalTime != null
          ? TimeOfDay.fromDateTime(selectedArrivalTime!)
          : TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (tod == null) return;
    setState(() {
      selectedArrivalTime = DateTime(
        date.year,
        date.month,
        date.day,
        tod.hour,
        tod.minute,
      );
    });
  }

  String _formatDateTimeLocal(DateTime dt) {
    return '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildPileSlotGrid(ThemeData theme) {
    return Column(
      children: widget.station.piles.map((pile) {
        final isSelected = pile.pileId == selectedPileId;
        final readyCount = pile.slots.where(_isReadyByArrival).length;
        final hasReady = readyCount > 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline.withValues(alpha: 0.3),
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
                      : theme.colorScheme.surface,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(11)),
                ),
                child: Row(
                  children: [
                    FaIcon(
                      FontAwesomeIcons.chargingStation,
                      size: 14,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Swap Pile ${pile.pileIndex}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color:
                            isSelected ? theme.colorScheme.primary : null,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      selectedArrivalTime != null
                          ? '$readyCount/${pile.slots.length} ready'
                          : '${pile.availableSlots}/${pile.slots.length} ready',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: hasReady
                            ? Colors.green
                            : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: pile.slots.map((slot) {
                    final isThisSelected = slot.slotId == selectedSlotId;
                    final isAvail = slot.status == BatterySlotStatus.available;
                    final isCharging = slot.status == BatterySlotStatus.charging ||
                        slot.status == BatterySlotStatus.swappedOut;
                    final isReserved = slot.status == BatterySlotStatus.reserved;
                    final canSelect = _canSelectSlot(slot);
                    final willBeReady = _isReadyByArrival(slot);
                    final etaText = (isCharging && slot.estimatedFullAt != null)
                        ? _formatSlotEta(slot.estimatedFullAt!)
                        : null;

                    return Tooltip(
                      message: _buildSlotTooltip(slot),
                      child: InkWell(
                        onTap: canSelect
                            ? () => setState(() {
                                  selectedPileId = pile.pileId;
                                  selectedSlotId = slot.slotId;
                                })
                            : null,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 52,
                          height: 56,
                          decoration: BoxDecoration(
                            color: canSelect && willBeReady
                                ? (isThisSelected
                                    ? Colors.green.shade200
                                    : Colors.green.shade50)
                                : isAvail
                                    ? Colors.green.shade50
                                    : isCharging
                                        ? Colors.orange.shade50
                                        : Colors.grey.shade100,
                            border: Border.all(
                              color: canSelect && willBeReady
                                  ? (isThisSelected
                                      ? Colors.green
                                      : Colors.green.shade300)
                                  : isAvail
                                      ? Colors.green.shade300
                                      : isCharging
                                          ? Colors.orange.shade300
                                          : Colors.grey.shade300,
                              width: isThisSelected ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (isCharging &&
                                  slot.batteryChargePercent < 100) ...[
                                SizedBox(
                                  width: 20,
                                  height: 12,
                                  child: LinearProgressIndicator(
                                    value: slot.batteryChargePercent / 100,
                                    backgroundColor: Colors.orange.shade200,
                                    valueColor: AlwaysStoppedAnimation(
                                        Colors.orange.shade700),
                                  ),
                                ),
                                const SizedBox(height: 2),
                              ],
                              FaIcon(
                                isAvail
                                    ? FontAwesomeIcons.batteryFull
                                    : isCharging
                                        ? FontAwesomeIcons.batteryHalf
                                        : isReserved
                                            ? FontAwesomeIcons.lock
                                            : FontAwesomeIcons.batteryEmpty,
                                size: 12,
                                color: canSelect && willBeReady
                                    ? Colors.green
                                    : isAvail
                                        ? Colors.green
                                        : isCharging
                                            ? Colors.orange
                                            : Colors.grey,
                              ),
                              const SizedBox(height: 1),
                              Text(
                                '${slot.batteryChargePercent}%',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontSize: 8,
                                  color: canSelect && willBeReady
                                      ? Colors.green.shade800
                                      : isAvail
                                          ? Colors.green
                                          : isCharging
                                              ? Colors.orange.shade800
                                              : theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.6),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (etaText != null && !isAvail) ...[
                                const SizedBox(height: 1),
                                Text(
                                  etaText,
                                  style:
                                      theme.textTheme.labelSmall?.copyWith(
                                    fontSize: 6,
                                    color: canSelect
                                        ? Colors.green.shade700
                                        : Colors.orange.shade700,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
