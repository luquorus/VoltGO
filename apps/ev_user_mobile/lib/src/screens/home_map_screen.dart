import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:shared_auth/shared_auth.dart';
import '../providers/station_providers.dart';
import '../providers/routing_provider.dart';
import '../widgets/station_marker.dart';
import '../widgets/main_scaffold.dart';
import '../models/battery_swap_models.dart';
import '../models/route_models.dart';
export '../providers/routing_provider.dart' show RouteStatus;

/// Home Map Screen with OpenStreetMap + Leaflet and bottom sheet station list
class HomeMapScreen extends ConsumerStatefulWidget {
  const HomeMapScreen({super.key});

  @override
  ConsumerState<HomeMapScreen> createState() => _HomeMapScreenState();
}

class _HomeMapScreenState extends ConsumerState<HomeMapScreen> {
  final MapController _mapController = MapController();
  String? _selectedStationId;
  double _radiusKm = 5.0;
  double _batterySwapRadiusKm = 5.0;
  double? _minPowerKw;
  bool? _hasAC;
  LatLng? _currentLocation;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  bool _isSearchMode = false;
  Timer? _searchDebounce;
  bool _showBatterySwapMarkers = false;
  List<BatterySwapStationModel> _batterySwapStations = [];
  int _mapFitBoundsVersion = 0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _destinationController.addListener(_onDestinationChanged);
    _requestLocationAndSearch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _destinationController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onDestinationChanged() {
    final query = _destinationController.text.trim();
    final notifier = ref.read(routingProvider.notifier);
    notifier.searchDestination(query);
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    final query = _searchController.text.trim();
    
    if (query.isEmpty) {
      setState(() {
        _isSearchMode = false;
      });
      // Reset to location-based search
      if (_currentLocation != null) {
        final notifier = ref.read(stationSearchProvider.notifier);
        notifier.search(StationSearchParams(
          lat: _currentLocation!.latitude,
          lng: _currentLocation!.longitude,
          radiusKm: _radiusKm,
          minPowerKw: _minPowerKw,
          hasAC: _hasAC,
        ));
      }
      return;
    }

    setState(() {
      _isSearchMode = true;
    });

    // Debounce search - wait 500ms after user stops typing
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted && query.isNotEmpty) {
        final notifier = ref.read(stationSearchProvider.notifier);
        notifier.searchByName(query);
      }
    });
  }

  Future<void> _requestLocationAndSearch() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          AppToast.showWarning(
            context,
            'Location is off. Please enable GPS to find stations near you.',
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            AppToast.showError(
                context, 'You denied location permission.');
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          AppToast.showError(context,
              'Location permission was permanently denied. Open Settings to grant access.');
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      final location = LatLng(position.latitude, position.longitude);

      setState(() {
        _currentLocation = location;
      });

      // Set origin in routing provider
      ref.read(routingProvider.notifier).setOrigin(location);

      final notifier = ref.read(stationSearchProvider.notifier);
      await notifier.search(StationSearchParams(
        lat: position.latitude,
        lng: position.longitude,
        radiusKm: _radiusKm,
        minPowerKw: _minPowerKw,
        hasAC: _hasAC,
      ));

      _mapController.move(location, 13.0);

      // Also load battery swap stations if the toggle is on
      if (_showBatterySwapMarkers) {
        await _loadBatterySwapStations(location.latitude, location.longitude);
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(
            context, 'Could not get location: ${formatApiError(e)}');
      }
    }
  }

  Future<void> _loadBatterySwapStations(double lat, double lng) async {
    try {
      final repository = ref.read(stationRepositoryProvider);
      final stations = await repository.getBatterySwapStations(
        lat: lat,
        lng: lng,
        radiusKm: _batterySwapRadiusKm,
      );
      if (mounted) {
        setState(() {
          _batterySwapStations = stations;
        });
      }
    } catch (e) {
      // Non-critical - battery swap stations load failure is silent
    }
  }

  void _onDestinationSelected(PlaceSuggestion suggestion) {
    _destinationController.text = suggestion.shortName;
    _ensureBatteryInfo();
    ref.read(routingProvider.notifier).selectDestination(suggestion);
    setState(() {
      _mapFitBoundsVersion++;
    });
  }

  void _ensureBatteryInfo() {
    final routingState = ref.read(routingProvider);
    if (routingState.batteryPercent == null || routingState.vehicleRangeKm == null) {
      // No battery info set yet — show dialog as overlay
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showBatterySetupIfNeeded(context, routingState);
      });
    }
  }

  void _onLongPressWithBatterySetup(LatLng point) {
    _ensureBatteryInfo();
    ref.read(routingProvider.notifier).selectDestinationByLongPress(point);
    ref.read(routingProvider.notifier).hideSuggestions();
    _destinationController.text = 'Long press location';
    setState(() {
      _mapFitBoundsVersion++;
    });
  }

  void _clearRoute() {
    ref.read(routingProvider.notifier).clearRoute();
    _destinationController.clear();
    setState(() {
      _mapFitBoundsVersion++;
    });
  }

  void _showRecommendedStationSheet(BuildContext context, RecommendedStation station) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _RecommendedStationSheet(
        station: station,
        onNavigate: () {
          Navigator.pop(ctx);
          context.push('/stations/${station.stationId}');
        },
      ),
    );
  }

  Widget _buildMapWidget(List<Marker> markers, List<Marker> swapMarkers, List<Marker> routeStationMarkers) {
    final routingState = ref.watch(routingProvider);
    final initialLocation = _currentLocation ?? const LatLng(21.0285, 105.8542); // Default: Hanoi

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: initialLocation,
        initialZoom: 13.0,
        onTap: (tapPosition, point) {
          // Dismiss suggestions when tapping map
          ref.read(routingProvider.notifier).hideSuggestions();
        },
        onLongPress: (tapPosition, point) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Finding route to ${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}...'),
              duration: const Duration(seconds: 1),
            ),
          );
          _onLongPressWithBatterySetup(point);
        },
        onMapEvent: (event) {
          // Map event handling
        },
      ),
      children: [
        // OpenStreetMap tile layer
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.ev_user_mobile',
          maxZoom: 19,
        ),
        // Route polyline
        if (routingState.showRoute && routingState.route != null)
          PolylineLayer(
            polylines: [
              Polyline(
                points: routingState.route!.polyline
                    .map((p) => LatLng(p.lat, p.lng))
                    .toList(),
                strokeWidth: 5.0,
                color: const Color(0xFF2196F3),
              ),
            ],
          ),
        // Markers layer (normal stations)
        MarkerLayer(
          markers: [...markers, ...swapMarkers],
        ),
        // Route station markers (orange/amber)
        if (routingState.showRoute && routingState.route != null)
          MarkerLayer(
            markers: routeStationMarkers,
          ),
        // Current location marker
        if (_currentLocation != null)
          MarkerLayer(
            markers: [
              Marker(
                point: _currentLocation!,
                width: 40,
                height: 40,
                child: const FaIcon(
                  FontAwesomeIcons.locationDot,
                  color: Colors.blue,
                  size: 30,
                ),
              ),
            ],
          ),
        // Destination marker (when route is shown)
        if (routingState.showRoute && routingState.destinationMarker != null)
          MarkerLayer(
            markers: [
              Marker(
                point: routingState.destinationMarker!.position,
                width: 40,
                height: 40,
                child: const _DestinationMarker(),
              ),
            ],
          ),
      ],
    );
  }

  void _onMarkerTap(String stationId) {
    // Navigate to station detail screen
    context.push('/stations/$stationId');
  }

  void _onBatterySwapMarkerTap(BatterySwapStationModel station) {
    context.push('/battery-swap?stationId=${station.stationId}');
  }

  Future<void> _onFilterChanged() async {
    try {
      LatLng? location = _currentLocation;
      if (location == null) {
        final position = await Geolocator.getCurrentPosition();
        location = LatLng(position.latitude, position.longitude);
        if (mounted) setState(() => _currentLocation = location);
      }

      final notifier = ref.read(stationSearchProvider.notifier);
      await notifier.updateFilters(StationSearchParams(
        lat: location.latitude,
        lng: location.longitude,
        radiusKm: _radiusKm,
        minPowerKw: _minPowerKw,
        hasAC: _hasAC,
      ));

      if (_showBatterySwapMarkers) {
        await _loadBatterySwapStations(location.latitude, location.longitude);
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(
            context, 'Could not apply filters: ${formatApiError(e)}');
      }
    }
  }

  Widget _buildRecommendedMarker(RecommendedStation station, {bool isOptimal = false}) {
    return Container(
      width: isOptimal ? 52 : 44,
      height: isOptimal ? 52 : 44,
      decoration: BoxDecoration(
        color: isOptimal ? Colors.green : Colors.orange,
        shape: BoxShape.circle,
        border: Border.all(
          color: isOptimal ? Colors.lightGreen.shade200 : Colors.white,
          width: isOptimal ? 3 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isOptimal ? Colors.green : Colors.orange).withOpacity(0.4),
            blurRadius: isOptimal ? 8 : 4,
            spreadRadius: isOptimal ? 2 : 0,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          FaIcon(
            FontAwesomeIcons.bolt,
            color: Colors.white,
            size: isOptimal ? 20 : 16,
          ),
          if (isOptimal)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  color: Colors.amber,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: FaIcon(
                    FontAwesomeIcons.star,
                    color: Colors.white,
                    size: 9,
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                station.score.toStringAsFixed(0),
                style: TextStyle(
                  color: isOptimal ? Colors.green : Colors.orange,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteRecommendationSheet(BuildContext context, RoutingState routingState) {
    final theme = Theme.of(context);
    final route = routingState.route!;
    final summary = route.summary;
    final stations = route.recommendedStations;
    final optimal = route.optimalStation;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outline.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Route summary header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                FaIcon(
                  FontAwesomeIcons.route,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        routingState.destinationMarker?.name ??
                            routingState.destinationName ??
                            'Route',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${summary.distanceKm.toStringAsFixed(1)} km · ~${summary.durationMinutes} min',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _clearRoute,
                  child: const Text('Clear'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Battery recommendation status chip
          if (routingState.batteryPercent != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: routingState.needsChargingStop
                            ? Colors.orange.withOpacity(0.1)
                            : Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FaIcon(
                            routingState.needsChargingStop
                                ? FontAwesomeIcons.batteryHalf
                                : FontAwesomeIcons.batteryFull,
                            color: routingState.needsChargingStop
                                ? Colors.orange
                                : Colors.green,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '${routingState.batteryPercent}% pin · ${routingState.remainingRangeKm?.toStringAsFixed(0) ?? '?'} km',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: routingState.needsChargingStop
                                    ? Colors.orange
                                    : Colors.green,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (routingState.needsChargingStop) ...[
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                ' - Need charging',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ] else ...[
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                ' - Enough for trip',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (stations.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.teal.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const FaIcon(
                              FontAwesomeIcons.bolt,
                              color: Colors.teal,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '${stations.length} stations along route',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.teal,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
          ] else if (stations.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const FaIcon(
                          FontAwesomeIcons.bolt,
                          color: Colors.orange,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${stations.length} charging stations along route',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.orange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          // Station list — empty state
          if (stations.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  FaIcon(
                    FontAwesomeIcons.bolt,
                    color: theme.colorScheme.onSurface.withOpacity(0.25),
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No charging stations found along this route',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Try expanding your search or choosing a different route',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.45),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          if (stations.isNotEmpty) ...[
            // Primary recommendation card (top of list)
            if (optimal != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: _buildPrimaryRecommendationCard(context, optimal),
              ),
              const Divider(height: 8),
            ],
            // Top 3 list header
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 8),
              child: Row(
                children: [
                  Text(
                    'Top ${stations.length} Recommendations',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Lower score = better',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 150,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: stations.length,
                itemBuilder: (context, index) {
                  final station = stations[index];
                  return _buildRecommendedStationCard(context, station);
                },
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildRouteErrorSheet(BuildContext context, RoutingState routingState) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            alignment: Alignment.center,
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: FaIcon(
                  FontAwesomeIcons.triangleExclamation,
                  color: Colors.red.shade700,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Route unavailable',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      routingState.errorMessage ?? routingState.errorCode ?? 'Unable to calculate route',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.65),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _clearRoute,
                  icon: const FaIcon(FontAwesomeIcons.xmark, size: 14),
                  label: const Text('Clear'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    // Re-trigger route calculation
                    if (routingState.destination != null) {
                      setState(() {
                        _mapFitBoundsVersion++;
                      });
                      ref.read(routingProvider.notifier).retryRoute();
                    }
                  },
                  icon: const FaIcon(FontAwesomeIcons.rotate, size: 14),
                  label: const Text('Retry'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendedStationCard(BuildContext context, RecommendedStation station) {
    final theme = Theme.of(context);
    final isOptimal = station.isOptimalStop;
    final color = isOptimal ? Colors.green : Colors.orange;

    return Container(
      width: 210,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: color.withOpacity(0.3),
            width: isOptimal ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: () => _showRecommendedStationSheet(context, station),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: FaIcon(
                          station.isOptimalStop ? FontAwesomeIcons.star : FontAwesomeIcons.bolt,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        station.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  station.address,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                // Recommendation reason
                if (station.recommendationReason != null)
                  Text(
                    station.recommendationReason!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: color,
                      fontSize: 10,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                const Spacer(),
                Row(
                  children: [
                    _buildStationChip(Icons.electric_bolt, '${station.totalPowerKw.toStringAsFixed(0)} kW', theme),
                    const SizedBox(width: 4),
                    _buildStationChip(Icons.ev_station, '${station.availablePorts}/${station.totalPorts}', theme),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildStationChip(Icons.route, '${(station.detourMeters / 1000).toStringAsFixed(1)} km', theme),
                    if (station.estimatedBatteryAtArrival != null) ...[
                      const SizedBox(width: 4),
                      _buildStationChip(
                        Icons.battery_std,
                        'Pin ~${station.estimatedBatteryAtArrival!.toStringAsFixed(0)}%',
                        theme,
                      ),
                    ],
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '#${station.score.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStationChip(IconData icon, String label, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: theme.colorScheme.onSurface.withOpacity(0.6)),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: theme.colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryRecommendationCard(BuildContext context, RecommendedStation station) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade50, Colors.lightGreen.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FaIcon(FontAwesomeIcons.star, color: Colors.white, size: 10),
                    SizedBox(width: 4),
                    Text(
                      'PRIMARY RECOMMENDATION',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              FaIcon(FontAwesomeIcons.carBattery, color: Colors.green.shade700, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            station.name,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          if (station.recommendationReason != null)
            Text(
              station.recommendationReason!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.green.shade700,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              _buildStationChip(Icons.electric_bolt, '${station.totalPowerKw.toStringAsFixed(0)} kW', theme),
              _buildStationChip(Icons.route, '${(station.detourMeters / 1000).toStringAsFixed(1)} km detour', theme),
              _buildStationChip(Icons.ev_station, '${station.availablePorts}/${station.totalPorts} ports', theme),
              if (station.estimatedBatteryAtArrival != null)
                _buildStationChip(Icons.battery_std, 'Battery ~${station.estimatedBatteryAtArrival!.toStringAsFixed(0)}%', theme),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.push('/stations/${station.stationId}'),
              icon: const FaIcon(FontAwesomeIcons.arrowRight, size: 14),
              label: const Text('Navigate to Station'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showBatterySetupDialog(BuildContext context, RoutingState routingState) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _BatterySetupSheet(
        currentBattery: routingState.batteryPercent ?? 50,
        currentRange: routingState.vehicleRangeKm ?? 300,
      ),
    );

    if (result != null && mounted) {
      final battery = result['battery'] as int;
      final range = result['range'] as double;
      ref.read(routingProvider.notifier).setBatteryInfo(battery, range);

      // Re-calculate route with new battery info if destination is set
      if (routingState.destination != null) {
        setState(() {
          _mapFitBoundsVersion++;
        });
        ref.read(routingProvider.notifier).selectDestinationByCoordinates(routingState.destination!);
      }
    }
  }

  Future<void> _showBatterySetupIfNeeded(BuildContext context, RoutingState routingState) async {
    // Only show if battery info is truly missing (not just defaults)
    if (routingState.batteryPercent == null && routingState.vehicleRangeKm == null) {
      // First time routing without battery info — prompt user to set it
      final result = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => _BatterySetupSheet(
          currentBattery: 50,
          currentRange: 300,
        ),
      );

      if (result != null && mounted) {
        final battery = result['battery'] as int;
        final range = result['range'] as double;
        ref.read(routingProvider.notifier).setBatteryInfo(battery, range);

        // Re-calculate route with battery info
        if (routingState.destination != null) {
          setState(() => _mapFitBoundsVersion++);
          ref.read(routingProvider.notifier).selectDestinationByCoordinates(routingState.destination!);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(stationSearchProvider);
    final routingState = ref.watch(routingProvider);
    final theme = Theme.of(context);

    // Build markers from charging stations
    final markers = <Marker>[];
    for (final station in state.stations) {
      final stationId = station['stationId'] as String? ?? '';
      final lat = station['lat'] as double?;
      final lng = station['lng'] as double?;
      final swap = station['supportsBatterySwap'] == true;

      if (lat != null && lng != null) {
        markers.add(
          Marker(
            point: LatLng(lat, lng),
            width: 28,
            height: 28,
            child: GestureDetector(
              onTap: () => _onMarkerTap(stationId),
              child: StationMarker(isBatterySwap: swap),
            ),
          ),
        );
      }
    }

    // Add battery swap station markers
    final swapMarkers = <Marker>[];
    if (_showBatterySwapMarkers) {
      for (final station in _batterySwapStations) {
        final lat = station.lat;
        final lng = station.lng;
        if (lat != null && lng != null) {
          swapMarkers.add(
            Marker(
              point: LatLng(lat, lng),
              width: 32,
              height: 32,
              child: GestureDetector(
                onTap: () => _onBatterySwapMarkerTap(station),
                child: const BatterySwapMapMarker(),
              ),
            ),
          );
        }
      }
    }

    // Build recommended station markers for route
    final routeStationMarkers = <Marker>[];
    if (routingState.showRoute && routingState.route != null) {
      for (final station in routingState.route!.recommendedStations) {
        final isOptimal = routingState.route!.optimalStation?.stationId == station.stationId;
        routeStationMarkers.add(
          Marker(
            point: LatLng(station.lat, station.lng),
            width: isOptimal ? 52 : 44,
            height: isOptimal ? 52 : 44,
            child: GestureDetector(
              onTap: () => _showRecommendedStationSheet(context, station),
              child: _buildRecommendedMarker(station, isOptimal: isOptimal),
            ),
          ),
        );
      }
    }

    // Auto-fit map bounds when route is shown
    // Use a version counter to prevent stale closures
    if (routingState.showRoute && routingState.route != null) {
      final fitVersion = _mapFitBoundsVersion;
      final polyline = routingState.route!.polyline;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (polyline.isEmpty) {
          debugPrint('[RoutingMap] fitBounds skipped - empty polyline');
          return;
        }
        try {
          final bounds = LatLngBounds.fromPoints(
            polyline.map((p) => LatLng(p.lat, p.lng)).toList(),
          );
          // Only fit if this is still the current version
          if (fitVersion == _mapFitBoundsVersion) {
            _mapController.fitCamera(
              CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(80)),
            );
          }
        } catch (e) {
          debugPrint('[RoutingMap] fitBounds error: $e');
        }
      });
    }

    // Route rendering diagnostic — fires after build when route is shown
    if (routingState.showRoute && routingState.route != null) {
      final polyline = routingState.route!.polyline;
      final stationMarkers = routingState.route!.recommendedStations.length;
      final seq = routingState.lastRouteSequence;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        try {
          if (polyline.isEmpty) {
            routingState.diagnostics.logRenderFailed(
              'EMPTY_POLYLINE', 'Polyline has no points', seq);
          } else {
            routingState.diagnostics.logRenderSuccess(
              polyline.length, stationMarkers, seq);
          }
        } catch (e, st) {
          routingState.diagnostics.logRenderFailed(
            'RENDER_EXCEPTION', e, seq);
          debugPrint('[RoutingMap] renderDiag error: $e\n$st');
        }
      });
    }

    return MainScaffold(
      showBottomNav: true,
      child: Stack(
        children: [
          // OSM map background
          _buildMapWidget(markers, swapMarkers, routeStationMarkers),

          // Destination search bar (above existing search bar)
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: _buildDestinationSearchBar(context, theme, routingState),
          ),

          // Route recommendation sheet at bottom (show route data or error)
          if (routingState.showRoute && routingState.route != null)
            DraggableScrollableSheet(
              initialChildSize: 0.25,
              minChildSize: 0.15,
              maxChildSize: 0.5,
              builder: (context, scrollController) {
                return SingleChildScrollView(
                  controller: scrollController,
                  child: _buildRouteRecommendationSheet(context, routingState),
                );
              },
            ),

          // Route error bottom sheet — shown when route calculation failed but destination is set
          if (routingState.status == RouteStatus.error &&
              routingState.destination != null)
            DraggableScrollableSheet(
              initialChildSize: 0.15,
              minChildSize: 0.08,
              maxChildSize: 0.25,
              builder: (context, scrollController) {
                return SingleChildScrollView(
                  controller: scrollController,
                  child: _buildRouteErrorSheet(context, routingState),
                );
              },
            ),

          // Bottom sheet with station list (when no route)
          if (!routingState.showRoute)
            DraggableScrollableSheet(
              initialChildSize: 0.4,
              minChildSize: 0.2,
              maxChildSize: 0.9,
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Handle bar
                      Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 8),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.outline.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),

                      // Header with filters summary
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Text(
                              'Charging stations (${state.totalElements})',
                              style: theme.textTheme.titleLarge,
                            ),
                            const Spacer(),
                            if (_showBatterySwapMarkers)
                              Badge(
                                label: Text('${_batterySwapStations.length}'),
                                child: IconButton(
                                  icon: FaIcon(
                                    FontAwesomeIcons.carBattery,
                                    color: theme.colorScheme.primary,
                                  ),
                                  tooltip: 'Battery swap markers on',
                                  onPressed: () => _showBatterySwapFilterSheet(context),
                                ),
                              )
                            else
                              IconButton(
                                icon: FaIcon(
                                  FontAwesomeIcons.carBattery,
                                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                                ),
                                tooltip: 'Show battery swap stations',
                                onPressed: () => _toggleBatterySwapMarkers(context),
                              ),
                            IconButton(
                              icon: const FaIcon(FontAwesomeIcons.bolt),
                              tooltip: 'Optimize by time',
                              onPressed: () => context.push('/recommendations'),
                            ),
                            IconButton(
                              icon: FaIcon(
                                FontAwesomeIcons.batteryHalf,
                                color: _showBatterySwapMarkers
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurface.withOpacity(0.5),
                              ),
                              tooltip: 'Battery swap',
                              onPressed: () => context.push('/battery-swap'),
                            ),
                            IconButton(
                              icon: const FaIcon(FontAwesomeIcons.filter),
                              tooltip: 'Filters',
                              onPressed: () => _showFilterDialog(context),
                            ),
                          ],
                        ),
                      ),

                      const Divider(height: 1),

                      // Station list
                      Expanded(
                        child: _buildStationList(context, state, scrollController),
                      ),
                    ],
                  ),
                );
              },
            ),

          // Loading indicator when calculating route
          if (routingState.status == RouteStatus.loading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Calculating route...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDestinationSearchBar(
    BuildContext context,
    ThemeData theme,
    RoutingState routingState,
  ) {
    final tealColor = Colors.teal[800] ?? Colors.green[900] ?? Colors.teal;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Battery status chip (shown when battery info is set)
        if (routingState.batteryPercent != null && routingState.vehicleRangeKm != null)
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: routingState.needsChargingStop
                  ? Colors.orange.shade50
                  : Colors.green.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: routingState.needsChargingStop
                    ? Colors.orange.shade200
                    : Colors.green.shade200,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FaIcon(
                  routingState.needsChargingStop
                      ? FontAwesomeIcons.batteryHalf
                      : FontAwesomeIcons.batteryFull,
                  color: routingState.needsChargingStop
                      ? Colors.orange.shade700
                      : Colors.green.shade700,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  '${routingState.batteryPercent}%',
                  style: TextStyle(
                    color: routingState.needsChargingStop
                        ? Colors.orange.shade700
                        : Colors.green.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '~${routingState.remainingRangeKm?.toStringAsFixed(0)} km',
                  style: TextStyle(
                    color: routingState.needsChargingStop
                        ? Colors.orange.shade600
                        : Colors.green.shade600,
                    fontSize: 12,
                  ),
                ),
                if (routingState.needsChargingStop) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Need charging',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _showBatterySetupDialog(context, routingState),
                  child: FaIcon(
                    FontAwesomeIcons.pen,
                    color: Colors.grey.shade400,
                    size: 12,
                  ),
                ),
              ],
            ),
          ),
        // Destination search field
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: FaIcon(
                  FontAwesomeIcons.locationDot,
                  color: routingState.showRoute ? Colors.orange : tealColor,
                  size: 20,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _destinationController,
                  autofocus: false,
                  onTap: () {
                    if (routingState.showRoute) {
                      // Show suggestions even when route is active
                      ref.read(routingProvider.notifier).showSuggestionsList();
                    }
                  },
                  decoration: InputDecoration(
                    hintText: routingState.showRoute
                        ? routingState.destinationName ?? 'Where to?'
                        : 'Where to?',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
                  ),
                  style: TextStyle(color: tealColor),
                ),
              ),
              if (_destinationController.text.isNotEmpty || routingState.showRoute)
                IconButton(
                  icon: FaIcon(
                    FontAwesomeIcons.xmark,
                    color: Colors.grey[600],
                    size: 16,
                  ),
                  onPressed: _clearRoute,
                ),
            ],
          ),
        ),

        // Suggestions dropdown
        if (routingState.showSuggestions && routingState.suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 250),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: routingState.suggestions.length,
                itemBuilder: (context, index) {
                  final suggestion = routingState.suggestions[index];
                  return ListTile(
                    leading: FaIcon(
                      FontAwesomeIcons.locationDot,
                      color: tealColor,
                      size: 18,
                    ),
                    title: Text(
                      suggestion.shortName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      suggestion.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    onTap: () => _onDestinationSelected(suggestion),
                  );
                },
              ),
            ),
          ),

        // Loading indicator for suggestions
        if (routingState.isSearchingPlaces)
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Searching places...'),
              ],
            ),
          ),

        // Existing station search bar
        if (!routingState.showRoute)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _buildSearchBar(context, theme),
          ),
      ],
    );
  }

  Widget _buildStationList(
    BuildContext context,
    StationSearchState state,
    ScrollController scrollController,
  ) {
    if (state.isLoading && state.stations.isEmpty) {
      return const SkeletonList(
        count: 4,
        padding: EdgeInsets.all(16),
      );
    }

    if (state.error != null && state.stations.isEmpty) {
      return ErrorState(
        message: formatApiError(state.error),
        code: state.error!.code,
        traceId: state.error!.traceId,
        onRetry: () => _requestLocationAndSearch(),
      );
    }

    if (state.stations.isEmpty) {
      return EmptyState(
        icon: FontAwesomeIcons.locationDot,
        title: 'No charging stations found',
        message: _isSearchMode
            ? 'Try another keyword or clear search to see all stations.'
            : 'Expand the search radius or change filters and try again.',
        action: OutlinedButton.icon(
          onPressed: _requestLocationAndSearch,
          icon: const FaIcon(FontAwesomeIcons.rotate, size: 14),
          label: const Text('Reload'),
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: state.stations.length + (state.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == state.stations.length) {
          if (!state.isLoadingMore) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(stationSearchProvider.notifier).loadMore();
            });
          }
          return const Padding(
            padding: EdgeInsets.all(16),
            child: SkeletonListTile(),
          );
        }

        final station = state.stations[index];
        final stationId = station['stationId'] as String? ?? '';
        final isSelected = stationId == _selectedStationId;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildStationCard(context, station, isSelected),
        );
      },
    );
  }

  Widget _buildStationCard(
    BuildContext context,
    Map<String, dynamic> station,
    bool isSelected,
  ) {
    final theme = Theme.of(context);
    final name = station['name'] as String? ?? 'Unnamed station';
    final address = station['address'] as String? ?? '';
    final trustScore = station['trustScore'] as int? ?? 0;
    final chargingSummary = station['chargingSummary'] as Map<String, dynamic>?;
    final totalPorts = chargingSummary?['totalPorts'] as int? ?? 0;
    final maxPowerKw = chargingSummary?['maxPowerKw'] as double? ?? 0.0;
    final dcPorts = chargingSummary?['dcPorts'] as int? ?? 0;
    final acPorts = chargingSummary?['acPorts'] as int? ?? 0;
    final supportsBatterySwap = station['supportsBatterySwap'] as bool? ?? false;
    final batterySwap = station['batterySwap'] as Map<String, dynamic>?;
    final totalPiles = batterySwap?['totalPiles'] as int? ?? 0;
    final totalSlots = batterySwap?['totalSlots'] as int? ?? 0;
    final availableBatteries = batterySwap?['availableBatteries'] as int? ?? 0;

    return StationCard(
      title: name,
      subtitle: address,
      badges: [
        ScoreBadge(score: trustScore),
        // Battery-swap-only stations: show "X piles × Y pins" instead of "0 ports"
        if (supportsBatterySwap && totalPorts == 0 && totalPiles > 0)
          StatusPill(
            label: '$totalPiles × ${totalSlots ~/ totalPiles} piles',
            color: theme.colorScheme.primary,
          )
        else
          StatusPill(
            label: '$totalPorts ports',
            color: theme.colorScheme.primary,
          ),
        if (supportsBatterySwap && totalPorts > 0)
          StatusPill(
            label: '+ $totalPiles piles',
            color: Colors.teal,
          ),
        if (maxPowerKw > 0)
          StatusPill(
            label: 'Up to ${maxPowerKw.toStringAsFixed(0)}kW',
            color: theme.colorScheme.secondary,
          ),
        if (dcPorts > 0)
          StatusPill(
            label: '$dcPorts DC',
            color: Colors.blue,
          ),
        if (acPorts > 0)
          StatusPill(
            label: '$acPorts AC',
            color: Colors.green,
          ),
        if (supportsBatterySwap && availableBatteries > 0)
          StatusPill(
            label: '$availableBatteries ready',
            color: Colors.green,
          ),
      ],
      onTap: () {
        final stationId = station['stationId'] as String? ?? '';
        final lat = station['lat'] as double?;
        final lng = station['lng'] as double?;

        setState(() {
          _selectedStationId = stationId;
        });

        if (lat != null && lng != null) {
          _mapController.move(LatLng(lat, lng), 15.0);
        }

        // Battery-swap-only stations: navigate to battery swap screen
        if (supportsBatterySwap && totalPorts == 0) {
          context.push('/battery-swap?stationId=$stationId');
          return;
        }

        // Navigate to station detail
        context.push('/stations/$stationId');
      },
    );
  }

  Future<void> _toggleBatterySwapMarkers(BuildContext context) async {
    if (_showBatterySwapMarkers) {
      setState(() {
        _showBatterySwapMarkers = false;
        _batterySwapStations = [];
      });
      return;
    }

    if (_currentLocation == null) {
      try {
        final position = await Geolocator.getCurrentPosition();
        if (mounted) {
          _currentLocation = LatLng(position.latitude, position.longitude);
          await _loadBatterySwapStations(
            _currentLocation!.latitude,
            _currentLocation!.longitude,
          );
          setState(() {
            _showBatterySwapMarkers = true;
          });
        }
      } catch (e) {
        if (mounted) {
          AppToast.showError(context, 'Could not get location for battery swap search.');
        }
      }
      return;
    }

    if (mounted) {
      await _loadBatterySwapStations(
        _currentLocation!.latitude,
        _currentLocation!.longitude,
      );
      setState(() {
        _showBatterySwapMarkers = true;
      });
    }
  }

  Future<void> _showBatterySwapFilterSheet(BuildContext context) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _BatterySwapFilterSheet(
        radiusKm: _batterySwapRadiusKm,
        stations: _batterySwapStations,
      ),
    );

    if (result != null) {
      setState(() {
        _batterySwapRadiusKm = result['radiusKm'] as double;
      });
      if (_currentLocation != null) {
        await _loadBatterySwapStations(
          _currentLocation!.latitude,
          _currentLocation!.longitude,
        );
      }
    }
  }

  Future<void> _showFilterDialog(BuildContext context) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _FilterDialog(
        radiusKm: _radiusKm,
        minPowerKw: _minPowerKw,
        hasAC: _hasAC,
      ),
    );

    if (result != null) {
      setState(() {
        _radiusKm = result['radiusKm'] as double;
        _minPowerKw = result['minPowerKw'] as double?;
        _hasAC = result['hasAC'] as bool?;
      });
      await _onFilterChanged();
    }
  }

  Widget _buildSearchBar(BuildContext context, ThemeData theme) {
    final tealColor = Colors.teal[800] ?? Colors.green[900] ?? Colors.teal;

    return StatefulBuilder(
      builder: (context, setState) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            autofocus: false,
            onChanged: (value) {
              setState(() {});
            },
            decoration: InputDecoration(
              hintText: 'Search stations by name...',
              hintStyle: TextStyle(color: Colors.grey[600]),
              prefixIcon: Padding(
                padding: const EdgeInsets.all(12.0),
                child: FaIcon(
                  FontAwesomeIcons.magnifyingGlass,
                  color: tealColor,
                  size: 20,
                ),
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: FaIcon(
                        FontAwesomeIcons.xmark,
                        color: Colors.grey[600],
                        size: 16,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: tealColor, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            style: TextStyle(color: tealColor),
          ),
        );
      },
    );
  }
}

