import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import '../models/game_score.dart';
import '../models/prediction.dart';
import 'espn_scores_service.dart';

/// Service for fetching game scores and evaluating prediction results
class SettlementService {
  static const String _baseUrl = AppConstants.oddsApiBaseUrl;
  static const String _apiKey = AppConstants.oddsApiKey;

  final EspnScoresService _espnService = EspnScoresService();
  int _remainingRequests = 500;

  /// Get remaining API requests
  int get remainingRequests => _remainingRequests;

  /// Fetch scores for multiple sports - uses ESPN as primary source
  Future<Map<String, List<GameScore>>> fetchScoresForSports(
    Set<String> sportKeys,
  ) async {
    final results = <String, List<GameScore>>{};

    for (final sportKey in sportKeys) {
      try {
        final scores = await fetchScoresForSport(sportKey);
        results[sportKey] = scores;
      } catch (e) {
        // Log error but continue with other sports
        debugPrint('Failed to fetch scores for $sportKey: $e');
        results[sportKey] = [];
      }
    }

    return results;
  }

  /// Fetch scores for a single sport - ESPN first, fallback to Odds API
  Future<List<GameScore>> fetchScoresForSport(String sportKey) async {
    // Try ESPN first (no API key required, no rate limits)
    if (_espnService.supportsSport(sportKey)) {
      try {
        final espnScores = await _espnService.fetchScoresForSport(sportKey);
        if (espnScores.isNotEmpty) {
          debugPrint('ESPN: Got ${espnScores.length} scores for $sportKey');
          return espnScores;
        }
      } catch (e) {
        debugPrint('ESPN failed for $sportKey: $e, trying Odds API...');
      }
    }

    // Fallback to The Odds API
    return _fetchFromOddsApi(sportKey);
  }

