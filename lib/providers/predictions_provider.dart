import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/prediction.dart';
import '../config/constants.dart';
import '../services/supabase_service.dart';

class PredictionsProvider extends ChangeNotifier {
  final List<Prediction> _predictions = [];
  bool _isLoading = false;
  String? _userId;

  /// Callback for when a prediction is settled, to award XP
  /// Parameters: (bool won, int betCount, bool isParlay)
  Future<void> Function(bool won, int betCount, bool isParlay)? onSettlementCallback;

  List<Prediction> get predictions => List.unmodifiable(_predictions);
  bool get isLoading => _isLoading;

  List<Prediction> get pendingPredictions =>
      _predictions.where((p) => p.isPending).toList();

  List<Prediction> get settledPredictions =>
      _predictions.where((p) => p.isSettled).toList();

  List<Prediction> get wonPredictions =>
      _predictions.where((p) => p.isWon).toList();

  List<Prediction> get lostPredictions =>
      _predictions.where((p) => p.isLost).toList();

  int get totalPendingStake =>
      pendingPredictions.fold(0, (sum, p) => sum + p.stake);

  int get totalWinnings =>
      wonPredictions.fold(0, (sum, p) => sum + (p.payout ?? p.potentialPayout));

  double get winRate {
    final settled = settledPredictions.length;
    if (settled == 0) return 0;
    return (wonPredictions.length / settled) * 100;
  }

  /// Get unique sport keys from pending predictions
  Set<String> get pendingSportKeys =>
      pendingPredictions.map((p) => p.sportKey).toSet();

  /// Get pending predictions grouped by game ID
  Map<String, List<Prediction>> get pendingByGameId {
    final map = <String, List<Prediction>>{};
    for (final p in pendingPredictions) {
      map.putIfAbsent(p.gameId, () => []).add(p);
    }
    return map;
  }

  /// Get pending predictions grouped by parlay ID
  Map<String?, List<Prediction>> get pendingByParlayId {
    final map = <String?, List<Prediction>>{};
    for (final p in pendingPredictions) {
      map.putIfAbsent(p.parlayId, () => []).add(p);
    }
    return map;
  }

  /// Check if there are eligible predictions for settlement
  bool get hasEligiblePredictions {
    final now = DateTime.now();
    return pendingPredictions.any((p) {
      final timeSinceStart = now.difference(p.gameStartTime);
      return timeSinceStart.inHours >= 2;
    });
  }

  void setUserId(String? userId) {
    // Clear predictions when switching users
    if (_userId != userId) {
      _predictions.clear();
    }
    _userId = userId;
  }

  Future<void> loadPredictions() async {
    _isLoading = true;
    notifyListeners();

    // Clear existing predictions first
    _predictions.clear();

    try {
      // Only load from Supabase if user is logged in
      if (_userId != null) {
        final supabasePredictions = await SupabaseService.getUserPredictions(_userId!);
        _predictions.addAll(
          supabasePredictions.map((json) => Prediction.fromSupabase(json)),
        );
        debugPrint('Loaded ${_predictions.length} predictions for user $_userId');
      }
      // No fallback to local storage - predictions are user-specific
    } catch (e) {
      debugPrint('Error loading predictions: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addPrediction(Prediction prediction) async {
    _predictions.insert(0, prediction);
    await _savePredictions();

    // Save to Supabase
    if (_userId != null) {
      try {
        await SupabaseService.savePrediction(prediction, _userId!);
      } catch (e) {
        debugPrint('Error saving prediction to Supabase: $e');
      }
    }

    notifyListeners();
  }

  Future<void> addPredictions(List<Prediction> newPredictions) async {
    _predictions.insertAll(0, newPredictions);
    await _savePredictions();

    // Save to Supabase
    if (_userId != null) {
      try {
        await SupabaseService.savePredictions(newPredictions, _userId!);
      } catch (e) {
        debugPrint('Error saving predictions to Supabase: $e');
      }
    }

    notifyListeners();
  }

  Future<void> updatePredictionStatus(
    String predictionId,
    PredictionStatus status, {
    int? payout,
    int? finalHomeScore,
    int? finalAwayScore,
  }) async {
    final index = _predictions.indexWhere((p) => p.id == predictionId);
    if (index != -1) {
      _predictions[index] = _predictions[index].copyWith(
        status: status,
        payout: payout,
        finalHomeScore: finalHomeScore,
        finalAwayScore: finalAwayScore,
      );
      await _savePredictions();

      // Update in Supabase
      try {
        await SupabaseService.updatePredictionStatus(
          predictionId,
          status,
          payout,
          finalHomeScore: finalHomeScore,
          finalAwayScore: finalAwayScore,
        );
      } catch (e) {
        debugPrint('Error updating prediction in Supabase: $e');
      }

      notifyListeners();
    }
  }

  Future<void> settlePrediction(String predictionId, bool won, {bool isParlay = false}) async {
    final index = _predictions.indexWhere((p) => p.id == predictionId);
    if (index != -1) {
      final prediction = _predictions[index];
      final status = won ? PredictionStatus.won : PredictionStatus.lost;
      final payout = won ? prediction.potentialPayout : 0;

      _predictions[index] = prediction.copyWith(
        status: status,
        payout: payout,
      );
      await _savePredictions();

      // Update in Supabase
      try {
        await SupabaseService.updatePredictionStatus(predictionId, status, payout);
      } catch (e) {
        debugPrint('Error settling prediction in Supabase: $e');
      }

      // Award XP via callback if set
      if (onSettlementCallback != null) {
        await onSettlementCallback!(won, 1, isParlay);
      }

      notifyListeners();
    }
  }

  List<Prediction> getPredictionsForGame(String gameId) {
    return _predictions.where((p) => p.gameId == gameId).toList();
  }

  List<Prediction> getPredictionsForSport(String sportKey) {
    return _predictions.where((p) => p.sportKey == sportKey).toList();
  }

  List<Prediction> getRecentPredictions({int limit = 10}) {
    return _predictions.take(limit).toList();
  }

  Future<void> _savePredictions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonData = _predictions.map((p) => p.toJson()).toList();
      await prefs.setString(StorageKeys.predictions, jsonEncode(jsonData));
    } catch (e) {
      debugPrint('Error saving predictions: $e');
    }
  }

  Future<void> clearPredictions() async {
    _predictions.clear();
    _userId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(StorageKeys.predictions);
    notifyListeners();
  }

  /// Clear all user data on logout
  Future<void> clearUserData() async {
    _predictions.clear();
    _userId = null;
    // Also clear local storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(StorageKeys.predictions);
    notifyListeners();
  }

  // Simulate settling predictions (for demo purposes)
  Future<void> simulateSettlement() async {
    final pending = pendingPredictions;
    for (final prediction in pending) {
      // Check if game should have ended
      if (prediction.gameStartTime.isBefore(DateTime.now().subtract(const Duration(hours: 2)))) {
        // Randomly determine win/loss (60% win rate for demo)
        final won = DateTime.now().millisecondsSinceEpoch % 10 < 6;
        await settlePrediction(prediction.id, won);
      }
    }
  }
}
