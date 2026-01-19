import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/game_score.dart';

/// Service for fetching live scores from ESPN's public API
/// No API key required - uses ESPN's hidden public endpoints
class EspnScoresService {
  static const String _baseUrl = 'https://site.api.espn.com/apis/site/v2/sports';

  /// ESPN sport paths mapped from our sport keys
  static const Map<String, String> _sportPaths = {
    // NFL
    'americanfootball_nfl': 'football/nfl',
    // NBA
    'basketball_nba': 'basketball/nba',
    // College Football
    'americanfootball_ncaaf': 'football/college-football',
    // College Basketball
    'basketball_ncaab': 'basketball/mens-college-basketball',
    // MLB
    'baseball_mlb': 'baseball/mlb',
    // NHL
    'icehockey_nhl': 'hockey/nhl',
    // MLS
    'soccer_usa_mls': 'soccer/usa.1',
    // Premier League
    'soccer_epl': 'soccer/eng.1',
    // La Liga
    'soccer_spain_la_liga': 'soccer/esp.1',
    // Serie A
    'soccer_italy_serie_a': 'soccer/ita.1',
    // Bundesliga
    'soccer_germany_bundesliga': 'soccer/ger.1',
    // Ligue 1
    'soccer_france_ligue_one': 'soccer/fra.1',
    // Champions League
    'soccer_uefa_champs_league': 'soccer/uefa.champions',
  };

  /// Fetch scores for multiple sports
  Future<Map<String, List<GameScore>>> fetchScoresForSports(
    Set<String> sportKeys,
  ) async {
    final results = <String, List<GameScore>>{};

    for (final sportKey in sportKeys) {
      try {
        final scores = await fetchScoresForSport(sportKey);
        results[sportKey] = scores;
      } catch (e) {
        debugPrint('ESPN: Failed to fetch scores for $sportKey: $e');
        results[sportKey] = [];
      }
    }

    return results;
  }

