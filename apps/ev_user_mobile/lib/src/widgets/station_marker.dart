import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Custom station marker widget (circular with icon).
/// [isBatterySwap] uses a distinct darker teal style for trạm đổi pin.
class StationMarker extends StatelessWidget {
  final bool isBatterySwap;

  const StationMarker({super.key, this.isBatterySwap = false});

  @override
  Widget build(BuildContext context) {
    // Charging: bolt icon, medium green. Battery swap: battery icon, darker teal.
    final bg = isBatterySwap ? const Color(0xFF00695C) : const Color(0xFF4CAF50);
    final icon = isBatterySwap ? FontAwesomeIcons.batteryFull : FontAwesomeIcons.bolt;
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: FaIcon(
          icon,
          color: Colors.white,
          size: 14,
        ),
      ),
    );
  }
}

