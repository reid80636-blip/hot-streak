import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:confetti/confetti.dart';

import '../../config/theme.dart';
import '../../config/design_system.dart';
import '../../models/game.dart';
import '../../models/prediction.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bet_slip_provider.dart';
import '../../providers/predictions_provider.dart';
import '../common/team_logo.dart';
import '../common/bet_slip_modal.dart';
import '../common/popup_nav_bar.dart';

/// Stadium Live style bottom sheet for placing a single bet or adding to slip
class QuickBetPopup extends StatefulWidget {
  final Game game;
  final PredictionType type;
  final PredictionOutcome outcome;
  final double odds;
  final double? line;

  const QuickBetPopup({
    super.key,
    required this.game,
    required this.type,
    required this.outcome,
    required this.odds,
    this.line,
  });

  static Future<void> show(
    BuildContext context, {
    required Game game,
    required PredictionType type,
    required PredictionOutcome outcome,
    required double odds,
    double? line,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (context) => QuickBetPopup(
        game: game,
        type: type,
        outcome: outcome,
        odds: odds,
        line: line,
      ),
    );
  }

  @override
  State<QuickBetPopup> createState() => _QuickBetPopupState();
}

class _QuickBetPopupState extends State<QuickBetPopup> {
  double _stake = 100;
  bool _isPlacing = false;
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

  String _formatOddsMultiplier(double odds) {
    return 'x${odds.toStringAsFixed(2)}';
  }

  String _getOutcomeLabel() {
    switch (widget.outcome) {
      case PredictionOutcome.home:
        return widget.game.homeTeam.name;
      case PredictionOutcome.away:
        return widget.game.awayTeam.name;
      case PredictionOutcome.draw:
        return 'Draw';
      case PredictionOutcome.over:
        return 'Over ${widget.line?.toStringAsFixed(1) ?? ''}';
      case PredictionOutcome.under:
        return 'Under ${widget.line?.toStringAsFixed(1) ?? ''}';
    }
  }

  String _getTypeLabel() {
    switch (widget.type) {
      case PredictionType.moneyline:
        return 'Moneyline';
      case PredictionType.spread:
        final line = widget.line ?? 0;
        return 'Spread ${line > 0 ? '+' : ''}${line.toStringAsFixed(1)}';
      case PredictionType.total:
        return 'Total';
      case PredictionType.playerProp:
        return 'Player Prop';
    }
  }

  String? _getTeamLogoUrl() {
    switch (widget.outcome) {
      case PredictionOutcome.home:
        return widget.game.homeTeam.logoUrl;
      case PredictionOutcome.away:
        return widget.game.awayTeam.logoUrl;
      default:
        return null;
    }
  }

  String _getTeamNameForLogo() {
    switch (widget.outcome) {
      case PredictionOutcome.home:
        return widget.game.homeTeam.name;
      case PredictionOutcome.away:
        return widget.game.awayTeam.name;
      default:
        return widget.game.homeTeam.name;
    }
  }

  int get _potentialPayout => (_stake * widget.odds).round();

  /// Add to bet slip for parlay building
  void _addToSlip() {
    final betSlip = context.read<BetSlipProvider>();
    final navigator = Navigator.of(context);
    final currentContext = context;

    // Add to bet slip
    betSlip.addItem(
      widget.game,
      widget.type,
      widget.outcome,
      widget.odds,
      line: widget.line,
    );

    HapticFeedback.mediumImpact();

    // Close this popup and show the bet slip modal
    navigator.pop();

    // Show bet slip modal after a brief delay
    Future.delayed(const Duration(milliseconds: 100), () {
      if (currentContext.mounted) {
        BetSlipModal.show(currentContext);
      }
    });
  }

