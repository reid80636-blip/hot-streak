import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../config/theme.dart';
import '../../models/sport.dart';

/// A beautifully animated sport card for the onboarding flow
/// Features: gradient backgrounds, glow effects, shimmer animations, elastic selections
class SportCard extends StatefulWidget {
  final Sport sport;
  final bool isSelected;
  final VoidCallback onTap;
  final int animationDelay;

  const SportCard({
    super.key,
    required this.sport,
    required this.isSelected,
    required this.onTap,
    this.animationDelay = 0,
  });

  @override
  State<SportCard> createState() => _SportCardState();
}

class _SportCardState extends State<SportCard> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.isSelected) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(SportCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isSelected && oldWidget.isSelected) {
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
    final gradientStart = widget.sport.gradientStart ?? widget.sport.color;
    final gradientEnd = widget.sport.gradientEnd ?? widget.sport.color.withOpacity(0.7);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          final pulseValue = widget.isSelected ? _pulseAnimation.value : 0.0;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              gradient: widget.isSelected
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        gradientStart,
                        gradientEnd,
                      ],
                    )
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.cardBackground,
                        AppColors.cardBackground.withOpacity(0.8),
                      ],
                    ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: widget.isSelected
                    ? Colors.white.withOpacity(0.5 + pulseValue * 0.2)
                    : AppColors.borderSubtle.withOpacity(0.3),
                width: widget.isSelected ? 2.5 : 1,
              ),
              boxShadow: [
                // Outer glow for selected state
                if (widget.isSelected) ...[
                  BoxShadow(
                    color: gradientStart.withOpacity(0.4 + pulseValue * 0.15),
                    blurRadius: 24 + pulseValue * 8,
                    spreadRadius: 2 + pulseValue * 2,
                  ),
                  // Inner shadow for depth
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ] else ...[
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ],
            ),
            child: Stack(
              children: [
                // Shimmer overlay for selected cards
                if (widget.isSelected)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(23),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment(-1.5 + pulseValue * 3, -0.5),
                            end: Alignment(-0.5 + pulseValue * 3, 0.5),
                            colors: [
                              Colors.white.withOpacity(0),
                              Colors.white.withOpacity(0.1),
                              Colors.white.withOpacity(0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                // Inner highlight at top
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 60,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(23)),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withOpacity(widget.isSelected ? 0.15 : 0.05),
                            Colors.white.withOpacity(0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Main content
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Sport logo in circle with ring
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer ring (animated for selected)
                          if (widget.isSelected)
                            Container(
                              width: 76 + pulseValue * 4,
                              height: 76 + pulseValue * 4,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3 + pulseValue * 0.2),
                                  width: 2,
                                ),
                              ),
                            ),
                          // Logo container
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: widget.isSelected
                                      ? gradientStart.withOpacity(0.4)
                                      : Colors.black.withOpacity(0.15),
                                  blurRadius: widget.isSelected ? 12 : 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: widget.sport.logoUrl != null
                                    ? CachedNetworkImage(
                                        imageUrl: widget.sport.logoUrl!,
                                        fit: BoxFit.contain,
                                        placeholder: (context, url) => Center(
                                          child: Text(
                                            widget.sport.emoji,
                                            style: const TextStyle(fontSize: 30),
                                          ),
                                        ),
                                        errorWidget: (context, url, error) => Center(
                                          child: Text(
                                            widget.sport.emoji,
                                            style: const TextStyle(fontSize: 30),
                                          ),
                                        ),
                                      )
                                    : Center(
                                        child: Text(
                                          widget.sport.emoji,
                                          style: const TextStyle(fontSize: 30),
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // Sport short name
                      Text(
                        widget.sport.shortName,
                        style: TextStyle(
                          color: widget.isSelected ? Colors.white : AppColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          shadows: widget.isSelected
                              ? [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 4,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Sport full name
                      Text(
                        widget.sport.name,
                        style: TextStyle(
                          color: widget.isSelected
                              ? Colors.white.withOpacity(0.9)
                              : AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Selection checkmark with bounce
                if (widget.isSelected)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        color: gradientStart,
                        size: 20,
                      ),
                    )
                        .animate()
                        .scale(
                          begin: const Offset(0, 0),
                          end: const Offset(1, 1),
                          duration: 300.ms,
                          curve: Curves.elasticOut,
                        )
                        .fadeIn(duration: 150.ms),
                  ),
              ],
            ),
          );
        },
      ),
    )
        .animate(delay: Duration(milliseconds: widget.animationDelay))
        .fadeIn(duration: 350.ms)
        .scale(
          begin: const Offset(0.75, 0.75),
          end: const Offset(1, 1),
          duration: 400.ms,
          curve: Curves.easeOutBack,
        );
  }
}
