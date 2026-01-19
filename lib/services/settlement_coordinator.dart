import 'package:flutter/foundation.dart';
import '../models/game_score.dart';
import '../models/prediction.dart';
import '../providers/predictions_provider.dart';
import '../providers/auth_provider.dart';
import 'settlement_service.dart';

/// Coordinates the settlement process between services and providers
class SettlementCoordinator {
  final SettlementService settlementService;
  final PredictionsProvider predictionsProvider;
  final AuthProvider authProvider;

  bool _isSettling = false;
  DateTime? _lastSettlement;

  static const Duration _minSettlementInterval = Duration(minutes: 5);

  SettlementCoordinator({
    required this.settlementService,
    required this.predictionsProvider,
    required this.authProvider,
  });

  /// Whether settlement is currently running
  bool get isSettling => _isSettling;

  /// Run the full settlement cycle
  Future<SettlementSummary> runSettlement() async {
    // Prevent concurrent settlement runs
    if (_isSettling) {
      return SettlementSummary.skipped('Already running');
    }

    // Rate limiting - don't settle too frequently
    if (_lastSettlement != null) {
      final elapsed = DateTime.now().difference(_lastSettlement!);
      if (elapsed < _minSettlementInterval) {
        return SettlementSummary.skipped(
          'Too soon (${_minSettlementInterval.inMinutes - elapsed.inMinutes}m remaining)',
        );
      }
    }

    _isSettling = true;

    try {
      final summary = SettlementSummary();

      // 1. Get pending predictions
      final pending = predictionsProvider.pendingPredictions;
      if (pending.isEmpty) {
        return SettlementSummary.skipped('No pending predictions');
      }

      // 2. Filter to games that should have finished (started 2+ hours ago)
      final eligiblePredictions = pending.where((p) {
        final timeSinceStart = DateTime.now().difference(p.gameStartTime);
        return timeSinceStart.inHours >= 2;
      }).toList();

      if (eligiblePredictions.isEmpty) {
        return SettlementSummary.skipped('No games finished yet');
      }

      debugPrint('Settlement: ${eligiblePredictions.length} eligible predictions');

      // 3. Fetch scores for relevant sports
      final sportKeys = eligiblePredictions.map((p) => p.sportKey).toSet();
      Map<String, List<GameScore>> scoresBySport;

      try {
        scoresBySport = await settlementService.fetchScoresForSports(sportKeys);
      } catch (e) {
        debugPrint('Failed to fetch scores: $e');
        return SettlementSummary.skipped('Failed to fetch scores');
      }

      // 4. Create game ID to score mapping with multiple ID formats
      // Store raw ID, espn_prefixed, and normalized versions for robust matching
      final scoresByGameId = <String, GameScore>{};
      for (final scores in scoresBySport.values) {
        for (final score in scores) {
          // Store with multiple ID formats for robust matching
          _addScoreWithIdVariants(scoresByGameId, score);
        }
      }

      debugPrint('Settlement: fetched ${scoresByGameId.length} game scores');
      debugPrint('Settlement: Score game IDs: ${scoresByGameId.keys.take(10).toList()}...');
      debugPrint('Settlement: Prediction game IDs: ${eligiblePredictions.map((p) => p.gameId).toList()}');

      // 5. Settle individual (straight) bets
      await _settleStraightBets(eligiblePredictions, scoresByGameId, scoresBySport, summary);

      // 6. Settle parlays
      await _settleParlays(eligiblePredictions, scoresByGameId, scoresBySport, summary);

      _lastSettlement = DateTime.now();

      debugPrint('Settlement complete: $summary');
      return summary;
    } catch (e) {
      debugPrint('Settlement error: $e');
      return SettlementSummary.skipped('Error: $e');
    } finally {
      _isSettling = false;
    }
  }

