import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';

import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../models/game.dart';
import '../../models/prediction.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bet_slip_provider.dart';
import '../../providers/predictions_provider.dart';

class BetSlipSheet extends StatefulWidget {
  final Game game;
  final PredictionType type;
  final PredictionOutcome outcome;
  final double odds;
  final String label;
  final double? line;

  const BetSlipSheet({
    super.key,
    required this.game,
    required this.type,
    required this.outcome,
    required this.odds,
    required this.label,
    this.line,
  });

  static Future<void> show(
    BuildContext context, {
    required Game game,
    required PredictionType type,
    required PredictionOutcome outcome,
    required double odds,
    required String label,
    double? line,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BetSlipSheet(
        game: game,
        type: type,
        outcome: outcome,
        odds: odds,
        label: label,
        line: line,
      ),
    );
  }

  @override
  State<BetSlipSheet> createState() => _BetSlipSheetState();
}

class _BetSlipSheetState extends State<BetSlipSheet> {
  late ConfettiController _confettiController;
  double _stake = 100;
  bool _isPlacing = false;

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

  int get potentialPayout => (_stake * widget.odds).round();

  String _formatOdds(double odds) {
    return 'x${odds.toStringAsFixed(2)}';
  }

  String _getTypeDisplay(PredictionType type) {
    switch (type) {
      case PredictionType.moneyline:
        return 'Moneyline';
      case PredictionType.spread:
        return 'Spread';
      case PredictionType.total:
        return 'Total';
      case PredictionType.playerProp:
        return 'Player Prop';
    }
  }

  Future<void> _placeBet() async {
    final auth = context.read<AuthProvider>();
    final predictions = context.read<PredictionsProvider>();

    if ((auth.user?.coins ?? 0) < _stake.round()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Not enough coins!'),
          backgroundColor: AppColors.accentRed,
        ),
      );
      return;
    }

    setState(() => _isPlacing = true);

    // Deduct coins
    await auth.removeCoins(_stake.round());

    // Create prediction
    final prediction = Prediction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      gameId: widget.game.id,
      sportKey: widget.game.sportKey,
      homeTeam: widget.game.homeTeam.name,
      awayTeam: widget.game.awayTeam.name,
      type: widget.type,
      outcome: widget.outcome,
      odds: widget.odds,
      stake: _stake.round(),
      line: widget.line,
      gameStartTime: widget.game.startTime,
    );

    await predictions.addPrediction(prediction);

    _confettiController.play();

    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.accentGreen),
              const SizedBox(width: 8),
              Text('Bet placed! Potential win: $potentialPayout coins'),
            ],
          ),
          backgroundColor: AppColors.cardBackground,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final userCoins = auth.user?.coins ?? 0;
    final maxStake = userCoins.toDouble().clamp(10.0, 10000.0);

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.primaryDark,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Match info
                    Text(
                      '${widget.game.awayTeam.name} @ ${widget.game.homeTeam.name}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Bet selection
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.borderMedium,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.label,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _getTypeDisplay(widget.type),
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _formatOdds(widget.odds),
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Stake section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    // Stake label and value
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Stake',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(
                              Icons.monetization_on,
                              color: AppColors.gold,
                              size: 24,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _stake.round().toString(),
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Slider
                    SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: AppColors.accent,
                        inactiveTrackColor: AppColors.surfaceColor,
                        thumbColor: AppColors.accent,
                        overlayColor: AppColors.accent.withOpacity(0.2),
                        trackHeight: 8,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 14,
                        ),
                      ),
                      child: Slider(
                        value: _stake.clamp(10.0, maxStake),
                        min: 10.0,
                        max: maxStake,
                        divisions: ((maxStake - 10) / 10).round().clamp(1, 999),
                        onChanged: (value) {
                          setState(() {
                            _stake = ((value / 10).round() * 10).toDouble();
                          });
                        },
                      ),
                    ),

                    // Quick stake buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [100, 250, 500, 1000].map((amount) {
                        final isDisabled = amount > userCoins;
                        return GestureDetector(
                          onTap: isDisabled
                              ? null
                              : () => setState(() => _stake = amount.toDouble()),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: _stake == amount
                                  ? AppColors.accent
                                  : AppColors.surfaceColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '$amount',
                              style: TextStyle(
                                color: isDisabled
                                    ? AppColors.textMuted
                                    : _stake == amount
                                        ? Colors.black
                                        : AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 24),

                    // Potential payout
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.accentGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.accentGreen.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Potential Payout',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 16,
                            ),
                          ),
                          Row(
                            children: [
                              const Icon(
                                Icons.monetization_on,
                                color: AppColors.accentGreen,
                                size: 24,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                potentialPayout.toString(),
                                style: const TextStyle(
                                  color: AppColors.accentGreen,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Place bet button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isPlacing ? null : _placeBet,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isPlacing
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : const Text(
                                'Place Bet',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Balance reminder
                    Text(
                      'Your balance: $userCoins coins',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Confetti
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            particleDrag: 0.05,
            emissionFrequency: 0.05,
            numberOfParticles: 20,
            gravity: 0.2,
            colors: const [
              AppColors.accent,
              AppColors.accentGreen,
              AppColors.gold,
            ],
          ),
        ),
      ],
    );
  }
}
