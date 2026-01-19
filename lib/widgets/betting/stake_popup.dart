import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:confetti/confetti.dart';

import '../../config/theme.dart';
import '../../models/game.dart';
import '../../models/prediction.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bet_slip_provider.dart';
import '../../providers/predictions_provider.dart';
import '../../providers/games_provider.dart';
import '../common/team_logo.dart';

/// Premium stake popup matching the reference design - Blue Aura Theme
/// Centered dialog style with glass morphism effects
class StakePopup extends StatefulWidget {
  final Game game;
  final PredictionType type;
  final PredictionOutcome outcome;
  final double odds;
  final double? line;

  const StakePopup({
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
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (context) => StakePopup(
        game: game,
        type: type,
        outcome: outcome,
        odds: odds,
        line: line,
      ),
    );
  }

  @override
  State<StakePopup> createState() => _StakePopupState();
}

class _StakePopupState extends State<StakePopup> {
  double _stake = 1000;
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

  String _getOutcomeLabel() {
    switch (widget.outcome) {
      case PredictionOutcome.home:
        return '${widget.game.homeTeam.name} Win';
      case PredictionOutcome.away:
        return '${widget.game.awayTeam.name} Win';
      case PredictionOutcome.draw:
        return 'Draw';
      case PredictionOutcome.over:
        return 'Over ${widget.line?.toStringAsFixed(1) ?? ''}';
      case PredictionOutcome.under:
        return 'Under ${widget.line?.toStringAsFixed(1) ?? ''}';
    }
  }

