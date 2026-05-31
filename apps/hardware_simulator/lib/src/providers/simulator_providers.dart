import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_api/shared_api.dart';
import '../models/simulator_models.dart';
import '../services/simulator_websocket_service.dart';

final baseUrlProvider = Provider<String>((ref) {
  return dotenv.get('BASE_URL', fallback: 'http://localhost:8080');
});

final wsBaseUrlProvider = Provider<String>((ref) {
  final baseUrl = ref.watch(baseUrlProvider);
  return baseUrl.replaceFirst('http://', 'ws://').replaceFirst('https://', 'wss://');
});

final batterySwapStationsProvider = FutureProvider<List<SimulatorStationListItem>>((ref) async {
  final factory = ref.read(apiClientFactoryProvider);
  if (factory == null) throw Exception('API client not initialized');
  final response = await factory.public.getAllSwapStations();
  return (response)
      .map((e) => SimulatorStationListItem.fromJson(e as Map<String, dynamic>))
      .toList();
});

final selectedStationIdProvider = StateProvider<String?>((ref) => null);

final stationPilesProvider = FutureProvider.family<SimulatorStationPilesModel?, String>((ref, stationId) async {
  final factory = ref.read(apiClientFactoryProvider);
  if (factory == null) throw Exception('API client not initialized');
  try {
    final response = await factory.public.getStationPiles(stationId);
    return SimulatorStationPilesModel.fromJson(response);
  } catch (e) {
    return null;
  }
});

final wsServiceProvider = Provider<SimulatorWebSocketService>((ref) {
  final service = SimulatorWebSocketService();
  ref.onDispose(() => service.dispose());
  return service;
});

final wsConnectionStatusProvider = StateProvider<bool>((ref) => false);

final activeSwapCodeProvider = StateProvider<SwapCodeEvent?>((ref) => null);

final enteredSwapCodeProvider = StateProvider<String>((ref) => '');
