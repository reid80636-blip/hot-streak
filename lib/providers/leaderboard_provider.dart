import 'package:flutter/foundation.dart';
import '../services/supabase_service.dart';

enum LeaderboardTimeFilter {
  daily,
  weekly,
  allTime,
}

class LeaderboardEntry {
  final int rank;
  final String oderId;
  final String username;
  final String? avatarUrl;
  final int coins;
  final int wins;
  final int totalPredictions;
  final double winRate;
  final List<String> badges;

  const LeaderboardEntry({
    required this.rank,
    required this.oderId,
    required this.username,
    this.avatarUrl,
    required this.coins,
    required this.wins,
    required this.totalPredictions,
    required this.winRate,
    this.badges = const [],
  });
}

class LeaderboardProvider extends ChangeNotifier {
  List<LeaderboardEntry> _entries = [];
  LeaderboardTimeFilter _timeFilter = LeaderboardTimeFilter.weekly;
  String? _sportFilter;
  bool _isLoading = false;

  List<LeaderboardEntry> get entries => _entries;
  LeaderboardTimeFilter get timeFilter => _timeFilter;
  String? get sportFilter => _sportFilter;
  bool get isLoading => _isLoading;

  Future<void> fetchLeaderboard() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Try fetching from Supabase
      final supabaseData = await SupabaseService.getLeaderboard(
        timeFilter: _timeFilter.name,
      );

      if (supabaseData.isNotEmpty) {
        _entries = supabaseData.asMap().entries.map((entry) {
          final index = entry.key;
          final user = entry.value;
          final wins = user['wins'] as int? ?? 0;
          final total = user['total_predictions'] as int? ?? 0;

          return LeaderboardEntry(
            rank: index + 1,
            oderId: user['id'] as String,
            username: user['username'] as String? ?? 'User',
            coins: user['coins'] as int? ?? 0,
            wins: wins,
            totalPredictions: total,
            winRate: total > 0 ? (wins / total) * 100 : 0,
            badges: List<String>.from(user['badges'] ?? []),
          );
        }).toList();

        _isLoading = false;
        notifyListeners();
        return;
      }
    } catch (e) {
      debugPrint('Error fetching leaderboard from Supabase: $e');
    }

    // Fallback to mock data
    _entries = _generateMockLeaderboard();

    _isLoading = false;
    notifyListeners();
  }

  void setTimeFilter(LeaderboardTimeFilter filter) {
    _timeFilter = filter;
    fetchLeaderboard();
  }

  void setSportFilter(String? sportKey) {
    _sportFilter = sportKey;
    fetchLeaderboard();
  }

  List<LeaderboardEntry> _generateMockLeaderboard() {
    final mockUsers = [
      ('BetKing99', 152340, 89, 124, ['streak_master', 'epl_expert']),
      ('SoccerPro', 143200, 82, 115, ['soccer_guru']),
      ('OddsWizard', 138900, 78, 112, ['combo_king']),
      ('WinStreak', 125600, 71, 98, ['hot_hand']),
      ('BetMaster', 118400, 68, 96, []),
      ('PropKing', 112300, 64, 92, ['prop_specialist']),
      ('SharpMoney', 105700, 61, 88, []),
      ('ClutchBets', 98200, 58, 84, ['clutch_performer']),
      ('ValueHunter', 92100, 55, 80, []),
      ('StatGuru', 86500, 52, 76, ['analytics_pro']),
      ('LineMovr', 81200, 49, 72, []),
      ('EdgeFinder', 76800, 47, 70, []),
      ('SmartPick', 72400, 44, 66, []),
      ('BetBrain', 68100, 42, 64, []),
      ('OddsShark', 64300, 40, 62, []),
      ('MoneyMaker', 60500, 38, 60, []),
      ('WinMore', 57200, 36, 58, []),
      ('BetSmart', 54100, 34, 56, []),
      ('PickPro', 51300, 32, 54, []),
      ('CashKing', 48600, 30, 52, []),
    ];

    // Adjust based on time filter
    final multiplier = _timeFilter == LeaderboardTimeFilter.daily
        ? 0.1
        : _timeFilter == LeaderboardTimeFilter.weekly
            ? 0.3
            : 1.0;

    return mockUsers.asMap().entries.map((entry) {
      final index = entry.key;
      final user = entry.value;
      final adjustedCoins = (user.$2 * multiplier).round();
      final adjustedWins = (user.$3 * multiplier).round();
      final adjustedTotal = (user.$4 * multiplier).round();

      return LeaderboardEntry(
        rank: index + 1,
        oderId: 'user_$index',
        username: user.$1,
        coins: adjustedCoins,
        wins: adjustedWins,
        totalPredictions: adjustedTotal,
        winRate: adjustedTotal > 0 ? (adjustedWins / adjustedTotal) * 100 : 0,
        badges: List<String>.from(user.$5),
      );
    }).toList();
  }

  LeaderboardEntry? getUserRank(String oderId) {
    try {
      return _entries.firstWhere((e) => e.oderId == oderId);
    } catch (_) {
      return null;
    }
  }

  bool isInTopPercentile(String oderId, double percentile) {
    final userEntry = getUserRank(oderId);
    if (userEntry == null || _entries.isEmpty) return false;

    final threshold = (_entries.length * percentile).ceil();
    return userEntry.rank <= threshold;
  }
}
