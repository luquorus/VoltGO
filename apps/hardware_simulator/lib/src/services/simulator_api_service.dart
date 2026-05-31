import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_api/shared_api.dart';

class SimulatorApiService {
  final ApiClientFactory _factory;

  SimulatorApiService(this._factory);

  Future<List<Map<String, dynamic>>> getBatterySwapStations() async {
    final response = await _factory.public.getAllSwapStations();
    return (response as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> getStationPiles(String stationId) async {
    final response = await _factory.public.getStationPiles(stationId);
    return Map<String, dynamic>.from(response);
  }
}

final simulatorApiServiceProvider = Provider<SimulatorApiService>((ref) {
  final factory = ref.watch(apiClientFactoryProvider);
  if (factory == null) throw Exception('API client not initialized');
  return SimulatorApiService(factory);
});
