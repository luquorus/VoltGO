import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';
import '../providers/station_providers.dart';
import '../repositories/station_repository.dart';
import '../widgets/main_scaffold.dart';
import '../models/battery_swap_models.dart';
import '../services/battery_swap_websocket_service.dart';
import '../widgets/rating/station_rating_section.dart';
import 'battery_swap_booking_sheet.dart';

final _stationDetailProvider =
    FutureProvider.family<BatterySwapStationDetailModel, String>(
        (ref, stationId) async {
  final repository = ref.read(stationRepositoryProvider);
  try {
    return await repository.getBatterySwapStationDetail(stationId);
  } on ApiError catch (e) {
    // Backend returns VALIDATION_ERROR with "Station does not support battery swap"
    // or NOT_FOUND for non-existent stations
    if (e.code == 'NOT_FOUND' ||
        e.code == 'STATION_NOT_FOUND' ||
        e.code == 'VALIDATION_ERROR' ||
        e.message.toLowerCase().contains('not found') ||
        e.message.toLowerCase().contains('does not support') ||
        e.message.toLowerCase().contains('no swap piles')) {
      throw ApiError(
        traceId: e.traceId,
        code: 'NOT_A_BATTERY_SWAP_STATION',
        message: 'This station does not have battery swap service.',
        timestamp: e.timestamp,
      );
    }
    rethrow;
  }
});

final _preSelectedStationDetailProvider =
    FutureProvider.family<BatterySwapStationDetailModel, String>(
        (ref, stationId) async {
  final repository = ref.read(stationRepositoryProvider);
  try {
    return await repository.getBatterySwapStationDetail(stationId);
  } on ApiError catch (e) {
    // Backend returns VALIDATION_ERROR with "Station does not support battery swap"
    // or NOT_FOUND for non-existent stations
    if (e.code == 'NOT_FOUND' ||
        e.code == 'STATION_NOT_FOUND' ||
        e.code == 'VALIDATION_ERROR' ||
        e.message.toLowerCase().contains('not found') ||
        e.message.toLowerCase().contains('does not support') ||
        e.message.toLowerCase().contains('no swap piles')) {
      throw ApiError(
        traceId: e.traceId,
        code: 'NOT_A_BATTERY_SWAP_STATION',
        message: 'This station does not have battery swap service.',
        timestamp: e.timestamp,
      );
    }
    rethrow;
  }
});

class BatterySwapScreen extends ConsumerStatefulWidget {
  final String? preSelectedStationId;

  const BatterySwapScreen({super.key, this.preSelectedStationId});

  @override
  ConsumerState<BatterySwapScreen> createState() => _BatterySwapScreenState();
}

class _BatterySwapScreenState extends ConsumerState<BatterySwapScreen> {
  bool _loadingLocation = false;
  String? _locationError;

  int _requestedBatteryPercent = 20;
  double _batteryCapacityKwh = 60;
  late final TextEditingController _capacityController;

