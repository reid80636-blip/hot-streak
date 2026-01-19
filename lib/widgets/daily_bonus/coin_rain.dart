import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Animated coin rain effect for big wins
class CoinRain extends StatefulWidget {
  final bool isPlaying;
  final int intensity; // 1-3, affects coin count

  const CoinRain({
    super.key,
    this.isPlaying = false,
    this.intensity = 2,
  });

  @override
  State<CoinRain> createState() => _CoinRainState();
}

class _CoinRainState extends State<CoinRain> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Coin> _coins = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(CoinRain oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !oldWidget.isPlaying) {
      _startRain();
    }
  }

  void _startRain() {
    _coins.clear();
    final coinCount = widget.intensity * 15;

    for (int i = 0; i < coinCount; i++) {
      _coins.add(_Coin(
        x: _random.nextDouble(),
        startDelay: _random.nextDouble() * 0.5,
        speed: 0.3 + _random.nextDouble() * 0.4,
        size: 16 + _random.nextDouble() * 16,
        rotation: _random.nextDouble() * 2 * pi,
        rotationSpeed: (_random.nextDouble() - 0.5) * 4,
        wobble: _random.nextDouble() * 20,
        wobbleSpeed: 2 + _random.nextDouble() * 3,
      ));
    }

    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isPlaying && _coins.isEmpty) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _CoinRainPainter(
          coins: _coins,
          progress: _controller.value,
        ),
      ),
    );
  }
}

class _Coin {
  final double x;
  final double startDelay;
  final double speed;
  final double size;
  final double rotation;
  final double rotationSpeed;
  final double wobble;
  final double wobbleSpeed;

  _Coin({
    required this.x,
    required this.startDelay,
    required this.speed,
    required this.size,
    required this.rotation,
    required this.rotationSpeed,
    required this.wobble,
    required this.wobbleSpeed,
  });
}

class _CoinRainPainter extends CustomPainter {
  final List<_Coin> coins;
  final double progress;

  _CoinRainPainter({
    required this.coins,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final coin in coins) {
      // Calculate coin position based on progress
      final adjustedProgress = (progress - coin.startDelay).clamp(0.0, 1.0);
      if (adjustedProgress <= 0) continue;

      final y = -coin.size + (size.height + coin.size * 2) * adjustedProgress * coin.speed * 2;
      if (y > size.height + coin.size) continue;

      final wobbleOffset = sin(adjustedProgress * coin.wobbleSpeed * 2 * pi) * coin.wobble;
      final x = coin.x * size.width + wobbleOffset;
      final rotation = coin.rotation + adjustedProgress * coin.rotationSpeed * 2 * pi;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);

      _drawCoin(canvas, coin.size);

      canvas.restore();
    }
  }

  void _drawCoin(Canvas canvas, double size) {
    final radius = size / 2;

    // Coin edge (3D effect)
    final edgePaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(-radius, 0),
        Offset(radius, 0),
        [
          const Color(0xFFB8860B),
          const Color(0xFFFFD700),
          const Color(0xFFB8860B),
        ],
        [0.0, 0.5, 1.0],
      );

    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 2), width: size, height: size * 0.3),
      edgePaint,
    );

    // Main coin face
    final facePaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(-radius * 0.3, -radius * 0.3),
        radius * 1.5,
        [
          const Color(0xFFFFE135),
          const Color(0xFFFFD700),
          const Color(0xFFDAA520),
          const Color(0xFFB8860B),
        ],
        [0.0, 0.3, 0.7, 1.0],
      );

    canvas.drawCircle(Offset.zero, radius, facePaint);

    // Inner ring
    final ringPaint = Paint()
      ..color = const Color(0xFFB8860B).withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawCircle(Offset.zero, radius * 0.7, ringPaint);

    // Dollar sign or star
    final symbolPaint = Paint()
      ..color = const Color(0xFFB8860B).withOpacity(0.6);

    // Simple star shape
    final starPath = Path();
    for (int i = 0; i < 5; i++) {
      final angle = -pi / 2 + (i * 4 * pi / 5);
      final point = Offset(cos(angle) * radius * 0.4, sin(angle) * radius * 0.4);
      if (i == 0) {
        starPath.moveTo(point.dx, point.dy);
      } else {
        starPath.lineTo(point.dx, point.dy);
      }
    }
    starPath.close();

    canvas.drawPath(starPath, symbolPaint);

    // Highlight
    final highlightPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(-radius * 0.3, -radius * 0.3),
        radius * 0.5,
        [
          Colors.white.withOpacity(0.6),
          Colors.white.withOpacity(0.0),
        ],
      );

    canvas.drawCircle(Offset(-radius * 0.3, -radius * 0.3), radius * 0.4, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant _CoinRainPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
