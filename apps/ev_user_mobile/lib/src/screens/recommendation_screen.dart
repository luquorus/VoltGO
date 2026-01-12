import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:shared_network/shared_network.dart';
import '../providers/station_providers.dart';
import '../widgets/main_scaffold.dart';

/// Recommendation Screen - Find optimal charging stations
class RecommendationScreen extends ConsumerStatefulWidget {
  const RecommendationScreen({super.key});

  @override
  ConsumerState<RecommendationScreen> createState() => _RecommendationScreenState();
}

class _RecommendationScreenState extends ConsumerState<RecommendationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _batteryCapacityController = TextEditingController(text: '60');
  final _targetPercentController = TextEditingController(text: '80');
  final _vehicleMaxChargeKwController = TextEditingController(text: '120');
  final _averageSpeedController = TextEditingController(text: '30');
  final _consumptionController = TextEditingController(text: '0.18');

  double _batteryPercent = 25.0;
  double _radiusKm = 15.0;
  bool _showAdvanced = false;
  LatLng? _currentLocation;

  @override
  void initState() {
    super.initState();
    _requestLocation();
  }

  @override
  void dispose() {
    _batteryCapacityController.dispose();
    _targetPercentController.dispose();
    _vehicleMaxChargeKwController.dispose();
    _averageSpeedController.dispose();
    _consumptionController.dispose();
    super.dispose();
  }

  Future<void> _requestLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        if (mounted) {
          AppToast.showError(context, 'Location permission required');
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, 'Failed to get location: $e');
      }
    }
  }

  void _onSearch() {
    if (!_formKey.currentState!.validate()) return;
    if (_currentLocation == null) {
      AppToast.showError(context, 'Please wait for location');
      return;
    }

    final params = RecommendationParams(
      lat: _currentLocation!.latitude,
      lng: _currentLocation!.longitude,
      radiusKm: _radiusKm,
      batteryPercent: _batteryPercent.round(),
      batteryCapacityKwh: double.parse(_batteryCapacityController.text),
      targetPercent: int.tryParse(_targetPercentController.text),
      consumptionKwhPerKm: double.tryParse(_consumptionController.text),
      averageSpeedKmph: double.tryParse(_averageSpeedController.text),
      vehicleMaxChargeKw: double.tryParse(_vehicleMaxChargeKwController.text),
      limit: 10,
    );

    ref.read(recommendationProvider.notifier).getRecommendations(params);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(recommendationProvider);

    return MainScaffold(
      showBottomNav: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tìm trạm tối ưu'),
          leading: IconButton(
            icon: const FaIcon(FontAwesomeIcons.xmark),
            onPressed: () => context.pop(),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Vehicle Info Card
                _buildVehicleInfoCard(context, theme),
                const SizedBox(height: 16),

                // Search Range Card
                _buildSearchRangeCard(context, theme),
                const SizedBox(height: 16),

                // Search Button
                ElevatedButton.icon(
                  onPressed: state.isLoading ? null : _onSearch,
                  icon: state.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const FaIcon(FontAwesomeIcons.magnifyingGlass, size: 18),
                  label: Text(
                    state.isLoading ? 'Đang tìm...' : 'Tính gợi ý',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Results
                if (state.error != null) _buildError(context, theme, state.error!),
                if (state.isLoading && state.response == null)
                  const Center(child: LoadingState()),
                if (state.response != null && !state.isLoading)
                  _buildResults(context, theme, state),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleInfoCard(BuildContext context, ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                FaIcon(
                  FontAwesomeIcons.car,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'Thông tin xe',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Battery Percent
            Row(
              children: [
                FaIcon(
                  FontAwesomeIcons.batteryHalf,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pin hiện tại: ${_batteryPercent.round()}%',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Slider(
              value: _batteryPercent,
              min: 0,
              max: 100,
              divisions: 100,
              label: '${_batteryPercent.round()}%',
              onChanged: (value) => setState(() => _batteryPercent = value),
            ),
            const SizedBox(height: 20),
            // Battery Capacity
            TextFormField(
              controller: _batteryCapacityController,
              decoration: InputDecoration(
                labelText: 'Dung tích pin (kWh)',
                hintText: '60',
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: FaIcon(
                    FontAwesomeIcons.batteryThreeQuarters,
                    size: 20,
                  ),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: theme.colorScheme.surface,
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Vui lòng nhập dung tích pin';
                }
                final num = double.tryParse(value);
                if (num == null || num <= 0) {
                  return 'Dung tích pin phải > 0';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Target Percent
            TextFormField(
              controller: _targetPercentController,
              decoration: InputDecoration(
                labelText: 'Mục tiêu sạc (%)',
                hintText: '80',
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: FaIcon(
                    FontAwesomeIcons.flagCheckered,
                    size: 20,
                  ),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: theme.colorScheme.surface,
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Vui lòng nhập mục tiêu sạc';
                }
                final num = int.tryParse(value);
                if (num == null || num < 0 || num > 100) {
                  return 'Mục tiêu sạc phải từ 0-100%';
                }
                if (num < _batteryPercent.round()) {
                  return 'Mục tiêu sạc phải >= pin hiện tại';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Advanced Settings
            ExpansionTile(
              title: Row(
                children: [
                  FaIcon(
                    FontAwesomeIcons.gear,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Cài đặt nâng cao',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              trailing: FaIcon(
                _showAdvanced
                    ? FontAwesomeIcons.chevronUp
                    : FontAwesomeIcons.chevronDown,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              initiallyExpanded: _showAdvanced,
              onExpansionChanged: (expanded) =>
                  setState(() => _showAdvanced = expanded),
              children: [
                const SizedBox(height: 8),
                TextFormField(
                  controller: _vehicleMaxChargeKwController,
                  decoration: InputDecoration(
                    labelText: 'Công suất sạc tối đa (kW)',
                    hintText: '120',
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: FaIcon(
                        FontAwesomeIcons.bolt,
                        size: 20,
                      ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surface,
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _averageSpeedController,
                  decoration: InputDecoration(
                    labelText: 'Tốc độ trung bình (km/h)',
                    hintText: '30',
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: FaIcon(
                        FontAwesomeIcons.gauge,
                        size: 20,
                      ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surface,
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _consumptionController,
                  decoration: InputDecoration(
                    labelText: 'Tiêu hao (kWh/km)',
                    hintText: '0.18',
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: FaIcon(
                        FontAwesomeIcons.droplet,
                        size: 20,
                      ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surface,
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchRangeCard(BuildContext context, ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                FaIcon(
                  FontAwesomeIcons.locationCrosshairs,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'Phạm vi tìm',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                FaIcon(
                  FontAwesomeIcons.circleDot,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Bán kính: ${_radiusKm.round()} km',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Slider(
              value: _radiusKm,
              min: 5,
              max: 50,
              divisions: 9,
              label: '${_radiusKm.round()} km',
              onChanged: (value) => setState(() => _radiusKm = value),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [5, 10, 15, 20, 30, 50].map((km) {
                return ChoiceChip(
                  label: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text('$km km'),
                  ),
                  selected: _radiusKm == km,
                  onSelected: (selected) {
                    if (selected) setState(() => _radiusKm = km.toDouble());
                  },
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                );
              }).toList(),
            ),
            if (_currentLocation == null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Đang lấy vị trí...',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, ThemeData theme, ApiError error) {
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FaIcon(
              FontAwesomeIcons.triangleExclamation,
              color: theme.colorScheme.onErrorContainer,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lỗi',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    error.message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(
      BuildContext context, ThemeData theme, RecommendationState state) {
    final results = state.results;

    if (results.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              children: [
                FaIcon(FontAwesomeIcons.magnifyingGlass,
                    size: 48, color: theme.colorScheme.outline),
                const SizedBox(height: 16),
                Text(
                  'Không tìm thấy trạm trong bán kính ${_radiusKm.round()} km',
                  style: theme.textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            FaIcon(
              FontAwesomeIcons.list,
              color: theme.colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Kết quả (${results.length}) - Sắp xếp theo tổng thời gian',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...results.map((result) => _buildResultCard(context, theme, result)),
      ],
    );
  }

  Widget _buildResultCard(
      BuildContext context, ThemeData theme, Map<String, dynamic> result) {
    final name = result['name'] as String? ?? 'Unknown';
    final address = result['address'] as String? ?? '';
    final distanceKm = (result['estimate'] as Map<String, dynamic>?)?['distanceKm'] as double? ?? 0.0;
    final travelMinutes = (result['estimate'] as Map<String, dynamic>?)?['travelMinutes'] as int? ?? 0;
    final chargeMinutes = (result['estimate'] as Map<String, dynamic>?)?['chargeMinutes'] as int? ?? 0;
    final totalMinutes = (result['estimate'] as Map<String, dynamic>?)?['totalMinutes'] as int? ?? 0;
    final chosenPort = result['chosenPort'] as Map<String, dynamic>?;
    final powerType = chosenPort?['powerType'] as String? ?? 'DC';
    final powerKw = chosenPort?['powerKw'] as num?;
    final effectiveKw = chosenPort?['assumedEffectiveKw'] as double?;
    final stationId = result['stationId'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/stations/$stationId'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Name + Distance
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      FaIcon(
                        FontAwesomeIcons.locationDot,
                        size: 14,
                        color: const Color(0xFF4A5568),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${distanceKm.toStringAsFixed(1)} km',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF4A5568),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Port Info
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    FaIcon(
                      powerType == 'DC'
                          ? FontAwesomeIcons.bolt
                          : FontAwesomeIcons.plug,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        powerKw != null
                            ? '$powerType ${powerKw.toStringAsFixed(0)}kW (effective ${effectiveKw?.toStringAsFixed(0) ?? 'N/A'}kW)'
                            : '$powerType (effective ${effectiveKw?.toStringAsFixed(0) ?? 'N/A'}kW)',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Total Time Highlight
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FaIcon(
                      FontAwesomeIcons.clock,
                      color: theme.colorScheme.onPrimaryContainer,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Tổng: $totalMinutes phút',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Breakdown
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildBreakdownItem(
                      context,
                      theme,
                      'Di chuyển',
                      '$travelMinutes phút',
                      FontAwesomeIcons.car,
                    ),
                    Container(
                      width: 1,
                      height: 60,
                      color: theme.colorScheme.outline.withOpacity(0.3),
                    ),
                    _buildBreakdownItem(
                      context,
                      theme,
                      'Sạc',
                      '$chargeMinutes phút',
                      FontAwesomeIcons.bolt,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/stations/$stationId'),
                      icon: const FaIcon(FontAwesomeIcons.circleInfo, size: 14),
                      label: const Text('Xem chi tiết'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => context.push(
                        '/bookings/create?stationId=$stationId&stationName=${Uri.encodeComponent(name)}',
                      ),
                      icon: const FaIcon(FontAwesomeIcons.calendarCheck, size: 14),
                      label: const Text('Book cổng'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBreakdownItem(
    BuildContext context,
    ThemeData theme,
    String label,
    String value,
    IconData icon,
  ) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(
            icon,
            size: 24,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: const Color(0xFF4A5568),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}


