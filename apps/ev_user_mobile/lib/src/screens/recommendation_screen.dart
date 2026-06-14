import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:shared_network/shared_network.dart';
import 'package:shared_auth/shared_auth.dart';
import '../providers/station_providers.dart';
import '../providers/routing_provider.dart';
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

    final batteryCapacity = double.tryParse(_batteryCapacityController.text) ?? 60;
    final targetPercent = int.tryParse(_targetPercentController.text) ?? 80;
    final consumption = double.tryParse(_consumptionController.text) ?? 0.18;
    final maxCharge = double.tryParse(_vehicleMaxChargeKwController.text) ?? 120;

    // Persist vehicle settings for routing — will be used on next route calculation
    final settings = VehicleSettings(
      batteryPercent: _batteryPercent.round(),
      vehicleRangeKm: 300, // vehicleRangeKm is estimated; use default
      batteryCapacityKwh: batteryCapacity,
      vehicleMaxChargeKw: maxCharge,
      consumptionKwhPerKm: consumption,
    );
    ref.read(routingProvider.notifier).setVehicleSettings(settings);

    final params = RecommendationParams(
      lat: _currentLocation!.latitude,
      lng: _currentLocation!.longitude,
      radiusKm: _radiusKm,
      batteryPercent: _batteryPercent.round(),
      batteryCapacityKwh: batteryCapacity,
      targetPercent: targetPercent,
      consumptionKwhPerKm: consumption,
      averageSpeedKmph: double.tryParse(_averageSpeedController.text),
      vehicleMaxChargeKw: maxCharge,
      limit: 10,
    );

    ref.read(recommendationProvider.notifier).getRecommendations(params);
    ref
        .read(personalizedRecommendationProvider.notifier)
        .getPersonalizedRecommendations(params);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(recommendationProvider);
    final personalized = ref.watch(personalizedRecommendationProvider);

    return MainScaffold(
      showBottomNav: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Find optimal stations'),
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
                    state.isLoading ? 'Searching...' : 'Get recommendations',
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
                if (personalized.response != null && !personalized.isLoading) ...[
                  const SizedBox(height: 20),
                  _buildPersonalizedResults(context, theme, personalized.response!),
                ],
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
                  'Vehicle information',
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
                    'Current battery: ${_batteryPercent.round()}%',
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
                labelText: 'Battery capacity (kWh)',
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
                  return 'Please enter battery capacity';
                }
                final num = double.tryParse(value);
                if (num == null || num <= 0) {
                  return 'Battery capacity must be > 0';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Target Percent
            TextFormField(
              controller: _targetPercentController,
              decoration: InputDecoration(
                labelText: 'Target charge (%)',
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
                  return 'Please enter target charge';
                }
                final num = int.tryParse(value);
                if (num == null || num < 0 || num > 100) {
                  return 'Target charge must be between 0-100%';
                }
                if (num < _batteryPercent.round()) {
                  return 'Target charge must be >= current battery level';
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
                    'Advanced settings',
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
                    labelText: 'Max charging power (kW)',
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
                    labelText: 'Average speed (km/h)',
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
                    labelText: 'Consumption (kWh/km)',
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
                  'Search range',
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
                    'Radius: ${_radiusKm.round()} km',
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
                      'Getting location...',
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
                    'Error',
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
                  'No stations found within ${_radiusKm.round()} km',
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
                'Results (${results.length}) - Sorted by total time',
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

  Widget _buildPersonalizedResults(
      BuildContext context, ThemeData theme, Map<String, dynamic> response) {
    final results = (response['results'] as List<dynamic>? ?? [])
        .map((e) => e as Map<String, dynamic>)
        .toList();
    if (results.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            FaIcon(FontAwesomeIcons.wandMagicSparkles,
                color: theme.colorScheme.primary, size: 18),
            const SizedBox(width: 8),
            Text(
              'Personalized suggestions (AI)',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...results.take(3).map((item) {
          final stationId = item['stationId']?.toString() ?? '';
          final name = item['name']?.toString() ?? 'Unnamed station';
          final score = item['score']?.toString() ?? '0';
          final reasons = (item['reasons'] as List<dynamic>? ?? [])
              .map((e) => e.toString())
              .toList();
          return Card(
            child: ListTile(
              title: Text(name),
              subtitle: Text(reasons.isNotEmpty ? reasons.first : ''),
              trailing: Text('Score $score'),
              onTap: stationId.isEmpty ? null : () => context.push('/stations/$stationId'),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildResultCard(
      BuildContext context, ThemeData theme, Map<String, dynamic> result) {
    final name = result['name'] as String? ?? 'Unnamed station';
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
                      'Total: $totalMinutes min',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Breakdown — responsive: column on narrow screens, row on wide
              MediaQuery.of(context).size.width > 480
                  ? _buildBreakdownRow(theme, travelMinutes, chargeMinutes)
                  : _buildBreakdownColumn(theme, travelMinutes, chargeMinutes),
              const SizedBox(height: 12),
              // Actions — use Wrap so buttons flow on narrow screens
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: MediaQuery.of(context).size.width > 600
                        ? null
                        : double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/stations/$stationId'),
                      icon: const FaIcon(FontAwesomeIcons.circleInfo, size: 14),
                      label: const Text('View details'),
                    ),
                  ),
                  SizedBox(
                    width: MediaQuery.of(context).size.width > 600
                        ? null
                        : double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => context.push(
                        '/bookings/create?stationId=$stationId&stationName=${Uri.encodeComponent(name)}',
                      ),
                      icon: const FaIcon(FontAwesomeIcons.calendarCheck, size: 14),
                      label: const Text('Book port'),
                    ),
                  ),
                  SizedBox(
                    width: MediaQuery.of(context).size.width > 600
                        ? null
                        : double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showSmartTimeSuggestions(context, result),
                      icon: const FaIcon(FontAwesomeIcons.clockRotateLeft, size: 14),
                      label: const Text('Suggested times'),
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

  Widget _buildBreakdownRow(ThemeData theme, int travelMinutes, int chargeMinutes) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildBreakdownItem(theme, 'Travel', '$travelMinutes min', FontAwesomeIcons.car),
          Container(
            width: 1,
            height: 60,
            color: theme.colorScheme.outline.withOpacity(0.3),
          ),
          _buildBreakdownItem(theme, 'Charging', '$chargeMinutes min', FontAwesomeIcons.bolt),
        ],
      ),
    );
  }

  Widget _buildBreakdownColumn(ThemeData theme, int travelMinutes, int chargeMinutes) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildBreakdownItem(theme, 'Travel', '$travelMinutes min', FontAwesomeIcons.car),
          SizedBox(height: 8),
          Container(
            height: 1,
            color: theme.colorScheme.outline.withOpacity(0.3),
          ),
          SizedBox(height: 8),
          _buildBreakdownItem(theme, 'Charging', '$chargeMinutes min', FontAwesomeIcons.bolt),
        ],
      ),
    );
  }

  Widget _buildBreakdownItem(
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

  Future<void> _showSmartTimeSuggestions(
      BuildContext context, Map<String, dynamic> result) async {
    final stationId = result['stationId'] as String? ?? '';
    if (stationId.isEmpty) return;
    final estimate = result['estimate'] as Map<String, dynamic>? ?? {};
    final distanceKm = (estimate['distanceKm'] as num?)?.toDouble() ?? 1.0;
    final targetPercent = int.tryParse(_targetPercentController.text) ?? 80;
    final batteryCapacity =
        double.tryParse(_batteryCapacityController.text) ?? 60.0;

    try {
      final response =
          await ref.read(stationRepositoryProvider).getSmartTimeSuggestions(
                stationId: stationId,
                distanceKm: distanceKm,
                batteryPercent: _batteryPercent.round(),
                targetPercent: targetPercent,
                batteryCapacityKwh: batteryCapacity,
                averageSpeedKmph:
                    double.tryParse(_averageSpeedController.text),
              );
      if (!context.mounted) return;
      final suggestions = (response['suggestions'] as List<dynamic>? ?? [])
          .map((e) => e as Map<String, dynamic>)
          .toList();
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Optimal charging slots'),
          content: SizedBox(
            width: 460,
            child: suggestions.isEmpty
                ? const Text('No suitable suggestions right now.')
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: suggestions.map((item) {
                      final slotStart = item['slotStart']?.toString() ?? '';
                      final score = item['score']?.toString() ?? '';
                      final load = item['predictedLoad']?.toString() ?? '';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          '$slotStart\nScore: $score • Predicted load: $load',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      );
                    }).toList(),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      AppToast.showError(
          context, 'Could not load suggestions: ${formatApiError(e)}');
    }
  }
}


