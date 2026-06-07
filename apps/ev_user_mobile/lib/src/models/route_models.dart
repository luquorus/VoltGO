import 'package:flutter/foundation.dart';

@immutable
class LatLngPoint {
  final double lat;
  final double lng;

  const LatLngPoint({required this.lat, required this.lng});

  factory LatLngPoint.fromJson(Map<String, dynamic> json) {
    return LatLngPoint(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};
}

@immutable
class RouteRequest {
  final LatLngPoint origin;
  final LatLngPoint destination;
  final int? batteryPercent;
  final double? vehicleRangeKm;
  final double? consumptionKwhPerKm;

  const RouteRequest({
    required this.origin,
    required this.destination,
    this.batteryPercent,
    this.vehicleRangeKm,
    this.consumptionKwhPerKm,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'origin': origin.toJson(),
      'destination': destination.toJson(),
    };
    if (batteryPercent != null) map['batteryPercent'] = batteryPercent!;
    if (vehicleRangeKm != null) map['vehicleRangeKm'] = vehicleRangeKm!;
    if (consumptionKwhPerKm != null) map['consumptionKwhPerKm'] = consumptionKwhPerKm!;
    return map;
  }
}

@immutable
class RecommendedStation {
  final String stationId;
  final String name;
  final String address;
  final double lat;
  final double lng;
  final double distanceFromRouteMeters;
  final double detourMeters;
  final double totalPowerKw;
  final int availablePorts;
  final int totalPorts;
  final List<String> connectorTypes;
  final double? rating;
  final int estimatedArrivalMinutes;
  final int waitTimeMinutes;
  final int estimatedChargeMinutes;
  final double score;
  final double? distanceKm;
  final double? optimalChargingStopMinutes;
  final bool isOptimalStop;
  final double? remainingRangeAfterStopKm;
  final double? estimatedBatteryAtArrival;
  final String? recommendationReason;
  final bool isRecommended;

  const RecommendedStation({
    required this.stationId,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    required this.distanceFromRouteMeters,
    required this.detourMeters,
    required this.totalPowerKw,
    required this.availablePorts,
    required this.totalPorts,
    required this.connectorTypes,
    this.rating,
    required this.estimatedArrivalMinutes,
    required this.waitTimeMinutes,
    required this.estimatedChargeMinutes,
    required this.score,
    this.distanceKm,
    this.optimalChargingStopMinutes,
    this.isOptimalStop = false,
    this.remainingRangeAfterStopKm,
    this.estimatedBatteryAtArrival,
    this.recommendationReason,
    this.isRecommended = false,
  });

