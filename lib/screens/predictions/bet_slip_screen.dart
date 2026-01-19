import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';

import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../config/constants.dart';
import '../../models/prediction.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bet_slip_provider.dart';
import '../../providers/predictions_provider.dart';

class BetSlipScreen extends StatefulWidget {
  const BetSlipScreen({super.key});

  @override
  State<BetSlipScreen> createState() => _BetSlipScreenState();
}

class _BetSlipScreenState extends State<BetSlipScreen> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  String _formatOdds(double odds) {
    return 'x${odds.toStringAsFixed(2)}';
  }

  String _getTypeDisplay(PredictionType type) {
    switch (type) {
      case PredictionType.moneyline:
        return 'MONEYLINE';
      case PredictionType.spread:
        return 'SPREAD';
      case PredictionType.total:
        return 'TOTAL';
      case PredictionType.playerProp:
        return 'PLAYER PROP';
    }
  }

  Future<void> _placePredictions(BuildContext context) async {
    final betSlip = context.read<BetSlipProvider>();
    final auth = context.read<AuthProvider>();
    final predictions = context.read<PredictionsProvider>();

    final totalStake = betSlip.totalStake;

    // Check if user has enough coins
    if ((auth.user?.coins ?? 0) < totalStake) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Not enough coins!'),
          backgroundColor: AppColors.accentRed,
        ),
      );
      return;
    }

    // Deduct coins
    await auth.removeCoins(totalStake);

    // Create predictions
    final newPredictions = betSlip.createPredictions();
    await predictions.addPredictions(newPredictions);

    // Award XP for placing bets
    final isParlay = betSlip.isCombo && betSlip.itemCount >= 2;
    await auth.awardXpForBet(betCount: newPredictions.length, isParlay: isParlay);

    // Clear bet slip
    betSlip.clear();

    // Show success
    _confettiController.play();

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.cardBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.accentGreen),
              SizedBox(width: 8),
              Text('Prediction Placed!', style: TextStyle(color: AppColors.textPrimary)),
            ],
          ),
          content: Text(
            'Good luck! Your ${newPredictions.length} prediction${newPredictions.length > 1 ? 's have' : ' has'} been placed.',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                context.go(AppRoutes.predictions);
              },
              child: const Text('View My Picks'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                context.go(AppRoutes.games);
              },
              child: const Text('Keep Betting'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.primaryDark,
          appBar: AppBar(
            backgroundColor: AppColors.primaryDark,
            title: const Text('Bet Slip'),
            actions: [
              Consumer<BetSlipProvider>(
                builder: (context, betSlip, child) {
                  if (betSlip.isEmpty) return const SizedBox.shrink();
                  return TextButton(
                    onPressed: () => betSlip.clear(),
                    child: const Text(
                      'Clear All',
                      style: TextStyle(color: AppColors.accentRed),
                    ),
                  );
                },
              ),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Consumer<BetSlipProvider>(
                builder: (context, betSlip, child) {
                  if (betSlip.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 64,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Your bet slip is empty',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Add predictions from the games screen',
                            style: TextStyle(
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () => context.go(AppRoutes.games),
                            child: const Text('Browse Games'),
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: [
                      // Bet items - either parlay view or single bets
                      Expanded(
                        child: betSlip.isCombo && betSlip.itemCount >= 2
                            ? _buildParlayView(betSlip)
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: betSlip.items.length,
                                itemBuilder: (context, index) {
                                  final item = betSlip.items[index];
                                  return _BetSlipItem(
                                    item: item,
                                    index: index,
                                    isCombo: false,
                                    onRemove: () => betSlip.removeItem(index),
                                    onStakeChanged: (stake) => betSlip.updateStake(index, stake),
                                  ).animate(delay: (index * 50).ms).fadeIn().slideX(begin: 0.1, end: 0);
                                },
                              ),
                      ),

                      // Bottom summary
                      _BottomSummary(onPlaceBet: () => _placePredictions(context)),
                    ],
                  );
                },
              ),
            ),
          ),
        ),

        // Confetti
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [
              AppColors.accent,
              AppColors.gold,
              AppColors.accentGreen,
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildParlayView(BetSlipProvider betSlip) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.accent.withOpacity(0.2),
              AppColors.cardBackground,
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.accent, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Parlay header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.layers, color: Colors.black, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    '${betSlip.itemCount}-Leg Parlay',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'x${betSlip.comboOdds.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // All picks displayed
            ...betSlip.items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: index < betSlip.items.length - 1
                      ? Border(bottom: BorderSide(color: AppColors.surfaceColor))
                      : null,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: AppColors.accent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.outcomeDisplay,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            item.matchDisplay,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'x${item.odds.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: AppColors.accentGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => betSlip.removeItem(index),
                      child: const Icon(Icons.close, color: AppColors.textMuted, size: 20),
                    ),
                  ],
                ),
              );
            }),

            // Combined odds footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceColor.withOpacity(0.5),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Combined Odds:', style: TextStyle(color: AppColors.textSecondary)),
                  Text(
                    'x${betSlip.comboOdds.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BetSlipItem extends StatelessWidget {
  final dynamic item; // BetSlipItem
  final int index;
  final bool isCombo;
  final VoidCallback onRemove;
  final ValueChanged<int> onStakeChanged;

  const _BetSlipItem({
    required this.item,
    required this.index,
    required this.isCombo,
    required this.onRemove,
    required this.onStakeChanged,
  });

  String _formatOdds(double odds) {
    return 'x${odds.toStringAsFixed(2)}';
  }

  String _getTypeDisplay(PredictionType type) {
    switch (type) {
      case PredictionType.moneyline:
        return 'MONEYLINE';
      case PredictionType.spread:
        return 'SPREAD';
      case PredictionType.total:
        return 'TOTAL';
      case PredictionType.playerProp:
        return 'PLAYER PROP';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with match and remove button
          Row(
            children: [
              Expanded(
                child: Text(
                  item.matchDisplay,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onRemove,
                child: const Icon(
                  Icons.close,
                  color: AppColors.textMuted,
                  size: 20,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Prediction details
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.outcomeDisplay,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _getTypeDisplay(item.type),
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _formatOdds(item.odds),
                style: const TextStyle(
                  color: AppColors.accentGreen,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          // Stake input (only show if not combo, or first item in combo)
          if (!isCombo || index == 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Text(
                  'Stake:',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const Spacer(),
                _StakeAdjuster(
                  stake: item.stake,
                  onChanged: onStakeChanged,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Potential Win:',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                Row(
                  children: [
                    const Icon(Icons.monetization_on, color: AppColors.gold, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${item.potentialPayout}',
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StakeAdjuster extends StatelessWidget {
  final int stake;
  final ValueChanged<int> onChanged;

  const _StakeAdjuster({
    required this.stake,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => onChanged((stake - 50).clamp(AppConstants.minBetAmount, AppConstants.maxBetAmount)),
            child: Container(
              padding: const EdgeInsets.all(8),
              child: const Icon(Icons.remove, color: AppColors.textSecondary, size: 20),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.monetization_on, color: AppColors.gold, size: 16),
                const SizedBox(width: 4),
                Text(
                  '$stake',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => onChanged((stake + 50).clamp(AppConstants.minBetAmount, AppConstants.maxBetAmount)),
            child: Container(
              padding: const EdgeInsets.all(8),
              child: const Icon(Icons.add, color: AppColors.textSecondary, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomSummary extends StatelessWidget {
  final VoidCallback onPlaceBet;

  const _BottomSummary({required this.onPlaceBet});

  @override
  Widget build(BuildContext context) {
    return Consumer2<BetSlipProvider, AuthProvider>(
      builder: (context, betSlip, auth, child) {
        final hasEnoughCoins = (auth.user?.coins ?? 0) >= betSlip.totalStake;

        return Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Summary rows
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Stake',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.monetization_on, color: AppColors.gold, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          '${betSlip.totalStake}',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Potential Win',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.monetization_on, color: AppColors.gold, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          '${betSlip.totalPotentialPayout}',
                          style: const TextStyle(
                            color: AppColors.accentGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Place bet button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: hasEnoughCoins ? onPlaceBet : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: hasEnoughCoins ? AppColors.accent : AppColors.surfaceColor,
                    ),
                    child: Text(
                      hasEnoughCoins
                          ? 'Place Prediction'
                          : 'Not Enough Coins',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