  @override
  void initState() {
    super.initState();
    _capacityController =
        TextEditingController(text: _batteryCapacityKwh.toString());
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loadingLocation = true;
      _locationError = null;
    });

    final preId = widget.preSelectedStationId;

    // If we have a pre-selected station (from station detail screen),
    // skip location search and just fetch that station's detail.
    if (preId != null && preId.isNotEmpty) {
      try {
        await ref.read(batterySwapProvider.notifier).loadMyReservations();
      } catch (e) {
        // Non-critical, ignore reservation load errors
      } finally {
        if (mounted) setState(() => _loadingLocation = false);
      }
      return;
    }

    try {
      final permission = await _ensureLocationPermission();
      if (permission == null) return;

      final position = await Geolocator.getCurrentPosition();
      await ref.read(batterySwapProvider.notifier).loadStations(
            lat: position.latitude,
            lng: position.longitude,
            radiusKm: 20,
          );
      await ref.read(batterySwapProvider.notifier).loadMyReservations();
    } catch (e) {
      if (mounted) {
        setState(() => _locationError = formatApiError(e));
      }
    } finally {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  Future<LocationPermission?> _ensureLocationPermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() =>
              _locationError = 'Location is off. Please enable GPS and try again.');
        }
        return null;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() => _locationError =
              'Location permission is required to find nearby battery swap stations.');
        }
        return null;
      }
      return permission;
    } catch (e) {
      if (mounted) {
        setState(() => _locationError = formatApiError(e));
      }
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(batterySwapProvider);
    final theme = Theme.of(context);

    return MainScaffold(
      showBottomNav: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Battery swap'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => context.pop(),
          ),
          actions: [
            IconButton(
              tooltip: 'Reload',
              onPressed: _loadingLocation ? null : _loadData,
              icon: const FaIcon(FontAwesomeIcons.arrowsRotate, size: 18),
            ),
            IconButton(
              tooltip: 'My reservations',
              onPressed: () => context.push('/battery-swap/reservations'),
              icon: const FaIcon(FontAwesomeIcons.clockRotateLeft, size: 18),
            ),
          ],
        ),
        body: _buildBody(theme, state),
      ),
    );
  }

  Widget _buildBody(ThemeData theme, BatterySwapState state) {
    if (_loadingLocation) {
      return const LoadingState(message: 'Getting your location...');
    }

    if (_locationError != null) {
      return ErrorState(
        title: 'Could not get location',
        message: _locationError,
        icon: FontAwesomeIcons.locationCrosshairs,
        onRetry: _loadData,
      );
    }

    if (state.isLoading && state.stations.isEmpty) {
      return const LoadingState(message: 'Loading nearby battery swap stations...');
    }

    if (state.error != null && state.stations.isEmpty) {
      return ErrorState(
        message: formatApiError(state.error),
        code: state.error!.code,
        traceId: state.error!.traceId,
        onRetry: _loadData,
      );
    }

    // Pre-selected station mode: show detail only, no nearby list
    if (widget.preSelectedStationId != null &&
        widget.preSelectedStationId!.isNotEmpty) {
      return _buildPreSelectedBody(theme, state);
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (state.error != null)
            _ErrorBanner(
              message: formatApiError(state.error),
              onDismiss: () =>
                  ref.read(batterySwapProvider.notifier).clearError(),
            ),
          _buildSectionHeader(
            theme,
            icon: FontAwesomeIcons.locationDot,
            title: 'Nearby battery swap stations',
            count: state.stations.length,
          ),
          const SizedBox(height: 8),
          if (state.stations.isEmpty)
            const EmptyState(
              icon: FontAwesomeIcons.batteryEmpty,
              title: 'No nearby battery swap stations',
              message:
                  'Try expanding the search area or reload in a few minutes.',
              compact: true,
            )
          else
            ...state.stations.map((s) => _buildStationCard(theme, s)),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildPreSelectedBody(ThemeData theme, BatterySwapState state) {
    final stationId = widget.preSelectedStationId!;
    final detailAsync = ref.watch(_preSelectedStationDetailProvider(stationId));

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (state.error != null)
            _ErrorBanner(
              message: formatApiError(state.error),
              onDismiss: () =>
                  ref.read(batterySwapProvider.notifier).clearError(),
            ),
          detailAsync.when(
            data: (detail) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back hint
                  InkWell(
                    onTap: () => context.pop(),
                    child: Row(
                      children: [
                        FaIcon(
                          FontAwesomeIcons.arrowLeft,
                          size: 14,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Back to station details',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Station detail card
                  _buildPreSelectedStationCard(theme, detail),
                  const SizedBox(height: 16),
                  // Link to reservations screen
                  TextButton.icon(
                    onPressed: () => context.push('/battery-swap/reservations'),
                    icon: FaIcon(
                      FontAwesomeIcons.clockRotateLeft,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                    label: Text(
                      'My reservations',
                      style: TextStyle(color: theme.colorScheme.primary),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) {
              return _buildPreSelectedError(theme, e);
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPreSelectedStationCard(
      ThemeData theme, BatterySwapStationDetailModel detail) {
    final price = detail.basePriceVnd;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: FaIcon(
                    FontAwesomeIcons.carBattery,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        detail.name ?? 'Battery Swap Station',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if ((detail.address ?? '').isNotEmpty)
                        Text(
                          detail.address!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color:
                                theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _PreSelectedStat(
                  label: 'Piles',
                  value: '${detail.totalPiles}',
                  icon: FontAwesomeIcons.chargingStation,
                  color: theme.colorScheme.primary,
                ),
                _PreSelectedStat(
                  label: 'Ready',
                  value: '${detail.availableBatteries}',
                  icon: FontAwesomeIcons.batteryFull,
                  color: detail.availableBatteries > 0
                      ? Colors.green
                      : Colors.orange,
                ),
                _PreSelectedStat(
                  label: 'Total',
                  value: '${detail.totalSlots}',
                  icon: FontAwesomeIcons.layerGroup,
                  color: theme.colorScheme.secondary,
                ),
                _PreSelectedStat(
                  label: 'Fee',
                  value: '$price VND',
                  icon: FontAwesomeIcons.dollarSign,
                  color: Colors.teal,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Pile/slot layout
            Text(
              'Swap pile layout',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ...detail.piles.map((pile) => _buildPreSelectedPileRow(theme, pile)),
            const SizedBox(height: 16),
            // Book button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: detail.availableBatteries > 0
                    ? () => _showReserveSheet(detail)
                    : null,
                icon: const FaIcon(FontAwesomeIcons.bolt, size: 14),
                label: Text(
                  detail.availableBatteries > 0
                      ? 'Book battery swap'
                      : 'No batteries ready (charging)',
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Rating & reviews
            StationRatingSection(
              stationId: detail.stationId,
              compact: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreSelectedPileRow(ThemeData theme, SwapPileModel pile) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.3),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          FaIcon(
            FontAwesomeIcons.chargingStation,
            size: 14,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Pile ${pile.pileIndex}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: pile.availableSlots > 0
                  ? Colors.green.shade100
                  : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${pile.availableSlots} ready',
              style: theme.textTheme.labelSmall?.copyWith(
                color: pile.availableSlots > 0
                    ? Colors.green.shade800
                    : Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 6),
          if (pile.chargingSlots > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${pile.chargingSlots} charging',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.orange.shade800,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          const SizedBox(width: 6),
          // Show first 4 slots as mini indicators with charging progress
          ...pile.slots.take(4).map((slot) {
            final isAvail = slot.status == BatterySlotStatus.available;
            final isCharging = slot.status == BatterySlotStatus.charging ||
                slot.status == BatterySlotStatus.swappedOut;
            return Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FaIcon(
                    isAvail
                        ? FontAwesomeIcons.batteryFull
                        : isCharging
                            ? FontAwesomeIcons.batteryHalf
                            : FontAwesomeIcons.batteryEmpty,
                    size: 12,
                    color: isAvail
                        ? Colors.green
                        : isCharging
                            ? Colors.orange
                            : Colors.grey,
                  ),
                  if (isCharging && slot.batteryChargePercent < 100)
                    SizedBox(
                      width: 12,
                      height: 4,
                      child: LinearProgressIndicator(
                        value: slot.batteryChargePercent / 100,
                        backgroundColor: Colors.orange.shade200,
                        valueColor: AlwaysStoppedAnimation(Colors.orange.shade700),
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPreSelectedError(ThemeData theme, Object e) {
    final apiError = e is ApiError ? e : null;
    final isNotSwap = apiError?.code == 'NOT_A_BATTERY_SWAP_STATION';
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          FaIcon(
            isNotSwap ? FontAwesomeIcons.carBattery : Icons.error_outline,
            size: 48,
            color: isNotSwap ? Colors.orange : Colors.red,
          ),
          const SizedBox(height: 12),
          Text(
            isNotSwap
                ? 'This station does not have battery swap service.'
                : 'Failed to load station',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => context.pop(),
            child: const Text('Back to station details'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required int count,
  }) {
    return Row(
      children: [
        FaIcon(icon, size: 16, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStationCard(ThemeData theme, BatterySwapStationModel station) {
    final stationId = station.stationId;
    final distanceKm = station.distanceKm;
    final hasAvailable = station.availableBatteries > 0;
    final price = station.basePriceVnd;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        station.name ?? 'Unnamed station',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if ((station.address ?? '').isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          station.address!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (distanceKm != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${distanceKm.toStringAsFixed(1)} km',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (station.totalPiles > 0)
              _buildPileSummary(theme, station, price),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: !hasAvailable || stationId.isEmpty
                        ? null
                        : () => _showStationDetailSheet(stationId, price),
                    icon: const FaIcon(FontAwesomeIcons.bolt, size: 14),
                    label: Text(
                      hasAvailable
                          ? 'Book battery swap'
                          : 'No slots available',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPileSummary(ThemeData theme, BatterySwapStationModel station, int price) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        StatusPill(
          label: '${station.totalPiles} pile${station.totalPiles > 1 ? 's' : ''}',
          color: theme.colorScheme.primary,
        ),
        StatusPill(
          label: '${station.availableBatteries} ready',
          color: station.availableBatteries > 0 ? Colors.green : Colors.orange,
        ),
        StatusPill(
          label: '$price VND/session',
          color: theme.colorScheme.secondary,
        ),
      ],
    );
  }

  Future<void> _showStationDetailSheet(
      String stationId, int basePriceVnd) async {
    final detail = await showModalBottomSheet<BatterySwapStationDetailModel>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _StationDetailSheet(
        stationId: stationId,
        basePriceVnd: basePriceVnd,
      ),
    );
    if (detail != null && mounted) {
      _showReserveSheet(detail);
    }
  }

  Future<void> _showReserveSheet(BatterySwapStationDetailModel station) async {
    final state = ref.read(batterySwapProvider);
    final hasActiveAtStation = state.myReservations.any(
        (r) => r.stationId == station.stationId &&
               (r.status == 'RESERVED' || r.status == 'SWAPPING'));

    final result = await showModalBottomSheet<BatterySwapBookingResult>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => BatterySwapBookingSheet(
        station: station,
        hasActiveAtStation: hasActiveAtStation,
      ),
    );

    if (result == null || !mounted) return;
    setState(() {
      _requestedBatteryPercent = result.requestedBatteryPercent;
      _batteryCapacityKwh = result.batteryCapacityKwh;
      _capacityController.text = result.batteryCapacityKwh.toString();
    });

    try {
      final reservation = await ref.read(batterySwapProvider.notifier).reserve(
            stationId: station.stationId,
            expectedArrivalAt: result.expectedArrivalAt,
            requestedBatteryPercent: result.requestedBatteryPercent,
            batteryCapacityKwh: result.batteryCapacityKwh,
            pileId: result.pileId,
            slotId: result.slotId,
            note: result.note,
          );
      await ref.read(batterySwapProvider.notifier).loadMyReservations();
      if (mounted) {
        AppToast.showSuccess(
          context,
          'Booked! Arrive by ${_formatDateTimeLocal(result.expectedArrivalAt)}. '
          'Your slot is held for 15 minutes.',
        );
        context.pushReplacement(
          '/battery-swap/reservations?reservationId=${reservation.id}',
        );
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, 'Book failed: ${formatApiError(e)}');
      }
    }
  }

  String _formatDateTimeLocal(DateTime dt) {
    return '${dt.day}/${dt.month} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildReservationCard(
      ThemeData theme, BatterySwapReservationModel reservation) {
    final id = reservation.id;
    final status = reservation.status;
    final stationName = reservation.stationName;
    final arrivalTime = reservation.reservedSlotAt;
    final confirmedArrival = reservation.confirmedArrivalAt;
    final reservedAt = reservation.reservedAt;
    final paymentStatus = reservation.paymentStatus;
    final isPaid = paymentStatus == 'PAID';
    final isReserved = status == 'RESERVED';
    final isSwapping = status == 'SWAPPING';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
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
                        stationName ??
                            'Reservation ${id.length >= 8 ? id.substring(0, 8) : id}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (reservation.pileIndex != null) ...[
                        const SizedBox(height: 2),
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
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                StatusPill(
                  label: '${reservation.basePriceVnd} VND',
                  color: theme.colorScheme.secondary,
                ),
                StatusPill(
                  label: _paymentLabel(paymentStatus),
                  color: isPaid ? Colors.teal : Colors.blueGrey,
                ),
              ],
            ),
            if (arrivalTime != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  FaIcon(FontAwesomeIcons.clock, size: 12,
                      color: theme.colorScheme.onSurface.withOpacity(0.6)),
                  const SizedBox(width: 6),
                  Text(
                    'Arrive by: ${_formatDateTimeLocal(arrivalTime.toLocal())}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ],
            // Payment countdown: UNPAID + isReserved
            if (!isPaid && isReserved && reservedAt != null)
              _CountdownTimer(
                label: 'Payment expires in:',
                from: reservedAt.add(const Duration(minutes: 10)),
                expiredLabel: 'Payment expired',
                onExpired: () => ref.read(batterySwapProvider.notifier).loadMyReservations(),
              ),
            // Hold countdown: isReserved + isPaid + !confirmedArrival
            if (isReserved && isPaid && !isSwapping)
              _CountdownTimer(
                label: 'Hold expires in:',
                from: (confirmedArrival ?? arrivalTime ?? reservedAt ?? DateTime.now())
                    .add(const Duration(minutes: 15)),
                expiredLabel: 'Hold expired',
                onExpired: () => ref.read(batterySwapProvider.notifier).loadMyReservations(),
              ),
            // Hold countdown: isSwapping
            if (isSwapping && confirmedArrival != null)
              _CountdownTimer(
                label: 'Swap must start in:',
                from: confirmedArrival.add(const Duration(minutes: 15)),
                expiredLabel: 'Swap expired',
                onExpired: () => ref.read(batterySwapProvider.notifier).loadMyReservations(),
              ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                // RESERVED + UNPAID → Pay
                if (isReserved && !isPaid)
                  ElevatedButton.icon(
                    onPressed: () => _runAction(
                      label: 'Pay for battery swap',
                      action: () => ref.read(batterySwapProvider.notifier).pay(id),
                      successMsg: 'Payment successful.',
                    ),
                    icon: const FaIcon(FontAwesomeIcons.creditCard, size: 12),
                    label: const Text('Pay now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                  ),
                // RESERVED + PAID + !arrived → "I'm here" (confirmArrival)
                if (isReserved && isPaid && (confirmedArrival == null))
                  ElevatedButton.icon(
                    onPressed: () => _runAction(
                      label: 'Confirm arrival',
                      action: () => ref.read(batterySwapProvider.notifier).confirmArrival(id),
                      successMsg: 'Arrival confirmed. You have 15 minutes to start swapping.',
                    ),
                    icon: const FaIcon(FontAwesomeIcons.locationDot, size: 12),
                    label: const Text('I\'m here'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                // RESERVED + PAID + arrived → "Start Swap" (shows swap code dialog)
                if (isReserved && isPaid && (confirmedArrival != null) && !isSwapping)
                  ElevatedButton.icon(
                    onPressed: () => _startSwap(id),
                    icon: const FaIcon(FontAwesomeIcons.key, size: 12),
                    label: const Text('Start Swap'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                // SWAPPING → Show "Verifying..." spinner
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
                    onPressed: () => _confirmAndCancel(id),
                    icon: const FaIcon(FontAwesomeIcons.xmark, size: 12),
                    label: const Text('Cancel'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _paymentLabel(String paymentStatus) {
    switch (paymentStatus) {
      case 'PAID':
        return 'Paid';
      case 'REFUNDED':
        return 'Refunded';
      default:
        return 'Unpaid';
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'RESERVED':
        return 'Reserved';
      case 'SWAPPING':
        return 'Swapping';
      case 'COMPLETED':
        return 'Completed';
      case 'CANCELLED':
        return 'Cancelled';
      case 'EXPIRED':
        return 'Expired';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'RESERVED':
        return Colors.blue;
      case 'SWAPPING':
        return Colors.orange;
      case 'COMPLETED':
        return Colors.green;
      case 'CANCELLED':
        return Colors.grey;
      case 'EXPIRED':
        return Colors.deepOrange;
      default:
        return Colors.blueGrey;
    }
  }

  Future<void> _confirmAndCancel(String reservationId) async {
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
      label: 'Cancel reservation',
      action: () =>
          ref.read(batterySwapProvider.notifier).cancel(reservationId),
      successMsg: 'Reservation cancelled.',
    );
  }

  Future<void> _runAction({
    required String label,
    required Future<void> Function() action,
    required String successMsg,
    bool reloadReservations = true,
  }) async {
    try {
      await action();
      if (reloadReservations) {
        await ref.read(batterySwapProvider.notifier).loadMyReservations();
      }
      if (mounted) AppToast.showSuccess(context, successMsg);
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, '$label failed: ${formatApiError(e)}');
      }
    }
  }

  Future<void> _startSwap(String reservationId) async {
    final notifier = ref.read(batterySwapProvider.notifier);
    DateTime? deadlineAt;
    int? pileIndex;
    int? slotIndex;
    bool isLoading = true;
    String? error;
    final codeController = TextEditingController();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          if (isLoading && error == null) {
            Future.microtask(() async {
              try {
                final result = await notifier.getSwapCode(reservationId);
                if (ctx.mounted) {
                  setDialogState(() {
                    deadlineAt = result['deadlineAt'] != null
                        ? DateTime.tryParse(result['deadlineAt'].toString())
                        : null;
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
                const Expanded(child: Text('Enter Swap Code')),
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
                            'Enter the 4-digit code shown on the station display',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: codeController,
                            keyboardType: TextInputType.number,
                            maxLength: 4,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 12,
                            ),
                            decoration: InputDecoration(
                              hintText: '0 0 0 0',
                              hintStyle: TextStyle(
                                color: Colors.grey.shade400,
                                letterSpacing: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              counterText: '',
                            ),
                          ),
                          if (pileIndex != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Pile $pileIndex · Slot ${slotIndex ?? '?'}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                            ),
                          ],
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
                              deadlineAt = result['deadlineAt'] != null
                                  ? DateTime.tryParse(
                                      result['deadlineAt'].toString())
                                  : null;
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
                      child: const Text('Show Station Info'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        final code = codeController.text.trim();
                        if (code.length != 4) return;
                        Navigator.pop(ctx);
                        await _confirmSwap(reservationId, code);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Confirm Swap'),
                    ),
                  ],
          );
        },
      ),
    );
  }

  Future<void> _confirmSwap(String reservationId, String swapCode) async {
    final notifier = ref.read(batterySwapProvider.notifier);
    bool confirming = true;
    String? error;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          if (confirming && error == null) {
            Future.microtask(() async {
              try {
                await notifier.verifySwap(reservationId, swapCode);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Swap completed successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  setDialogState(() {
                    error = formatApiError(e);
                    confirming = false;
                  });
                }
              }
            });
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                FaIcon(FontAwesomeIcons.checkCircle, color: Colors.green.shade700),
                const SizedBox(width: 8),
                const Text('Confirm Swap'),
              ],
            ),
            content: error != null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FaIcon(FontAwesomeIcons.triangleExclamation,
                          size: 48, color: Colors.red.shade400),
                      const SizedBox(height: 12),
                      Text(error!, textAlign: TextAlign.center),
                    ],
                  )
                : const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Confirming swap...'),
                    ],
                  ),
            actions: error != null
                ? [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Close'),
                    ),
                  ]
                : null,
          );
        },
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
                    : '${widget.label} ${_formatSwapDuration(Duration(seconds: seconds))}',
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

  String _formatSwapDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }
}

class _CountdownTimer extends StatefulWidget {
  final String label;
  final DateTime from;
  final String expiredLabel;
  final VoidCallback onExpired;

  const _CountdownTimer({
    required this.label,
    required this.from,
    required this.expiredLabel,
    required this.onExpired,
  });

  @override
  State<_CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<_CountdownTimer> {
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
          margin: const EdgeInsets.only(top: 6),
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
    if (m > 0) {
      return '${m}m ${s}s';
    }
    return '${s}s';
  }
}

class _StationDetailSheet extends ConsumerWidget {
  final String stationId;
  final int basePriceVnd;

  const _StationDetailSheet({
    required this.stationId,
    required this.basePriceVnd,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(_stationDetailProvider(stationId));
    final theme = Theme.of(context);

    return detailAsync.when(
      data: (detail) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: FaIcon(
                          FontAwesomeIcons.batteryFull,
                          color: theme.colorScheme.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              detail.name ?? 'Battery Swap Station',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if ((detail.address ?? '').isNotEmpty)
                              Text(
                                detail.address!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color:
                                      theme.colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _StatItem(
                          label: 'Piles',
                          value: '${detail.totalPiles}',
                          icon: FontAwesomeIcons.chargingStation,
                        ),
                        _StatItem(
                          label: 'Ready',
                          value: '${detail.availableBatteries}',
                          icon: FontAwesomeIcons.batteryFull,
                          color: detail.availableBatteries > 0
                              ? Colors.green
                              : Colors.orange,
                        ),
                        _StatItem(
                          label: 'Total',
                          value: '${detail.totalSlots}',
                          icon: FontAwesomeIcons.layerGroup,
                          color: theme.colorScheme.secondary,
                        ),
                        _StatItem(
                          label: 'Fee',
                          value: '$basePriceVnd VND',
                          icon: FontAwesomeIcons.dollarSign,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Swap pile layout',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...detail.piles.map((pile) => _buildPileCard(
                        context,
                        pile,
                      )),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: detail.availableBatteries > 0
                          ? () => Navigator.pop(context, detail)
                          : null,
                      icon: const FaIcon(FontAwesomeIcons.bolt, size: 14),
                      label: Text(
                        detail.availableBatteries > 0
                            ? 'Book battery swap'
                            : 'No batteries ready (charging)',
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Rating & reviews (reused widget, no copy-paste)
                  StationRatingSection(
                    stationId: stationId,
                    compact: true,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) {
        final err = e as ApiError;
        final isNotSwap = err.code == 'NOT_A_BATTERY_SWAP_STATION';
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FaIcon(
                isNotSwap ? FontAwesomeIcons.carBattery : Icons.error_outline,
                size: 48,
                color: isNotSwap ? Colors.orange : Colors.red,
              ),
              const SizedBox(height: 8),
              Text(
                isNotSwap
                    ? 'This station does not have battery swap service.'
                    : 'Failed to load station detail',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 4),
              if (!isNotSwap)
                Text(
                  '$e',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPileCard(BuildContext context, SwapPileModel pile) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.3),
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
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                FaIcon(
                  FontAwesomeIcons.chargingStation,
                  size: 14,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
                const SizedBox(width: 8),
                Text(
                  'Swap Pile ${pile.pileIndex}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: pile.availableSlots > 0
                        ? Colors.green.shade100
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${pile.availableSlots} ready',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: pile.availableSlots > 0
                          ? Colors.green.shade800
                          : Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                if (pile.chargingSlots > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${pile.chargingSlots} charging',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.w500,
                      ),
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
                final isAvail = slot.status == BatterySlotStatus.available;
                final isCharging = slot.status == BatterySlotStatus.charging ||
                    slot.status == BatterySlotStatus.swappedOut;
                final isReserved = slot.status == BatterySlotStatus.reserved;

                return Tooltip(
                  message: _buildSlotTooltipDetail(slot),
                  child: Container(
                    width: 52,
                    height: 60,
                    decoration: BoxDecoration(
                      color: isAvail
                          ? Colors.green.shade50
                          : isCharging
                              ? Colors.orange.shade50
                              : Colors.grey.shade100,
                      border: Border.all(
                        color: isAvail
                            ? Colors.green.shade300
                            : isCharging
                                ? Colors.orange.shade300
                                : Colors.grey.shade300,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isCharging && slot.batteryChargePercent < 100) ...[
                          SizedBox(
                            width: 24,
                            height: 10,
                            child: LinearProgressIndicator(
                              value: slot.batteryChargePercent / 100,
                              backgroundColor: Colors.orange.shade200,
                              valueColor: AlwaysStoppedAnimation(Colors.orange.shade700),
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
                          color: isAvail
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
                            color: isAvail
                                ? Colors.green
                                : isCharging
                                    ? Colors.orange.shade800
                                    : theme.colorScheme.onSurface.withOpacity(0.6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _formatSlotEta(DateTime utcTime) {
    final local = utcTime.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  String _buildSlotTooltipDetail(BatterySlotModel slot) {
    switch (slot.status) {
      case BatterySlotStatus.available:
        return 'Slot ${slot.slotIndex}: Ready (100%)';
      case BatterySlotStatus.charging:
      case BatterySlotStatus.swappedOut:
        if (slot.estimatedFullAt == null) {
          return 'Slot ${slot.slotIndex}: Charging ${slot.batteryChargePercent}%';
        }
        return 'Slot ${slot.slotIndex}: Charging ${slot.batteryChargePercent}% — Full at ${_formatSlotEta(slot.estimatedFullAt!)}';
      case BatterySlotStatus.reserved:
        return 'Slot ${slot.slotIndex}: Reserved';
      case BatterySlotStatus.occupied:
        return 'Slot ${slot.slotIndex}: Occupied';
    }
  }
}

class _PreSelectedStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _PreSelectedStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        FaIcon(icon, size: 16, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.primary;
    return Column(
      children: [
        FaIcon(icon, size: 16, color: c),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: c,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const _ErrorBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.error.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          FaIcon(FontAwesomeIcons.triangleExclamation,
              color: theme.colorScheme.error, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Close',
            iconSize: 16,
            onPressed: onDismiss,
            icon: const FaIcon(FontAwesomeIcons.xmark),
          ),
        ],
      ),
    );
  }
}