  /// Settle straight (non-parlay) bets
  Future<void> _settleStraightBets(
    List<Prediction> predictions,
    Map<String, GameScore> scoresByGameId,
    Map<String, List<GameScore>> scoresBySport,
    SettlementSummary summary,
  ) async {
    // Filter to straight bets only
    final straightBets = predictions.where((p) => p.parlayId == null);

    for (final prediction in straightBets) {
      // Use flexible matching to find the score
      final score = _findScoreForPrediction(prediction, scoresByGameId, scoresBySport);
      debugPrint('Settlement: Checking prediction ${prediction.id} for game ${prediction.gameId}');
      debugPrint('Settlement: Score found: ${score != null ? "${score.homeScore}-${score.awayScore}, completed: ${score.completed}" : "NOT FOUND"}');
      final result = settlementService.evaluatePrediction(prediction, score);
      debugPrint('Settlement: Result = $result');

      // Skip if still pending
      if (result == SettlementResult.pending) continue;

      int payout = 0;
      PredictionStatus status;

      switch (result) {
        case SettlementResult.won:
          payout = prediction.potentialPayout;
          status = PredictionStatus.won;
          // Credit winnings to user
          await authProvider.addCoins(payout);
          // Record stats
          await authProvider.recordPredictionResult(true);
          summary.wins++;
          summary.totalWinnings += payout;
          debugPrint('Won: ${prediction.outcomeDisplay} - +$payout coins');
          break;

        case SettlementResult.lost:
          payout = 0;
          status = PredictionStatus.lost;
          // Record stats
          await authProvider.recordPredictionResult(false);
          summary.losses++;
          debugPrint('Lost: ${prediction.outcomeDisplay}');
          break;

        case SettlementResult.push:
          // Return the stake
          payout = prediction.stake;
          status = PredictionStatus.push;
          await authProvider.addCoins(payout);
          summary.pushes++;
          debugPrint('Push: ${prediction.outcomeDisplay} - refund $payout coins');
          break;

        case SettlementResult.cancelled:
          // Return the stake
          payout = prediction.stake;
          status = PredictionStatus.cancelled;
          await authProvider.addCoins(payout);
          debugPrint('Cancelled: ${prediction.outcomeDisplay} - refund $payout coins');
          break;

        default:
          continue;
      }

      // Update prediction status with final scores
      await predictionsProvider.updatePredictionStatus(
        prediction.id,
        status,
        payout: payout,
        finalHomeScore: score?.homeScore,
        finalAwayScore: score?.awayScore,
      );
      summary.settledCount++;
    }
  }

  /// Settle parlay bets
  Future<void> _settleParlays(
    List<Prediction> predictions,
    Map<String, GameScore> scoresByGameId,
    Map<String, List<GameScore>> scoresBySport,
    SettlementSummary summary,
  ) async {
    // Group by parlay ID
    final parlayGroups = <String, List<Prediction>>{};
    for (final p in predictions.where((p) => p.parlayId != null)) {
      parlayGroups.putIfAbsent(p.parlayId!, () => []).add(p);
    }

    for (final entry in parlayGroups.entries) {
      final legs = entry.value;

      // Build a map of scores for parlay legs using flexible matching
      final parlayScores = <String, GameScore>{};
      for (final leg in legs) {
        final score = _findScoreForPrediction(leg, scoresByGameId, scoresBySport);
        if (score != null) {
          parlayScores[leg.gameId] = score;
        }
      }

      final parlayResult = settlementService.evaluateParlay(legs, parlayScores);

      // Skip if parlay not ready to settle (unless it lost)
      if (!parlayResult.allLegsSettled &&
          parlayResult.overallResult != SettlementResult.lost) {
        continue;
      }

      debugPrint('Settling parlay ${entry.key}: ${parlayResult.overallResult}');

      // Credit winnings based on overall result
      switch (parlayResult.overallResult) {
        case SettlementResult.won:
          await authProvider.addCoins(parlayResult.payout);
          summary.totalWinnings += parlayResult.payout;
          summary.parlaysWon++;
          // Record win for each leg
          for (var i = 0; i < legs.length; i++) {
            await authProvider.recordPredictionResult(true);
          }
          debugPrint('Parlay won: +${parlayResult.payout} coins');
          break;

        case SettlementResult.push:
          await authProvider.addCoins(parlayResult.payout);
          summary.parlaysPushed++;
          debugPrint('Parlay pushed: refund ${parlayResult.payout} coins');
          break;

        case SettlementResult.lost:
          summary.parlaysLost++;
          // Record loss for each leg
          for (var i = 0; i < legs.length; i++) {
            await authProvider.recordPredictionResult(false);
          }
          debugPrint('Parlay lost');
          break;

        default:
          continue;
      }

      // Update each leg's status
      for (final leg in legs) {
        final legResult = parlayResult.legResults[leg.id]!;
        final legStatus = _resultToStatus(legResult);
        final legScore = parlayScores[leg.gameId];

        // For parlay legs, payout is only on the first leg (or could be distributed)
        // We'll put the full payout on each leg for display purposes
        final legPayout = parlayResult.overallResult == SettlementResult.won
            ? parlayResult.payout
            : 0;

        await predictionsProvider.updatePredictionStatus(
          leg.id,
          legStatus,
          payout: legPayout,
          finalHomeScore: legScore?.homeScore,
          finalAwayScore: legScore?.awayScore,
        );
      }

      summary.settledCount += legs.length;
    }
  }

