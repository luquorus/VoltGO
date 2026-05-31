import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

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

class SwapCodeEvent {
  final String swapCode;
  final DateTime? deadlineAt;
  final String? reservationId;
  final String? stationId;
  final String? pileId;
  final String? slotId;

  SwapCodeEvent({
    required this.swapCode,
    this.deadlineAt,
    this.reservationId,
    this.stationId,
    this.pileId,
    this.slotId,
  });

  factory SwapCodeEvent.fromJson(Map<String, dynamic> json) {
    return SwapCodeEvent(
      swapCode: json['swapCode'] as String? ?? '',
      deadlineAt: json['deadlineAt'] != null
          ? DateTime.tryParse(json['deadlineAt'] as String)
          : null,
      reservationId: json['reservationId'] as String?,
      stationId: json['stationId'] as String?,
      pileId: json['pileId'] as String?,
      slotId: json['slotId'] as String?,
    );
  }
}

class SimulatorWebSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  bool _connecting = false;
  final Set<String> _subscribedStations = {};
  final Set<VoidCallback> _connectListeners = {};
  final Set<void Function(String error)> _errorListeners = {};
  final Set<void Function(SlotUpdateEvent)> _slotUpdateListeners = {};
  final Set<void Function(SwapCodeEvent)> _swapCodeListeners = {};
  final Set<VoidCallback> _swapCompletedListeners = {};
  final Set<VoidCallback> _swapCancelledListeners = {};
  final StreamController<SlotUpdateEvent> _slotUpdateController =
      StreamController<SlotUpdateEvent>.broadcast();

  String? _wsBaseUrl;

  SimulatorWebSocketService();

  bool get isConnected => _channel != null && _serverConfirmedConnection;
  bool _serverConfirmedConnection = false;

  Future<void> connect(String wsBaseUrl) async {
    if (_connecting || isConnected) return;
    _connecting = true;
    _wsBaseUrl = wsBaseUrl;

    try {
      final uri = Uri.parse('$wsBaseUrl/ws/display/battery-swap');
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
    } catch (e) {
      _connecting = false;
      _notifyError(e.toString());
      _scheduleReconnect();
    }
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _subscribedStations.clear();
    _slotUpdateListeners.clear();
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

  void subscribe(String stationId) {
    _subscribedStations.add(stationId);
    _send({'type': 'subscribe', 'stationId': stationId});
  }

  void unsubscribe(String stationId) {
    _subscribedStations.remove(stationId);
    _send({'type': 'unsubscribe', 'stationId': stationId});
  }

  void addConnectListener(VoidCallback cb) => _connectListeners.add(cb);
  void removeConnectListener(VoidCallback cb) => _connectListeners.remove(cb);

  void addErrorListener(void Function(String error) cb) =>
      _errorListeners.add(cb);
  void removeErrorListener(void Function(String error) cb) =>
      _errorListeners.remove(cb);

  void addSlotUpdateListener(void Function(SlotUpdateEvent) cb) =>
      _slotUpdateListeners.add(cb);
  void removeSlotUpdateListener(void Function(SlotUpdateEvent) cb) =>
      _slotUpdateListeners.remove(cb);

  void addSwapCodeListener(void Function(SwapCodeEvent) cb) =>
      _swapCodeListeners.add(cb);
  void removeSwapCodeListener(void Function(SwapCodeEvent) cb) =>
      _swapCodeListeners.remove(cb);

  void addSwapCompletedListener(VoidCallback cb) =>
      _swapCompletedListeners.add(cb);
  void removeSwapCompletedListener(VoidCallback cb) =>
      _swapCompletedListeners.remove(cb);

  void addSwapCancelledListener(VoidCallback cb) =>
      _swapCancelledListeners.add(cb);
  void removeSwapCancelledListener(VoidCallback cb) =>
      _swapCancelledListeners.remove(cb);

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
          final event = SwapCodeEvent.fromJson(msg);
          for (final cb in _swapCodeListeners) {
            cb(event);
          }
          break;
        case 'SWAP_COMPLETED':
          for (final cb in _swapCompletedListeners) {
            cb();
          }
          break;
        case 'SWAP_CANCELLED':
          for (final cb in _swapCancelledListeners) {
            cb();
          }
          break;
        case 'ERROR':
          _notifyError((msg['message'] as String?) ?? 'Unknown error');
          break;
      }
    } catch (e) {
      debugPrint('[DisplayWS] Failed to parse message: $e');
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

  void dispose() {
    disconnect();
    _slotUpdateController.close();
  }
}
