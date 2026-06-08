import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:shared_api/shared_api.dart';
import '../providers/station_providers.dart';
import '../providers/loyalty_providers.dart';
import '../widgets/main_scaffold.dart';
import '../models/battery_swap_models.dart';
import '../services/battery_swap_websocket_service.dart';

/// Screen for tracking battery swap reservations.
/// Navigated to after a successful booking, or from the bookings list.
class BatterySwapReservationScreen extends ConsumerStatefulWidget {
  final String? reservationId;

  const BatterySwapReservationScreen({super.key, this.reservationId});

  @override
  ConsumerState<BatterySwapReservationScreen> createState() =>
      _BatterySwapReservationScreenState();
}

class _BatterySwapReservationScreenState
    extends ConsumerState<BatterySwapReservationScreen> {
  StreamSubscription<SlotUpdateEvent>? _wsSubscription;
  StreamSubscription<SwapCompletedEvent>? _swapCompletedSubscription;
  String? _wsStationId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _swapCompletedSubscription?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    await ref.read(batterySwapProvider.notifier).loadMyReservations();
    _subscribeToWebSocket();
  }

  void _subscribeToWebSocket() {
    final ws = ref.read(batterySwapWsProvider);
    ws.addSlotUpdateListener(_onSlotUpdate);
    _wsSubscription = ws.onSlotUpdate().listen((_) {
      ref.read(batterySwapProvider.notifier).loadMyReservations();
    });
    _swapCompletedSubscription = ws.onSwapCompleted().listen((_) {
      ref.read(batterySwapProvider.notifier).loadMyReservations();
      ref.invalidate(loyaltyProfileProvider);
    });
    // Subscribe to all stations that have active reservations
    final state = ref.read(batterySwapProvider);
    for (final r in state.myReservations) {
      if (r.status == 'RESERVED' || r.status == 'SWAPPING') {
        ws.subscribeToStation(r.stationId);
        _wsStationId ??= r.stationId;
      }
    }
  }

  void _onSlotUpdate(SlotUpdateEvent event) {
    ref.read(batterySwapProvider.notifier).loadMyReservations();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(batterySwapProvider);
    final theme = Theme.of(context);

    return MainScaffold(
      showBottomNav: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My battery swaps'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: RefreshIndicator(
          onRefresh: () => ref.read(batterySwapProvider.notifier).loadMyReservations(),
          child: _buildBody(state, theme),
        ),
      ),
    );
  }

  Widget _buildBody(BatterySwapState state, ThemeData theme) {
    if (state.error != null && state.myReservations.isEmpty) {
      return ErrorState(
        message: formatApiError(state.error),
        onRetry: () => ref.read(batterySwapProvider.notifier).loadMyReservations(),
      );
    }

    if (state.myReservations.isEmpty) {
      return EmptyState(
        icon: FontAwesomeIcons.batteryEmpty,
        title: 'No reservations yet',
        message: 'Book a battery swap from a station page.',
        action: ElevatedButton.icon(
          onPressed: () => context.go('/home'),
          icon: const FaIcon(FontAwesomeIcons.map, size: 14),
          label: const Text('Find a station'),
        ),
      );
    }

    final highlightId = widget.reservationId;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: state.myReservations.length,
      itemBuilder: (context, index) {
        final r = state.myReservations[index];
        return _ReservationCard(
          key: ValueKey(r.id),
          reservation: r,
          isHighlighted: r.id == highlightId,
        );
      },
    );
  }
}

class _ReservationCard extends ConsumerStatefulWidget {
  final BatterySwapReservationModel reservation;
  final bool isHighlighted;

  const _ReservationCard({
    super.key,
    required this.reservation,
    this.isHighlighted = false,
  });

  @override
  ConsumerState<_ReservationCard> createState() => _ReservationCardState();
}

class _ReservationCardState extends ConsumerState<_ReservationCard> {
  String? _previousSlotStatus;

  @override
  void initState() {
    super.initState();
    _previousSlotStatus = widget.reservation.slotStatus;
  }

