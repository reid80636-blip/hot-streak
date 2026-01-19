import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../providers/auth_provider.dart';

class CoinBalance extends StatelessWidget {
  final bool showIcon;
  final bool compact;
  final bool tappable;

  const CoinBalance({
    super.key,
    this.showIcon = true,
    this.compact = false,
    this.tappable = true,
  });

  String _formatCoins(int coins) {
    if (coins >= 1000000) {
      return '${(coins / 1000000).toStringAsFixed(1)}M';
    } else if (coins >= 1000) {
      return '${(coins / 1000).toStringAsFixed(1)}K';
    }
    return coins.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        final coins = auth.user?.coins ?? 0;

        final widget = Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 14,
            vertical: compact ? 6 : 8,
          ),
          decoration: BoxDecoration(
            gradient: AppColors.goldGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.gold.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showIcon) ...[
                Icon(
                  Icons.monetization_on,
                  color: Colors.white,
                  size: compact ? 16 : 20,
                ),
                SizedBox(width: compact ? 4 : 6),
              ],
              Text(
                _formatCoins(coins),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: compact ? 13 : 15,
                ),
              ),
            ],
          ),
        );

        if (tappable) {
          return GestureDetector(
            onTap: () => context.push(AppRoutes.wallet),
            child: widget,
          );
        }

        return widget;
      },
    );
  }
}

class AnimatedCoinBalance extends StatefulWidget {
  final int coins;
  final int? previousCoins;

  const AnimatedCoinBalance({
    super.key,
    required this.coins,
    this.previousCoins,
  });

  @override
  State<AnimatedCoinBalance> createState() => _AnimatedCoinBalanceState();
}

class _AnimatedCoinBalanceState extends State<AnimatedCoinBalance> {
  late int _displayCoins;

  @override
  void initState() {
    super.initState();
    _displayCoins = widget.previousCoins ?? widget.coins;
    if (widget.previousCoins != null && widget.previousCoins != widget.coins) {
      _animateToNewValue();
    }
  }

  @override
  void didUpdateWidget(AnimatedCoinBalance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coins != widget.coins) {
      _animateToNewValue();
    }
  }

  void _animateToNewValue() {
    // Simple animation by updating value
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() => _displayCoins = widget.coins);
      }
    });
  }

  String _formatCoins(int coins) {
    if (coins >= 1000000) {
      return '${(coins / 1000000).toStringAsFixed(1)}M';
    } else if (coins >= 1000) {
      return '${(coins / 1000).toStringAsFixed(1)}K';
    }
    return coins.toString();
  }

  @override
  Widget build(BuildContext context) {
    final isIncrease = widget.coins > (widget.previousCoins ?? widget.coins);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.monetization_on,
          color: AppColors.gold,
          size: 28,
        ),
        const SizedBox(width: 8),
        Text(
          _formatCoins(_displayCoins),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 28,
          ),
        ).animate(target: isIncrease ? 1 : 0).scale(
              begin: const Offset(1, 1),
              end: const Offset(1.1, 1.1),
              duration: 200.ms,
            ),
      ],
    );
  }
}
