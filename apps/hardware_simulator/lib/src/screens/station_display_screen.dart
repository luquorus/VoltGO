import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/simulator_theme.dart';
import '../providers/display_providers.dart';
import '../models/simulator_models.dart';
import '../widgets/slot_widget.dart';
import '../services/display_websocket_service.dart';

class StationDisplayScreen extends ConsumerStatefulWidget {
  const StationDisplayScreen({super.key});

  @override
  ConsumerState<StationDisplayScreen> createState() => _StationDisplayScreenState();
}

class _StationDisplayScreenState extends ConsumerState<StationDisplayScreen> {
  StreamSubscription? _wsConnectedSub;
  StreamSubscription? _slotUpdateSub;
  StreamSubscription? _swapCodeSub;
  StreamSubscription? _swapCompletedSub;
  StreamSubscription? _swapCancelledSub;
  bool _wsConnected = false;
  SimulatorStationPilesModel? _stationData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  void _init() {
    _setupWebSocket();
    _loadInitialData();

    // Listen to station selection changes to reconnect WS with device key
    ref.listenManual(displaySelectedStationIdProvider, (prev, next) {
      if (next != null) {
        _connectWebSocket(next);
        _loadStationData(next);
      }
    });
  }

  void _connectWebSocket(String stationId) {
    final ws = ref.read(displayWsServiceProvider);
    final deviceKeyAsync = ref.read(displayDeviceKeyProvider(stationId));
    final baseUrl = ref.read(publicBaseUrlProvider);
    final wsUrl = baseUrl
        .replaceFirst('http://', 'ws://')
        .replaceFirst('https://', 'wss://') + '/ws/display/battery-swap';

    deviceKeyAsync.whenData((deviceKey) {
      ws.connect(wsUrl, deviceKey: deviceKey);
      ws.subscribe(stationId);
    });

    // Also do polling fallback for active swap code
    _pollActiveSwapCode(stationId);
  }

  Timer? _swapCodePollTimer;

