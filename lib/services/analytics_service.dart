import '../models/prediction.dart';

/// User betting patterns derived from prediction history
class UserBettingPatterns {
  final List<String> favoriteTeams;
  final List<String> favoriteSports;
  final Map<String, double> winRateBySport;
  final Map<PredictionType, int> betTypeCount;
  final int totalBets;
  final int totalWins;
  final double overallWinRate;

  const UserBettingPatterns({
    required this.favoriteTeams,
    required this.favoriteSports,
    required this.winRateBySport,
    required this.betTypeCount,
    required this.totalBets,
    required this.totalWins,
    required this.overallWinRate,
  });

  static const empty = UserBettingPatterns(
    favoriteTeams: [],
    favoriteSports: [],
    winRateBySport: {},
    betTypeCount: {},
    totalBets: 0,
    totalWins: 0,
    overallWinRate: 0,
  );

  bool get hasHistory => totalBets > 0;
  bool get hasSignificantHistory => totalBets >= 3;
}

/// Service to analyze user betting patterns
class AnalyticsService {
  /// Analyze prediction history to find user patterns
  UserBettingPatterns analyzeHistory(List<Prediction> predictions) {
    if (predictions.isEmpty) {
      return UserBettingPatterns.empty;
    }

    // Count team bets (weight recent bets higher)
    final teamCounts = <String, double>{};
    final sportCounts = <String, double>{};
    final sportWins = <String, int>{};
    final sportTotal = <String, int>{};
    final betTypeCounts = <PredictionType, int>{};

    int totalWins = 0;
    int settledBets = 0;

    final now = DateTime.now();

    for (final pred in predictions) {
      // Calculate recency weight (more recent = higher weight)
      final daysSinceBet = now.difference(pred.createdAt).inDays;
      final recencyWeight = _calculateRecencyWeight(daysSinceBet);

      // Track teams bet on
      final teamName = _getTeamName(pred);
      if (teamName != null) {
        teamCounts[teamName] = (teamCounts[teamName] ?? 0) + recencyWeight;
      }

      // Track sports
      final sportKey = pred.sportKey;
      sportCounts[sportKey] = (sportCounts[sportKey] ?? 0) + recencyWeight;

      // Track bet types
      betTypeCounts[pred.type] =
          (betTypeCounts[pred.type] ?? 0) + 1;

      // Track win rates for settled bets
      if (pred.status == PredictionStatus.won ||
          pred.status == PredictionStatus.lost) {
        settledBets++;
        sportTotal[sportKey] = (sportTotal[sportKey] ?? 0) + 1;

        if (pred.status == PredictionStatus.won) {
          totalWins++;
          sportWins[sportKey] = (sportWins[sportKey] ?? 0) + 1;
        }
      }
    }

    // Calculate win rate by sport
    final winRateBySport = <String, double>{};
    for (final sport in sportTotal.keys) {
      final wins = sportWins[sport] ?? 0;
      final total = sportTotal[sport]!;
      winRateBySport[sport] = total > 0 ? wins / total : 0;
    }

    // Sort and get top teams/sports
    final sortedTeams = teamCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final sortedSports = sportCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return UserBettingPatterns(
      favoriteTeams: sortedTeams.take(5).map((e) => e.key).toList(),
      favoriteSports: sortedSports.take(3).map((e) => e.key).toList(),
      winRateBySport: winRateBySport,
      betTypeCount: betTypeCounts,
      totalBets: predictions.length,
      totalWins: totalWins,
      overallWinRate: settledBets > 0 ? totalWins / settledBets : 0,
    );
  }

  /// Calculate weight based on how recent the bet was
  double _calculateRecencyWeight(int daysSinceBet) {
    if (daysSinceBet <= 1) return 3.0; // Today/yesterday
    if (daysSinceBet <= 7) return 2.0; // This week
    if (daysSinceBet <= 30) return 1.5; // This month
    return 1.0; // Older
  }

  /// Extract team name from prediction based on outcome
  String? _getTeamName(Prediction pred) {
    switch (pred.outcome) {
      case PredictionOutcome.home:
        return pred.homeTeam;
      case PredictionOutcome.away:
        return pred.awayTeam;
      case PredictionOutcome.over:
      case PredictionOutcome.under:
      case PredictionOutcome.draw:
        return null; // Not team-specific
    }
  }

  /// Get suggested bet type based on win rates
  PredictionType? getSuggestedBetType(UserBettingPatterns patterns) {
    if (!patterns.hasSignificantHistory) return null;

    // Find bet type with best implicit success
    // For simplicity, suggest the type they bet on most
    if (patterns.betTypeCount.isEmpty) return null;

    final sorted = patterns.betTypeCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.first.key;
  }

  /// Check if a team is a favorite
  bool isTeamFavorite(String teamName, UserBettingPatterns patterns) {
    return patterns.favoriteTeams.contains(teamName);
  }

  /// Get score for how relevant a game is to user preferences
  double getGameRelevanceScore(
    String homeTeam,
    String awayTeam,
    String sportKey,
    UserBettingPatterns patterns,
  ) {
    if (!patterns.hasHistory) return 0;

    double score = 0;

    // Team affinity (strongest signal)
    if (patterns.favoriteTeams.contains(homeTeam)) {
      final idx = patterns.favoriteTeams.indexOf(homeTeam);
      score += (5 - idx) * 2; // Top team gets 10 points, 5th gets 2
    }
    if (patterns.favoriteTeams.contains(awayTeam)) {
      final idx = patterns.favoriteTeams.indexOf(awayTeam);
      score += (5 - idx) * 2;
    }

    // Sport preference
    if (patterns.favoriteSports.contains(sportKey)) {
      final idx = patterns.favoriteSports.indexOf(sportKey);
      score += (3 - idx) * 1.5; // Top sport gets 4.5 points
    }

    // Win rate bonus
    final sportWinRate = patterns.winRateBySport[sportKey] ?? 0;
    if (sportWinRate > 0.5) {
      score += sportWinRate * 3; // Up to 3 bonus points for winning sport
    }

    return score;
  }
}
