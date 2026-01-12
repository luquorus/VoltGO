import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_ui/shared_ui.dart';
import '../providers/booking_providers.dart';
import '../providers/station_providers.dart';

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
      title: 'Booking Details',
      actions: [
        IconButton(
          icon: const FaIcon(FontAwesomeIcons.xmark),
          onPressed: () => _handleClose(context),
          tooltip: 'Close',
        ),
      ],
      body: bookingAsync.when(
        loading: () => const LoadingState(),
        error: (e, st) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(bookingDetailProvider(widget.bookingId)),
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
    // Get payment intent from local state (if created) or from booking response (if backend includes it)
    final localPaymentIntent = ref.read(paymentIntentProvider(widget.bookingId));
    final bookingPaymentIntent = booking['paymentIntent'] as Map<String, dynamic>?;
    final paymentIntent = localPaymentIntent ?? bookingPaymentIntent;

    if (status != 'HOLD') {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment',
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
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

  Widget _buildPaymentIntentInfo(
    BuildContext context,
    Map<String, dynamic> paymentIntent,
    ThemeData theme,
  ) {
    final amount = paymentIntent['amount'] as int? ?? 0;
    final currency = paymentIntent['currency'] as String? ?? 'VND';
    final paymentStatus = paymentIntent['status'] as String? ?? '';

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
            _buildInfoRow(
              theme,
              FontAwesomeIcons.moneyBill,
              'Amount',
              '${_formatAmount(amount)} $currency',
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

  Widget _buildInfoRow(ThemeData theme, IconData icon, String label, String value) {
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
        AppToast.showError(context, 'Failed to create payment intent: ${e.toString()}');
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
        
        AppToast.showSuccess(context, 'Payment succeeded!');
        ref.invalidate(bookingDetailProvider(widget.bookingId));
        _startCountdown(); // Restart countdown check
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, 'Failed to simulate payment: ${e.toString()}');
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
        AppToast.showError(context, 'Failed to simulate payment: ${e.toString()}');
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
        AppToast.showError(context, 'Failed to cancel booking: ${e.toString()}');
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

