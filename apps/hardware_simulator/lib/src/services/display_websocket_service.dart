import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class DisplaySlotUpdateEvent {
  final String slotId;
  final int slotIndex;
  final int batteryChargePercent;
  final String status;
  final DateTime? estimatedFullAt;

  DisplaySlotUpdateEvent({
    required this.slotId,
    required this.slotIndex,
    required this.batteryChargePercent,
    required this.status,
    this.estimatedFullAt,
  });

  factory DisplaySlotUpdateEvent.fromJson(Map<String, dynamic> json) {
    return DisplaySlotUpdateEvent(
      slotId: json['slotId'] as String? ?? '',
      slotIndex: (json['slotIndex'] as num?)?.toInt() ?? 0,
      batteryChargePercent: (json['batteryChargePercent'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'AVAILABLE',
      estimatedFullAt: json['estimatedFullAt'] != null
          ? DateTime.tryParse(json['estimatedFullAt'] as String)
          : null,
    );
  }
}

class DisplaySwapCodeEvent {
  final String swapCode;
  final DateTime? deadlineAt;
  final String reservationId;
  final String? stationId;
  final String? pileId;
  final String? slotId;

  DisplaySwapCodeEvent({
    required this.swapCode,
    this.deadlineAt,
    required this.reservationId,
    this.stationId,
    this.pileId,
    this.slotId,
  });

  factory DisplaySwapCodeEvent.fromJson(Map<String, dynamic> json) {
    return DisplaySwapCodeEvent(
      swapCode: json['swapCode'] as String? ?? '',
      deadlineAt: json['deadlineAt'] != null
          ? DateTime.tryParse(json['deadlineAt'] as String)
          : null,
      reservationId: json['reservationId'] as String? ?? '',
      stationId: json['stationId'] as String?,
      pileId: json['pileId'] as String?,
      slotId: json['slotId'] as String?,
    );
  }
}

class DisplayWebSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  bool _serverConfirmedConnection = false;
  String? _wsBaseUrl;
  final Set<String> _subscribedStations = {};
  final Set<VoidCallback> _connectListeners = {};
  final Set<void Function(DisplaySlotUpdateEvent)> _slotUpdateListeners = {};
  final Set<void Function(DisplaySwapCodeEvent)> _swapCodeListeners = {};
  final Set<VoidCallback> _swapCompletedListeners = {};
  final StreamController<DisplaySlotUpdateEvent> _slotUpdateController =
      StreamController<DisplaySlotUpdateEvent>.broadcast();
  final StreamController<DisplaySwapCodeEvent> _swapCodeController =
      StreamController<DisplaySwapCodeEvent>.broadcast();

  bool get isConnected => _channel != null && _serverConfirmedConnection;
  Stream<DisplaySlotUpdateEvent> get onSlotUpdate => _slotUpdateController.stream;
  Stream<DisplaySwapCodeEvent> get onSwapCode => _swapCodeController.stream;

  Future<void> connect(String wsBaseUrl, {String? deviceKey}) async {
    String url = wsBaseUrl;
    if (deviceKey != null && deviceKey.isNotEmpty) {
      url = '$wsBaseUrl?deviceKey=$deviceKey';
    }

    _wsBaseUrl = url;
    _doConnect();
  }

  void _doConnect() {
    _channel?.sink.close();
    _subscription?.cancel();
    _serverConfirmedConnection = false;

    try {
      final uri = Uri.parse(_wsBaseUrl!);
      _channel = WebSocketChannel.connect(uri);

      _subscription = _channel!.stream.listen(
        _handleMessage,
        onError: (error) {
          _serverConfirmedConnection = false;
          _scheduleReconnect();
        },
        onDone: () {
          _serverConfirmedConnection = false;
          _scheduleReconnect();
        },
      );
    } catch (e) {
      debugPrint('[DisplayWS] Connection error: $e');
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (_wsBaseUrl != null) _doConnect();
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

  void addSlotUpdateListener(void Function(DisplaySlotUpdateEvent) cb) =>
      _slotUpdateListeners.add(cb);
  void removeSlotUpdateListener(void Function(DisplaySlotUpdateEvent) cb) =>
      _slotUpdateListeners.remove(cb);

  void addSwapCodeListener(void Function(DisplaySwapCodeEvent) cb) =>
      _swapCodeListeners.add(cb);
  void removeSwapCodeListener(void Function(DisplaySwapCodeEvent) cb) =>
      _swapCodeListeners.remove(cb);

  void addSwapCompletedListener(VoidCallback cb) =>
      _swapCompletedListeners.add(cb);
  void removeSwapCompletedListener(VoidCallback cb) =>
      _swapCompletedListeners.remove(cb);

  void _send(Map<String, dynamic> data) {
    if (_channel != null && _serverConfirmedConnection) {
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
          for (final cb in _connectListeners) cb();
          for (final stationId in _subscribedStations.toList()) {
            _send({'type': 'subscribe', 'stationId': stationId});
          }
          break;
        case 'SUBSCRIBED':
          break;
        case 'SLOT_UPDATE':
          final slot = msg['slot'] as Map<String, dynamic>?;
          if (slot != null) {
            final event = DisplaySlotUpdateEvent.fromJson(slot);
            for (final cb in _slotUpdateListeners) cb(event);
            _slotUpdateController.add(event);
          }
          break;
        case 'SWAP_CODE':
          final event = DisplaySwapCodeEvent.fromJson(msg as Map<String, dynamic>);
          for (final cb in _swapCodeListeners) cb(event);
          _swapCodeController.add(event);
          break;
        case 'SWAP_COMPLETED':
          for (final cb in _swapCompletedListeners) cb();
          break;
      }
    } catch (e) {
      debugPrint('[DisplayWS] Failed to parse message: $e');
    }
  }

  void dispose() {
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _slotUpdateController.close();
    _swapCodeController.close();
  }
}
