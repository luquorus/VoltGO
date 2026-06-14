import 'package:shared_api/shared_api.dart';
import 'package:shared_network/shared_network.dart';

/// Lightweight item returned by the search-by-name endpoint.
class StationSearchItem {
  final String stationId;
  final String name;
  final String? address;
  final double? lat;
  final double? lng;
  final String? operatingHours;
  final bool supportsBatterySwap;

  StationSearchItem({
    required this.stationId,
    required this.name,
    this.address,
    this.lat,
    this.lng,
    this.operatingHours,
    this.supportsBatterySwap = false,
  });

  factory StationSearchItem.fromJson(Map<String, dynamic> json) {
    double? _asDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return StationSearchItem(
      stationId: (json['stationId'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      address: json['address'] as String?,
      lat: _asDouble(json['lat']),
      lng: _asDouble(json['lng']),
      operatingHours: json['operatingHours'] as String?,
      supportsBatterySwap: (json['supportsBatterySwap'] as bool?) ?? false,
    );
  }
}

/// Full charging-station detail used to auto-fill the create-CR form.
class StationAutoFillData {
  final String stationId;
  final String name;
  final String? address;
  final double? lat;
  final double? lng;
  final String? operatingHours;
  final String? parking;
  final String? visibility;
  final String? publicStatus;
  final List<PortAutoFill> ports;
  final int? totalBatteries;
  final double? avgChargePowerKw;

  StationAutoFillData({
    required this.stationId,
    required this.name,
    this.address,
    this.lat,
    this.lng,
    this.operatingHours,
    this.parking,
    this.visibility,
    this.publicStatus,
    this.ports = const [],
    this.totalBatteries,
    this.avgChargePowerKw,
  });

  factory StationAutoFillData.fromJson(Map<String, dynamic> json) {
    double? _asDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    int? _asInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    final portsJson = (json['ports'] as List<dynamic>? ?? const [])
        .map((e) => PortAutoFill.fromJson(e as Map<String, dynamic>))
        .toList();

    final batterySwap = json['batterySwap'] as Map<String, dynamic>?;
    final supportsSwap = (json['supportsBatterySwap'] as bool?) ?? false;

    return StationAutoFillData(
      stationId: (json['stationId'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      address: json['address'] as String?,
      lat: _asDouble(json['lat']),
      lng: _asDouble(json['lng']),
      operatingHours: json['operatingHours'] as String?,
      parking: json['parking'] as String?,
      visibility: json['visibility'] as String?,
      publicStatus: json['publicStatus'] as String?,
      ports: portsJson,
      totalBatteries: supportsSwap && batterySwap != null
          ? _asInt(batterySwap['totalBatteries'])
          : null,
      avgChargePowerKw: supportsSwap && batterySwap != null
          ? _asDouble(batterySwap['avgChargePowerKw'])
          : null,
    );
  }
}

class PortAutoFill {
  final String? powerType; // AC / DC
  final double? powerKw;
  final int? count;

  PortAutoFill({this.powerType, this.powerKw, this.count});

  factory PortAutoFill.fromJson(Map<String, dynamic> json) {
    double? _asDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    int? _asInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    return PortAutoFill(
      powerType: json['powerType'] as String?,
      powerKw: _asDouble(json['powerKw']),
      count: _asInt(json['count']),
    );
  }
}

/// Battery-swap search item.
class BatterySwapStationSearchItem {
  final String stationId;
  final String name;
  final String? address;
  final String? publicStatus;
  final int? totalBatteries;
  final int? availableBatteries;

  BatterySwapStationSearchItem({
    required this.stationId,
    required this.name,
    this.address,
    this.publicStatus,
    this.totalBatteries,
    this.availableBatteries,
  });

  factory BatterySwapStationSearchItem.fromJson(Map<String, dynamic> json) {
    int? _asInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    return BatterySwapStationSearchItem(
      stationId: (json['id'] as String?) ?? (json['stationId'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      address: json['address'] as String?,
      publicStatus: json['publicStatus'] as String?,
      totalBatteries: _asInt(json['totalBatteries']),
      availableBatteries: _asInt(json['availableBatteries']),
    );
  }
}

/// Battery-swap full detail used to auto-fill the create-CR form.
class BatterySwapStationAutoFillData {
  final String stationId;
  final String name;
  final String? address;
  final double? lat;
  final double? lng;
  final String? operatingHours;
  final int? totalBatteries;
  final int? availableBatteries;
  final double? avgChargePowerKw;

  BatterySwapStationAutoFillData({
    required this.stationId,
    required this.name,
    this.address,
    this.lat,
    this.lng,
    this.operatingHours,
    this.totalBatteries,
    this.availableBatteries,
    this.avgChargePowerKw,
  });

  factory BatterySwapStationAutoFillData.fromJson(Map<String, dynamic> json) {
    double? _asDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    int? _asInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    return BatterySwapStationAutoFillData(
      stationId: (json['id'] as String?) ?? (json['stationId'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      address: json['address'] as String?,
      lat: _asDouble(json['lat']),
      lng: _asDouble(json['lng']),
      operatingHours: json['operatingHours'] as String?,
      totalBatteries: _asInt(json['totalBatteries']),
      availableBatteries: _asInt(json['availableBatteries']),
      avgChargePowerKw: _asDouble(json['avgChargePowerKw']),
    );
  }
}

/// Repository for searching stations and fetching their full detail
/// (used by the create-change-request form for auto-fill).
class StationSearchRepository {
  final CollaboratorMobileApiClient apiClient;

  StationSearchRepository(this.apiClient);

  Future<List<StationSearchItem>> searchChargingStations(String name) async {
    try {
      final response = await apiClient.searchChargingStationsByName(name);
      return _parseContent(response)
          .map((e) => StationSearchItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } on ApiError {
      rethrow;
    } catch (e) {
      throw _wrap(e, 'Could not search charging stations.');
    }
  }

  Future<StationAutoFillData> getChargingStationDetail(String stationId) async {
    if (stationId.trim().isEmpty) {
      throw Exception('Station id is empty');
    }
    try {
      final response = await apiClient.getChargingStationDetail(stationId);
      return StationAutoFillData.fromJson(response);
    } on ApiError {
      rethrow;
    } catch (e) {
      throw _wrap(e, 'Could not load charging station detail.');
    }
  }

  Future<List<BatterySwapStationSearchItem>> searchBatterySwapStations(
      String search) async {
    try {
      final response = await apiClient.searchBatterySwapStationsByName(search);
      return _parseContent(response)
          .map((e) =>
              BatterySwapStationSearchItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } on ApiError {
      rethrow;
    } catch (e) {
      throw _wrap(e, 'Could not search battery-swap stations.');
    }
  }

  Future<BatterySwapStationAutoFillData> getBatterySwapStationDetail(
      String stationId) async {
    if (stationId.trim().isEmpty) {
      throw Exception('Station id is empty');
    }
    try {
      final response = await apiClient.getBatterySwapStationDetail(stationId);
      return BatterySwapStationAutoFillData.fromJson(response);
    } on ApiError {
      rethrow;
    } catch (e) {
      throw _wrap(e, 'Could not load battery-swap station detail.');
    }
  }

  List<dynamic> _parseContent(Map<String, dynamic> response) {
    final dynamic content = response['content'];
    if (content is List) return content;
    if (response['items'] is List) return response['items'] as List;
    if (response['data'] is List) return response['data'] as List;
    return const [];
  }

  Exception _wrap(Object e, String fallback) {
    if (e is Exception) return e;
    return Exception('$fallback: $e');
  }
}
