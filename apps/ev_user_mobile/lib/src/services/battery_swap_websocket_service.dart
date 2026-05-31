import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_auth/shared_auth.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/battery_swap_models.dart';

/// WebSocket slot update event
class SlotUpdateEvent {
  final String slotId;
  final int slotIndex;
  final String? batteryId;
  final int batteryChargePercent;
  final BatterySlotStatus status;
  final DateTime? estimatedFullAt;
  final DateTime updatedAt;

  SlotUpdateEvent({
    required this.slotId,
    required this.slotIndex,
    this.batteryId,
    required this.batteryChargePercent,
    required this.status,
    this.estimatedFullAt,
    required this.updatedAt,
  });
}

/// WebSocket swap code event - fired when a swap code is generated for a reservation
class SwapCodeEvent {
  final String stationId;
  final String slotId;
  final String reservationId;
  final String swapCode;
  final DateTime? deadlineAt;

  SwapCodeEvent({
    required this.stationId,
    required this.slotId,
    required this.reservationId,
    required this.swapCode,
    this.deadlineAt,
  });
}

/// WebSocket swap completed event - fired when a swap is successfully completed
class SwapCompletedEvent {
  final String stationId;
  final String slotId;
  final String reservationId;
  final String status;

  SwapCompletedEvent({
    required this.stationId,
    required this.slotId,
    required this.reservationId,
    required this.status,
  });
}

/// Battery swap WebSocket service.
/// Connects to /ws/battery-swap, authenticates via JWT token,
/// broadcasts slot updates to listeners.
class BatterySwapWebSocketService {
  final String wsBaseUrl;
  final AuthState Function() getAuthState;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  bool _connecting = false;
  String? _connectedStationId;
  final Set<VoidCallback> _connectListeners = {};
  final Set<void Function(String error)> _errorListeners = {};
  final Set<void Function(SlotUpdateEvent)> _slotUpdateListeners = {};
  final StreamController<SlotUpdateEvent> _slotUpdateController =
      StreamController<SlotUpdateEvent>.broadcast();
  final StreamController<SwapCodeEvent> _swapCodeController =
      StreamController<SwapCodeEvent>.broadcast();
  final StreamController<SwapCompletedEvent> _swapCompletedController =
      StreamController<SwapCompletedEvent>.broadcast();

  /// Cache of latest slot data: slotId → BatterySlotModel
  final Map<String, BatterySlotModel> _slotCache = {};

  BatterySwapWebSocketService({
    required this.wsBaseUrl,
    required this.getAuthState,
  }) {
    _tryConnect();
  }

  void _tryConnect() {
    final auth = getAuthState();
    if (auth.isAuthenticated && auth.token != null && auth.token!.isNotEmpty) {
      connect();
    }
  }

  bool get isConnected => _channel != null;

  /// Connect to WebSocket with current JWT token.
  Future<void> connect() async {
    if (_connecting || isConnected) return;
    _connecting = true;

    final auth = getAuthState();
    final token = auth.token;
    if (token == null || token.isEmpty) {
      _notifyError('Not authenticated');
      _connecting = false;
      return;
    }

    try {
      final uri = Uri.parse('$wsBaseUrl/ws/battery-swap?token=$token');
      _channel = WebSocketChannel.connect(uri);

      _subscription = _channel!.stream.listen(
        _handleMessage,
        onError: (error) {
          _connecting = false;
          _notifyError('Connection error');
          _scheduleReconnect();
        },
        onDone: () {
          _connecting = false;
          _channel = null;
          _connectedStationId = null;
          _scheduleReconnect();
        },
      );

      _connecting = false;
      _notifyConnected();
    } catch (e) {
      _connecting = false;
      _notifyError(e.toString());
      _scheduleReconnect();
    }
  }

