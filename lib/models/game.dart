import 'dart:convert';

enum GameStatus {
  upcoming,
  live,
  finished,
}

class Team {
  final String name;
  final String? logoUrl;
  final int? score;

  const Team({
    required this.name,
    this.logoUrl,
    this.score,
  });

  Team copyWith({
    String? name,
    String? logoUrl,
    int? score,
  }) {
    return Team(
      name: name ?? this.name,
      logoUrl: logoUrl ?? this.logoUrl,
      score: score ?? this.score,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'logoUrl': logoUrl,
      'score': score,
    };
  }

  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      name: json['name'] as String,
      logoUrl: json['logoUrl'] as String?,
      score: json['score'] as int?,
    );
  }
}

class Odds {
  final double home;
  final double away;
  final double? draw;
  final double? homeSpread;
  final double? awaySpread;
  final double? spreadLine;
  final double? overOdds;
  final double? underOdds;
  final double? totalLine;

  const Odds({
    required this.home,
    required this.away,
    this.draw,
    this.homeSpread,
    this.awaySpread,
    this.spreadLine,
    this.overOdds,
    this.underOdds,
    this.totalLine,
  });

  Map<String, dynamic> toJson() {
    return {
      'home': home,
      'away': away,
      'draw': draw,
      'homeSpread': homeSpread,
      'awaySpread': awaySpread,
      'spreadLine': spreadLine,
      'overOdds': overOdds,
      'underOdds': underOdds,
      'totalLine': totalLine,
    };
  }

  factory Odds.fromJson(Map<String, dynamic> json) {
    return Odds(
      home: (json['home'] as num).toDouble(),
      away: (json['away'] as num).toDouble(),
      draw: (json['draw'] as num?)?.toDouble(),
      homeSpread: (json['homeSpread'] as num?)?.toDouble(),
      awaySpread: (json['awaySpread'] as num?)?.toDouble(),
      spreadLine: (json['spreadLine'] as num?)?.toDouble(),
      overOdds: (json['overOdds'] as num?)?.toDouble(),
      underOdds: (json['underOdds'] as num?)?.toDouble(),
      totalLine: (json['totalLine'] as num?)?.toDouble(),
    );
  }
}

class Game {
  final String id;
  final String sportKey;
  final Team homeTeam;
  final Team awayTeam;
  final DateTime startTime;
  final GameStatus status;
  final Odds? odds;
  final String? venue;
  final String? league;
  final String? gameTime; // Live game time display (e.g., "Q3 5:42", "45'", "Final")

  const Game({
    required this.id,
    required this.sportKey,
    required this.homeTeam,
    required this.awayTeam,
    required this.startTime,
    this.status = GameStatus.upcoming,
    this.odds,
    this.venue,
    this.league,
    this.gameTime,
  });

  bool get isLive => status == GameStatus.live;
  bool get isFinished => status == GameStatus.finished;
  bool get isUpcoming => status == GameStatus.upcoming;

  bool get isSoccer => sportKey.startsWith('soccer');

  String get displayTime {
    final now = DateTime.now();
    final diff = startTime.difference(now);

    if (status == GameStatus.live) return 'LIVE';
    if (status == GameStatus.finished) return 'FINAL';

    if (diff.inDays > 0) {
      return '${diff.inDays}d';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m';
    } else {
      return 'Soon';
    }
  }

  Game copyWith({
    String? id,
    String? sportKey,
    Team? homeTeam,
    Team? awayTeam,
    DateTime? startTime,
    GameStatus? status,
    Odds? odds,
    String? venue,
    String? league,
    String? gameTime,
  }) {
    return Game(
      id: id ?? this.id,
      sportKey: sportKey ?? this.sportKey,
      homeTeam: homeTeam ?? this.homeTeam,
      awayTeam: awayTeam ?? this.awayTeam,
      startTime: startTime ?? this.startTime,
      status: status ?? this.status,
      odds: odds ?? this.odds,
      venue: venue ?? this.venue,
      league: league ?? this.league,
      gameTime: gameTime ?? this.gameTime,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sportKey': sportKey,
      'homeTeam': homeTeam.toJson(),
      'awayTeam': awayTeam.toJson(),
      'startTime': startTime.toIso8601String(),
      'status': status.name,
      'odds': odds?.toJson(),
      'venue': venue,
      'league': league,
      'gameTime': gameTime,
    };
  }