  @override
  void didUpdateWidget(_ReservationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _previousSlotStatus = oldWidget.reservation.slotStatus;
  }

  bool get _slotJustBecameAvailable {
    final current = widget.reservation.slotStatus;
    final prev = _previousSlotStatus;
    return current == 'AVAILABLE' && prev != 'AVAILABLE';
  }

  @override
  Widget build(BuildContext context) {
    final reservation = widget.reservation;
    final theme = Theme.of(context);
    final status = reservation.status;
    final stationName = reservation.stationName;
    final arrivalTime = reservation.reservedSlotAt;
    final confirmedArrival = reservation.confirmedArrivalAt;
    final reservedAt = reservation.reservedAt;
    final paymentStatus = reservation.paymentStatus;
    final isPaid = paymentStatus == 'PAID';
    final isReserved = status == 'RESERVED';
    final isSwapping = status == 'SWAPPING';
    final isCompleted = status == 'COMPLETED';
    final hasArrived = confirmedArrival != null;

    final showSlotReadyBanner = _slotJustBecameAvailable &&
        (isReserved && hasArrived || isSwapping);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: widget.isHighlighted
            ? Border.all(color: theme.colorScheme.primary, width: 2)
            : null,
      ),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showSlotReadyBanner) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: Row(
                    children: [
                      FaIcon(FontAwesomeIcons.batteryFull,
                          color: Colors.green.shade700, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          reservation.pileIndex != null
                              ? 'Your slot ${reservation.slotIndex} is ready! '
                                  'Please insert your battery.'
                              : 'Your slot is ready! '
                                  'Please insert your battery.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            FaIcon(
                              FontAwesomeIcons.batteryFull,
                              size: 14,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                stationName ?? 'Station',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (reservation.pileIndex != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Pile ${reservation.pileIndex} · Slot ${reservation.slotIndex ?? '?'}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  StatusPill(
                    label: _statusLabel(status),
                    color: _statusColor(status),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (arrivalTime != null) ...[
                _buildInfoRow(
                  theme,
                  FontAwesomeIcons.clock,
                  'Arrive by',
                  _formatDateTime(arrivalTime.toLocal()),
                ),
                const SizedBox(height: 6),
              ],
              _buildInfoRow(
                theme,
                FontAwesomeIcons.dollarSign,
                'Fee',
                reservation.voucherRedemptionId != null && (reservation.discountAmountVnd ?? 0) > 0
                    ? '${_formatAmt(reservation.basePriceVnd - (reservation.discountAmountVnd ?? 0))} VND'
                    : '${_formatAmt(reservation.basePriceVnd)} VND',
              ),
              if (reservation.voucherRedemptionId != null && (reservation.discountAmountVnd ?? 0) > 0) ...[
                const SizedBox(height: 6),
                _buildInfoRow(
                  theme,
                  FontAwesomeIcons.ticketSimple,
                  'Voucher',
                  '-${_formatAmt(reservation.discountAmountVnd ?? 0)} VND',
                ),
              ],
              const SizedBox(height: 6),
              _buildInfoRow(
                theme,
                FontAwesomeIcons.creditCard,
                'Payment',
                _paymentLabel(paymentStatus),
              ),
              if (reservation.requestedBatteryPercent > 0) ...[
                const SizedBox(height: 6),
                _buildInfoRow(
                  theme,
                  FontAwesomeIcons.batteryHalf,
                  'Your battery',
                  '${reservation.requestedBatteryPercent}% (will be charged)',
                ),
              ],

              // New battery charge indicator (SWAPPING — shows current slot charge)
              if (isSwapping && reservation.slotBatteryChargePercent != null) ...[
                const SizedBox(height: 6),
                _buildInfoRow(
                  theme,
                  FontAwesomeIcons.batteryFull,
                  'New battery',
                  '${reservation.slotBatteryChargePercent}%',
                ),
              ],

              // Slot ready info after arrival (RESERVED + PAID + arrived, before swapping)
              if (isReserved && isPaid && hasArrived && !isSwapping) ...[
                const SizedBox(height: 6),
                _buildInfoRow(
                  theme,
                  FontAwesomeIcons.locationDot,
                  'Go to',
                  reservation.pileIndex != null
                      ? 'Pile ${reservation.pileIndex} · Slot ${reservation.slotIndex ?? '?'}'
                      : 'Your assigned slot',
                ),
              ],

              // Hold countdown (RESERVED + PAID)
              if (isReserved && isPaid && !isSwapping && confirmedArrival != null)
                _CountdownWidget(
                  label: 'Hold expires in:',
                  from: confirmedArrival.add(const Duration(minutes: 15)),
                  expiredLabel: 'Hold expired',
                  onExpired: () =>
                      ref.read(batterySwapProvider.notifier).loadMyReservations(),
                ),

              // Swap countdown (SWAPPING — within 15 min of arrival)
              if (isSwapping && confirmedArrival != null)
                _CountdownWidget(
                  label: 'Swap must start in:',
                  from: confirmedArrival.add(const Duration(minutes: 15)),
                  expiredLabel: 'Swap expired',
                  onExpired: () =>
                      ref.read(batterySwapProvider.notifier).loadMyReservations(),
                ),

              // User's old battery charging progress (COMPLETED)
              if (isCompleted && reservation.estimatedReadyAt != null) ...[
                const SizedBox(height: 8),
                _UserOldBatteryCharging(
                  startPercent: reservation.requestedBatteryPercent,
                  estimatedReadyAt: reservation.estimatedReadyAt!.toLocal(),
                ),
              ],

              const SizedBox(height: 12),
              _buildActionButtons(context,
                  isReserved: isReserved,
                  isPaid: isPaid,
                  isSwapping: isSwapping,
                  isCompleted: isCompleted,
                  arrived: hasArrived),

              // Points earned banner when completed
              if (isCompleted) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: Row(
                    children: [
                      FaIcon(FontAwesomeIcons.sackDollar,
                          color: Colors.green.shade700, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Congratulations!',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                            Text(
                              'You earned +30 loyalty points for this swap',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(ThemeData theme, IconData icon, String label, String value) {
    return Row(
      children: [
        FaIcon(icon, size: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        Text(value, style: theme.textTheme.bodySmall),
      ],
    );
  }

  Widget _buildActionButtons(
    BuildContext context, {
    required bool isReserved,
    required bool isPaid,
    required bool isSwapping,
    required bool isCompleted,
    required bool arrived,
  }) {
    // Completed — no actions
    if (isCompleted) return const SizedBox.shrink();

    final notifier = ref.read(batterySwapProvider.notifier);
    final reservationId = widget.reservation.id;

    final hasAppliedVoucher = widget.reservation.voucherRedemptionId != null && (widget.reservation.discountAmountVnd ?? 0) > 0;
    final isFree = hasAppliedVoucher && widget.reservation.discountAmountVnd! >= widget.reservation.basePriceVnd;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // RESERVED + UNPAID → Show payment status or free voucher badge
        if (isReserved && !isPaid) ...[
          if (isFree) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const FaIcon(FontAwesomeIcons.checkCircle, color: Colors.green, size: 14),
                  const SizedBox(width: 6),
                  const Text(
                    'Free (Voucher)',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            if (!hasAppliedVoucher) ...[
              ElevatedButton.icon(
                onPressed: () => _showSwapVoucherSelector(context, reservationId),
                icon: const FaIcon(FontAwesomeIcons.ticketSimple, size: 12),
                label: const Text('Apply Voucher'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade100,
                  foregroundColor: Colors.orange.shade800,
                ),
              ),
            ],
            ElevatedButton.icon(
              onPressed: () => _runAction(
                context,
                label: 'Pay for battery swap',
                action: () => notifier.pay(reservationId),
                successMsg: 'Payment successful.',
              ),
              icon: const FaIcon(FontAwesomeIcons.creditCard, size: 12),
              label: Text(hasAppliedVoucher
                  ? 'Pay remaining'
                  : 'Pay now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],

        // RESERVED + PAID + not arrived yet → "I'm here"
        if (isReserved && isPaid && !arrived)
          ElevatedButton.icon(
            onPressed: () => _runAction(
              context,
              label: 'Confirm arrival',
              action: () => notifier.confirmArrival(reservationId),
              successMsg: 'Arrival confirmed. Please start the swap.',
            ),
            icon: const FaIcon(FontAwesomeIcons.locationDot, size: 12),
            label: const Text("I'm here"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),

        // RESERVED + PAID + arrived → "Start Swap" (calls backend to generate code + broadcast to simulator)
        if (isReserved && isPaid && arrived)
          ElevatedButton.icon(
            onPressed: () => _runAction(
              context,
              label: 'Start Swap',
              action: () async {
                final result = await notifier.start(reservationId);
                if (context.mounted) {
                  _showSwapCodeDialogFromReservation(context, reservationId, result);
                }
              },
              successMsg: 'Swap code shown. Enter it on the HW Simulator and confirm on this app.',
            ),
            icon: const FaIcon(FontAwesomeIcons.key, size: 12),
            label: const Text('Start Swap'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),

        // SWAPPING → Show "Verifying..." spinner (swap in progress)
        if (isSwapping)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade300),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.orange.shade700,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Verifying...',
                  style: TextStyle(
                    color: Colors.orange.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

        if (isReserved || isSwapping)
          TextButton.icon(
            onPressed: () => _confirmAndCancel(context),
            icon: const FaIcon(FontAwesomeIcons.xmark, size: 12),
            label: const Text('Cancel'),
          ),
      ],
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  String _paymentLabel(String paymentStatus) {
    switch (paymentStatus) {
      case 'PAID': return 'Paid';
      case 'REFUNDED': return 'Refunded';
      default: return 'Unpaid';
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'RESERVED': return 'Reserved';
      case 'SWAPPING': return 'Swapping';
      case 'COMPLETED': return 'Completed';
      case 'CANCELLED': return 'Cancelled';
      case 'EXPIRED': return 'Expired';
      default: return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'RESERVED': return Colors.blue;
      case 'SWAPPING': return Colors.orange;
      case 'COMPLETED': return Colors.green;
      case 'CANCELLED': return Colors.grey;
      case 'EXPIRED': return Colors.deepOrange;
      default: return Colors.blueGrey;
    }
  }

  String _formatAmt(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  Future<void> _runAction(
    BuildContext context, {
    required String label,
    required Future<void> Function() action,
    required String successMsg,
  }) async {
    try {
      await action();
      if (context.mounted) AppToast.showSuccess(context, successMsg);
    } catch (e) {
      if (context.mounted) {
        AppToast.showError(context, '$label failed: ${formatApiError(e)}');
      }
    }
  }

  void _showSwapVoucherSelector(BuildContext context, String reservationId) async {
    final vouchersAsync = ref.read(myVouchersProvider('REDEEMED'));
    final state = vouchersAsync.valueOrNull;
    if (state == null || state.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No free battery swap vouchers available. Earn some from the Loyalty page!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final freeSwapVouchers = state.where((v) {
      final def = v.definition;
      return def?.voucherType == 'FREE_SERVICE' && def?.serviceType == 'BATTERY_SWAP';
    }).toList();

    if (freeSwapVouchers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No free battery swap vouchers available. Earn some from the Loyalty page!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, controller) => _SwapVoucherSelectorSheet(
          vouchers: freeSwapVouchers,
          onApply: (voucher) async {
            Navigator.pop(ctx);
            try {
              await ref.read(applyVoucherProvider.notifier).applyToSwap(voucher.id, reservationId);
              ref.read(batterySwapProvider.notifier).loadMyReservations();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Voucher applied! Battery swap is now free.'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to apply voucher: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
        ),
      ),
    );
  }

  Future<void> _confirmAndCancel(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel reservation?'),
        content: const Text(
            'Are you sure you want to cancel this battery swap reservation? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Cancel reservation')),
        ],
      ),
    );
    if (ok != true) return;

    await _runAction(
      context,
      label: 'Cancel reservation',
      action: () =>
          ref.read(batterySwapProvider.notifier).cancel(widget.reservation.id),
      successMsg: 'Reservation cancelled.',
    );
  }

  Future<void> _showSwapCodeDialogFromReservation(
    BuildContext context,
    String reservationId,
    BatterySwapReservationModel reservation,
  ) async {
    String? swapCode = reservation.swapCode;
    DateTime? deadlineAt = reservation.swapDeadlineAt;
    int? pileIndex = reservation.pileIndex;
    int? slotIndex = reservation.slotIndex;
    String enteredCode = '';
    bool isLoading = false;
    String? error;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                FaIcon(FontAwesomeIcons.key, color: Colors.green.shade700),
                const SizedBox(width: 8),
                const Expanded(child: Text('Swap Code')),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (pileIndex != null)
                  Text(
                    'Pile $pileIndex · Slot ${slotIndex ?? '?'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (deadlineAt != null) ...[
                  const SizedBox(height: 8),
                  _SwapCodeCountdownWidget(
                    label: 'Code expires in:',
                    from: deadlineAt.toLocal(),
                    expiredLabel: 'Code expired',
                    onExpired: () {
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      FaIcon(FontAwesomeIcons.infoCircle, size: 16, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Enter the code shown on the HW Simulator',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.blue.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  key: ValueKey('swapCodeInput'),
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 8),
                  decoration: InputDecoration(
                    hintText: 'Enter code',
                    counterText: '',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade400),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade400),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.green.shade700, width: 2),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red),
                    ),
                  ),
                  onChanged: (value) {
                    setDialogState(() {
                      enteredCode = value;
                      error = null;
                    });
                  },
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    error!,
                    style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isLoading || enteredCode.length != 4
                    ? null
                    : () async {
                        setDialogState(() {
                          isLoading = true;
                          error = null;
                        });
                        try {
                          await ref.read(batterySwapProvider.notifier)
                              .verifySwap(reservationId, enteredCode);
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            await _showSwapSuccessDialog(context);
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            setDialogState(() {
                              isLoading = false;
                              error = formatApiError(e);
                            });
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Confirm Swap'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showSwapCodeDialog(BuildContext context, String reservationId) async {
    final notifier = ref.read(batterySwapProvider.notifier);
    String? swapCode;
    DateTime? deadlineAt;
    String? stationName;
    int? pileIndex;
    int? slotIndex;
    bool isLoading = true;
    String? error;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          // Initial load
          if (isLoading && error == null) {
            Future.microtask(() async {
              try {
                final result = await notifier.getSwapCode(reservationId);
                if (ctx.mounted) {
                  setDialogState(() {
                    swapCode = result['swapCode'] as String?;
                    deadlineAt = result['deadlineAt'] != null
                        ? DateTime.tryParse(result['deadlineAt'].toString())
                        : null;
                    stationName = result['stationName'] as String?;
                    pileIndex = (result['pileIndex'] as num?)?.toInt();
                    slotIndex = (result['slotIndex'] as num?)?.toInt();
                    isLoading = false;
                  });
                }
              } catch (e) {
                if (ctx.mounted) {
                  setDialogState(() {
                    error = formatApiError(e);
                    isLoading = false;
                  });
                }
              }
            });
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                FaIcon(FontAwesomeIcons.key, color: Colors.green.shade700),
                const SizedBox(width: 8),
                const Expanded(child: Text('Swap Code')),
              ],
            ),
            content: isLoading
                ? const SizedBox(
                    height: 120,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : error != null
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FaIcon(FontAwesomeIcons.triangleExclamation,
                              size: 48, color: Colors.red.shade400),
                          const SizedBox(height: 12),
                          Text(error!, textAlign: TextAlign.center),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Enter this code at the station terminal',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 12),
                          if (pileIndex != null)
                            Text(
                              'Pile $pileIndex · Slot ${slotIndex ?? '?'}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          if (deadlineAt != null) ...[
                            const SizedBox(height: 12),
                            _SwapCodeCountdownWidget(
                              label: 'Code expires in:',
                              from: deadlineAt!,
                              expiredLabel: 'Code expired',
                              onExpired: () {
                                if (ctx.mounted) Navigator.pop(ctx);
                              },
                            ),
                          ],
                        ],
                      ),
            actions: error != null
                ? [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Close'),
                    ),
                  ]
                : [
                    TextButton(
                      onPressed: () async {
                        setDialogState(() {
                          isLoading = true;
                          error = null;
                        });
                        try {
                          final result = await notifier.getSwapCode(reservationId);
                          if (ctx.mounted) {
                            setDialogState(() {
                              swapCode = result['swapCode'] as String?;
                              deadlineAt = result['deadlineAt'] != null
                                  ? DateTime.tryParse(
                                      result['deadlineAt'].toString())
                                  : null;
                              stationName = result['stationName'] as String?;
                              pileIndex = (result['pileIndex'] as num?)?.toInt();
                              slotIndex = (result['slotIndex'] as num?)?.toInt();
                              isLoading = false;
                            });
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            setDialogState(() {
                              error = formatApiError(e);
                              isLoading = false;
                            });
                          }
                        }
                      },
                      child: const Text('Refresh Code'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Done'),
                    ),
                  ],
          );
        },
      ),
    );
  }

  Future<void> _showSwapSuccessDialog(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                shape: BoxShape.circle,
              ),
              child: FaIcon(FontAwesomeIcons.check,
                  size: 48, color: Colors.green.shade700),
            ),
            const SizedBox(height: 16),
            Text(
              'Swap Successful!',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your old battery is now charging',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.green.shade700,
                  ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Great!'),
          ),
        ],
      ),
    );
  }
}

/// Countdown widget specifically for swap code display with prominent styling.
class _SwapCodeCountdownWidget extends StatefulWidget {
  final String label;
  final DateTime from;
  final String expiredLabel;
  final VoidCallback onExpired;

  const _SwapCodeCountdownWidget({
    required this.label,
    required this.from,
    required this.expiredLabel,
    required this.onExpired,
  });

  @override
  State<_SwapCodeCountdownWidget> createState() => _SwapCodeCountdownWidgetState();
}

class _SwapCodeCountdownWidgetState extends State<_SwapCodeCountdownWidget> {
  late final Stream<int> _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Stream.periodic(const Duration(seconds: 1),
        (_) => widget.from.difference(DateTime.now()).inSeconds)
        .takeWhile((seconds) => seconds >= 0);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _ticker,
      builder: (context, snapshot) {
        final seconds = snapshot.data ?? widget.from.difference(DateTime.now()).inSeconds;
        final isExpired = seconds < 0;

        if (isExpired && snapshot.connectionState == ConnectionState.done) {
          WidgetsBinding.instance.addPostFrameCallback((_) => widget.onExpired());
        }

        final color = isExpired
            ? Colors.deepOrange
            : seconds < 60
                ? Colors.red
                : Colors.orange;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FaIcon(
                isExpired ? FontAwesomeIcons.clock : FontAwesomeIcons.hourglassHalf,
                size: 14,
                color: color,
              ),
              const SizedBox(width: 8),
              Text(
                isExpired
                    ? widget.expiredLabel
                    : '${widget.label} ${_formatDuration(Duration(seconds: seconds))}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }
}

class _SwapVoucherSelectorSheet extends StatelessWidget {
  final List<VoucherRedemption> vouchers;
  final void Function(VoucherRedemption) onApply;

  const _SwapVoucherSelectorSheet({
    required this.vouchers,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Free Battery Swap Vouchers',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'These vouchers make your battery swap completely free.',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: vouchers.length,
              itemBuilder: (context, index) {
                final voucher = vouchers[index];
                final def = voucher.definition;

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => onApply(voucher),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.battery_charging_full,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  def?.name ?? 'Free Battery Swap',
                                  style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  def?.description ?? '',
                                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'FREE',
                                        style: TextStyle(
                                          color: Colors.green[700],
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Expires: ${_formatDateShort(voucher.expiresAt)}',
                                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          FaIcon(
                            FontAwesomeIcons.chevronRight,
                            size: 14,
                            color: Colors.grey[400],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateShort(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

/// Shows the charging progress of the user's old battery after swap completion.
class _UserOldBatteryCharging extends StatefulWidget {
  final int startPercent;
  final DateTime estimatedReadyAt;

  const _UserOldBatteryCharging({
    required this.startPercent,
    required this.estimatedReadyAt,
  });

  @override
  State<_UserOldBatteryCharging> createState() => _UserOldBatteryChargingState();
}

class _UserOldBatteryChargingState extends State<_UserOldBatteryCharging> {
  late final Stream<int> _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Stream.periodic(const Duration(seconds: 1),
        (_) => _calcProgress()).takeWhile((_) => true);
  }

  int _calcProgress() {
    final now = DateTime.now();
    if (now.isAfter(widget.estimatedReadyAt)) return 100;
    final totalMs = widget.estimatedReadyAt.difference(now).inMilliseconds;
    if (totalMs <= 0) return 100;
    final elapsed = Duration(minutes: 30).inMilliseconds - totalMs;
    // Approximate: assume 30-min charge duration from startPercent to 100%
    final progress = widget.startPercent + ((100 - widget.startPercent) * elapsed / Duration(minutes: 30).inMilliseconds);
    return progress.clamp(widget.startPercent, 100).round();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final isReady = now.isAfter(widget.estimatedReadyAt);
    final progress = isReady ? 100 : _calcProgress();

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FaIcon(
                isReady ? FontAwesomeIcons.batteryFull : FontAwesomeIcons.batteryHalf,
                size: 14,
                color: isReady ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Your old battery is charging',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.orange.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                isReady ? 'Ready!' : '$progress%',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isReady ? Colors.green : Colors.orange.shade800,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (!isReady) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress / 100,
                backgroundColor: Colors.orange.shade200,
                valueColor: AlwaysStoppedAnimation(Colors.orange.shade700),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Full at ${widget.estimatedReadyAt.hour.toString().padLeft(2, '0')}:'
              '${widget.estimatedReadyAt.minute.toString().padLeft(2, '0')}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.orange.shade700,
              ),
            ),
          ] else
            Text(
              'Pick it up at the station anytime.',
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.green.shade800,
              ),
            ),
        ],
      ),
    );
  }
}

class _CountdownWidget extends StatefulWidget {
  final String label;
  final DateTime from;
  final String expiredLabel;
  final VoidCallback onExpired;

  const _CountdownWidget({
    required this.label,
    required this.from,
    required this.expiredLabel,
    required this.onExpired,
  });

  @override
  State<_CountdownWidget> createState() => _CountdownWidgetState();
}

class _CountdownWidgetState extends State<_CountdownWidget> {
  late final Stream<int> _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Stream.periodic(const Duration(seconds: 1),
        (_) => widget.from.difference(DateTime.now()).inSeconds)
        .takeWhile((seconds) => seconds >= 0);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _ticker,
      builder: (context, snapshot) {
        final seconds = snapshot.data ?? widget.from.difference(DateTime.now()).inSeconds;
        final isExpired = seconds < 0;

        if (isExpired && snapshot.connectionState == ConnectionState.done) {
          WidgetsBinding.instance.addPostFrameCallback((_) => widget.onExpired());
        }

        final color = isExpired
            ? Colors.deepOrange
            : seconds < 60
                ? Colors.red
                : Colors.orange;

        return Container(
          margin: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              FaIcon(
                isExpired ? FontAwesomeIcons.clock : FontAwesomeIcons.hourglassHalf,
                size: 12,
                color: color,
              ),
              const SizedBox(width: 6),
              Text(
                isExpired
                    ? widget.expiredLabel
                    : '${widget.label} ${_formatDuration(Duration(seconds: seconds))}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }
}