  /// Fetch scores for a single sport from ESPN
  Future<List<GameScore>> fetchScoresForSport(String sportKey) async {
    final sportPath = _sportPaths[sportKey];
    if (sportPath == null) {
      debugPrint('ESPN: Unknown sport key: $sportKey');
      return [];
    }

    // Get today's and yesterday's games
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));

    final scores = <GameScore>[];

    // Fetch today's games
    scores.addAll(await _fetchScoreboardForDate(sportKey, sportPath, today));

    // Fetch yesterday's games (for recently completed)
    scores.addAll(await _fetchScoreboardForDate(sportKey, sportPath, yesterday));

    return scores;
  }

  /// Fetch scoreboard for a specific date
  Future<List<GameScore>> _fetchScoreboardForDate(
    String sportKey,
    String sportPath,
    DateTime date,
  ) async {
    final dateStr = '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
    final url = Uri.parse('$_baseUrl/$sportPath/scoreboard?dates=$dateStr');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final events = data['events'] as List<dynamic>? ?? [];

        return events.map((event) => _parseEvent(event, sportKey)).toList();
      } else {
        debugPrint('ESPN API error: ${response.statusCode} for $sportPath');
        return [];
      }
    } catch (e) {
      debugPrint('ESPN network error for $sportPath: $e');
      return [];
    }
  }

  /// Parse an ESPN event into our GameScore model
  GameScore _parseEvent(Map<String, dynamic> event, String sportKey) {
    final id = event['id'] as String;
    final date = DateTime.parse(event['date'] as String);

    // Get status info
    final status = event['status'] as Map<String, dynamic>?;
    final statusType = status?['type'] as Map<String, dynamic>?;
    final statusName = statusType?['name'] as String? ?? '';
    final completed = statusType?['completed'] as bool? ?? false;

    // Get competitors (teams and scores)
    final competitions = event['competitions'] as List<dynamic>? ?? [];
    final competition = (competitions.isNotEmpty && competitions[0] != null)
        ? competitions[0] as Map<String, dynamic>
        : null;
    final competitors = competition?['competitors'] as List<dynamic>? ?? [];

    String homeTeam = '';
    String awayTeam = '';
    int? homeScore;
    int? awayScore;

    for (final competitor in competitors) {
      if (competitor == null) continue;
      final comp = competitor as Map<String, dynamic>;
      final team = comp['team'] as Map<String, dynamic>?;
      final teamName = team?['displayName'] as String? ?? team?['name'] as String? ?? '';
      final scoreStr = comp['score'] as String?;
      final score = scoreStr != null ? int.tryParse(scoreStr) : null;
      final homeAway = comp['homeAway'] as String?;

      if (homeAway == 'home') {
        homeTeam = teamName;
        homeScore = score;
      } else if (homeAway == 'away') {
        awayTeam = teamName;
        awayScore = score;
      }
    }

    return GameScore(
      id: id,
      sportKey: sportKey,
      sportTitle: _getSportTitle(sportKey),
      homeTeam: homeTeam,
      awayTeam: awayTeam,
      commenceTime: date,
      completed: completed || statusName == 'STATUS_FINAL',
      homeScore: homeScore,
      awayScore: awayScore,
      lastUpdate: DateTime.now(),
    );
  }

  /// Get sport title from sport key
  String _getSportTitle(String sportKey) {
    final titles = {
      'americanfootball_nfl': 'NFL',
      'basketball_nba': 'NBA',
      'americanfootball_ncaaf': 'NCAAF',
      'basketball_ncaab': 'NCAAB',
      'baseball_mlb': 'MLB',
      'icehockey_nhl': 'NHL',
      'soccer_usa_mls': 'MLS',
      'soccer_epl': 'EPL',
      'soccer_spain_la_liga': 'La Liga',
      'soccer_italy_serie_a': 'Serie A',
      'soccer_germany_bundesliga': 'Bundesliga',
      'soccer_france_ligue_one': 'Ligue 1',
      'soccer_uefa_champs_league': 'Champions League',
    };
    return titles[sportKey] ?? sportKey;
  }

  /// Fetch live/in-progress games only
  Future<List<GameScore>> fetchLiveGames() async {
    final allScores = <GameScore>[];

    // Fetch from all supported sports
    for (final entry in _sportPaths.entries) {
      try {
        final sportPath = entry.value;
        final url = Uri.parse('$_baseUrl/$sportPath/scoreboard');

        final response = await http.get(url);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final events = data['events'] as List<dynamic>? ?? [];

          for (final event in events) {
            final status = event['status'] as Map<String, dynamic>?;
            final statusType = status?['type'] as Map<String, dynamic>?;
            final statusName = statusType?['name'] as String? ?? '';

            // Only include in-progress games
            if (statusName == 'STATUS_IN_PROGRESS') {
              allScores.add(_parseEvent(event, entry.key));
            }
          }
        }
      } catch (e) {
        debugPrint('ESPN: Error fetching live games for ${entry.key}: $e');
      }
    }

    return allScores;
  }

  /// Get game details by event ID
  Future<GameScore?> fetchGameById(String eventId, String sportKey) async {
    final sportPath = _sportPaths[sportKey];
    if (sportPath == null) return null;

    final url = Uri.parse('$_baseUrl/$sportPath/summary?event=$eventId');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Parse from summary format
        final header = data['header'] as Map<String, dynamic>?;
        final competitions = header?['competitions'] as List<dynamic>?;
        if (competitions != null && competitions.isNotEmpty) {
          final competition = competitions[0] as Map<String, dynamic>;

          // Reconstruct event format for parsing
          return _parseEvent({
            'id': eventId,
            'date': competition['date'],
            'status': competition['status'],
            'competitions': [competition],
          }, sportKey);
        }
      }
    } catch (e) {
      debugPrint('ESPN: Error fetching game $eventId: $e');
    }

    return null;
  }

  /// Check if ESPN supports a sport
  bool supportsSport(String sportKey) => _sportPaths.containsKey(sportKey);

  /// Get all supported sport keys
  List<String> get supportedSports => _sportPaths.keys.toList();

  /// Fetch detailed game stats including player statistics
  Future<GameDetails?> fetchGameDetails(String eventId, String sportKey) async {
    final sportPath = _sportPaths[sportKey];
    if (sportPath == null) return null;

    // Strip 'espn_' prefix if present
    final cleanEventId = eventId.replaceFirst('espn_', '');
    debugPrint('ESPN: Fetching game details for $cleanEventId (original: $eventId)');

    final url = Uri.parse('$_baseUrl/$sportPath/summary?event=$cleanEventId');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final details = _parseGameDetails(data, sportKey, cleanEventId);

        // Also fetch live odds from core API
        final odds = await _fetchOddsForEvent(sportKey, cleanEventId);
        if (odds.isNotEmpty) {
          debugPrint('ESPN: Got live odds for $cleanEventId: spread=${odds['spread']}, total=${odds['total']}');
          return GameDetails(
            eventId: details.eventId,
            sportKey: details.sportKey,
            homeTeam: details.homeTeam,
            awayTeam: details.awayTeam,
            homeStats: details.homeStats,
            awayStats: details.awayStats,
            homePlayers: details.homePlayers,
            awayPlayers: details.awayPlayers,
            scoringPlays: details.scoringPlays,
            leaders: details.leaders,
            venue: details.venue,
            attendance: details.attendance,
            spreadLine: odds['spread'],
            totalLine: odds['total'],
            homeMoneyline: odds['homeMoneyline'],
            awayMoneyline: odds['awayMoneyline'],
            homeSpreadOdds: odds['homeSpreadOdds'],
            awaySpreadOdds: odds['awaySpreadOdds'],
            overOdds: odds['overOdds'],
            underOdds: odds['underOdds'],
          );
        }

        return details;
      }
    } catch (e) {
      debugPrint('ESPN: Error fetching game details $eventId: $e');
    }

    return null;
  }

  /// Parse game details from ESPN summary endpoint
  GameDetails _parseGameDetails(Map<String, dynamic> data, String sportKey, String eventId) {
    // Parse header info
    final header = data['header'] as Map<String, dynamic>?;
    final competitions = header?['competitions'] as List<dynamic>? ?? [];
    final competition = competitions.isNotEmpty ? competitions[0] as Map<String, dynamic> : null;

    // Get team info
    final competitors = competition?['competitors'] as List<dynamic>? ?? [];
    TeamStats? homeTeam;
    TeamStats? awayTeam;

    for (final comp in competitors) {
      final teamData = comp as Map<String, dynamic>;
      final team = teamData['team'] as Map<String, dynamic>?;
      final isHome = teamData['homeAway'] == 'home';

      final teamStats = TeamStats(
        id: team?['id'] as String? ?? '',
        name: team?['displayName'] as String? ?? '',
        abbreviation: team?['abbreviation'] as String? ?? '',
        logo: team?['logo'] as String?,
        score: int.tryParse(teamData['score'] as String? ?? ''),
        record: _parseRecord(teamData['record'] as List<dynamic>?),
        color: team?['color'] as String?,
      );

      if (isHome) {
        homeTeam = teamStats;
      } else {
        awayTeam = teamStats;
      }
    }

    // Parse boxscore/team statistics
    final boxscore = data['boxscore'] as Map<String, dynamic>?;
    final teamStatsData = boxscore?['teams'] as List<dynamic>? ?? [];
    List<StatCategory> homeStats = [];
    List<StatCategory> awayStats = [];

    for (final teamStat in teamStatsData) {
      final ts = teamStat as Map<String, dynamic>;
      final team = ts['team'] as Map<String, dynamic>?;
      final isHome = team?['id'] == homeTeam?.id;
      final statistics = ts['statistics'] as List<dynamic>? ?? [];

      final stats = statistics.map((s) {
        final stat = s as Map<String, dynamic>;
        return StatCategory(
          name: stat['name'] as String? ?? '',
          displayName: stat['displayValue'] as String? ?? '',
          value: stat['displayValue'] as String? ?? '',
        );
      }).toList();

      if (isHome) {
        homeStats = stats;
      } else {
        awayStats = stats;
      }
    }

    // Parse player statistics
    final players = boxscore?['players'] as List<dynamic>? ?? [];
    List<PlayerStats> homePlayers = [];
    List<PlayerStats> awayPlayers = [];

    for (final playerSection in players) {
      final ps = playerSection as Map<String, dynamic>;
      final team = ps['team'] as Map<String, dynamic>?;
      final isHome = team?['id'] == homeTeam?.id;
      final statistics = ps['statistics'] as List<dynamic>? ?? [];

      final playerList = <PlayerStats>[];

      for (final statCategory in statistics) {
        final sc = statCategory as Map<String, dynamic>;
        final categoryName = sc['name'] as String? ?? '';
        final labels = (sc['labels'] as List<dynamic>?)?.cast<String>() ?? [];
        final athletes = sc['athletes'] as List<dynamic>? ?? [];

        for (final athlete in athletes) {
          final a = athlete as Map<String, dynamic>;
          final athleteInfo = a['athlete'] as Map<String, dynamic>?;
          final stats = (a['stats'] as List<dynamic>?)?.cast<String>() ?? [];

          // Create stat map from labels and values
          final statMap = <String, String>{};
          for (var i = 0; i < labels.length && i < stats.length; i++) {
            statMap[labels[i]] = stats[i];
          }

          playerList.add(PlayerStats(
            id: athleteInfo?['id'] as String? ?? '',
            name: athleteInfo?['displayName'] as String? ?? '',
            shortName: athleteInfo?['shortName'] as String? ?? '',
            position: athleteInfo?['position']?['abbreviation'] as String? ?? '',
            jersey: athleteInfo?['jersey'] as String? ?? '',
            headshot: athleteInfo?['headshot']?['href'] as String?,
            category: categoryName,
            stats: statMap,
          ));
        }
      }

      if (isHome) {
        homePlayers = playerList;
      } else {
        awayPlayers = playerList;
      }
    }

    // Parse game info
    final gameInfo = data['gameInfo'] as Map<String, dynamic>?;
    final venue = gameInfo?['venue'] as Map<String, dynamic>?;

    // Parse scoring plays/key events
    List<ScoringPlay> plays = [];

    debugPrint('ESPN DEBUG: Parsing plays for event $eventId');
    debugPrint('ESPN DEBUG: homeTeam id=${homeTeam?.id}, abbr=${homeTeam?.abbreviation}');
    debugPrint('ESPN DEBUG: awayTeam id=${awayTeam?.id}, abbr=${awayTeam?.abbreviation}');

    // Try the 'plays' array first (NBA, most sports) - filter for scoring plays
    final allPlays = data['plays'] as List<dynamic>? ?? [];
    debugPrint('ESPN DEBUG: Total plays in data: ${allPlays.length}');

    if (allPlays.isNotEmpty) {
      int scoringCount = 0;
      for (final p in allPlays) {
        final play = p as Map<String, dynamic>;
        final isScoringPlay = play['scoringPlay'] as bool? ?? false;
        if (isScoringPlay) {
          scoringCount++;
          final teamId = play['team']?['id'] as String?;
          // Find team info from header
          String? teamAbbr;
          String? teamLogo;
          if (teamId == homeTeam?.id) {
            teamAbbr = homeTeam?.abbreviation;
            teamLogo = homeTeam?.logo;
          } else if (teamId == awayTeam?.id) {
            teamAbbr = awayTeam?.abbreviation;
            teamLogo = awayTeam?.logo;
          }

          plays.add(ScoringPlay(
            description: play['text'] as String? ?? '',
            teamLogo: teamLogo,
            teamAbbr: teamAbbr,
            period: play['period']?['number'] as int? ?? 0,
            clock: play['clock']?['displayValue'] as String? ?? '',
            homeScore: play['homeScore'] as int? ?? 0,
            awayScore: play['awayScore'] as int? ?? 0,
          ));
        }
      }
      debugPrint('ESPN DEBUG: Found $scoringCount scoring plays');
    }

    // Fallback: Try scoringPlays (some sports)
    if (plays.isEmpty) {
      final scoringPlays = data['scoringPlays'] as List<dynamic>? ?? [];
      if (scoringPlays.isNotEmpty) {
        plays = scoringPlays.map((p) {
          final play = p as Map<String, dynamic>;
          final team = play['team'] as Map<String, dynamic>?;
          return ScoringPlay(
            description: play['text'] as String? ?? '',
            teamLogo: team?['logo'] as String?,
            teamAbbr: team?['abbreviation'] as String?,
            period: play['period']?['number'] as int? ?? 0,
            clock: play['clock']?['displayValue'] as String? ?? '',
            homeScore: play['homeScore'] as int? ?? 0,
            awayScore: play['awayScore'] as int? ?? 0,
          );
        }).toList();
      }
    }

    // For football, also try drives for more play data
    if (plays.isEmpty && sportKey.contains('football')) {
      final drives = data['drives'] as Map<String, dynamic>?;
      final previousDrives = drives?['previous'] as List<dynamic>? ?? [];
      for (final drive in previousDrives) {
        final d = drive as Map<String, dynamic>;
        final team = d['team'] as Map<String, dynamic>?;
        final driveResult = d['result'] as String? ?? '';
        final driveDesc = d['description'] as String? ?? driveResult;

        // Only add scoring drives
        if (driveResult.toLowerCase().contains('touchdown') ||
            driveResult.toLowerCase().contains('field goal')) {
          plays.add(ScoringPlay(
            description: driveDesc,
            teamLogo: team?['logos']?[0]?['href'] as String?,
            teamAbbr: team?['abbreviation'] as String?,
            period: d['start']?['period']?['number'] as int? ?? 0,
            clock: d['start']?['clock']?['displayValue'] as String? ?? '',
            homeScore: d['end']?['homeScore'] as int? ?? 0,
            awayScore: d['end']?['awayScore'] as int? ?? 0,
          ));
        }
      }
    }

    // For soccer, try keyEvents
    if (plays.isEmpty && sportKey.contains('soccer')) {
      final keyEvents = data['keyEvents'] as List<dynamic>? ?? [];
      plays = keyEvents.map((e) {
        final event = e as Map<String, dynamic>;
        final team = event['team'] as Map<String, dynamic>?;
        final clock = event['clock'] as Map<String, dynamic>?;
        return ScoringPlay(
          description: event['text'] as String? ?? event['type']?['text'] as String? ?? '',
          teamLogo: team?['logo'] as String?,
          teamAbbr: team?['abbreviation'] as String?,
          period: event['period']?['number'] as int? ?? ((clock?['value'] as num? ?? 0) > 45 ? 2 : 1),
          clock: clock?['displayValue'] as String? ?? '',
          homeScore: event['homeScore'] as int? ?? 0,
          awayScore: event['awayScore'] as int? ?? 0,
        );
      }).toList();
    }

    debugPrint('ESPN: Parsed ${plays.length} scoring plays for event $eventId');

    // Parse leaders - structure is: leaders[team].leaders[category].leaders[player]
    final leadersData = data['leaders'] as List<dynamic>? ?? [];
    List<GameLeader> gameLeaders = [];

    for (final teamLeaders in leadersData) {
      final tl = teamLeaders as Map<String, dynamic>;
      final team = tl['team'] as Map<String, dynamic>?;
      final teamAbbr = team?['abbreviation'] as String?;
      final teamLogo = team?['logo'] as String?;
      final categories = tl['leaders'] as List<dynamic>? ?? [];

      for (final category in categories) {
        final cat = category as Map<String, dynamic>;
        final categoryName = cat['name'] as String? ?? cat['displayName'] as String? ?? '';
        final categoryLeaders = cat['leaders'] as List<dynamic>? ?? [];

        for (final leader in categoryLeaders) {
          final l = leader as Map<String, dynamic>;
          final athlete = l['athlete'] as Map<String, dynamic>?;

          // Headshot can be a string or a nested object with 'href'
          String? headshotUrl;
          final headshot = athlete?['headshot'];
          if (headshot is String) {
            headshotUrl = headshot;
          } else if (headshot is Map<String, dynamic>) {
            headshotUrl = headshot['href'] as String?;
          }

          gameLeaders.add(GameLeader(
            category: categoryName,
            name: athlete?['displayName'] as String? ?? '',
            value: l['displayValue'] as String? ?? '',
            teamAbbr: teamAbbr,
            headshot: headshotUrl,
          ));
        }
      }
    }

    debugPrint('ESPN: Parsed ${gameLeaders.length} game leaders for event $eventId');

    return GameDetails(
      eventId: eventId,
      sportKey: sportKey,
      homeTeam: homeTeam,
      awayTeam: awayTeam,
      homeStats: homeStats,
      awayStats: awayStats,
      homePlayers: homePlayers,
      awayPlayers: awayPlayers,
      scoringPlays: plays,
      leaders: gameLeaders,
      venue: venue?['fullName'] as String?,
      attendance: gameInfo?['attendance'] as int?,
    );
  }

  String? _parseRecord(List<dynamic>? records) {
    if (records == null || records.isEmpty) return null;
    final record = records[0] as Map<String, dynamic>?;
    return record?['summary'] as String?;
  }

  /// ESPN Core API base URL for odds
  static const String _coreApiUrl = 'https://sports.core.api.espn.com/v2/sports';

  /// Map sport keys to core API paths
  static const Map<String, String> _coreApiPaths = {
    'americanfootball_nfl': 'football/leagues/nfl',
    'basketball_nba': 'basketball/leagues/nba',
    'americanfootball_ncaaf': 'football/leagues/college-football',
    'basketball_ncaab': 'basketball/leagues/mens-college-basketball',
    'baseball_mlb': 'baseball/leagues/mlb',
    'icehockey_nhl': 'hockey/leagues/nhl',
    'soccer_usa_mls': 'soccer/leagues/usa.1',
    'soccer_epl': 'soccer/leagues/eng.1',
    'soccer_spain_la_liga': 'soccer/leagues/esp.1',
    'soccer_italy_serie_a': 'soccer/leagues/ita.1',
    'soccer_germany_bundesliga': 'soccer/leagues/ger.1',
    'soccer_france_ligue_one': 'soccer/leagues/fra.1',
    'soccer_uefa_champs_league': 'soccer/leagues/uefa.champions',
  };

  /// Fetch odds for a specific event from ESPN's core API
  Future<Map<String, double>> _fetchOddsForEvent(String sportKey, String eventId) async {
    final corePath = _coreApiPaths[sportKey];
    if (corePath == null) return {};

    final url = Uri.parse('$_coreApiUrl/$corePath/events/$eventId/competitions/$eventId/odds');

    try {
      final response = await http.get(url).timeout(
        const Duration(seconds: 3),
        onTimeout: () => http.Response('{}', 408),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['items'] as List<dynamic>? ?? [];

        if (items.isEmpty) {
          return {};
        }

        // Get the first provider's odds (usually ESPN BET or DraftKings)
        final odds = items[0] as Map<String, dynamic>;
        debugPrint('ESPN Odds Raw: $odds');

        final result = <String, double>{};

        // Parse spread - try multiple field names
        final spread = odds['spread'] ?? odds['pointSpread'] ?? odds['details'];
        if (spread != null) {
          if (spread is num) {
            result['spread'] = spread.toDouble();
          } else if (spread is String) {
            result['spread'] = double.tryParse(spread) ?? 0;
          }
        }

        // Parse total/over-under
        final total = odds['overUnder'] ?? odds['total'] ?? odds['overunder'];
        if (total != null) {
          if (total is num) {
            result['total'] = total.toDouble();
          } else if (total is String) {
            result['total'] = double.tryParse(total) ?? 0;
          }
        }

        // Parse team odds
        final homeOdds = odds['homeTeamOdds'] as Map<String, dynamic>?;
        final awayOdds = odds['awayTeamOdds'] as Map<String, dynamic>?;

        if (homeOdds != null) {
          result['homeMoneyline'] = _parseOddsValue(homeOdds['moneyLine'] ?? homeOdds['odds'] ?? homeOdds['american']);
          result['homeSpreadOdds'] = _parseOddsValue(homeOdds['spreadOdds'] ?? homeOdds['pointSpreadOdds']);
        }

        if (awayOdds != null) {
          result['awayMoneyline'] = _parseOddsValue(awayOdds['moneyLine'] ?? awayOdds['odds'] ?? awayOdds['american']);
          result['awaySpreadOdds'] = _parseOddsValue(awayOdds['spreadOdds'] ?? awayOdds['pointSpreadOdds']);
        }

        // Parse over/under odds
        result['overOdds'] = _parseOddsValue(odds['overOdds']);
        result['underOdds'] = _parseOddsValue(odds['underOdds']);

        debugPrint('ESPN Odds Parsed: $result');
        return result;
      } else {
        debugPrint('ESPN Odds: HTTP ${response.statusCode} for event $eventId');
      }
    } catch (e) {
      debugPrint('ESPN Odds: Error fetching for event $eventId: $e');
    }

    return {};
  }

  double _parseOddsValue(dynamic value) {
    if (value == null) return -110;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? -110;
    return -110;
  }

  double _parseMoneyline(dynamic teamOdds) {
    if (teamOdds == null) return -110;
    if (teamOdds is Map<String, dynamic>) {
      return _parseOddsValue(teamOdds['moneyLine'] ?? teamOdds['odds'] ?? teamOdds['american']);
    }
    return -110;
  }

  double _parseSpreadOdds(dynamic teamOdds) {
    if (teamOdds == null) return -110;
    if (teamOdds is Map<String, dynamic>) {
      return _parseOddsValue(teamOdds['spreadOdds'] ?? teamOdds['pointSpreadOdds']);
    }
    return -110;
  }

  /// Fetch odds for multiple events in parallel (much faster than sequential)
  Future<Map<String, Map<String, double>>> _fetchOddsForEvents(
    String sportKey,
    List<String> eventIds,
  ) async {
    if (eventIds.isEmpty) return {};

    debugPrint('ESPN: Fetching odds for ${eventIds.length} games in parallel...');

    final futures = eventIds.map((id) async {
      final odds = await _fetchOddsForEvent(sportKey, id);
      return MapEntry(id, odds);
    }).toList();

    final results = await Future.wait(futures);
    final oddsMap = Map.fromEntries(results.where((e) => e.value.isNotEmpty));

    debugPrint('ESPN: Got odds for ${oddsMap.length}/${eventIds.length} games');
    return oddsMap;
  }

  /// Apply odds to a game
  EspnGame _applyOddsToGame(EspnGame game, Map<String, double>? odds) {
    if (odds == null || odds.isEmpty) return game;
    return game.copyWithOdds(
      spreadLine: odds['spread'],
      totalLine: odds['total'],
      homeMoneyline: odds['homeMoneyline'],
      awayMoneyline: odds['awayMoneyline'],
      homeSpreadOdds: odds['homeSpreadOdds'],
      awaySpreadOdds: odds['awaySpreadOdds'],
      overOdds: odds['overOdds'],
      underOdds: odds['underOdds'],
    );
  }

  /// Fetch all games for today (scheduled, live, and completed)
  Future<List<EspnGame>> fetchAllGamesForToday(String sportKey) async {
    final sportPath = _sportPaths[sportKey];
    if (sportPath == null) {
      debugPrint('ESPN: Unknown sport key: $sportKey');
      return [];
    }

    final url = Uri.parse('$_baseUrl/$sportPath/scoreboard');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final events = data['events'] as List<dynamic>? ?? [];

        debugPrint('ESPN: Found ${events.length} games for $sportKey');

        // Parse games first
        var games = events.map((event) => _parseEventToGame(event, sportKey)).toList();

        // Fetch odds in PARALLEL for ALL games (not just upcoming)
        final allGameIds = games.map((g) => g.id).toList();
        final allOdds = await _fetchOddsForEvents(sportKey, allGameIds);

        // Apply odds to games
        games = games.map((game) => _applyOddsToGame(game, allOdds[game.id])).toList();

        return games;
      } else {
        debugPrint('ESPN API error: ${response.statusCode} for $sportPath');
        return [];
      }
    } catch (e) {
      debugPrint('ESPN network error for $sportPath: $e');
      return [];
    }
  }

  /// Fetch games from the past week (for live scores screen)
  Future<List<EspnGame>> fetchGamesForPastWeek(String sportKey) async {
    final sportPath = _sportPaths[sportKey];
    if (sportPath == null) {
      debugPrint('ESPN: Unknown sport key: $sportKey');
      return [];
    }

    final allGames = <EspnGame>[];
    final now = DateTime.now();

    // Fetch games for the past 7 days
    for (int i = 0; i < 7; i++) {
      final date = now.subtract(Duration(days: i));
      final games = await fetchGamesForDate(sportKey, date);
      allGames.addAll(games);
    }

    debugPrint('ESPN: Got ${allGames.length} games for $sportKey (past week)');
    return allGames;
  }

  /// Fetch games for a specific date (live/completed only)
  Future<List<EspnGame>> fetchGamesForDate(String sportKey, DateTime date) async {
    final sportPath = _sportPaths[sportKey];
    if (sportPath == null) {
      return [];
    }

    final dateStr = '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
    final url = Uri.parse('$_baseUrl/$sportPath/scoreboard?dates=$dateStr');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final events = data['events'] as List<dynamic>? ?? [];

        var games = events
            .map((event) => _parseEventToGame(event, sportKey))
            .where((game) => game.isLive || game.isCompleted)
            .toList();

        // Fetch odds in parallel for all games
        final gameIds = games.map((g) => g.id).toList();
        final allOdds = await _fetchOddsForEvents(sportKey, gameIds);

        // Apply odds to games
        games = games.map((game) => _applyOddsToGame(game, allOdds[game.id])).toList();

        return games;
      }
    } catch (e) {
      debugPrint('ESPN network error for $sportPath ($dateStr): $e');
    }

    return [];
  }

  /// Fetch upcoming games for a specific date (not started yet)
  Future<List<EspnGame>> fetchUpcomingGamesForDate(String sportKey, DateTime date) async {
    final sportPath = _sportPaths[sportKey];
    if (sportPath == null) {
      return [];
    }

    final dateStr = '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
    final url = Uri.parse('$_baseUrl/$sportPath/scoreboard?dates=$dateStr');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final events = data['events'] as List<dynamic>? ?? [];

        // Parse upcoming (not started) games
        var games = events
            .map((event) => _parseEventToGame(event, sportKey))
            .where((game) => !game.isLive && !game.isCompleted)
            .toList();

        // Fetch odds in parallel for all games
        final gameIds = games.map((g) => g.id).toList();
        final allOdds = await _fetchOddsForEvents(sportKey, gameIds);

        // Apply odds to games
        games = games.map((game) => _applyOddsToGame(game, allOdds[game.id])).toList();

        return games;
      }
    } catch (e) {
      debugPrint('ESPN network error for $sportPath ($dateStr): $e');
    }

    return [];
  }

  /// Fetch upcoming games for the next N days (for more games in certain sports)
  Future<List<EspnGame>> fetchUpcomingGamesForDays(String sportKey, int days) async {
    final allGames = <EspnGame>[];
    final now = DateTime.now();

    for (int i = 0; i <= days; i++) {
      final date = now.add(Duration(days: i));
      final games = await fetchUpcomingGamesForDate(sportKey, date);
      allGames.addAll(games);
    }

    debugPrint('ESPN: Got ${allGames.length} upcoming games for $sportKey (next $days days)');
    return allGames;
  }

  /// Parse ESPN event into EspnGame model
  EspnGame _parseEventToGame(Map<String, dynamic> event, String sportKey) {
    final id = event['id'] as String;
    final name = event['name'] as String? ?? '';
    final shortName = event['shortName'] as String? ?? '';
    final date = DateTime.parse(event['date'] as String);

    // Get status info
    final status = event['status'] as Map<String, dynamic>?;
    final statusType = status?['type'] as Map<String, dynamic>?;
    final statusName = statusType?['name'] as String? ?? '';
    final statusDescription = statusType?['description'] as String? ?? '';
    final completed = statusType?['completed'] as bool? ?? false;
    final displayClock = status?['displayClock'] as String?;
    final period = status?['period'] as int?;

    // Build game time string
    String? gameTime;
    if (statusName == 'STATUS_IN_PROGRESS') {
      if (sportKey.contains('basketball')) {
        gameTime = 'Q$period $displayClock';
      } else if (sportKey.contains('football')) {
        gameTime = 'Q$period $displayClock';
      } else if (sportKey.contains('soccer')) {
        gameTime = "$displayClock'";
      } else {
        gameTime = displayClock;
      }
    } else if (statusName == 'STATUS_FINAL') {
      gameTime = 'Final';
    } else if (statusName == 'STATUS_HALFTIME') {
      gameTime = 'Halftime';
    }

    // Get competitors (teams and scores)
    final competitions = event['competitions'] as List<dynamic>? ?? [];
    final competition = (competitions.isNotEmpty && competitions[0] != null)
        ? competitions[0] as Map<String, dynamic>
        : null;
    final competitors = competition?['competitors'] as List<dynamic>? ?? [];

    // NOTE: Scoreboard odds (competition['odds']) are ALWAYS empty
    // Real odds are fetched via Core API in _fetchOddsForEvents()
    // Odds fields are left null here and populated after parallel fetch

    String homeTeam = '';
    String awayTeam = '';
    String? homeAbbr;
    String? awayAbbr;
    String? homeLogo;
    String? awayLogo;
    int? homeScore;
    int? awayScore;
    String? homeRecord;
    String? awayRecord;

    for (final competitor in competitors) {
      if (competitor == null) continue;
      final comp = competitor as Map<String, dynamic>;
      final team = comp['team'] as Map<String, dynamic>?;
      final teamName = team?['displayName'] as String? ?? team?['name'] as String? ?? '';
      final abbr = team?['abbreviation'] as String?;
      final logo = team?['logo'] as String?;
      final scoreStr = comp['score'] as String?;
      final score = scoreStr != null ? int.tryParse(scoreStr) : null;
      final homeAway = comp['homeAway'] as String?;
      final records = comp['records'] as List<dynamic>?;
      final record = (records != null && records.isNotEmpty && records[0] != null)
          ? (records[0] as Map<String, dynamic>)['summary'] as String?
          : null;

      if (homeAway == 'home') {
        homeTeam = teamName;
        homeAbbr = abbr;
        homeLogo = logo;
        homeScore = score;
        homeRecord = record;
      } else if (homeAway == 'away') {
        awayTeam = teamName;
        awayAbbr = abbr;
        awayLogo = logo;
        awayScore = score;
        awayRecord = record;
      }
    }

    return EspnGame(
      id: id,
      sportKey: sportKey,
      name: name,
      shortName: shortName,
      startTime: date,
      homeTeam: homeTeam,
      awayTeam: awayTeam,
      homeAbbr: homeAbbr,
      awayAbbr: awayAbbr,
      homeLogo: homeLogo,
      awayLogo: awayLogo,
      homeScore: homeScore,
      awayScore: awayScore,
      homeRecord: homeRecord,
      awayRecord: awayRecord,
      isLive: statusName == 'STATUS_IN_PROGRESS' || statusName == 'STATUS_HALFTIME',
      isCompleted: completed || statusName == 'STATUS_FINAL',
      gameTime: gameTime,
      statusDescription: statusDescription,
      // Odds populated via Core API in _fetchOddsForEvents()
    );
  }
}

