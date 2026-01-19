import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/game.dart';
import '../models/prediction.dart';
import '../services/espn_scores_service.dart';

/// Represents a live or completed game from ESPN
class LiveGame {
  final Game game;
  final String? gameTime;
  final int? homeScore;
  final int? awayScore;
  final bool isLive;
  final bool isCompleted;
  final DateTime lastUpdated;

  const LiveGame({
    required this.game,
    this.gameTime,
    this.homeScore,
    this.awayScore,
    this.isLive = false,
    this.isCompleted = false,
    required this.lastUpdated,
  });

  /// Check if the game has started (live or completed)
  bool get hasStarted => isLive || isCompleted;
}

class LiveScoresProvider extends ChangeNotifier {
  final EspnScoresService _espnService = EspnScoresService();

  List<LiveGame> _liveGames = [];
  Set<String> _favoriteTeams = {};
  Set<String> _activeGameIds = {};
  Set<String> _seenGameIds = {}; // Track loaded game IDs to prevent duplicates
  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _isLoadingMore = false; // For background loading indicator
  Timer? _refreshTimer;
  DateTime? _lastRefresh;
  int _loadProgress = 0; // 0-100 progress indicator

  // Priority sports to load first (for "All" tab)
  static const List<String> _prioritySports = [
    'americanfootball_nfl',
    'basketball_nba',
    'americanfootball_ncaaf',
    'soccer_epl',
    'basketball_ncaab',
  ];

  List<LiveGame> get liveGames => _liveGames;
  Set<String> get favoriteTeams => _favoriteTeams;
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  bool get isLoadingMore => _isLoadingMore;
  int get loadProgress => _loadProgress;
  DateTime? get lastRefresh => _lastRefresh;

  /// Get only games that are currently live/in progress
  List<LiveGame> get ongoingGames => _liveGames.where((g) => g.isLive).toList();

  /// Get games by sport category
  List<LiveGame> getGamesBySport(String sportCategory) {
    switch (sportCategory) {
      case 'nfl':
        return _liveGames.where((g) => g.game.sportKey == 'americanfootball_nfl').toList();
      case 'cfb':
        return _liveGames.where((g) => g.game.sportKey == 'americanfootball_ncaaf').toList();
      case 'nba':
        return _liveGames.where((g) => g.game.sportKey == 'basketball_nba').toList();
      case 'cbb':
        return _liveGames.where((g) => g.game.sportKey == 'basketball_ncaab').toList();
      case 'soccer':
        return _liveGames.where((g) => g.game.sportKey.startsWith('soccer')).toList();
      default:
        return _liveGames;
    }
  }

  /// Get popular games (completed games from popular teams)
  List<LiveGame> get popularGames {
    final popularTeams = [
      'chiefs', 'cowboys', 'eagles', 'packers', '49ers', 'patriots',
      'lakers', 'celtics', 'warriors', 'bulls', 'knicks', 'heat',
      'alabama', 'ohio state', 'georgia', 'michigan', 'texas',
      'manchester', 'arsenal', 'liverpool', 'chelsea', 'real madrid', 'barcelona',
    ];

    return _liveGames.where((g) {
      if (g.isLive) return false; // Don't include ongoing in popular
      final home = g.game.homeTeam.name.toLowerCase();
      final away = g.game.awayTeam.name.toLowerCase();
      return popularTeams.any((t) => home.contains(t) || away.contains(t));
    }).take(5).toList();
  }

  /// Live games the user has active bets on
  List<LiveGame> get activeBetGames {
    return _liveGames
        .where((lg) => _activeGameIds.contains(lg.game.id) ||
                       _activeGameIds.contains('espn_${lg.game.id.replaceFirst('espn_', '')}'))
        .toList();
  }

  /// Live games featuring teams the user frequently bets on
  List<LiveGame> get favoriteTeamGames {
    return _liveGames.where((lg) {
      final homeTeam = lg.game.homeTeam.name.toLowerCase();
      final awayTeam = lg.game.awayTeam.name.toLowerCase();
      return _favoriteTeams.any((fav) =>
          homeTeam.contains(fav.toLowerCase()) ||
          awayTeam.contains(fav.toLowerCase()));
    }).where((lg) => !_isActiveBetGame(lg)).toList();
  }

  bool _isActiveBetGame(LiveGame lg) {
    return _activeGameIds.contains(lg.game.id) ||
           _activeGameIds.contains('espn_${lg.game.id.replaceFirst('espn_', '')}');
  }

  /// All other live games
  List<LiveGame> get otherLiveGames {
    final activeBetIds = activeBetGames.map((lg) => lg.game.id).toSet();
    final favoriteIds = favoriteTeamGames.map((lg) => lg.game.id).toSet();
    return _liveGames
        .where((lg) =>
            !activeBetIds.contains(lg.game.id) &&
            !favoriteIds.contains(lg.game.id))
        .toList();
  }

