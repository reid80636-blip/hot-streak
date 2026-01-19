import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../config/design_system.dart';
import '../../config/routes.dart';
import '../../models/game.dart';
import '../../models/sport.dart';
import '../../models/game_score.dart';
import '../../providers/auth_provider.dart';
import '../../providers/games_provider.dart';
import '../../providers/predictions_provider.dart';
import '../../providers/suggestions_provider.dart';
import '../../services/settlement_service.dart';
import '../../services/settlement_coordinator.dart';
import '../../widgets/common/coin_balance.dart';
import '../../widgets/common/game_card.dart';
import '../../widgets/common/team_logo.dart';
import '../../widgets/daily_bonus/spin_wheel_popup.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedFilter = 'for_you'; // 'for_you' = suggested, 'popular' = Popular, or sport key

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  /// Initialize all data - wait for both games and predictions to load
  Future<void> _initializeData() async {
    final auth = context.read<AuthProvider>();
    final gamesProvider = context.read<GamesProvider>();
    final predictionsProvider = context.read<PredictionsProvider>();

    // Start fetching games
    final gamesFuture = gamesProvider.fetchGames();

    // Set up predictions if user is logged in
    Future<void>? predictionsFuture;
    if (auth.user != null) {
      predictionsProvider.setUserId(auth.user!.id);
      predictionsFuture = predictionsProvider.loadPredictions();

      // Show daily bonus wheel popup if available
      _checkDailyBonus();
    }

    // Wait for BOTH games and predictions to load before generating suggestions
    await Future.wait([
      gamesFuture,
      if (predictionsFuture != null) predictionsFuture,
    ]);

    if (!mounted) return;

    // Now generate suggestions with fully loaded data
    _generateSuggestions();

    // Run settlement after everything is loaded
    if (auth.user != null) {
      _runSettlement();
    }
  }

  /// Check and show daily bonus wheel if available
  void _checkDailyBonus() {
    final auth = context.read<AuthProvider>();
    if (auth.user?.canClaimDailyBonus ?? false) {
      // Delay slightly to let home screen render first
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          SpinWheelPopup.show(context);
        }
      });
    }
  }

  /// Generate personalized suggestions based on betting history and user preferences
  void _generateSuggestions() {
    if (!mounted) return;

    final auth = context.read<AuthProvider>();
    final games = context.read<GamesProvider>().allGames;
    final predictions = context.read<PredictionsProvider>().predictions;
    final suggestions = context.read<SuggestionsProvider>();

    // Load user's saved preferences into the suggestions provider
    if (auth.user != null) {
      suggestions.setFollowedSports(auth.user!.favoriteSports);
      suggestions.setFollowedTeams(auth.user!.favoriteTeams);
    }

    suggestions.generateSuggestions(allGames: games, history: predictions);
  }

  /// Run the settlement process to check for finished games and settle bets
  Future<void> _runSettlement() async {
    if (!mounted) return;

    final auth = context.read<AuthProvider>();
    final predictions = context.read<PredictionsProvider>();

    // Only run if there are eligible predictions
    if (!predictions.hasEligiblePredictions) return;

    final coordinator = SettlementCoordinator(
      settlementService: SettlementService(),
      predictionsProvider: predictions,
      authProvider: auth,
    );

    final summary = await coordinator.runSettlement();

    // Show notification if any bets were settled
    if (summary.settledCount > 0 && mounted) {
      _showSettlementNotification(summary);
    }
  }

  /// Show a snackbar notification about settled bets
  void _showSettlementNotification(SettlementSummary summary) {
    final hasWins = summary.wins > 0 || summary.parlaysWon > 0;
    final totalWins = summary.wins + summary.parlaysWon;
    final totalLosses = summary.losses + summary.parlaysLost;

    String message;
    IconData icon;
    Color iconColor;

    if (hasWins && summary.totalWinnings > 0) {
      message = '$totalWins bet(s) won! +${summary.totalWinnings} coins';
      icon = Icons.celebration;
      iconColor = AppColors.gold;
    } else if (totalLosses > 0) {
      message = '$totalLosses bet(s) settled';
      icon = Icons.sports_score;
      iconColor = AppColors.textSecondary;
    } else {
      message = '${summary.settledCount} bet(s) settled';
      icon = Icons.check_circle;
      iconColor = AppColors.accentCyan;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.glassBackground(0.95),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'View',
          textColor: AppColors.accentCyan,
          onPressed: () => context.go(AppRoutes.predictions),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await context.read<GamesProvider>().fetchGames(force: true);
            await _runSettlement();
            _generateSuggestions();
          },
          child: CustomScrollView(
            slivers: [
              // App bar
              SliverToBoxAdapter(
                child: _buildAppBar(context),
              ),

              // Daily bonus card
              SliverToBoxAdapter(
                child: _buildDailyBonusCard(context),
              ),

              // Hot Picks (personalized suggestions + popular games)
              SliverToBoxAdapter(
                child: _buildHotPicksSection(context),
              ),

              // Sports quick access
              SliverToBoxAdapter(
                child: _buildSportsSection(context),
              ),

              // Games to Bet On header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xxl, AppSpacing.lg, AppSpacing.sm),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.accentCyan.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: const Icon(
                              Icons.sports_score,
                              color: AppColors.accentCyan,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Games to Bet On',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => context.go(AppRoutes.games),
                        child: const Text(
                          'See All',
                          style: TextStyle(
                            color: AppColors.accentCyan,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Filter chips
              SliverToBoxAdapter(
                child: _buildFilterChips(),
              ),

              // Bettable games list (only games with odds)
              Consumer2<GamesProvider, SuggestionsProvider>(
                builder: (context, gamesProvider, suggestionsProvider, child) {
                  // Show loading only if no games loaded yet
                  if (gamesProvider.isLoading && gamesProvider.allGames.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    );
                  }

                  List<Game> bettableGames;

                  // Apply filter
                  if (_selectedFilter == 'for_you') {
                    // For You = personalized suggestions (will be based on onboarding later)
                    // For now: mix of suggestions + featured games
                    final suggestedGames = suggestionsProvider.suggestions
                        .map((s) => s.game)
                        .where((g) => g.odds != null && g.isUpcoming)
                        .toList();

                    // Fill with featured/popular if not enough suggestions
                    final featuredGames = gamesProvider.featuredGames
                        .where((g) => !suggestedGames.any((s) => s.id == g.id))
                        .toList();

                    bettableGames = [...suggestedGames, ...featuredGames].take(15).toList();
                  } else if (_selectedFilter == 'popular') {
                    // Popular = games with highest odds variance
                    bettableGames = gamesProvider.allGames
                        .where((g) => g.odds != null && g.isUpcoming)
                        .toList();
                    bettableGames.sort((a, b) {
                      final aSpread = (a.odds!.home - a.odds!.away).abs();
                      final bSpread = (b.odds!.home - b.odds!.away).abs();
                      return bSpread.compareTo(aSpread);
                    });
                    bettableGames = bettableGames.take(15).toList();
                  } else if (_selectedFilter == 'soccer_all') {
                    // All soccer leagues filter
                    bettableGames = gamesProvider.allGames
                        .where((g) => g.odds != null && g.isUpcoming && g.sportKey.startsWith('soccer_'))
                        .take(15)
                        .toList();
                  } else {
                    // Sport key filter
                    bettableGames = gamesProvider.allGames
                        .where((g) => g.odds != null && g.isUpcoming && g.sportKey == _selectedFilter)
                        .take(15)
                        .toList();
                  }

                  if (bettableGames.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Icon(
                                _selectedFilter == 'for_you' ? Icons.auto_awesome : Icons.sports,
                                size: 48,
                                color: AppColors.textMuted,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No ${_getFilterLabel(_selectedFilter)} games available',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _selectedFilter == 'for_you'
                                    ? 'Follow teams in Settings to get personalized picks!'
                                    : 'Check back soon for new games!',
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return GameCard(game: bettableGames[index])
                            .animate(delay: (index * 50).ms)
                            .fadeIn()
                            .slideX(begin: 0.1, end: 0);
                      },
                      childCount: bettableGames.length,
                    ),
                  );
                },
              ),

              // Bottom padding for FAB
              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build filter chips for games section - Blue Aura glass pill style
  Widget _buildFilterChips() {
    final filters = [
      _FilterOption(key: 'for_you', label: 'For You', emoji: '✨', color: AppColors.accentCyan),
      _FilterOption(key: 'popular', label: 'Hot', emoji: '🔥', color: AppColors.liveRed),
      _FilterOption(key: 'americanfootball_nfl', label: 'NFL', emoji: '', color: AppColors.nfl, logoUrl: 'https://a.espncdn.com/combiner/i?img=/i/teamlogos/leagues/500/nfl.png'),
      _FilterOption(key: 'basketball_nba', label: 'NBA', emoji: '', color: AppColors.nba, logoUrl: 'https://a.espncdn.com/combiner/i?img=/i/teamlogos/leagues/500/nba.png'),
      _FilterOption(key: 'icehockey_nhl', label: 'NHL', emoji: '', color: AppColors.nhl, logoUrl: 'https://a.espncdn.com/combiner/i?img=/i/teamlogos/leagues/500/nhl.png'),
      _FilterOption(key: 'americanfootball_ncaaf', label: 'CFB', emoji: '', color: AppColors.ncaaf, logoUrl: 'https://a.espncdn.com/i/espn/misc_logos/500/ncaaf.png'),
      _FilterOption(key: 'basketball_ncaab', label: 'CBB', emoji: '', color: AppColors.ncaab, logoUrl: 'https://a.espncdn.com/i/espn/misc_logos/500/ncaam.png'),
      _FilterOption(key: 'soccer_all', label: 'Soccer', emoji: '', color: AppColors.soccer, logoUrl: 'https://a.espncdn.com/combiner/i?img=/i/leaguelogos/soccer/500/23.png'),
    ];

    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _selectedFilter == filter.key;
          final hasLogo = filter.logoUrl != null;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
            child: GestureDetector(
              onTap: () => setState(() => _selectedFilter = filter.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(
                  horizontal: hasLogo ? AppSpacing.sm : AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (filter.color ?? AppColors.accentCyan).withOpacity(0.2)
                      : AppColors.glassBackground(0.4),
                  borderRadius: BorderRadius.circular(AppRadius.round),
                  border: Border.all(
                    color: isSelected
                        ? (filter.color ?? AppColors.accentCyan).withOpacity(0.6)
                        : AppColors.borderGlow,
                    width: 1.5,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: (filter.color ?? AppColors.accentCyan).withOpacity(0.3),
                            blurRadius: 12,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasLogo) ...[
                      Image.network(
                        filter.logoUrl!,
                        width: 20,
                        height: 20,
                        errorBuilder: (_, __, ___) => Text(
                          filter.label,
                          style: TextStyle(
                            color: isSelected ? (filter.color ?? AppColors.accentCyan) : AppColors.textSecondaryOp,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                    ] else if (filter.emoji.isNotEmpty) ...[
                      Text(filter.emoji, style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      filter.label,
                      style: TextStyle(
                        color: isSelected ? (filter.color ?? AppColors.accentCyan) : AppColors.textMutedOp,
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Get display label for a filter
  String _getFilterLabel(String filterKey) {
    switch (filterKey) {
      case 'for_you':
        return 'suggested';
      case 'popular':
        return 'Popular';
      case 'americanfootball_nfl':
        return 'NFL';
      case 'basketball_nba':
        return 'NBA';
      case 'soccer_all':
        return 'Soccer';
      case 'icehockey_nhl':
        return 'NHL';
      case 'americanfootball_ncaaf':
        return 'College Football';
      case 'basketball_ncaab':
        return 'College Basketball';
      default:
        return Sport.fromKey(filterKey)?.name ?? filterKey;
    }
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
      child: Row(
        children: [
          // Logo and name
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryGlow,
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.local_fire_department,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'HotStreak',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const Spacer(),

          // Coins
          const CoinBalance(),

          const SizedBox(width: 12),

          // Profile
          GestureDetector(
            onTap: () => context.go(AppRoutes.profile),
            child: Consumer<AuthProvider>(
              builder: (context, auth, child) {
                return Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.borderGlow, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.cyanGlow,
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.glassBackground(0.6),
                    child: Text(
                      auth.user?.username.substring(0, 1).toUpperCase() ?? 'U',
                      style: const TextStyle(
                        color: AppColors.accentCyan,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildDailyBonusCard(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        if (!auth.isLoggedIn || !(auth.user?.canClaimDailyBonus ?? false)) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
          child: GestureDetector(
            onTap: () => SpinWheelPopup.show(context),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                gradient: AppColors.goldGradient,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(
                  color: AppColors.gold.withOpacity(0.5),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.goldGlow,
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Icon(Icons.casino, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Spin for Daily Bonus!',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Tap to spin the wheel',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                ],
              ),
            ),
          ),
        ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.1, end: 0);
      },
    );
  }

  Widget _buildHotPicksSection(BuildContext context) {
    return Consumer2<SuggestionsProvider, GamesProvider>(
      builder: (context, suggestions, gamesProvider, child) {
        // Get personalized suggestions
        final personalizedGames = suggestions.suggestions.take(3).toList();

        // Get popular games (games with good matchups from popular teams)
        final popularTeams = [
          'LA Lakers', 'Golden State Warriors', 'Boston Celtics',
          'Kansas City Chiefs', 'Dallas Cowboys',
          'Duke Blue Devils', 'North Carolina Tar Heels', 'NC State Wolfpack',
          'Real Madrid', 'Manchester City',
        ];

        final popularGames = gamesProvider.allGames
            .where((g) =>
                g.odds != null &&
                g.isUpcoming &&
                (popularTeams.any((t) => g.homeTeam.name.contains(t) || g.awayTeam.name.contains(t))))
            .take(4)
            .toList();

        // Combine: personalized first, then fill with popular
        final displayGames = <_HotPickDisplayItem>[];

        for (final suggestion in personalizedGames) {
          displayGames.add(_HotPickDisplayItem(
            game: suggestion.game,
            reason: suggestion.reason,
            isPersonalized: true,
          ));
        }

        // Add popular games that aren't already in personalized
        for (final game in popularGames) {
          if (!displayGames.any((d) => d.game.id == game.id)) {
            displayGames.add(_HotPickDisplayItem(
              game: game,
              reason: 'Trending',
              isPersonalized: false,
            ));
          }
          if (displayGames.length >= 6) break;
        }

        // If still not enough, add any upcoming games
        if (displayGames.length < 4) {
          for (final game in gamesProvider.featuredGames) {
            if (!displayGames.any((d) => d.game.id == game.id)) {
              displayGames.add(_HotPickDisplayItem(
                game: game,
                reason: 'Bet Now',
                isPersonalized: false,
              ));
            }
            if (displayGames.length >= 6) break;
          }
        }

        if (displayGames.isEmpty) {
          return const SizedBox.shrink();
        }

        final hasPersonalized = displayGames.any((d) => d.isPersonalized);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.accentCyan.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Icon(
                      Icons.local_fire_department,
                      color: AppColors.accentCyan,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Featured Bets',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          hasPersonalized
                              ? 'Picks based on your betting history'
                              : 'Top games to bet on now',
                          style: TextStyle(
                            color: AppColors.textMutedOp,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: displayGames.length,
                itemBuilder: (context, index) {
                  final item = displayGames[index];
                  return _HotPickCardSimple(
                    game: item.game,
                    reason: item.reason,
                  ).animate(delay: (index * 80).ms)
                      .fadeIn()
                      .slideX(begin: 0.15, end: 0);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSportsSection(BuildContext context) {
    // Only show the main sports: NFL, NBA, NHL, CFB, CBB, Soccer
    // Use the combined Soccer sport from mainSports
    final mainSports = Sport.mainSports;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 20, 16, 10),
          child: Text(
            'Sports',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 78,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: mainSports.length,
            itemBuilder: (context, index) {
              final sport = mainSports[index];
              return _SportCardMinimal(sport: sport)
                  .animate(delay: (index * 40).ms)
                  .fadeIn()
                  .scale(begin: const Offset(0.9, 0.9));
            },
          ),
        ),
      ],
    );
  }
}

/// Minimalistic sport card with centered logo - Blue Aura glass style
class _SportCardMinimal extends StatelessWidget {
  final Sport sport;

  const _SportCardMinimal({required this.sport});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('${AppRoutes.games}?sport=${sport.key}'),
      child: Container(
        width: 74,
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.glassBackground(0.5),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: AppColors.borderGlow,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Centered league logo
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: sport.logoUrl != null
                      ? Image.network(
                          sport.logoUrl!,
                          width: 28,
                          height: 28,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Center(
                            child: Text(sport.emoji, style: const TextStyle(fontSize: 18)),
                          ),
                        )
                      : Center(
                          child: Text(sport.emoji, style: const TextStyle(fontSize: 18)),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              sport.shortName == 'College Football' ? 'CFB' :
              sport.shortName == 'College Basketball' ? 'CBB' :
              sport.shortName,
              style: TextStyle(
                color: AppColors.textSecondaryOp,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for subtle diagonal lines pattern
class _SportPatternPainter extends CustomPainter {
  final Color color;

  _SportPatternPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.1)
      ..strokeWidth = 1;

    for (double i = -size.height; i < size.width + size.height; i += 12) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HotPickDisplayItem {
  final Game game;
  final String reason;
  final bool isPersonalized;

  const _HotPickDisplayItem({
    required this.game,
    required this.reason,
    required this.isPersonalized,
  });
}

class _HotPickCardSimple extends StatelessWidget {
  final Game game;
  final String reason;

  const _HotPickCardSimple({
    required this.game,
    required this.reason,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/games/${game.id}'),
      child: Container(
        width: 170,
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs + 2),
        decoration: BoxDecoration(
          color: AppColors.glassBackground(0.6),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: AppColors.borderGlow,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.cyanGlow,
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Reason tag
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                decoration: BoxDecoration(
                  gradient: AppColors.cyanGradient,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  reason,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 10),
              // Teams
              Row(
                children: [
                  TeamLogoCircle(teamName: game.awayTeam.name, size: 22, logoUrl: game.awayTeam.logoUrl),
                  const SizedBox(width: 8),
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
              const SizedBox(height: 6),
              Row(
                children: [
                  TeamLogoCircle(teamName: game.homeTeam.name, size: 22, logoUrl: game.homeTeam.logoUrl),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '@ ${game.homeTeam.name.split(' ').last}',
                      style: TextStyle(
                        color: AppColors.textSecondaryOp,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Time
              Text(
                game.displayTime,
                style: TextStyle(
                  color: game.isLive ? AppColors.accentGreen : AppColors.textMutedOp,
                  fontSize: 11,
                  fontWeight: game.isLive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Filter option for games section
class _FilterOption {
  final String key;
  final String label;
  final String emoji;
  final Color? color;
  final String? logoUrl;

  const _FilterOption({
    required this.key,
    required this.label,
    required this.emoji,
    this.color,
    this.logoUrl,
  });
}
