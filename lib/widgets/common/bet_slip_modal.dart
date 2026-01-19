import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';
import 'package:uuid/uuid.dart';

import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../config/design_system.dart';
import '../../models/prediction.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bet_slip_provider.dart';
import '../../providers/predictions_provider.dart';
import 'popup_nav_bar.dart';

class BetSlipModal extends StatefulWidget {
  const BetSlipModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const BetSlipModal(),
    );
  }

  @override
  State<BetSlipModal> createState() => _BetSlipModalState();
}

class _BetSlipModalState extends State<BetSlipModal>
    with SingleTickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _slideController;
  bool _isExpanded = false;
  bool _isPlacing = false;
  bool _isParlayMode = true; // Default to parlay when 2+ selections
  double _stake = 100;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    HapticFeedback.lightImpact();
  }

  String _formatOdds(double odds) {
    return 'x${odds.toStringAsFixed(2)}';
  }

  Future<void> _placeBets() async {
    final auth = context.read<AuthProvider>();
    final betSlip = context.read<BetSlipProvider>();
    final predictions = context.read<PredictionsProvider>();

    // Determine if we're placing as parlay (only applies when 2+ items)
    final isPlacingAsParlay = betSlip.items.length >= 2 && _isParlayMode;

    final totalStake = isPlacingAsParlay ? _stake.round() : betSlip.items.fold(0, (sum, item) => sum + _stake.round());

    if ((auth.user?.coins ?? 0) < totalStake) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Not enough coins!'),
          backgroundColor: AppColors.accentRed,
        ),
      );
      return;
    }

    setState(() => _isPlacing = true);
    HapticFeedback.heavyImpact();

    // Deduct coins
    await auth.removeCoins(totalStake);

    // Create predictions
    const uuid = Uuid();
    final newPredictions = <Prediction>[];

    if (isPlacingAsParlay) {
      // For parlay bets, create predictions with a shared parlayId
      final legs = betSlip.items.length;
      final multiplier = AppConstants.comboMultipliers[legs.clamp(2, 8)] ?? 2.0;
      final comboOdds = betSlip.comboOdds * multiplier;
      final parlayId = uuid.v4(); // Shared ID to group parlay legs
      final parlayLegs = legs;

      for (final item in betSlip.items) {
        newPredictions.add(Prediction(
          id: uuid.v4(),
          gameId: item.gameId,
          sportKey: item.sportKey,
          homeTeam: item.homeTeam,
          awayTeam: item.awayTeam,
          type: item.type,
          outcome: item.outcome,
          odds: comboOdds,
          stake: _stake.round(),
          line: item.line,
          gameStartTime: item.gameStartTime,
          parlayId: parlayId,
          parlayLegs: parlayLegs,
        ));
      }
    } else {
      // Individual bets
      for (final item in betSlip.items) {
        newPredictions.add(Prediction(
          id: uuid.v4(),
          gameId: item.gameId,
          sportKey: item.sportKey,
          homeTeam: item.homeTeam,
          awayTeam: item.awayTeam,
          type: item.type,
          outcome: item.outcome,
          odds: item.odds,
          stake: _stake.round(),
          line: item.line,
          gameStartTime: item.gameStartTime,
        ));
      }
    }

    await predictions.addPredictions(newPredictions);

    // Award XP for placing bets
    await auth.awardXpForBet(betCount: newPredictions.length, isParlay: isPlacingAsParlay);

    // Play celebration
    _confettiController.play();
    HapticFeedback.heavyImpact();

    // Store values before clearing
    final wasParlay = isPlacingAsParlay;
    final betCount = newPredictions.length;

    // Get scaffold messenger and navigator before async delay
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context, rootNavigator: false);

    await Future.delayed(const Duration(milliseconds: 1500));

    if (mounted) {
      betSlip.clear();
      navigator.pop();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.accentGreen),
              const SizedBox(width: 8),
              Text(
                wasParlay
                    ? 'Parlay placed! Good luck!'
                    : '$betCount bet${betCount > 1 ? 's' : ''} placed!',
              ),
            ],
          ),
          backgroundColor: AppColors.cardBackground,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final betSlip = context.watch<BetSlipProvider>();
    final auth = context.watch<AuthProvider>();
    final userCoins = auth.user?.coins ?? 0;
    final maxStake = userCoins.toDouble().clamp(10.0, 10000.0);

    final screenHeight = MediaQuery.of(context).size.height;
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    final modalHeight = _isExpanded ? screenHeight * 0.9 : screenHeight * 0.6;

    return Stack(
      children: [
        // Dismiss on tap outside
        GestureDetector(
          onTap: () => Navigator.of(context, rootNavigator: false).pop(),
          child: Container(color: Colors.transparent),
        ),

        // Modal content - centered on large screens
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              height: modalHeight,
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
                  children: [
                    // Handle bar and header
                    _buildHeader(betSlip),

                    // Bet items list
                    Expanded(
                      child: betSlip.isEmpty
                          ? _buildEmptyState()
                          : _buildBetsList(betSlip),
                    ),

                    // Bottom section with stake and place button
                    if (!betSlip.isEmpty)
                      _buildBottomSection(betSlip, userCoins, maxStake),

                    // Navigation bar - always visible
                    Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPadding + 8),
                      child: const PopupNavBar(),
                    ),
                  ],
                ),
              ),
            ).animate().slideY(begin: 1, end: 0, duration: 300.ms, curve: Curves.easeOutCubic),
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

  Widget _buildHeader(BetSlipProvider betSlip) {
    return Column(
      children: [
        // Handle bar
        GestureDetector(
          onTap: _toggleExpanded,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: AppDecorations.handleBar(),
            ),
          ),
        ),

        // Header row
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Row(
            children: [
              // Title with count badge
              Row(
                children: [
                  Text(
                    'Bet Slip',
                    style: AppTypography.heading2(),
                  ),
                  if (!betSlip.isEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: AppColors.cyanGradient,
                        borderRadius: BorderRadius.circular(AppRadius.round),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.cyanGlow,
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Text(
                        '${betSlip.itemCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              const Spacer(),

              // Expand/collapse button
              IconButton(
                onPressed: _toggleExpanded,
                icon: AnimatedRotation(
                  turns: _isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_up,
                    color: AppColors.textSecondaryOp,
                  ),
                ),
              ),

              // Clear all button
              if (!betSlip.isEmpty)
                TextButton(
                  onPressed: () {
                    betSlip.clear();
                    HapticFeedback.mediumImpact();
                  },
                  child: const Text(
                    'Clear',
                    style: TextStyle(color: AppColors.accentRed),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long,
            size: 64,
            color: AppColors.textMutedOp,
          ),
          const SizedBox(height: 16),
          Text(
            'Your bet slip is empty',
            style: TextStyle(
              color: AppColors.textSecondaryOp,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap on odds to add bets',
            style: TextStyle(
              color: AppColors.textMutedOp,
              fontSize: 14,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildBetsList(BetSlipProvider betSlip) {
    // If 2+ items, show parlay card at top with compact legs
    if (betSlip.items.length >= 2) {
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            // Mode toggle (Parlay vs Singles)
            _buildModeToggle(betSlip),
            const SizedBox(height: 12),

            // Parlay card OR individual bets based on mode
            if (_isParlayMode)
              _buildParlayCard(betSlip)
            else
              ...betSlip.items.asMap().entries.map((entry) {
                return _buildBetItem(entry.value, entry.key, betSlip)
                    .animate()
                    .fadeIn(delay: Duration(milliseconds: entry.key * 50))
                    .slideX(begin: 0.1, end: 0);
              }),
          ],
        ),
      );
    }

    // Single bet - show normally
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: betSlip.items.length,
      itemBuilder: (context, index) {
        final item = betSlip.items[index];
        return _buildBetItem(item, index, betSlip)
            .animate()
            .fadeIn(delay: Duration(milliseconds: index * 50))
            .slideX(begin: 0.1, end: 0);
      },
    );
  }

  /// Parlay/Singles mode toggle
  Widget _buildModeToggle(BetSlipProvider betSlip) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.glassBackground(0.4),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _isParlayMode = true);
                HapticFeedback.selectionClick();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: _isParlayMode ? AppColors.primaryGradient : null,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  boxShadow: _isParlayMode ? [
                    BoxShadow(
                      color: AppColors.primaryGlow,
                      blurRadius: 8,
                    ),
                  ] : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.layers,
                      size: 18,
                      color: _isParlayMode ? Colors.white : AppColors.textMutedOp,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Parlay',
                      style: TextStyle(
                        color: _isParlayMode ? Colors.white : AppColors.textSecondaryOp,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _isParlayMode
                            ? Colors.white.withOpacity(0.2)
                            : AppColors.accentCyan.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${AppConstants.comboMultipliers[betSlip.items.length.clamp(2, 8)] ?? 2.0}x',
                        style: TextStyle(
                          color: _isParlayMode ? Colors.white : AppColors.accentCyan,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _isParlayMode = false);
                HapticFeedback.selectionClick();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: !_isParlayMode ? AppColors.primaryGradient : null,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  boxShadow: !_isParlayMode ? [
                    BoxShadow(
                      color: AppColors.primaryGlow,
                      blurRadius: 8,
                    ),
                  ] : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.receipt_long,
                      size: 18,
                      color: !_isParlayMode ? Colors.white : AppColors.textMutedOp,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Singles',
                      style: TextStyle(
                        color: !_isParlayMode ? Colors.white : AppColors.textSecondaryOp,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The main parlay card with all the details
  Widget _buildParlayCard(BetSlipProvider betSlip) {
    final legs = betSlip.items.length;
    final baseOdds = betSlip.comboOdds;
    final multiplier = AppConstants.comboMultipliers[legs.clamp(2, 8)] ?? 2.0;
    final combinedOdds = baseOdds * multiplier;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.glassBackground(0.6),
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        border: Border.all(
          color: AppColors.borderGlow,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.cyanGlow,
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.accent.withOpacity(0.2),
                  AppColors.accentCyan.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl - 2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryGlow,
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.layers, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PARLAY',
                        style: TextStyle(
                          color: AppColors.accentCyan,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      Text(
                        '$legs Leg${legs > 1 ? 's' : ''}',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                // Multiplier badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: AppColors.winGradient,
                    borderRadius: BorderRadius.circular(AppRadius.round),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.successGlow,
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Text(
                    '${multiplier}x BONUS',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Odds breakdown
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Combined odds display
                _buildOddsRow('Base Odds', 'x${baseOdds.toStringAsFixed(2)}', false),
                const SizedBox(height: 8),
                _buildOddsRow('Parlay Bonus', '${multiplier}x', true),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(color: AppColors.borderSubtle, height: 1),
                ),
                // Final combined odds
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Combined Odds',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: AppColors.cyanGradient,
                        borderRadius: BorderRadius.circular(AppRadius.round),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.cyanGlow,
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Text(
                        'x${combinedOdds.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Legs list
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.glassBackground(0.3),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Column(
              children: [
                ...betSlip.items.asMap().entries.map((entry) {
                  final item = entry.value;
                  final index = entry.key;
                  return _buildCompactLeg(item, index, betSlip, isLast: index == betSlip.items.length - 1);
                }),
              ],
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1));
  }

  Widget _buildOddsRow(String label, String value, bool isBonus) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isBonus ? AppColors.accentGreen : AppColors.textSecondaryOp,
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: isBonus ? AppColors.accentGreen : AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactLeg(BetSlipItem item, int index, BetSlipProvider betSlip, {required bool isLast}) {
    // Get sport emoji
    String sportEmoji = '🎯';
    if (item.sportKey.contains('nfl') || item.sportKey.contains('ncaaf')) {
      sportEmoji = '🏈';
    } else if (item.sportKey.contains('nba') || item.sportKey.contains('ncaab')) {
      sportEmoji = '🏀';
    } else if (item.sportKey.contains('soccer')) {
      sportEmoji = '⚽';
    } else if (item.sportKey.contains('mlb')) {
      sportEmoji = '⚾';
    } else if (item.sportKey.contains('nhl')) {
      sportEmoji = '🏒';
    }

    return Container(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10, top: index == 0 ? 0 : 10),
      decoration: BoxDecoration(
        border: isLast ? null : Border(
          bottom: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      child: Row(
        children: [
          Text(sportEmoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.outcomeDisplay,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  item.matchDisplay,
                  style: TextStyle(
                    color: AppColors.textMutedOp,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.glassBackground(0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borderGlow),
            ),
            child: Text(
              'x${item.odds.toStringAsFixed(2)}',
              style: const TextStyle(
                color: AppColors.accentCyan,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              betSlip.removeItem(index);
              HapticFeedback.lightImpact();
            },
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.accentRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.close,
                color: AppColors.accentRed,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBetItem(BetSlipItem item, int index, BetSlipProvider betSlip) {
    return Dismissible(
      key: Key('${item.gameId}_${item.type}_${item.outcome}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        betSlip.removeItem(index);
        HapticFeedback.mediumImpact();
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.accentRed.withOpacity(0.2),
          borderRadius: BorderRadius.circular(AppRadius.xxl),
        ),
        child: const Icon(Icons.delete, color: AppColors.accentRed),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: AppDecorations.glassDecoration(),
        child: Row(
          children: [
            // Bet info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Outcome
                  Text(
                    item.outcomeDisplay,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Match
                  Text(
                    item.matchDisplay,
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

            // Odds badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: AppColors.cyanGradient,
                borderRadius: BorderRadius.circular(AppRadius.round),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.cyanGlow,
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Text(
                _formatOdds(item.odds),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // Remove button
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () {
                betSlip.removeItem(index);
                HapticFeedback.lightImpact();
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.glassBackground(0.4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Icon(
                  Icons.close,
                  color: AppColors.textMutedOp,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSection(
    BetSlipProvider betSlip,
    int userCoins,
    double maxStake,
  ) {
    // Determine if placing as parlay (only when 2+ items and parlay mode)
    final isPlacingAsParlay = betSlip.items.length >= 2 && _isParlayMode;
    final legs = betSlip.items.length;
    final multiplier = AppConstants.comboMultipliers[legs.clamp(2, 8)] ?? 2.0;

    final potentialPayout = isPlacingAsParlay
        ? (_stake * betSlip.comboOdds * multiplier).round()
        : betSlip.items.fold<int>(0, (sum, item) => sum + (_stake * item.odds).round());

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.glassBackground(0.6),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: AppColors.borderGlow)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Stake with animated coin slider
          _CoinSlider(
            value: _stake,
            min: 10.0,
            max: maxStake,
            onChanged: (value) {
              setState(() {
                _stake = ((value / 10).round() * 10).toDouble();
              });
            },
          ),

          const SizedBox(height: 12),

          // Quick stake buttons - compact
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
                          color: isDisabled ? AppColors.textDim
                              : isSelected ? Colors.white : AppColors.textPrimary,
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

          const SizedBox(height: 12),

          // Payout + Place bet in one row
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
                        isPlacingAsParlay ? 'Parlay Payout' : 'Payout',
                        style: TextStyle(color: AppColors.textMutedOp, fontSize: 11),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.monetization_on, color: AppColors.accentGreen, size: 20),
                          const SizedBox(width: 4),
                          _AnimatedNumber(
                            value: potentialPayout,
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
              const SizedBox(width: 12),
              // Place bet button
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 54,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryGlow,
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isPlacing ? null : _placeBets,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                      ),
                      child: _isPlacing
                          ? const SizedBox(
                              width: 24, height: 24,
                              child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.bolt, size: 20),
                                const SizedBox(width: 6),
                                Text(
                                  isPlacingAsParlay ? 'Place Parlay' : 'Place Bet${betSlip.items.length > 1 ? 's' : ''}',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),

        ],
      ),
    );
  }
}

// Animated number display
class _AnimatedNumber extends StatelessWidget {
  final int value;
  final TextStyle style;

  const _AnimatedNumber({
    super.key,
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

// Custom animated slider
class _AnimatedSlider extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _AnimatedSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  State<_AnimatedSlider> createState() => _AnimatedSliderState();
}

class _AnimatedSliderState extends State<_AnimatedSlider>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderThemeData(
        activeTrackColor: AppColors.accentCyan,
        inactiveTrackColor: AppColors.glassBackground(0.4),
        thumbColor: AppColors.accentCyan,
        overlayColor: AppColors.accentCyan.withOpacity(0.2),
        trackHeight: 10,
        thumbShape: _AnimatedThumbShape(
          enabledThumbRadius: _isDragging ? 18 : 14,
        ),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 28),
      ),
      child: Slider(
        value: widget.value,
        min: widget.min,
        max: widget.max,
        divisions: ((widget.max - widget.min) / 10).round().clamp(1, 999),
        onChangeStart: (_) {
          setState(() => _isDragging = true);
          _pulseController.forward();
        },
        onChangeEnd: (_) {
          setState(() => _isDragging = false);
          _pulseController.reverse();
        },
        onChanged: widget.onChanged,
      ),
    );
  }
}

class _AnimatedThumbShape extends SliderComponentShape {
  final double enabledThumbRadius;

  const _AnimatedThumbShape({
    required this.enabledThumbRadius,
  });

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size.fromRadius(enabledThumbRadius);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;

    // Outer glow
    final glowPaint = Paint()
      ..color = AppColors.accentCyan.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(center, enabledThumbRadius + 4, glowPaint);

    // Main thumb
    final thumbPaint = Paint()
      ..color = AppColors.accentCyan
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, enabledThumbRadius, thumbPaint);

    // Inner highlight
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(center.dx - 3, center.dy - 3),
      enabledThumbRadius * 0.4,
      highlightPaint,
    );
  }
}

// Simple slider with fire animation for high bets
class _CoinSlider extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _CoinSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = (value - min) / (max - min);
    final isHighBet = percentage > 0.5;
    final isVeryHighBet = percentage > 0.8;

    return Column(
      children: [
        // Stake display with fire for high bets
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isVeryHighBet) ...[
              const Text('🔥', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 4),
            ],
            const Icon(Icons.monetization_on, color: AppColors.gold, size: 28),
            const SizedBox(width: 8),
            Text(
              value.round().toString(),
              style: TextStyle(
                color: isVeryHighBet ? AppColors.orange : AppColors.textPrimary,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              ' coins',
              style: TextStyle(color: AppColors.textMutedOp, fontSize: 14),
            ),
            if (isVeryHighBet) ...[
              const SizedBox(width: 4),
              const Text('🔥', style: TextStyle(fontSize: 24)),
            ],
          ],
        ),

        const SizedBox(height: 12),

        // Normal slider with fire track for high bets
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: isVeryHighBet
                ? AppColors.orange
                : isHighBet
                    ? AppColors.accentCyan
                    : AppColors.accentCyan,
            inactiveTrackColor: AppColors.glassBackground(0.4),
            thumbColor: isVeryHighBet ? AppColors.orange : AppColors.accentCyan,
            overlayColor: (isVeryHighBet ? AppColors.orange : AppColors.accentCyan).withOpacity(0.2),
            trackHeight: 8,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: ((max - min) / 10).round().clamp(1, 999),
            onChanged: (newValue) {
              onChanged(newValue);
              if (newValue >= max * 0.8) {
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
              Text('${min.round()}', style: TextStyle(color: AppColors.textMutedOp, fontSize: 11)),
              if (isHighBet)
                Text(
                  isVeryHighBet ? '🔥 HIGH ROLLER 🔥' : 'Going big!',
                  style: TextStyle(
                    color: isVeryHighBet ? AppColors.orange : AppColors.accentCyan,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              Text('${max.round()}', style: TextStyle(color: AppColors.textMutedOp, fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }
}
