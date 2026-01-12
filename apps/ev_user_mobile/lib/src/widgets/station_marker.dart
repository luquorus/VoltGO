import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Custom station marker widget (circular with lightning bolt)
class StationMarker extends StatelessWidget {
  const StationMarker({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50), // Green
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
      child: const Center(
        child: FaIcon(
          FontAwesomeIcons.bolt,
          color: Colors.white,
          size: 14,
        ),
      ),
    );
  }
}

