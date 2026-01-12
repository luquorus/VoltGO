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
import '../widgets/station_marker.dart';
import '../widgets/main_scaffold.dart';

/// Home Map Screen with OpenStreetMap + Leaflet and bottom sheet station list
class HomeMapScreen extends ConsumerStatefulWidget {
  const HomeMapScreen({super.key});

  @override
  ConsumerState<HomeMapScreen> createState() => _HomeMapScreenState();
}

class _HomeMapScreenState extends ConsumerState<HomeMapScreen> {
  final MapController _mapController = MapController();
  ScrollController? _bottomSheetScrollController;
  String? _selectedStationId;
  double _radiusKm = 5.0;
  double? _minPowerKw;
  bool? _hasAC;
  LatLng? _currentLocation;
  double _currentZoom = 13.0;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearchMode = false;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _requestLocationAndSearch();
  }

  @override
  void dispose() {
    _bottomSheetScrollController?.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
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
      // Request location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            AppToast.showError(context, 'Location permission denied');
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          AppToast.showError(context, 'Location permission permanently denied');
        }
        return;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition();
      final location = LatLng(position.latitude, position.longitude);
      
      setState(() {
        _currentLocation = location;
      });
      
      // Search stations
      final notifier = ref.read(stationSearchProvider.notifier);
      await notifier.search(StationSearchParams(
        lat: position.latitude,
        lng: position.longitude,
        radiusKm: _radiusKm,
        minPowerKw: _minPowerKw,
        hasAC: _hasAC,
      ));

      // Move map to user location
      _mapController.move(location, 13.0);
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, 'Failed to get location: $e');
      }
    }
  }

  Widget _buildMapWidget(List<Marker> markers) {
    final initialLocation = _currentLocation ?? const LatLng(21.0285, 105.8542); // Default: Hanoi
    
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: initialLocation,
        initialZoom: 13.0,
        onTap: (tapPosition, point) {
          // Handle map tap if needed
        },
        onMapEvent: (event) {
          if (event is MapEventMoveEnd) {
            setState(() {
              _currentZoom = _mapController.camera.zoom;
            });
          }
        },
      ),
      children: [
        // OpenStreetMap tile layer
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.ev_user_mobile',
          maxZoom: 19,
        ),
        // Markers layer
        MarkerLayer(
          markers: markers,
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
      ],
    );
  }

  void _onMarkerTap(String stationId) {
    // Navigate to station detail screen
    context.push('/stations/$stationId');
  }

  Future<void> _onFilterChanged() async {
    final state = ref.read(stationSearchProvider);
    final position = await Geolocator.getCurrentPosition();
    
    final notifier = ref.read(stationSearchProvider.notifier);
    await notifier.updateFilters(StationSearchParams(
      lat: position.latitude,
      lng: position.longitude,
      radiusKm: _radiusKm,
      minPowerKw: _minPowerKw,
      hasAC: _hasAC,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(stationSearchProvider);
    final theme = Theme.of(context);

    // Build markers from stations
    final markers = <Marker>[];
    for (final station in state.stations) {
      final stationId = station['stationId'] as String? ?? '';
      final lat = station['lat'] as double?;
      final lng = station['lng'] as double?;
      final name = station['name'] as String? ?? 'Unknown';

      if (lat != null && lng != null) {
        markers.add(
          Marker(
            point: LatLng(lat, lng),
            width: 28,
            height: 28,
            child: GestureDetector(
              onTap: () => _onMarkerTap(stationId),
              child: const StationMarker(),
            ),
          ),
        );
      }
    }

    return MainScaffold(
      showBottomNav: true,
      child: Stack(
        children: [
          // Google Map with error handling
          _buildMapWidget(markers),

          // Search bar (Google Maps style)
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: _buildSearchBar(context, theme),
          ),

          // Bottom sheet with station list
          DraggableScrollableSheet(
            initialChildSize: 0.4,
            minChildSize: 0.2,
            maxChildSize: 0.9,
            builder: (context, scrollController) {
              _bottomSheetScrollController = scrollController;
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
                            'Stations (${state.totalElements})',
                            style: theme.textTheme.titleLarge,
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const FaIcon(FontAwesomeIcons.bolt),
                            tooltip: 'Tối ưu theo thời gian',
                            onPressed: () => context.push('/recommendations'),
                          ),
                          IconButton(
                            icon: const FaIcon(FontAwesomeIcons.filter),
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
        ],
      ),
    );
  }

  Widget _buildStationList(
    BuildContext context,
    StationSearchState state,
    ScrollController scrollController,
  ) {
    if (state.isLoading) {
      return const Center(child: LoadingState());
    }

    if (state.error != null) {
      return Center(
        child: ErrorState(
          message: state.error!.message,
          onRetry: () => _requestLocationAndSearch(),
        ),
      );
    }

    if (state.stations.isEmpty) {
      return const Center(child: EmptyState(message: 'No stations found'));
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: state.stations.length + (state.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == state.stations.length) {
          // Load more
          if (!state.isLoadingMore) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(stationSearchProvider.notifier).loadMore();
            });
          }
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
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
    final name = station['name'] as String? ?? 'Unknown Station';
    final address = station['address'] as String? ?? '';
    final trustScore = station['trustScore'] as int? ?? 0;
    final chargingSummary = station['chargingSummary'] as Map<String, dynamic>?;
    final totalPorts = chargingSummary?['totalPorts'] as int? ?? 0;
    final maxPowerKw = chargingSummary?['maxPowerKw'] as double? ?? 0.0;
    final dcPorts = chargingSummary?['dcPorts'] as int? ?? 0;
    final acPorts = chargingSummary?['acPorts'] as int? ?? 0;

    return StationCard(
      title: name,
      subtitle: address,
      badges: [
        ScoreBadge(score: trustScore),
        StatusPill(
          label: '${totalPorts} ports',
          color: theme.colorScheme.primary,
        ),
        if (maxPowerKw > 0)
          StatusPill(
            label: '${maxPowerKw.toStringAsFixed(0)}kW max',
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

        // Navigate to station detail
        context.push('/stations/$stationId');
      },
    );
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
          // Radius
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

          // Min Power
          TextField(
            decoration: const InputDecoration(
              labelText: 'Min Power (kW) - Optional',
              helperText: 'DC ports only',
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

          // Has AC
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
          child: const Text('Clear Optional'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
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


