import 'dart:async';
import 'dart:convert' show JsonEncoder;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../models/route_models.dart';
import '../repositories/station_repository.dart';
import '../services/geocoding_service.dart';
import 'station_providers.dart';
import 'package:shared_auth/shared_auth.dart';

export 'package:shared_auth/shared_auth.dart' show VehicleSettings, VehicleSettingsStorage;

/// Diagnostic event types for routing flow.
class RoutingDiagnosticEvent {
  final String type;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  RoutingDiagnosticEvent({
    required this.type,
    required this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() =>
      '[${timestamp.toIso8601String()}] $type ${const JsonEncoder.withIndent('  ').convert(data)}';
}

class RoutingDiagnostics {
  final List<RoutingDiagnosticEvent> events = [];
  static const int maxEvents = 50;

  void log(String type, Map<String, dynamic> data) {
    events.add(RoutingDiagnosticEvent(type: type, data: data));
    if (events.length > maxEvents) {
      events.removeAt(0);
    }
    debugPrint('[RoutingDiag] $type: $data');
  }

  void logRouteResponse(RouteResponse response, int sequence) {
    log('ROUTE_BACKEND_RESPONSE', {
      'sequence': sequence,
      'distanceMeters': response.distanceMeters,
      'durationSeconds': response.durationSeconds,
      'polylinePoints': response.polyline.length,
      'recommendedStations': response.recommendedStations.length,
      'optimalStationId': response.optimalStation?.stationId,
      'optimalStationName': response.optimalStation?.name,
      'needsChargingStop': response.needsChargingStop,
      'remainingRangeKm': response.remainingRangeKm,
      'routeDistanceKm': response.routeDistanceKm,
      'summary': {
        'distanceKm': response.summary.distanceKm,
        'durationMinutes': response.summary.durationMinutes,
        'hasChargingStations': response.summary.hasChargingStations,
        'needsChargingRecommendation': response.summary.needsChargingRecommendation,
      },
      // Station details for each recommended station
      'stations': response.recommendedStations.map((s) => {
        'stationId': s.stationId,
        'name': s.name,
        'distanceFromRouteMeters': s.distanceFromRouteMeters,
        'totalPowerKw': s.totalPowerKw,
        'availablePorts': s.availablePorts,
        'totalPorts': s.totalPorts,
        'score': s.score,
        'isOptimalStop': s.isOptimalStop,
        'isRecommended': s.isRecommended,
        'batteryAtArrival': s.estimatedBatteryAtArrival,
        'recommendationReason': s.recommendationReason,
      }).toList(),
    });
  }

  void logRenderSuccess(int polylinePoints, int stationMarkers, int sequence) {
    log('ROUTE_RENDER_SUCCESS', {
      'polylinePoints': polylinePoints,
      'stationMarkers': stationMarkers,
      'sequence': sequence,
    });
  }

  void logRenderFailed(String reason, dynamic error, int sequence) {
    log('ROUTE_RENDER_FAILED', {
      'reason': reason,
      'error': error.toString(),
      'sequence': sequence,
    });
  }
}

class DestinationMarker {
  final String name;
  final String address;
  final LatLng position;

  const DestinationMarker({
    required this.name,
    required this.address,
    required this.position,
  });
}

enum RouteStatus {
  idle,
  loading,
  success,
  error,
}

class RoutingState {
  final RouteStatus status;
  final RouteResponse? route;
  final String? errorCode;
  final String? errorMessage;
  final LatLng? origin;
  final LatLng? destination;
  final String? destinationName;
  final DestinationMarker? destinationMarker;
  final List<PlaceSuggestion> suggestions;
  final bool showSuggestions;
  final bool showRoute;
  final bool isSearchingPlaces;
  final int? batteryPercent;
  final double? vehicleRangeKm;
  final double? remainingRangeKm;
  final bool needsChargingStop;
  final RecommendedStation? optimalStation;
  final RoutingDiagnostics diagnostics;
  final int lastRouteSequence;
  final double consumptionKwhPerKm;

  const RoutingState({
    this.status = RouteStatus.idle,
    this.route,
    this.errorCode,
    this.errorMessage,
    this.origin,
    this.destination,
    this.destinationName,
    this.destinationMarker,
    this.suggestions = const [],
    this.showSuggestions = false,
    this.showRoute = false,
    this.isSearchingPlaces = false,
    this.batteryPercent,
    this.vehicleRangeKm,
    this.remainingRangeKm,
    this.needsChargingStop = false,
    this.optimalStation,
    RoutingDiagnostics? diagnostics,
    this.lastRouteSequence = 0,
    this.consumptionKwhPerKm = 0.18,
  }) : diagnostics = diagnostics ?? const _DefaultDiagnostics();

  RoutingState copyWith({
    RouteStatus? status,
    RouteResponse? route,
    String? errorCode,
    String? errorMessage,
    LatLng? origin,
    LatLng? destination,
    String? destinationName,
    DestinationMarker? destinationMarker,
    List<PlaceSuggestion>? suggestions,
    bool? showSuggestions,
    bool? showRoute,
    bool? isSearchingPlaces,
    bool clearError = false,
    bool clearRoute = false,
    bool clearDestination = false,
    bool clearSuggestions = false,
    int? batteryPercent,
    double? vehicleRangeKm,
    double? remainingRangeKm,
    bool? needsChargingStop,
    RecommendedStation? optimalStation,
    bool clearOptimalStation = false,
    int? lastRouteSequence,
    double? consumptionKwhPerKm,
  }) {
    return RoutingState(
      status: status ?? this.status,
      route: clearRoute ? null : (route ?? this.route),
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      origin: origin ?? this.origin,
      destination: clearDestination ? null : (destination ?? this.destination),
      destinationName:
          clearDestination ? null : (destinationName ?? this.destinationName),
      destinationMarker:
          clearDestination ? null : (destinationMarker ?? this.destinationMarker),
      suggestions: clearSuggestions ? const [] : (suggestions ?? this.suggestions),
      showSuggestions: showSuggestions ?? this.showSuggestions,
      showRoute: clearRoute ? false : (showRoute ?? this.showRoute),
      isSearchingPlaces: isSearchingPlaces ?? this.isSearchingPlaces,
      batteryPercent: batteryPercent ?? this.batteryPercent,
      vehicleRangeKm: vehicleRangeKm ?? this.vehicleRangeKm,
      remainingRangeKm: remainingRangeKm ?? this.remainingRangeKm,
      needsChargingStop: needsChargingStop ?? this.needsChargingStop,
      optimalStation:
          clearOptimalStation ? null : (optimalStation ?? this.optimalStation),
      diagnostics: diagnostics,
      lastRouteSequence: lastRouteSequence ?? this.lastRouteSequence,
      consumptionKwhPerKm: consumptionKwhPerKm ?? this.consumptionKwhPerKm,
    );
  }
}

class _DefaultDiagnostics implements RoutingDiagnostics {
  const _DefaultDiagnostics();

  @override
  List<RoutingDiagnosticEvent> get events => const [];

  @override
  void log(String type, Map<String, dynamic> data) {}

  @override
  void logRouteResponse(RouteResponse response, int sequence) {}

  @override
  void logRenderSuccess(int polylinePoints, int stationMarkers, int sequence) {}

  @override
  void logRenderFailed(String reason, dynamic error, int sequence) {}
}

class RoutingNotifier extends StateNotifier<RoutingState> {
  final StationRepository _repository;
  final GeocodingService _geocodingService;
  final RoutingDiagnostics _diagnostics;
  final VehicleSettingsStorage _settingsStorage;
  Timer? _debounceTimer;
  Timer? _retryTimer;
  int _routeSequence = 0;
  bool _settingsLoaded = false;

  RoutingNotifier(this._repository, this._geocodingService)
      : _diagnostics = RoutingDiagnostics(),
        _settingsStorage = VehicleSettingsStorage(),
        super(RoutingState(diagnostics: RoutingDiagnostics())) {
    _loadVehicleSettings();
  }

  Future<void> _loadVehicleSettings() async {
    if (_settingsLoaded) return;
    _settingsLoaded = true;
    final settings = await _settingsStorage.load();
    if (mounted) {
      state = state.copyWith(
        batteryPercent: settings.batteryPercent,
        vehicleRangeKm: settings.vehicleRangeKm,
        consumptionKwhPerKm: settings.consumptionKwhPerKm,
      );
      _diagnostics.log('VEHICLE_SETTINGS_LOADED', {
        'batteryPercent': settings.batteryPercent,
        'vehicleRangeKm': settings.vehicleRangeKm,
        'consumptionKwhPerKm': settings.consumptionKwhPerKm,
      });
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Origin management
  // -------------------------------------------------------------------------

  void setOrigin(LatLng location) {
    state = state.copyWith(origin: location);
  }

  // -------------------------------------------------------------------------
  // Place search with debounce
  // -------------------------------------------------------------------------

  void searchDestination(String query) {
    _debounceTimer?.cancel();

    if (query.trim().isEmpty) {
      state = state.copyWith(
        showSuggestions: false,
        clearSuggestions: true,
        isSearchingPlaces: false,
      );
      return;
    }

    state = state.copyWith(showSuggestions: true, isSearchingPlaces: true);

    _debounceTimer = Timer(const Duration(milliseconds: 400), () async {
      final results = await _geocodingService.searchPlaces(query);
      if (mounted) {
        state = state.copyWith(
          suggestions: results,
          showSuggestions: true,
          isSearchingPlaces: false,
        );
      }
    });
  }

  void hideSuggestions() {
    state = state.copyWith(showSuggestions: false);
  }

  void showSuggestionsList() {
    if (state.suggestions.isNotEmpty) {
      state = state.copyWith(showSuggestions: true);
    }
  }

  // -------------------------------------------------------------------------
  // Destination selection
  // -------------------------------------------------------------------------

  Future<void> selectDestination(PlaceSuggestion suggestion) async {
    _debounceTimer?.cancel();
    _retryTimer?.cancel();

    final destLatLng = LatLng(suggestion.lat, suggestion.lng);
    final marker = DestinationMarker(
      name: suggestion.shortName,
      address: suggestion.displayName,
      position: destLatLng,
    );

    _routeSequence++;

    state = state.copyWith(
      status: RouteStatus.idle,
      destination: destLatLng,
      destinationName: suggestion.shortName,
      destinationMarker: marker,
      showSuggestions: false,
      clearSuggestions: true,
      clearRoute: true,
      clearError: true,
      clearOptimalStation: true,
    );

    _diagnostics.log('DESTINATION_SELECTED', {
      'name': suggestion.shortName,
      'lat': suggestion.lat,
      'lng': suggestion.lng,
      'sequence': _routeSequence,
    });

    await _calculateRoute(suggestion);
  }

  Future<void> selectDestinationByLongPress(LatLng point) async {
    _debounceTimer?.cancel();
    _retryTimer?.cancel();
    _routeSequence++;

    state = state.copyWith(
      status: RouteStatus.loading,
      clearError: true,
    );

    _diagnostics.log('DESTINATION_LONG_PRESS', {
      'lat': point.latitude,
      'lng': point.longitude,
      'sequence': _routeSequence,
    });

    try {
      final suggestion = await _geocodingService.reverseGeocode(
        point.latitude,
        point.longitude,
      );

      if (!mounted) return;

      if (suggestion != null) {
        final destLatLng = LatLng(suggestion.lat, suggestion.lng);
        final marker = DestinationMarker(
          name: suggestion.shortName,
          address: suggestion.displayName,
          position: destLatLng,
        );

        state = state.copyWith(
          destination: destLatLng,
          destinationName: suggestion.shortName,
          destinationMarker: marker,
          showSuggestions: false,
          clearSuggestions: true,
          clearRoute: true,
          clearError: true,
        );

        await _calculateRoute(suggestion);
      } else {
        final destLatLng = LatLng(point.latitude, point.longitude);
        final displayName =
            '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
        final marker = DestinationMarker(
          name: displayName,
          address: displayName,
          position: destLatLng,
        );

        state = state.copyWith(
          destination: destLatLng,
          destinationName: displayName,
          destinationMarker: marker,
          showSuggestions: false,
          clearSuggestions: true,
          clearRoute: true,
          clearError: true,
        );

        await _calculateRouteFromCoordinates(destLatLng);
      }
    } catch (e) {
      if (!mounted) return;

      final destLatLng = LatLng(point.latitude, point.longitude);
      final displayName =
          '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
      final marker = DestinationMarker(
        name: displayName,
        address: displayName,
        position: destLatLng,
      );

      state = state.copyWith(
        destination: destLatLng,
        destinationName: displayName,
        destinationMarker: marker,
        showSuggestions: false,
        clearSuggestions: true,
        clearRoute: true,
        clearError: true,
      );

      await _calculateRouteFromCoordinates(destLatLng);
    }
  }

  Future<void> selectDestinationByCoordinates(LatLng dest) async {
    _debounceTimer?.cancel();
    _retryTimer?.cancel();
    _routeSequence++;

    final destLatLng = dest;
    final displayName =
        '${dest.latitude.toStringAsFixed(5)}, ${dest.longitude.toStringAsFixed(5)}';
    final marker = DestinationMarker(
      name: displayName,
      address: displayName,
      position: destLatLng,
    );

    state = state.copyWith(
      status: RouteStatus.idle,
      destination: destLatLng,
      destinationName: displayName,
      destinationMarker: marker,
      showSuggestions: false,
      clearSuggestions: true,
      clearRoute: true,
      clearError: true,
      clearOptimalStation: true,
    );

    _diagnostics.log('DESTINATION_BY_COORDINATES', {
      'lat': dest.latitude,
      'lng': dest.longitude,
      'sequence': _routeSequence,
    });

    await _calculateRouteFromCoordinates(destLatLng);
  }

  // -------------------------------------------------------------------------
  // Route calculation with sequence-based race condition prevention
  // and 1-retry on OSRM failure
  // -------------------------------------------------------------------------

  Future<void> _calculateRoute(PlaceSuggestion destination) async {
    final origin = state.origin;
    if (origin == null) {
      state = state.copyWith(
        status: RouteStatus.error,
        errorCode: 'LOCATION_NOT_AVAILABLE',
        errorMessage: 'Current location not available. Please enable GPS and try again.',
      );
      _diagnostics.log('ROUTE_REQUEST_FAILED', {
        'reason': 'LOCATION_NOT_AVAILABLE',
        'sequence': _routeSequence,
      });
      return;
    }

    final currentSequence = _routeSequence;

    state = state.copyWith(
      status: RouteStatus.loading,
      clearError: true,
    );

    _diagnostics.log('ROUTE_REQUEST_STARTED', {
      'originLat': origin.latitude,
      'originLng': origin.longitude,
      'destLat': destination.lat,
      'destLng': destination.lng,
      'batteryPercent': state.batteryPercent,
      'vehicleRangeKm': state.vehicleRangeKm,
      'sequence': currentSequence,
    });

    RouteResponse? response;
    String? errorCode;
    String? errorMessage;

    // Attempt 1
    try {
      response = await _attemptRoute(origin, destination);
    } catch (e) {
      errorCode = 'ROUTE_ERROR';
      errorMessage = e.toString();
    }

    // Attempt 2 (retry once if OSRM/network error, NOT for validation errors)
    if (response == null &&
        errorCode != null &&
        !_isNonRetryableError(errorCode)) {
      _diagnostics.log('ROUTE_REQUEST_RETRY', {
        'attempt': 2,
        'errorCode': errorCode,
        'sequence': currentSequence,
      });

      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted || _routeSequence != currentSequence) {
        _diagnostics.log('ROUTE_REQUEST_CANCELLED', {
          'reason': 'stale_or_unmounted',
          'sequence': currentSequence,
          'currentSequence': _routeSequence,
        });
        return;
      }

      try {
        response = await _attemptRoute(origin, destination);
        errorCode = null;
        errorMessage = null;
      } catch (e) {
        errorCode = 'ROUTE_ERROR';
        errorMessage = e.toString();
      }
    }

    if (!mounted || _routeSequence != currentSequence) {
      _diagnostics.log('ROUTE_REQUEST_IGNORED', {
        'reason': 'stale_sequence',
        'sequence': currentSequence,
        'currentSequence': _routeSequence,
      });
      return;
    }

    if (response != null) {
      state = state.copyWith(
        status: RouteStatus.success,
        route: response,
        showRoute: true,
        needsChargingStop: response.needsChargingStop,
        remainingRangeKm: response.remainingRangeKm,
        optimalStation: response.optimalStation,
        lastRouteSequence: currentSequence,
      );
      _diagnostics.log('ROUTE_REQUEST_SUCCESS', {
        'distanceMeters': response.distanceMeters,
        'durationSeconds': response.durationSeconds,
        'polylinePoints': response.polyline.length,
        'stations': response.recommendedStations.length,
        'needsChargingStop': response.needsChargingStop,
        'optimalStation': response.optimalStation?.stationId,
        'sequence': currentSequence,
      });
    } else {
      state = state.copyWith(
        status: RouteStatus.error,
        errorCode: errorCode,
        errorMessage: errorMessage,
      );
      _diagnostics.log('ROUTE_REQUEST_FAILED', {
        'errorCode': errorCode,
        'errorMessage': errorMessage,
        'sequence': currentSequence,
      });
    }
  }

  Future<void> _calculateRouteFromCoordinates(LatLng destination) async {
    final origin = state.origin;
    if (origin == null) {
      state = state.copyWith(
        status: RouteStatus.error,
        errorCode: 'LOCATION_NOT_AVAILABLE',
        errorMessage: 'Current location not available. Please wait for GPS to initialize.',
      );
      _diagnostics.log('ROUTE_REQUEST_FAILED', {
        'reason': 'LOCATION_NOT_AVAILABLE',
        'sequence': _routeSequence,
      });
      return;
    }

    final currentSequence = _routeSequence;

    state = state.copyWith(
      status: RouteStatus.loading,
      clearError: true,
    );

    _diagnostics.log('ROUTE_REQUEST_STARTED', {
      'originLat': origin.latitude,
      'originLng': origin.longitude,
      'destLat': destination.latitude,
      'destLng': destination.longitude,
      'batteryPercent': state.batteryPercent,
      'vehicleRangeKm': state.vehicleRangeKm,
      'sequence': currentSequence,
    });

    RouteResponse? response;
    String? errorCode;
    String? errorMessage;

    // Attempt 1
    try {
      response = await _attemptRouteFromCoords(origin, destination);
    } catch (e) {
      errorCode = 'ROUTE_ERROR';
      errorMessage = e.toString();
    }

    // Attempt 2 (retry once if OSRM/network error)
    if (response == null &&
        errorCode != null &&
        !_isNonRetryableError(errorCode)) {
      _diagnostics.log('ROUTE_REQUEST_RETRY', {
        'attempt': 2,
        'errorCode': errorCode,
        'sequence': currentSequence,
      });

      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted || _routeSequence != currentSequence) {
        _diagnostics.log('ROUTE_REQUEST_CANCELLED', {
          'reason': 'stale_or_unmounted',
          'sequence': currentSequence,
          'currentSequence': _routeSequence,
        });
        return;
      }

      try {
        response = await _attemptRouteFromCoords(origin, destination);
        errorCode = null;
        errorMessage = null;
      } catch (e) {
        errorCode = 'ROUTE_ERROR';
        errorMessage = e.toString();
      }
    }

    if (!mounted || _routeSequence != currentSequence) {
      _diagnostics.log('ROUTE_REQUEST_IGNORED', {
        'reason': 'stale_sequence',
        'sequence': currentSequence,
        'currentSequence': _routeSequence,
      });
      return;
    }

    if (response != null) {
      state = state.copyWith(
        status: RouteStatus.success,
        route: response,
        showRoute: true,
        needsChargingStop: response.needsChargingStop,
        remainingRangeKm: response.remainingRangeKm,
        optimalStation: response.optimalStation,
        lastRouteSequence: currentSequence,
      );
      _diagnostics.log('ROUTE_REQUEST_SUCCESS', {
        'distanceMeters': response.distanceMeters,
        'durationSeconds': response.durationSeconds,
        'polylinePoints': response.polyline.length,
        'stations': response.recommendedStations.length,
        'needsChargingStop': response.needsChargingStop,
        'optimalStation': response.optimalStation?.stationId,
        'sequence': currentSequence,
      });
    } else {
      state = state.copyWith(
        status: RouteStatus.error,
        errorCode: errorCode,
        errorMessage: errorMessage,
      );
      _diagnostics.log('ROUTE_REQUEST_FAILED', {
        'errorCode': errorCode,
        'errorMessage': errorMessage,
        'sequence': currentSequence,
      });
    }
  }

  Future<RouteResponse> _attemptRoute(
      LatLng origin, PlaceSuggestion destination) async {
    // Fallback defaults: use saved vehicle settings if battery info is missing
    final batteryPercent = state.batteryPercent ?? 50;
    final vehicleRangeKm = state.vehicleRangeKm ?? 300;
    final consumption = state.consumptionKwhPerKm;

    final request = RouteRequest(
      origin: LatLngPoint(lat: origin.latitude, lng: origin.longitude),
      destination: LatLngPoint(lat: destination.lat, lng: destination.lng),
      batteryPercent: batteryPercent,
      vehicleRangeKm: vehicleRangeKm,
      consumptionKwhPerKm: consumption,
    );
    return await _repository.calculateRoute(request);
  }

  Future<RouteResponse> _attemptRouteFromCoords(
      LatLng origin, LatLng destination) async {
    final batteryPercent = state.batteryPercent ?? 50;
    final vehicleRangeKm = state.vehicleRangeKm ?? 300;
    final consumption = state.consumptionKwhPerKm;

    final request = RouteRequest(
      origin: LatLngPoint(lat: origin.latitude, lng: origin.longitude),
      destination:
          LatLngPoint(lat: destination.latitude, lng: destination.longitude),
      batteryPercent: batteryPercent,
      vehicleRangeKm: vehicleRangeKm,
      consumptionKwhPerKm: consumption,
    );
    return await _repository.calculateRoute(request);
  }

  bool _isNonRetryableError(String errorCode) {
    // These codes come from the backend via ApiError.code
    // INTERNAL_ERROR and SERVICE_UNAVAILABLE ARE retryable (OSRM/network issues)
    // Everything else is non-retryable (client errors, validation, no route)
    return errorCode != 'INTERNAL_ERROR' &&
        errorCode != 'SERVICE_UNAVAILABLE' &&
        errorCode != 'NETWORK_ERROR';
  }

  // -------------------------------------------------------------------------
  // Route clearing
  // -------------------------------------------------------------------------

  void clearRoute() {
    _debounceTimer?.cancel();
    _retryTimer?.cancel();
    _routeSequence++;

    state = state.copyWith(
      status: RouteStatus.idle,
      clearRoute: true,
      clearDestination: true,
      clearError: true,
      clearSuggestions: true,
      showSuggestions: false,
      showRoute: false,
      // Do NOT clear battery info on route clear — keep saved vehicle settings
      clearOptimalStation: true,
    );

    _diagnostics.log('ROUTE_CLEARED', {'sequence': _routeSequence});
  }

  void setRouteFromCurrentLocation(LatLng origin, LatLng destination,
      {String? destinationName}) {
    final marker = destinationName != null
        ? DestinationMarker(
            name: destinationName,
            address: destinationName,
            position: destination,
          )
        : null;
    state = state.copyWith(
      origin: origin,
      destination: destination,
      destinationName: destinationName,
      destinationMarker: marker,
    );
  }

  // -------------------------------------------------------------------------
  // Battery info
  // -------------------------------------------------------------------------

  void setBatteryInfo(int batteryPercent, double vehicleRangeKm) {
    double remaining = (batteryPercent / 100.0) * vehicleRangeKm;
    state = state.copyWith(
      batteryPercent: batteryPercent,
      vehicleRangeKm: vehicleRangeKm,
      remainingRangeKm: remaining,
    );

    _diagnostics.log('BATTERY_INFO_SET', {
      'batteryPercent': batteryPercent,
      'vehicleRangeKm': vehicleRangeKm,
      'remainingRangeKm': remaining,
    });

    // Persist vehicle settings so routing always has battery info
    _settingsStorage.save(VehicleSettings(
      batteryPercent: batteryPercent,
      vehicleRangeKm: vehicleRangeKm,
      batteryCapacityKwh: 60,
      vehicleMaxChargeKw: 120,
      consumptionKwhPerKm: state.consumptionKwhPerKm,
    ));
  }

  void setVehicleSettings(VehicleSettings settings) {
    final remaining = (settings.batteryPercent / 100.0) * settings.vehicleRangeKm;
    state = state.copyWith(
      batteryPercent: settings.batteryPercent,
      vehicleRangeKm: settings.vehicleRangeKm,
      remainingRangeKm: remaining,
      consumptionKwhPerKm: settings.consumptionKwhPerKm,
    );
    _settingsStorage.save(settings);
    _diagnostics.log('VEHICLE_SETTINGS_APPLIED', settings.toJson());
  }

  void clearBatteryInfo() {
    // Reset to saved defaults instead of null — routing should never send null
    state = state.copyWith(
      batteryPercent: 50,
      vehicleRangeKm: 300,
      remainingRangeKm: 150,
      needsChargingStop: false,
      clearOptimalStation: true,
    );
  }

  // -------------------------------------------------------------------------
  // Retry current route
  // -------------------------------------------------------------------------

  Future<void> retryRoute() async {
    if (state.destination == null) return;

    _routeSequence++;

    _diagnostics.log('ROUTE_RETRY_REQUESTED', {
      'sequence': _routeSequence,
      'destination': state.destinationName,
    });

    if (state.destinationMarker != null) {
      await _calculateRoute(PlaceSuggestion(
        displayName: state.destinationMarker!.address,
        lat: state.destinationMarker!.position.latitude,
        lng: state.destinationMarker!.position.longitude,
      ));
    } else {
      await _calculateRouteFromCoordinates(state.destination!);
    }
  }
}

  // -------------------------------------------------------------------------
  // Providers
  // -------------------------------------------------------------------------

final geocodingServiceProvider = Provider<GeocodingService>((ref) {
  return GeocodingService();
});

final routingProvider =
    StateNotifierProvider<RoutingNotifier, RoutingState>((ref) {
  final repository = ref.watch(stationRepositoryProvider);
  final geocodingService = ref.watch(geocodingServiceProvider);
  return RoutingNotifier(repository, geocodingService);
});

final vehicleSettingsStorageProvider = Provider<VehicleSettingsStorage>((ref) {
  return VehicleSettingsStorage();
});