/// ESPN game data model
class EspnGame {
  final String id;
  final String sportKey;
  final String name;
  final String shortName;
  final DateTime startTime;
  final String homeTeam;
  final String awayTeam;
  final String? homeAbbr;
  final String? awayAbbr;
  final String? homeLogo;
  final String? awayLogo;
  final int? homeScore;
  final int? awayScore;
  final String? homeRecord;
  final String? awayRecord;
  final bool isLive;
  final bool isCompleted;
  final String? gameTime;
  final String? statusDescription;
  // Betting odds from DraftKings via ESPN
  final double? spreadLine;
  final double? totalLine;
  final double? homeMoneyline;   // American odds e.g., -115
  final double? awayMoneyline;   // American odds e.g., +105
  final double? homeSpreadOdds;  // American odds e.g., -110
  final double? awaySpreadOdds;  // American odds e.g., -110
  final double? overOdds;        // American odds e.g., -112
  final double? underOdds;       // American odds e.g., -108

  const EspnGame({
    required this.id,
    required this.sportKey,
    required this.name,
    required this.shortName,
    required this.startTime,
    required this.homeTeam,
    required this.awayTeam,
    this.homeAbbr,
    this.awayAbbr,
    this.homeLogo,
    this.awayLogo,
    this.homeScore,
    this.awayScore,
    this.homeRecord,
    this.awayRecord,
    this.isLive = false,
    this.isCompleted = false,
    this.gameTime,
    this.statusDescription,
    this.spreadLine,
    this.totalLine,
    this.homeMoneyline,
    this.awayMoneyline,
    this.homeSpreadOdds,
    this.awaySpreadOdds,
    this.overOdds,
    this.underOdds,
  });

