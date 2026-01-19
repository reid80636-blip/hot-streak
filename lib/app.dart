import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'config/theme.dart';
import 'config/routes.dart';
import 'providers/auth_provider.dart';
import 'providers/games_provider.dart';
import 'providers/bet_slip_provider.dart';
import 'providers/predictions_provider.dart';
import 'providers/leaderboard_provider.dart';
import 'providers/suggestions_provider.dart';
import 'providers/live_scores_provider.dart';
import 'providers/feed_provider.dart';

class HotStreakApp extends StatefulWidget {
  const HotStreakApp({super.key});

  @override
  State<HotStreakApp> createState() => _HotStreakAppState();
}

class _HotStreakAppState extends State<HotStreakApp> {
  late GoRouter _router;
  bool _routerInitialized = false;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => GamesProvider()),
        ChangeNotifierProvider(create: (_) => BetSlipProvider()),
        ChangeNotifierProvider(create: (_) => PredictionsProvider()),
        ChangeNotifierProvider(create: (_) => LeaderboardProvider()),
        ChangeNotifierProvider(create: (_) => SuggestionsProvider()),
        ChangeNotifierProvider(create: (_) => LiveScoresProvider()),
        ChangeNotifierProvider(create: (_) => FeedProvider()),
      ],
      child: Consumer2<AuthProvider, PredictionsProvider>(
        builder: (context, auth, predictions, child) {
          // Connect XP awarding callback from predictions settlement
          predictions.onSettlementCallback = (won, betCount, isParlay) async {
            await auth.awardXpForSettlement(
              won: won,
              betCount: betCount,
              isParlay: isParlay,
            );
            // Also update user stats
            await auth.recordPredictionResult(won);
          };

          // Only create router once, refreshListenable handles auth changes
          if (!_routerInitialized) {
            _router = createRouter(authProvider: auth);
            _routerInitialized = true;
          }

          return MaterialApp.router(
            title: 'HotStreak',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.darkTheme,
            routerConfig: _router,
          );
        },
      ),
    );
  }
}