  factory Game.fromJson(Map<String, dynamic> json) {
    return Game(
      id: json['id'] as String,
      sportKey: json['sportKey'] as String? ?? json['sport_key'] as String,
      homeTeam: Team.fromJson(json['homeTeam'] as Map<String, dynamic>),
      awayTeam: Team.fromJson(json['awayTeam'] as Map<String, dynamic>),
      startTime: DateTime.parse(json['startTime'] as String? ?? json['commence_time'] as String),
      status: GameStatus.values.firstWhere(
        (s) => s.name == (json['status'] as String? ?? 'upcoming'),
        orElse: () => GameStatus.upcoming,
      ),
      odds: json['odds'] != null
          ? Odds.fromJson(json['odds'] as Map<String, dynamic>)
          : null,
      venue: json['venue'] as String?,
      league: json['league'] as String?,
      gameTime: json['gameTime'] as String?,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory Game.fromJsonString(String source) =>
      Game.fromJson(jsonDecode(source) as Map<String, dynamic>);

  // Factory for parsing The Odds API response
  factory Game.fromOddsApi(Map<String, dynamic> json) {
    final bookmakers = json['bookmakers'] as List<dynamic>? ?? [];
    Odds? odds;

    if (bookmakers.isNotEmpty) {
      final bookmaker = bookmakers.first as Map<String, dynamic>;
      final markets = bookmaker['markets'] as List<dynamic>? ?? [];

      double? homeOdds;
      double? awayOdds;
      double? drawOdds;
      double? homeSpread;
      double? awaySpread;
      double? spreadLine;
      double? overOdds;
      double? underOdds;
      double? totalLine;

      for (final market in markets) {
        final marketMap = market as Map<String, dynamic>;
        final key = marketMap['key'] as String;
        final outcomes = marketMap['outcomes'] as List<dynamic>? ?? [];

        if (key == 'h2h') {
          for (final outcome in outcomes) {
            final outcomeMap = outcome as Map<String, dynamic>;
            final name = outcomeMap['name'] as String;
            final price = (outcomeMap['price'] as num).toDouble();

            if (name == json['home_team']) {
              homeOdds = price;
            } else if (name == json['away_team']) {
              awayOdds = price;
            } else if (name == 'Draw') {
              drawOdds = price;
            }
          }
        } else if (key == 'spreads') {
          for (final outcome in outcomes) {
            final outcomeMap = outcome as Map<String, dynamic>;
            final name = outcomeMap['name'] as String;
            final price = (outcomeMap['price'] as num).toDouble();
            final point = (outcomeMap['point'] as num?)?.toDouble();

            if (name == json['home_team']) {
              homeSpread = price;
              spreadLine = point;
            } else if (name == json['away_team']) {
              awaySpread = price;
            }
          }
        } else if (key == 'totals') {
          for (final outcome in outcomes) {
            final outcomeMap = outcome as Map<String, dynamic>;
            final name = outcomeMap['name'] as String;
            final price = (outcomeMap['price'] as num).toDouble();
            final point = (outcomeMap['point'] as num?)?.toDouble();

            if (name == 'Over') {
              overOdds = price;
              totalLine = point;
            } else if (name == 'Under') {
              underOdds = price;
            }
          }
        }
      }

      if (homeOdds != null && awayOdds != null) {
        odds = Odds(
          home: homeOdds,
          away: awayOdds,
          draw: drawOdds,
          homeSpread: homeSpread,
          awaySpread: awaySpread,
          spreadLine: spreadLine,
          overOdds: overOdds,
          underOdds: underOdds,
          totalLine: totalLine,
        );
      }
    }

    return Game(
      id: json['id'] as String,
      sportKey: json['sport_key'] as String,
      homeTeam: Team(name: json['home_team'] as String),
      awayTeam: Team(name: json['away_team'] as String),
      startTime: DateTime.parse(json['commence_time'] as String),
      status: GameStatus.upcoming,
      odds: odds,
    );
  }
}
