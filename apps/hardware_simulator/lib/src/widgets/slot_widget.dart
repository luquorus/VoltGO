import 'package:flutter/material.dart';
import '../theme/simulator_theme.dart';
import '../models/simulator_models.dart';

class SlotWidget extends StatefulWidget {
  final SimulatorSlotModel slot;
  final bool isReserved;

  const SlotWidget({
    super.key,
    required this.slot,
    this.isReserved = false,
  });

  @override
  State<SlotWidget> createState() => _SlotWidgetState();
}

class _SlotWidgetState extends State<SlotWidget> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.isReserved) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(SlotWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isReserved && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isReserved && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = SimulatorTheme.getSlotStatusColor(widget.slot.status);
    final batteryIcon = SimulatorTheme.getSlotBatteryIcon(widget.slot.status);
    final isCharging = widget.slot.status.toUpperCase() == 'CHARGING';
    final isSwappedOut = widget.slot.status.toUpperCase() == 'SWAPPED_OUT';

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final scale = widget.isReserved ? _pulseAnimation.value : 1.0;
        return Transform.scale(
          scale: scale,
          child: Container(
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.isReserved ? statusColor : statusColor.withOpacity(0.5),
                width: widget.isReserved ? 3 : 2,
              ),
              boxShadow: widget.isReserved
                  ? [
                      BoxShadow(
                        color: statusColor.withOpacity(0.4),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        batteryIcon,
                        color: statusColor,
                        size: 28,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.slot.batteryChargePercent}%',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          widget.slot.status,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isCharging || isSwappedOut) ...[
                        const SizedBox(height: 6),
                        _buildProgressBar(statusColor),
                      ],
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

  Widget _buildProgressBar(Color color) {
    return Container(
      height: 6,
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(3),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: widget.slot.batteryChargePercent / 100,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}
