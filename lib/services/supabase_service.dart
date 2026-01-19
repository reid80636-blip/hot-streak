import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/constants.dart';
import '../models/user.dart' as app;
import '../models/prediction.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      anonKey: AppConstants.supabaseAnonKey,
    );
  }

  // Auth methods
  static User? get currentUser => client.auth.currentUser;
  static bool get isLoggedIn => currentUser != null;
  static Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  /// Refresh the session if needed
  /// Returns true if session is valid (either already valid or successfully refreshed)
  static Future<bool> ensureValidSession() async {
    try {
      final session = client.auth.currentSession;
      if (session == null) return false;

      // Check if token is expired or about to expire (within 60 seconds)
      final expiresAt = session.expiresAt;
      if (expiresAt != null) {
        final expiryTime = DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
        final now = DateTime.now();

        // If token expires within 60 seconds, refresh it
        if (expiryTime.difference(now).inSeconds < 60) {
          print('Session expiring soon, refreshing...');
          final response = await client.auth.refreshSession();
          return response.session != null;
        }
      }

      return true;
    } catch (e) {
      print('Error refreshing session: $e');
      // Try to refresh anyway
      try {
        final response = await client.auth.refreshSession();
        return response.session != null;
      } catch (refreshError) {
        print('Failed to refresh session: $refreshError');
        return false;
      }
    }
  }

  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? username,
  }) async {
    final response = await client.auth.signUp(
      email: email,
      password: password,
      data: {'username': username ?? email.split('@').first},
    );
    return response;
  }

  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  /// Sign in with Google OAuth
  /// For web: uses OAuth popup/redirect
  /// Returns true if OAuth flow started successfully
  static Future<bool> signInWithGoogle() async {
    // For web, don't specify redirectTo - Supabase will use the current URL
    final response = await client.auth.signInWithOAuth(
      OAuthProvider.google,
    );
    return response;
  }

  /// Check if user signed in via OAuth (Google, etc.)
  static bool get isOAuthUser {
    final user = currentUser;
    if (user == null) return false;
    return user.appMetadata['provider'] == 'google';
  }

  // User Profile methods
  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    // Ensure session is valid before making request
    final sessionValid = await ensureValidSession();
    if (!sessionValid) {
      print('Warning: Session invalid, profile fetch may fail');
    }

    try {
      final response = await client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      return response;
    } catch (e) {
      print('Error fetching profile: $e');

      // Handle various error types gracefully
      final errorStr = e.toString().toLowerCase();

      // 400 = Bad Request (table might not exist, schema issue)
      // 401 = Unauthorized (auth issue)
      // 404 = Not Found
      // These all mean "no profile available" - return null to trigger local fallback
      if (errorStr.contains('400') ||
          errorStr.contains('401') ||
          errorStr.contains('404') ||
          errorStr.contains('jwt') ||
          errorStr.contains('relation') ||
          errorStr.contains('does not exist')) {
        print('Supabase profile unavailable, using local fallback');
        return null;
      }

      // For other errors, try refresh and retry once
      try {
        await client.auth.refreshSession();
        final retryResponse = await client
            .from('profiles')
            .select()
            .eq('id', userId)
            .maybeSingle();
        return retryResponse;
      } catch (retryError) {
        print('Retry failed: $retryError - using local fallback');
        return null;
      }
    }
  }

  static Future<void> createUserProfile(app.User user) async {
    try {
      // Try upsert first - works if profile doesn't exist or we have permission
      await client.from('profiles').upsert({
        'id': user.id,
        'username': user.username,
        'email': user.email,
        'coins': user.coins,
        'xp': user.xp,
        'level': user.level,
        'total_predictions': user.totalPredictions,
        'wins': user.wins,
        'losses': user.losses,
        'last_daily_bonus': user.lastDailyBonus?.toIso8601String(),
        'badges': user.badges,
        'favorite_teams': user.favoriteTeams,
        'favorite_sports': user.favoriteSports,
        'onboarding_complete': user.onboardingComplete,
        'notifications_enabled': user.notificationsEnabled,
        'created_at': user.createdAt.toIso8601String(),
      });
    } catch (e) {
      // Supabase might not be available or table doesn't exist
      // This is fine - we use local storage as fallback
      print('Supabase createProfile skipped: $e');
    }
  }

  static Future<void> updateUserProfile(app.User user) async {
    try {
      await client.from('profiles').update({
        'username': user.username,
        'coins': user.coins,
        'xp': user.xp,
        'level': user.level,
        'total_predictions': user.totalPredictions,
        'wins': user.wins,
        'losses': user.losses,
        'last_daily_bonus': user.lastDailyBonus?.toIso8601String(),
        'badges': user.badges,
        'favorite_teams': user.favoriteTeams,
        'favorite_sports': user.favoriteSports,
        'onboarding_complete': user.onboardingComplete,
        'notifications_enabled': user.notificationsEnabled,
      }).eq('id', user.id);
    } catch (e) {
      // Supabase might not be available - this is fine, we use local storage
      print('Supabase updateProfile skipped: $e');
    }
  }

  static Future<void> updateCoins(String oderId, int coins) async {
    await client.from('profiles').update({'coins': coins}).eq('id', oderId);
  }

  static Future<void> updateXp(String oderId, int xp, int level) async {
    await client.from('profiles').update({
      'xp': xp,
      'level': level,
    }).eq('id', oderId);
  }

  static Future<void> updateDailyBonus(String oderId, DateTime claimedAt) async {
    await client.from('profiles').update({
      'last_daily_bonus': claimedAt.toIso8601String(),
    }).eq('id', oderId);
  }

  // Predictions methods
  static Future<void> savePrediction(Prediction prediction, String oderId) async {
    await client.from('predictions').insert({
      'id': prediction.id,
      'user_id': oderId,
      'game_id': prediction.gameId,
      'sport_key': prediction.sportKey,
      'home_team': prediction.homeTeam,
      'away_team': prediction.awayTeam,
      'type': prediction.type.name,
      'outcome': prediction.outcome.name,
      'odds': prediction.odds,
      'stake': prediction.stake,
      'line': prediction.line,
      'status': prediction.status.name,
      'game_start_time': prediction.gameStartTime.toIso8601String(),
      'created_at': prediction.createdAt.toIso8601String(),
      'payout': prediction.payout,
      'parlay_id': prediction.parlayId,
      'parlay_legs': prediction.parlayLegs,
    });
  }

  static Future<void> savePredictions(List<Prediction> predictions, String oderId) async {
    final data = predictions.map((p) => {
      'id': p.id,
      'user_id': oderId,
      'game_id': p.gameId,
      'sport_key': p.sportKey,
      'home_team': p.homeTeam,
      'away_team': p.awayTeam,
      'type': p.type.name,
      'outcome': p.outcome.name,
      'odds': p.odds,
      'stake': p.stake,
      'line': p.line,
      'status': p.status.name,
      'game_start_time': p.gameStartTime.toIso8601String(),
      'created_at': p.createdAt.toIso8601String(),
      'payout': p.payout,
      'parlay_id': p.parlayId,
      'parlay_legs': p.parlayLegs,
    }).toList();

    await client.from('predictions').insert(data);
  }

  static Future<List<Map<String, dynamic>>> getUserPredictions(String oderId) async {
    final response = await client
        .from('predictions')
        .select()
        .eq('user_id', oderId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  static Future<void> updatePredictionStatus(
    String predictionId,
    PredictionStatus status,
    int? payout, {
    int? finalHomeScore,
    int? finalAwayScore,
  }) async {
    final updateData = <String, dynamic>{
      'status': status.name,
      'payout': payout,
    };
    if (finalHomeScore != null) {
      updateData['final_home_score'] = finalHomeScore;
    }
    if (finalAwayScore != null) {
      updateData['final_away_score'] = finalAwayScore;
    }
    await client.from('predictions').update(updateData).eq('id', predictionId);
  }

  // Leaderboard methods
  static Future<List<Map<String, dynamic>>> getLeaderboard({
    String? timeFilter,
    int limit = 100,
  }) async {
    var query = client
        .from('profiles')
        .select('id, username, coins, wins, total_predictions, badges')
        .order('coins', ascending: false)
        .limit(limit);

    final response = await query;
    return List<Map<String, dynamic>>.from(response);
  }

  // Collectibles methods
  static Future<void> saveCollectible(Map<String, dynamic> collectible, String oderId) async {
    await client.from('collectibles').insert({
      ...collectible,
      'user_id': oderId,
    });
  }

  static Future<List<Map<String, dynamic>>> getUserCollectibles(String oderId) async {
    final response = await client
        .from('collectibles')
        .select()
        .eq('user_id', oderId)
        .order('earned_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }
}
