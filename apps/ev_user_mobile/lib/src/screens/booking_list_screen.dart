import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:shared_auth/shared_auth.dart';
import '../providers/booking_providers.dart';
import '../widgets/main_scaffold.dart';

/// Booking List Screen
class BookingListScreen extends ConsumerStatefulWidget {
  const BookingListScreen({super.key});

  @override
  ConsumerState<BookingListScreen> createState() => _BookingListScreenState();
}

class _BookingListScreenState extends ConsumerState<BookingListScreen> {
  String? _lastUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = ref.read(authStateProvider);
      _lastUserId = authState.userId;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bookingListProvider);
    final authState = ref.watch(authStateProvider);
    final theme = Theme.of(context);

    // Refresh booking list if userId changed (user switched accounts)
    if (_lastUserId != null && _lastUserId != authState.userId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(bookingListProvider.notifier).refresh();
      });
      _lastUserId = authState.userId;
    } else if (_lastUserId == null) {
      _lastUserId = authState.userId;
    }

    return MainScaffold(
      title: 'My bookings',
      child: RefreshIndicator(
        onRefresh: () => ref.read(bookingListProvider.notifier).refresh(),
        child: _buildContent(context, ref, state, theme),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    BookingListState state,
    ThemeData theme,
  ) {
    if (state.isLoading && state.bookings.isEmpty && state.batterySwapReservations.isEmpty) {
      return const SkeletonList(count: 4);
    }

    if (state.error != null && state.bookings.isEmpty && state.batterySwapReservations.isEmpty) {
      return ErrorState(
        message: formatApiError(state.error),
        onRetry: () => ref.read(bookingListProvider.notifier).refresh(),
      );
    }

    if (state.bookings.isEmpty && state.batterySwapReservations.isEmpty) {
      return EmptyState(
        icon: FontAwesomeIcons.calendarXmark,
        title: 'No bookings yet',
        message: 'Pick a charging station on the map and book a suitable slot.',
        action: ElevatedButton.icon(
          onPressed: () => context.go('/home'),
          icon: const FaIcon(FontAwesomeIcons.map, size: 14),
          label: const Text('Find a station'),
        ),
      );
    }

    final allItems = state.allItems;
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: allItems.length + (state.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == allItems.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(bookingListProvider.notifier).loadMore();
          });
          return const Padding(
            padding: EdgeInsets.all(8),
            child: SkeletonListTile(),
          );
        }

        final item = allItems[index];
        return _BookingCard(item: item);
      },
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Map<String, dynamic> item;

  const _BookingCard({required this.item});

  String get _type => item['_type'] as String? ?? 'CHARGER';
  bool get _isBatterySwap => _type == 'BATTERY_SWAP';
  String get _id => item['id']?.toString() ?? '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final id = item['id']?.toString() ?? '';
    final status = item['status']?.toString() ?? 'UNKNOWN';
    final stationName = item['stationName'] as String?;

    // Charger-specific fields
    final startTime = _parseDateTime(item['startTime'] as String?);
    final endTime = _parseDateTime(item['endTime'] as String?);
    final holdExpiresAt = _parseDateTime(item['holdExpiresAt'] as String?);

    // Battery swap-specific fields
    final reservedSlotAt = _parseDateTime(item['reservedSlotAt'] as String?);
    final confirmedArrivalAt = _parseDateTime(item['confirmedArrivalAt'] as String?);
    final pileIndex = item['pileIndex'] as int?;
    final slotIndex = item['slotIndex'] as int?;
    final paymentStatus = item['paymentStatus']?.toString();
    final basePriceVnd = item['basePriceVnd'] as int?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _onTap(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (_isBatterySwap)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FaIcon(
                        FontAwesomeIcons.batteryFull,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FaIcon(
                        FontAwesomeIcons.bolt,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      _isBatterySwap
                          ? 'Battery Swap${stationName != null ? ' · $stationName' : ''}'
                          : 'Booking #${id.length >= 8 ? id.substring(0, 8) : id}',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  StatusPill(
                    label: _statusLabel(status),
                    colorMapper: (_) => _statusColor(status),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Charger booking info
              if (!_isBatterySwap) ...[
                if (startTime != null) ...[
                  _buildInfoRow(theme, FontAwesomeIcons.calendar, 'Start', _formatDateTime(startTime)),
                  const SizedBox(height: 8),
                ],
                if (endTime != null) ...[
                  _buildInfoRow(theme, FontAwesomeIcons.calendar, 'End', _formatDateTime(endTime)),
                  const SizedBox(height: 8),
                ],
                if (status == 'HOLD' && holdExpiresAt != null) ...[
                  _buildInfoRow(theme, FontAwesomeIcons.clock, 'Hold until', _formatDateTime(holdExpiresAt)),
                ],
              ],

              // Battery swap info
              if (_isBatterySwap) ...[
                if (pileIndex != null && slotIndex != null) ...[
                  _buildInfoRow(theme, FontAwesomeIcons.chargingStation, 'Pile/Slot', '$pileIndex / $slotIndex'),
                  const SizedBox(height: 8),
                ],
                if (reservedSlotAt != null) ...[
                  _buildInfoRow(theme, FontAwesomeIcons.clock, 'Arrive by', _formatDateTime(reservedSlotAt)),
                  const SizedBox(height: 8),
                ],
                if (basePriceVnd != null) ...[
                  _buildInfoRow(theme, FontAwesomeIcons.dollarSign, 'Fee', '$basePriceVnd VND'),
                  const SizedBox(height: 8),
                ],
                if (paymentStatus != null) ...[
                  _buildInfoRow(theme, FontAwesomeIcons.creditCard, 'Payment', _paymentLabel(paymentStatus)),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _onTap(BuildContext context) {
    if (_isBatterySwap) {
      // Navigate to battery swap screen with station pre-selected
      final stationId = item['stationId']?.toString();
      if (stationId != null && stationId.isNotEmpty) {
        context.push('/battery-swap?stationId=$stationId');
      }
    } else {
      context.push('/bookings/$_id');
    }
  }

  String _paymentLabel(String paymentStatus) {
    switch (paymentStatus) {
      case 'PAID': return 'Paid';
      case 'REFUNDED': return 'Refunded';
      default: return 'Unpaid';
    }
  }

  String _statusLabel(String status) {
    if (_isBatterySwap) {
      switch (status) {
        case 'RESERVED': return 'Reserved';
        case 'SWAPPING': return 'Swapping';
        case 'COMPLETED': return 'Completed';
        case 'CANCELLED': return 'Cancelled';
        case 'EXPIRED': return 'Expired';
        default: return status;
      }
    }
    switch (status) {
      case 'HOLD': return 'On hold';
      case 'CONFIRMED': return 'Confirmed';
      case 'CANCELLED': return 'Cancelled';
      case 'EXPIRED': return 'Expired';
      case 'COMPLETED': return 'Completed';
      default: return status;
    }
  }

  Color _statusColor(String status) {
    if (_isBatterySwap) {
      switch (status) {
        case 'RESERVED': return Colors.blue;
        case 'SWAPPING': return Colors.orange;
        case 'COMPLETED': return Colors.green;
        case 'CANCELLED': return Colors.grey;
        case 'EXPIRED': return Colors.deepOrange;
        default: return Colors.blueGrey;
      }
    }
    switch (status) {
      case 'HOLD': return Colors.orange;
      case 'CONFIRMED': return Colors.green;
      case 'COMPLETED': return Colors.teal;
      case 'CANCELLED':
      case 'EXPIRED': return Colors.red;
      default: return Colors.grey;
    }
  }

  Widget _buildInfoRow(ThemeData theme, IconData icon, String label, String value) {
    return Row(
      children: [
        FaIcon(icon, size: 16, color: theme.colorScheme.onSurface.withOpacity(0.6)),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
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
}

