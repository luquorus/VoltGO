import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/simulator_theme.dart';
import '../services/simulator_websocket_service.dart';

class SwapCodeBanner extends StatefulWidget {
  final SwapCodeEvent swapCodeEvent;
  final VoidCallback onDismiss;
  final VoidCallback? onExpired;

  const SwapCodeBanner({
    super.key,
    required this.swapCodeEvent,
    required this.onDismiss,
    this.onExpired,
  });

  @override
  State<SwapCodeBanner> createState() => _SwapCodeBannerState();
}

class _SwapCodeBannerState extends State<SwapCodeBanner> with SingleTickerProviderStateMixin {
  Timer? _countdownTimer;
  Duration _timeRemaining = Duration.zero;
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _calculateTimeRemaining();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _calculateTimeRemaining();
    });

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  void _calculateTimeRemaining() {
    if (widget.swapCodeEvent.deadlineAt != null) {
      final remaining = widget.swapCodeEvent.deadlineAt!.difference(DateTime.now());
      setState(() {
        _timeRemaining = remaining.isNegative ? Duration.zero : remaining;
      });
      if (remaining.isNegative) {
        _countdownTimer?.cancel();
        widget.onExpired?.call();
      }
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _glowController.dispose();
    super.dispose();
  }

  String get _formattedTime {
    final minutes = _timeRemaining.inMinutes;
    final seconds = _timeRemaining.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                SimulatorTheme.statusReserved.withOpacity(0.15 * _glowAnimation.value),
                SimulatorTheme.primaryTeal.withOpacity(0.1 * _glowAnimation.value),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: SimulatorTheme.statusReserved.withOpacity(_glowAnimation.value),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: SimulatorTheme.statusReserved.withOpacity(0.3 * _glowAnimation.value),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: SimulatorTheme.statusReserved.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.swap_horiz,
                              color: SimulatorTheme.statusReserved,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'SWAP CODE',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: SimulatorTheme.textSecondary,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: widget.onDismiss,
                        icon: const Icon(Icons.close),
                        color: SimulatorTheme.textSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Swap code display
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: SimulatorTheme.statusReserved.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _formatSwapCode(widget.swapCodeEvent.swapCode),
                      style: const TextStyle(
                        fontSize: 56,
                        fontWeight: FontWeight.bold,
                        color: SimulatorTheme.statusReserved,
                        letterSpacing: 16,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Timer
                  if (widget.swapCodeEvent.deadlineAt != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.timer,
                          color: _timeRemaining.inSeconds < 30 ? Colors.red : SimulatorTheme.accentAmber,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Expires in $_formattedTime',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: _timeRemaining.inSeconds < 30 ? Colors.red : SimulatorTheme.accentAmber,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.phone_android, color: Colors.blue, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'User will enter this code on their EV app to confirm the swap',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue.shade200,
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
        );
      },
    );
  }

  String _formatSwapCode(String code) {
    if (code.length == 4) {
      return '${code[0]}  ${code[1]}  ${code[2]}  ${code[3]}';
    }
    return code;
  }
}