/// Filter Dialog
class _FilterDialog extends StatefulWidget {
  final double radiusKm;
  final double? minPowerKw;
  final bool? hasAC;

  const _FilterDialog({
    required this.radiusKm,
    this.minPowerKw,
    this.hasAC,
  });

  @override
  State<_FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<_FilterDialog> {
  late double _radiusKm;
  double? _minPowerKw;
  bool? _hasAC;

  @override
  void initState() {
    super.initState();
    _radiusKm = widget.radiusKm;
    _minPowerKw = widget.minPowerKw;
    _hasAC = widget.hasAC;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filters'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            decoration: const InputDecoration(
              labelText: 'Radius (km)',
              helperText: 'Required: 0.1 - 100 km',
            ),
            keyboardType: TextInputType.number,
            controller: TextEditingController(text: _radiusKm.toString()),
            onChanged: (value) {
              final parsed = double.tryParse(value);
              if (parsed != null && parsed >= 0.1 && parsed <= 100) {
                _radiusKm = parsed;
              }
            },
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Minimum power (kW) - Optional',
              helperText: 'Applies to DC ports only',
            ),
            keyboardType: TextInputType.number,
            controller: TextEditingController(
              text: _minPowerKw?.toString() ?? '',
            ),
            onChanged: (value) {
              if (value.isEmpty) {
                _minPowerKw = null;
              } else {
                final parsed = double.tryParse(value);
                if (parsed != null && parsed > 0) {
                  _minPowerKw = parsed;
                }
              }
            },
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            title: const Text('Has AC ports'),
            value: _hasAC ?? false,
            onChanged: (value) {
              setState(() {
                _hasAC = value;
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            setState(() {
              _minPowerKw = null;
              _hasAC = null;
            });
          },
          child: const Text('Clear options'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_radiusKm < 0.1 || _radiusKm > 100) return;
            Navigator.pop(context, {
              'radiusKm': _radiusKm,
              'minPowerKw': _minPowerKw,
              'hasAC': _hasAC,
            });
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

/// Battery swap map marker - distinct teal style
class BatterySwapMapMarker extends StatelessWidget {
  const BatterySwapMapMarker({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0xFF00695C),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Center(
        child: FaIcon(
          FontAwesomeIcons.batteryFull,
          color: Colors.white,
          size: 14,
        ),
      ),
    );
  }
}

/// Battery Swap Filter Sheet - separate radius for battery swap stations
class _BatterySwapFilterSheet extends StatefulWidget {
  final double radiusKm;
  final List<BatterySwapStationModel> stations;

  const _BatterySwapFilterSheet({
    required this.radiusKm,
    required this.stations,
  });

  @override
  State<_BatterySwapFilterSheet> createState() => _BatterySwapFilterSheetState();
}

class _BatterySwapFilterSheetState extends State<_BatterySwapFilterSheet> {
  late double _radiusKm;

  @override
  void initState() {
    super.initState();
    _radiusKm = widget.radiusKm;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FaIcon(
                FontAwesomeIcons.carBattery,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Battery swap stations',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
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
            '${widget.stations.length} station${widget.stations.length != 1 ? 's' : ''} found in current area',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Search radius',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          StatefulBuilder(
            builder: (ctx, setSheetState) {
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: _radiusKm,
                          min: 1,
                          max: 50,
                          divisions: 49,
                          label: '${_radiusKm.toStringAsFixed(0)} km',
                          onChanged: (v) {
                            setSheetState(() => _radiusKm = v);
                          },
                        ),
                      ),
                      SizedBox(
                        width: 56,
                        child: Text(
                          '${_radiusKm.toStringAsFixed(0)} km',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          if (widget.stations.isNotEmpty) ...[
            Text(
              'Nearby stations',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 160,
              child: ListView.builder(
                itemCount: widget.stations.length,
                itemBuilder: (ctx, idx) {
                  final s = widget.stations[idx];
                  return ListTile(
                    dense: true,
                    leading: FaIcon(
                      FontAwesomeIcons.carBattery,
                      color: s.availableBatteries > 0
                          ? Colors.green
                          : Colors.orange,
                      size: 16,
                    ),
                    title: Text(s.name ?? 'Unnamed station'),
                    subtitle: Text(
                      '${s.availableBatteries} ready · ${s.distanceKm?.toStringAsFixed(1) ?? '?'} km away',
                      style: theme.textTheme.bodySmall,
                    ),
                    trailing: FaIcon(
                      FontAwesomeIcons.chevronRight,
                      size: 12,
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                    ),
                    onTap: () {
                      Navigator.pop(context, {'radiusKm': _radiusKm});
                      context.push('/battery-swap?stationId=${s.stationId}');
                    },
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, {'radiusKm': _radiusKm}),
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Recommended Station Sheet - shows station details when tapped on route
class _RecommendedStationSheet extends StatelessWidget {
  final RecommendedStation station;
  final VoidCallback onNavigate;

  const _RecommendedStationSheet({
    required this.station,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: FaIcon(
                    FontAwesomeIcons.bolt,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      station.name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Score: ${station.score.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (station.rating != null) ...[
                          const FaIcon(
                            FontAwesomeIcons.star,
                            color: Colors.amber,
                            size: 14,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            station.rating!.toStringAsFixed(1),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ],
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
          const SizedBox(height: 12),
          Text(
            station.address,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          // Recommendation reason from backend
          if (station.recommendationReason != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  FaIcon(FontAwesomeIcons.circleInfo, color: Colors.green.shade700, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      station.recommendationReason!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.green.shade700,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                context,
                Icons.electric_bolt,
                '${station.totalPowerKw.toStringAsFixed(0)} kW',
                'Công suất',
              ),
              _buildStatItem(
                context,
                Icons.ev_station,
                '${station.availablePorts}/${station.totalPorts}',
                'Cổng',
              ),
              _buildStatItem(
                context,
                Icons.timer,
                '~${station.estimatedArrivalMinutes} min',
                'Arrival',
              ),
              if (station.estimatedBatteryAtArrival != null)
                _buildStatItem(
                  context,
                  Icons.battery_std,
                  '~${station.estimatedBatteryAtArrival!.toStringAsFixed(0)}%',
                  'Battery at arrival',
                )
              else
                _buildStatItem(
                  context,
                  Icons.route,
                  '${(station.detourMeters / 1000).toStringAsFixed(1)} km',
                  'Detour',
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Charging time row
          if (station.estimatedChargeMinutes > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  FaIcon(Icons.access_time, color: theme.colorScheme.primary, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Estimated charging: ',
                    style: theme.textTheme.bodySmall,
                  ),
                  Text(
                    '~${station.estimatedChargeMinutes} min',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const Spacer(),
                  if (station.optimalChargingStopMinutes != null)
                    Text(
                      'Total stop: ~${station.optimalChargingStopMinutes!.toStringAsFixed(0)} min',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          // Connector types
          if (station.connectorTypes.isNotEmpty) ...[
            Text(
              'Connector Types',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: station.connectorTypes.map((type) {
                return Chip(
                  label: Text(type),
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onNavigate,
              icon: const FaIcon(FontAwesomeIcons.arrowRight),
              label: const Text('View Station Details'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    IconData icon,
    String value,
    String label,
  ) {
    final theme = Theme.of(context);
    return Column(
      children: [
        FaIcon(icon, color: Colors.orange, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
    );
  }
}

/// Destination marker widget — Google Maps style red teardrop with center dot.
class _DestinationMarker extends StatelessWidget {
  const _DestinationMarker();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer pulsing circle (shadow effect)
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
        ),
        // Main teardrop shape
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: const Center(
            child: FaIcon(
              FontAwesomeIcons.locationPin,
              color: Colors.white,
              size: 14,
            ),
          ),
        ),
      ],
    );
  }
}

/// Battery setup sheet for EV users to input battery info
class _BatterySetupSheet extends StatefulWidget {
  final int currentBattery;
  final double currentRange;

  const _BatterySetupSheet({
    required this.currentBattery,
    required this.currentRange,
  });

  @override
  State<_BatterySetupSheet> createState() => _BatterySetupSheetState();
}

class _BatterySetupSheetState extends State<_BatterySetupSheet> {
  late double _battery;
  late double _range;

  @override
  void initState() {
    super.initState();
    _battery = widget.currentBattery.toDouble();
    _range = widget.currentRange;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remaining = (_battery / 100.0) * _range;

    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FaIcon(FontAwesomeIcons.carBattery, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 10),
              Text(
                'Vehicle Battery Info',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 20),
          // Current battery
          Text('Current Battery: ${_battery.toInt()}%', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Slider(
            value: _battery,
            min: 5,
            max: 100,
            divisions: 19,
            label: '${_battery.toInt()}%',
            onChanged: (v) => setState(() => _battery = v),
          ),
          const SizedBox(height: 16),
          // Max range
          Text('Max Range (at 100%): ${_range.toInt()} km', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Slider(
            value: _range,
            min: 100,
            max: 700,
            divisions: 60,
            label: '${_range.toInt()} km',
            onChanged: (v) => setState(() => _range = v),
          ),
          const SizedBox(height: 16),
          // Remaining range display
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: remaining < 50 ? Colors.orange.shade50 : Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: remaining < 50 ? Colors.orange.shade200 : Colors.green.shade200,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FaIcon(
                  remaining < 50 ? FontAwesomeIcons.batteryHalf : FontAwesomeIcons.batteryFull,
                  color: remaining < 50 ? Colors.orange.shade700 : Colors.green.shade700,
                ),
                const SizedBox(width: 8),
                Text(
                  'Remaining Range: ${remaining.toStringAsFixed(0)} km',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: remaining < 50 ? Colors.orange.shade700 : Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, {
                'battery': _battery.toInt(),
                'range': _range,
              }),
              child: const Text('Apply'),
            ),
          ),
        ],
      ),
    );
  }
}