  Future<void> _placeBet() async {
    final auth = context.read<AuthProvider>();
    final predictions = context.read<PredictionsProvider>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final totalStake = _stake.round();

    if ((auth.user?.coins ?? 0) < totalStake) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Not enough coins!'),
          backgroundColor: AppColors.accentRed,
        ),
      );
      return;
    }

    setState(() => _isPlacing = true);
    HapticFeedback.heavyImpact();

    await auth.removeCoins(totalStake);

    const uuid = Uuid();
    final prediction = Prediction(
      id: uuid.v4(),
      gameId: widget.game.id,
      sportKey: widget.game.sportKey,
      homeTeam: widget.game.homeTeam.name,
      awayTeam: widget.game.awayTeam.name,
      type: widget.type,
      outcome: widget.outcome,
      odds: widget.odds,
      stake: totalStake,
      line: widget.line,
      gameStartTime: widget.game.startTime,
    );

    await predictions.addPredictions([prediction]);

    // Award XP for placing bet
    await auth.awardXpForBet(betCount: 1, isParlay: false);

    _confettiController.play();
    HapticFeedback.heavyImpact();

    await Future.delayed(const Duration(milliseconds: 1200));

    if (mounted) {
      navigator.pop();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.accentGreen),
              const SizedBox(width: 8),
              Text('Bet placed on ${_getOutcomeLabel()}!'),
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
    final betSlip = context.watch<BetSlipProvider>();
    final userCoins = auth.user?.coins ?? 0;
    final maxStake = userCoins.toDouble().clamp(10.0, 10000.0);
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    // Check if this bet is already in the slip
    final isInSlip = betSlip.hasItem(
      widget.game.id,
      widget.type,
      widget.outcome,
    );

    return Stack(
      children: [
        // Dismiss on tap outside
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(color: Colors.transparent),
        ),

        // Modal content - centered on screen (Stadium Live style)
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 500,
              maxHeight: screenHeight * 0.7,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.primaryDark,
                borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxxl)),
                border: Border.all(color: AppColors.borderGlow),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.cyanGlow,
                    blurRadius: 30,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHandleBar(),
                  _buildGameCard(isInSlip),
                  // Bottom section with dark background (Stadium Live style)
                  _buildBottomSection(userCoins, maxStake, bottomPadding, betSlip, isInSlip),
                  // Navigation bar - always visible at bottom
                  Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding + 8),
                    child: const PopupNavBar(),
                  ),
                ],
              ),
            ).animate().slideY(
              begin: 1,
              end: 0,
              duration: 300.ms,
              curve: Curves.easeOutCubic,
            ),
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
            numberOfParticles: 30,
            gravity: 0.1,
            shouldLoop: false,
            colors: const [
              AppColors.accent,
              AppColors.accentCyan,
              AppColors.accentGreen,
              AppColors.gold,
              Colors.white,
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHandleBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: AppDecorations.handleBar(),
      ),
    );
  }

  Widget _buildGameCard(bool isInSlip) {
    final showTeamLogo = widget.outcome == PredictionOutcome.home ||
        widget.outcome == PredictionOutcome.away;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: isInSlip
          ? AppDecorations.glassActive()
          : AppDecorations.glassDecoration(),
      child: Row(
        children: [
          // Team/outcome logo
          if (showTeamLogo)
            TeamLogo(
              teamName: _getTeamNameForLogo(),
              size: 52,
              logoUrl: _getTeamLogoUrl(),
            )
          else
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.glassBackground(0.4),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.borderGlow),
              ),
              child: Icon(
                widget.outcome == PredictionOutcome.over
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                color: AppColors.accentCyan,
                size: 28,
              ),
            ),
          const SizedBox(width: 14),

          // Bet details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _getOutcomeLabel(),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isInSlip)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          gradient: AppColors.cyanGradient,
                          borderRadius: BorderRadius.circular(AppRadius.round),
                        ),
                        child: const Text(
                          'IN SLIP',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.game.awayTeam.name} @ ${widget.game.homeTeam.name}',
                  style: TextStyle(
                    color: AppColors.textSecondaryOp,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Odds badge
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: AppColors.cyanGradient,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.cyanGlow,
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Text(
                  _formatOddsMultiplier(widget.odds),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _getTypeLabel(),
                style: TextStyle(
                  color: AppColors.textMutedOp,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Stadium Live style bottom section with dark background
  Widget _buildBottomSection(
    int userCoins,
    double maxStake,
    double bottomPadding,
    BetSlipProvider betSlip,
    bool isInSlip,
  ) {
    final percentage = (_stake - 10) / (maxStake - 10);
    final isHighBet = percentage > 0.5;
    final isVeryHighBet = percentage > 0.8;
    final canPlaceBet = userCoins >= _stake.round() && !_isPlacing;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.glassBackground(0.4),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: AppColors.borderGlow)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Stake display with fire for high bets
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isVeryHighBet) ...[
                const Text('🔥', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 4),
              ],
              const Icon(Icons.monetization_on, color: AppColors.gold, size: 24),
              const SizedBox(width: 6),
              Text(
                _stake.round().toString(),
                style: TextStyle(
                  color: isVeryHighBet ? AppColors.orange : AppColors.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                ' coins',
                style: TextStyle(color: AppColors.textMutedOp, fontSize: 12),
              ),
              if (isVeryHighBet) ...[
                const SizedBox(width: 4),
                const Text('🔥', style: TextStyle(fontSize: 20)),
              ],
            ],
          ),

          const SizedBox(height: 8),

          // Slider
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: isVeryHighBet ? AppColors.orange : AppColors.accentCyan,
              inactiveTrackColor: AppColors.glassBackground(0.4),
              thumbColor: isVeryHighBet ? AppColors.orange : AppColors.accentCyan,
              overlayColor: (isVeryHighBet ? AppColors.orange : AppColors.accentCyan)
                  .withOpacity(0.2),
              trackHeight: 8,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14),
            ),
            child: Slider(
              value: _stake.clamp(10, maxStake),
              min: 10,
              max: maxStake,
              divisions: ((maxStake - 10) / 10).round().clamp(1, 999),
              onChanged: (newValue) {
                setState(() {
                  _stake = ((newValue / 10).round() * 10).toDouble();
                });
                if (newValue >= maxStake * 0.8) {
                  HapticFeedback.heavyImpact();
                } else {
                  HapticFeedback.selectionClick();
                }
              },
            ),
          ),

          // Min/Max labels
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('10', style: TextStyle(color: AppColors.textMutedOp, fontSize: 11)),
                if (isHighBet)
                  Text(
                    isVeryHighBet ? '🔥 HIGH ROLLER 🔥' : 'Going big!',
                    style: TextStyle(
                      color: isVeryHighBet ? AppColors.orange : AppColors.accentCyan,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                Text('${maxStake.round()}', style: TextStyle(color: AppColors.textMutedOp, fontSize: 11)),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Quick stake buttons - fill width like Stadium Live
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [50, 100, 250, 500, 1000].map((amount) {
              final isDisabled = amount > userCoins;
              final isSelected = _stake.round() == amount;
              return Expanded(
                child: GestureDetector(
                  onTap: isDisabled ? null : () {
                    setState(() => _stake = amount.toDouble());
                    HapticFeedback.lightImpact();
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      gradient: isSelected ? AppColors.primaryGradient : null,
                      color: isSelected ? null : AppColors.glassBackground(0.4),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(
                        color: isSelected ? Colors.transparent : AppColors.borderSubtle,
                      ),
                      boxShadow: isSelected ? [
                        BoxShadow(
                          color: AppColors.primaryGlow,
                          blurRadius: 6,
                        ),
                      ] : null,
                    ),
                    child: Center(
                      child: Text(
                        '$amount',
                        style: TextStyle(
                          color: isDisabled
                              ? AppColors.textDim
                              : isSelected
                                  ? Colors.white
                                  : AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 8),

          // Payout + buttons row (Stadium Live style)
          Row(
            children: [
              // Payout box
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.accentGreen.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                      color: AppColors.accentGreen.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payout',
                        style: TextStyle(color: AppColors.textMutedOp, fontSize: 11),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.monetization_on, color: AppColors.accentGreen, size: 20),
                          const SizedBox(width: 4),
                          _AnimatedNumber(
                            value: _potentialPayout,
                            style: const TextStyle(
                              color: AppColors.accentGreen,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Add to Slip button
              Expanded(
                child: SizedBox(
                  height: 54,
                  child: OutlinedButton(
                    onPressed: isInSlip ? null : _addToSlip,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accentCyan,
                      side: BorderSide(
                        color: isInSlip ? AppColors.textDim : AppColors.borderGlow,
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isInSlip ? Icons.check : Icons.add,
                              size: 16,
                              color: isInSlip ? AppColors.textDim : AppColors.accentCyan,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isInSlip ? 'Added' : 'Add',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isInSlip ? AppColors.textDim : AppColors.accentCyan,
                              ),
                            ),
                          ],
                        ),
                        if (betSlip.itemCount > 0 && !isInSlip)
                          Text(
                            '${betSlip.itemCount} in slip',
                            style: TextStyle(
                              fontSize: 9,
                              color: AppColors.textMutedOp,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Place bet button
              Expanded(
                child: SizedBox(
                  height: 54,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: canPlaceBet ? AppColors.primaryGradient : null,
                      color: canPlaceBet ? null : AppColors.glassBackground(0.4),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      boxShadow: canPlaceBet ? [
                        BoxShadow(
                          color: AppColors.primaryGlow,
                          blurRadius: 8,
                        ),
                      ] : null,
                    ),
                    child: ElevatedButton(
                      onPressed: canPlaceBet ? _placeBet : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.transparent,
                        disabledForegroundColor: AppColors.textDim,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                        elevation: 0,
                      ),
                      child: _isPlacing
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: Colors.white,
                              ),
                            )
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.bolt, size: 18),
                                Text(
                                  'Bet',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Parlay hint when items in slip
          if (betSlip.itemCount > 0) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                Navigator.of(context).pop();
                BetSlipModal.show(context);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.accentCyan.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.accentCyan.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.layers, color: AppColors.accentCyan, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '${betSlip.itemCount} pick${betSlip.itemCount > 1 ? 's' : ''} in parlay',
                      style: const TextStyle(
                        color: AppColors.accentCyan,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_ios, color: AppColors.accentCyan, size: 14),
                  ],
                ),
              ),
            ),
          ],

        ],
      ),
    );
  }
}

/// Animated number display for smooth payout transitions
class _AnimatedNumber extends StatelessWidget {
  final int value;
  final TextStyle style;

  const _AnimatedNumber({
    required this.value,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, child) {
        return Text(
          animatedValue.toString(),
          style: style,
        );
      },
    );
  }
}
