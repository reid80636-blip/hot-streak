import 'dart:math';
import 'package:flutter/material.dart';

/// Represents a single prize segment on the spin wheel
class WheelPrize {
  final int coins;
  final double probability;
  final Color color;
  final String? label;
  final bool isJackpot;

  const WheelPrize({
    required this.coins,
    required this.probability,
    required this.color,
    this.label,
    this.isJackpot = false,
  });
}

/// Configuration for the spin wheel prizes and selection logic
/// Colors match the Blue Aura theme
class SpinWheelConfig {
  // Prize distribution - probabilities sum to 1.0
  // Colors match Blue Aura theme with cyan/blue gradient
  static const List<WheelPrize> prizes = [
    // High probability: Small amounts (60% total) - Deep blues
    WheelPrize(coins: 50, probability: 0.20, color: Color(0xFF0A1628)),   // Primary dark
    WheelPrize(coins: 100, probability: 0.20, color: Color(0xFF1E3A5F)),  // Glass blue
    WheelPrize(coins: 150, probability: 0.12, color: Color(0xFF1A3A5C)),  // Surface blue
    WheelPrize(coins: 200, probability: 0.08, color: Color(0xFF0D47A1)),  // Deep blue

    // Medium probability: Medium amounts (30% total) - Brighter blues/cyans
    WheelPrize(coins: 300, probability: 0.12, color: Color(0xFF0066FF)),  // Primary accent
    WheelPrize(coins: 500, probability: 0.10, color: Color(0xFF00A3FF)),  // Glow blue
    WheelPrize(coins: 750, probability: 0.08, color: Color(0xFF00D4FF)),  // Accent cyan

    // Low probability: Large amounts (9% total) - Special colors
    WheelPrize(coins: 1000, probability: 0.05, color: Color(0xFF00FF7F)), // Success green
    WheelPrize(coins: 1500, probability: 0.025, color: Color(0xFF7C3AED)), // Purple
    WheelPrize(coins: 2500, probability: 0.015, color: Color(0xFFFF416C)), // Live red/pink

    // Very rare: Jackpot (1% total) - Gold for coins
    WheelPrize(
      coins: 5000,
      probability: 0.01,
      color: Color(0xFFFFD700),  // Gold (Jackpot - coins)
      label: 'JACKPOT',
      isJackpot: true,
    ),
  ];

  /// Select a prize using weighted random algorithm
  static WheelPrize selectPrize() {
    final random = Random();
    final roll = random.nextDouble();

    double cumulative = 0;
    for (final prize in prizes) {
      cumulative += prize.probability;
      if (roll < cumulative) {
        return prize;
      }
    }

    // Fallback (shouldn't happen if probabilities sum to 1.0)
    return prizes.first;
  }

  /// Get the segment index for a given prize
  static int getSegmentIndex(WheelPrize prize) {
    return prizes.indexOf(prize);
  }

  /// Total number of segments
  static int get segmentCount => prizes.length;
}
