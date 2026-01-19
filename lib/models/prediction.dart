import 'dart:convert';

enum PredictionType {
  moneyline,
  spread,
  total,
  playerProp,
}

enum PredictionStatus {
  pending,
  won,
  lost,
  push,
  cancelled,
}

enum PredictionOutcome {
  home,
  away,
  draw,
  over,
  under,
}

class Prediction {
  final String id;
  final String gameId;
  final String sportKey;
  final String homeTeam;
  final String awayTeam;
  final PredictionType type;
  final PredictionOutcome outcome;
  final double odds;
  final int stake;
  final double? line; // For spreads and totals
  final PredictionStatus status;
  final DateTime createdAt;
  final DateTime gameStartTime;
  final int? payout;
  final String? parlayId; // Groups multiple predictions as a parlay
  final int? parlayLegs; // Number of legs in parlay
  final int? finalHomeScore; // Final score when game is settled
  final int? finalAwayScore; // Final score when game is settled

  Prediction({
    required this.id,
    required this.gameId,
    required this.sportKey,
    required this.homeTeam,
    required this.awayTeam,
    required this.type,
    required this.outcome,
    required this.odds,
    required this.stake,
    this.line,
    this.status = PredictionStatus.pending,
    DateTime? createdAt,
    required this.gameStartTime,
    this.payout,
    this.parlayId,
    this.parlayLegs,
    this.finalHomeScore,
    this.finalAwayScore,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isParlay => parlayId != null;

  int get potentialPayout {
    if (odds >= 2.0) {
      return (stake * odds).round();
    } else {
      return (stake * odds).round();
    }
  }

  String get outcomeDisplay {
    switch (type) {
      case PredictionType.moneyline:
        return outcome == PredictionOutcome.home
            ? homeTeam
            : outcome == PredictionOutcome.away
                ? awayTeam
                : 'Draw';
      case PredictionType.spread:
        final lineStr = line != null
            ? (line! > 0 ? '+${line!.toStringAsFixed(1)}' : line!.toStringAsFixed(1))
            : '';
        return outcome == PredictionOutcome.home
            ? '$homeTeam $lineStr'
            : '$awayTeam $lineStr';
      case PredictionType.total:
        return outcome == PredictionOutcome.over
            ? 'Over ${line?.toStringAsFixed(1) ?? ''}'
            : 'Under ${line?.toStringAsFixed(1) ?? ''}';
      case PredictionType.playerProp:
        return outcome.name;
    }
  }

  String get typeDisplay {
    switch (type) {
      case PredictionType.moneyline:
        return 'Moneyline';
      case PredictionType.spread:
        return 'Spread';
      case PredictionType.total:
        return 'Total';
      case PredictionType.playerProp:
        return 'Player Prop';
    }
  }

  String get oddsDisplay {
    return 'x${odds.toStringAsFixed(2)}';
  }

  bool get isPending => status == PredictionStatus.pending;
  bool get isWon => status == PredictionStatus.won;
  bool get isLost => status == PredictionStatus.lost;
  bool get isSettled =>
      status == PredictionStatus.won ||
      status == PredictionStatus.lost ||
      status == PredictionStatus.push;

  bool get hasScores => finalHomeScore != null && finalAwayScore != null;

  String get scoreDisplay {
    if (!hasScores) return '';
    return '$finalAwayScore - $finalHomeScore';
  }

  String get fullScoreDisplay {
    if (!hasScores) return '';
    return '$awayTeam $finalAwayScore - $finalHomeScore $homeTeam';
  }

  Prediction copyWith({
    String? id,
    String? gameId,
    String? sportKey,
    String? homeTeam,
    String? awayTeam,
    PredictionType? type,
    PredictionOutcome? outcome,
    double? odds,
    int? stake,
    double? line,
    PredictionStatus? status,
    DateTime? createdAt,
    DateTime? gameStartTime,
    int? payout,
    String? parlayId,
    int? parlayLegs,
    int? finalHomeScore,
    int? finalAwayScore,
  }) {
    return Prediction(
      id: id ?? this.id,
      gameId: gameId ?? this.gameId,
      sportKey: sportKey ?? this.sportKey,
      homeTeam: homeTeam ?? this.homeTeam,
      awayTeam: awayTeam ?? this.awayTeam,
      type: type ?? this.type,
      outcome: outcome ?? this.outcome,
      odds: odds ?? this.odds,
      stake: stake ?? this.stake,
      line: line ?? this.line,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      gameStartTime: gameStartTime ?? this.gameStartTime,
      payout: payout ?? this.payout,
      parlayId: parlayId ?? this.parlayId,
      parlayLegs: parlayLegs ?? this.parlayLegs,
      finalHomeScore: finalHomeScore ?? this.finalHomeScore,
      finalAwayScore: finalAwayScore ?? this.finalAwayScore,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'gameId': gameId,
      'sportKey': sportKey,
      'homeTeam': homeTeam,
      'awayTeam': awayTeam,
      'type': type.name,
      'outcome': outcome.name,
      'odds': odds,
      'stake': stake,
      'line': line,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'gameStartTime': gameStartTime.toIso8601String(),
      'payout': payout,
      'parlayId': parlayId,
      'parlayLegs': parlayLegs,
      'finalHomeScore': finalHomeScore,
      'finalAwayScore': finalAwayScore,
    };
  }

  factory Prediction.fromJson(Map<String, dynamic> json) {
    return Prediction(
      id: json['id'] as String,
      gameId: json['gameId'] as String,
      sportKey: json['sportKey'] as String,
      homeTeam: json['homeTeam'] as String,
      awayTeam: json['awayTeam'] as String,
      type: PredictionType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => PredictionType.moneyline,
      ),
      outcome: PredictionOutcome.values.firstWhere(
        (o) => o.name == json['outcome'],
        orElse: () => PredictionOutcome.home,
      ),
      odds: (json['odds'] as num).toDouble(),
      stake: json['stake'] as int,
      line: (json['line'] as num?)?.toDouble(),
      status: PredictionStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => PredictionStatus.pending,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      gameStartTime: DateTime.parse(json['gameStartTime'] as String),
      payout: json['payout'] as int?,
      parlayId: json['parlayId'] as String?,
      parlayLegs: json['parlayLegs'] as int?,
      finalHomeScore: json['finalHomeScore'] as int?,
      finalAwayScore: json['finalAwayScore'] as int?,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory Prediction.fromJsonString(String source) =>
      Prediction.fromJson(jsonDecode(source) as Map<String, dynamic>);

  factory Prediction.fromSupabase(Map<String, dynamic> json) {
    return Prediction(
      id: json['id'] as String,
      gameId: json['game_id'] as String,
      sportKey: json['sport_key'] as String,
      homeTeam: json['home_team'] as String,
      awayTeam: json['away_team'] as String,
      type: PredictionType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => PredictionType.moneyline,
      ),
      outcome: PredictionOutcome.values.firstWhere(
        (o) => o.name == json['outcome'],
        orElse: () => PredictionOutcome.home,
      ),
      odds: (json['odds'] as num).toDouble(),
      stake: json['stake'] as int,
      line: (json['line'] as num?)?.toDouble(),
      status: PredictionStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => PredictionStatus.pending,
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
      gameStartTime: DateTime.parse(json['game_start_time'] as String),
      payout: json['payout'] as int?,
      parlayId: json['parlay_id'] as String?,
      parlayLegs: json['parlay_legs'] as int?,
      finalHomeScore: json['final_home_score'] as int?,
      finalAwayScore: json['final_away_score'] as int?,
    );
  }
}

class BetSlipItem {
  final String gameId;
  final String sportKey;
  final String homeTeam;
  final String awayTeam;
  final PredictionType type;
  final PredictionOutcome outcome;
  final double odds;
  final double? line;
  final DateTime gameStartTime;
  int stake;

  BetSlipItem({
    required this.gameId,
    required this.sportKey,
    required this.homeTeam,
    required this.awayTeam,
    required this.type,
    required this.outcome,
    required this.odds,
    this.line,
    required this.gameStartTime,
    this.stake = 100,
  });

  int get potentialPayout => (stake * odds).round();

  String get outcomeDisplay {
    switch (type) {
      case PredictionType.moneyline:
        return outcome == PredictionOutcome.home
            ? homeTeam
            : outcome == PredictionOutcome.away
                ? awayTeam
                : 'Draw';
      case PredictionType.spread:
        final lineStr = line != null
            ? (line! > 0 ? '+${line!.toStringAsFixed(1)}' : line!.toStringAsFixed(1))
            : '';
        return outcome == PredictionOutcome.home
            ? '$homeTeam $lineStr'
            : '$awayTeam $lineStr';
      case PredictionType.total:
        return outcome == PredictionOutcome.over
            ? 'Over ${line?.toStringAsFixed(1) ?? ''}'
            : 'Under ${line?.toStringAsFixed(1) ?? ''}';
      case PredictionType.playerProp:
        return outcome.name;
    }
  }

  String get matchDisplay => '$awayTeam @ $homeTeam';
}