  factory RecommendedStation.fromJson(Map<String, dynamic> json) {
    return RecommendedStation(
      stationId: json['stationId']?.toString() ?? '',
      name: json['name'] as String? ?? 'Unknown Station',
      address: json['address'] as String? ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0,
      distanceFromRouteMeters:
          (json['distanceFromRouteMeters'] as num?)?.toDouble() ?? 0,
      detourMeters: (json['detourMeters'] as num?)?.toDouble() ?? 0,
      totalPowerKw: (json['totalPowerKw'] as num?)?.toDouble() ?? 0,
      availablePorts: (json['availablePorts'] as num?)?.toInt() ?? 0,
      totalPorts: (json['totalPorts'] as num?)?.toInt() ?? 0,
      connectorTypes: (json['connectorTypes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      rating: (json['rating'] as num?)?.toDouble(),
      estimatedArrivalMinutes:
          (json['estimatedArrivalMinutes'] as num?)?.toInt() ?? 0,
      waitTimeMinutes: (json['waitTimeMinutes'] as num?)?.toInt() ?? 0,
      estimatedChargeMinutes:
          (json['estimatedChargeMinutes'] as num?)?.toInt() ?? 0,
      score: (json['score'] as num?)?.toDouble() ?? 0,
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      optimalChargingStopMinutes: (json['optimalChargingStopMinutes'] as num?)?.toDouble(),
      isOptimalStop: json['isOptimalStop'] as bool? ?? false,
      remainingRangeAfterStopKm: (json['remainingRangeAfterStopKm'] as num?)?.toDouble(),
      estimatedBatteryAtArrival: (json['estimatedBatteryAtArrival'] as num?)?.toDouble(),
      recommendationReason: json['recommendationReason'] as String?,
      isRecommended: json['isRecommended'] as bool? ?? false,
    );
  }
}

@immutable
class RouteSummary {
  final double distanceKm;
  final int durationMinutes;
  final bool viaRoad;
  final bool hasChargingStations;
  final bool? needsChargingRecommendation;
  final String? primaryRecommendationReason;

  const RouteSummary({
    required this.distanceKm,
    required this.durationMinutes,
    required this.viaRoad,
    required this.hasChargingStations,
    this.needsChargingRecommendation,
    this.primaryRecommendationReason,
  });

  factory RouteSummary.fromJson(Map<String, dynamic> json) {
    return RouteSummary(
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0,
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 0,
      viaRoad: json['viaRoad'] as bool? ?? true,
      hasChargingStations: json['hasChargingStations'] as bool? ?? false,
      needsChargingRecommendation: json['needsChargingRecommendation'] as bool?,
      primaryRecommendationReason: json['primaryRecommendationReason'] as String?,
    );
  }
}

@immutable
class RouteResponse {
  final int distanceMeters;
  final int durationSeconds;
  final List<LatLngPoint> polyline;
  final List<RecommendedStation> recommendedStations;
  final RouteSummary summary;
  final RecommendedStation? optimalStation;
  final bool needsChargingStop;
  final double? remainingRangeKm;
  final double? routeDistanceKm;
  final RouteBoundingBox? boundingBox;

  const RouteResponse({
    required this.distanceMeters,
    required this.durationSeconds,
    required this.polyline,
    required this.recommendedStations,
    required this.summary,
    this.optimalStation,
    this.needsChargingStop = false,
    this.remainingRangeKm,
    this.routeDistanceKm,
    this.boundingBox,
  });

  factory RouteResponse.fromJson(Map<String, dynamic> json) {
    final polylineList = (json['polyline'] as List<dynamic>?)
            ?.map((e) => LatLngPoint.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    final stationsList = (json['recommendedStations'] as List<dynamic>?)
            ?.map((e) => RecommendedStation.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return RouteResponse(
      distanceMeters: (json['distanceMeters'] as num?)?.toInt() ?? 0,
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      polyline: polylineList,
      recommendedStations: stationsList,
      summary: json['summary'] != null
          ? RouteSummary.fromJson(json['summary'] as Map<String, dynamic>)
          : const RouteSummary(
              distanceKm: 0,
              durationMinutes: 0,
              viaRoad: true,
              hasChargingStations: false,
            ),
      optimalStation: json['optimalStation'] != null
          ? RecommendedStation.fromJson(json['optimalStation'] as Map<String, dynamic>)
          : null,
      needsChargingStop: json['needsChargingStop'] as bool? ?? false,
      remainingRangeKm: (json['remainingRangeKm'] as num?)?.toDouble(),
      routeDistanceKm: (json['routeDistanceKm'] as num?)?.toDouble(),
      boundingBox: json['boundingBox'] != null
          ? RouteBoundingBox.fromJson(json['boundingBox'] as Map<String, dynamic>)
          : null,
    );
  }
}

@immutable
class RouteBoundingBox {
  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;

  const RouteBoundingBox({
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
  });

  factory RouteBoundingBox.fromJson(Map<String, dynamic> json) {
    return RouteBoundingBox(
      minLat: (json['minLat'] as num?)?.toDouble() ?? 0,
      maxLat: (json['maxLat'] as num?)?.toDouble() ?? 0,
      minLng: (json['minLng'] as num?)?.toDouble() ?? 0,
      maxLng: (json['maxLng'] as num?)?.toDouble() ?? 0,
    );
  }
}

@immutable
class PlaceSuggestion {
  final String displayName;
  final double lat;
  final double lng;
  final String? type;
  final double? importance;

  const PlaceSuggestion({
    required this.displayName,
    required this.lat,
    required this.lng,
    this.type,
    this.importance,
  });

  factory PlaceSuggestion.fromNominatimJson(Map<String, dynamic> json) {
    return PlaceSuggestion(
      displayName: json['display_name'] as String? ?? '',
      lat: double.parse(json['lat'] as String),
      lng: double.parse(json['lon'] as String),
      type: json['type'] as String?,
      importance: (json['importance'] as num?)?.toDouble(),
    );
  }

  factory PlaceSuggestion.fromOsrmJson(Map<String, dynamic> json) {
    final location = json['location'] as List<dynamic>?;
    final name = json['name'] as String? ?? '';
    final raw = json['raw'] as Map<String, dynamic>?;
    final properties = raw?['properties'] as Map<String, dynamic>?;

    final city = properties?['city'] as String?;
    final country = properties?['country'] as String?;
    final street = properties?['street'] as String?;

    String displayName;
    if (city != null || country != null) {
      final parts = <String>[name];
      if (street != null && street != name) parts.add(street);
      if (city != null) parts.add(city);
      if (country != null) parts.add(country);
      displayName = parts.join(', ');
    } else {
      displayName = name;
    }

    return PlaceSuggestion(
      displayName: displayName,
      lat: location != null && location.length >= 2 ? (location[1] as num).toDouble() : 0,
      lng: location != null && location.length >= 2 ? (location[0] as num).toDouble() : 0,
      type: properties?['type'] as String?,
      importance: null,
    );
  }

  String get shortName {
    final parts = displayName.split(', ');
    if (parts.length >= 2) {
      return '${parts[0]}, ${parts[1]}';
    }
    return displayName;
  }
}