  bool get hasLiveGames => _liveGames.isNotEmpty;
  bool get hasActiveBets => activeBetGames.isNotEmpty;
  bool get hasFavoriteTeamGames => favoriteTeamGames.isNotEmpty;

  /// Initialize with user's betting history
  void initialize({
    required List<Game> allGames,
    required List<Prediction> predictions,
  }) {
    // Extract favorite teams from betting history
    _extractFavoriteTeams(predictions);

    // Extract active game IDs (pending bets)
    _activeGameIds = predictions
        .where((p) => p.status == PredictionStatus.pending)
        .map((p) => p.gameId)
        .toSet();

    // Fetch real ESPN data from past week
    _fetchPastWeekGames();
  }

  /// Extract teams user frequently bets on
  void _extractFavoriteTeams(List<Prediction> predictions) {
    final teamCounts = <String, int>{};

    for (final prediction in predictions) {
      teamCounts[prediction.homeTeam] =
          (teamCounts[prediction.homeTeam] ?? 0) + 1;
      teamCounts[prediction.awayTeam] =
          (teamCounts[prediction.awayTeam] ?? 0) + 1;
    }

    // Get teams bet on 2+ times
    _favoriteTeams = teamCounts.entries
        .where((e) => e.value >= 2)
        .map((e) => e.key)
        .toSet();
  }

  /// Fetch games progressively - FIRST sport immediately, then others in background
  /// Shows content as fast as possible for better UX
  Future<void> _fetchPastWeekGames() async {
    _isLoading = true;
    _loadProgress = 0;
    _seenGameIds.clear();
    _liveGames = [];
    notifyListeners();

    final allSports = _espnService.supportedSports;
    final remainingSports = allSports.where((s) => !_prioritySports.contains(s)).toList();
    final totalSteps = _prioritySports.length + remainingSports.length + 1;
    int completedSteps = 0;

    // PHASE 1: Load FIRST sport IMMEDIATELY and show it
    debugPrint('ESPN: Phase 1 - Loading first sport immediately (NFL)...');
    final firstSport = _prioritySports.first; // NFL
    try {
      final espnGames = await _espnService.fetchAllGamesForToday(firstSport);
      _addGamesToList(espnGames);
    } catch (e) {
      debugPrint('ESPN: Error fetching $firstSport: $e');
    }
    completedSteps++;
    _loadProgress = 15;

    // IMMEDIATELY show UI with first sport's data
    _sortGames();
    _isLoading = false;
    _isLoadingMore = true;
    notifyListeners();
    debugPrint('ESPN: First sport loaded - ${_liveGames.length} games shown immediately');

    // PHASE 2: Load remaining priority sports in background
    debugPrint('ESPN: Phase 2 - Loading remaining priority sports...');
    for (int i = 1; i < _prioritySports.length; i++) {
      final sportKey = _prioritySports[i];
      try {
        final espnGames = await _espnService.fetchAllGamesForToday(sportKey);
        _addGamesToList(espnGames);
      } catch (e) {
        debugPrint('ESPN: Error fetching $sportKey: $e');
      }
      completedSteps++;
      _loadProgress = ((completedSteps / totalSteps) * 60).round();

      // Update UI after each sport
      _sortGames();
      notifyListeners();
    }
    debugPrint('ESPN: Priority sports complete - ${_liveGames.length} games loaded');

    // PHASE 3: Load remaining sports (background)
    debugPrint('ESPN: Phase 3 - Loading remaining sports...');
    for (final sportKey in remainingSports) {
      try {
        final espnGames = await _espnService.fetchAllGamesForToday(sportKey);
        _addGamesToList(espnGames);
      } catch (e) {
        debugPrint('ESPN: Error fetching $sportKey: $e');
      }
      completedSteps++;
      _loadProgress = ((completedSteps / totalSteps) * 80).round();

      _sortGames();
      notifyListeners();
    }
    debugPrint('ESPN: All sports complete - ${_liveGames.length} games loaded');

    // PHASE 4: Load past week data (deep background)
    debugPrint('ESPN: Phase 4 - Loading past week data...');
    await _loadPastWeekInBackground();

    _loadProgress = 100;
    _isLoadingMore = false;
    _lastRefresh = DateTime.now();
    notifyListeners();

    debugPrint('ESPN Live Scores: Fully loaded ${_liveGames.length} games (${_liveGames.where((g) => g.isLive).length} live, ${_liveGames.where((g) => g.isCompleted).length} completed)');
  }

