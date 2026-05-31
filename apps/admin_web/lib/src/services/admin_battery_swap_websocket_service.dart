import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_auth/shared_auth.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// WebSocket slot update event for admin simulator
class SlotUpdateEvent {
  final String slotId;
  final int slotIndex;
  final String? batteryId;
  final int batteryChargePercent;
  final String status;
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

  factory SlotUpdateEvent.fromJson(Map<String, dynamic> json) {
    return SlotUpdateEvent(
      slotId: json['slotId'] as String? ?? '',
      slotIndex: (json['slotIndex'] as num?)?.toInt() ?? 0,
      batteryId: json['batteryId'] as String?,
      batteryChargePercent: (json['batteryChargePercent'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'AVAILABLE',
      estimatedFullAt: json['estimatedFullAt'] != null
          ? DateTime.tryParse(json['estimatedFullAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// WebSocket swap code event
class SwapCodeEvent {
  final String swapCode;
  final DateTime? expiry;
  final String reservationId;

  SwapCodeEvent({
    required this.swapCode,
    this.expiry,
    required this.reservationId,
  });

  factory SwapCodeEvent.fromJson(Map<String, dynamic> json) {
    return SwapCodeEvent(
      swapCode: json['swapCode'] as String? ?? '',
      expiry: json['expiry'] != null
          ? DateTime.tryParse(json['expiry'] as String)
          : null,
      reservationId: json['reservationId'] as String? ?? '',
    );
  }
}

/// Admin Battery Swap WebSocket Service.
/// Connects to /ws/battery-swap, authenticates via JWT token,
/// broadcasts slot updates to listeners.
class AdminBatterySwapWebSocketService {
  final AuthState Function() getAuthState;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  bool _connecting = false;
  final Set<String> _subscribedStations = {};
  final Set<VoidCallback> _connectListeners = {};
  final Set<void Function(String error)> _errorListeners = {};
  final Set<void Function(SlotUpdateEvent)> _slotUpdateListeners = {};
  final Set<void Function(String code, DateTime? expiry, String reservationId)> _swapCodeListeners = {};
  final Set<VoidCallback> _swapCompletedListeners = {};
  final StreamController<SlotUpdateEvent> _slotUpdateController =
      StreamController<SlotUpdateEvent>.broadcast();

  String? _wsBaseUrl;

  AdminBatterySwapWebSocketService({
    required this.getAuthState,
  });

  bool get isConnected => _channel != null;
  bool _serverConfirmedConnection = false;

  /// Connect to WebSocket with current JWT token.
  Future<void> connect(String wsBaseUrl) async {
    if (_connecting || isConnected) return;
    _connecting = true;
    _wsBaseUrl = wsBaseUrl;

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
          _serverConfirmedConnection = false;
          _notifyError('Connection error');
          _scheduleReconnect();
        },
        onDone: () {
          _connecting = false;
          _serverConfirmedConnection = false;
          _channel = null;
          _scheduleReconnect();
        },
      );

      _connecting = false;
      // Note: _notifyConnected() is called when backend sends CONNECTED message,
      // not here, to avoid race condition where channel is open but server
      // hasn't confirmed auth yet.
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
    _subscribedStations.clear();
    _slotUpdateListeners.clear();
    _swapCodeListeners.clear();
    _swapCompletedListeners.clear();
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
    _connecting = false;
    _serverConfirmedConnection = false;
  }

  Timer? _reconnectTimer;

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!isConnected && _wsBaseUrl != null) {
        connect(_wsBaseUrl!);
      }
    });
  }

  /// Subscribe to slot updates for a specific station.
  void subscribe(String stationId) {
    _subscribedStations.add(stationId);
    _send({'type': 'subscribe', 'stationId': stationId});
  }

  /// Unsubscribe from a station.
  void unsubscribe(String stationId) {
    _subscribedStations.remove(stationId);
    _send({'type': 'unsubscribe', 'stationId': stationId});
  }

  /// Listen for connection events.
  void addConnectListener(VoidCallback cb) => _connectListeners.add(cb);
  void removeConnectListener(VoidCallback cb) => _connectListeners.remove(cb);

  /// Listen for error events.
  void addErrorListener(void Function(String error) cb) =>
      _errorListeners.add(cb);
  void removeErrorListener(void Function(String error) cb) =>
      _errorListeners.remove(cb);

  /// Listen for slot update events.
  void addSlotUpdateListener(void Function(SlotUpdateEvent) cb) =>
      _slotUpdateListeners.add(cb);
  void removeSlotUpdateListener(void Function(SlotUpdateEvent) cb) =>
      _slotUpdateListeners.remove(cb);

  /// Listen for swap code events.
  void addSwapCodeListener(void Function(String code, DateTime? expiry, String reservationId) cb) =>
      _swapCodeListeners.add(cb);
  void removeSwapCodeListener(void Function(String code, DateTime? expiry, String reservationId) cb) =>
      _swapCodeListeners.remove(cb);

  /// Listen for swap completed events.
  void addSwapCompletedListener(VoidCallback cb) =>
      _swapCompletedListeners.add(cb);
  void removeSwapCompletedListener(VoidCallback cb) =>
      _swapCompletedListeners.remove(cb);

  /// Stream of slot updates.
  Stream<SlotUpdateEvent> get onSlotUpdate => _slotUpdateController.stream;

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
          _serverConfirmedConnection = true;
          _notifyConnected();
          // Re-subscribe to previously subscribed stations after reconnect
          for (final stationId in _subscribedStations.toList()) {
            _send({'type': 'subscribe', 'stationId': stationId});
          }
          break;
        case 'SUBSCRIBED':
          _notifyConnected();
          break;

        case 'SLOT_UPDATE':
          final slot = msg['slot'] as Map<String, dynamic>?;
          if (slot != null) {
            final event = SlotUpdateEvent.fromJson(slot);
            for (final cb in _slotUpdateListeners) {
              cb(event);
            }
            _slotUpdateController.add(event);
          }
          break;

        case 'SWAP_CODE':
          final code = msg['swapCode'] as String? ?? '';
          final expiryStr = msg['expiry'] as String?;
          final reservationId = msg['reservationId'] as String? ?? '';
          final expiry = expiryStr != null ? DateTime.tryParse(expiryStr) : null;
          for (final cb in _swapCodeListeners) {
            cb(code, expiry, reservationId);
          }
          break;

        case 'SWAP_COMPLETED':
          for (final cb in _swapCompletedListeners) {
            cb();
          }
          break;

        case 'ERROR':
          _notifyError((msg['message'] as String?) ?? 'Unknown error');
          break;
      }
    } catch (e) {
      debugPrint('[WS Admin] Failed to parse message: $e');
    }
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

  /// Dispose and clean up resources.
  void dispose() {
    disconnect();
    _slotUpdateController.close();
  }
}
