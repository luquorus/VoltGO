import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';
import '../providers/station_providers.dart';
import '../providers/routing_provider.dart';
import '../widgets/station_marker.dart';
import '../widgets/main_scaffold.dart';
import '../widgets/compact_station_card.dart';
import '../widgets/filter_bottom_sheet.dart';
import '../widgets/selected_station_preview.dart';
import '../models/battery_swap_models.dart';
import '../models/route_models.dart';
export '../providers/routing_provider.dart' show RouteStatus;

/// Service mode the user has selected in the bottom sheet.
enum HomeServiceMode {
  charging,
  batterySwap,
}

/// Home Map Screen — redesigned with a single search bar, clear service
/// selector, modal filter sheet, and a cleaner bottom sheet that switches
/// between Nearby and Route modes.
class HomeMapScreen extends ConsumerStatefulWidget {
  const HomeMapScreen({super.key});

  @override
  ConsumerState<HomeMapScreen> createState() => _HomeMapScreenState();
}

class _HomeMapScreenState extends ConsumerState<HomeMapScreen> {
  final MapController _mapController = MapController();

  // ── Selected UI state ────────────────────────────────────────────────
  String? _selectedStationId;
  HomeServiceMode _serviceMode = HomeServiceMode.charging;

  // ── Filter state ─────────────────────────────────────────────────────
  HomeMapFilterState _filter = const HomeMapFilterState();
  double _batterySwapRadiusKm = 5.0;

  // ── Search & location state ──────────────────────────────────────────
  LatLng? _currentLocation;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearchMode = false;
  Timer? _searchDebounce;

  // ── Battery swap local cache ─────────────────────────────────────────
  List<BatterySwapStationModel> _batterySwapStations = [];

  // ── Map fit bounds version (prevents stale fit calls) ────────────────
  int _mapFitBoundsVersion = 0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _requestLocationAndSearch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  // ── Search & destination input ───────────────────────────────────────

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    final query = _searchController.text.trim();

    // Empty query → reset search state, fall back to nearby search
    if (query.isEmpty) {
      setState(() => _isSearchMode = false);
      if (_currentLocation != null) {
        _triggerNearbySearch();
      }
      return;
    }

    setState(() => _isSearchMode = true);

