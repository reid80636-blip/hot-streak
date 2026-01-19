import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/wheel_prize.dart';

/// A premium spinning wheel widget with metallic/chrome effects
class SpinWheel extends StatefulWidget {
  final int? targetSegmentIndex;
  final VoidCallback? onSpinComplete;
  final VoidCallback? onSpinStart;

  const SpinWheel({
    super.key,
    this.targetSegmentIndex,
    this.onSpinComplete,
    this.onSpinStart,
  });

  @override
  State<SpinWheel> createState() => SpinWheelState();
}

class SpinWheelState extends State<SpinWheel>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;
  double _currentAngle = 0;
  bool _isSpinning = false;
  int? _highlightedSegment;
  int _lastTickSegment = -1;
  int _tickCount = 0;

  // Animation configuration
  static const Duration spinDuration = Duration(milliseconds: 5000);
  static const int baseRotations = 6;

  bool get isSpinning => _isSpinning;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: spinDuration,
      vsync: this,
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _onAnimationComplete();
      }
    });

    _controller.addListener(_checkForTick);
  }

  @override
  void dispose() {
    _controller.removeListener(_checkForTick);
    _controller.dispose();
    super.dispose();
  }

  /// Check if we've crossed into a new segment and trigger haptic feedback
  void _checkForTick() {
    if (!_isSpinning) return;

    final currentAngle = _rotationAnimation.value;
    final segmentCount = SpinWheelConfig.segmentCount;
    final segmentAngle = (2 * pi) / segmentCount;

    // Calculate which segment the pointer (at top) is pointing at
    final normalizedAngle = (currentAngle % (2 * pi));
    final segmentIndex = ((normalizedAngle / segmentAngle) % segmentCount).floor();

    if (segmentIndex != _lastTickSegment) {
      _lastTickSegment = segmentIndex;
      _tickCount++;

      // Vary haptic intensity based on spin speed (fewer ticks at start = faster)
      if (_tickCount % 2 == 0 || _controller.value > 0.7) {
        HapticFeedback.selectionClick();
      }
    }
  }

  /// Start the spin animation to land on the target segment
  void startSpin(int targetIndex) {
    if (_isSpinning) return;

    setState(() {
      _isSpinning = true;
      _highlightedSegment = null;
      _lastTickSegment = -1;
      _tickCount = 0;
    });

    widget.onSpinStart?.call();

    final segmentCount = SpinWheelConfig.segmentCount;
    final segmentAngle = (2 * pi) / segmentCount;

    final targetSegmentAngle = targetIndex * segmentAngle;

    // Add random offset within segment for natural feel (25-75% into the segment)
    final random = Random();
    final offsetWithinSegment =
        segmentAngle * 0.25 + random.nextDouble() * segmentAngle * 0.5;

    final totalRotation =
        (baseRotations * 2 * pi) + (2 * pi - targetSegmentAngle) - offsetWithinSegment;

    _rotationAnimation = Tween<double>(
      begin: _currentAngle,
      end: _currentAngle + totalRotation,
    ).animate(CurvedAnimation(
      parent: _controller,
      // Custom curve for more dramatic slow-down
      curve: const _WheelSpinCurve(),
    ));

    _controller.forward(from: 0);
  }

  void _onAnimationComplete() {
    _currentAngle = _rotationAnimation.value % (2 * pi);

    // Dramatic final haptic
    HapticFeedback.heavyImpact();

    setState(() {
      _isSpinning = false;
      _highlightedSegment = widget.targetSegmentIndex;
    });

    // Small delay before calling completion callback
    Future.delayed(const Duration(milliseconds: 200), () {
      widget.onSpinComplete?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final angle = _isSpinning ? _rotationAnimation.value : _currentAngle;

        return Transform.rotate(
          angle: angle,
          child: CustomPaint(
            size: Size.infinite,
            painter: _PremiumWheelPainter(
              prizes: SpinWheelConfig.prizes,
              highlightedSegment: _highlightedSegment,
            ),
          ),
        );
      },
    );
  }
}

