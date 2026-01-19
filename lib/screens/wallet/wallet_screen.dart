import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';

import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/predictions_provider.dart';
import '../../widgets/daily_bonus/spin_wheel_popup.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen>
    with TickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _claimDailyBonus(BuildContext context) async {
    HapticFeedback.mediumImpact();
    // Show spin wheel popup instead of direct claim
    await SpinWheelPopup.show(context);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.primaryDark,
          appBar: AppBar(
            backgroundColor: AppColors.primaryDark,
            elevation: 0,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.arrow_back_rounded, size: 20),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
              ).createShader(bounds),
              child: const Text(
                'Wallet',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            centerTitle: true,
          ),
          body: Consumer<AuthProvider>(
            builder: (context, auth, child) {
              final user = auth.user;
              if (user == null) {
                return const Center(
                  child: Text(
                    'Not logged in',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                );
              }

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Premium Balance Card
                        _buildBalanceCard(user.coins),

                        const SizedBox(height: 24),

                        // Daily Bonus Card
                        _buildDailyBonusCard(user.canClaimDailyBonus),

                        const SizedBox(height: 28),

                        // Stats Section
                        _buildStatsSection(context),

                        const SizedBox(height: 28),

                        // Quests Section
                        _buildQuestsSection(context),

                        const SizedBox(height: 24),

                        // Info card
                        _buildInfoCard(),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              );
            },
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
              Color(0xFFFFD700),
              Color(0xFF00FF7F),
              Color(0xFFFF6B35),
              Colors.white,
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceCard(int coins) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFD700), Color(0xFFFFA500), Color(0xFFFF8C00)],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD700).withOpacity(0.5),
                blurRadius: 30,
                offset: const Offset(0, 12),
                spreadRadius: 2,
              ),
            ],
          ),
          child: Stack(
            children: [
              // Shimmer overlay
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: ShaderMask(
                    shaderCallback: (bounds) {
                      return LinearGradient(
                        begin: Alignment(-2 + _shimmerController.value * 4, 0),
                        end: Alignment(-1 + _shimmerController.value * 4, 0),
                        colors: const [
                          Colors.transparent,
                          Colors.white24,
                          Colors.transparent,
                        ],
                      ).createShader(bounds);
                    },
                    blendMode: BlendMode.srcATop,
                    child: Container(color: Colors.white),
                  ),
                ),
              ),
              // Content
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.account_balance_wallet_rounded,
                                color: Colors.white, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'BALANCE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulseAnimation.value,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.25),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.3),
                                    blurRadius: 15,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.monetization_on_rounded,
                                color: Colors.white,
                                size: 36,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 14),
                      Text(
                        _formatCoins(coins),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 52,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -2,
                          shadows: [
                            Shadow(
                              color: Colors.black26,
                              blurRadius: 10,
                              offset: Offset(2, 4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'coins',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ).animate().fadeIn(duration: 400.ms).scale(
          begin: const Offset(0.9, 0.9),
          end: const Offset(1, 1),
          curve: Curves.easeOutBack,
        );
  }

  String _formatCoins(int coins) {
    if (coins >= 1000000) {
      return '${(coins / 1000000).toStringAsFixed(1)}M';
    } else if (coins >= 10000) {
      return '${(coins / 1000).toStringAsFixed(1)}K';
    }
    return coins.toString();
  }

  Widget _buildDailyBonusCard(bool canClaim) {
    return GestureDetector(
      onTap: canClaim ? () => _claimDailyBonus(context) : null,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: canClaim
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF00FF7F).withOpacity(0.2),
                    const Color(0xFF10B981).withOpacity(0.1),
                  ],
                )
              : null,
          color: canClaim ? null : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: canClaim
                ? const Color(0xFF00FF7F).withOpacity(0.5)
                : AppColors.borderSubtle,
            width: canClaim ? 2 : 1,
          ),
          boxShadow: canClaim
              ? [
                  BoxShadow(
                    color: const Color(0xFF00FF7F).withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: canClaim
                    ? const LinearGradient(
                        colors: [Color(0xFF00FF7F), Color(0xFF10B981)],
                      )
                    : null,
                color: canClaim ? null : AppColors.primaryDark,
                borderRadius: BorderRadius.circular(16),
                boxShadow: canClaim
                    ? [
                        BoxShadow(
                          color: const Color(0xFF00FF7F).withOpacity(0.4),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                canClaim ? Icons.casino_rounded : Icons.check_circle_rounded,
                color: canClaim ? Colors.white : AppColors.textMuted,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daily Bonus',
                    style: TextStyle(
                      color: canClaim
                          ? const Color(0xFF00FF7F)
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    canClaim
                        ? 'Spin the wheel for up to 5,000 coins!'
                        : 'Come back tomorrow for more coins',
                    style: TextStyle(
                      color: canClaim
                          ? Colors.white.withOpacity(0.8)
                          : AppColors.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            // CTA
            if (canClaim)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00FF7F), Color(0xFF10B981)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00FF7F).withOpacity(0.4),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'SPIN',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryDark,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: AppColors.textMuted,
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    ).animate(delay: 150.ms).fadeIn().slideY(begin: 0.1, end: 0);
  }

  Widget _buildStatsSection(BuildContext context) {
    return Consumer2<AuthProvider, PredictionsProvider>(
      builder: (context, auth, predictions, child) {
        final user = auth.user;
        if (user == null) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('YOUR STATS', Icons.bar_chart_rounded, 200),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _PremiumStatCard(
                    icon: Icons.trending_up_rounded,
                    label: 'Win Rate',
                    value: '${user.winRate.toStringAsFixed(1)}%',
                    gradientColors: const [Color(0xFF10B981), Color(0xFF059669)],
                    delay: 250,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PremiumStatCard(
                    icon: Icons.emoji_events_rounded,
                    label: 'Total Wins',
                    value: '${user.wins}',
                    gradientColors: const [Color(0xFFFFD700), Color(0xFFF59E0B)],
                    delay: 300,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _PremiumStatCard(
                    icon: Icons.sports_rounded,
                    label: 'Total Bets',
                    value: '${user.totalPredictions}',
                    gradientColors: const [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                    delay: 350,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PremiumStatCard(
                    icon: Icons.monetization_on_rounded,
                    label: 'Total Winnings',
                    value: _formatCoins(predictions.totalWinnings),
                    gradientColors: const [Color(0xFFFF6B35), Color(0xFFE74C3C)],
                    delay: 400,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, int delay) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: AppColors.textSecondary,
            size: 16,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
      ],
    ).animate(delay: Duration(milliseconds: delay)).fadeIn(duration: 300.ms);
  }

  Widget _buildQuestsSection(BuildContext context) {
    return Consumer2<AuthProvider, PredictionsProvider>(
      builder: (context, auth, predictions, child) {
        final user = auth.user;
        if (user == null) return const SizedBox.shrink();

        // Calculate quest progress based on actual data
        final todayPredictions = predictions.predictions
            .where((p) =>
                p.createdAt.day == DateTime.now().day &&
                p.createdAt.month == DateTime.now().month &&
                p.createdAt.year == DateTime.now().year)
            .length;

        final todayWins = predictions.predictions
            .where((p) =>
                p.isWon &&
                p.createdAt.day == DateTime.now().day &&
                p.createdAt.month == DateTime.now().month &&
                p.createdAt.year == DateTime.now().year)
            .length;

        final parlayBets = predictions.predictions
            .where((p) =>
                p.parlayId != null &&
                p.createdAt.day == DateTime.now().day &&
                p.createdAt.month == DateTime.now().month &&
                p.createdAt.year == DateTime.now().year)
            .length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('DAILY QUESTS', Icons.emoji_events_rounded, 450),
            const SizedBox(height: 16),
            _PremiumQuestCard(
              title: 'Make 3 Predictions',
              description: 'Place 3 bets today',
              reward: 100,
              xpReward: 25,
              progress: todayPredictions.clamp(0, 3),
              total: 3,
              gradientColors: const [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
              delay: 500,
            ),
            const SizedBox(height: 12),
            _PremiumQuestCard(
              title: 'Win a Prediction',
              description: 'Have at least one winning bet',
              reward: 200,
              xpReward: 50,
              progress: todayWins.clamp(0, 1),
              total: 1,
              gradientColors: const [Color(0xFF10B981), Color(0xFF059669)],
              delay: 550,
            ),
            const SizedBox(height: 12),
            _PremiumQuestCard(
              title: 'Try a Parlay Bet',
              description: 'Place a combo bet with 2+ picks',
              reward: 150,
              xpReward: 35,
              progress: parlayBets > 0 ? 1 : 0,
              total: 1,
              gradientColors: const [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
              delay: 600,
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.info_outline_rounded,
                color: AppColors.accent, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Coins are virtual and have no real monetary value. This is for entertainment purposes only.',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    ).animate(delay: 650.ms).fadeIn();
  }
}

/// Premium stat card with gradient icon
class _PremiumStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final List<Color> gradientColors;
  final int delay;

  const _PremiumStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.gradientColors,
    this.delay = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: gradientColors.first.withOpacity(0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradientColors),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: gradientColors.first.withOpacity(0.35),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ).animate(delay: Duration(milliseconds: delay)).fadeIn().slideY(begin: 0.1, end: 0);
  }
}

/// Premium quest card with progress
class _PremiumQuestCard extends StatelessWidget {
  final String title;
  final String description;
  final int reward;
  final int xpReward;
  final int progress;
  final int total;
  final List<Color> gradientColors;
  final int delay;

  const _PremiumQuestCard({
    required this.title,
    required this.description,
    required this.reward,
    required this.xpReward,
    required this.progress,
    required this.total,
    required this.gradientColors,
    this.delay = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isComplete = progress >= total;
    final progressPercent = (progress / total).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isComplete
              ? const Color(0xFF00FF7F).withOpacity(0.4)
              : gradientColors.first.withOpacity(0.15),
          width: isComplete ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Icon
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: isComplete
                      ? const LinearGradient(
                          colors: [Color(0xFF00FF7F), Color(0xFF10B981)],
                        )
                      : LinearGradient(colors: gradientColors),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: (isComplete ? const Color(0xFF00FF7F) : gradientColors.first)
                          .withOpacity(0.35),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Icon(
                  isComplete ? Icons.check_rounded : Icons.flag_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              // Title & Description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isComplete
                            ? const Color(0xFF00FF7F)
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Rewards
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.monetization_on_rounded,
                          color: Color(0xFFFFD700), size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '+$reward',
                        style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_awesome_rounded,
                          color: Color(0xFF8B5CF6), size: 12),
                      const SizedBox(width: 4),
                      Text(
                        '+$xpReward XP',
                        style: const TextStyle(
                          color: Color(0xFF8B5CF6),
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress bar
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.primaryDark,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progressPercent,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: isComplete
                            ? const LinearGradient(
                                colors: [Color(0xFF00FF7F), Color(0xFF10B981)],
                              )
                            : LinearGradient(colors: gradientColors),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: (isComplete
                                    ? const Color(0xFF00FF7F)
                                    : gradientColors.first)
                                .withOpacity(0.4),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isComplete
                      ? const Color(0xFF00FF7F).withOpacity(0.15)
                      : AppColors.primaryDark,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$progress/$total',
                  style: TextStyle(
                    color: isComplete
                        ? const Color(0xFF00FF7F)
                        : AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate(delay: Duration(milliseconds: delay)).fadeIn().slideX(begin: 0.05, end: 0);
  }
}
