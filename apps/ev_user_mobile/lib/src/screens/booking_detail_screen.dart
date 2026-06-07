import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:shared_api/shared_api.dart';
import '../providers/booking_providers.dart';
import '../providers/station_providers.dart';
import '../providers/loyalty_providers.dart';

/// Booking Detail Screen
class BookingDetailScreen extends ConsumerStatefulWidget {
  final String bookingId;

  const BookingDetailScreen({
    super.key,
    required this.bookingId,
  });

  @override
  ConsumerState<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends ConsumerState<BookingDetailScreen> {
  Timer? _countdownTimer;
  Duration? _remainingTime;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _paymentSectionKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }


  @override
  void dispose() {
    _countdownTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToPaymentSection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_paymentSectionKey.currentContext != null) {
        Scrollable.ensureVisible(
          _paymentSectionKey.currentContext!,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final bookingAsync = ref.read(bookingDetailProvider(widget.bookingId));
      bookingAsync.whenData((booking) {
        final status = booking['status'] as String? ?? '';
        if (status == 'HOLD') {
          final holdExpiresAt = _parseDateTime(booking['holdExpiresAt'] as String?);
          if (holdExpiresAt != null) {
            final now = DateTime.now();
            final remaining = holdExpiresAt.difference(now);
            if (remaining.isNegative) {
              setState(() {
                _remainingTime = Duration.zero;
              });
              timer.cancel();
              // Refresh booking to get updated status
              ref.invalidate(bookingDetailProvider(widget.bookingId));
            } else {
              setState(() {
                _remainingTime = remaining;
              });
            }
          }
        } else {
          timer.cancel();
        }
      });
    });
  }

  void _handleClose(BuildContext context) {
    final bookingAsync = ref.read(bookingDetailProvider(widget.bookingId));
    final status = bookingAsync.value?['status'] as String? ?? '';
    
    // If booking is CONFIRMED (payment success), navigate to home
    if (status == 'CONFIRMED') {
      context.go('/home');
    } else {
      // Otherwise, just pop back
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookingAsync = ref.watch(bookingDetailProvider(widget.bookingId));
    final theme = Theme.of(context);
    
    // Get stationId from booking to fetch station info
    final stationId = bookingAsync.value?['stationId'] as String?;

    return AppScaffold(
      title: 'Booking details',
      actions: [
        IconButton(
          icon: const FaIcon(FontAwesomeIcons.xmark),
          onPressed: () => _handleClose(context),
          tooltip: 'Close',
        ),
      ],
      body: bookingAsync.when(
        loading: () =>
            const LoadingState(message: 'Loading booking details...'),
        error: (e, st) => ErrorState(
          title: 'Could not load booking',
          message: formatApiError(e),
          code: extractErrorCode(e),
          traceId: extractTraceId(e),
          onRetry: () =>
              ref.invalidate(bookingDetailProvider(widget.bookingId)),
        ),
        data: (booking) {
          final stationId = booking['stationId'] as String?;
          return RefreshIndicator(
            onRefresh: () => ref.refresh(bookingDetailProvider(widget.bookingId).future),
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context, booking, theme),
                  const SizedBox(height: 24),
                  _buildBookingInfo(context, booking, theme, stationId),
                  const SizedBox(height: 24),
                  Container(
                    key: _paymentSectionKey,
                    child: _buildPaymentSection(context, booking, theme),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Map<String, dynamic> booking, ThemeData theme) {
    final id = booking['id'] as String? ?? '';
    final status = booking['status'] as String? ?? 'UNKNOWN';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Booking #${id.substring(0, 8)}',
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
                StatusPill(
                  label: status,
                  colorMapper: (status) {
                    switch (status) {
                      case 'HOLD':
                        return Colors.orange;
                      case 'CONFIRMED':
                        return Colors.green;
                      case 'CANCELLED':
                      case 'EXPIRED':
                        return Colors.red;
                      default:
                        return Colors.grey;
                    }
                  },
                ),
              ],
            ),
            if (status == 'HOLD' && _remainingTime != null) ...[
              const SizedBox(height: 16),
              _buildCountdown(context, theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCountdown(BuildContext context, ThemeData theme) {
    final minutes = _remainingTime!.inMinutes;
    final seconds = _remainingTime!.inSeconds % 60;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          FaIcon(
            FontAwesomeIcons.clock,
            color: theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 12),
          Text(
            'Hold expires in: ${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onErrorContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingInfo(
    BuildContext context,
    Map<String, dynamic> booking,
    ThemeData theme,
    String? stationId,
  ) {
    final startTime = _parseDateTime(booking['startTime'] as String?);
    final endTime = _parseDateTime(booking['endTime'] as String?);
    final createdAt = _parseDateTime(booking['createdAt'] as String?);
    final status = booking['status'] as String? ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Booking Information',
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        InfoCard(
          children: [
            // Station information
            if (stationId != null)
              _buildStationInfo(context, theme, stationId),
            if (stationId != null && (startTime != null || endTime != null || createdAt != null))
              const Divider(height: 24),
            if (startTime != null)
              _buildInfoRow(
                theme,
                FontAwesomeIcons.calendar,
                'Start Time',
                _formatDateTime(startTime),
              ),
            if (endTime != null)
              _buildInfoRow(
                theme,
                FontAwesomeIcons.calendar,
                'End Time',
                _formatDateTime(endTime),
              ),
            if (createdAt != null)
              _buildInfoRow(
                theme,
                FontAwesomeIcons.clock,
                'Created At',
                _formatDateTime(createdAt),
              ),
          ],
        ),
        if (status == 'HOLD' || status == 'CONFIRMED') ...[
          const SizedBox(height: 16),
          SecondaryButton(
            label: 'Cancel Booking',
            onPressed: () => _cancelBooking(context, booking),
          ),
        ],
      ],
    );
  }

  Widget _buildPaymentSection(
    BuildContext context,
    Map<String, dynamic> booking,
    ThemeData theme,
  ) {
    final status = booking['status'] as String? ?? '';
    final priceSnapshot = booking['priceSnapshot'] as Map<String, dynamic>?;
    final voucherRedemptionId = booking['voucherRedemptionId'] as String?;
    final localPaymentIntent = ref.read(paymentIntentProvider(widget.bookingId));
    final bookingPaymentIntent = booking['paymentIntent'] as Map<String, dynamic>?;
    final paymentIntent = localPaymentIntent ?? bookingPaymentIntent;

    if (status != 'HOLD') {
      return const SizedBox.shrink();
    }

    final originalAmount = priceSnapshot?['amount'] as int? ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment',
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 12),

        // Price breakdown card
        _buildPriceBreakdownCard(context, booking, paymentIntent, theme),

        const SizedBox(height: 12),

        // Voucher section
        _buildVoucherSection(
          context,
          booking,
          voucherRedemptionId,
          originalAmount,
          theme,
        ),

        const SizedBox(height: 16),

        if (paymentIntent == null) ...[
          PrimaryButton(
            label: 'Create Payment Intent',
            onPressed: () => _createPaymentIntent(context),
          ),
        ] else ...[
          _buildPaymentIntentInfo(context, paymentIntent, theme),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  label: 'Simulate Success',
                  onPressed: () => _simulatePaymentSuccess(context, paymentIntent),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SecondaryButton(
                  label: 'Simulate Fail',
                  onPressed: () => _simulatePaymentFail(context, paymentIntent),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildPriceBreakdownCard(
    BuildContext context,
    Map<String, dynamic> booking,
    Map<String, dynamic>? paymentIntent,
    ThemeData theme,
  ) {
    final priceSnapshot = booking['priceSnapshot'] as Map<String, dynamic>?;
    final voucherRedemptionId = booking['voucherRedemptionId'] as String?;
    final discountAmount = paymentIntent?['discountAmount'] as int? ?? 0;
    final finalAmount = paymentIntent?['amount'] as int? ??
        (priceSnapshot?['amount'] as int? ?? 0);

    final hasDiscount = voucherRedemptionId != null && discountAmount > 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Price Breakdown',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              theme,
              FontAwesomeIcons.bolt,
              'Unit',
              priceSnapshot?['unitLabel'] as String? ?? '-',
            ),
            _buildInfoRow(
              theme,
              FontAwesomeIcons.chargingStation,
              'Power',
              '${priceSnapshot?['powerKw'] ?? 0} kW ${priceSnapshot?['powerType'] ?? ''}',
            ),
            _buildInfoRow(
              theme,
              FontAwesomeIcons.clock,
              'Duration',
              '${priceSnapshot?['durationMinutes'] ?? 0} min (${priceSnapshot?['slotCount'] ?? 0} slots)',
            ),
            const Divider(),
            _buildInfoRow(
              theme,
              FontAwesomeIcons.tag,
              'Original Price',
              '${_formatAmount(priceSnapshot?['amount'] as int? ?? 0)} VND',
            ),
            if (hasDiscount) ...[
              _buildInfoRow(
                theme,
                FontAwesomeIcons.tag,
                'Voucher Discount',
                '-${_formatAmount(discountAmount)} VND',
                valueColor: Colors.green,
              ),
              const Divider(),
              _buildInfoRow(
                theme,
                FontAwesomeIcons.solidMoneyBill1,
                'Final Amount',
                '${_formatAmount(finalAmount)} VND',
                valueColor: theme.colorScheme.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVoucherSection(
    BuildContext context,
    Map<String, dynamic> booking,
    String? voucherRedemptionId,
    int originalAmount,
    ThemeData theme,
  ) {
    final vouchersAsync = ref.watch(myVouchersProvider('REDEEMED'));
    final applyState = ref.watch(applyVoucherProvider);
    final hasAppliedVoucher = voucherRedemptionId != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                FaIcon(
                  FontAwesomeIcons.ticketSimple,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Voucher',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (hasAppliedVoucher) ...[
              vouchersAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
                data: (vouchers) {
                  final applied = vouchers.where((v) => v.id == voucherRedemptionId).toList();
                  if (applied.isEmpty) {
                    return Text(
                      'Voucher applied',
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.green),
                    );
                  }
                  final v = applied.first;
                  final def = v.definition;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  def?.name ?? 'Voucher',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Code: ${v.voucherCode}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const FaIcon(FontAwesomeIcons.check, color: Colors.green, size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  'Applied',
                                  style: TextStyle(color: Colors.green[700], fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: applyState.isLoading
                            ? null
                            : () => _showRemoveVoucherConfirm(context, voucherRedemptionId),
                        child: Text(
                          'Remove Voucher',
                          style: TextStyle(color: Colors.red[400], fontSize: 13),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ] else ...[
              vouchersAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text(
                  'Could not load vouchers',
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.red),
                ),
                data: (vouchers) {
                  final available = vouchers.where((v) {
                    final def = v.definition;
                    // Show PERCENT_DISCOUNT vouchers and FREE_SERVICE/CHARGING vouchers
                    if (def?.voucherType == 'PERCENT_DISCOUNT') return true;
                    if (def?.voucherType == 'FREE_SERVICE' &&
                        (def?.serviceType == 'CHARGING' || def?.serviceType == null)) return true;
                    return false;
                  }).toList();

                  if (available.isEmpty) {
                    return Text(
                      'No available vouchers. Visit Loyalty page to earn some!',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${available.length} voucher(s) available',
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: applyState.isLoading
                              ? null
                              : () => _showVoucherSelector(context, available, originalAmount),
                          icon: applyState.isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const FaIcon(FontAwesomeIcons.plus, size: 14),
                          label: const Text('Apply Voucher'),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showVoucherSelector(
    BuildContext context,
    List<VoucherRedemption> vouchers,
    int originalAmount,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) => _VoucherSelectorSheet(
          vouchers: vouchers,
          originalAmount: originalAmount,
          onApply: (voucher) async {
            Navigator.pop(ctx);
            await _applyVoucher(context, voucher.id);
          },
        ),
      ),
    );
  }

  void _showRemoveVoucherConfirm(BuildContext context, String voucherRedemptionId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Voucher'),
        content: const Text('Are you sure you want to remove this voucher from this booking?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // NOTE: Backend does not have a remove-voucher endpoint yet.
    // The best approach is to cancel this booking and re-create without voucher.
    // For now, show a message.
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please cancel this booking and create a new one without the voucher.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _applyVoucher(BuildContext context, String redemptionId) async {
    try {
      await ref.read(applyVoucherProvider.notifier).applyToBooking(redemptionId, widget.bookingId);
      ref.invalidate(bookingDetailProvider(widget.bookingId));
      ref.invalidate(paymentIntentProvider(widget.bookingId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Voucher applied successfully!'),
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
  }

  Widget _buildPaymentIntentInfo(
    BuildContext context,
    Map<String, dynamic> paymentIntent,
    ThemeData theme,
  ) {
    final amount = paymentIntent['amount'] as int? ?? 0;
    final currency = paymentIntent['currency'] as String? ?? 'VND';
    final paymentStatus = paymentIntent['status'] as String? ?? '';
    final discountAmount = paymentIntent['discountAmount'] as int?;
    final hasDiscount = discountAmount != null && discountAmount > 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment Intent',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (hasDiscount) ...[
              _buildInfoRow(
                theme,
                FontAwesomeIcons.tag,
                'Original Amount',
                '${_formatAmount(amount + discountAmount)} $currency',
                valueColor: Colors.grey,
              ),
              _buildInfoRow(
                theme,
                FontAwesomeIcons.tag,
                'Discount',
                '-${_formatAmount(discountAmount)} $currency',
                valueColor: Colors.green,
              ),
              const Divider(),
            ],
            _buildInfoRow(
              theme,
              FontAwesomeIcons.moneyBill,
              'Final Amount',
              '${_formatAmount(amount)} $currency',
              valueColor: hasDiscount ? theme.colorScheme.primary : null,
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              theme,
              FontAwesomeIcons.circleCheck,
              'Status',
              paymentStatus,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStationInfo(BuildContext context, ThemeData theme, String stationId) {
    final stationAsync = ref.watch(stationDetailFutureProvider(stationId));
    
    return stationAsync.when(
      loading: () => _buildInfoRow(
        theme,
        FontAwesomeIcons.locationDot,
        'Station',
        'Loading...',
      ),
      error: (e, st) => _buildInfoRow(
        theme,
        FontAwesomeIcons.locationDot,
        'Station',
        'Unable to load station info',
      ),
      data: (station) {
        final name = station['name'] as String? ?? 'Unknown Station';
        final address = station['address'] as String? ?? '';
        
        return InkWell(
          onTap: () => context.push('/stations/$stationId'),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FaIcon(FontAwesomeIcons.locationDot, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Station',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        name,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      if (address.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          address,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                FaIcon(
                  FontAwesomeIcons.chevronRight,
                  size: 16,
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(ThemeData theme, IconData icon, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          FaIcon(icon, color: theme.colorScheme.primary, size: 20),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: theme.textTheme.bodyMedium,
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createPaymentIntent(BuildContext context) async {
    try {
      final repository = ref.read(bookingRepositoryProvider);
      final paymentIntent = await repository.createPaymentIntent(widget.bookingId);
      if (mounted) {
        // Save payment intent to local state
        ref.read(paymentIntentProvider(widget.bookingId).notifier).state = paymentIntent;
        
        AppToast.showSuccess(context, 'Payment intent created');
        
        // Scroll to payment section
        _scrollToPaymentSection();
        
        // Refresh booking to get updated status
        ref.invalidate(bookingDetailProvider(widget.bookingId));
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, 'Failed to create payment session: ${formatApiError(e)}');
      }
    }
  }

  Future<void> _simulatePaymentSuccess(
    BuildContext context,
    Map<String, dynamic> paymentIntent,
  ) async {
    final intentId = paymentIntent['id'] as String?;
    if (intentId == null) return;

    try {
      final repository = ref.read(bookingRepositoryProvider);
      final updatedIntent = await repository.simulatePaymentSuccess(intentId);
      if (mounted) {
        // Update local state with updated payment intent
        ref.read(paymentIntentProvider(widget.bookingId).notifier).state = updatedIntent;
        
        AppToast.showSuccess(context, 'Payment succeeded! You earned +30 points');
        ref.invalidate(bookingDetailProvider(widget.bookingId));
        ref.invalidate(loyaltyProfileProvider);
        _startCountdown(); // Restart countdown check
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, 'Payment simulation failed: ${formatApiError(e)}');
      }
    }
  }

  Future<void> _simulatePaymentFail(
    BuildContext context,
    Map<String, dynamic> paymentIntent,
  ) async {
    final intentId = paymentIntent['id'] as String?;
    if (intentId == null) return;

    try {
      final repository = ref.read(bookingRepositoryProvider);
      final updatedIntent = await repository.simulatePaymentFail(intentId);
      if (mounted) {
        // Update local state with updated payment intent
        ref.read(paymentIntentProvider(widget.bookingId).notifier).state = updatedIntent;
        
        AppToast.showInfo(context, 'Payment failed');
        ref.invalidate(bookingDetailProvider(widget.bookingId));
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, 'Payment simulation failed: ${formatApiError(e)}');
      }
    }
  }

  Future<void> _cancelBooking(BuildContext context, Map<String, dynamic> booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: const Text('Are you sure you want to cancel this booking?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final repository = ref.read(bookingRepositoryProvider);
      await repository.cancelBooking(widget.bookingId);
      if (mounted) {
        AppToast.showSuccess(context, 'Booking cancelled');
        ref.invalidate(bookingDetailProvider(widget.bookingId));
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, 'Failed to cancel booking: ${formatApiError(e)}');
      }
    }
  }

  DateTime? _parseDateTime(String? dateStr) {
    if (dateStr == null) return null;
    try {
      return DateTime.parse(dateStr).toLocal();
    } catch (e) {
      return null;
    }
  }

  String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatAmount(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}

class _VoucherSelectorSheet extends StatelessWidget {
  final List<VoucherRedemption> vouchers;
  final int originalAmount;
  final void Function(VoucherRedemption) onApply;

  const _VoucherSelectorSheet({
    required this.vouchers,
    required this.originalAmount,
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
            'Select Voucher',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: vouchers.length,
              itemBuilder: (context, index) {
                final voucher = vouchers[index];
                final def = voucher.definition;
                final isPercent = def?.voucherType == 'PERCENT_DISCOUNT';
                final isFreeService = def?.voucherType == 'FREE_SERVICE';
                final discountPct = def?.discountPercent ?? 0;
                final maxVal = def?.maxValueVnd ?? 0;
                final int maxCap = maxVal > 0 ? maxVal : originalAmount;
                final estimatedDiscount = ((originalAmount * discountPct) / 100).round().clamp(0, maxCap);
                final finalAmount = originalAmount - estimatedDiscount;

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
                              isFreeService ? Icons.battery_charging_full : Icons.discount,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  def?.name ?? 'Voucher',
                                  style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  def?.description ?? '',
                                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                if (isPercent) ...[
                                  Text(
                                    'Save ~${_formatAmt(estimatedDiscount)} VND (-$discountPct%)',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.green[700],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ] else if (isFreeService) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'FREE Charging',
                                      style: TextStyle(
                                        color: Colors.green[700],
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                isPercent
                                    ? 'Final: ${_formatAmt(finalAmount)}'
                                    : 'FREE',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isPercent
                                      ? theme.colorScheme.primary
                                      : Colors.green[700],
                                ),
                              ),
                              const SizedBox(height: 4),
                              FaIcon(
                                FontAwesomeIcons.chevronRight,
                                size: 14,
                                color: Colors.grey[400],
                              ),
                            ],
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

  String _formatAmt(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}

