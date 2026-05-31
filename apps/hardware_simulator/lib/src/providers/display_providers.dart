import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/simulator_models.dart';
import '../services/display_websocket_service.dart';
final publicBaseUrlProvider = Provider<String>((ref) {
  return 'http://localhost:8080';
});

/// Public REST client for display screen
final publicDioProvider = Provider<Dio>((ref) {
  final baseUrl = ref.watch(publicBaseUrlProvider);
  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));
  return dio;
});

/// Device key for current display session (fetched once per station selection)
final displayDeviceKeyProvider = FutureProvider.family<String?, String>((ref, stationId) async {
  final dio = ref.watch(publicDioProvider);
  try {
    final response = await dio.get('/api/public/device/stations/$stationId/key');
    final data = response.data as Map<String, dynamic>;
    return data['deviceKey'] as String?;
  } catch (e) {
    return null;
  }
});

/// Fetch station list (public)
final displayStationsProvider = FutureProvider<List<SimulatorStationListItem>>((ref) async {
  final dio = ref.watch(publicDioProvider);
  try {
    final response = await dio.get('/api/public/battery-swap/stations');
    final list = response.data as List<dynamic>;
    return list
        .map((e) => SimulatorStationListItem.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (e) {
    return [];
  }
});

/// Selected station ID
final displaySelectedStationIdProvider = StateProvider<String?>((ref) => null);

/// Fetch station piles (public)
final displayStationPilesProvider = FutureProvider.family<SimulatorStationPilesModel?, String>((ref, stationId) async {
  final dio = ref.watch(publicDioProvider);
  try {
    final response = await dio.get('/api/public/battery-swap/stations/$stationId/piles');
    return SimulatorStationPilesModel.fromJson(response.data as Map<String, dynamic>);
  } catch (e) {
    return null;
  }
});

/// Polling fallback: active swap code for a station
final displayActiveSwapCodeProvider = FutureProvider.family<DisplaySwapCodeEvent?, String>((ref, stationId) async {
  final dio = ref.watch(publicDioProvider);
  try {
    final response = await dio.get('/api/public/battery-swap/stations/$stationId/active-code');
    final data = response.data as Map<String, dynamic>;
    final code = data['swapCode'] as String?;
    if (code == null || code.isEmpty) return null;
    return DisplaySwapCodeEvent(
      swapCode: code,
      reservationId: data['reservationId'] as String? ?? '',
      deadlineAt: data['deadlineAt'] != null ? DateTime.tryParse(data['deadlineAt'] as String) : null,
    );
  } catch (e) {
    return null;
  }
});

/// Public WebSocket service with device-key support
final displayWsServiceProvider = Provider<DisplayWebSocketService>((ref) {
  final service = DisplayWebSocketService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Auto-connect WS when station is selected (reads device key and connects)
final displayWsAutoConnectProvider = Provider<void>((ref) {
  final wsService = ref.watch(displayWsServiceProvider);
  final selectedStationId = ref.watch(displaySelectedStationIdProvider);
  if (selectedStationId == null) return;

  final deviceKeyAsync = ref.watch(displayDeviceKeyProvider(selectedStationId));

  deviceKeyAsync.whenData((deviceKey) {
    final baseUrl = ref.watch(publicBaseUrlProvider);
    final wsUrl = baseUrl
        .replaceFirst('http://', 'ws://')
        .replaceFirst('https://', 'wss://') +
        '/ws/display/battery-swap';
    wsService.connect(wsUrl, deviceKey: deviceKey);
    wsService.subscribe(selectedStationId);
  });
});

/// Active swap code displayed
final displayShownSwapCodeProvider = StateProvider<DisplaySwapCodeEvent?>((ref) => null);

/// Refresh trigger for station piles
final displayRefreshTriggerProvider = StateProvider<int>((ref) => 0);

/// Auto-refresh provider
final displayRefreshStationPilesProvider = FutureProvider.family<SimulatorStationPilesModel?, String>((ref, stationId) async {
  ref.watch(displayRefreshTriggerProvider);
  final dio = ref.watch(publicDioProvider);
  try {
    final response = await dio.get('/api/public/battery-swap/stations/$stationId/piles');
    return SimulatorStationPilesModel.fromJson(response.data as Map<String, dynamic>);
  } catch (e) {
    return null;
  }
});
