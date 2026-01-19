import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../config/design_system.dart';
import '../../models/game.dart';
import '../../models/sport.dart';
import '../../providers/games_provider.dart';
import '../../providers/predictions_provider.dart';
import '../../providers/suggestions_provider.dart';
import '../../widgets/common/game_card.dart';
import '../../widgets/common/sport_chip.dart';

class GamesListScreen extends StatefulWidget {
  final String? initialSportKey;

  const GamesListScreen({super.key, this.initialSportKey});

  @override
  State<GamesListScreen> createState() => _GamesListScreenState();
}

class _GamesListScreenState extends State<GamesListScreen> {
  String? _selectedSportKey;

  @override
  void initState() {
    super.initState();
    _selectedSportKey = widget.initialSportKey;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GamesProvider>().fetchGames();
      _generateSuggestions();
    });
  }

  void _generateSuggestions() {
    final games = context.read<GamesProvider>().allGames;
    final predictions = context.read<PredictionsProvider>().predictions;
    final suggestions = context.read<SuggestionsProvider>();

    suggestions.generateSuggestions(allGames: games, history: predictions);
  }

  /// Get combined games list with sections: For You, Popular, All Games
  List<_GameDisplayItem> _getCombinedGames(
    GamesProvider gamesProvider,
    SuggestionsProvider suggestionsProvider,
  ) {
    final seenIds = <String>{};
    final displayItems = <_GameDisplayItem>[];

    // Base filter: only upcoming games with odds (bettable)
    final bettableGames = gamesProvider.allGames
        .where((g) => g.isUpcoming && g.odds != null)
        .toList();

    // Apply sport filter if selected
    List<Game> filteredBettable = bettableGames;
    if (_selectedSportKey != null) {
      if (_selectedSportKey == 'soccer_all') {
        // Filter for all soccer leagues
        filteredBettable = bettableGames
            .where((g) => g.sportKey.startsWith('soccer_'))
            .toList();
      } else {
        filteredBettable = bettableGames
            .where((g) => g.sportKey == _selectedSportKey)
            .toList();
      }
    }

    // 1. Add "For You" suggestions first (personalized)
    final suggestions = suggestionsProvider.suggestions
        .map((s) => s.game)
        .where((g) => g.isUpcoming && g.odds != null)
        .where((g) => _selectedSportKey == null ||
            (_selectedSportKey == 'soccer_all' ? g.sportKey.startsWith('soccer_') : g.sportKey == _selectedSportKey))
        .toList();

    if (suggestions.isNotEmpty) {
      // Add section header
      displayItems.add(_GameDisplayItem.sectionHeader('For You'));

      for (final game in suggestions) {
        if (!seenIds.contains(game.id)) {
          seenIds.add(game.id);
          displayItems.add(_GameDisplayItem(game: game));
        }
      }
    }

    // 2. Add "Popular" games (using smart popularity scoring)
    final popularGames = List<Game>.from(filteredBettable)
      ..sort((a, b) {
        final aScore = _PopularityScorer.getPopularityScore(a);
        final bScore = _PopularityScorer.getPopularityScore(b);
        return bScore.compareTo(aScore); // Higher score first
      });

    final popularToShow = <Game>[];
    // Only show games that meet the popularity threshold
    for (final game in popularGames) {
      if (popularToShow.length >= 6) break; // Limit to 6 popular games
      if (!seenIds.contains(game.id) && _PopularityScorer.isPopular(game)) {
        seenIds.add(game.id);
        popularToShow.add(game);
      }
    }

    if (popularToShow.isNotEmpty) {
      // Add section header
      displayItems.add(_GameDisplayItem.sectionHeader('Popular'));

      for (final game in popularToShow) {
        displayItems.add(_GameDisplayItem(game: game));
      }
    }

    // 3. Add ALL remaining games, sorted by start time
    final remainingGames = filteredBettable
        .where((g) => !seenIds.contains(g.id))
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    if (remainingGames.isNotEmpty) {
      // Add section header
      displayItems.add(_GameDisplayItem.sectionHeader('All Games'));

      for (final game in remainingGames) {
        seenIds.add(game.id);
        displayItems.add(_GameDisplayItem(game: game));
      }
    }

    return displayItems;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
              child: Row(
                children: [
                  const Text(
                    'Games',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.glassBackground(0.5),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.borderGlow),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.refresh),
                      color: AppColors.accentCyan,
                      onPressed: () {
                        context.read<GamesProvider>().fetchGames(force: true);
                        _generateSuggestions();
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Sport filters
            SportChipsRow(
              selectedSportKey: _selectedSportKey,
              onSportSelected: (key) {
                setState(() => _selectedSportKey = key);
              },
            ),

            const SizedBox(height: 12),

            // Games list (combined For You + Popular)
            Expanded(
              child: Consumer2<GamesProvider, SuggestionsProvider>(
                builder: (context, gamesProvider, suggestionsProvider, child) {
                  if (gamesProvider.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final displayItems = _getCombinedGames(
                    gamesProvider,
                    suggestionsProvider,
                  );

                  if (displayItems.isEmpty) {
                    return _buildEmptyState();
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      await gamesProvider.fetchGames(force: true);
                      _generateSuggestions();
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: displayItems.length,
                      itemBuilder: (context, index) {
                        final item = displayItems[index];

                        // Render section header
                        if (item.isHeader) {
                          return _SectionHeader(
                            title: item.sectionHeader!,
                            icon: _getSectionIcon(item.sectionHeader!),
                          );
                        }

                        // Render game card
                        return GameCard(
                          game: item.game!,
                          showSportBadge: _selectedSportKey == null,
                        ).animate(delay: (index * 20).ms).fadeIn().slideX(
                              begin: 0.03,
                              end: 0,
                            );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getSectionIcon(String section) {
    switch (section) {
      case 'For You':
        return Icons.star_rounded;
      case 'Popular':
        return Icons.local_fire_department_rounded;
      case 'All Games':
        return Icons.sports;
      default:
        return Icons.sports;
    }
  }

  Widget _buildEmptyState() {
    final sportName = _selectedSportKey != null
        ? (_selectedSportKey == 'soccer_all' ? 'Soccer' : Sport.fromKey(_selectedSportKey!)?.name ?? 'games')
        : 'upcoming games';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: AppColors.glassBackground(0.4),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.borderGlow),
            ),
            child: Icon(Icons.sports, size: 48, color: AppColors.textMutedOp),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'No $sportName to bet on',
            style: TextStyle(
              color: AppColors.textSecondaryOp,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          TextButton(
            onPressed: () {
              context.read<GamesProvider>().fetchGames(force: true);
              _generateSuggestions();
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accentCyan,
            ),
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }
}

/// Helper class to track game display items with optional section headers
class _GameDisplayItem {
  final Game? game;
  final String? sectionHeader;
  final bool isHeader;

  const _GameDisplayItem({
    this.game,
    this.sectionHeader,
    this.isHeader = false,
  });

  factory _GameDisplayItem.sectionHeader(String title) {
    return _GameDisplayItem(
      sectionHeader: title,
      isHeader: true,
    );
  }
}

/// Smart popularity scoring for games
class _PopularityScorer {
  /// Popular/big market teams by sport
  static const Map<String, Set<String>> _popularTeams = {
    'americanfootball_nfl': {
      'Dallas Cowboys', 'Kansas City Chiefs', 'San Francisco 49ers',
      'Green Bay Packers', 'New England Patriots', 'Philadelphia Eagles',
      'Buffalo Bills', 'Las Vegas Raiders', 'Denver Broncos', 'Chicago Bears',
      'New York Giants', 'New York Jets', 'Miami Dolphins', 'Baltimore Ravens',
      'Pittsburgh Steelers', 'Los Angeles Rams', 'Los Angeles Chargers',
    },
    'basketball_nba': {
      'Los Angeles Lakers', 'LA Lakers', 'Golden State Warriors', 'Boston Celtics',
      'New York Knicks', 'Chicago Bulls', 'Miami Heat', 'Brooklyn Nets',
      'Philadelphia 76ers', 'Dallas Mavericks', 'Phoenix Suns', 'Denver Nuggets',
      'Milwaukee Bucks', 'LA Clippers', 'Houston Rockets', 'Cleveland Cavaliers',
    },
    'basketball_ncaab': {
      'Duke Blue Devils', 'Duke', 'North Carolina Tar Heels', 'North Carolina', 'UNC',
      'Kansas Jayhawks', 'Kansas', 'Kentucky Wildcats', 'Kentucky',
      'UCLA Bruins', 'UCLA', 'UConn Huskies', 'UConn', 'Connecticut',
      'Gonzaga Bulldogs', 'Gonzaga', 'Michigan State Spartans', 'Michigan State',
      'Indiana Hoosiers', 'Indiana', 'Villanova Wildcats', 'Villanova',
      'Arizona Wildcats', 'Arizona', 'Houston Cougars', 'Houston',
      'Purdue Boilermakers', 'Purdue', 'Tennessee Volunteers', 'Tennessee',
      'Auburn Tigers', 'Auburn', 'Alabama Crimson Tide', 'Alabama',
    },
    'americanfootball_ncaaf': {
      'Alabama Crimson Tide', 'Alabama', 'Ohio State Buckeyes', 'Ohio State',
      'Georgia Bulldogs', 'Georgia', 'Michigan Wolverines', 'Michigan',
      'Notre Dame Fighting Irish', 'Notre Dame', 'Texas Longhorns', 'Texas',
      'USC Trojans', 'USC', 'LSU Tigers', 'LSU', 'Clemson Tigers', 'Clemson',
      'Oklahoma Sooners', 'Oklahoma', 'Penn State Nittany Lions', 'Penn State',
      'Florida State Seminoles', 'Florida State', 'Oregon Ducks', 'Oregon',
      'Florida Gators', 'Florida', 'Tennessee Volunteers', 'Tennessee',
    },
    'icehockey_nhl': {
      'Toronto Maple Leafs', 'Toronto', 'TOR', 'Montreal Canadiens', 'Montreal', 'MTL',
      'New York Rangers', 'NYR', 'Chicago Blackhawks', 'Chicago', 'CHI',
      'Boston Bruins', 'Boston', 'BOS', 'Vegas Golden Knights', 'Vegas', 'VGK',
      'Edmonton Oilers', 'Edmonton', 'EDM', 'Pittsburgh Penguins', 'Pittsburgh', 'PIT',
      'Colorado Avalanche', 'Colorado', 'COL', 'Detroit Red Wings', 'Detroit', 'DET',
    },
    'baseball_mlb': {
      'New York Yankees', 'Yankees', 'NYY', 'Los Angeles Dodgers', 'Dodgers', 'LAD',
      'Boston Red Sox', 'Red Sox', 'BOS', 'Chicago Cubs', 'Cubs', 'CHC',
      'San Francisco Giants', 'Giants', 'SF', 'St. Louis Cardinals', 'Cardinals', 'STL',
      'Philadelphia Phillies', 'Phillies', 'PHI', 'Atlanta Braves', 'Braves', 'ATL',
      'Houston Astros', 'Astros', 'HOU', 'New York Mets', 'Mets', 'NYM',
    },
    'soccer_epl': {
      'Manchester United', 'Man United', 'MAN', 'Liverpool', 'LIV',
      'Manchester City', 'Man City', 'MNC', 'Chelsea', 'CHE',
      'Arsenal', 'ARS', 'Tottenham', 'Tottenham Hotspur', 'TOT',
      'Newcastle', 'Newcastle United', 'NEW',
    },
    'soccer_spain_la_liga': {
      'Real Madrid', 'RMA', 'Barcelona', 'BAR', 'Atletico Madrid', 'ATM',
    },
    'soccer_uefa_champs_league': {
      'Real Madrid', 'RMA', 'Barcelona', 'BAR', 'Manchester City', 'MNC',
      'Bayern Munich', 'BAY', 'PSG', 'Paris Saint-Germain', 'Liverpool', 'LIV',
      'Manchester United', 'MAN', 'Chelsea', 'CHE', 'Arsenal', 'ARS',
      'Inter Milan', 'INT', 'AC Milan', 'MIL', 'Juventus', 'JUV',
      'Borussia Dortmund', 'DOR', 'Atletico Madrid', 'ATM',
    },
    'soccer_usa_mls': {
      'LA Galaxy', 'LAG', 'LAFC', 'Inter Miami', 'MIA',
      'New York Red Bulls', 'NYRB', 'Atlanta United', 'ATL',
      'Seattle Sounders', 'SEA', 'Portland Timbers', 'POR',
    },
  };

  /// Classic rivalry matchups that draw high viewership
  static const List<List<String>> _rivalries = [
    // NFL
    ['Cowboys', 'Eagles'], ['Cowboys', 'Giants'], ['Cowboys', 'Commanders'],
    ['Packers', 'Bears'], ['Packers', 'Vikings'], ['Steelers', 'Ravens'],
    ['Chiefs', '49ers'], ['Patriots', 'Jets'], ['Raiders', 'Chiefs'],
    // NBA
    ['Lakers', 'Celtics'], ['Lakers', 'Clippers'], ['Lakers', 'Warriors'],
    ['Knicks', 'Nets'], ['Heat', 'Celtics'], ['Bulls', 'Pistons'],
    // NCAAB
    ['Duke', 'North Carolina'], ['Duke', 'UNC'], ['Kentucky', 'Louisville'],
    ['Kansas', 'Missouri'], ['Indiana', 'Purdue'], ['Michigan', 'Michigan State'],
    ['UCLA', 'USC'], ['Arizona', 'Arizona State'],
    // NCAAF
    ['Alabama', 'Auburn'], ['Ohio State', 'Michigan'], ['USC', 'UCLA'],
    ['Texas', 'Oklahoma'], ['Florida', 'Georgia'], ['Clemson', 'South Carolina'],
    ['Notre Dame', 'USC'], ['Oregon', 'Oregon State'],
    // NHL
    ['Rangers', 'Islanders'], ['Bruins', 'Canadiens'], ['Penguins', 'Capitals'],
    ['Maple Leafs', 'Canadiens'], ['Blackhawks', 'Red Wings'],
    // Soccer
    ['Manchester United', 'Liverpool'], ['Manchester City', 'Manchester United'],
    ['Real Madrid', 'Barcelona'], ['Arsenal', 'Tottenham'], ['Chelsea', 'Arsenal'],
    ['Inter Milan', 'AC Milan'], ['Bayern', 'Dortmund'],
    // MLS
    ['LA Galaxy', 'LAFC'], ['Seattle', 'Portland'], ['New York', 'Red Bulls'],
  ];

  /// Calculate popularity score for a game (higher = more popular)
  static double getPopularityScore(Game game) {
    double score = 0;

    // 1. Team popularity (0-40 points)
    final sportTeams = _popularTeams[game.sportKey] ?? {};
    final homePopular = sportTeams.any((t) =>
        game.homeTeam.name.toLowerCase().contains(t.toLowerCase()) ||
        t.toLowerCase().contains(game.homeTeam.name.toLowerCase()));
    final awayPopular = sportTeams.any((t) =>
        game.awayTeam.name.toLowerCase().contains(t.toLowerCase()) ||
        t.toLowerCase().contains(game.awayTeam.name.toLowerCase()));

    if (homePopular) score += 20;
    if (awayPopular) score += 20;

    // 2. Rivalry bonus (0-25 points)
    final homeName = game.homeTeam.name.toLowerCase();
    final awayName = game.awayTeam.name.toLowerCase();
    for (final rivalry in _rivalries) {
      final team1 = rivalry[0].toLowerCase();
      final team2 = rivalry[1].toLowerCase();
      if ((homeName.contains(team1) && awayName.contains(team2)) ||
          (homeName.contains(team2) && awayName.contains(team1))) {
        score += 25;
        break;
      }
    }

    // 3. Prime time bonus (0-15 points)
    final hour = game.startTime.hour;
    final weekday = game.startTime.weekday;
    final isWeekend = weekday == DateTime.saturday || weekday == DateTime.sunday;
    final isPrimeTime = hour >= 17 && hour <= 22; // 5pm - 10pm
    final isAfternoon = hour >= 12 && hour <= 17;

    if (isWeekend && isPrimeTime) {
      score += 15; // Weekend prime time
    } else if (isWeekend && isAfternoon) {
      score += 12; // Weekend afternoon
    } else if (isPrimeTime) {
      score += 10; // Weekday prime time
    } else if (isAfternoon) {
      score += 5; // Weekday afternoon
    }

    // 4. Sport-specific bonuses
    // NFL games are always popular
    if (game.sportKey == 'americanfootball_nfl') {
      score += 10;
    }
    // Champions League knockout games
    if (game.sportKey == 'soccer_uefa_champs_league') {
      score += 8;
    }
    // March Madness boost (March/April)
    if (game.sportKey == 'basketball_ncaab') {
      final month = game.startTime.month;
      if (month == 3 || month == 4) {
        score += 10;
      }
    }

    // 5. Close odds bonus (competitive game) - 0-10 points
    if (game.odds != null) {
      final spread = (game.odds!.home - game.odds!.away).abs();
      if (spread < 0.3) {
        score += 10; // Very close odds
      } else if (spread < 0.5) {
        score += 5; // Fairly close
      }
    }

    return score;
  }

  /// Check if a game is popular enough to feature
  static bool isPopular(Game game) {
    return getPopularityScore(game) >= 25;
  }
}

/// Section header for games list - Blue Aura style
class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({
    required this.title,
    required this.icon,
  });

  Color get _iconColor {
    switch (title) {
      case 'For You':
        return AppColors.accentCyan;
      case 'Popular':
        return AppColors.liveRed;
      default:
        return AppColors.textSecondaryOp;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.sm),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _iconColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, color: _iconColor, size: 18),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              color: _iconColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _iconColor.withOpacity(0.3),
                    AppColors.borderSubtle,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