  bool get hasScores => homeScore != null && awayScore != null;
  bool get isScheduled => !isLive && !isCompleted;
  bool get hasOdds => spreadLine != null || totalLine != null || homeMoneyline != null;

  /// Get the ESPN event ID without prefix
  String get espnEventId => id.replaceFirst('espn_', '');

  /// Create a copy with updated odds
  EspnGame copyWithOdds({
    double? spreadLine,
    double? totalLine,
    double? homeMoneyline,
    double? awayMoneyline,
    double? homeSpreadOdds,
    double? awaySpreadOdds,
    double? overOdds,
    double? underOdds,
  }) {
    return EspnGame(
      id: id,
      sportKey: sportKey,
      name: name,
      shortName: shortName,
      startTime: startTime,
      homeTeam: homeTeam,
      awayTeam: awayTeam,
      homeAbbr: homeAbbr,
      awayAbbr: awayAbbr,
      homeLogo: homeLogo,
      awayLogo: awayLogo,
      homeScore: homeScore,
      awayScore: awayScore,
      homeRecord: homeRecord,
      awayRecord: awayRecord,
      isLive: isLive,
      isCompleted: isCompleted,
      gameTime: gameTime,
      statusDescription: statusDescription,
      spreadLine: spreadLine ?? this.spreadLine,
      totalLine: totalLine ?? this.totalLine,
      homeMoneyline: homeMoneyline ?? this.homeMoneyline,
      awayMoneyline: awayMoneyline ?? this.awayMoneyline,
      homeSpreadOdds: homeSpreadOdds ?? this.homeSpreadOdds,
      awaySpreadOdds: awaySpreadOdds ?? this.awaySpreadOdds,
      overOdds: overOdds ?? this.overOdds,
      underOdds: underOdds ?? this.underOdds,
    );
  }
}

