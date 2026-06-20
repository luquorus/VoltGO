import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Preview card shown in the bottom sheet when a station is selected.
/// Provides clear Route, Book, or Reserve actions.
class SelectedStationPreview extends StatelessWidget {
  final String name;
  final String? address;
  final double? distanceKm;
  final int? etaMinutes;
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
  final bool isBatterySwapOnly;
  final VoidCallback onRoute;
  final VoidCallback onBookOrReserve;
  final VoidCallback? onClearSelection;

  const SelectedStationPreview({
    super.key,
    required this.name,
    this.address,
    this.distanceKm,
    this.etaMinutes,
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
    this.isBatterySwapOnly = false,
    required this.onRoute,
    required this.onBookOrReserve,
    this.onClearSelection,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    // Icon
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isBatterySwapOnly
                            ? const Color(0xFF00695C).withOpacity(0.1)
                            : Colors.green.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: FaIcon(
                          isBatterySwapOnly
                              ? FontAwesomeIcons.batteryFull
                              : FontAwesomeIcons.bolt,
                          color: isBatterySwapOnly
                              ? const Color(0xFF00695C)
                              : Colors.green,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Name + address
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (address != null && address!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              address!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (onClearSelection != null)
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: onClearSelection,
                        tooltip: 'Clear selection',
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                // Info row: distance, availability, power
                Row(
                  children: [
                    if (distanceKm != null) ...[
                      _InfoChip(
                        icon: Icons.near_me,
                        label: '${distanceKm!.toStringAsFixed(1)} km',
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (etaMinutes != null) ...[
                      _InfoChip(
                        icon: Icons.schedule,
                        label: '~${etaMinutes} min',
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (isBatterySwapOnly) ...[
                      _InfoChip(
                        icon: Icons.battery_charging_full,
                        label: '$availableBatteries ready',
                        color: availableBatteries > 0 ? Colors.green : Colors.orange,
                      ),
                    ] else ...[
                      _InfoChip(
                        icon: Icons.ev_station,
                        label: '$availablePorts/$totalPorts ports',
                        color: availablePorts > 0 ? Colors.green : Colors.grey,
                      ),
                      if (maxPowerKw > 0) ...[
                        const SizedBox(width: 8),
                        _InfoChip(
                          icon: Icons.electric_bolt,
                          label: '${maxPowerKw.toStringAsFixed(0)} kW',
                          color: Colors.orange,
                        ),
                      ],
                    ],
                    const Spacer(),
                    if (trustScore > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _trustColor(trustScore).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _trustColor(trustScore).withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FaIcon(
                              FontAwesomeIcons.shieldHalved,
                              color: _trustColor(trustScore),
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$trustScore',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _trustColor(trustScore),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                // Badges for hybrid stations
                if (supportsBatterySwap && totalPorts > 0) ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _BadgeChip(
                        label: '$totalPorts charging ports',
                        color: theme.colorScheme.primary,
                      ),
                      _BadgeChip(
                        label: '+ $totalPiles battery piles',
                        color: const Color(0xFF00695C),
                      ),
                      if (availableBatteries > 0)
                        _BadgeChip(
                          label: '$availableBatteries batteries ready',
                          color: Colors.green,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onRoute,
                        icon: const FaIcon(FontAwesomeIcons.route, size: 16),
                        label: const Text('Route'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: onBookOrReserve,
                        icon: FaIcon(
                          isBatterySwapOnly
                              ? FontAwesomeIcons.batteryFull
                              : FontAwesomeIcons.calendarCheck,
                          size: 16,
                        ),
                        label: Text(
                          isBatterySwapOnly ? 'Reserve' : 'Book',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _trustColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.lightGreen;
    if (score >= 40) return Colors.orange;
    return Colors.red;
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  final String label;
  final Color color;

  const _BadgeChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
