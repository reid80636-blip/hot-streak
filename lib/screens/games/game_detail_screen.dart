import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../models/game.dart';
import '../../models/prediction.dart';
import '../../models/sport.dart';
import '../../providers/games_provider.dart';
import '../../providers/bet_slip_provider.dart';
import '../../widgets/betting/game_bet_popup.dart';
import '../../widgets/common/bet_slip_modal.dart';

class GameDetailScreen extends StatelessWidget {
  final String gameId;

  const GameDetailScreen({super.key, required this.gameId});

  @override
  Widget build(BuildContext context) {
    return Consumer<GamesProvider>(
      builder: (context, gamesProvider, child) {
        final game = gamesProvider.getGameById(gameId);

        if (game == null) {
          return Scaffold(
            backgroundColor: AppColors.primaryDark,
            appBar: AppBar(backgroundColor: Colors.transparent),
            body: const Center(
              child: Text(
                'Game not found',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          );
        }

        return _GameDetailContent(game: game);
      },
    );
  }
}

class _GameDetailContent extends StatelessWidget {
  final Game game;

  const _GameDetailContent({required this.game});

  @override
  Widget build(BuildContext context) {
    final sport = Sport.fromKey(game.sportKey);
    final dateFormat = DateFormat('EEEE, MMMM d • h:mm a');

    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: CustomScrollView(
        slivers: [
          // App bar
          SliverAppBar(
            backgroundColor: AppColors.primaryDark,
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      sport?.color.withOpacity(0.3) ?? AppColors.accent.withOpacity(0.3),
                      AppColors.primaryDark,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      // Sport badge
                      if (sport != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: sport.color.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(sport.emoji),
                              const SizedBox(width: 6),
                              Text(
                                sport.name,
                                style: TextStyle(
                                  color: sport.color,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                      // Teams
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              game.awayTeam.name,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              game.isLive || game.isFinished ? 'vs' : '@',
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              game.homeTeam.name,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Date/time
                      Text(
                        game.isLive
                            ? 'LIVE NOW'
                            : dateFormat.format(game.startTime.toLocal()),
                        style: TextStyle(
                          color: game.isLive ? AppColors.accentGreen : AppColors.textSecondary,
                          fontWeight: game.isLive ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Prediction options
          if (game.odds != null && !game.isFinished) ...[
            // Moneyline section
            SliverToBoxAdapter(
              child: _PredictionSection(
                title: 'Moneyline',
                subtitle: 'Pick the winner',
                child: Row(
                  children: [
                    _OddsTile(
                      label: game.awayTeam.name,
                      odds: game.odds!.away,
                      game: game,
                      type: PredictionType.moneyline,
                      outcome: PredictionOutcome.away,
                    ),
                    const SizedBox(width: 8),
                    if (game.isSoccer && game.odds!.draw != null)
                      _OddsTile(
                        label: 'Draw',
                        odds: game.odds!.draw!,
                        game: game,
                        type: PredictionType.moneyline,
                        outcome: PredictionOutcome.draw,
                      ),
                    if (game.isSoccer && game.odds!.draw != null)
                      const SizedBox(width: 8),
                    _OddsTile(
                      label: game.homeTeam.name,
                      odds: game.odds!.home,
                      game: game,
                      type: PredictionType.moneyline,
                      outcome: PredictionOutcome.home,
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0),
            ),

            // Spread section (for non-soccer)
            if (!game.isSoccer && game.odds!.spreadLine != null)
              SliverToBoxAdapter(
                child: _PredictionSection(
                  title: 'Spread',
                  subtitle: 'Point spread betting',
                  child: Row(
                    children: [
                      _OddsTile(
                        label: game.awayTeam.name,
                        odds: game.odds!.awaySpread ?? 1.91,
                        game: game,
                        type: PredictionType.spread,
                        outcome: PredictionOutcome.away,
                        line: -(game.odds!.spreadLine ?? 0),
                      ),
                      const SizedBox(width: 8),
                      _OddsTile(
                        label: game.homeTeam.name,
                        odds: game.odds!.homeSpread ?? 1.91,
                        game: game,
                        type: PredictionType.spread,
                        outcome: PredictionOutcome.home,
                        line: game.odds!.spreadLine,
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0),
              ),

            // Total section
            if (game.odds!.totalLine != null)
              SliverToBoxAdapter(
                child: _PredictionSection(
                  title: 'Total',
                  subtitle: 'Over/Under ${game.odds!.totalLine}',
                  child: Row(
                    children: [
                      _OddsTile(
                        label: 'Over',
                        odds: game.odds!.overOdds ?? 1.91,
                        game: game,
                        type: PredictionType.total,
                        outcome: PredictionOutcome.over,
                        line: game.odds!.totalLine,
                      ),
                      const SizedBox(width: 8),
                      _OddsTile(
                        label: 'Under',
                        odds: game.odds!.underOdds ?? 1.91,
                        game: game,
                        type: PredictionType.total,
                        outcome: PredictionOutcome.under,
                        line: game.odds!.totalLine,
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1, end: 0),
              ),
          ],

          // No odds message
          if (game.odds == null || game.isFinished)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        game.isFinished ? Icons.sports_score : Icons.hourglass_empty,
                        size: 48,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        game.isFinished
                            ? 'This game has ended'
                            : 'Odds not available yet',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Bottom padding
          const SliverToBoxAdapter(
            child: SizedBox(height: 100),
          ),
        ],
      ),
      bottomNavigationBar: Consumer<BetSlipProvider>(
        builder: (context, betSlip, child) {
          if (betSlip.isEmpty) return const SizedBox.shrink();

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryDark,
              border: Border(
                top: BorderSide(color: AppColors.borderSubtle),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: ElevatedButton(
                onPressed: () => BetSlipModal.show(context),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.receipt_long, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'View Bet Slip',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${betSlip.itemCount}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ).animate().slideY(begin: 1, end: 0, duration: 300.ms, curve: Curves.easeOut);
        },
      ),
    );
  }
}

class _PredictionSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _PredictionSection({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _OddsTile extends StatelessWidget {
  final String label;
  final double odds;
  final Game game;
  final PredictionType type;
  final PredictionOutcome outcome;
  final double? line;

  const _OddsTile({
    required this.label,
    required this.odds,
    required this.game,
    required this.type,
    required this.outcome,
    this.line,
  });

  String _formatOdds(double odds) {
    return 'x${odds.toStringAsFixed(2)}';
  }

  String _formatLine(double? line) {
    if (line == null) return '';
    if (line > 0) return '+${line.toStringAsFixed(1)}';
    return line.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Consumer<BetSlipProvider>(
        builder: (context, betSlip, child) {
          final isSelected = betSlip.hasItem(game.id, type, outcome);

          return GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              GameBetPopup.show(context, game);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.accent.withOpacity(0.2)
                    : AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppColors.accent : AppColors.borderSubtle,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  if (line != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _formatLine(line),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    _formatOdds(odds),
                    style: TextStyle(
                      color: isSelected ? AppColors.accent : AppColors.accentGreen,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
