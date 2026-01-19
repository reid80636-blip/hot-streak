import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../config/design_system.dart';
import '../../models/game.dart';
import '../../models/prediction.dart';
import '../../models/sport.dart';
import '../../providers/bet_slip_provider.dart';
import '../betting/game_bet_popup.dart';
import '../betting/stake_popup.dart';
import 'team_logo.dart';

class GameCard extends StatelessWidget {
  final Game game;
  final bool showSportBadge;
  final VoidCallback? onTap;

  const GameCard({
    super.key,
    required this.game,
    this.showSportBadge = true,
    this.onTap,
  });

  String _formatOdds(double odds) {
    return 'x${odds.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final sport = Sport.fromKey(game.sportKey);
    final dateFormat = DateFormat('E, MMM d • h:mm a');

    return GestureDetector(
      onTap: onTap ?? () => GameBetPopup.show(context, game),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: game.isLive
            ? AppDecorations.glassLive()
            : AppDecorations.glassDecoration(),
        child: Column(
          children: [
            // Header with sport and time
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  if (showSportBadge && sport != null) ...[
                    _SportLogoBadge(sport: sport),
                    const Spacer(),
                  ],
                  if (game.isLive)
                    _buildLiveBadge()
                  else
                    Text(
                      dateFormat.format(game.startTime.toLocal()),
                      style: TextStyle(
                        color: AppColors.textSubtle,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),

            // Teams
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Away team
                  Expanded(
                    child: Row(
                      children: [
                        TeamLogo(teamName: game.awayTeam.name, size: 44, logoUrl: game.awayTeam.logoUrl),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                game.awayTeam.name,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (game.isLive || game.isFinished)
                                Text(
                                  '${game.awayTeam.score ?? 0}',
                                  style: TextStyle(
                                    color: _isWinning(game.awayTeam.score, game.homeTeam.score)
                                        ? AppColors.accentCyan
                                        : AppColors.textSubtle,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // VS or @
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      game.isLive || game.isFinished ? '-' : '@',
                      style: TextStyle(
                        color: AppColors.textDim,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  // Home team
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                game.homeTeam.name,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.end,
                              ),
                              if (game.isLive || game.isFinished)
                                Text(
                                  '${game.homeTeam.score ?? 0}',
                                  style: TextStyle(
                                    color: _isWinning(game.homeTeam.score, game.awayTeam.score)
                                        ? AppColors.accentCyan
                                        : AppColors.textSubtle,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        TeamLogo(teamName: game.homeTeam.name, size: 44, logoUrl: game.homeTeam.logoUrl),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Odds - tappable to add to bet slip (only for upcoming games)
            if (game.odds != null && !game.isFinished && !game.isLive) ...[
              Consumer<BetSlipProvider>(
                builder: (context, betSlip, child) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.glassBackground(0.3),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(AppRadius.xxl),
                        bottomRight: Radius.circular(AppRadius.xxl),
                      ),
                      border: Border(
                        top: BorderSide(color: AppColors.borderSubtle),
                      ),
                    ),
                    child: Row(
                      children: [
                        _OddsButton(
                          label: game.awayTeam.name.split(' ').last,
                          odds: _formatOdds(game.odds!.away),
                          isHighlighted: betSlip.hasItem(game.id, PredictionType.moneyline, PredictionOutcome.away),
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            // Go directly to stake popup with away team selected
                            StakePopup.show(
                              context,
                              game: game,
                              type: PredictionType.moneyline,
                              outcome: PredictionOutcome.away,
                              odds: game.odds!.away,
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        if (game.isSoccer && game.odds!.draw != null) ...[
                          _OddsButton(
                            label: 'Draw',
                            odds: _formatOdds(game.odds!.draw!),
                            isHighlighted: betSlip.hasItem(game.id, PredictionType.moneyline, PredictionOutcome.draw),
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              // Go directly to stake popup with draw selected
                              StakePopup.show(
                                context,
                                game: game,
                                type: PredictionType.moneyline,
                                outcome: PredictionOutcome.draw,
                                odds: game.odds!.draw!,
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                        ],
                        _OddsButton(
                          label: game.homeTeam.name.split(' ').last,
                          odds: _formatOdds(game.odds!.home),
                          isHighlighted: betSlip.hasItem(game.id, PredictionType.moneyline, PredictionOutcome.home),
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            // Go directly to stake popup with home team selected
                            StakePopup.show(
                              context,
                              game: game,
                              type: PredictionType.moneyline,
                              outcome: PredictionOutcome.home,
                              odds: game.odds!.home,
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ] else
              const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  bool _isWinning(int? score1, int? score2) {
    if (score1 == null || score2 == null) return false;
    return score1 > score2;
  }

  Widget _buildLiveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: AppColors.liveGradient,
        borderRadius: BorderRadius.circular(AppRadius.round),
        boxShadow: [
          BoxShadow(
            color: AppColors.liveGlow,
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.6),
                  blurRadius: 4,
                ),
              ],
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .fadeIn(duration: 800.ms)
              .then()
              .fadeOut(duration: 800.ms),
          const SizedBox(width: 6),
          const Text(
            'LIVE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _OddsButton extends StatelessWidget {
  final String label;
  final String odds;
  final bool isHighlighted;
  final VoidCallback? onTap;

  const _OddsButton({
    required this.label,
    required this.odds,
    this.isHighlighted = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: isHighlighted
              ? BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryGlow,
                      blurRadius: 12,
                    ),
                  ],
                )
              : BoxDecoration(
                  color: AppColors.glassBackground(0.5),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: AppColors.borderGlow,
                  ),
                ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isHighlighted ? Colors.white.withOpacity(0.9) : AppColors.textSubtle,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                odds,
                style: TextStyle(
                  color: isHighlighted ? Colors.white : AppColors.accentCyan,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Polished sport logo badge with actual league logo - compact size
class _SportLogoBadge extends StatelessWidget {
  final Sport sport;

  const _SportLogoBadge({required this.sport});

  @override
  Widget build(BuildContext context) {
    // Get display name - shorten for soccer leagues
    String displayName = sport.shortName;
    if (sport.key.startsWith('soccer_')) {
      displayName = 'Soccer';
    } else if (displayName == 'College Football') {
      displayName = 'CFB';
    } else if (displayName == 'College Basketball') {
      displayName = 'CBB';
    }

    return Container(
      padding: const EdgeInsets.only(left: 3, right: 10, top: 3, bottom: 3),
      decoration: BoxDecoration(
        color: AppColors.glassBackground(0.5),
        borderRadius: BorderRadius.circular(AppRadius.round),
        border: Border.all(
          color: AppColors.borderGlow,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // League logo in white circle
          Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: sport.logoUrl != null
                    ? Image.network(
                        sport.logoUrl!,
                        width: 16,
                        height: 16,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Center(
                          child: Text(
                            sport.emoji,
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          sport.emoji,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Sport name - consistent white/cyan color
          Text(
            displayName,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Smaller sport logo badge for featured cards
class _SportLogoBadgeSmall extends StatelessWidget {
  final Sport sport;

  const _SportLogoBadgeSmall({required this.sport});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.borderGlow,
          width: 1,
        ),
      ),
      child: ClipOval(
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: sport.logoUrl != null
              ? Image.network(
                  sport.logoUrl!,
                  width: 14,
                  height: 14,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Center(
                    child: Text(
                      sport.emoji,
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                )
              : Center(
                  child: Text(
                    sport.emoji,
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
        ),
      ),
    );
  }
}

class FeaturedGameCard extends StatelessWidget {
  final Game game;

  const FeaturedGameCard({super.key, required this.game});

  String _formatOdds(double odds) {
    return 'x${odds.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final sport = Sport.fromKey(game.sportKey);

    return GestureDetector(
      onTap: () => GameBetPopup.show(context, game),
      child: Container(
        width: 180,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: AppColors.glassBackground(0.6),
          borderRadius: BorderRadius.circular(AppRadius.xxl),
          border: Border.all(
            color: sport?.color.withOpacity(0.4) ?? AppColors.borderGlow,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.cyanGlow,
              blurRadius: 20,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Sport badge and time
              Row(
                children: [
                  if (sport != null)
                    _SportLogoBadgeSmall(sport: sport),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: game.isLive
                          ? AppColors.liveRed.withOpacity(0.2)
                          : AppColors.glassBackground(0.4),
                      borderRadius: BorderRadius.circular(AppRadius.round),
                      border: Border.all(
                        color: game.isLive
                            ? AppColors.liveRed.withOpacity(0.4)
                            : AppColors.borderSubtle,
                      ),
                    ),
                    child: Text(
                      game.displayTime,
                      style: TextStyle(
                        color: game.isLive ? AppColors.liveRed : AppColors.textSubtle,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Teams with logos
              Row(
                children: [
                  TeamLogoCircle(teamName: game.awayTeam.name, size: 26),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      game.awayTeam.name.split(' ').last,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TeamLogoCircle(teamName: game.homeTeam.name, size: 26),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '@ ${game.homeTeam.name.split(' ').last}',
                      style: TextStyle(
                        color: AppColors.textSubtle,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Odds display
              if (game.odds != null)
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.glassBackground(0.4),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.borderGlow),
                        ),
                        child: Center(
                          child: Text(
                            _formatOdds(game.odds!.away),
                            style: const TextStyle(
                              color: AppColors.accentCyan,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.glassBackground(0.4),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.borderGlow),
                        ),
                        child: Center(
                          child: Text(
                            _formatOdds(game.odds!.home),
                            style: const TextStyle(
                              color: AppColors.accentCyan,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