/// Game details with full stats
class GameDetails {
  final String eventId;
  final String sportKey;
  final TeamStats? homeTeam;
  final TeamStats? awayTeam;
  final List<StatCategory> homeStats;
  final List<StatCategory> awayStats;
  final List<PlayerStats> homePlayers;
  final List<PlayerStats> awayPlayers;
  final List<ScoringPlay> scoringPlays;
  final List<GameLeader> leaders;
  final String? venue;
  final int? attendance;
  // Live odds
  final double? spreadLine;
  final double? totalLine;
  final double? homeMoneyline;
  final double? awayMoneyline;
  final double? homeSpreadOdds;
  final double? awaySpreadOdds;
  final double? overOdds;
  final double? underOdds;

  const GameDetails({
    required this.eventId,
    required this.sportKey,
    this.homeTeam,
    this.awayTeam,
    this.homeStats = const [],
    this.awayStats = const [],
    this.homePlayers = const [],
    this.awayPlayers = const [],
    this.scoringPlays = const [],
    this.leaders = const [],
    this.venue,
    this.attendance,
    this.spreadLine,
    this.totalLine,
    this.homeMoneyline,
    this.awayMoneyline,
    this.homeSpreadOdds,
    this.awaySpreadOdds,
    this.overOdds,
    this.underOdds,
  });

