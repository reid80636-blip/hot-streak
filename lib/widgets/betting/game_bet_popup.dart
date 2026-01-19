import 'dart:async';

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
import '../../providers/games_provider.dart';
import '../../providers/predictions_provider.dart';
import '../common/team_logo.dart';
import 'stake_popup.dart';

/// Stadium Live style bottom sheet for game betting with all options
class GameBetPopup extends StatefulWidget {
  final Game game;

  const GameBetPopup({super.key, required this.game});

  static Future<void> show(BuildContext context, Game game) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (context) => GameBetPopup(game: game),
    );
  }

  @override
  State<GameBetPopup> createState() => _GameBetPopupState();
}

class _GameBetPopupState extends State<GameBetPopup> {
  PredictionType _selectedType = PredictionType.moneyline;
  PredictionOutcome? _selectedOutcome;
  double? _selectedOdds;
  double? _selectedLine;
  double _stake = 100;
  bool _isPlacing = false;
  late ConfettiController _confettiController;
  Timer? _refreshTimer;
  late Game _game;

  Game get game => _game;

  @override
  void initState() {
    super.initState();
    _game = widget.game;
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));

    // Start auto-refresh for live games every 5 seconds
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    // Refresh immediately if game is live or recently started
    if (_game.isLive || !_game.isUpcoming) {
      _refreshGameData();
    }

    // Set up periodic refresh every 5 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        _refreshGameData();
      }
    });
  }

  Future<void> _refreshGameData() async {
    if (!mounted) return;

    final gamesProvider = context.read<GamesProvider>();
    final updatedGame = await gamesProvider.refreshGameById(_game.id);

    if (updatedGame != null && mounted) {
      setState(() {
        _game = updatedGame;
      });
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _confettiController.dispose();
    super.dispose();
  }

  String _formatOddsMultiplier(double odds) {
    return 'x${odds.toStringAsFixed(2)}';
  }

  String _getOutcomeLabel() {
    if (_selectedOutcome == null) return '';
    switch (_selectedOutcome!) {
      case PredictionOutcome.home:
        return game.homeTeam.name;
      case PredictionOutcome.away:
        return game.awayTeam.name;
      case PredictionOutcome.draw:
        return 'Draw';
      case PredictionOutcome.over:
        return 'Over ${_selectedLine?.toStringAsFixed(1) ?? ''}';
      case PredictionOutcome.under:
        return 'Under ${_selectedLine?.toStringAsFixed(1) ?? ''}';
    }
  }

  int get _potentialPayout => _selectedOdds != null ? (_stake * _selectedOdds!).round() : 0;

  void _selectBet(PredictionOutcome outcome, double odds, {double? line}) {
    HapticFeedback.selectionClick();

    // Close this popup and open StakePopup with selected bet
    Navigator.of(context).pop();

    StakePopup.show(
      context,
      game: _game,
      type: _selectedType,
      outcome: outcome,
      odds: odds,
      line: line,
    );
  }

  Future<void> _placeBet() async {
    if (_selectedOutcome == null || _selectedOdds == null) return;

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
      gameId: game.id,
      sportKey: game.sportKey,
      homeTeam: game.homeTeam.name,
      awayTeam: game.awayTeam.name,
      type: _selectedType,
      outcome: _selectedOutcome!,
      odds: _selectedOdds!,
      stake: totalStake,
      line: _selectedLine,
      gameStartTime: game.startTime,
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
    final userCoins = auth.user?.coins ?? 0;
    final maxStake = userCoins.toDouble().clamp(10.0, 10000.0);
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Stack(
      children: [
        // Dismiss on tap outside
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(color: Colors.transparent),
        ),

        // Bottom sheet content
        Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 500,
              maxHeight: screenHeight * 0.75,
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
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHandleBar(),
                    _buildGameHeader(),
                    _buildBetTypeSelector(),
                    const SizedBox(height: 12),
                    _buildOddsOptions(),
                    const SizedBox(height: 8),
                    // Hint text
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Tap odds to continue',
                        style: TextStyle(
                          color: AppColors.textMutedOp,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(height: bottomPadding + 16),
                  ],
                ),
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

  Widget _buildGameHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.glassDecoration(),
      child: Row(
        children: [
          // Away team
          Expanded(
            child: Column(
              children: [
                TeamLogo(
                  teamName: game.awayTeam.name,
                  size: 48,
                  logoUrl: game.awayTeam.logoUrl,
                ),
                const SizedBox(height: 8),
                Text(
                  game.awayTeam.name.split(' ').last,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // VS / Score
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                if (game.isLive || game.isFinished)
                  Text(
                    '${game.awayTeam.score ?? 0} - ${game.homeTeam.score ?? 0}',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                else
                  Text(
                    '@',
                    style: TextStyle(
                      color: AppColors.textMutedOp,
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: game.isLive
                        ? AppColors.accentGreen.withOpacity(0.2)
                        : AppColors.glassBackground(0.4),
                    borderRadius: BorderRadius.circular(AppRadius.round),
                    border: Border.all(
                      color: game.isLive
                          ? AppColors.accentGreen.withOpacity(0.4)
                          : AppColors.borderSubtle,
                    ),
                  ),
                  child: Text(
                    game.isLive
                        ? (game.gameTime ?? 'LIVE')
                        : game.isFinished
                            ? 'FINAL'
                            : game.displayTime,
                    style: TextStyle(
                      color: game.isLive ? AppColors.accentGreen : AppColors.textMutedOp,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Home team
          Expanded(
            child: Column(
              children: [
                TeamLogo(
                  teamName: game.homeTeam.name,
                  size: 48,
                  logoUrl: game.homeTeam.logoUrl,
                ),
                const SizedBox(height: 8),
                Text(
                  game.homeTeam.name.split(' ').last,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBetTypeSelector() {
    final types = [
      PredictionType.moneyline,
      if (!game.isSoccer && game.odds?.spreadLine != null) PredictionType.spread,
      if (game.odds?.totalLine != null) PredictionType.total,
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 48,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.glassBackground(0.4),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          children: types.map((type) => _buildSegment(type)).toList(),
        ),
      ),
    );
  }

  Widget _buildSegment(PredictionType type) {
    final isSelected = type == _selectedType;
    String label;
    switch (type) {
      case PredictionType.moneyline:
        label = 'Moneyline';
        break;
      case PredictionType.spread:
        label = 'Spread';
        break;
      case PredictionType.total:
        label = 'Total';
        break;
      default:
        label = type.name;
    }

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            _selectedType = type;
            _selectedOutcome = null;
            _selectedOdds = null;
            _selectedLine = null;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            gradient: isSelected ? AppColors.primaryGradient : null,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: isSelected ? [
              BoxShadow(
                color: AppColors.primaryGlow,
                blurRadius: 8,
              ),
            ] : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textSecondaryOp,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOddsOptions() {
    if (game.odds == null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Odds not available',
          style: TextStyle(color: AppColors.textMutedOp),
        ),
      );
    }

    final odds = game.odds!;

    switch (_selectedType) {
      case PredictionType.moneyline:
        return _buildMoneylineOptions(odds);
      case PredictionType.spread:
        return _buildSpreadOptions(odds);
      case PredictionType.total:
        return _buildTotalOptions(odds);
      default:
        return const SizedBox();
    }
  }

  Widget _buildMoneylineOptions(Odds odds) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildOddsCard(
            teamName: game.awayTeam.name,
            logoUrl: game.awayTeam.logoUrl,
            label: 'Away',
            odds: odds.away,
            outcome: PredictionOutcome.away,
          ),
          const SizedBox(width: 10),
          if (game.isSoccer && odds.draw != null) ...[
            _buildOddsCard(
              teamName: null,
              logoUrl: null,
              label: 'Draw',
              odds: odds.draw!,
              outcome: PredictionOutcome.draw,
              icon: Icons.compare_arrows,
            ),
            const SizedBox(width: 10),
          ],
          _buildOddsCard(
            teamName: game.homeTeam.name,
            logoUrl: game.homeTeam.logoUrl,
            label: 'Home',
            odds: odds.home,
            outcome: PredictionOutcome.home,
          ),
        ],
      ),
    );
  }

  Widget _buildSpreadOptions(Odds odds) {
    if (odds.spreadLine == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Spread not available', style: TextStyle(color: AppColors.textMutedOp)),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildOddsCard(
            teamName: game.awayTeam.name,
            logoUrl: game.awayTeam.logoUrl,
            label: '${(-odds.spreadLine!) > 0 ? '+' : ''}${(-odds.spreadLine!).toStringAsFixed(1)}',
            odds: odds.awaySpread ?? 1.91,
            outcome: PredictionOutcome.away,
            line: -odds.spreadLine!,
          ),
          const SizedBox(width: 10),
          _buildOddsCard(
            teamName: game.homeTeam.name,
            logoUrl: game.homeTeam.logoUrl,
            label: '${odds.spreadLine! > 0 ? '+' : ''}${odds.spreadLine!.toStringAsFixed(1)}',
            odds: odds.homeSpread ?? 1.91,
            outcome: PredictionOutcome.home,
            line: odds.spreadLine!,
          ),
        ],
      ),
    );
  }

  Widget _buildTotalOptions(Odds odds) {
    if (odds.totalLine == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Totals not available', style: TextStyle(color: AppColors.textMutedOp)),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildOddsCard(
            teamName: null,
            logoUrl: null,
            label: 'O ${odds.totalLine!.toStringAsFixed(1)}',
            odds: odds.overOdds ?? 1.91,
            outcome: PredictionOutcome.over,
            line: odds.totalLine!,
            icon: Icons.arrow_upward_rounded,
          ),
          const SizedBox(width: 10),
          _buildOddsCard(
            teamName: null,
            logoUrl: null,
            label: 'U ${odds.totalLine!.toStringAsFixed(1)}',
            odds: odds.underOdds ?? 1.91,
            outcome: PredictionOutcome.under,
            line: odds.totalLine!,
            icon: Icons.arrow_downward_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildOddsCard({
    required String? teamName,
    required String? logoUrl,
    required String label,
    required double odds,
    required PredictionOutcome outcome,
    double? line,
    IconData? icon,
  }) {
    final isSelected = _selectedOutcome == outcome;

    return Expanded(
      child: GestureDetector(
        onTap: () => _selectBet(outcome, odds, line: line),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: isSelected
              ? AppDecorations.glassActive()
              : AppDecorations.glassDecoration(opacity: 0.4),
          child: Column(
            children: [
              // Team logo or icon
              if (teamName != null)
                TeamLogo(teamName: teamName, size: 40, logoUrl: logoUrl)
              else
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.glassBackground(0.4),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.borderGlow),
                  ),
                  child: Icon(icon ?? Icons.sports, color: AppColors.accentCyan, size: 24),
                ),
              const SizedBox(height: 10),
              // Label
              Text(
                teamName?.split(' ').last ?? label,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (teamName != null)
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.textMutedOp,
                    fontSize: 11,
                  ),
                ),
              const SizedBox(height: 8),
              // Odds badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  gradient: isSelected ? AppColors.cyanGradient : null,
                  color: isSelected ? null : AppColors.glassBackground(0.4),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: isSelected ? null : Border.all(color: AppColors.borderGlow),
                  boxShadow: isSelected ? [
                    BoxShadow(
                      color: AppColors.cyanGlow,
                      blurRadius: 8,
                    ),
                  ] : null,
                ),
                child: Text(
                  _formatOddsMultiplier(odds),
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.accentCyan,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStakeSection(double maxStake) {
    final percentage = (_stake - 10) / (maxStake - 10);
    final isHighBet = percentage > 0.5;
    final isVeryHighBet = percentage > 0.8;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Stake display
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isVeryHighBet) ...[
                const Text('🔥', style: TextStyle(fontSize: 22))
                    .animate(onPlay: (c) => c.repeat())
                    .shake(duration: 500.ms, hz: 3),
                const SizedBox(width: 6),
              ],
              const Icon(Icons.monetization_on, color: AppColors.gold, size: 28),
              const SizedBox(width: 8),
              Text(
                _stake.round().toString(),
                style: TextStyle(
                  color: isVeryHighBet ? AppColors.orange : AppColors.textPrimary,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'coins',
                style: TextStyle(color: AppColors.textMutedOp, fontSize: 14),
              ),
              if (isVeryHighBet) ...[
                const SizedBox(width: 6),
                const Text('🔥', style: TextStyle(fontSize: 22))
                    .animate(onPlay: (c) => c.repeat())
                    .shake(duration: 500.ms, hz: 3),
              ],
            ],
          ),

          const SizedBox(height: 16),

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
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
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

          // Labels
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
                Text(maxStake.round().toString(),
                    style: TextStyle(color: AppColors.textMutedOp, fontSize: 11)),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Quick buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [50, 100, 250, 500, 1000]
                .where((amount) => amount <= maxStake)
                .map((amount) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _buildQuickAmountButton(amount),
                    ))
                .toList(),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildQuickAmountButton(int amount) {
    final isSelected = _stake.round() == amount;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _stake = amount.toDouble());
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected ? AppColors.primaryGradient : null,
          color: isSelected ? null : AppColors.glassBackground(0.4),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: isSelected
              ? null
              : Border.all(color: AppColors.borderSubtle),
          boxShadow: isSelected ? [
            BoxShadow(
              color: AppColors.primaryGlow,
              blurRadius: 8,
            ),
          ] : null,
        ),
        child: Text(
          amount.toString(),
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondaryOp,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildPayoutSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.accentGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.accentGreen.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Potential Win:',
            style: TextStyle(color: AppColors.textSecondaryOp, fontSize: 15),
          ),
          const SizedBox(width: 10),
          const Icon(Icons.monetization_on, color: AppColors.accentGreen, size: 24),
          const SizedBox(width: 6),
          Text(
            _potentialPayout.toString(),
            style: const TextStyle(
              color: AppColors.accentGreen,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceButton(int userCoins) {
    final canPlaceBet =
        _selectedOutcome != null && userCoins >= _stake.round() && !_isPlacing;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: Container(
          decoration: BoxDecoration(
            gradient: canPlaceBet ? AppColors.primaryGradient : null,
            color: canPlaceBet ? null : AppColors.glassBackground(0.4),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: canPlaceBet ? [
              BoxShadow(
                color: AppColors.primaryGlow,
                blurRadius: 12,
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
              disabledForegroundColor: AppColors.textMutedOp,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              elevation: 0,
            ),
            child: _isPlacing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.bolt, size: 22),
                      const SizedBox(width: 8),
                      const Text(
                        'Place Bet',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
