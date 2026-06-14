import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VehicleSettings {
  final int batteryPercent;
  final double vehicleRangeKm;
  final double batteryCapacityKwh;
  final double vehicleMaxChargeKw;
  final double consumptionKwhPerKm;

  const VehicleSettings({
    this.batteryPercent = 50,
    this.vehicleRangeKm = 300,
    this.batteryCapacityKwh = 60,
    this.vehicleMaxChargeKw = 120,
    this.consumptionKwhPerKm = 0.18,
  });

  VehicleSettings copyWith({
    int? batteryPercent,
    double? vehicleRangeKm,
    double? batteryCapacityKwh,
    double? vehicleMaxChargeKw,
    double? consumptionKwhPerKm,
  }) {
    return VehicleSettings(
      batteryPercent: batteryPercent ?? this.batteryPercent,
      vehicleRangeKm: vehicleRangeKm ?? this.vehicleRangeKm,
      batteryCapacityKwh: batteryCapacityKwh ?? this.batteryCapacityKwh,
      vehicleMaxChargeKw: vehicleMaxChargeKw ?? this.vehicleMaxChargeKw,
      consumptionKwhPerKm: consumptionKwhPerKm ?? this.consumptionKwhPerKm,
    );
  }

  Map<String, dynamic> toJson() => {
        'batteryPercent': batteryPercent,
        'vehicleRangeKm': vehicleRangeKm,
        'batteryCapacityKwh': batteryCapacityKwh,
        'vehicleMaxChargeKw': vehicleMaxChargeKw,
        'consumptionKwhPerKm': consumptionKwhPerKm,
      };

  factory VehicleSettings.fromJson(Map<String, dynamic> json) {
    return VehicleSettings(
      batteryPercent: (json['batteryPercent'] as num?)?.toInt() ?? 50,
      vehicleRangeKm: (json['vehicleRangeKm'] as num?)?.toDouble() ?? 300,
      batteryCapacityKwh: (json['batteryCapacityKwh'] as num?)?.toDouble() ?? 60,
      vehicleMaxChargeKw: (json['vehicleMaxChargeKw'] as num?)?.toDouble() ?? 120,
      consumptionKwhPerKm: (json['consumptionKwhPerKm'] as num?)?.toDouble() ?? 0.18,
    );
  }

  static const VehicleSettings defaults = VehicleSettings();
}

class VehicleSettingsStorage {
  static const String _key = 'vehicle_settings';

  Future<VehicleSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key);
    if (json == null) return VehicleSettings.defaults;
    try {
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      return VehicleSettings.fromJson(decoded);
    } catch (_) {
      return VehicleSettings.defaults;
    }
  }

  Future<void> save(VehicleSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(settings.toJson()));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
