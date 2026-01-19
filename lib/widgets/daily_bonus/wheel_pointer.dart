import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Premium chrome/gold pointer that sits at the top of the wheel
class WheelPointer extends StatelessWidget {
  final double size;
  final bool showGlow;

  const WheelPointer({
    super.key,
    this.size = 40,
    this.showGlow = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 1.4,
      height: size * 1.5,
      child: CustomPaint(
        size: Size(size * 1.4, size * 1.5),
        painter: _PremiumPointerPainter(showGlow: showGlow),
      ),
    );
  }
}

class _PremiumPointerPainter extends CustomPainter {
  final bool showGlow;

  _PremiumPointerPainter({this.showGlow = false});

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final pointerWidth = size.width * 0.7;
    final pointerHeight = size.height * 0.75;

    // Draw intense glow when prize revealed (cyan - Blue Aura theme)
    if (showGlow) {
      // Multiple glow layers for intensity
      for (int i = 3; i >= 0; i--) {
        final glowPaint = Paint()
          ..color = const Color(0xFF00D4FF).withOpacity(0.3 - i * 0.05)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12.0 + i * 6);

        final glowPath = Path()
          ..moveTo(centerX - pointerWidth / 2 - 8, 0)
          ..lineTo(centerX + pointerWidth / 2 + 8, 0)
          ..lineTo(centerX, pointerHeight + 10)
          ..close();

        canvas.drawPath(glowPath, glowPaint);
      }
    }

    // Main pointer shape
    final pointerPath = Path()
      ..moveTo(centerX - pointerWidth / 2, 0)
      ..lineTo(centerX + pointerWidth / 2, 0)
      ..lineTo(centerX, pointerHeight)
      ..close();

    // Chrome base with cyan tint (Blue Aura theme)
    final chromePaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(centerX - pointerWidth / 2, 0),
        Offset(centerX + pointerWidth / 2, pointerHeight),
        [
          const Color(0xFF80EAFF),  // Light cyan
          const Color(0xFF00D4FF),  // Accent cyan
          const Color(0xFF00A3FF),  // Glow blue
          const Color(0xFF0066FF),  // Primary accent
          const Color(0xFF004ACC),  // Deep blue
        ],
        [0.0, 0.25, 0.5, 0.75, 1.0],
      );

    canvas.drawPath(pointerPath, chromePaint);

    // Left side highlight (light reflection)
    final leftHighlightPath = Path()
      ..moveTo(centerX - pointerWidth / 2, 0)
      ..lineTo(centerX - pointerWidth / 4, 0)
      ..lineTo(centerX - pointerWidth / 8, pointerHeight * 0.6)
      ..lineTo(centerX, pointerHeight)
      ..close();

    final leftHighlightPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(centerX - pointerWidth / 2, 0),
        Offset(centerX, pointerHeight * 0.5),
        [
          Colors.white.withOpacity(0.5),
          Colors.white.withOpacity(0.2),
          Colors.transparent,
        ],
        [0.0, 0.4, 1.0],
      );

    canvas.drawPath(leftHighlightPath, leftHighlightPaint);

    // Top edge highlight
    final topHighlightPath = Path()
      ..moveTo(centerX - pointerWidth / 2 + 4, 2)
      ..lineTo(centerX + pointerWidth / 4, 2)
      ..lineTo(centerX - pointerWidth / 6, pointerHeight * 0.3)
      ..close();

    final topHighlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.6);

    canvas.drawPath(topHighlightPath, topHighlightPaint);

    // Right side shadow
    final rightShadowPath = Path()
      ..moveTo(centerX + pointerWidth / 2, 0)
      ..lineTo(centerX + pointerWidth / 4, 0)
      ..lineTo(centerX, pointerHeight)
      ..close();

    final rightShadowPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(centerX + pointerWidth / 2, 0),
        Offset(centerX, pointerHeight),
        [
          Colors.black.withOpacity(0.3),
          Colors.black.withOpacity(0.1),
        ],
      );

    canvas.drawPath(rightShadowPath, rightShadowPaint);

    // Chrome border
    final borderPath = Path()
      ..moveTo(centerX - pointerWidth / 2, 0)
      ..lineTo(centerX + pointerWidth / 2, 0)
      ..lineTo(centerX, pointerHeight)
      ..close();

    final borderPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(centerX - pointerWidth / 2, 0),
        Offset(centerX + pointerWidth / 2, 0),
        [
          const Color(0xFFFFFFFF),
          const Color(0xFFE8E8E8),
          const Color(0xFFB8B8B8),
          const Color(0xFFE8E8E8),
          const Color(0xFFFFFFFF),
        ],
        [0.0, 0.25, 0.5, 0.75, 1.0],
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(borderPath, borderPaint);

    // Inner cyan border (Blue Aura theme)
    final innerBorderPath = Path()
      ..moveTo(centerX - pointerWidth / 2 + 4, 4)
      ..lineTo(centerX + pointerWidth / 2 - 4, 4)
      ..lineTo(centerX, pointerHeight - 6)
      ..close();

    final innerBorderPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(centerX - pointerWidth / 2, 0),
        Offset(centerX + pointerWidth / 2, 0),
        [
          const Color(0xFF00D4FF),  // Accent cyan
          const Color(0xFF0066FF),  // Primary accent
          const Color(0xFF00D4FF),
        ],
        [0.0, 0.5, 1.0],
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawPath(innerBorderPath, innerBorderPaint);

    // Top mounting bracket (chrome circle)
    final bracketRadius = pointerWidth * 0.22;
    final bracketCenter = Offset(centerX, bracketRadius + 2);

    // Bracket shadow
    canvas.drawCircle(
      Offset(bracketCenter.dx + 2, bracketCenter.dy + 2),
      bracketRadius,
      Paint()..color = Colors.black.withOpacity(0.3),
    );

    // Bracket chrome
    final bracketPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(bracketCenter.dx - bracketRadius * 0.3, bracketCenter.dy - bracketRadius * 0.3),
        bracketRadius * 1.5,
        [
          const Color(0xFFFFFFFF),
          const Color(0xFFE0E0E0),
          const Color(0xFFB0B0B0),
          const Color(0xFF808080),
        ],
        [0.0, 0.3, 0.6, 1.0],
      );

    canvas.drawCircle(bracketCenter, bracketRadius, bracketPaint);

    // Bracket border (cyan - Blue Aura theme)
    canvas.drawCircle(
      bracketCenter,
      bracketRadius,
      Paint()
        ..color = const Color(0xFF00D4FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Bracket center gem (cyan - Blue Aura theme)
    final gemPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(bracketCenter.dx - 2, bracketCenter.dy - 2),
        bracketRadius * 0.5,
        [
          const Color(0xFF80EAFF),  // Light cyan
          const Color(0xFF00D4FF),  // Accent cyan
          const Color(0xFF0066FF),  // Primary accent
        ],
        [0.0, 0.5, 1.0],
      );

    canvas.drawCircle(bracketCenter, bracketRadius * 0.5, gemPaint);

    // Gem highlight
    canvas.drawCircle(
      Offset(bracketCenter.dx - bracketRadius * 0.15, bracketCenter.dy - bracketRadius * 0.15),
      bracketRadius * 0.15,
      Paint()..color = Colors.white.withOpacity(0.7),
    );
  }

  @override
  bool shouldRepaint(covariant _PremiumPointerPainter oldDelegate) {
    return oldDelegate.showGlow != showGlow;
  }
}
