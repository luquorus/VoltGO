import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:shared_auth/shared_auth.dart';
import '../providers/booking_providers.dart';
import '../providers/station_providers.dart';
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

class _BookingCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> item;

  const _BookingCard({required this.item});

  String get _type => item['_type'] as String? ?? 'CHARGER';
  bool get _isBatterySwap => _type == 'BATTERY_SWAP';
  String get _id => item['id']?.toString() ?? '';

  @override
  ConsumerState<_BookingCard> createState() => _BookingCardState();
}

class _BookingCardState extends ConsumerState<_BookingCard> {
  @override
  Widget build(BuildContext context) {
    if (widget._isBatterySwap) {
      return _BatterySwapBookingCard(item: widget.item);
    } else {
      return _ChargingBookingCard(item: widget.item);
    }
  }
}

/// Battery Swap booking card (unchanged from original)
class _BatterySwapBookingCard extends StatelessWidget {
  final Map<String, dynamic> item;

  const _BatterySwapBookingCard({required this.item});

  String get _id => item['id']?.toString() ?? '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final id = item['id']?.toString() ?? '';
    final status = item['status']?.toString() ?? 'UNKNOWN';
    final stationName = item['stationName'] as String?;

    final reservedSlotAt = _parseDateTime(item['reservedSlotAt'] as String?);
    final pileIndex = item['pileIndex'] as int?;
    final slotIndex = item['slotIndex'] as int?;
    final paymentStatus = item['paymentStatus']?.toString();
    final basePriceVnd = item['basePriceVnd'] as int?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          final stationId = item['stationId']?.toString();
          if (stationId != null && stationId.isNotEmpty) {
            context.push('/battery-swap?stationId=$stationId');
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FaIcon(
                      FontAwesomeIcons.batteryFull,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Battery Swap${stationName != null ? ' · $stationName' : ''}',
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
          ),
        ),
      ),
    );
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

  Widget _buildInfoRow(ThemeData theme, IconData icon, String label, String value) {
    return Row(
      children: [
        FaIcon(icon, size: 16, color: theme.colorScheme.onSurface.withOpacity(0.6)),
        const SizedBox(width: 8),
        Text('$label: ', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6))),
        Text(value, style: theme.textTheme.bodyMedium),
      ],
    );
  }

  DateTime? _parseDateTime(String? dateStr) {
    if (dateStr == null) return null;
    try { return DateTime.parse(dateStr).toLocal(); } catch (e) { return null; }
  }

  String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _paymentLabel(String paymentStatus) {
    switch (paymentStatus) {
      case 'PAID': return 'Paid';
      case 'REFUNDED': return 'Refunded';
      default: return 'Unpaid';
    }
  }
}

/// Charging booking card with rich info (station name, charger, price, countdown)
class _ChargingBookingCard extends ConsumerWidget {
  final Map<String, dynamic> item;

  const _ChargingBookingCard({required this.item});

  String get _id => item['id']?.toString() ?? '';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final status = item['status']?.toString() ?? 'UNKNOWN';
    final startTime = _parseDateTime(item['startTime'] as String?);
    final endTime = _parseDateTime(item['endTime'] as String?);
    final holdExpiresAt = _parseDateTime(item['holdExpiresAt'] as String?);
    final priceSnapshot = item['priceSnapshot'] as Map<String, dynamic>?;
    final totalAmount = priceSnapshot?['totalAmount'] as int?;
    final chargerUnitLabel = priceSnapshot?['chargerUnitLabel'] as String?;
    final powerKw = priceSnapshot?['powerKw'] as num?;
    final powerType = priceSnapshot?['powerType'] as String?;
    final stationId = item['stationId']?.toString();

