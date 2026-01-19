import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Animated LED lights that circle the wheel rim - casino style
class WheelLights extends StatefulWidget {
  final double diameter;
  final bool isSpinning;
  final bool isPrizeRevealed;

  const WheelLights({
    super.key,
    required this.diameter,
    this.isSpinning = false,
    this.isPrizeRevealed = false,
  });

  @override
  State<WheelLights> createState() => _WheelLightsState();
}

class _WheelLightsState extends State<WheelLights>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  static const int lightCount = 24;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.diameter, widget.diameter),
          painter: _WheelLightsPainter(
            animationValue: _controller.value,
            isSpinning: widget.isSpinning,
            isPrizeRevealed: widget.isPrizeRevealed,
          ),
        );
      },
    );
  }
}

class _WheelLightsPainter extends CustomPainter {
  final double animationValue;
  final bool isSpinning;
  final bool isPrizeRevealed;

  _WheelLightsPainter({
    required this.animationValue,
    required this.isSpinning,
    required this.isPrizeRevealed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    const lightCount = 24;
    final lightRadius = radius * 0.035;
    final orbitRadius = radius - lightRadius - 4;

    for (int i = 0; i < lightCount; i++) {
      final angle = (2 * pi * i / lightCount) - pi / 2;
      final x = center.dx + orbitRadius * cos(angle);
      final y = center.dy + orbitRadius * sin(angle);

      // Determine if this light should be "on"
      bool isLit;
      if (isPrizeRevealed) {
        // All lights flash together rapidly
        isLit = (animationValue * 4).floor() % 2 == 0;
      } else if (isSpinning) {
        // Chase pattern - 3 lights on, rotating quickly
        final chasePosition = (animationValue * lightCount * 2).floor() % lightCount;
        final distance = (i - chasePosition + lightCount) % lightCount;
        isLit = distance < 3;
      } else {
        // Alternating pattern, slow pulse
        final pulsePhase = (animationValue * 2).floor() % 2;
        isLit = (i + pulsePhase) % 2 == 0;
      }

      // Draw outer glow for lit lights (cyan - Blue Aura theme)
      if (isLit) {
        final glowPaint = Paint()
          ..color = const Color(0xFF00D4FF).withOpacity(0.6)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
        canvas.drawCircle(Offset(x, y), lightRadius * 1.8, glowPaint);
      }

      // Draw light bulb (cyan - Blue Aura theme)
      final bulbGradient = ui.Gradient.radial(
        Offset(x - lightRadius * 0.3, y - lightRadius * 0.3),
        lightRadius * 1.5,
        isLit
            ? [
                const Color(0xFFFFFFFF),  // White center
                const Color(0xFF80EAFF),  // Light cyan
                const Color(0xFF00D4FF),  // Accent cyan
                const Color(0xFF0066FF),  // Primary accent
              ]
            : [
                const Color(0xFF4A4A4A),
                const Color(0xFF3A3A3A),
                const Color(0xFF2A2A2A),
                const Color(0xFF1A1A1A),
              ],
        [0.0, 0.3, 0.6, 1.0],
      );

      final bulbPaint = Paint()..shader = bulbGradient;
      canvas.drawCircle(Offset(x, y), lightRadius, bulbPaint);

      // Chrome ring around each bulb
      final ringPaint = Paint()
        ..shader = ui.Gradient.sweep(
          Offset(x, y),
          [
            const Color(0xFFE8E8E8),
            const Color(0xFF888888),
            const Color(0xFFE8E8E8),
            const Color(0xFF666666),
            const Color(0xFFE8E8E8),
          ],
          [0.0, 0.25, 0.5, 0.75, 1.0],
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(Offset(x, y), lightRadius, ringPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WheelLightsPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.isSpinning != isSpinning ||
        oldDelegate.isPrizeRevealed != isPrizeRevealed;
  }
}
