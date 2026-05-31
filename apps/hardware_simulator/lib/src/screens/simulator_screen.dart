import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_auth/shared_auth.dart';
import '../theme/simulator_theme.dart';
import '../providers/simulator_providers.dart';
import '../models/simulator_models.dart';
import '../services/simulator_websocket_service.dart';
import '../widgets/slot_widget.dart';
import '../widgets/swap_code_banner.dart';

class SimulatorScreen extends ConsumerStatefulWidget {
  const SimulatorScreen({super.key});

  @override
  ConsumerState<SimulatorScreen> createState() => _SimulatorScreenState();
}

class _SimulatorScreenState extends ConsumerState<SimulatorScreen> {
  bool _wsConnected = false;
  StreamSubscription? _slotUpdateSubscription;
  String? _lastSelectedStationId;

  SwapCodeEvent? _activeSwapCode;
  bool _showSwapSuccess = false;
  Timer? _swapSuccessTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupWebSocket();
    });
  }

  void _setupWebSocket() {
    final wsService = ref.read(wsServiceProvider);
    wsService.addConnectListener(_onWsConnected);
    wsService.addSwapCodeListener(_onSwapCodeReceived);
    wsService.addSwapCompletedListener(_onSwapCompleted);
  }

  void _onSwapCodeReceived(SwapCodeEvent event) {
    if (mounted) {
      setState(() {
        _activeSwapCode = event;
        _showSwapSuccess = false;
      });
    }
  }

  void _onSwapCompleted() {
    if (mounted) {
      setState(() {
        _showSwapSuccess = true;
        _activeSwapCode = null;
      });
      _swapSuccessTimer?.cancel();
      _swapSuccessTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() => _showSwapSuccess = false);
        }
      });
    }
  }

  void _onWsConnected() {
    if (mounted) {
      setState(() => _wsConnected = true);
    }
  }

  void _subscribeToStation(String stationId) {
    if (_lastSelectedStationId == stationId) return;

    _slotUpdateSubscription?.cancel();
    _lastSelectedStationId = stationId;

    final wsService = ref.read(wsServiceProvider);
    final wsBaseUrl = ref.read(wsBaseUrlProvider);
    if (!wsService.isConnected) {
      wsService.connect(wsBaseUrl);
    }
    wsService.subscribe(stationId);

    _slotUpdateSubscription = wsService.onSlotUpdate.listen((_) {
      if (mounted) {
        ref.invalidate(stationPilesProvider(stationId));
      }
    });
  }

  @override
  void dispose() {
    _slotUpdateSubscription?.cancel();
    _swapSuccessTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedStationId = ref.watch(selectedStationIdProvider);

    return Scaffold(
      backgroundColor: SimulatorTheme.backgroundDark,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.developer_board, color: SimulatorTheme.primaryTeal),
            const SizedBox(width: 12),
            const Text('Battery Swap Simulator'),
            const Spacer(),
            _buildConnectionStatus(),
            const SizedBox(width: 16),
            _buildRefreshButton(selectedStationId),
            const SizedBox(width: 8),
            _buildLogoutButton(),
          ],
        ),
        toolbarHeight: 64,
        backgroundColor: SimulatorTheme.surfaceDark,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: SimulatorTheme.cardDark,
            child: Row(
              children: [
                const Icon(Icons.location_on, size: 20, color: SimulatorTheme.textSecondary),
                const SizedBox(width: 8),
                const Text(
                  'Station:',
                  style: TextStyle(color: SimulatorTheme.textSecondary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ref.watch(batterySwapStationsProvider).when(
                    data: (stations) => _buildStationDropdown(stations, selectedStationId),
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Error: $e', style: const TextStyle(color: Colors.red)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _buildLegendBar(),
              Expanded(
                child: selectedStationId == null
                    ? _buildEmptyState()
                    : _buildPilesGrid(selectedStationId),
              ),
            ],
          ),
          if (_activeSwapCode != null)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.7),
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: SwapCodeBanner(
                      swapCodeEvent: _activeSwapCode!,
                      onDismiss: () {
                        setState(() => _activeSwapCode = null);
                      },
                    ),
                  ),
                ),
              ),
            ),
          if (_showSwapSuccess) _buildSwapSuccessDialog(),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _wsConnected
            ? SimulatorTheme.statusOnline.withOpacity(0.1)
            : SimulatorTheme.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _wsConnected ? SimulatorTheme.statusOnline : SimulatorTheme.textDisabled,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _wsConnected ? SimulatorTheme.statusOnline : SimulatorTheme.textDisabled,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _wsConnected ? 'Connected' : 'Disconnected',
            style: TextStyle(
              fontSize: 12,
              color: _wsConnected ? SimulatorTheme.statusOnline : SimulatorTheme.textDisabled,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefreshButton(String? selectedStationId) {
    return IconButton(
      icon: const Icon(Icons.refresh),
      onPressed: () {
        if (selectedStationId != null) {
          ref.invalidate(stationPilesProvider(selectedStationId));
        }
        ref.invalidate(batterySwapStationsProvider);
      },
      tooltip: 'Refresh',
    );
  }

  Widget _buildLogoutButton() {
    return IconButton(
      icon: const Icon(Icons.logout),
      onPressed: () async {
        await ref.read(authStateNotifierProvider.notifier).logout();
        if (mounted) context.go('/login');
      },
      tooltip: 'Logout',
    );
  }

  Widget _buildStationDropdown(List<SimulatorStationListItem> stations, String? selectedId) {
    if (stations.isEmpty) {
      return const Text('No battery swap stations available');
    }

    return DropdownButtonFormField<String>(
      value: selectedId,
      decoration: InputDecoration(
        filled: true,
        fillColor: SimulatorTheme.surfaceDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
      dropdownColor: SimulatorTheme.cardDark,
      items: stations.map((station) {
        return DropdownMenuItem(
          value: station.stationId,
          child: Text(
            station.name ?? station.stationId,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: SimulatorTheme.textPrimary),
          ),
        );
      }).toList(),
      onChanged: (value) {
        ref.read(selectedStationIdProvider.notifier).state = value;
        if (value != null) {
          _subscribeToStation(value);
        }
      },
    );
  }

  Widget _buildLegendBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: SimulatorTheme.surfaceDark,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildLegendItem(SimulatorTheme.statusAvailable, 'AVAILABLE'),
          _buildLegendItem(SimulatorTheme.statusCharging, 'CHARGING'),
          _buildLegendItem(SimulatorTheme.statusReserved, 'RESERVED'),
          _buildLegendItem(SimulatorTheme.statusOccupied, 'OCCUPIED'),
          _buildLegendItem(SimulatorTheme.statusSwappedOut, 'SWAPPED_OUT'),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            border: Border.all(color: color, width: 2),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: SimulatorTheme.textSecondary,
          ),
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
            Icons.developer_board,
            size: 80,
            color: SimulatorTheme.textDisabled,
          ),
          const SizedBox(height: 24),
          const Text(
            'Select a station to view simulator',
            style: TextStyle(
              fontSize: 18,
              color: SimulatorTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose a battery swap station from the dropdown above',
            style: TextStyle(
              fontSize: 14,
              color: SimulatorTheme.textDisabled,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPilesGrid(String stationId) {
    final pilesAsync = ref.watch(stationPilesProvider(stationId));

    return pilesAsync.when(
      data: (stationPiles) {
        if (stationPiles == null || stationPiles.piles.isEmpty) {
          return const Center(
            child: Text(
              'No piles available for this station',
              style: TextStyle(color: SimulatorTheme.textSecondary),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 900 ? 3 : (constraints.maxWidth > 600 ? 2 : 1);

              return GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.3,
                ),
                itemCount: stationPiles.piles.length,
                itemBuilder: (context, index) {
                  final pile = stationPiles.piles[index];
                  return _buildPileCard(pile);
                },
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Failed to load piles',
              style: TextStyle(color: Colors.red.shade300),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => ref.invalidate(stationPilesProvider(stationId)),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPileCard(SimulatorPileModel pile) {
    final pileStatusColor = SimulatorTheme.getPileStatusColor(pile.status);

    return Card(
      color: SimulatorTheme.cardDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: pileStatusColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      elevation: 4,
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
                    color: pileStatusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: pileStatusColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.layers,
                        size: 18,
                        color: pileStatusColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Pile ${pile.pileIndex + 1}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: pileStatusColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: pileStatusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    pile.status,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: pileStatusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
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
                  return SlotWidget(
                    slot: slot,
                    isReserved: slot.status.toUpperCase() == 'RESERVED',
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwapSuccessDialog() {
    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Card(
          color: SimulatorTheme.cardDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: SimulatorTheme.statusOnline.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle,
                          color: SimulatorTheme.statusOnline,
                          size: 80,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                const Text(
                  'Swap Successful!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: SimulatorTheme.statusOnline,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'The battery has been swapped successfully.',
                  style: TextStyle(
                    fontSize: 16,
                    color: SimulatorTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Closing in 5 seconds...',
                  style: TextStyle(
                    fontSize: 14,
                    color: SimulatorTheme.textDisabled,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
