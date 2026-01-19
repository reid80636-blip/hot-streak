/// Model representing game scores from The Odds API /scores endpoint
class GameScore {
  final String id;
  final String sportKey;
  final String sportTitle;
  final String homeTeam;
  final String awayTeam;
  final DateTime commenceTime;
  final bool completed;
  final int? homeScore;
  final int? awayScore;
  final DateTime? lastUpdate;

  GameScore({
    required this.id,
    required this.sportKey,
    required this.sportTitle,
    required this.homeTeam,
    required this.awayTeam,
    required this.commenceTime,
    required this.completed,
    this.homeScore,
    this.awayScore,
    this.lastUpdate,
  });

  /// Whether the game ended in a draw
  bool get isDraw =>
      completed && homeScore != null && awayScore != null && homeScore == awayScore;

  /// The winning team name, or 'draw' for ties, or null if not completed
  String? get winner {
    if (!completed || homeScore == null || awayScore == null) return null;
    if (homeScore! > awayScore!) return homeTeam;
    if (awayScore! > homeScore!) return awayTeam;
    return 'draw';
  }

  /// Total combined score of both teams
  int get totalScore => (homeScore ?? 0) + (awayScore ?? 0);

  /// Whether scores are available
  bool get hasScores => homeScore != null && awayScore != null;

  /// Parse from The Odds API /scores response
  factory GameScore.fromOddsApi(Map<String, dynamic> json) {
    // Parse scores array
    int? homeScore;
    int? awayScore;
    final scores = json['scores'] as List<dynamic>?;

    if (scores != null) {
      for (final score in scores) {
        final name = score['name'] as String;
        final scoreStr = score['score'] as String?;
        final scoreValue = scoreStr != null ? int.tryParse(scoreStr) : null;

        if (name == json['home_team']) {
          homeScore = scoreValue;
        } else if (name == json['away_team']) {
          awayScore = scoreValue;
        }
      }
    }

    return GameScore(
      id: json['id'] as String,
      sportKey: json['sport_key'] as String,
      sportTitle: json['sport_title'] as String? ?? '',
      homeTeam: json['home_team'] as String,
      awayTeam: json['away_team'] as String,
      commenceTime: DateTime.parse(json['commence_time'] as String),
      completed: json['completed'] as bool? ?? false,
      homeScore: homeScore,
      awayScore: awayScore,
      lastUpdate: json['last_update'] != null
          ? DateTime.tryParse(json['last_update'] as String)
          : null,
    );
  }

  @override
  String toString() {
    return 'GameScore($awayTeam ${awayScore ?? '-'} @ $homeTeam ${homeScore ?? '-'}, completed: $completed)';
  }
}

/// Result of evaluating a single prediction
enum SettlementResult {
  won,
  lost,
  push,
  cancelled,
  pending,
}

/// Summary of a settlement run
class SettlementSummary {
  int settledCount = 0;
  int wins = 0;
  int losses = 0;
  int pushes = 0;
  int parlaysWon = 0;
  int parlaysLost = 0;
  int parlaysPushed = 0;
  int totalWinnings = 0;
  String? skipReason;

  SettlementSummary();

  SettlementSummary.skipped(this.skipReason);

  bool get wasSkipped => skipReason != null;

  @override
  String toString() {
    if (wasSkipped) return 'SettlementSummary(skipped: $skipReason)';
    return 'SettlementSummary(settled: $settledCount, wins: $wins, losses: $losses, winnings: $totalWinnings)';
  }
}

/// Result of evaluating a parlay
class ParlaySettlementResult {
  final String parlayId;
  final Map<String, SettlementResult> legResults;
  final SettlementResult overallResult;
  final int payout;
  final bool allLegsSettled;

  ParlaySettlementResult({
    required this.parlayId,
    required this.legResults,
    required this.overallResult,
    required this.payout,
    required this.allLegsSettled,
  });

  bool get hasAnyLoss => legResults.values.any((r) => r == SettlementResult.lost);
  bool get allWon => legResults.values.every((r) => r == SettlementResult.won);
  bool get allPush => legResults.values.every((r) => r == SettlementResult.push);
}