  String _getGameLabel() {
    final away = widget.game.awayTeam.name.length > 3
        ? widget.game.awayTeam.name.substring(0, 3).toUpperCase()
        : widget.game.awayTeam.name.toUpperCase();
    final home = widget.game.homeTeam.name.length > 3
        ? widget.game.homeTeam.name.substring(0, 3).toUpperCase()
        : widget.game.homeTeam.name.toUpperCase();
    return '$away ${widget.game.awayTeam.name} @ $home ${widget.game.homeTeam.name}';
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

  /// Add to bet slip for combo building
  void _addToSlip() {
    final betSlip = context.read<BetSlipProvider>();

    betSlip.addItem(
      widget.game,
      widget.type,
      widget.outcome,
      widget.odds,
      line: widget.line,
    );

    HapticFeedback.mediumImpact();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.add_circle, color: AppColors.accentCyan, size: 20),
            const SizedBox(width: 8),
            const Text('Added to combo'),
          ],
        ),
        backgroundColor: AppColors.cardBackground,
        duration: const Duration(seconds: 1),
      ),
    );

    setState(() {});
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
              Text('Locked in ${_getOutcomeLabel()}!'),
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
    final maxStake = userCoins.toDouble().clamp(10.0, 50000.0);
    final screenSize = MediaQuery.of(context).size;

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

        // Main dialog
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 380,
              maxHeight: screenSize.height * 0.85,
            ),
            child: Container(
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF1E3A5F), // Glass blue
                    Color(0xFF0A1628), // Primary dark
                  ],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: const Color(0xFF00D4FF).withOpacity(0.4),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00D4FF).withOpacity(0.3),
                    blurRadius: 40,
                    spreadRadius: 5,
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.6),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildHeader(userCoins),
                      _buildSelectedBet(),
                      _buildMakeCombo(betSlip, isInSlip),
                      _buildBoostStake(),
                      _buildAmountSection(maxStake),
                      _buildLockInButton(userCoins),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ).animate().fadeIn(duration: 200.ms).scale(
                  begin: const Offset(0.9, 0.9),
                  end: const Offset(1, 1),
                  duration: 250.ms,
                  curve: Curves.easeOutBack,
                ),
          ),
        ),

        // Confetti
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            particleDrag: 0.03,
            emissionFrequency: 0.03,
            numberOfParticles: 40,
            gravity: 0.1,
            shouldLoop: false,
            colors: const [
              Color(0xFFFFD700),
              Color(0xFF00D4FF),
              Color(0xFF00A3FF),
              Color(0xFF00FF7F),
              Colors.white,
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(int userCoins) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Row(
        children: [
          // Single Stake logo/icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF00D4FF).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF00D4FF).withOpacity(0.3),
              ),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: Color(0xFF00D4FF),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'SINGLE STAKE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const Spacer(),
          // Balance display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFFFD700).withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                const Text(
                  'Balance',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.monetization_on,
                  color: Color(0xFFFFD700),
                  size: 18,
                ),
                const SizedBox(width: 4),
                Text(
                  _formatNumber(userCoins),
                  style: const TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FF7F).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add,
                    color: Color(0xFF00FF7F),
                    size: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedBet() {
    final showTeamLogo = widget.outcome == PredictionOutcome.home ||
        widget.outcome == PredictionOutcome.away;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          // Team logo or icon
          if (showTeamLogo)
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: TeamLogo(
                  teamName: _getTeamNameForLogo(),
                  size: 44,
                  logoUrl: _getTeamLogoUrl(),
                ),
              ),
            )
          else
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF00D4FF).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF00D4FF).withOpacity(0.3),
                ),
              ),
              child: Icon(
                widget.outcome == PredictionOutcome.over
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                color: const Color(0xFF00D4FF),
                size: 24,
              ),
            ),
          const SizedBox(width: 12),

          // Bet details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getOutcomeLabel(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.game.awayTeam.name} @ ${widget.game.homeTeam.name}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Odds badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF00D4FF).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF00D4FF).withOpacity(0.4),
              ),
            ),
            child: Text(
              '${widget.odds.toStringAsFixed(2)}x',
              style: const TextStyle(
                color: Color(0xFF00D4FF),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Remove button
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close,
                color: Colors.white.withOpacity(0.6),
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMakeCombo(BetSlipProvider betSlip, bool isInSlip) {
    // Get suggested games for combo
    final gamesProvider = context.read<GamesProvider>();
    final suggestedGames = gamesProvider.upcomingGames
        .where((g) => g.id != widget.game.id && g.odds != null)
        .take(2)
        .toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      child: Column(
        children: [
          // Header row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF00D4FF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.layers,
                  color: Color(0xFF00D4FF),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Make A Combo',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              // Add Stake button
              GestureDetector(
                onTap: isInSlip ? null : _addToSlip,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: isInSlip
                        ? null
                        : const LinearGradient(
                            colors: [Color(0xFF00D4FF), Color(0xFF00A3FF)],
                          ),
                    color: isInSlip ? Colors.white.withOpacity(0.1) : null,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isInSlip ? Icons.check : Icons.add,
                        color: isInSlip ? Colors.white54 : Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isInSlip ? 'Added' : 'Add Stake',
                        style: TextStyle(
                          color: isInSlip ? Colors.white54 : Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Suggested picks
          if (suggestedGames.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: suggestedGames.map((game) {
                return Expanded(
                  child: _buildSuggestedPick(game),
                );
              }).toList(),
            ),
          ],

          // Combo count indicator
          if (betSlip.itemCount > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF00D4FF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${betSlip.itemCount} pick${betSlip.itemCount > 1 ? 's' : ''} in combo • ${betSlip.comboOdds.toStringAsFixed(2)}x',
                style: const TextStyle(
                  color: Color(0xFF00D4FF),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSuggestedPick(Game game) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          // Add button
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF00D4FF).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.add,
              color: Color(0xFF00D4FF),
              size: 14,
            ),
          ),
          const SizedBox(width: 8),
          // Team info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${game.awayTeam.name.split(' ').last} @ ${game.homeTeam.name.split(' ').last}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Odds
          if (game.odds != null)
            Text(
              '${game.odds!.home.toStringAsFixed(2)}x',
              style: const TextStyle(
                color: Color(0xFF00D4FF),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBoostStake() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.bolt,
              color: Color(0xFFFFD700),
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Boost Stake',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFFFD700).withOpacity(0.3),
              ),
            ),
            child: const Icon(
              Icons.bolt,
              color: Color(0xFFFFD700),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountSection(double maxStake) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        children: [
          // Amount and Payout row
          Row(
            children: [
              // Amount
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Amount',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.monetization_on,
                            color: Color(0xFFFFD700),
                            size: 24,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _formatNumber(_stake.round()),
                            style: const TextStyle(
                              color: Colors.white,
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
              const SizedBox(width: 12),
              // Payout
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FF7F).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF00FF7F).withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payout',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.monetization_on,
                            color: Color(0xFF00FF7F),
                            size: 24,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _formatNumber(_potentialPayout),
                            style: const TextStyle(
                              color: Color(0xFF00FF7F),
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
            ],
          ),

          const SizedBox(height: 16),

          // Slider with golden track
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: const Color(0xFFFFD700),
                inactiveTrackColor: Colors.white.withOpacity(0.1),
                thumbColor: const Color(0xFFFFD700),
                overlayColor: const Color(0xFFFFD700).withOpacity(0.2),
                trackHeight: 6,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
              ),
              child: Slider(
                value: _stake.clamp(10, maxStake),
                min: 10,
                max: maxStake,
                divisions: ((maxStake - 10) / 50).round().clamp(1, 999),
                onChanged: (newValue) {
                  setState(() {
                    _stake = ((newValue / 50).round() * 50).toDouble().clamp(10, maxStake);
                  });
                  HapticFeedback.selectionClick();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockInButton(int userCoins) {
    final canPlaceBet = userCoins >= _stake.round() && !_isPlacing;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: canPlaceBet
            ? const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
              )
            : null,
        color: canPlaceBet ? null : Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(28),
        boxShadow: canPlaceBet
            ? [
                BoxShadow(
                  color: const Color(0xFFFFD700).withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: canPlaceBet ? _placeBet : null,
          borderRadius: BorderRadius.circular(28),
          child: Center(
            child: _isPlacing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Color(0xFF1A1A1F),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Coin icons on left
                      const Icon(
                        Icons.fast_forward,
                        color: Color(0xFF1A1A1F),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      // Lock icon
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.monetization_on,
                          color: Color(0xFF1A1A1F),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'LOCK IN',
                        style: TextStyle(
                          color: canPlaceBet ? const Color(0xFF1A1A1F) : Colors.white38,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Coin icons on right
                      const Icon(
                        Icons.fast_rewind,
                        color: Color(0xFF1A1A1F),
                        size: 20,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(number >= 10000 ? 0 : 1)}K';
    }
    return number.toString();
  }
}