/// Custom curve for realistic wheel spin physics
class _WheelSpinCurve extends Curve {
  const _WheelSpinCurve();

  @override
  double transformInternal(double t) {
    // Fast start, very gradual slowdown with suspenseful ending
    if (t < 0.3) {
      // Quick acceleration
      return 0.4 * (t / 0.3);
    } else if (t < 0.85) {
      // Steady spin with gradual slowdown
      final normalizedT = (t - 0.3) / 0.55;
      return 0.4 + 0.5 * (1 - pow(1 - normalizedT, 2));
    } else {
      // Final suspenseful slowdown
      final normalizedT = (t - 0.85) / 0.15;
      return 0.9 + 0.1 * Curves.easeOutCubic.transform(normalizedT);
    }
  }
}

/// Premium wheel painter with metallic/chrome effects
class _PremiumWheelPainter extends CustomPainter {
  final List<WheelPrize> prizes;
  final int? highlightedSegment;

  _PremiumWheelPainter({
    required this.prizes,
    this.highlightedSegment,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;
    final segmentAngle = (2 * pi) / prizes.length;

    // Draw chrome outer rim
    _drawChromeRim(canvas, center, radius);

    // Draw segments
    for (int i = 0; i < prizes.length; i++) {
      final prize = prizes[i];
      final startAngle = -pi / 2 + (i * segmentAngle);

      _drawPremiumSegment(
        canvas,
        center,
        radius * 0.88,
        startAngle,
        segmentAngle,
        prize,
        isHighlighted: highlightedSegment == i,
      );

      _drawSegmentText(
        canvas,
        center,
        radius * 0.88,
        startAngle + segmentAngle / 2,
        prize,
        isHighlighted: highlightedSegment == i,
      );
    }

    // Draw premium segment dividers
    _drawSegmentDividers(canvas, center, radius * 0.88, prizes.length);

    // Draw premium center hub
    _drawCenterHub(canvas, center, radius * 0.22);
  }

  void _drawChromeRim(Canvas canvas, Offset center, double radius) {
    // Outer shadow for depth
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(center, radius + 2, shadowPaint);

    // Chrome gradient rim
    final rimWidth = radius * 0.12;
    final outerRadius = radius;
    final innerRadius = radius - rimWidth;

    // Base chrome
    final chromePaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(center.dx - radius * 0.3, center.dy - radius * 0.3),
        radius * 2,
        [
          const Color(0xFFE8E8E8),
          const Color(0xFFD0D0D0),
          const Color(0xFF909090),
          const Color(0xFF606060),
          const Color(0xFF808080),
        ],
        [0.0, 0.25, 0.5, 0.75, 1.0],
      );

    final rimPath = Path()
      ..addOval(Rect.fromCircle(center: center, radius: outerRadius))
      ..addOval(Rect.fromCircle(center: center, radius: innerRadius))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(rimPath, chromePaint);

    // Chrome highlights
    final highlightPaint = Paint()
      ..shader = ui.Gradient.sweep(
        center,
        [
          Colors.white.withOpacity(0.5),
          Colors.transparent,
          Colors.white.withOpacity(0.3),
          Colors.transparent,
          Colors.white.withOpacity(0.5),
        ],
        [0.0, 0.2, 0.5, 0.8, 1.0],
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(center, outerRadius - 2, highlightPaint);
    canvas.drawCircle(center, innerRadius + 2, highlightPaint);

    // Inner rim edge (cyan accent - Blue Aura theme)
    final cyanEdgePaint = Paint()
      ..shader = ui.Gradient.sweep(
        center,
        [
          const Color(0xFF00D4FF),  // Accent cyan
          const Color(0xFF00A3FF),  // Glow blue
          const Color(0xFF00D4FF),
          const Color(0xFF0066FF),  // Primary accent
          const Color(0xFF00D4FF),
        ],
        [0.0, 0.25, 0.5, 0.75, 1.0],
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawCircle(center, innerRadius, cyanEdgePaint);
  }

  void _drawPremiumSegment(
    Canvas canvas,
    Offset center,
    double radius,
    double startAngle,
    double sweepAngle,
    WheelPrize prize, {
    bool isHighlighted = false,
  }) {
    final path = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
      )
      ..close();

    // Base color with gradient for depth
    final baseColor = prize.color;
    final lighterColor = Color.lerp(baseColor, Colors.white, 0.35)!;
    final darkerColor = Color.lerp(baseColor, Colors.black, 0.4)!;

    // Radial gradient for 3D depth
    final gradientPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(
          center.dx + radius * 0.2 * cos(startAngle + sweepAngle / 2),
          center.dy + radius * 0.2 * sin(startAngle + sweepAngle / 2),
        ),
        radius * 1.2,
        [
          lighterColor,
          baseColor,
          darkerColor,
        ],
        [0.0, 0.5, 1.0],
      );

    canvas.drawPath(path, gradientPaint);

    // Glossy overlay (top highlight)
    final glossPath = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(
        Rect.fromCircle(center: center, radius: radius * 0.7),
        startAngle,
        sweepAngle,
        false,
      )
      ..close();

    final glossPaint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        radius,
        [
          Colors.white.withOpacity(0.25),
          Colors.white.withOpacity(0.08),
          Colors.transparent,
        ],
        [0.0, 0.4, 0.7],
      );

