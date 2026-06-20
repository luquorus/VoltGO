import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_ui/shared_ui.dart';
import '../models/battery_swap_models.dart';

/// Compact station card for the home map bottom sheet.
/// Shows only the most important information: name, address, distance,
/// availability, power type, trust score, and primary CTA.
class CompactStationCard extends StatelessWidget {
  final String stationId;
  final String name;
  final String? address;
  final int trustScore;
  final int totalPorts;
  final int availablePorts;
  final double maxPowerKw;
  final int dcPorts;
  final int acPorts;
  final bool supportsBatterySwap;
  final int totalPiles;
  final int totalSlots;
  final int availableBatteries;
  final double? distanceKm;
  final bool isSelected;
  final VoidCallback onTap;

  const CompactStationCard({
    super.key,
    required this.stationId,
    required this.name,
    this.address,
    this.trustScore = 0,
    this.totalPorts = 0,
    this.availablePorts = 0,
    this.maxPowerKw = 0,
    this.dcPorts = 0,
    this.acPorts = 0,
    this.supportsBatterySwap = false,
    this.totalPiles = 0,
    this.totalSlots = 0,
    this.availableBatteries = 0,
    this.distanceKm,
    this.isSelected = false,
    required this.onTap,
  });

  bool get _isBatterySwapOnly => supportsBatterySwap && totalPorts == 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: isSelected ? 4 : 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _isBatterySwapOnly
                      ? const Color(0xFF00695C).withOpacity(0.1)
                      : Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: FaIcon(
                    _isBatterySwapOnly
                        ? FontAwesomeIcons.batteryFull
                        : FontAwesomeIcons.bolt,
                    color: _isBatterySwapOnly
                        ? const Color(0xFF00695C)
                        : Colors.green,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Middle: info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name + distance
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (distanceKm != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            '${distanceKm!.toStringAsFixed(1)} km',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    // Address
                    if (address != null && address!.isNotEmpty) ...[
                      Text(
                        address!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                    ],
                    // Badges row (at most 3)
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: _buildBadges(theme),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildBadges(ThemeData theme) {
    final badges = <Widget>[];

    // Trust score
    if (trustScore > 0) {
      badges.add(_MiniBadge(
        label: trustScore >= 80
            ? 'Trust $trustScore'
            : trustScore >= 60
                ? 'Trust $trustScore'
                : 'Trust $trustScore',
        color: trustScore >= 80
            ? Colors.green
            : trustScore >= 60
                ? Colors.lightGreen
                : Colors.orange,
      ));
    }

    if (badges.length >= 3) return badges.take(3).toList();

    if (_isBatterySwapOnly) {
      // Battery swap only station
      badges.add(_MiniBadge(
        label: '$totalPiles piles × ${totalSlots ~/ (totalPiles > 0 ? totalPiles : 1)} slots',
        color: const Color(0xFF00695C),
      ));
      if (badges.length >= 3) return badges.take(3).toList();

      if (availableBatteries > 0) {
        badges.add(_MiniBadge(
          label: '$availableBatteries ready',
          color: Colors.green,
        ));
      }
    } else {
      // Charging station
      badges.add(_MiniBadge(
        label: '$totalPorts ports',
        color: theme.colorScheme.primary,
      ));
      if (badges.length >= 3) return badges.take(3).toList();

      if (maxPowerKw > 0) {
        badges.add(_MiniBadge(
          label: 'Up to ${maxPowerKw.toStringAsFixed(0)} kW',
          color: Colors.blue,
        ));
      }
      if (badges.length >= 3) return badges.take(3).toList();

      if (availablePorts > 0) {
        badges.add(_MiniBadge(
          label: '$availablePorts available',
          color: Colors.green,
        ));
      }
    }

    if (badges.length >= 3) return badges.take(3).toList();

    // Extra badge for hybrid stations (charging + battery swap)
    if (supportsBatterySwap && totalPorts > 0 && availableBatteries > 0) {
      badges.add(_MiniBadge(
        label: '+ $totalPiles piles',
        color: Colors.teal,
      ));
    }

    return badges.take(3).toList();
  }
}

class _MiniBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// Compact card specifically for battery swap stations in the bottom sheet.
class CompactSwapStationCard extends StatelessWidget {
  final BatterySwapStationModel station;
  final bool isSelected;
  final VoidCallback onTap;

  const CompactSwapStationCard({
    super.key,
    required this.station,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: isSelected ? 4 : 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: const Color(0xFF00695C), width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF00695C).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: FaIcon(
                    FontAwesomeIcons.batteryFull,
                    color: const Color(0xFF00695C),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            station.name ?? 'Unnamed station',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (station.distanceKm != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            '${station.distanceKm!.toStringAsFixed(1)} km',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF00695C),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    if (station.address != null &&
                        station.address!.isNotEmpty) ...[
                      Text(
                        station.address!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                    ],
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        _MiniBadge(
                          label: '${station.totalPiles} piles',
                          color: const Color(0xFF00695C),
                        ),
                        _MiniBadge(
                          label: '${station.availableBatteries} ready',
                          color: station.availableBatteries > 0
                              ? Colors.green
                              : Colors.orange,
                        ),
                        if (station.avgChargePowerKw > 0)
                          _MiniBadge(
                            label:
                                '${station.avgChargePowerKw.toStringAsFixed(0)} kW avg',
                            color: Colors.blue,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
