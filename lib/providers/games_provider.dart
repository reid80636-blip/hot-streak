import 'package:flutter/foundation.dart';

import '../models/game.dart';
import '../models/sport.dart';
import '../config/constants.dart';
import '../services/espn_scores_service.dart';

class GamesProvider extends ChangeNotifier {
  final Map<String, List<Game>> _gamesBySport = {};
  final Map<String, Game> _gamesById = {};
  final EspnScoresService _espnService = EspnScoresService();
  bool _isLoading = false;
  String? _error;
  DateTime? _lastFetch;

  List<Game> getGamesForSport(String sportKey) => _gamesBySport[sportKey] ?? [];

  List<Game> get allGames {
    final all = <Game>[];
    for (final games in _gamesBySport.values) {
      all.addAll(games);
    }
    all.sort((a, b) => a.startTime.compareTo(b.startTime));
    return all;
  }

  /// Get only upcoming games that can be bet on (not live or finished)
  List<Game> get bettableGames {
    return allGames.where((g) => g.isUpcoming && g.odds != null).toList();
  }

  List<Game> get featuredGames {
    final now = DateTime.now();
    return allGames
        .where((g) => g.startTime.isAfter(now) && g.odds != null)
        .take(6)
        .toList();
  }

  Game? getGameById(String id) => _gamesById[id];

  /// Fetch fresh data for a single game (bypasses cache) - used for live score updates
  Future<Game?> refreshGameById(String gameId) async {
    // Strip espn_ prefix if present to get the ESPN event ID
    final espnId = gameId.replaceFirst('espn_', '');

    // Find the sport key from cached game
    final cachedGame = _gamesById[gameId];
    if (cachedGame == null) return null;

    final sportKey = cachedGame.sportKey;
    if (!_espnService.supportsSport(sportKey)) return cachedGame;

    try {
      // Fetch fresh game data from ESPN
      final games = await _espnService.fetchAllGamesForToday(sportKey);

      // Find the matching game
      for (final eg in games) {
        if (eg.id == espnId) {
          final updatedGame = _espnGameToGame(eg);

          // Update cache
          _gamesById[gameId] = updatedGame;

          // Update in sport list
          final sportGames = _gamesBySport[sportKey];
          if (sportGames != null) {
            final index = sportGames.indexWhere((g) => g.id == gameId);
            if (index >= 0) {
              sportGames[index] = updatedGame;
            }
          }

          notifyListeners();
          return updatedGame;
        }
      }
    } catch (e) {
      debugPrint('Error refreshing game $gameId: $e');
    }

    return cachedGame;
  }

  bool get isLoading => _isLoading;
  String? get error => _error;

  bool get shouldRefresh {
    if (_lastFetch == null) return true;
    return DateTime.now().difference(_lastFetch!) > AppConstants.cacheExpiry;
  }

