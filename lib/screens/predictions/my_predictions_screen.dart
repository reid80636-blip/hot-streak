import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../config/design_system.dart';
import '../../models/prediction.dart';
import '../../models/game_score.dart';
import '../../providers/auth_provider.dart';
import '../../providers/predictions_provider.dart';
import '../../services/settlement_service.dart';
import '../../services/settlement_coordinator.dart';

class MyPredictionsScreen extends StatefulWidget {
  const MyPredictionsScreen({super.key});

  @override
  State<MyPredictionsScreen> createState() => _MyPredictionsScreenState();
}

class _MyPredictionsScreenState extends State<MyPredictionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _isSettling = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PredictionsProvider>().loadPredictions().then((_) {
        _runSettlement();
      });
    });
  }

  /// Run the settlement process to check for finished games and settle bets
  Future<void> _runSettlement() async {
    if (!mounted || _isSettling) return;

    final auth = context.read<AuthProvider>();
    final predictions = context.read<PredictionsProvider>();

    // Only run if there are eligible predictions
    if (!predictions.hasEligiblePredictions) return;

    setState(() => _isSettling = true);

    final coordinator = SettlementCoordinator(
      settlementService: SettlementService(),
      predictionsProvider: predictions,
      authProvider: auth,
    );

    final summary = await coordinator.runSettlement();

    if (mounted) {
      setState(() => _isSettling = false);

      // Show notification if any bets were settled
      if (summary.settledCount > 0) {
        _showSettlementNotification(summary);
      }
    }
  }

  /// Show a snackbar notification about settled bets
  void _showSettlementNotification(SettlementSummary summary) {
    final hasWins = summary.wins > 0 || summary.parlaysWon > 0;
    final totalWins = summary.wins + summary.parlaysWon;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              hasWins ? Icons.celebration : Icons.sports_score,
              color: hasWins ? AppColors.gold : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hasWins
                    ? '$totalWins bet(s) won! +${summary.totalWinnings} coins'
                    : '${summary.settledCount} bet(s) settled',
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.cardBackground,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Refresh predictions and run settlement
  Future<void> _onRefresh() async {
    await context.read<PredictionsProvider>().loadPredictions();
    await _runSettlement();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: SafeArea(
        child: Column(
          children: [
            // Premium Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'My Picks',
                        style: GoogleFonts.lora(
                          color: AppColors.textPrimary,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Track your predictions',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Consumer<PredictionsProvider>(
                    builder: (context, predictions, child) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.accentGreen.withOpacity(0.15),
                              AppColors.accentGreen.withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.accentGreen.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.trending_up,
                              color: AppColors.accentGreen,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${predictions.winRate.toStringAsFixed(1)}%',
                              style: GoogleFonts.lora(
                                color: AppColors.accentGreen,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Premium Tab bar - Blue Aura style
            Container(
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.glassBackground(0.6),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.borderGlow),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.cyanGlow,
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  gradient: AppColors.cyanGradient,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.cyanGlow,
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.textMutedOp,
                labelStyle: GoogleFonts.lora(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                tabs: const [
                  Tab(text: 'Pending'),
                  Tab(text: 'Settled'),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Settlement indicator
            if (_isSettling)
              Container(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accentCyan,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Checking game results...',
                      style: TextStyle(
                        color: AppColors.textSecondaryOp,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  RefreshIndicator(
                    onRefresh: _onRefresh,
                    child: _PredictionsList(filter: 'pending'),
                  ),
                  RefreshIndicator(
                    onRefresh: _onRefresh,
                    child: _PredictionsList(filter: 'settled'),
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

class _PredictionsList extends StatelessWidget {
  final String filter;

  const _PredictionsList({required this.filter});

  // Group predictions by parlayId
  List<dynamic> _groupPredictions(List<Prediction> predictions) {
    final grouped = <dynamic>[];
    final parlayMap = <String, List<Prediction>>{};

    for (final prediction in predictions) {
      if (prediction.parlayId != null) {
        parlayMap.putIfAbsent(prediction.parlayId!, () => []);
        parlayMap[prediction.parlayId!]!.add(prediction);
      } else {
        grouped.add(prediction);
      }
    }

    // Add parlay groups
    for (final parlayPredictions in parlayMap.values) {
      grouped.add(parlayPredictions);
    }

    // Sort by creation date (most recent first)
    grouped.sort((a, b) {
      final aDate = a is List<Prediction> ? a.first.createdAt : (a as Prediction).createdAt;
      final bDate = b is List<Prediction> ? b.first.createdAt : (b as Prediction).createdAt;
      return bDate.compareTo(aDate);
    });

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PredictionsProvider>(
      builder: (context, predictionsProvider, child) {
        final predictions = filter == 'pending'
            ? predictionsProvider.pendingPredictions
            : predictionsProvider.settledPredictions;

        if (predictions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  filter == 'pending'
                      ? Icons.hourglass_empty
                      : Icons.history,
                  size: 64,
                  color: AppColors.textMuted,
                ),
                const SizedBox(height: 16),
                Text(
                  filter == 'pending'
                      ? 'No pending predictions'
                      : 'No settled predictions yet',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        final groupedItems = _groupPredictions(predictions);

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
          itemCount: groupedItems.length,
          itemBuilder: (context, index) {
            final item = groupedItems[index];
            if (item is List<Prediction>) {
              return _ParlayCard(predictions: item)
                  .animate(delay: (index * 50).ms)
                  .fadeIn()
                  .slideX(begin: 0.05, end: 0);
            }
            return _PredictionCard(prediction: item as Prediction)
                .animate(delay: (index * 50).ms)
                .fadeIn()
                .slideX(begin: 0.05, end: 0);
          },
        );
      },
    );
  }
}

class _PredictionCard extends StatelessWidget {
  final Prediction prediction;

  const _PredictionCard({required this.prediction});

  String _formatOdds(double odds) {
    return 'x${odds.toStringAsFixed(2)}';
  }

  String _getGameStatusText() {
    final now = DateTime.now();
    final gameTime = prediction.gameStartTime;

    if (gameTime.isAfter(now)) {
      final dateFormat = DateFormat('MMM d, h:mm a');
      return dateFormat.format(gameTime.toLocal());
    }

    final hoursSinceStart = now.difference(gameTime).inHours;
    if (!prediction.isSettled) {
      if (hoursSinceStart < 4) {
        return 'In Progress';
      }
      return 'Awaiting Result';
    }

    return '';
  }

  Color _getGameStatusColor() {
    final now = DateTime.now();
    final gameTime = prediction.gameStartTime;

    if (prediction.isSettled) {
      return AppColors.textSecondary;
    }
    if (gameTime.isAfter(now)) {
      return AppColors.textMuted;
    }
    final hoursSinceStart = now.difference(gameTime).inHours;
    if (hoursSinceStart < 4) {
      return AppColors.accentGreen;
    }
    return AppColors.orange;
  }

  String _getWinnerName() {
    if (!prediction.hasScores) return '';
    final homeWon = prediction.finalHomeScore! > prediction.finalAwayScore!;
    final awayWon = prediction.finalAwayScore! > prediction.finalHomeScore!;
    if (homeWon) return prediction.homeTeam;
    if (awayWon) return prediction.awayTeam;
    return 'Draw';
  }

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (prediction.status) {
      case PredictionStatus.pending:
        statusColor = AppColors.orange;
        statusIcon = Icons.schedule;
        statusText = 'Pending';
        break;
      case PredictionStatus.won:
        statusColor = AppColors.accentGreen;
        statusIcon = Icons.check_circle;
        statusText = 'Won';
        break;
      case PredictionStatus.lost:
        statusColor = AppColors.accentRed;
        statusIcon = Icons.cancel;
        statusText = 'Lost';
        break;
      case PredictionStatus.push:
        statusColor = AppColors.textMuted;
        statusIcon = Icons.remove_circle;
        statusText = 'Push';
        break;
      case PredictionStatus.cancelled:
        statusColor = AppColors.textMuted;
        statusIcon = Icons.block;
        statusText = 'Cancelled';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.glassBackground(0.6),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: prediction.isSettled
              ? statusColor.withOpacity(0.4)
              : AppColors.borderGlow,
          width: prediction.isSettled ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: prediction.isSettled && prediction.isWon
                ? AppColors.successGlow
                : AppColors.cyanGlow,
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with matchup and status
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${prediction.awayTeam} @ ${prediction.homeTeam}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (!prediction.isSettled) ...[
                        const SizedBox(height: 4),
                        Text(
                          _getGameStatusText(),
                          style: TextStyle(
                            color: _getGameStatusColor(),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: statusColor.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 13, color: statusColor),
                      const SizedBox(width: 5),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Clean Bet Box with Lora italic bold styling - Blue Aura
          Container(
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primaryDark,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: AppColors.accentCyan.withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        prediction.outcomeDisplay,
                        style: GoogleFonts.lora(
                          color: AppColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        prediction.typeDisplay,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.accentGreen.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _formatOdds(prediction.odds),
                    style: GoogleFonts.lora(
                      color: AppColors.accentGreen,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Final score display when settled
          if (prediction.isSettled && prediction.hasScores)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: statusColor.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  // Score
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryDark,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${prediction.finalAwayScore} - ${prediction.finalHomeScore}',
                      style: GoogleFonts.lora(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Winner
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.emoji_events, size: 16, color: AppColors.gold),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _getWinnerName(),
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
                  ),
                ],
              ),
            ),

          const SizedBox(height: 12),

          // Bottom stats - clean layout
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Row(
              children: [
                // Stake
                _StatBox(
                  label: 'Stake',
                  value: '${prediction.stake}',
                  valueColor: AppColors.textPrimary,
                ),
                const SizedBox(width: 12),
                Container(
                  width: 1,
                  height: 30,
                  color: AppColors.borderSubtle,
                ),
                const SizedBox(width: 12),
                // Payout
                _StatBox(
                  label: prediction.isSettled ? 'Payout' : 'To Win',
                  value: prediction.isSettled
                      ? '${prediction.payout ?? 0}'
                      : '${prediction.potentialPayout}',
                  valueColor: prediction.isWon
                      ? AppColors.accentGreen
                      : prediction.isLost
                          ? AppColors.accentRed
                          : AppColors.gold,
                  isHighlighted: prediction.isWon,
                ),
                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final bool isHighlighted;

  const _StatBox({
    required this.label,
    required this.value,
    required this.valueColor,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Icon(
              Icons.monetization_on,
              color: isHighlighted ? AppColors.accentGreen : AppColors.gold,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              value,
              style: GoogleFonts.lora(
                color: valueColor,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ParlayCard extends StatelessWidget {
  final List<Prediction> predictions;

  const _ParlayCard({required this.predictions});

  String _getLegWinnerName(Prediction prediction) {
    if (!prediction.hasScores) return '';
    final homeWon = prediction.finalHomeScore! > prediction.finalAwayScore!;
    final awayWon = prediction.finalAwayScore! > prediction.finalHomeScore!;
    if (homeWon) return prediction.homeTeam;
    if (awayWon) return prediction.awayTeam;
    return 'Draw';
  }

  @override
  Widget build(BuildContext context) {
    final first = predictions.first;
    final stake = first.stake;
    final potentialPayout = first.potentialPayout;
    final multiplier = predictions.length;

    final allWon = predictions.every((p) => p.isWon);
    final anyLost = predictions.any((p) => p.isLost);
    final allSettled = predictions.every((p) => p.isSettled);

    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (anyLost) {
      statusColor = AppColors.accentRed;
      statusIcon = Icons.cancel;
      statusText = 'Lost';
    } else if (allWon) {
      statusColor = AppColors.accentGreen;
      statusIcon = Icons.check_circle;
      statusText = 'Won';
    } else if (allSettled) {
      statusColor = AppColors.textMuted;
      statusIcon = Icons.remove_circle;
      statusText = 'Push';
    } else {
      statusColor = AppColors.orange;
      statusIcon = Icons.schedule;
      statusText = 'Pending';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.glassBackground(0.6),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: AppColors.accentCyan.withOpacity(0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.cyanGlow,
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Parlay Header - Blue Aura
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.accentCyan.withOpacity(0.25),
                  AppColors.accentCyan.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl - 2)),
            ),
            child: Row(
              children: [
                // Multiplier badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: AppColors.cyanGradient,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.cyanGlow,
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    '${multiplier}x',
                    style: GoogleFonts.lora(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PARLAY',
                      style: GoogleFonts.lora(
                        color: AppColors.accentCyan,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      '${predictions.length} picks combined',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: statusColor.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 13, color: statusColor),
                      const SizedBox(width: 5),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Clean Bets Box
          Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryDark,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.borderSubtle,
              ),
            ),
            child: Column(
              children: predictions.asMap().entries.map((entry) {
                final index = entry.key;
                final prediction = entry.value;
                final legWon = prediction.isWon;
                final legLost = prediction.isLost;
                final isLast = index == predictions.length - 1;

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: !isLast
                        ? Border(
                            bottom: BorderSide(
                              color: AppColors.borderSubtle,
                            ),
                          )
                        : null,
                  ),
                  child: Row(
                    children: [
                      // Status indicator
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: legWon
                              ? AppColors.accentGreen.withOpacity(0.2)
                              : legLost
                                  ? AppColors.accentRed.withOpacity(0.2)
                                  : AppColors.cardBackground,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: legWon
                                ? AppColors.accentGreen.withOpacity(0.5)
                                : legLost
                                    ? AppColors.accentRed.withOpacity(0.5)
                                    : AppColors.borderSubtle,
                          ),
                        ),
                        child: Icon(
                          legWon
                              ? Icons.check
                              : legLost
                                  ? Icons.close
                                  : Icons.circle_outlined,
                          size: 14,
                          color: legWon
                              ? AppColors.accentGreen
                              : legLost
                                  ? AppColors.accentRed
                                  : AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Bet details with Lora italic bold
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              prediction.outcomeDisplay,
                              style: GoogleFonts.lora(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${prediction.awayTeam} @ ${prediction.homeTeam}',
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            // Score when settled
                            if (prediction.isSettled && prediction.hasScores) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.cardBackground,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${prediction.finalAwayScore} - ${prediction.finalHomeScore}',
                                      style: GoogleFonts.lora(
                                        color: AppColors.textPrimary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(Icons.emoji_events, size: 12, color: AppColors.gold),
                                  const SizedBox(width: 4),
                                  Text(
                                    _getLegWinnerName(prediction),
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          // Payout Box - Blue Aura
          Container(
            margin: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.accentCyan.withOpacity(0.12),
                  AppColors.accentGreen.withOpacity(0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: AppColors.accentCyan.withOpacity(0.25),
              ),
            ),
            child: Row(
              children: [
                // Stake
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Stake',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.monetization_on, color: AppColors.gold, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '$stake',
                          style: GoogleFonts.lora(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(width: AppSpacing.lg),
                // Multiplier
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.accentCyan.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    '× ${multiplier}',
                    style: GoogleFonts.lora(
                      color: AppColors.accentCyan,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                const Spacer(),
                // Payout
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      allSettled ? 'PAYOUT' : 'TO WIN',
                      style: TextStyle(
                        color: allWon ? AppColors.accentGreen : AppColors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.monetization_on,
                          color: allWon ? AppColors.accentGreen : AppColors.gold,
                          size: 20,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          allWon ? '${first.payout ?? potentialPayout}' : '$potentialPayout',
                          style: GoogleFonts.lora(
                            color: allWon
                                ? AppColors.accentGreen
                                : anyLost
                                    ? AppColors.accentRed
                                    : AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 22,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
