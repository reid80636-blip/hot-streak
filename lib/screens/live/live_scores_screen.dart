import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../config/design_system.dart';
import '../../models/sport.dart';
import '../../providers/games_provider.dart';
import '../../providers/live_scores_provider.dart';
import '../../providers/predictions_provider.dart';
import '../../widgets/common/team_logo.dart';
import 'live_game_detail_screen.dart';

class LiveScoresScreen extends StatefulWidget {
  const LiveScoresScreen({super.key});

  @override
  State<LiveScoresScreen> createState() => _LiveScoresScreenState();
}

class _LiveScoresScreenState extends State<LiveScoresScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late TabController _tabController;
  LiveScoresProvider? _liveScoresProvider;
  GamesProvider? _gamesProvider;
  bool _initialized = false;
  Timer? _autoRefreshTimer;

  // Tab categories
  static const List<_SportTab> _sportTabs = [
    _SportTab(id: 'all', label: 'All', emoji: '🏆'),
    _SportTab(id: 'nfl', label: 'NFL', emoji: '🏈'),
    _SportTab(id: 'cfb', label: 'CFB', emoji: '🏈'),
    _SportTab(id: 'nba', label: 'NBA', emoji: '🏀'),
    _SportTab(id: 'cbb', label: 'CBB', emoji: '🏀'),
    _SportTab(id: 'soccer', label: 'Soccer', emoji: '⚽'),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _tabController = TabController(length: _sportTabs.length, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _initializeLiveScores();
    }
  }

  void _initializeLiveScores() {
    if (!mounted) return;

    _gamesProvider = context.read<GamesProvider>();
    _liveScoresProvider = context.read<LiveScoresProvider>();
    final predictions = context.read<PredictionsProvider>().predictions;
    final games = _gamesProvider!.allGames;

    _liveScoresProvider!.initialize(allGames: games, predictions: predictions);

    // Start auto-refresh every 5 seconds for live scores
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && _gamesProvider != null) {
        final games = _gamesProvider!.allGames;
        _liveScoresProvider?.refresh(games);
      }
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _pulseController.dispose();
    _tabController.dispose();
    _liveScoresProvider?.stopAutoRefresh();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    final games = context.read<GamesProvider>().allGames;
    await context.read<LiveScoresProvider>().refresh(games);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            // Header
            SliverToBoxAdapter(
              child: _buildHeader(),
            ),
            // Tab bar - Blue Aura style
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyTabBarDelegate(
                tabBar: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  indicatorColor: AppColors.accentCyan,
                  indicatorWeight: 3,
                  labelColor: AppColors.accentCyan,
                  unselectedLabelColor: AppColors.textMutedOp,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  tabs: _sportTabs.map((tab) => Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(tab.emoji),
                        const SizedBox(width: 6),
                        Text(tab.label),
                      ],
                    ),
                  )).toList(),
                ),
              ),
            ),
          ],
          body: TabBarView(
            controller: _tabController,
            children: _sportTabs.map((tab) {
              if (tab.id == 'all') {
                return _buildAllSportsView();
              }
              return _buildSportView(tab.id);
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Live indicator
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.accentRed.withOpacity(
                        0.5 + (_pulseController.value * 0.5),
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accentRed.withOpacity(
                            0.3 + (_pulseController.value * 0.3),
                          ),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(width: 10),
              const Text(
                'Live Scores',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Consumer<LiveScoresProvider>(
                builder: (context, liveScores, child) {
                  if (liveScores.isRefreshing) {
                    return const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accentCyan,
                      ),
                    );
                  }
                  return GestureDetector(
                    onTap: _handleRefresh,
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.glassBackground(0.5),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.borderGlow),
                      ),
                      child: const Icon(
                        Icons.refresh,
                        color: AppColors.accentCyan,
                        size: 20,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          Consumer<LiveScoresProvider>(
            builder: (context, liveScores, child) {
              final lastRefresh = liveScores.lastRefresh;
              final isLoadingMore = liveScores.isLoadingMore;
              final progress = liveScores.loadProgress;

              return Row(
                children: [
                  Text(
                    lastRefresh != null
                        ? 'Past 7 days • Updated ${_formatLastRefresh(lastRefresh)}'
                        : 'Past 7 days',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  if (isLoadingMore) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accentCyan.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$progress%',
                      style: TextStyle(
                        color: AppColors.accentCyan.withOpacity(0.6),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  String _formatLastRefresh(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  /// Build the "All" tab with ongoing games and popular games
  Widget _buildAllSportsView() {
    return Consumer<LiveScoresProvider>(
      builder: (context, liveScores, child) {
        // Show loading spinner only on initial load
        if (liveScores.isLoading && liveScores.liveGames.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          );
        }

        final ongoingGames = liveScores.ongoingGames;
        final popularGames = liveScores.popularGames;

        // Show empty state only if not loading more data
        if (ongoingGames.isEmpty && popularGames.isEmpty && liveScores.liveGames.isEmpty) {
          if (liveScores.isLoadingMore) {
            return _buildLoadingMoreState();
          }
          return _buildEmptyState();
        }

        return ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: RefreshIndicator(
            onRefresh: _handleRefresh,
            color: AppColors.accentCyan,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                // Quick stats
                _buildQuickStats(liveScores),

                // Ongoing games section
                if (ongoingGames.isNotEmpty) ...[
                _buildSectionHeader(
                  '🔴 Live Now',
                  '${ongoingGames.length} game${ongoingGames.length > 1 ? 's' : ''} in progress',
                  isLive: true,
                ),
                ...ongoingGames.asMap().entries.map((entry) {
                  return _LiveScoreCard(liveGame: entry.value)
                      .animate(delay: (entry.key * 50).ms)
                      .fadeIn()
                      .slideX(begin: 0.05, end: 0);
                }),
                const SizedBox(height: 16),
              ],

              // Popular games section
              if (popularGames.isNotEmpty) ...[
                _buildSectionHeader(
                  '🔥 Popular Games',
                  'Featured matchups from this week',
                ),
                ...popularGames.asMap().entries.map((entry) {
                  return _LiveScoreCard(liveGame: entry.value)
                      .animate(delay: (entry.key * 50).ms)
                      .fadeIn()
                      .slideX(begin: 0.05, end: 0);
                }),
                const SizedBox(height: 16),
              ],

              // Recent completed if no ongoing or popular
              if (ongoingGames.isEmpty && popularGames.isEmpty) ...[
                _buildSectionHeader(
                  '📊 Recent Games',
                  'Completed games from this week',
                ),
                ...liveScores.liveGames.take(10).toList().asMap().entries.map((entry) {
                  return _LiveScoreCard(liveGame: entry.value)
                      .animate(delay: (entry.key * 50).ms)
                      .fadeIn()
                      .slideX(begin: 0.05, end: 0);
                }),
              ],
            ],
          ),
          ),
        );
      },
    );
  }

  /// Build view for a specific sport
  Widget _buildSportView(String sportCategory) {
    return Consumer<LiveScoresProvider>(
      builder: (context, liveScores, child) {
        final games = liveScores.getGamesBySport(sportCategory);

        // Show loading spinner on initial load with no games for this sport yet
        if (liveScores.isLoading && games.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          );
        }

        // Show empty or loading state when no games
        if (games.isEmpty) {
          // Still loading more games? Show loading state
          if (liveScores.isLoadingMore) {
            return _buildLoadingMoreStateForSport(sportCategory);
          }
          return _buildEmptyStateForSport(sportCategory);
        }

        // Sort: live first, then by time
        final sortedGames = List<LiveGame>.from(games)
          ..sort((a, b) {
            if (a.isLive && !b.isLive) return -1;
            if (!a.isLive && b.isLive) return 1;
            return b.game.startTime.compareTo(a.game.startTime);
          });

        final liveGames = sortedGames.where((g) => g.isLive).toList();
        final completedGames = sortedGames.where((g) => g.isCompleted).toList();

        return ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: RefreshIndicator(
            onRefresh: _handleRefresh,
            color: AppColors.accentCyan,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                // Live games
                if (liveGames.isNotEmpty) ...[
                  _buildSectionHeader(
                    '🔴 Live Now',
                    '${liveGames.length} game${liveGames.length > 1 ? 's' : ''} in progress',
                    isLive: true,
                  ),
                  ...liveGames.asMap().entries.map((entry) {
                    return _LiveScoreCard(liveGame: entry.value)
                        .animate(delay: (entry.key * 50).ms)
                        .fadeIn()
                        .slideX(begin: 0.05, end: 0);
                  }),
                  const SizedBox(height: 16),
                ],

                // Completed games
                if (completedGames.isNotEmpty) ...[
                  _buildSectionHeader(
                    '✅ Final Scores',
                    '${completedGames.length} completed game${completedGames.length > 1 ? 's' : ''}',
                  ),
                  ...completedGames.asMap().entries.map((entry) {
                    return _LiveScoreCard(liveGame: entry.value)
                        .animate(delay: (entry.key * 50).ms)
                        .fadeIn()
                        .slideX(begin: 0.05, end: 0);
                  }),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, String subtitle, {bool isLive = false}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isLive ? AppColors.accentGreen : AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(LiveScoresProvider liveScores) {
    final liveCount = liveScores.ongoingGames.length;
    final finalCount = liveScores.liveGames.where((g) => g.isCompleted).length;
    final totalGames = liveScores.liveGames.length;

    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.glassBackground(0.6),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.borderGlow),
        boxShadow: [
          BoxShadow(
            color: AppColors.cyanGlow,
            blurRadius: 15,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            label: 'Live Now',
            value: '$liveCount',
            color: AppColors.accentGreen,
            icon: Icons.play_circle_filled,
          ),
          Container(
            width: 1,
            height: 40,
            color: AppColors.borderGlow,
          ),
          _StatItem(
            label: 'Final',
            value: '$finalCount',
            color: AppColors.textSecondaryOp,
            icon: Icons.check_circle,
          ),
          Container(
            width: 1,
            height: 40,
            color: AppColors.borderGlow,
          ),
          _StatItem(
            label: 'This Week',
            value: '$totalGames',
            color: AppColors.accentCyan,
            icon: Icons.sports,
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: -0.1, end: 0);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.surfaceColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.sports_outlined,
              size: 40,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No Games This Week',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'No live or completed games found',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _handleRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _buildLoadingMoreState() {
    return Consumer<LiveScoresProvider>(
      builder: (context, liveScores, child) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppColors.accentCyan,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Loading Games...',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${liveScores.loadProgress}% complete',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
      },
    ).animate().fadeIn(duration: 200.ms);
  }

  Widget _buildLoadingMoreStateForSport(String sportCategory) {
    final sportName = {
      'nfl': 'NFL',
      'cfb': 'College Football',
      'nba': 'NBA',
      'cbb': 'College Basketball',
      'soccer': 'Soccer',
    }[sportCategory] ?? sportCategory;

    return Consumer<LiveScoresProvider>(
      builder: (context, liveScores, child) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppColors.accentCyan,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Loading $sportName...',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${liveScores.loadProgress}% complete',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
      },
    ).animate().fadeIn(duration: 200.ms);
  }

  Widget _buildEmptyStateForSport(String sportCategory) {
    final sportName = {
      'nfl': 'NFL',
      'cfb': 'College Football',
      'nba': 'NBA',
      'cbb': 'College Basketball',
      'soccer': 'Soccer',
    }[sportCategory] ?? sportCategory;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.surfaceColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.sports_outlined,
              size: 40,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No $sportName Games',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'No games found this week',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _handleRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms);
  }
}

class _SportTab {
  final String id;
  final String label;
  final String emoji;

  const _SportTab({
    required this.id,
    required this.label,
    required this.emoji,
  });
}

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _StickyTabBarDelegate({required this.tabBar});

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.primaryDark,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_StickyTabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar;
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _LiveScoreCard extends StatelessWidget {
  final LiveGame liveGame;

  const _LiveScoreCard({required this.liveGame});

  @override
  Widget build(BuildContext context) {
    final game = liveGame.game;

    return GestureDetector(
      onTap: () => _showGameDetails(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: AppColors.glassBackground(0.6),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: liveGame.isLive
                ? AppColors.accentGreen.withOpacity(0.4)
                : AppColors.borderGlow,
          ),
          boxShadow: liveGame.isLive ? [
            BoxShadow(
              color: AppColors.successGlow,
              blurRadius: 12,
            ),
          ] : null,
        ),
        child: Column(
          children: [
            // Main score row
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Away team
                  Expanded(
                    flex: 3,
                    child: Row(
                      children: [
                        TeamLogo(teamName: game.awayTeam.name, size: 36, logoUrl: game.awayTeam.logoUrl),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                game.awayTeam.name.split(' ').last,
                                style: TextStyle(
                                  color: (liveGame.awayScore ?? 0) > (liveGame.homeScore ?? 0)
                                      ? AppColors.textPrimary
                                      : AppColors.textSecondary,
                                  fontSize: 14,
                                  fontWeight: (liveGame.awayScore ?? 0) > (liveGame.homeScore ?? 0)
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Score
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: liveGame.isLive
                          ? AppColors.accentGreen.withOpacity(0.1)
                          : AppColors.surfaceColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '${liveGame.awayScore ?? 0}',
                          style: TextStyle(
                            color: (liveGame.awayScore ?? 0) > (liveGame.homeScore ?? 0)
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            '-',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        Text(
                          '${liveGame.homeScore ?? 0}',
                          style: TextStyle(
                            color: (liveGame.homeScore ?? 0) > (liveGame.awayScore ?? 0)
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Home team
                  Expanded(
                    flex: 3,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                game.homeTeam.name.split(' ').last,
                                style: TextStyle(
                                  color: (liveGame.homeScore ?? 0) > (liveGame.awayScore ?? 0)
                                      ? AppColors.textPrimary
                                      : AppColors.textSecondary,
                                  fontSize: 14,
                                  fontWeight: (liveGame.homeScore ?? 0) > (liveGame.awayScore ?? 0)
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        TeamLogo(teamName: game.homeTeam.name, size: 36, logoUrl: game.homeTeam.logoUrl),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Status bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceColor.withOpacity(0.5),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: liveGame.isLive
                          ? AppColors.accentGreen.withOpacity(0.2)
                          : AppColors.textMuted.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (liveGame.isLive) ...[
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.accentGreen,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          liveGame.isCompleted
                              ? 'FINAL'
                              : (liveGame.gameTime ?? 'LIVE'),
                          style: TextStyle(
                            color: liveGame.isLive
                                ? AppColors.accentGreen
                                : AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Sport badge
                  Row(
                    children: [
                      Text(
                        _getSportEmoji(game.sportKey),
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _getSportLabel(game.sportKey),
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Quick navigation tabs
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primaryDark,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                border: Border(
                  top: BorderSide(
                    color: AppColors.borderSubtle,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  _buildQuickTabButton(
                    context,
                    'Summary',
                    Icons.article_outlined,
                    0,
                  ),
                  const SizedBox(width: 6),
                  _buildQuickTabButton(
                    context,
                    'Box Score',
                    Icons.grid_on_rounded,
                    1,
                  ),
                  const SizedBox(width: 6),
                  _buildQuickTabButton(
                    context,
                    'Plays',
                    Icons.play_circle_outline_rounded,
                    2,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickTabButton(
    BuildContext context,
    String label,
    IconData icon,
    int tabIndex,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _showGameDetails(context, initialTab: tabIndex),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getSportEmoji(String sportKey) {
    if (sportKey.contains('soccer')) return '⚽';
    if (sportKey.contains('basketball')) return '🏀';
    if (sportKey.contains('football')) return '🏈';
    return '🏆';
  }

  String _getSportLabel(String sportKey) {
    final sport = Sport.fromKey(sportKey);
    return sport?.shortName ?? sportKey;
  }

  void _showGameDetails(BuildContext context, {int initialTab = 0}) {
    HapticFeedback.lightImpact();
    final game = liveGame.game;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LiveGameDetailScreen(
          eventId: game.id,
          sportKey: game.sportKey,
          homeTeam: game.homeTeam.name,
          awayTeam: game.awayTeam.name,
          homeLogo: game.homeTeam.logoUrl,
          awayLogo: game.awayTeam.logoUrl,
          homeScore: liveGame.homeScore,
          awayScore: liveGame.awayScore,
          gameTime: liveGame.gameTime,
          isLive: liveGame.isLive,
          initialTabIndex: initialTab,
        ),
      ),
    );
  }
}

class _GameDetailsSheet extends StatelessWidget {
  final LiveGame liveGame;

  const _GameDetailsSheet({required this.liveGame});

  @override
  Widget build(BuildContext context) {
    final game = liveGame.game;
    final sport = Sport.fromKey(game.sportKey);

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.surfaceColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Sport badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: (sport?.color ?? AppColors.accent).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(sport?.emoji ?? '🏆', style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(
                        sport?.name ?? 'Game',
                        style: TextStyle(
                          color: sport?.color ?? AppColors.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Teams and score
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Away team
                    Expanded(
                      child: Column(
                        children: [
                          TeamLogo(teamName: game.awayTeam.name, size: 60, logoUrl: game.awayTeam.logoUrl),
                          const SizedBox(height: 8),
                          Text(
                            game.awayTeam.name,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),

                    // Score
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: liveGame.isLive
                            ? AppColors.accentGreen.withOpacity(0.1)
                            : AppColors.surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                        border: liveGame.isLive
                            ? Border.all(color: AppColors.accentGreen.withOpacity(0.3))
                            : null,
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Text(
                                '${liveGame.awayScore ?? 0}',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  '-',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 28,
                                  ),
                                ),
                              ),
                              Text(
                                '${liveGame.homeScore ?? 0}',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: liveGame.isLive
                                  ? AppColors.accentGreen.withOpacity(0.2)
                                  : AppColors.textMuted.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              liveGame.isCompleted
                                  ? 'FINAL'
                                  : (liveGame.gameTime ?? 'LIVE'),
                              style: TextStyle(
                                color: liveGame.isLive
                                    ? AppColors.accentGreen
                                    : AppColors.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
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
                          TeamLogo(teamName: game.homeTeam.name, size: 60, logoUrl: game.homeTeam.logoUrl),
                          const SizedBox(height: 8),
                          Text(
                            game.homeTeam.name,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(color: AppColors.surfaceColor),

          // Game info
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildInfoSection('Game Info', [
                  _InfoRow(
                    label: 'Status',
                    value: liveGame.isLive ? 'In Progress' : 'Final',
                    valueColor: liveGame.isLive ? AppColors.accentGreen : null,
                  ),
                  if (liveGame.gameTime != null)
                    _InfoRow(
                      label: 'Game Time',
                      value: liveGame.gameTime!,
                    ),
                  _InfoRow(
                    label: 'Start Time',
                    value: _formatDateTime(game.startTime),
                  ),
                ]),

                const SizedBox(height: 20),

                _buildInfoSection('Score Breakdown', [
                  _InfoRow(
                    label: game.awayTeam.name,
                    value: '${liveGame.awayScore ?? 0}',
                    valueColor: (liveGame.awayScore ?? 0) > (liveGame.homeScore ?? 0)
                        ? AppColors.accentGreen
                        : null,
                  ),
                  _InfoRow(
                    label: game.homeTeam.name,
                    value: '${liveGame.homeScore ?? 0}',
                    valueColor: (liveGame.homeScore ?? 0) > (liveGame.awayScore ?? 0)
                        ? AppColors.accentGreen
                        : null,
                  ),
                  _InfoRow(
                    label: 'Total Points',
                    value: '${(liveGame.homeScore ?? 0) + (liveGame.awayScore ?? 0)}',
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: rows),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final gameDay = DateTime(dt.year, dt.month, dt.day);

    String dayStr;
    if (gameDay == today) {
      dayStr = 'Today';
    } else if (gameDay == today.subtract(const Duration(days: 1))) {
      dayStr = 'Yesterday';
    } else {
      dayStr = '${dt.month}/${dt.day}';
    }

    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');

    return '$dayStr at $hour:$minute $amPm';
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