  /// Disconnect and cancel all subscriptions.
  void disconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _connectedStationId = null;
    _slotCache.clear();
    _slotUpdateListeners.clear();
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
    _connecting = false;
    _slotUpdateController.close();
    _swapCodeController.close();
    _swapCompletedController.close();
  }

  Timer? _reconnectTimer;

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!isConnected) {
        connect();
      }
    });
  }

  void _onReconnected() {
    if (_connectedStationId != null) {
      _send({'type': 'subscribe', 'stationId': _connectedStationId});
    }
  }

  /// Subscribe to slot updates for a specific station.
  Future<void> subscribeToStation(String stationId) async {
    _connectedStationId = stationId;
    _send({'type': 'subscribe', 'stationId': stationId});
  }

  /// Unsubscribe from a station.
  void unsubscribeFromStation(String stationId) {
    if (_connectedStationId == stationId) {
      _send({'type': 'unsubscribe', 'stationId': stationId});
      _connectedStationId = null;
    }
  }

  /// Listen for connection events.
  void addConnectListener(VoidCallback cb) => _connectListeners.add(cb);
  void removeConnectListener(VoidCallback cb) => _connectListeners.remove(cb);

  /// Listen for error events.
  void addErrorListener(void Function(String error) cb) =>
      _errorListeners.add(cb);
  void removeErrorListener(void Function(String error) cb) =>
      _errorListeners.remove(cb);

  /// Listen for slot update events (add listener style).
  void addSlotUpdateListener(void Function(SlotUpdateEvent) cb) =>
      _slotUpdateListeners.add(cb);
  void removeSlotUpdateListener(void Function(SlotUpdateEvent) cb) =>
      _slotUpdateListeners.remove(cb);

  /// Stream of slot updates.
  Stream<SlotUpdateEvent> onSlotUpdate() => _slotUpdateController.stream;

  /// Stream of swap code events.
  Stream<SwapCodeEvent> onSwapCode() => _swapCodeController.stream;

  /// Stream of swap completed events.
  Stream<SwapCompletedEvent> onSwapCompleted() => _swapCompletedController.stream;

  /// Get latest cached slot data.
  BatterySlotModel? getCachedSlot(String slotId) => _slotCache[slotId];

  /// Get all cached slots.
  List<BatterySlotModel> getCachedSlots() => _slotCache.values.toList();

  void _send(Map<String, dynamic> data) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode(data));
    }
  }

  void _handleMessage(dynamic data) {
    try {
      final msg = jsonDecode(data as String) as Map<String, dynamic>;
      final type = (msg['type'] as String?) ?? '';

      switch (type) {
        case 'CONNECTED':
        case 'SUBSCRIBED':
          _notifyConnected();
          _onReconnected();
          break;

        case 'SLOT_UPDATE':
          final slot = msg['slot'] as Map<String, dynamic>;
          final event = _parseSlotUpdate(slot);
          _slotCache[event.slotId] = BatterySlotModel(
            slotId: event.slotId,
            slotIndex: event.slotIndex,
            batteryId: event.batteryId,
            batteryChargePercent: event.batteryChargePercent,
            status: event.status,
            estimatedFullAt: event.estimatedFullAt,
          );
          for (final cb in _slotUpdateListeners) {
            cb(event);
          }
          _slotUpdateController.add(event);
          break;

        case 'SWAP_CODE':
          final swapCodeEvent = _parseSwapCodeEvent(msg);
          _swapCodeController.add(swapCodeEvent);
          break;

        case 'SWAP_COMPLETED':
          final swapCompletedEvent = _parseSwapCompletedEvent(msg);
          _swapCompletedController.add(swapCompletedEvent);
          break;

        case 'ERROR':
          _notifyError((msg['message'] as String?) ?? 'Unknown error');
          break;
      }
    } catch (e) {
      debugPrint('[WS] Failed to parse message: $e');
    }
  }

  SlotUpdateEvent _parseSlotUpdate(Map<String, dynamic> slot) {
    return SlotUpdateEvent(
      slotId: (slot['slotId'] as String?) ?? '',
      slotIndex: (slot['slotIndex'] as num?)?.toInt() ?? 0,
      batteryId: slot['batteryId'] as String?,
      batteryChargePercent:
          (slot['batteryChargePercent'] as num?)?.toInt() ?? 0,
      status: _parseStatus(slot['status'] as String?),
      estimatedFullAt: slot['estimatedFullAt'] != null
          ? DateTime.tryParse(slot['estimatedFullAt'] as String)
          : null,
      updatedAt: slot['updatedAt'] != null
          ? DateTime.tryParse(slot['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  BatterySlotStatus _parseStatus(String? s) {
    switch (s?.toUpperCase()) {
      case 'OCCUPIED':
        return BatterySlotStatus.occupied;
      case 'CHARGING':
        return BatterySlotStatus.charging;
      case 'RESERVED':
        return BatterySlotStatus.reserved;
      case 'SWAPPED_OUT':
        return BatterySlotStatus.swappedOut;
      default:
        return BatterySlotStatus.available;
    }
  }

  SwapCodeEvent _parseSwapCodeEvent(Map<String, dynamic> msg) {
    return SwapCodeEvent(
      stationId: (msg['stationId'] as String?) ?? '',
      slotId: (msg['slotId'] as String?) ?? '',
      reservationId: (msg['reservationId'] as String?) ?? '',
      swapCode: (msg['swapCode'] as String?) ?? '',
      deadlineAt: msg['deadlineAt'] != null
          ? DateTime.tryParse(msg['deadlineAt'] as String)
          : null,
    );
  }

  SwapCompletedEvent _parseSwapCompletedEvent(Map<String, dynamic> msg) {
    return SwapCompletedEvent(
      stationId: (msg['stationId'] as String?) ?? '',
      slotId: (msg['slotId'] as String?) ?? '',
      reservationId: (msg['reservationId'] as String?) ?? '',
      status: (msg['status'] as String?) ?? '',
    );
  }

  void _notifyConnected() {
    for (final cb in _connectListeners) {
      cb();
    }
  }

  void _notifyError(String error) {
    for (final cb in _errorListeners) {
      cb(error);
    }
  }
}