  bool get hasOdds => spreadLine != null || homeMoneyline != null || totalLine != null;
}

/// Team statistics summary
class TeamStats {
  final String id;
  final String name;
  final String abbreviation;
  final String? logo;
  final int? score;
  final String? record;
  final String? color;

  const TeamStats({
    required this.id,
    required this.name,
    required this.abbreviation,
    this.logo,
    this.score,
    this.record,
    this.color,
  });
}

/// Individual stat category
class StatCategory {
  final String name;
  final String displayName;
  final String value;

  const StatCategory({
    required this.name,
    required this.displayName,
    required this.value,
  });
}

/// Player statistics
class PlayerStats {
  final String id;
  final String name;
  final String shortName;
  final String position;
  final String jersey;
  final String? headshot;
  final String category;
  final Map<String, String> stats;

  const PlayerStats({
    required this.id,
    required this.name,
    required this.shortName,
    required this.position,
    required this.jersey,
    this.headshot,
    required this.category,
    required this.stats,
  });

  /// Get a specific stat value
  String? getStat(String key) => stats[key];

  /// Get key stats based on sport category
  String get primaryStat {
    // For different positions/categories, show relevant stats
    if (category.toLowerCase().contains('passing')) {
      return '${stats['C/ATT'] ?? ''} ${stats['YDS'] ?? ''} YDS ${stats['TD'] ?? ''} TD';
    } else if (category.toLowerCase().contains('rushing')) {
      return '${stats['CAR'] ?? ''} CAR ${stats['YDS'] ?? ''} YDS ${stats['TD'] ?? ''} TD';
    } else if (category.toLowerCase().contains('receiving')) {
      return '${stats['REC'] ?? ''} REC ${stats['YDS'] ?? ''} YDS ${stats['TD'] ?? ''} TD';
    } else if (stats.containsKey('PTS')) {
      return '${stats['PTS'] ?? '0'} PTS ${stats['REB'] ?? '0'} REB ${stats['AST'] ?? '0'} AST';
    } else if (stats.containsKey('G')) {
      return '${stats['G'] ?? '0'} G ${stats['A'] ?? '0'} A';
    }
    return stats.values.take(3).join(' ');
  }
}

/// Scoring play/key event
class ScoringPlay {
  final String description;
  final String? teamLogo;
  final String? teamAbbr;
  final int period;
  final String clock;
  final int homeScore;
  final int awayScore;

  const ScoringPlay({
    required this.description,
    this.teamLogo,
    this.teamAbbr,
    required this.period,
    required this.clock,
    required this.homeScore,
    required this.awayScore,
  });
}

/// Game leader (top performer)
class GameLeader {
  final String category;
  final String name;
  final String value;
  final String? teamAbbr;
  final String? headshot;

  const GameLeader({
    required this.category,
    required this.name,
    required this.value,
    this.teamAbbr,
    this.headshot,
  });
}