    canvas.drawPath(glossPath, glossPaint);

    // Highlight effect for winning segment
    if (isHighlighted) {
      // Pulsing glow
      final glowPaint = Paint()
        ..color = Colors.white.withOpacity(0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawPath(path, glowPaint);

      // Bright overlay
      final highlightPaint = Paint()
        ..color = Colors.white.withOpacity(0.25);
      canvas.drawPath(path, highlightPaint);
    }
  }

  void _drawSegmentDividers(
    Canvas canvas,
    Offset center,
    double radius,
    int segmentCount,
  ) {
    final segmentAngle = (2 * pi) / segmentCount;

    for (int i = 0; i < segmentCount; i++) {
      final angle = -pi / 2 + (i * segmentAngle);
      final endX = center.dx + radius * cos(angle);
      final endY = center.dy + radius * sin(angle);

      // Chrome/metallic divider (cyan - Blue Aura theme)
      final dividerPaint = Paint()
        ..shader = ui.Gradient.linear(
          center,
          Offset(endX, endY),
          [
            const Color(0xFF0066FF),  // Primary accent
            const Color(0xFF00D4FF),  // Accent cyan
            const Color(0xFF0066FF),
          ],
          [0.0, 0.5, 1.0],
        )
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(
          center.dx + radius * 0.24 * cos(angle),
          center.dy + radius * 0.24 * sin(angle),
        ),
        Offset(endX, endY),
        dividerPaint,
      );
    }
  }

  void _drawSegmentText(
    Canvas canvas,
    Offset center,
    double radius,
    double angle,
    WheelPrize prize, {
    bool isHighlighted = false,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle + pi / 2);

    final textRadius = radius * 0.62;
    final fontSize = prize.isJackpot ? 15.0 : 13.0;

    // Draw amount with metallic effect
    final textPainter = TextPainter(
      text: TextSpan(
        text: prize.isJackpot ? '${prize.coins}' : '${prize.coins}',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          foreground: Paint()
            ..shader = ui.Gradient.linear(
              Offset(0, -textRadius - 10),
              Offset(0, -textRadius + 10),
              [
                Colors.white,
                isHighlighted ? const Color(0xFFFFE135) : const Color(0xFFE0E0E0),
              ],
            ),
          shadows: const [
            Shadow(
              color: Colors.black,
              blurRadius: 4,
              offset: Offset(1, 1),
            ),
            Shadow(
              color: Colors.black54,
              blurRadius: 2,
              offset: Offset(0, 0),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(-textPainter.width / 2, -textRadius - textPainter.height / 2),
    );

    // Draw jackpot label
    if (prize.isJackpot && prize.label != null) {
      final labelPainter = TextPainter(
        text: TextSpan(
          text: prize.label,
          style: TextStyle(
            fontSize: 7,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            foreground: Paint()
              ..shader = ui.Gradient.linear(
                Offset(0, -textRadius + 8),
                Offset(0, -textRadius + 16),
                [
                  const Color(0xFFFFD700),
                  const Color(0xFFFFFFFF),
                ],
              ),
            shadows: const [
              Shadow(color: Colors.black, blurRadius: 3),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      labelPainter.paint(
        canvas,
        Offset(-labelPainter.width / 2, -textRadius + textPainter.height / 2 + 4),
      );
    }

    canvas.restore();
  }

  void _drawCenterHub(Canvas canvas, Offset center, double radius) {
    // Outer glow (cyan - Blue Aura theme)
    final outerGlowPaint = Paint()
      ..color = const Color(0xFF00D4FF).withOpacity(0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
    canvas.drawCircle(center, radius + 8, outerGlowPaint);

    // Chrome base
    final chromePaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(center.dx - radius * 0.3, center.dy - radius * 0.3),
        radius * 1.5,
        [
          const Color(0xFFE8E8E8),
          const Color(0xFFC0C0C0),
          const Color(0xFF808080),
          const Color(0xFF606060),
        ],
        [0.0, 0.3, 0.7, 1.0],
      );
    canvas.drawCircle(center, radius, chromePaint);

    // Cyan inner ring (Blue Aura theme)
    final cyanRingPaint = Paint()
      ..shader = ui.Gradient.sweep(
        center,
        [
          const Color(0xFF00D4FF),  // Accent cyan
          const Color(0xFF0066FF),  // Primary accent
          const Color(0xFF00D4FF),
          const Color(0xFF00A3FF),  // Glow blue
          const Color(0xFF00D4FF),
        ],
        [0.0, 0.25, 0.5, 0.75, 1.0],
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.15;
    canvas.drawCircle(center, radius * 0.75, cyanRingPaint);

    // Inner chrome hub
    final innerChromePaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(center.dx - radius * 0.2, center.dy - radius * 0.2),
        radius,
        [
          const Color(0xFFFFFFFF),
          const Color(0xFFE0E0E0),
          const Color(0xFFB0B0B0),
          const Color(0xFF808080),
        ],
        [0.0, 0.3, 0.6, 1.0],
      );
    canvas.drawCircle(center, radius * 0.55, innerChromePaint);

    // Specular highlight
    final highlightPath = Path()
      ..addOval(Rect.fromCenter(
        center: Offset(center.dx - radius * 0.15, center.dy - radius * 0.2),
        width: radius * 0.5,
        height: radius * 0.3,
      ));

    final highlightPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(center.dx - radius * 0.15, center.dy - radius * 0.2),
        radius * 0.4,
        [
          Colors.white.withOpacity(0.8),
          Colors.white.withOpacity(0.0),
        ],
      );
    canvas.drawPath(highlightPath, highlightPaint);

    // Center bolt/gem (cyan - Blue Aura theme)
    final boltPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(center.dx - radius * 0.05, center.dy - radius * 0.05),
        radius * 0.25,
        [
          const Color(0xFF00E5FF),  // Bright cyan
          const Color(0xFF00D4FF),  // Accent cyan
          const Color(0xFF0066FF),  // Primary accent
        ],
        [0.0, 0.5, 1.0],
      );
    canvas.drawCircle(center, radius * 0.18, boltPaint);

    // Bolt highlight
    final boltHighlight = Paint()
      ..color = Colors.white.withOpacity(0.6);
    canvas.drawCircle(
      Offset(center.dx - radius * 0.05, center.dy - radius * 0.05),
      radius * 0.05,
      boltHighlight,
    );
  }

  @override
  bool shouldRepaint(covariant _PremiumWheelPainter oldDelegate) {
    return oldDelegate.highlightedSegment != highlightedSegment;
  }
}