    // Run both place search (for destination) and station-name search in
    // parallel so the user can find either with one bar. Suggestions are
    // shown via the routing provider.
    final notifier = ref.read(routingProvider.notifier);
    notifier.searchDestination(query);

    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted || query.isEmpty) return;
      final stationNotifier = ref.read(stationSearchProvider.notifier);
      stationNotifier.searchByName(query);
    });
  }

  void _onDestinationSelected(PlaceSuggestion suggestion) {
    _searchController.text = suggestion.shortName;
    _ensureBatteryInfo();
    ref.read(routingProvider.notifier).selectDestination(suggestion);
    setState(() => _mapFitBoundsVersion++);
  }

  void _ensureBatteryInfo() {
    final routingState = ref.read(routingProvider);
    if (routingState.batteryPercent == null || routingState.vehicleRangeKm == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showBatterySetupIfNeeded(context, routingState);
      });
    }
  }

  void _onLongPressWithBatterySetup(LatLng point) {
    _ensureBatteryInfo();
    ref.read(routingProvider.notifier).selectDestinationByLongPress(point);
    ref.read(routingProvider.notifier).hideSuggestions();
    _searchController.text = 'Long press location';
    setState(() => _mapFitBoundsVersion++);
  }

  void _clearRoute() {
    ref.read(routingProvider.notifier).clearRoute();
    _searchController.clear();
    setState(() => _mapFitBoundsVersion++);
  }

  // ── Location & search requests ──────────────────────────────────────

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
            AppToast.showError(context, 'You denied location permission.');
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
      setState(() => _currentLocation = location);

      ref.read(routingProvider.notifier).setOrigin(location);
      await _triggerNearbySearch();
      _mapController.move(location, 13.0);

      // Always preload battery-swap stations so the map shows BOTH
      // charging and swap markers regardless of the selected tab.
      await _loadBatterySwapStations(location.latitude, location.longitude);
    } catch (e) {
      if (mounted) {
        AppToast.showError(
            context, 'Could not get location: ${formatApiError(e)}');
      }
    }
  }

  Future<void> _triggerNearbySearch() async {
    if (_currentLocation == null) return;
    final notifier = ref.read(stationSearchProvider.notifier);
    await notifier.search(StationSearchParams(
      lat: _currentLocation!.latitude,
      lng: _currentLocation!.longitude,
      radiusKm: _filter.radiusKm,
      minPowerKw: _filter.minPowerKw,
      hasAC: _filter.hasAC,
    ));
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
        setState(() => _batterySwapStations = stations);
      }
    } catch (_) {
      // Silent — battery swap load failures should not block charging view.
    }
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
        radiusKm: _filter.radiusKm,
        minPowerKw: _filter.minPowerKw,
        hasAC: _filter.hasAC,
      ));
      // Reload battery-swap stations so the map keeps them in sync with
      // the current location, regardless of the active service-mode tab.
      await _loadBatterySwapStations(location.latitude, location.longitude);
    } catch (e) {
      if (mounted) {
        AppToast.showError(
            context, 'Could not apply filters: ${formatApiError(e)}');
      }
    }
  }

  // ── Service mode switching ──────────────────────────────────────────

  void _onServiceModeChanged(HomeServiceMode mode) {
    if (mode == _serviceMode) return;
    setState(() {
      _serviceMode = mode;
      _selectedStationId = null;
    });
    // The list filters by serviceMode, but the map always shows both
    // charging and battery-swap markers. Refresh on tab switch so the
    // list and the radius chip reflect the chosen mode.
    _loadBatterySwapStationsForCurrentLocation();
  }

  Future<void> _loadBatterySwapStationsForCurrentLocation() async {
    if (_currentLocation == null) {
      try {
        final position = await Geolocator.getCurrentPosition();
        if (mounted) {
          _currentLocation = LatLng(position.latitude, position.longitude);
        }
      } catch (e) {
        if (mounted) {
          AppToast.showError(context,
              'Could not get location for battery swap search.');
        }
        return;
      }
    }
    if (_currentLocation == null) return;
    await _loadBatterySwapStations(
      _currentLocation!.latitude,
      _currentLocation!.longitude,
    );
  }

  // ── Filter bottom sheet ─────────────────────────────────────────────

  Future<void> _openFilterSheet(BuildContext context) async {
    final result = await showModalBottomSheet<HomeMapFilterState>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => FilterBottomSheet(initialFilter: _filter),
    );
    if (result != null) {
      setState(() => _filter = result);
      await _onFilterChanged();
    }
  }

  Future<void> _openBatterySwapFilterSheet(BuildContext context) async {
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
    if (result != null && _currentLocation != null) {
      setState(() => _batterySwapRadiusKm = result['radiusKm'] as double);
      await _loadBatterySwapStations(
        _currentLocation!.latitude,
        _currentLocation!.longitude,
      );
    }
  }

  // ── Map widget ──────────────────────────────────────────────────────

  Widget _buildMapWidget(
    List<Marker> markers,
    List<Marker> swapMarkers,
    List<Marker> routeStationMarkers,
  ) {
    final routingState = ref.watch(routingProvider);
    final initialLocation =
        _currentLocation ?? const LatLng(21.0285, 105.8542); // Hanoi default

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: initialLocation,
        initialZoom: 13.0,
        onTap: (tapPosition, point) {
          ref.read(routingProvider.notifier).hideSuggestions();
        },
        onLongPress: (tapPosition, point) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Finding route to ${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}...',
              ),
              duration: const Duration(seconds: 1),
            ),
          );
          _onLongPressWithBatterySetup(point);
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.ev_user_mobile',
          maxZoom: 19,
        ),
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
        MarkerLayer(markers: [...markers, ...swapMarkers]),
        if (routingState.showRoute && routingState.route != null)
          MarkerLayer(markers: routeStationMarkers),
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
    setState(() => _selectedStationId = stationId);
  }

  void _onBatterySwapMarkerTap(BatterySwapStationModel station) {
    setState(() => _selectedStationId = station.stationId);
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(stationSearchProvider);
    final routingState = ref.watch(routingProvider);

    // Build markers for charging stations
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

    // Build battery swap markers — always shown on the map regardless
    // of the active service-mode tab. The list below is filtered by
    // serviceMode, but the map shows both types at all times.
    final swapMarkers = <Marker>[];
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

    // Build route recommended-station markers
    final routeStationMarkers = <Marker>[];
    if (routingState.showRoute && routingState.route != null) {
      for (final station in routingState.route!.recommendedStations) {
        final isOptimal =
            routingState.route!.optimalStation?.stationId == station.stationId;
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

    // Auto-fit map to route bounds
    if (routingState.showRoute && routingState.route != null) {
      final fitVersion = _mapFitBoundsVersion;
      final polyline = routingState.route!.polyline;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (polyline.isEmpty) return;
        try {
          final bounds = LatLngBounds.fromPoints(
            polyline.map((p) => LatLng(p.lat, p.lng)).toList(),
          );
          if (fitVersion == _mapFitBoundsVersion) {
            _mapController.fitCamera(
              CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(80)),
            );
          }
        } catch (_) {}
      });
    }

    // Route render diagnostic
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
        } catch (_) {}
      });
    }

    return MainScaffold(
      showBottomNav: true,
      child: Stack(
        children: [
          _buildMapWidget(markers, swapMarkers, routeStationMarkers),

          // Top search bar (always visible, single source of truth)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: _buildTopSearchBar(context, routingState),
            ),
          ),

          // Recommendation card removed — /recommendations screen is broken (white page).
          // See git history to restore if the destination screen is fixed.

          // Main bottom sheet (Nearby / Route mode)
          buildBottomSheet(context),

          // Route error sheet
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

          // Loading overlay
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

  // ── Top search bar (single source of truth) ─────────────────────────

  Widget _buildTopSearchBar(BuildContext context, RoutingState routingState) {
    final theme = Theme.of(context);
    final tealColor = Colors.teal[800] ?? Colors.green[900] ?? Colors.teal;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Main search bar + shared filter icon.
        // The filter icon opens the filter sheet for the active tab
        // (Charging → charging filters, Battery Swap → swap radius).
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Container(
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
                          FontAwesomeIcons.magnifyingGlass,
                          color: tealColor,
                          size: 20,
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onTap: () {
                            if (routingState.showRoute) {
                              ref
                                  .read(routingProvider.notifier)
                                  .showSuggestionsList();
                            }
                          },
                          decoration: InputDecoration(
                            hintText: 'Search station or destination',
                            hintStyle: TextStyle(color: Colors.grey[600]),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 0, vertical: 14),
                          ),
                          style: TextStyle(color: tealColor),
                        ),
                      ),
                      if (_searchController.text.isNotEmpty ||
                          routingState.showRoute)
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
              ),
              const SizedBox(width: 8),
              // Single, shared filter icon for both tabs. Behaviour
              // depends on the active service mode.
              IconButton.filledTonal(
                onPressed: () =>
                    _openFilterForActiveTab(context),
                icon: const FaIcon(FontAwesomeIcons.filter, size: 16),
                tooltip: _serviceMode == HomeServiceMode.charging
                    ? 'Filter charging stations'
                    : 'Filter battery swap radius',
              ),
            ],
          ),
        ),

        // Battery status pill — shown BELOW the search bar so it
        // is not occluded by the iPhone status bar / dynamic island.
        if (routingState.batteryPercent != null &&
            routingState.vehicleRangeKm != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _buildBatteryStatusPill(routingState, theme),
            ),
          ),

        // Battery-swap radius pill — only in Swap tab. Replaces the
        // previous floating chip on the map; sits right under the
        // search bar so it stays clear of iPhone safe-area.
        if (_serviceMode == HomeServiceMode.batterySwap)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _buildBatterySwapRadiusChip(),
            ),
          ),

        // Suggestions dropdown
        if (routingState.showSuggestions && routingState.suggestions.isNotEmpty)
          _buildSuggestionsPanel(routingState, theme, tealColor),

        // Loading indicator for suggestions
        if (routingState.isSearchingPlaces)
          _buildSuggestionsLoadingIndicator(theme),
      ],
    );
  }

  void _openFilterForActiveTab(BuildContext context) {
    if (_serviceMode == HomeServiceMode.charging) {
      _openFilterSheet(context);
    } else {
      _openBatterySwapFilterSheet(context);
    }
  }

  Widget _buildBatteryStatusPill(RoutingState routingState, ThemeData theme) {
    return Container(
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
    );
  }

  Widget _buildSuggestionsPanel(
      RoutingState routingState, ThemeData theme, Color tealColor) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
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
    );
  }

  Widget _buildSuggestionsLoadingIndicator(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
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
    );
  }

  Widget _buildBatterySwapRadiusChip() {
    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _openBatterySwapFilterSheet(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FaIcon(
                FontAwesomeIcons.batteryFull,
                color: const Color(0xFF00695C),
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                '${_batterySwapRadiusKm.toStringAsFixed(0)} km · ${_batterySwapStations.length} stations',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF00695C),
                ),
              ),
              const SizedBox(width: 4),
              const FaIcon(
                FontAwesomeIcons.chevronDown,
                size: 10,
                color: Color(0xFF00695C),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Recommended marker (route mode) ─────────────────────────────────

  Widget _buildRecommendedMarker(RecommendedStation station,
      {bool isOptimal = false}) {
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

  // ── Route-mode bottom sheet (recommendation sheet) ──────────────────

  Widget _buildRouteRecommendationSheet(
    BuildContext context,
    RoutingState routingState,
    ScrollController scrollController,
  ) {
    final theme = Theme.of(context);
    final route = routingState.route!;
    final summary = route.summary;
    final stations = route.recommendedStations;
    final optimal = route.optimalStation;

    return Material(
      color: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      elevation: 8,
      shadowColor: Colors.black.withOpacity(0.15),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Column(
          // Fill the sheet's allotted height — the parent DraggableScrollableSheet
          // gives us a finite BoxConstraints via SizedBox.expand, so this Column
          // will stretch exactly to the panel height. The inner SingleChildScrollView
          // handles overflow when content exceeds that height.
          mainAxisSize: MainAxisSize.max,
          children: [
            // Drag handle (visual affordance only — DraggableScrollableSheet
            // accepts drag gestures anywhere on the sheet body).
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Route summary header (fixed at top of sheet)
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
            // Scrollable body — uses the DraggableScrollableSheet's controller
            // so the sheet drag-handle and the body scroll stay in sync.
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                physics: const ClampingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (routingState.batteryPercent != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildBatteryStatusPill(routingState, theme),
                      )
                    else if (stations.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
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
                    if (stations.isNotEmpty && optimal != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: _buildPrimaryRecommendationCard(context, optimal),
                      ),
                    if (stations.isNotEmpty && optimal != null)
                      const Divider(height: 8),
                    if (stations.isNotEmpty)
                      Padding(
                        padding:
                            const EdgeInsets.only(left: 16, right: 16, top: 8),
                        child: Row(
                          children: [
                            Text(
                              'Top ${stations.length} Recommendations',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color:
                                    theme.colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Lower score = better',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color:
                                    theme.colorScheme.onSurface.withOpacity(0.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (stations.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: SizedBox(
                          // Height accommodates the recommended-station
                          // card content (icon + name + address +
                          // reason + 2 chip rows + score badge) without
                          // overflowing. Was 190 which still clipped
                          // cards on small screens (chip wrap + 2-line
                          // reason pushed content past 190 → bottom
                          // overflow ~20px).
                          height: 220,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: stations.length,
                            itemBuilder: (context, index) {
                              final station = stations[index];
                              return _buildRecommendedStationCard(
                                  context, station);
                            },
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
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
                      routingState.errorMessage ??
                          routingState.errorCode ??
                          'Unable to calculate route',
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
                    if (routingState.destination != null) {
                      setState(() => _mapFitBoundsVersion++);
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

  Widget _buildRecommendedStationCard(
      BuildContext context, RecommendedStation station) {
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
              mainAxisSize: MainAxisSize.min,
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
                          station.isOptimalStop
                              ? FontAwesomeIcons.star
                              : FontAwesomeIcons.bolt,
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
                if (station.recommendationReason != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    station.recommendationReason!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: color,
                      fontSize: 10,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8),
                // Wrap so chips fall onto a second line on narrow cards
                // instead of overflowing horizontally.
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    _buildStationChip(Icons.electric_bolt,
                        '${station.totalPowerKw.toStringAsFixed(0)} kW', theme),
                    _buildStationChip(Icons.ev_station,
                        '${station.availablePorts}/${station.totalPorts}', theme),
                    _buildStationChip(Icons.route,
                        '${(station.detourMeters / 1000).toStringAsFixed(1)} km',
                        theme),
                    if (station.estimatedBatteryAtArrival != null)
                      _buildStationChip(
                        Icons.battery_std,
                        'Pin ~${station.estimatedBatteryAtArrival!.toStringAsFixed(0)}%',
                        theme,
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
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
          Icon(icon,
              size: 10, color: theme.colorScheme.onSurface.withOpacity(0.6)),
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

  Widget _buildPrimaryRecommendationCard(
      BuildContext context, RecommendedStation station) {
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
              FaIcon(FontAwesomeIcons.carBattery,
                  color: Colors.green.shade700, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            station.name,
            style:
                theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
              _buildStationChip(Icons.electric_bolt,
                  '${station.totalPowerKw.toStringAsFixed(0)} kW', theme),
              _buildStationChip(Icons.route,
                  '${(station.detourMeters / 1000).toStringAsFixed(1)} km detour',
                  theme),
              _buildStationChip(Icons.ev_station,
                  '${station.availablePorts}/${station.totalPorts} ports', theme),
              if (station.estimatedBatteryAtArrival != null)
                _buildStationChip(Icons.battery_std,
                    'Battery ~${station.estimatedBatteryAtArrival!.toStringAsFixed(0)}%',
                    theme),
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

  // ── Bottom sheet for charging / battery swap lists ──────────────────

  Widget buildBottomSheet(BuildContext context) {
    final theme = Theme.of(context);
    final routingState = ref.watch(routingProvider);
    final state = ref.watch(stationSearchProvider);

    // Route mode: when route is shown, use the dedicated route sheet
    if (routingState.showRoute && routingState.route != null) {
      return _buildRouteBottomSheet(context, routingState);
    }

    // Otherwise: nearby mode with charging/battery swap list
    final title = _serviceMode == HomeServiceMode.charging
        ? (_isSearchMode
            ? 'Search results'
            : 'Nearby charging stations (${state.totalElements})')
        : 'Nearby battery swap stations (${_batterySwapStations.length})';

    return DraggableScrollableSheet(
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

              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
              ),

              // Active filter chips
              if (_serviceMode == HomeServiceMode.charging &&
                  _filter.hasActiveFilters)
                _buildActiveFilterChips(theme),

              // Helper line if no filters
              if (_serviceMode == HomeServiceMode.charging &&
                  !_filter.hasActiveFilters &&
                  !_isSearchMode)
                _buildHelperLine(theme,
                    'Showing stations near you'),

              if (_serviceMode == HomeServiceMode.batterySwap)
                _buildHelperLine(theme,
                    _batterySwapStations.isEmpty
                        ? 'No swap stations found nearby'
                        : 'Swap stations near you'),

              // Service mode selector + filter
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<HomeServiceMode>(
                        segments: const [
                          ButtonSegment(
                            value: HomeServiceMode.charging,
                            icon: FaIcon(FontAwesomeIcons.bolt, size: 14),
                            label: Text('Charging'),
                          ),
                          ButtonSegment(
                            value: HomeServiceMode.batterySwap,
                            icon:
                                FaIcon(FontAwesomeIcons.batteryFull, size: 14),
                            label: Text('Battery swap'),
                          ),
                        ],
                        selected: {_serviceMode},
                        onSelectionChanged: (selection) {
                          _onServiceModeChanged(selection.first);
                        },
                        showSelectedIcon: false,
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // List
              Expanded(
                child: _serviceMode == HomeServiceMode.charging
                    ? _buildChargingStationList(
                        context, state, scrollController)
                    : _buildBatterySwapStationList(
                        context, scrollController),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRouteBottomSheet(
      BuildContext context, RoutingState routingState) {
    return DraggableScrollableSheet(
      initialChildSize: 0.3,
      minChildSize: 0.15,
      maxChildSize: 0.85,
      snap: true,
      snapSizes: const [0.15, 0.4, 0.85],
      builder: (context, scrollController) {
        // Fill the sheet's allotted height exactly so the panel stays
        // bottom-anchored and snap-to-max-height works. The inner
        // recommendation sheet is responsible for scrolling its own content
        // when the sheet is at max size.
        return SizedBox.expand(
          child: _buildRouteRecommendationSheet(
            context,
            routingState,
            scrollController,
          ),
        );
      },
    );
  }

  Widget _buildActiveFilterChips(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          ..._filter.activeFilterChips.map(
            (label) => Chip(
              label: Text(
                label,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              visualDensity: VisualDensity.compact,
            ),
          ),
          ActionChip(
            label: const Text('Clear all',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            onPressed: () {
              setState(() => _filter = const HomeMapFilterState());
              _onFilterChanged();
            },
            padding: const EdgeInsets.symmetric(horizontal: 4),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildHelperLine(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          FaIcon(
            FontAwesomeIcons.circleInfo,
            size: 12,
            color: theme.colorScheme.onSurface.withOpacity(0.5),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChargingStationList(
    BuildContext context,
    StationSearchState state,
    ScrollController scrollController,
  ) {
    if (state.isLoading && state.stations.isEmpty) {
      return const SkeletonList(count: 4, padding: EdgeInsets.all(16));
    }
    if (state.error != null && state.stations.isEmpty) {
      return ErrorState(
        message: formatApiError(state.error),
        code: state.error!.code,
        traceId: state.error!.traceId,
        onRetry: _requestLocationAndSearch,
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
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildCompactStationCard(context, station),
        );
      },
    );
  }

  Widget _buildCompactStationCard(
      BuildContext context, Map<String, dynamic> station) {
    final stationId = station['stationId'] as String? ?? '';
    final name = station['name'] as String? ?? 'Unnamed station';
    final address = station['address'] as String? ?? '';
    final trustScore = station['trustScore'] as int? ?? 0;
    final chargingSummary = station['chargingSummary'] as Map<String, dynamic>?;
    final totalPorts = chargingSummary?['totalPorts'] as int? ?? 0;
    final availablePorts = chargingSummary?['availablePorts'] as int? ??
        chargingSummary?['acPorts'] as int? ??
        0;
    final maxPowerKw = chargingSummary?['maxPowerKw'] as double? ?? 0.0;
    final dcPorts = chargingSummary?['dcPorts'] as int? ?? 0;
    final acPorts = chargingSummary?['acPorts'] as int? ?? 0;
    final supportsBatterySwap = station['supportsBatterySwap'] as bool? ?? false;
    final batterySwap = station['batterySwap'] as Map<String, dynamic>?;
    final totalPiles = batterySwap?['totalPiles'] as int? ?? 0;
    final totalSlots = batterySwap?['totalSlots'] as int? ?? 0;
    final availableBatteries =
        batterySwap?['availableBatteries'] as int? ?? 0;
    final distanceKm = (station['distanceKm'] as num?)?.toDouble();

    final card = CompactStationCard(
      stationId: stationId,
      name: name,
      address: address,
      trustScore: trustScore,
      totalPorts: totalPorts,
      availablePorts: availablePorts,
      maxPowerKw: maxPowerKw,
      dcPorts: dcPorts,
      acPorts: acPorts,
      supportsBatterySwap: supportsBatterySwap,
      totalPiles: totalPiles,
      totalSlots: totalSlots,
      availableBatteries: availableBatteries,
      distanceKm: distanceKm,
      isSelected: _selectedStationId == stationId,
      onTap: () {
        setState(() => _selectedStationId = stationId);
        final lat = station['lat'] as double?;
        final lng = station['lng'] as double?;
        if (lat != null && lng != null) {
          _mapController.move(LatLng(lat, lng), 15.0);
        }
      },
    );

    if (_selectedStationId == stationId) {
      // Show selected preview below the card.
      final isSwapOnly = supportsBatterySwap && totalPorts == 0;
      return Column(
        children: [
          card,
          const SizedBox(height: 8),
          SelectedStationPreview(
            name: name,
            address: address,
            distanceKm: distanceKm,
            trustScore: trustScore,
            totalPorts: totalPorts,
            availablePorts: availablePorts,
            maxPowerKw: maxPowerKw,
            supportsBatterySwap: supportsBatterySwap,
            totalPiles: totalPiles,
            totalSlots: totalSlots,
            availableBatteries: availableBatteries,
            isBatterySwapOnly: isSwapOnly,
            onRoute: () {
              // Quick-action: open routing towards this station's coords
              final lat = station['lat'] as double?;
              final lng = station['lng'] as double?;
              if (lat != null && lng != null) {
                _onLongPressWithBatterySetup(LatLng(lat, lng));
              } else {
                context.push('/stations/$stationId');
              }
            },
            onBookOrReserve: () {
              if (isSwapOnly) {
                context.push('/battery-swap?stationId=$stationId');
              } else {
                context.push('/stations/$stationId');
              }
            },
            onClearSelection: () {
              setState(() => _selectedStationId = null);
            },
          ),
        ],
      );
    }

    return card;
  }

  Widget _buildBatterySwapStationList(
    BuildContext context,
    ScrollController scrollController,
  ) {
    if (_currentLocation == null && _batterySwapStations.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_batterySwapStations.isEmpty) {
      return EmptyState(
        icon: FontAwesomeIcons.batteryFull,
        title: 'No battery swap stations nearby',
        message:
            'Try expanding the search radius or move to a different location.',
        action: OutlinedButton.icon(
          onPressed: _loadBatterySwapStationsForCurrentLocation,
          icon: const FaIcon(FontAwesomeIcons.rotate, size: 14),
          label: const Text('Reload'),
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _batterySwapStations.length,
      itemBuilder: (context, index) {
        final station = _batterySwapStations[index];
        final isSelected = _selectedStationId == station.stationId;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            children: [
              CompactSwapStationCard(
                station: station,
                isSelected: isSelected,
                onTap: () {
                  setState(() => _selectedStationId = station.stationId);
                  final lat = station.lat;
                  final lng = station.lng;
                  if (lat != null && lng != null) {
                    _mapController.move(LatLng(lat, lng), 15.0);
                  }
                },
              ),
              if (isSelected) ...[
                const SizedBox(height: 8),
                SelectedStationPreview(
                  name: station.name ?? 'Unnamed station',
                  address: station.address,
                  distanceKm: station.distanceKm,
                  trustScore: 0,
                  supportsBatterySwap: true,
                  totalPiles: station.totalPiles,
                  totalSlots: station.totalSlots,
                  availableBatteries: station.availableBatteries,
                  isBatterySwapOnly: true,
                  onRoute: () {
                    final lat = station.lat;
                    final lng = station.lng;
                    if (lat != null && lng != null) {
                      _onLongPressWithBatterySetup(LatLng(lat, lng));
                    } else {
                      context.push(
                          '/battery-swap?stationId=${station.stationId}');
                    }
                  },
                  onBookOrReserve: () =>
                      context.push('/battery-swap?stationId=${station.stationId}'),
                  onClearSelection: () =>
                      setState(() => _selectedStationId = null),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ── Recommended-station sheet (route mode) ──────────────────────────

  void _showRecommendedStationSheet(
      BuildContext context, RecommendedStation station) {
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

  // ── Battery setup sheets ────────────────────────────────────────────

  Future<void> _showBatterySetupDialog(
      BuildContext context, RoutingState routingState) async {
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
      if (routingState.destination != null) {
        setState(() => _mapFitBoundsVersion++);
        ref
            .read(routingProvider.notifier)
            .selectDestinationByCoordinates(routingState.destination!);
      }
    }
  }

  Future<void> _showBatterySetupIfNeeded(
      BuildContext context, RoutingState routingState) async {
    if (routingState.batteryPercent == null &&
        routingState.vehicleRangeKm == null) {
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
        if (routingState.destination != null) {
          setState(() => _mapFitBoundsVersion++);
          ref
              .read(routingProvider.notifier)
              .selectDestinationByCoordinates(routingState.destination!);
        }
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────
//  Marker widgets
// ─────────────────────────────────────────────────────────────────────────

/// Battery swap map marker.
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

/// Destination marker — red teardrop with center dot.
class _DestinationMarker extends StatelessWidget {
  const _DestinationMarker();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
        ),
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

// ─────────────────────────────────────────────────────────────────────────
//  Filter sheets
// ─────────────────────────────────────────────────────────────────────────

/// Battery Swap Filter Sheet — separate radius for battery swap stations.
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
                FontAwesomeIcons.batteryFull,
                color: const Color(0xFF00695C),
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
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _radiusKm,
                  min: 1,
                  max: 50,
                  divisions: 49,
                  label: '${_radiusKm.toStringAsFixed(0)} km',
                  onChanged: (v) => setState(() => _radiusKm = v),
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
              height: 200,
              child: ListView.builder(
                itemCount: widget.stations.length,
                itemBuilder: (ctx, idx) {
                  final s = widget.stations[idx];
                  return ListTile(
                    dense: true,
                    leading: FaIcon(
                      FontAwesomeIcons.batteryFull,
                      color: s.availableBatteries > 0
                          ? Colors.green
                          : Colors.orange,
                      size: 16,
                    ),
                    title: Text(
                      s.name ?? 'Unnamed station',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${s.availableBatteries} ready · ${s.distanceKm?.toStringAsFixed(1) ?? '?'} km away',
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                  onPressed: () =>
                      Navigator.pop(context, {'radiusKm': _radiusKm}),
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

/// Recommended station sheet — full details when a route station is tapped.
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
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
                          Flexible(
                            child: Text(
                              station.rating!.toStringAsFixed(1),
                              style: theme.textTheme.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
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
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
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
                  FaIcon(FontAwesomeIcons.circleInfo,
                      color: Colors.green.shade700, size: 16),
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
          // Use Wrap so 3-4 stat items flow onto multiple lines on
          // narrow screens instead of overflowing horizontally.
          Wrap(
            alignment: WrapAlignment.spaceAround,
            crossAxisAlignment: WrapCrossAlignment.start,
            spacing: 16,
            runSpacing: 12,
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
          if (station.estimatedChargeMinutes > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  FaIcon(Icons.access_time,
                      color: theme.colorScheme.primary, size: 16),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Estimated charging: ',
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      '~${station.estimatedChargeMinutes} min',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (station.optimalChargingStopMinutes != null) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Total stop: ~${station.optimalChargingStopMinutes!.toStringAsFixed(0)} min',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
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
      mainAxisSize: MainAxisSize.min,
      children: [
        FaIcon(icon, color: Colors.orange, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Battery setup sheet for EV users to input battery info.
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
              FaIcon(FontAwesomeIcons.carBattery,
                  color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 10),
              Text(
                'Vehicle Battery Info',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 20),
          Text('Current Battery: ${_battery.toInt()}%',
              style: theme.textTheme.titleMedium),
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
          Text('Max Range (at 100%): ${_range.toInt()} km',
              style: theme.textTheme.titleMedium),
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
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: remaining < 50 ? Colors.orange.shade50 : Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: remaining < 50
                    ? Colors.orange.shade200
                    : Colors.green.shade200,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FaIcon(
                  remaining < 50
                      ? FontAwesomeIcons.batteryHalf
                      : FontAwesomeIcons.batteryFull,
                  color: remaining < 50
                      ? Colors.orange.shade700
                      : Colors.green.shade700,
                ),
                const SizedBox(width: 8),
                Text(
                  'Remaining Range: ${remaining.toStringAsFixed(0)} km',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: remaining < 50
                        ? Colors.orange.shade700
                        : Colors.green.shade700,
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
