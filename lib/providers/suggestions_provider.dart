import 'package:flutter/foundation.dart';

import '../models/game.dart';
import '../models/prediction.dart';
import '../services/analytics_service.dart';

/// Represents a suggested game with reason
class GameSuggestion {
  final Game game;
  final String reason;
  final double score;

  const GameSuggestion({
    required this.game,
    required this.reason,
    required this.score,
  });
}

/// Provider for personalized game suggestions
class SuggestionsProvider extends ChangeNotifier {
  final AnalyticsService _analyticsService = AnalyticsService();

  List<GameSuggestion> _suggestions = [];
  UserBettingPatterns _patterns = UserBettingPatterns.empty;
  List<String> _followedTeams = []; // User's explicitly followed teams
  List<String> _followedSports = []; // User's explicitly followed sports
  bool _isLoaded = false;

  List<GameSuggestion> get suggestions => _suggestions;
  UserBettingPatterns get patterns => _patterns;
  List<String> get followedTeams => _followedTeams;
  List<String> get followedSports => _followedSports;
  bool get hasSuggestions => _suggestions.isNotEmpty;
  bool get isLoaded => _isLoaded;

  /// Set user's followed teams from profile
  void setFollowedTeams(List<String> teams) {
    _followedTeams = teams;
    notifyListeners();
  }

  /// Set user's followed sports from profile
  void setFollowedSports(List<String> sports) {
    _followedSports = sports;
    notifyListeners();
  }

  /// Generate personalized suggestions based on betting history and followed teams
  void generateSuggestions({
    required List<Game> allGames,
    required List<Prediction> history,
  }) {
    // Analyze user patterns
    _patterns = _analyticsService.analyzeHistory(history);

    final now = DateTime.now();
    final upcomingGames = allGames
        .where((g) => g.startTime.isAfter(now) && !g.isFinished)
        .toList();

    if (upcomingGames.isEmpty) {
      _suggestions = [];
      _isLoaded = true;
      notifyListeners();
      return;
    }

    // Score each game based on relevance
    final scoredGames = <GameSuggestion>[];

    for (final game in upcomingGames) {
      double score = 0;
      String? reason;

      // Highest priority: User's explicitly followed teams (from onboarding)
      final homeTeam = game.homeTeam.name;
      final awayTeam = game.awayTeam.name;

      if (_followedTeams.contains(homeTeam)) {
        score += 100; // High priority for followed teams
        reason = 'Your team $homeTeam is playing';
      } else if (_followedTeams.contains(awayTeam)) {
        score += 100;
        reason = 'Your team $awayTeam is playing';
      }

      // Second priority: User's followed sports
      // Handle special case: 'soccer_all' matches any soccer league
      final matchesSport = _followedSports.contains(game.sportKey) ||
          (_followedSports.contains('soccer_all') && game.sportKey.startsWith('soccer_'));
      if (matchesSport) {
        score += 50; // Medium priority for followed sports
        reason ??= 'From your favorite sports';
      }

      // Also consider betting history patterns
      if (_patterns.hasHistory) {
        final historyScore = _analyticsService.getGameRelevanceScore(
          homeTeam,
          awayTeam,
          game.sportKey,
          _patterns,
        );
        score += historyScore;

        // Use history-based reason if no followed team reason
        if (reason == null && historyScore > 0) {
          reason = _generateReason(game);
        }
      }

      if (score > 0) {
        scoredGames.add(GameSuggestion(
          game: game,
          reason: reason ?? 'Recommended for you',
          score: score,
        ));
      }
    }

    // If no suggestions based on followed teams or history, show popular games
    if (scoredGames.isEmpty && upcomingGames.isNotEmpty) {
      // Add some games with odds as recommendations
      final gamesWithOdds = upcomingGames.where((g) => g.odds != null).take(6);
      for (final game in gamesWithOdds) {
        scoredGames.add(GameSuggestion(
          game: game,
          reason: 'Popular matchup',
          score: 1,
        ));
      }
    }

    // Sort by score and take top suggestions
    scoredGames.sort((a, b) => b.score.compareTo(a.score));
    _suggestions = scoredGames.take(6).toList();
    _isLoaded = true;

    notifyListeners();
  }

  /// Generate a human-readable reason for the suggestion
  String _generateReason(Game game) {
    final homeTeam = game.homeTeam.name;
    final awayTeam = game.awayTeam.name;

    // Check if favorite team is playing
    if (_patterns.favoriteTeams.isNotEmpty) {
      if (_patterns.favoriteTeams.contains(homeTeam)) {
        return 'Based on your ${homeTeam} bets';
      }
      if (_patterns.favoriteTeams.contains(awayTeam)) {
        return 'Based on your ${awayTeam} bets';
      }
    }

    // Check if favorite sport (including soccer_all handling)
    final isFavoriteSport = _patterns.favoriteSports.contains(game.sportKey) ||
        (_patterns.favoriteSports.contains('soccer_all') && game.sportKey.startsWith('soccer_'));
    if (isFavoriteSport) {
      final winRate = _patterns.winRateBySport[game.sportKey];
      if (winRate != null && winRate > 0.5) {
        return 'You\'re ${(winRate * 100).toInt()}% in this sport';
      }
      return 'One of your favorite sports';
    }

    return 'Recommended for you';
  }

  /// Get games featuring a specific team
  List<Game> getGamesForTeam(List<Game> allGames, String teamName) {
    return allGames.where((game) {
      return game.homeTeam.name == teamName || game.awayTeam.name == teamName;
    }).toList();
  }

  /// Get games for user's favorite sport with best win rate
  List<Game> getHotSportGames(List<Game> allGames) {
    if (_patterns.winRateBySport.isEmpty) return [];

    // Find sport with best win rate (min 40% sample)
    String? hotSport;
    double bestRate = 0;

    for (final entry in _patterns.winRateBySport.entries) {
      if (entry.value > bestRate && entry.value >= 0.4) {
        bestRate = entry.value;
        hotSport = entry.key;
      }
    }

    if (hotSport == null) return [];

    return allGames.where((g) => g.sportKey == hotSport).toList();
  }

  /// Clear suggestions
  void clear() {
    _suggestions = [];
    _patterns = UserBettingPatterns.empty;
    _followedTeams = [];
    _followedSports = [];
    _isLoaded = false;
    notifyListeners();
  }
}
