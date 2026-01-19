import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/onboarding/onboarding_intro.dart';
import '../screens/onboarding/preferences_flow.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/games/games_list_screen.dart';
import '../screens/games/game_detail_screen.dart';
import '../screens/predictions/bet_slip_screen.dart';
import '../screens/predictions/my_predictions_screen.dart';
import '../screens/live/live_scores_screen.dart';
import '../screens/feed/feed_screen.dart';
import '../screens/leaderboard/leaderboard_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/wallet/wallet_screen.dart';
import '../screens/collectibles/collectibles_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../widgets/common/main_scaffold.dart';

class AppRoutes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String onboardingIntro = '/onboarding-intro';
  static const String teamSelection = '/team-selection';
  static const String teamSelectionSettings = '/team-selection-settings';
  static const String onboardingFlow = '/onboarding-flow';
  static const String onboardingFlowSettings = '/onboarding-flow-settings';
  static const String welcomeOnboarding = '/welcome';
  static const String preferencesFlow = '/preferences';
  static const String preferencesFlowSettings = '/preferences-settings';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String games = '/games';
  static const String gameDetail = '/games/:id';
  static const String betSlip = '/bet-slip';
  static const String predictions = '/predictions';
  static const String live = '/live';
  static const String feed = '/feed';
  static const String leaderboard = '/leaderboard';
  static const String profile = '/profile';
  static const String wallet = '/wallet';
  static const String collectibles = '/collectibles';
  static const String settings = '/settings';
}

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createRouter({required AuthProvider authProvider}) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    refreshListenable: authProvider,
    routes: [
      // Splash screen
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),

      // Onboarding
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),

      // Onboarding Intro (4 feature pages before preferences)
      GoRoute(
        path: AppRoutes.onboardingIntro,
        builder: (context, state) => const OnboardingIntro(),
      ),

      // OLD ROUTES - Redirect to new Onboarding Intro
      GoRoute(
        path: AppRoutes.teamSelection,
        redirect: (context, state) => AppRoutes.onboardingIntro,
      ),
      GoRoute(
        path: AppRoutes.teamSelectionSettings,
        redirect: (context, state) => AppRoutes.preferencesFlowSettings,
      ),
      GoRoute(
        path: AppRoutes.onboardingFlow,
        redirect: (context, state) => AppRoutes.onboardingIntro,
      ),
      GoRoute(
        path: AppRoutes.onboardingFlowSettings,
        redirect: (context, state) => AppRoutes.preferencesFlowSettings,
      ),
      GoRoute(
        path: AppRoutes.welcomeOnboarding,
        redirect: (context, state) => AppRoutes.onboardingIntro,
      ),

      // Preferences Flow (Sports → Teams) for new accounts
      GoRoute(
        path: AppRoutes.preferencesFlow,
        builder: (context, state) => const PreferencesFlow(
          mode: PreferencesMode.onboarding,
        ),
      ),

      // Preferences Flow (Sports → Teams) from settings
      GoRoute(
        path: AppRoutes.preferencesFlowSettings,
        builder: (context, state) => const PreferencesFlow(
          mode: PreferencesMode.settings,
        ),
      ),

      // Auth routes
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),

      // Main app with bottom navigation
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => MainScaffold(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HomeScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.games,
            pageBuilder: (context, state) {
              final sportKey = state.uri.queryParameters['sport'];
              return NoTransitionPage(
                child: GamesListScreen(initialSportKey: sportKey),
              );
            },
          ),
          GoRoute(
            path: AppRoutes.predictions,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: MyPredictionsScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.live,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: LiveScoresScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.feed,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: FeedScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.leaderboard,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: LeaderboardScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.profile,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ProfileScreen(),
            ),
          ),
        ],
      ),

      // Full-screen routes
      GoRoute(
        path: AppRoutes.gameDetail,
        builder: (context, state) {
          final gameId = state.pathParameters['id']!;
          return GameDetailScreen(gameId: gameId);
        },
      ),
      GoRoute(
        path: AppRoutes.betSlip,
        builder: (context, state) => const BetSlipScreen(),
      ),
      GoRoute(
        path: AppRoutes.wallet,
        builder: (context, state) => const WalletScreen(),
      ),
      GoRoute(
        path: AppRoutes.collectibles,
        builder: (context, state) => const CollectiblesScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
    redirect: (context, state) {
      final path = state.uri.path;

      // Access LIVE values from authProvider
      final isLoggedIn = authProvider.isLoggedIn;

      // Allow splash to always show first
      if (path == AppRoutes.splash) return null;

      // Allow onboarding screens for logged in users
      if (path == AppRoutes.onboardingIntro ||
          path == AppRoutes.teamSelection ||
          path == AppRoutes.teamSelectionSettings ||
          path == AppRoutes.onboardingFlow ||
          path == AppRoutes.onboardingFlowSettings ||
          path == AppRoutes.welcomeOnboarding ||
          path == AppRoutes.preferencesFlow ||
          path == AppRoutes.preferencesFlowSettings) {
        if (!isLoggedIn) return AppRoutes.login;
        return null;
      }

      // Skip onboarding - go straight to login if not logged in
      if (!isLoggedIn &&
          path != AppRoutes.login &&
          path != AppRoutes.register) {
        return AppRoutes.login;
      }

      // Check if user needs onboarding (new user who hasn't completed setup)
      final needsOnboarding = authProvider.needsOnboarding;
      if (isLoggedIn && needsOnboarding && path == AppRoutes.home) {
        return AppRoutes.onboardingIntro;
      }

      // Redirect logged in users away from auth screens - go directly to home (or onboarding)
      if (isLoggedIn && (path == AppRoutes.login || path == AppRoutes.register || path == AppRoutes.onboarding)) {
        return needsOnboarding ? AppRoutes.onboardingIntro : AppRoutes.home;
      }

      return null;
    },
  );
}