    final stationAsync = stationId != null
        ? ref.watch(stationDetailFutureProvider(stationId))
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/bookings/$_id'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FaIcon(
                      FontAwesomeIcons.bolt,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Expanded(
                    child: stationAsync != null
                        ? stationAsync.when(
                            data: (station) {
                              final name = station['name'] as String? ?? 'Charging';
                              return Text(
                                'Charging · $name',
                                style: theme.textTheme.titleMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              );
                            },
                            loading: () => Text(
                              'Charging · Loading...',
                              style: theme.textTheme.titleMedium,
                            ),
                            error: (_, __) => Text(
                              'Charging · #${_id.length >= 8 ? _id.substring(0, 8) : _id}',
                              style: theme.textTheme.titleMedium,
                            ),
                          )
                        : Text(
                            'Charging · #${_id.length >= 8 ? _id.substring(0, 8) : _id}',
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

              // Charger info (from price snapshot)
              if (chargerUnitLabel != null) ...[
                _buildInfoRow(theme, FontAwesomeIcons.plug, 'Charger',
                    '$chargerUnitLabel${powerType != null ? ' · $powerType${powerKw != null ? ' ${powerKw.toDouble().toStringAsFixed(0)}kW' : ''}' : ''}'),
                const SizedBox(height: 8),
              ],

              // Time info
              if (startTime != null) ...[
                _buildInfoRow(theme, FontAwesomeIcons.calendar, 'Start', _formatDateTime(startTime)),
                const SizedBox(height: 8),
              ],
              if (endTime != null) ...[
                _buildInfoRow(theme, FontAwesomeIcons.calendar, 'End', _formatDateTime(endTime)),
                const SizedBox(height: 8),
              ],

              // Price info
              if (totalAmount != null) ...[
                _buildInfoRow(theme, FontAwesomeIcons.dollarSign, 'Fee', '$totalAmount VND'),
                const SizedBox(height: 8),
              ],

              // Hold countdown
              if (status == 'HOLD' && holdExpiresAt != null) ...[
                _HoldCountdownBadge(holdExpiresAt: holdExpiresAt),
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
        FaIcon(icon, size: 16, color: theme.colorScheme.onSurface.withOpacity(0.6)),
        const SizedBox(width: 8),
        Text('$label: ', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6))),
        Text(value, style: theme.textTheme.bodyMedium),
      ],
    );
  }

  String _statusLabel(String status) {
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
    switch (status) {
      case 'HOLD': return Colors.orange;
      case 'CONFIRMED': return Colors.green;
      case 'COMPLETED': return Colors.teal;
      case 'CANCELLED':
      case 'EXPIRED': return Colors.red;
      default: return Colors.grey;
    }
  }

  DateTime? _parseDateTime(String? dateStr) {
    if (dateStr == null) return null;
    try { return DateTime.parse(dateStr).toLocal(); } catch (e) { return null; }
  }

  String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

/// Countdown badge for HOLD booking
class _HoldCountdownBadge extends StatefulWidget {
  final DateTime holdExpiresAt;

  const _HoldCountdownBadge({required this.holdExpiresAt});

  @override
  State<_HoldCountdownBadge> createState() => _HoldCountdownBadgeState();
}

class _HoldCountdownBadgeState extends State<_HoldCountdownBadge> {
  late final Stream<int> _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Stream.periodic(const Duration(seconds: 1),
        (_) => widget.holdExpiresAt.difference(DateTime.now()).inSeconds)
        .takeWhile((seconds) => seconds >= 0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<int>(
      stream: _ticker,
      builder: (context, snapshot) {
        final seconds = snapshot.data ?? widget.holdExpiresAt.difference(DateTime.now()).inSeconds;
        final isExpired = seconds < 0;
        final color = isExpired
            ? Colors.red
            : seconds < 120
                ? Colors.deepOrange
                : Colors.orange;

        String label;
        if (isExpired) {
          label = 'Hold expired';
        } else {
          final m = seconds ~/ 60;
          final s = seconds % 60;
          label = 'Hold expires in ${m > 0 ? '${m}m ' : ''}${s}s';
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FaIcon(
                isExpired ? FontAwesomeIcons.clock : FontAwesomeIcons.hourglassHalf,
                size: 12,
                color: color,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
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
}

