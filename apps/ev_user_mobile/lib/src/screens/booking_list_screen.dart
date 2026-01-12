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
      title: 'My Bookings',
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
    if (state.isLoading && state.bookings.isEmpty) {
      return const LoadingState();
    }

    if (state.error != null && state.bookings.isEmpty) {
      return ErrorState(
        message: state.error!,
        onRetry: () => ref.read(bookingListProvider.notifier).refresh(),
      );
    }

    if (state.bookings.isEmpty) {
      return const EmptyState(message: 'No bookings found');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: state.bookings.length + (state.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == state.bookings.length) {
          // Load more
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(bookingListProvider.notifier).loadMore();
          });
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final booking = state.bookings[index];
        return _BookingCard(booking: booking);
      },
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;

  const _BookingCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final id = booking['id'] as String? ?? '';
    final stationId = booking['stationId'] as String? ?? '';
    final status = booking['status'] as String? ?? 'UNKNOWN';
    final startTime = _parseDateTime(booking['startTime'] as String?);
    final endTime = _parseDateTime(booking['endTime'] as String?);
    final holdExpiresAt = _parseDateTime(booking['holdExpiresAt'] as String?);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/bookings/$id'),
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
                      style: theme.textTheme.titleMedium,
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
              const SizedBox(height: 12),
              if (startTime != null) ...[
                _buildInfoRow(
                  theme,
                  FontAwesomeIcons.calendar,
                  'Start',
                  _formatDateTime(startTime),
                ),
                const SizedBox(height: 8),
              ],
              if (endTime != null) ...[
                _buildInfoRow(
                  theme,
                  FontAwesomeIcons.calendar,
                  'End',
                  _formatDateTime(endTime),
                ),
                const SizedBox(height: 8),
              ],
              if (status == 'HOLD' && holdExpiresAt != null) ...[
                _buildInfoRow(
                  theme,
                  FontAwesomeIcons.clock,
                  'Hold expires',
                  _formatDateTime(holdExpiresAt),
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