  /// Fetch scores from The Odds API (fallback)
  Future<List<GameScore>> _fetchFromOddsApi(String sportKey) async {
    // Check API quota
    if (_remainingRequests <= 10) {
      throw SettlementException('API quota low, skipping settlement');
    }

    final url = Uri.parse(
      '$_baseUrl/sports/$sportKey/scores'
      '?apiKey=$_apiKey'
      '&daysFrom=3', // Get last 3 days of games
    );

    try {
      final response = await http.get(url);

      // Update remaining from headers
      final remaining = response.headers['x-requests-remaining'];
      if (remaining != null) {
        _remainingRequests = int.tryParse(remaining) ?? _remainingRequests;
      }

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => GameScore.fromOddsApi(json)).toList();
      } else if (response.statusCode == 401) {
        throw SettlementException('Invalid API key');
      } else if (response.statusCode == 429) {
        throw SettlementException('API rate limit exceeded');
      } else {
        throw SettlementException('API error: ${response.statusCode}');
      }
    } catch (e) {
      if (e is SettlementException) rethrow;
      throw SettlementException('Network error: $e');
    }
  }

  /// Evaluate a single prediction against a game score
  SettlementResult evaluatePrediction(
    Prediction prediction,
    GameScore? score,
  ) {
    // Game not found in API
    if (score == null) {
      // If game was supposed to start 24+ hours ago, consider it cancelled
      final timeSinceStart = DateTime.now().difference(prediction.gameStartTime);
      if (timeSinceStart.inHours >= 24) {
        return SettlementResult.cancelled;
      }
      return SettlementResult.pending;
    }

    // Check if game is "effectively completed"
    // ESPN doesn't always mark games as completed even when they have final scores
    final isEffectivelyCompleted = _isGameEffectivelyCompleted(prediction, score);

    // Game not completed yet
    if (!score.completed && !isEffectivelyCompleted) {
      return SettlementResult.pending;
    }

    // Game found but scores are null (cancelled/postponed)
    if (!score.hasScores) {
      return SettlementResult.cancelled;
    }

    // Evaluate based on prediction type
    switch (prediction.type) {
      case PredictionType.moneyline:
        return _evaluateMoneyline(prediction, score);
      case PredictionType.spread:
        return _evaluateSpread(prediction, score);
      case PredictionType.total:
        return _evaluateTotal(prediction, score);
      case PredictionType.playerProp:
        // Player props not supported yet
        return SettlementResult.pending;
    }
  }

  /// Check if a game is effectively completed (has scores and enough time has passed)
  bool _isGameEffectivelyCompleted(Prediction prediction, GameScore score) {
    // Must have both scores
    if (!score.hasScores) return false;

    // Calculate time since game was supposed to start
    final timeSinceStart = DateTime.now().difference(prediction.gameStartTime);

    // Different sports have different game lengths
    // We use conservative estimates to ensure games are actually finished
    final sportKey = prediction.sportKey.toLowerCase();

    int minHoursForCompletion;
    if (sportKey.contains('football')) {
      // NFL/NCAAF games typically ~3.5 hours
      minHoursForCompletion = 4;
    } else if (sportKey.contains('basketball')) {
      // NBA/NCAAB games typically ~2.5 hours
      minHoursForCompletion = 3;
    } else if (sportKey.contains('baseball')) {
      // MLB games can be long, up to 4+ hours
      minHoursForCompletion = 5;
    } else if (sportKey.contains('hockey')) {
      // NHL games typically ~2.5 hours
      minHoursForCompletion = 3;
    } else if (sportKey.contains('soccer')) {
      // Soccer games ~2 hours including stoppage time
      minHoursForCompletion = 3;
    } else {
      // Default: 4 hours should cover most sports
      minHoursForCompletion = 4;
    }

    // If enough time has passed and we have scores, consider it completed
    if (timeSinceStart.inHours >= minHoursForCompletion) {
      debugPrint(
        'Settlement: Game ${score.id} effectively completed - '
        'has scores (${score.homeScore}-${score.awayScore}) and '
        '${timeSinceStart.inHours}h since start (min: ${minHoursForCompletion}h)',
      );
      return true;
    }

    return false;
  }

  /// Evaluate a moneyline bet
  SettlementResult _evaluateMoneyline(Prediction prediction, GameScore score) {
    switch (prediction.outcome) {
      case PredictionOutcome.home:
        // User bet on home team to win
        if (score.homeScore! > score.awayScore!) {
          return SettlementResult.won;
        } else if (score.homeScore! < score.awayScore!) {
          return SettlementResult.lost;
        } else {
          // Draw - for sports without draws, this is a push
          // For soccer, if they bet home and it's a draw, they lose
          return prediction.sportKey.startsWith('soccer')
              ? SettlementResult.lost
              : SettlementResult.push;
        }

      case PredictionOutcome.away:
        // User bet on away team to win
        if (score.awayScore! > score.homeScore!) {
          return SettlementResult.won;
        } else if (score.awayScore! < score.homeScore!) {
          return SettlementResult.lost;
        } else {
          return prediction.sportKey.startsWith('soccer')
              ? SettlementResult.lost
              : SettlementResult.push;
        }

      case PredictionOutcome.draw:
        // User bet on a draw (soccer only)
        return score.isDraw ? SettlementResult.won : SettlementResult.lost;

      default:
        return SettlementResult.pending;
    }
  }

  /// Evaluate a spread bet
  SettlementResult _evaluateSpread(Prediction prediction, GameScore score) {
    final line = prediction.line ?? 0;

    if (prediction.outcome == PredictionOutcome.home) {
      // Home team spread: Home score + spread line vs Away score
      // Example: Home -3.5 means home.score - 3.5 must be > away.score
      // Line is stored as negative for favorites (e.g., -3.5)
      final adjustedHomeScore = score.homeScore! + line;

      if (adjustedHomeScore > score.awayScore!) {
        return SettlementResult.won;
      } else if (adjustedHomeScore == score.awayScore!) {
        return SettlementResult.push;
      } else {
        return SettlementResult.lost;
      }
    } else if (prediction.outcome == PredictionOutcome.away) {
      // Away team spread: Away score + (negative of home line) vs Home score
      // If home is -3.5, away is +3.5
      final adjustedAwayScore = score.awayScore! - line;

      if (adjustedAwayScore > score.homeScore!) {
        return SettlementResult.won;
      } else if (adjustedAwayScore == score.homeScore!) {
        return SettlementResult.push;
      } else {
        return SettlementResult.lost;
      }
    }

    return SettlementResult.pending;
  }

  /// Evaluate an over/under total bet
  SettlementResult _evaluateTotal(Prediction prediction, GameScore score) {
    final line = prediction.line ?? 0;
    final total = score.totalScore.toDouble();

    if (prediction.outcome == PredictionOutcome.over) {
      if (total > line) {
        return SettlementResult.won;
      } else if (total == line) {
        return SettlementResult.push;
      } else {
        return SettlementResult.lost;
      }
    } else if (prediction.outcome == PredictionOutcome.under) {
      if (total < line) {
        return SettlementResult.won;
      } else if (total == line) {
        return SettlementResult.push;
      } else {
        return SettlementResult.lost;
      }
    }

    return SettlementResult.pending;
  }

  /// Evaluate a parlay (all legs must win for payout)
  ParlaySettlementResult evaluateParlay(
    List<Prediction> legs,
    Map<String, GameScore> scoresByGameId,
  ) {
    final results = <String, SettlementResult>{};

    // Evaluate each leg
    for (final leg in legs) {
      final score = scoresByGameId[leg.gameId];
      results[leg.id] = evaluatePrediction(leg, score);
    }

    // Determine overall result
    final hasAnyPending =
        results.values.any((r) => r == SettlementResult.pending);
    final hasAnyLoss = results.values.any((r) => r == SettlementResult.lost);
    final hasAnyCancelled =
        results.values.any((r) => r == SettlementResult.cancelled);

    // If any leg loses, parlay loses immediately
    if (hasAnyLoss) {
      return ParlaySettlementResult(
        parlayId: legs.first.parlayId!,
        legResults: results,
        overallResult: SettlementResult.lost,
        payout: 0,
        allLegsSettled: true, // Can settle early on loss
      );
    }

    // If any leg is cancelled, handle differently
    if (hasAnyCancelled) {
      final nonCancelledLegs =
          results.entries.where((e) => e.value != SettlementResult.cancelled);

      if (nonCancelledLegs.isEmpty) {
        // All legs cancelled - return stake
        return ParlaySettlementResult(
          parlayId: legs.first.parlayId!,
          legResults: results,
          overallResult: SettlementResult.push,
          payout: legs.first.stake,
          allLegsSettled: true,
        );
      }
      // Some cancelled - continue checking remaining
    }

    // If any leg pending, parlay stays pending
    if (hasAnyPending) {
      return ParlaySettlementResult(
        parlayId: legs.first.parlayId!,
        legResults: results,
        overallResult: SettlementResult.pending,
        payout: 0,
        allLegsSettled: false,
      );
    }

    // All legs are either won or push
    final allPush = results.values
        .where((r) => r != SettlementResult.cancelled)
        .every((r) => r == SettlementResult.push);

    if (allPush) {
      // All non-cancelled legs pushed - return stake
      return ParlaySettlementResult(
        parlayId: legs.first.parlayId!,
        legResults: results,
        overallResult: SettlementResult.push,
        payout: legs.first.stake,
        allLegsSettled: true,
      );
    }

    // Parlay won - calculate payout
    // Note: If some legs pushed, technically odds should be recalculated
    // but for simplicity we'll pay the full amount
    return ParlaySettlementResult(
      parlayId: legs.first.parlayId!,
      legResults: results,
      overallResult: SettlementResult.won,
      payout: legs.first.potentialPayout,
      allLegsSettled: true,
    );
  }
}

/// Exception for settlement-related errors
class SettlementException implements Exception {
  final String message;
  SettlementException(this.message);

  @override
  String toString() => 'SettlementException: $message';
}