  /// Convert SettlementResult to PredictionStatus
  PredictionStatus _resultToStatus(SettlementResult result) {
    switch (result) {
      case SettlementResult.won:
        return PredictionStatus.won;
      case SettlementResult.lost:
        return PredictionStatus.lost;
      case SettlementResult.push:
        return PredictionStatus.push;
      case SettlementResult.cancelled:
        return PredictionStatus.cancelled;
      case SettlementResult.pending:
        return PredictionStatus.pending;
    }
  }

  /// Force reset the rate limiter (useful for testing)
  void resetRateLimiter() {
    _lastSettlement = null;
  }

  /// Add score with multiple ID variants for robust matching
  void _addScoreWithIdVariants(Map<String, GameScore> map, GameScore score) {
    final rawId = score.id;

    // Store with raw ID
    map[rawId] = score;

    // Store with espn_ prefix (predictions often use this format)
    map['espn_$rawId'] = score;

    // If ID already has espn_ prefix, also store without it
    if (rawId.startsWith('espn_')) {
      final stripped = rawId.substring(5);
      map[stripped] = score;
    }

    // Store lowercase versions for case-insensitive matching
    map[rawId.toLowerCase()] = score;
    map['espn_${rawId.toLowerCase()}'] = score;
  }

  /// Find score for a prediction with flexible ID matching
  GameScore? _findScoreForPrediction(
    Prediction prediction,
    Map<String, GameScore> scoresByGameId,
    Map<String, List<GameScore>> scoresBySport,
  ) {
    final gameId = prediction.gameId;

    // Try direct lookup first (most common case)
    if (scoresByGameId.containsKey(gameId)) {
      return scoresByGameId[gameId];
    }

    // Try with espn_ prefix stripped
    if (gameId.startsWith('espn_')) {
      final strippedId = gameId.substring(5);
      if (scoresByGameId.containsKey(strippedId)) {
        return scoresByGameId[strippedId];
      }
    }

    // Try with espn_ prefix added
    final prefixedId = 'espn_$gameId';
    if (scoresByGameId.containsKey(prefixedId)) {
      return scoresByGameId[prefixedId];
    }

    // Try lowercase matching
    final lowerId = gameId.toLowerCase();
    if (scoresByGameId.containsKey(lowerId)) {
      return scoresByGameId[lowerId];
    }

    // Try fuzzy matching by teams and time within same sport
    final sportScores = scoresBySport[prediction.sportKey] ??
                        scoresBySport[_normalizeSportKey(prediction.sportKey)] ?? [];

    for (final score in sportScores) {
      // Match by home/away team names (case insensitive)
      final homeMatch = _teamsMatch(prediction.homeTeam, score.homeTeam);
      final awayMatch = _teamsMatch(prediction.awayTeam, score.awayTeam);

      // Match by time (within 2 hours of each other)
      final timeDiff = prediction.gameStartTime.difference(score.commenceTime).abs();
      final timeMatch = timeDiff.inHours <= 2;

      if (homeMatch && awayMatch && timeMatch) {
        debugPrint('Settlement: Fuzzy matched game ${prediction.gameId} to ${score.id} by teams/time');
        return score;
      }
    }

    return null;
  }

  /// Check if two team names match (handles abbreviations and variations)
  bool _teamsMatch(String team1, String team2) {
    final t1 = team1.toLowerCase().trim();
    final t2 = team2.toLowerCase().trim();

    // Exact match
    if (t1 == t2) return true;

    // One contains the other (handles "Lakers" vs "Los Angeles Lakers")
    if (t1.contains(t2) || t2.contains(t1)) return true;

    // Common abbreviation handling
    final t1Words = t1.split(' ');
    final t2Words = t2.split(' ');

    // If last word matches (usually the team nickname)
    if (t1Words.isNotEmpty && t2Words.isNotEmpty) {
      if (t1Words.last == t2Words.last) return true;
    }

    return false;
  }

  /// Normalize sport key for flexible matching
  String _normalizeSportKey(String sportKey) {
    final normalized = sportKey.toLowerCase().trim();

    // Handle common variations
    final mappings = {
      'nfl': 'americanfootball_nfl',
      'nba': 'basketball_nba',
      'mlb': 'baseball_mlb',
      'nhl': 'icehockey_nhl',
      'ncaaf': 'americanfootball_ncaaf',
      'ncaab': 'basketball_ncaab',
      'college_football': 'americanfootball_ncaaf',
      'college_basketball': 'basketball_ncaab',
      'mls': 'soccer_usa_mls',
      'epl': 'soccer_epl',
      'premier_league': 'soccer_epl',
    };

    return mappings[normalized] ?? normalized;
  }
}
