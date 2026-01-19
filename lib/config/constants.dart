class AppConstants {
  // App Info
  static const String appName = 'HotStreak';
  static const String appVersion = '1.0.0';

  // API Keys
  static const String oddsApiKey = '2558c3fad4c18889eba912d4f75524dc';
  static const String oddsApiBaseUrl = 'https://api.the-odds-api.com/v4';

  // Supabase Configuration
  static const String supabaseUrl = 'https://egdsonwgwoghxpdfzapl.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVnZHNvbndnd29naHhwZGZ6YXBsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgzNDUyMDAsImV4cCI6MjA4MzkyMTIwMH0.wd4pdOa-dRgUls-K4_g9Mo9TGnjRPqbhXghYlgw1VpI';

  // Default Values
  static const int startingCoins = 10000;
  static const int dailyBonusCoins = 500;
  static const int questBonusCoins = 100;

  // Bet Limits
  static const int minBetAmount = 10;
  static const int maxBetAmount = 10000;

  // Combo Multipliers
  static const Map<int, double> comboMultipliers = {
    2: 2.0,
    3: 3.5,
    4: 5.0,
    5: 8.0,
    6: 12.0,
    7: 18.0,
    8: 25.0,
  };

  // Sport Keys (The Odds API)
  static const Map<String, String> sportKeys = {
    'soccer_epl': 'English Premier League',
    'soccer_spain_la_liga': 'La Liga',
    'soccer_uefa_champs_league': 'Champions League',
    'soccer_usa_mls': 'MLS',
    'americanfootball_nfl': 'NFL',
    'basketball_nba': 'NBA',
    'americanfootball_ncaaf': 'NCAAF',
    'basketball_ncaab': 'NCAAB',
  };

  // Sport Display Order
  static const List<String> sportOrder = [
    'soccer_epl',
    'soccer_spain_la_liga',
    'soccer_uefa_champs_league',
    'soccer_usa_mls',
    'americanfootball_nfl',
    'basketball_nba',
    'americanfootball_ncaaf',
    'basketball_ncaab',
  ];

  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 400);
  static const Duration longAnimation = Duration(milliseconds: 600);

  // Cache Duration
  static const Duration cacheExpiry = Duration(minutes: 5);

  // Leaderboard
  static const int leaderboardTopCount = 100;
  static const double topPercentileForCollectible = 0.05; // Top 5%
}

class StorageKeys {
  static const String user = 'user';
  static const String coinBalance = 'coin_balance';
  static const String lastDailyBonus = 'last_daily_bonus';
  static const String onboardingComplete = 'onboarding_complete';
  static const String predictions = 'predictions';
  static const String collectibles = 'collectibles';
  static const String cachedGames = 'cached_games';
}