  /// Load past week data in background without blocking UI
  Future<void> _loadPastWeekInBackground() async {
    final now = DateTime.now();

    // Load days 1-6 (skip today which is already loaded)
    for (int day = 1; day <= 6; day++) {
      final date = now.subtract(Duration(days: day));

      // Load all sports for this day in parallel
      final futures = _espnService.supportedSports.map((sportKey) async {
        try {
          final games = await _espnService.fetchGamesForDate(sportKey, date);
          return games;
        } catch (e) {
          return <EspnGame>[];
        }
      });

      final results = await Future.wait(futures);
      for (final games in results) {
        _addGamesToList(games);
      }

      // Update UI after each day
      _sortGames();
      notifyListeners();
    }
  }

  /// Add games to list, avoiding duplicates
  void _addGamesToList(List<EspnGame> espnGames) {
    for (final eg in espnGames) {
      if (!_seenGameIds.contains(eg.id) && (eg.isLive || eg.isCompleted)) {
        _seenGameIds.add(eg.id);
        _liveGames.add(_espnGameToLiveGame(eg));
      }
    }
  }

  /// Sort games: live first, then by time
  void _sortGames() {
    _liveGames.sort((a, b) {
      if (a.isLive && !b.isLive) return -1;
      if (!a.isLive && b.isLive) return 1;
      return b.game.startTime.compareTo(a.game.startTime);
    });
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

  /// Convert ESPN game to LiveGame
  LiveGame _espnGameToLiveGame(EspnGame eg) {
    final isSoccer = eg.sportKey.startsWith('soccer');

    GameStatus status;
    if (eg.isLive) {
      status = GameStatus.live;
    } else if (eg.isCompleted) {
      status = GameStatus.finished;
    } else {
      status = GameStatus.upcoming;
    }

    // Only use real ESPN odds - no fallback fake odds
    final hasRealOdds = eg.homeMoneyline != null || eg.spreadLine != null || eg.totalLine != null;

    final game = Game(
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
          : null, // No fake odds - show unavailable if ESPN doesn't have data
    );

    return LiveGame(
      game: game,
      gameTime: eg.gameTime,
      homeScore: eg.homeScore,
      awayScore: eg.awayScore,
      isLive: eg.isLive,
      isCompleted: eg.isCompleted,
      lastUpdated: DateTime.now(),
    );
  }

  /// Refresh live scores from ESPN (quick refresh - just today)
  Future<void> refresh(List<Game> allGames) async {
    _isRefreshing = true;
    notifyListeners();

    // Quick refresh: just reload today's games for all sports
    final newGames = <LiveGame>[];
    final newIds = <String>{};

    // Load priority sports first
    for (final sportKey in _prioritySports) {
      try {
        final espnGames = await _espnService.fetchAllGamesForToday(sportKey);
        for (final eg in espnGames) {
          if (!newIds.contains(eg.id) && (eg.isLive || eg.isCompleted)) {
            newIds.add(eg.id);
            newGames.add(_espnGameToLiveGame(eg));
          }
        }
      } catch (e) {
        debugPrint('ESPN refresh error: $e');
      }
    }

    // Load remaining sports
    final remainingSports = _espnService.supportedSports
        .where((s) => !_prioritySports.contains(s));
    for (final sportKey in remainingSports) {
      try {
        final espnGames = await _espnService.fetchAllGamesForToday(sportKey);
        for (final eg in espnGames) {
          if (!newIds.contains(eg.id) && (eg.isLive || eg.isCompleted)) {
            newIds.add(eg.id);
            newGames.add(_espnGameToLiveGame(eg));
          }
        }
      } catch (e) {
        debugPrint('ESPN refresh error: $e');
      }
    }

    // Merge with existing past week data (keep old games not from today)
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final oldGames = _liveGames.where((g) => g.game.startTime.isBefore(todayStart)).toList();

    // Combine: new today + old past games
    _liveGames = [...newGames, ...oldGames];
    _sortGames();

    // Update seen IDs
    _seenGameIds = _liveGames.map((g) => g.game.id.replaceFirst('espn_', '')).toSet();

    _lastRefresh = DateTime.now();
    _isRefreshing = false;
    notifyListeners();
  }

  /// Start auto-refresh timer (every 5 seconds for live score updates)
  void startAutoRefresh(List<Game> Function() gamesProvider) {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      refresh(gamesProvider());
    });
  }

  /// Stop auto-refresh timer
  void stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  /// Update predictions (when user places new bets)
  void updatePredictions(List<Prediction> predictions) {
    _extractFavoriteTeams(predictions);
    _activeGameIds = predictions
        .where((p) => p.status == PredictionStatus.pending)
        .map((p) => p.gameId)
        .toSet();
    notifyListeners();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}
