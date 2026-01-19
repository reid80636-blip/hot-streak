import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/prediction.dart';
import '../models/game.dart';
import '../config/constants.dart';

class BetSlipProvider extends ChangeNotifier {
  final List<BetSlipItem> _items = [];
  bool _isCombo = false;

  List<BetSlipItem> get items => List.unmodifiable(_items);
  bool get isCombo => _isCombo;
  bool get isEmpty => _items.isEmpty;
  int get itemCount => _items.length;

  int get totalStake {
    if (_isCombo) {
      // For combos, use the first item's stake as the combo stake
      return _items.isNotEmpty ? _items.first.stake : 0;
    }
    return _items.fold(0, (sum, item) => sum + item.stake);
  }

  double get comboOdds {
    if (_items.isEmpty) return 1.0;
    return _items.fold(1.0, (product, item) => product * item.odds);
  }

  double get comboMultiplier {
    if (!_isCombo || _items.length < 2) return 1.0;
    return AppConstants.comboMultipliers[_items.length] ?? 1.0;
  }

  int get totalPotentialPayout {
    if (_isCombo && _items.isNotEmpty) {
      final comboStake = _items.first.stake;
      return (comboStake * comboOdds * comboMultiplier).round();
    }
    return _items.fold(0, (sum, item) => sum + item.potentialPayout);
  }

  bool hasItem(String gameId, PredictionType type, PredictionOutcome outcome) {
    return _items.any((item) =>
        item.gameId == gameId && item.type == type && item.outcome == outcome);
  }

  bool hasGamePrediction(String gameId, PredictionType type) {
    return _items.any((item) => item.gameId == gameId && item.type == type);
  }

  void addItem(Game game, PredictionType type, PredictionOutcome outcome, double odds, {double? line}) {
    // Remove any existing prediction of the same type for this game
    _items.removeWhere((item) => item.gameId == game.id && item.type == type);

    _items.add(BetSlipItem(
      gameId: game.id,
      sportKey: game.sportKey,
      homeTeam: game.homeTeam.name,
      awayTeam: game.awayTeam.name,
      type: type,
      outcome: outcome,
      odds: odds,
      line: line,
      gameStartTime: game.startTime,
    ));

    // Auto-enable combo/parlay when 2+ items
    if (_items.length >= 2) {
      _isCombo = true;
    }

    notifyListeners();
  }

  void removeItem(int index) {
    if (index >= 0 && index < _items.length) {
      _items.removeAt(index);

      // Disable combo if less than 2 items
      if (_items.length < 2) {
        _isCombo = false;
      }

      notifyListeners();
    }
  }

  void removeItemByGame(String gameId, PredictionType type, PredictionOutcome outcome) {
    _items.removeWhere((item) =>
        item.gameId == gameId && item.type == type && item.outcome == outcome);

    if (_items.length < 2) {
      _isCombo = false;
    }

    notifyListeners();
  }

  void updateStake(int index, int stake) {
    if (index >= 0 && index < _items.length) {
      final clampedStake = stake.clamp(
        AppConstants.minBetAmount,
        AppConstants.maxBetAmount,
      );
      _items[index].stake = clampedStake;
      notifyListeners();
    }
  }

  void setComboStake(int stake) {
    if (_items.isEmpty) return;
    final clampedStake = stake.clamp(
      AppConstants.minBetAmount,
      AppConstants.maxBetAmount,
    );
    for (final item in _items) {
      item.stake = clampedStake;
    }
    notifyListeners();
  }

  void toggleCombo() {
    if (_items.length >= 2) {
      _isCombo = !_isCombo;
      notifyListeners();
    }
  }

  void setCombo(bool value) {
    if (value && _items.length < 2) return;
    _isCombo = value;
    notifyListeners();
  }

  List<Prediction> createPredictions() {
    final predictions = <Prediction>[];
    const uuid = Uuid();
    final parlayId = _isCombo ? uuid.v4() : null;

    for (final item in _items) {
      predictions.add(Prediction(
        id: uuid.v4(),
        gameId: item.gameId,
        sportKey: item.sportKey,
        homeTeam: item.homeTeam,
        awayTeam: item.awayTeam,
        type: item.type,
        outcome: item.outcome,
        odds: _isCombo ? comboOdds : item.odds,
        stake: _isCombo ? _items.first.stake : item.stake,
        line: item.line,
        gameStartTime: item.gameStartTime,
        parlayId: parlayId,
        parlayLegs: _isCombo ? _items.length : null,
      ));
    }

    return predictions;
  }

  void clear() {
    _items.clear();
    _isCombo = false;
    notifyListeners();
  }
}