  Future<void> fetchGames({String? sportKey, bool force = false}) async {
    if (_isLoading) return;
    if (!force && !shouldRefresh && _gamesBySport.isNotEmpty) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (sportKey != null) {
        // Single sport fetch
        final games = await _fetchGamesForSport(sportKey);
        _gamesBySport[sportKey] = games;
        for (final game in games) {
          _gamesById[game.id] = game;
        }
      } else {
        // Phased loading for better perceived performance
        // Phase 1: Load priority sports first (most popular)
        final prioritySports = [
          'basketball_nba',
          'americanfootball_nfl',
          'basketball_ncaab',
        ];

        for (final key in prioritySports) {
          final games = await _fetchGamesForSport(key);
          _gamesBySport[key] = games;
          for (final game in games) {
            _gamesById[game.id] = game;
          }
        }

        // Notify after priority sports so UI updates quickly
        _isLoading = false;
        notifyListeners();
        _isLoading = true;

        // Phase 2: Load remaining sports
        final remainingSports = Sport.all
            .map((s) => s.key)
            .where((key) => !prioritySports.contains(key))
            .toList();

        for (final key in remainingSports) {
          final games = await _fetchGamesForSport(key);
          _gamesBySport[key] = games;
          for (final game in games) {
            _gamesById[game.id] = game;
          }
        }
      }

      _lastFetch = DateTime.now();
    } catch (e) {
      _error = e.toString();
      debugPrint('Error fetching games: $e');
      // No mock data fallback - show "no games" when errors occur
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<List<Game>> _fetchGamesForSport(String sportKey) async {
    // Use ESPN for game schedule - it includes spread/total lines when available
    if (_espnService.supportsSport(sportKey)) {
      try {
        List<EspnGame> espnGames;

        // Fetch multiple days for major sports to have more games
        final daysToFetch = _getDaysToFetch(sportKey);
        if (daysToFetch > 1) {
          espnGames = await _espnService.fetchUpcomingGamesForDays(sportKey, daysToFetch);
        } else {
          espnGames = await _espnService.fetchAllGamesForToday(sportKey);
        }

        // Only return upcoming games from ESPN
        var upcomingGames = espnGames
            .where((eg) => !eg.isLive && !eg.isCompleted)
            .map((eg) => _espnGameToGame(eg))
            .toList();

        // Remove duplicates (same teams, same day)
        upcomingGames = _removeDuplicateGames(upcomingGames);

        // Limit games per sport to prevent memory issues
        final maxGames = _getMaxGamesForSport(sportKey);
        if (upcomingGames.length > maxGames) {
          // Sort by start time and take the closest games
          upcomingGames.sort((a, b) => a.startTime.compareTo(b.startTime));
          upcomingGames = upcomingGames.take(maxGames).toList();
        }

        debugPrint('ESPN: Got ${upcomingGames.length} upcoming games for $sportKey');
        return upcomingGames;
      } catch (e) {
        debugPrint('ESPN failed for $sportKey: $e');
      }
    }

    // No games available (offseason or error) - return empty list
    debugPrint('No games available for $sportKey (possibly offseason)');
    return [];
  }

  /// Remove duplicate games (same matchup on same day)
  List<Game> _removeDuplicateGames(List<Game> games) {
    final seen = <String>{};
    final uniqueGames = <Game>[];

    for (final game in games) {
      // Create a unique key based on teams and date (not exact time)
      final dateKey = '${game.startTime.year}-${game.startTime.month}-${game.startTime.day}';
      final teamsKey = [game.homeTeam.name, game.awayTeam.name]..sort();
      final uniqueKey = '${game.sportKey}_${teamsKey.join('_')}_$dateKey';

      if (!seen.contains(uniqueKey)) {
        seen.add(uniqueKey);
        uniqueGames.add(game);
      }
    }

    if (games.length != uniqueGames.length) {
      debugPrint('Removed ${games.length - uniqueGames.length} duplicate games');
    }

    return uniqueGames;
  }

  /// Get max games per sport to prevent memory issues
  int _getMaxGamesForSport(String sportKey) {
    switch (sportKey) {
      // College sports have tons of games - limit more
      case 'basketball_ncaab':
        return 50; // Limit to 50 most recent
      case 'americanfootball_ncaaf':
        return 40;
      // Pro leagues - can handle more
      case 'basketball_nba':
      case 'icehockey_nhl':
      case 'baseball_mlb':
        return 30;
      case 'americanfootball_nfl':
        return 20;
      // Soccer leagues
      case 'soccer_epl':
      case 'soccer_spain_la_liga':
      case 'soccer_italy_serie_a':
      case 'soccer_germany_bundesliga':
      case 'soccer_france_ligue_one':
      case 'soccer_usa_mls':
      case 'soccer_uefa_champs_league':
        return 25;
      default:
        return 20;
    }
  }

  /// Get number of days to fetch for each sport
  int _getDaysToFetch(String sportKey) {
    switch (sportKey) {
      // College sports have many games, fetch a week
      case 'basketball_ncaab':
      case 'americanfootball_ncaaf':
        return 7;
      // Pro leagues - fetch 5 days for more games
      case 'basketball_nba':
      case 'icehockey_nhl':
      case 'baseball_mlb':
        return 5;
      // NFL has games mostly on weekends, fetch a week
      case 'americanfootball_nfl':
        return 7;
      // Soccer leagues - fetch 5 days
      case 'soccer_epl':
      case 'soccer_spain_la_liga':
      case 'soccer_italy_serie_a':
      case 'soccer_germany_bundesliga':
      case 'soccer_france_ligue_one':
      case 'soccer_usa_mls':
      case 'soccer_uefa_champs_league':
        return 5;
      default:
        return 1;
    }
  }

  /// Convert American odds (-110) to decimal odds (1.91)
  double _americanToDecimal(double? american) {
    if (american == null) return 1.91; // Default to -110 equivalent
    if (american >= 0) {
      return (american / 100) + 1;
    } else {
      return (100 / american.abs()) + 1;
    }
  }

  /// Convert ESPN game to app Game model
  Game _espnGameToGame(EspnGame eg) {
    final isSoccer = eg.sportKey.startsWith('soccer');
    final isMLS = eg.sportKey == 'soccer_usa_mls';

    // Determine game status
    GameStatus status;
    if (eg.isLive) {
      status = GameStatus.live;
    } else if (eg.isCompleted) {
      status = GameStatus.finished;
    } else {
      status = GameStatus.upcoming;
    }

    // MLS games don't have betting - no odds
    if (isMLS) {
      return Game(
        id: 'espn_${eg.id}',
        sportKey: eg.sportKey,
        homeTeam: Team(
          name: eg.homeTeam,
          score: eg.homeScore,
          logoUrl: eg.homeLogo,
        ),
        awayTeam: Team(
          name: eg.awayTeam,
          score: eg.awayScore,
          logoUrl: eg.awayLogo,
        ),
        startTime: eg.startTime,
        status: status,
        gameTime: eg.gameTime,
        odds: null, // No betting on MLS
      );
    }

    // Only use real ESPN odds from DraftKings - no fallback fake odds
    final hasRealOdds = eg.homeMoneyline != null || eg.spreadLine != null || eg.totalLine != null;

    return Game(
      id: 'espn_${eg.id}',
      sportKey: eg.sportKey,
      homeTeam: Team(
        name: eg.homeTeam,
        score: eg.homeScore,
        logoUrl: eg.homeLogo,
      ),
      awayTeam: Team(
        name: eg.awayTeam,
        score: eg.awayScore,
        logoUrl: eg.awayLogo,
      ),
      startTime: eg.startTime,
      status: status,
      gameTime: eg.gameTime,
      odds: hasRealOdds
          ? Odds(
              // Real moneyline odds from ESPN/DraftKings
              home: _americanToDecimal(eg.homeMoneyline),
              away: _americanToDecimal(eg.awayMoneyline),
              draw: isSoccer ? 3.20 : null,
              // Real spread odds
              homeSpread: isSoccer ? null : _americanToDecimal(eg.homeSpreadOdds),
              awaySpread: isSoccer ? null : _americanToDecimal(eg.awaySpreadOdds),
              spreadLine: eg.spreadLine,
              // Real totals odds
              overOdds: _americanToDecimal(eg.overOdds),
              underOdds: _americanToDecimal(eg.underOdds),
              totalLine: eg.totalLine,
            )
          : null, // No fake odds - show "odds not available" if ESPN doesn't have data
    );
  }

}