  void _pollActiveSwapCode(String stationId) {
    _swapCodePollTimer?.cancel();
    _pollAndShowSwapCode(stationId);
    _swapCodePollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _pollAndShowSwapCode(stationId);
    });
  }

  Future<void> _pollAndShowSwapCode(String stationId) async {
    final dio = ref.read(publicDioProvider);
    try {
      final response = await dio.get('/api/public/battery-swap/stations/$stationId/active-code');
      final data = response.data as Map<String, dynamic>;
      final code = data['swapCode'] as String?;
      if (code != null && code.isNotEmpty && mounted) {
        final event = DisplaySwapCodeEvent(
          swapCode: code,
          reservationId: data['reservationId'] as String? ?? '',
          deadlineAt: data['deadlineAt'] != null
              ? DateTime.tryParse(data['deadlineAt'] as String)
              : null,
        );
        ref.read(displayShownSwapCodeProvider.notifier).state = event;
      }
    } catch (_) {}
  }

  void _setupWebSocket() {
    final ws = ref.read(displayWsServiceProvider);
    ws.addConnectListener(_onWsConnected);
    ws.addSlotUpdateListener(_onSlotUpdate);
    _slotUpdateSub = ws.onSlotUpdate.listen(_onSlotUpdate);
    _swapCodeSub = ws.onSwapCode.listen(_onSwapCode);
    ws.addSwapCompletedListener(_onSwapCompleted);
    ws.addSwapCancelledListener(_onSwapCancelled);
  }

  void _onSwapCode(DisplaySwapCodeEvent event) {
    if (mounted) {
      ref.read(displayShownSwapCodeProvider.notifier).state = event;
    }
  }

  void _onSwapCompleted() {
    if (mounted) {
      ref.read(displayShownSwapCodeProvider.notifier).state = null;
    }
  }

  void _onSwapCancelled() {
    if (mounted) {
      ref.read(displayShownSwapCodeProvider.notifier).state = null;
    }
  }

  void _onWsConnected() {
    if (mounted) {
      setState(() => _wsConnected = true);
      final stationId = ref.read(displaySelectedStationIdProvider);
      if (stationId != null) {
        ref.read(displayWsServiceProvider).subscribe(stationId);
      }
    }
  }

  void _onSlotUpdate(DisplaySlotUpdateEvent event) {
    // Trigger a refresh of station data
    if (mounted) {
      ref.invalidate(displayStationPilesProvider(
          ref.read(displaySelectedStationIdProvider) ?? ''));
    }
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final dio = ref.read(publicDioProvider);
      final response = await dio.get('/api/public/battery-swap/stations');
      final list = response.data as List<dynamic>;
      if (list.isNotEmpty) {
        final first = SimulatorStationListItem.fromJson(list.first as Map<String, dynamic>);
        ref.read(displaySelectedStationIdProvider.notifier).state = first.stationId;
        await _loadStationData(first.stationId);
        _connectWebSocket(first.stationId);
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadStationData(String stationId) async {
    setState(() => _isLoading = true);
    try {
      final response = await ref.read(displayStationPilesProvider(stationId).future);
      setState(() {
        _stationData = response;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _onStationChanged(String? stationId) async {
    if (stationId == null) return;
    ref.read(displaySelectedStationIdProvider.notifier).state = stationId;
    _connectWebSocket(stationId);
    await _loadStationData(stationId);
  }

  @override
  void dispose() {
    _wsConnectedSub?.cancel();
    _slotUpdateSub?.cancel();
    _swapCodeSub?.cancel();
    _swapCompletedSub?.cancel();
    _swapCancelledSub?.cancel();
    _swapCodePollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stationsAsync = ref.watch(displayStationsProvider);
    final selectedId = ref.watch(displaySelectedStationIdProvider);
    final activeSwapCode = ref.watch(displayShownSwapCodeProvider);

    return Scaffold(
      backgroundColor: SimulatorTheme.backgroundDark,
      body: Stack(
        children: [
          Column(
            children: [
              // Header
              _buildHeader(),
              // Station selector
              _buildStationSelector(stationsAsync, selectedId),
              // Station info
              if (_stationData != null) _buildStationInfo(_stationData!),
              // Piles grid
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _stationData == null
                        ? _buildEmptyState()
                        : _buildPilesGrid(_stationData!),
              ),
            ],
          ),
          // Swap code banner overlay
          if (activeSwapCode != null)
            Positioned.fill(
              child: _SwapCodeBannerOverlay(
                event: activeSwapCode,
                onDismiss: () {
                  ref.read(displayShownSwapCodeProvider.notifier).state = null;
                },
                onExpired: () {
                  ref.read(displayShownSwapCodeProvider.notifier).state = null;
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 24,
        right: 24,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        color: SimulatorTheme.surfaceDark,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: SimulatorTheme.primaryTeal.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.battery_charging_full,
              color: SimulatorTheme.primaryTeal,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VoltGo Station Display',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Battery Swap Station Monitor',
                  style: TextStyle(
                    fontSize: 14,
                    color: SimulatorTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _wsConnected
                  ? SimulatorTheme.statusOnline.withOpacity(0.2)
                  : Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _wsConnected ? SimulatorTheme.statusOnline : Colors.red,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _wsConnected ? SimulatorTheme.statusOnline : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _wsConnected ? 'Live' : 'Offline',
                  style: TextStyle(
                    fontSize: 12,
                    color: _wsConnected ? SimulatorTheme.statusOnline : Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStationSelector(
      AsyncValue<List<SimulatorStationListItem>> stationsAsync, String? selectedId) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: SimulatorTheme.cardDark,
      child: Row(
        children: [
          const Icon(Icons.location_on, color: SimulatorTheme.textSecondary, size: 20),
          const SizedBox(width: 12),
          const Text(
            'Station:',
            style: TextStyle(color: SimulatorTheme.textSecondary, fontSize: 14),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: stationsAsync.when(
              data: (stations) {
                if (stations.isEmpty) {
                  return const Text(
                    'No stations available',
                    style: TextStyle(color: SimulatorTheme.textSecondary),
                  );
                }
                return DropdownButtonFormField<String>(
                  value: selectedId,
                  isExpanded: true,
                  dropdownColor: SimulatorTheme.cardDark,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: SimulatorTheme.surfaceDark,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                  items: stations.map((s) {
                    return DropdownMenuItem(
                      value: s.stationId,
                      child: Text(
                        s.name ?? s.stationId,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) => _onStationChanged(value),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error: $e', style: const TextStyle(color: Colors.red)),
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.refresh, color: SimulatorTheme.textSecondary),
            onPressed: () {
              final id = ref.read(displaySelectedStationIdProvider);
              if (id != null) {
                ref.invalidate(displayStationPilesProvider(id));
                _onStationChanged(id);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStationInfo(SimulatorStationPilesModel data) {
    int totalSlots = data.piles.fold(0, (sum, p) => sum + p.slots.length);
    int availableSlots = data.piles.fold(
        0, (sum, p) => sum + p.slots.where((s) => s.status == 'AVAILABLE').length);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      color: SimulatorTheme.surfaceDark,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(Icons.layers, '${data.piles.length}', 'Piles'),
          _buildStatItem(Icons.grid_view, '$totalSlots', 'Slots'),
          _buildStatItem(Icons.battery_full, '$availableSlots', 'Available'),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: SimulatorTheme.primaryTeal, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: SimulatorTheme.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.battery_unknown,
            size: 80,
            color: SimulatorTheme.textDisabled,
          ),
          const SizedBox(height: 16),
          Text(
            _error ?? 'Select a station to view',
            style: const TextStyle(
              fontSize: 18,
              color: SimulatorTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPilesGrid(SimulatorStationPilesModel data) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final crossCount = constraints.maxWidth > 1200
              ? 4
              : constraints.maxWidth > 800
                  ? 3
                  : constraints.maxWidth > 500
                      ? 2
                      : 1;
          return GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.2,
            ),
            itemCount: data.piles.length,
            itemBuilder: (context, index) {
              return _buildPileCard(data.piles[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildPileCard(SimulatorPileModel pile) {
    final statusColor = SimulatorTheme.getPileStatusColor(pile.status);
    final isActive = pile.status == 'ACTIVE';

    return Card(
      color: SimulatorTheme.cardDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isActive ? statusColor.withOpacity(0.5) : Colors.grey.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.layers, size: 18, color: statusColor),
                      const SizedBox(width: 8),
                      Text(
                        'Pile ${pile.pileIndex + 1}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    pile.status,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: pile.slots.length,
                itemBuilder: (context, index) {
                  final slot = pile.slots[index];
                  return _buildDisplaySlot(slot);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisplaySlot(SimulatorSlotModel slot) {
    final statusColor = SimulatorTheme.getSlotStatusColor(slot.status);
    final batteryIcon = SimulatorTheme.getSlotBatteryIcon(slot.status);

    return Container(
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor.withOpacity(0.5),
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(batteryIcon, color: statusColor, size: 22),
            const SizedBox(height: 4),
            Text(
              '${slot.batteryChargePercent}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                slot.status,
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwapCodeBannerOverlay extends StatefulWidget {
  final DisplaySwapCodeEvent event;
  final VoidCallback onDismiss;
  final VoidCallback? onExpired;

  const _SwapCodeBannerOverlay({
    required this.event,
    required this.onDismiss,
    this.onExpired,
  });

  @override
  State<_SwapCodeBannerOverlay> createState() => _SwapCodeBannerOverlayState();
}

class _SwapCodeBannerOverlayState extends State<_SwapCodeBannerOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  Duration _timeRemaining = Duration.zero;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _calculateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _calculateTime();
    });

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  void _calculateTime() {
    if (widget.event.deadlineAt != null) {
      final remaining = widget.event.deadlineAt!.difference(DateTime.now());
      setState(() {
        _timeRemaining = remaining.isNegative ? Duration.zero : remaining;
      });
      if (remaining.isNegative) {
        _timer?.cancel();
        widget.onExpired?.call();
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _glowController.dispose();
    super.dispose();
  }

  String get _formattedTime {
    final m = _timeRemaining.inMinutes;
    final s = _timeRemaining.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatCode(String code) {
    if (code.length == 4) return '${code[0]}  ${code[1]}  ${code[2]}  ${code[3]}';
    return code;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          color: Colors.black.withOpacity(0.85),
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(24),
              constraints: const BoxConstraints(maxWidth: 600),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    SimulatorTheme.statusReserved.withOpacity(0.2 * _glowAnimation.value),
                    SimulatorTheme.primaryTeal.withOpacity(0.1 * _glowAnimation.value),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: SimulatorTheme.statusReserved.withOpacity(_glowAnimation.value),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: SimulatorTheme.statusReserved.withOpacity(0.4 * _glowAnimation.value),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.swap_horiz,
                            color: SimulatorTheme.statusReserved,
                            size: 40,
                          ),
                          const SizedBox(width: 16),
                          const Text(
                            'SWAP CODE',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 4,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: SimulatorTheme.statusReserved.withOpacity(0.6),
                            width: 2,
                          ),
                        ),
                        child: Text(
                          _formatCode(widget.event.swapCode),
                          style: const TextStyle(
                            fontSize: 80,
                            fontWeight: FontWeight.bold,
                            color: SimulatorTheme.statusReserved,
                            letterSpacing: 20,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.timer,
                            color: _timeRemaining.inSeconds < 30 ? Colors.red : SimulatorTheme.accentAmber,
                            size: 28,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Expires in $_formattedTime',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: _timeRemaining.inSeconds < 30
                                  ? Colors.red
                                  : SimulatorTheme.accentAmber,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.withOpacity(0.4)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.phone_android, color: Colors.blue, size: 28),
                            SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                'User will enter this code on their app',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
