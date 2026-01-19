import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../models/user.dart';
import '../config/constants.dart';
import '../services/supabase_service.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  bool _onboardingComplete = false;
  String? _error;

  User? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get isLoading => _isLoading;
  bool get onboardingComplete => _onboardingComplete;
  String? get error => _error;

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    _onboardingComplete = prefs.getBool(StorageKeys.onboardingComplete) ?? false;

    // Check if user is logged in via Supabase
    final supabaseUser = SupabaseService.currentUser;
    if (supabaseUser != null) {
      // Try to refresh the session (but don't fail if it doesn't work)
      try {
        await SupabaseService.ensureValidSession();
      } catch (e) {
        debugPrint('Session refresh warning: $e');
      }

      // Handle OAuth callback (creates profile if new Google user)
      // This will fall back to local/auth data if Supabase profile fetch fails
      await handleOAuthCallback();
    } else {
      // Fallback to local storage
      final userJson = prefs.getString(StorageKeys.user);
      if (userJson != null) {
        try {
          _user = User.fromJsonString(userJson);
        } catch (e) {
          debugPrint('Error loading user: $e');
        }
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadUserProfile(String userId) async {
    try {
      final profile = await SupabaseService.getUserProfile(userId);
      if (profile != null) {
        final favoriteTeams = (profile['favorite_teams'] as List<dynamic>?)?.cast<String>() ?? [];
        final favoriteSports = (profile['favorite_sports'] as List<dynamic>?)?.cast<String>() ?? [];
        final notificationsEnabled = profile['notifications_enabled'] as bool? ?? true;

        _user = User(
          id: profile['id'] as String,
          username: profile['username'] as String? ?? 'User',
          email: profile['email'] as String? ?? '',
          coins: profile['coins'] as int? ?? AppConstants.startingCoins,
          xp: profile['xp'] as int? ?? 0,
          level: profile['level'] as int? ?? 1,
          totalPredictions: profile['total_predictions'] as int? ?? 0,
          wins: profile['wins'] as int? ?? 0,
          losses: profile['losses'] as int? ?? 0,
          lastDailyBonus: profile['last_daily_bonus'] != null
              ? DateTime.parse(profile['last_daily_bonus'] as String)
              : null,
          badges: (profile['badges'] as List<dynamic>?)?.cast<String>() ?? [],
          favoriteTeams: favoriteTeams,
          favoriteSports: favoriteSports,
          onboardingComplete: profile['onboarding_complete'] as bool? ?? false,
          notificationsEnabled: notificationsEnabled,
          createdAt: profile['created_at'] != null
              ? DateTime.parse(profile['created_at'] as String)
              : DateTime.now(),
        );
        await _saveUserLocally();
        return;
      }
    } catch (e) {
      debugPrint('Error loading user profile from Supabase: $e');
    }

    // Fallback: create user from Supabase auth data if profile fetch failed
    await _createUserFromAuthData(userId);
  }

  Future<void> _createUserFromAuthData(String userId) async {
    final supabaseUser = SupabaseService.currentUser;
    if (supabaseUser == null) return;

    // Try to load from local storage first
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(StorageKeys.user);
    if (userJson != null) {
      try {
        final localUser = User.fromJsonString(userJson);
        // Only use local if ID matches
        if (localUser.id == userId) {
          _user = localUser;
          return;
        }
      } catch (e) {
        debugPrint('Error loading local user: $e');
      }
    }

    // Create new user from auth metadata
    final metadata = supabaseUser.userMetadata ?? {};
    final email = supabaseUser.email ?? '';
    final username = metadata['username'] as String? ??
        metadata['full_name'] as String? ??
        metadata['name'] as String? ??
        email.split('@').first;

    _user = User(
      id: userId,
      username: username,
      email: email,
      coins: AppConstants.startingCoins,
      xp: 0,
      level: 1,
      totalPredictions: 0,
      wins: 0,
      losses: 0,
      badges: [],
      favoriteTeams: [],
      favoriteSports: [],
      onboardingComplete: false,
      notificationsEnabled: true,
      createdAt: DateTime.now(),
    );
    await _saveUserLocally();
    debugPrint('Created fallback user from auth data');
  }

  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(StorageKeys.onboardingComplete, true);
    _onboardingComplete = true;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await SupabaseService.signIn(
        email: email,
        password: password,
      );

      if (response.user != null) {
        await _loadUserProfile(response.user!.id);
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } on AuthException catch (e) {
      debugPrint('Auth error: ${e.message}');
      _error = e.message;

      // If user doesn't exist, create account automatically (for demo)
      if (e.message.contains('Invalid login credentials')) {
        return await register(email.split('@').first, email, password);
      }
    } catch (e) {
      debugPrint('Login error: $e');
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Sign in with Google OAuth
  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final success = await SupabaseService.signInWithGoogle();

      if (success) {
        // OAuth redirects the browser, so we return true
        // The actual user loading happens when the page reloads
        // after OAuth callback via init()
        return true;
      }
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      _error = 'Failed to sign in with Google';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Handle OAuth callback - create profile if new user
  Future<void> handleOAuthCallback() async {
    final supabaseUser = SupabaseService.currentUser;
    if (supabaseUser == null) return;

    // Try to load/check profile - handles errors gracefully with fallback
    try {
      final profile = await SupabaseService.getUserProfile(supabaseUser.id);

      if (profile == null) {
        // New user (OAuth or profile not found) - check local first
        final prefs = await SharedPreferences.getInstance();
        final localJson = prefs.getString(StorageKeys.user);

        if (localJson != null) {
          try {
            final localUser = User.fromJsonString(localJson);
            if (localUser.id == supabaseUser.id) {
              _user = localUser;
              debugPrint('Loaded existing local user');
              notifyListeners();
              return;
            }
          } catch (e) {
            debugPrint('Error parsing local user: $e');
          }
        }

        // New OAuth user - create profile with onboardingComplete: false
        final username = supabaseUser.userMetadata?['full_name'] ??
                        supabaseUser.userMetadata?['name'] ??
                        supabaseUser.email?.split('@').first ??
                        'User';

        _user = User(
          id: supabaseUser.id,
          username: username,
          email: supabaseUser.email ?? '',
          coins: AppConstants.startingCoins,
          xp: 0,
          level: 1,
          totalPredictions: 0,
          wins: 0,
          losses: 0,
          badges: [],
          favoriteTeams: [],
          favoriteSports: [],
          onboardingComplete: false, // NEW USER - needs onboarding
          notificationsEnabled: true,
          createdAt: DateTime.now(),
        );

        await _saveUserLocally();
        await SupabaseService.createUserProfile(_user!);
        debugPrint('Created new user - needs onboarding');
      } else {
        await _loadUserProfile(supabaseUser.id);
      }
    } catch (e) {
      debugPrint('Error in handleOAuthCallback: $e');
      // Fallback to local/auth data
      await _createUserFromAuthData(supabaseUser.id);
    }

    notifyListeners();
  }

  Future<bool> register(String username, String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await SupabaseService.signUp(
        email: email,
        password: password,
        username: username,
      );

      if (response.user != null) {
        // Create new user profile with onboardingComplete: false
        _user = User(
          id: response.user!.id,
          username: username,
          email: email,
          coins: AppConstants.startingCoins,
          xp: 0,
          level: 1,
          totalPredictions: 0,
          wins: 0,
          losses: 0,
          badges: [],
          favoriteTeams: [],
          favoriteSports: [],
          onboardingComplete: false, // NEW USER - needs onboarding
          notificationsEnabled: true,
          createdAt: DateTime.now(),
        );

        // Save locally first (always works)
        await _saveUserLocally();
        // Try to save to Supabase (may fail, that's ok)
        await SupabaseService.createUserProfile(_user!);

        debugPrint('Registered new user - needs onboarding');
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } on AuthException catch (e) {
      debugPrint('Auth error: ${e.message}');
      _error = e.message;
    } catch (e) {
      debugPrint('Register error: $e');
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    try {
      await SupabaseService.signOut();
    } catch (e) {
      debugPrint('Logout error: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(StorageKeys.user);
    _user = null;
    notifyListeners();
  }

  Future<void> updateUser(User updatedUser) async {
    _user = updatedUser;
    await _saveUser();
    notifyListeners();
  }

  Future<void> addCoins(int amount) async {
    if (_user == null) return;
    _user = _user!.copyWith(coins: _user!.coins + amount);
    await _saveUser();
    notifyListeners();
  }

  Future<void> removeCoins(int amount) async {
    if (_user == null) return;
    if (_user!.coins < amount) return;
    _user = _user!.copyWith(coins: _user!.coins - amount);
    await _saveUser();
    notifyListeners();
  }

  Future<void> addXp(int amount) async {
    if (_user == null) return;

    var newXp = _user!.xp + amount;
    var newLevel = _user!.level;

    // Level up logic
    while (newXp >= newLevel * 1000) {
      newXp -= newLevel * 1000;
      newLevel++;
    }

    _user = _user!.copyWith(xp: newXp, level: newLevel);
    await _saveUser();
    notifyListeners();
  }

  Future<bool> claimDailyBonus() async {
    if (_user == null) return false;
    if (!_user!.canClaimDailyBonus) return false;

    final now = DateTime.now();
    _user = _user!.copyWith(
      coins: _user!.coins + AppConstants.dailyBonusCoins,
      lastDailyBonus: now,
    );

    await _saveUser();

    // Update in Supabase
    try {
      await SupabaseService.updateDailyBonus(_user!.id, now);
    } catch (e) {
      debugPrint('Error updating daily bonus in Supabase: $e');
    }

    notifyListeners();
    return true;
  }

  /// Claim daily bonus with a custom coin amount (used by spin wheel)
  Future<bool> claimDailyBonusWithAmount(int coins) async {
    if (_user == null) return false;
    if (!_user!.canClaimDailyBonus) return false;

    final now = DateTime.now();
    _user = _user!.copyWith(
      coins: _user!.coins + coins,
      lastDailyBonus: now,
    );

    await _saveUser();

    // Update in Supabase
    try {
      await SupabaseService.updateDailyBonus(_user!.id, now);
    } catch (e) {
      debugPrint('Error updating daily bonus in Supabase: $e');
    }

    notifyListeners();
    return true;
  }

  Future<void> recordPredictionResult(bool won) async {
    if (_user == null) return;

    _user = _user!.copyWith(
      totalPredictions: _user!.totalPredictions + 1,
      wins: won ? _user!.wins + 1 : _user!.wins,
      losses: won ? _user!.losses : _user!.losses + 1,
    );

    // Add XP for predictions
    await addXp(won ? 50 : 10);
    await _saveUser();
    notifyListeners();
  }

  /// Update user's favorite teams and mark onboarding complete
  Future<void> setFavoriteTeams(List<String> teams) async {
    if (_user == null) return;

    _user = _user!.copyWith(
      favoriteTeams: teams,
      onboardingComplete: true,
    );

    await _saveUser();
    notifyListeners();
  }

  /// Update only favorite teams (for settings)
  Future<void> updateFavoriteTeams(List<String> teams) async {
    if (_user == null) return;

    _user = _user!.copyWith(favoriteTeams: teams);
    await _saveUser();
    notifyListeners();
  }

  /// Set user's favorite sports
  Future<void> setFavoriteSports(List<String> sports) async {
    if (_user == null) return;

    _user = _user!.copyWith(favoriteSports: sports);
    await _saveUser();
    notifyListeners();
  }

  /// Update favorite sports (for settings)
  Future<void> updateFavoriteSports(List<String> sports) async {
    if (_user == null) return;

    _user = _user!.copyWith(favoriteSports: sports);
    await _saveUser();
    notifyListeners();
  }

  /// Complete onboarding with both sports and teams
  Future<void> completeOnboardingWithPreferences({
    required List<String> sports,
    required List<String> teams,
  }) async {
    if (_user == null) return;

    _user = _user!.copyWith(
      favoriteSports: sports,
      favoriteTeams: teams,
      onboardingComplete: true,
    );

    await _saveUser();
    notifyListeners();
  }

  /// Toggle notifications on/off
  Future<void> setNotificationsEnabled(bool enabled) async {
    if (_user == null) return;

    _user = _user!.copyWith(notificationsEnabled: enabled);
    await _saveUser();
    notifyListeners();
  }

  /// Update username
  Future<void> updateUsername(String username) async {
    if (_user == null) return;

    _user = _user!.copyWith(username: username);
    await _saveUser();
    notifyListeners();
  }

  /// Update default stake amount
  Future<void> setDefaultStake(int stake) async {
    if (_user == null) return;

    _user = _user!.copyWith(defaultStake: stake);
    await _saveUser();
    notifyListeners();
  }

  /// Award XP for placing a bet
  Future<void> awardXpForBet({int betCount = 1, bool isParlay = false}) async {
    if (_user == null) return;

    // Base XP for placing a bet
    int xpAmount = 10 * betCount;

    // Bonus for parlay bets
    if (isParlay) {
      xpAmount += 15;
    }

    await addXp(xpAmount);
  }

  /// Award XP for bet settlement
  Future<void> awardXpForSettlement({required bool won, int betCount = 1, bool isParlay = false}) async {
    if (_user == null) return;

    int xpAmount;
    if (won) {
      // More XP for wins
      xpAmount = 50 * betCount;
      if (isParlay) {
        xpAmount += 50; // Big bonus for parlay wins
      }
    } else {
      // Small consolation XP for losses
      xpAmount = 5 * betCount;
    }

    await addXp(xpAmount);
  }

  /// Check if user needs onboarding (sports + teams selection)
  bool get needsOnboarding {
    return _user != null && !_user!.onboardingComplete;
  }

  /// Legacy alias for needsOnboarding
  bool get needsTeamOnboarding => needsOnboarding;

  Future<void> _saveUser() async {
    if (_user == null) return;

    // Save locally
    await _saveUserLocally();

    // Save to Supabase
    try {
      await SupabaseService.updateUserProfile(_user!);
    } catch (e) {
      debugPrint('Error saving user to Supabase: $e');
    }
  }

  Future<void> _saveUserLocally() async {
    if (_user == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageKeys.user, _user!.toJsonString());
  }
}
