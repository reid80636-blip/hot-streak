import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../providers/auth_provider.dart';
import '../../providers/predictions_provider.dart';
import '../../providers/suggestions_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Defer initialization to after the build phase
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initAndNavigate();
    });
  }

  Future<void> _initAndNavigate() async {
    if (!mounted) return;

    final authProvider = context.read<AuthProvider>();
    final predictionsProvider = context.read<PredictionsProvider>();
    final suggestionsProvider = context.read<SuggestionsProvider>();

    // Check if already logged in via Supabase session
    await authProvider.init();

    if (!mounted) return;

    // If already logged in, load user-specific data
    if (authProvider.isLoggedIn && authProvider.user != null) {
      // Set user ID and load their predictions
      predictionsProvider.setUserId(authProvider.user!.id);
      await predictionsProvider.loadPredictions();

      // Set followed teams/sports for suggestions
      suggestionsProvider.setFollowedTeams(authProvider.user!.favoriteTeams);
      suggestionsProvider.setFollowedSports(authProvider.user!.favoriteSports);

      if (!mounted) return;

      // Check if new user needs onboarding (feature pages → sports → teams)
      if (authProvider.needsOnboarding) {
        debugPrint('New user detected - redirecting to onboarding intro');
        context.go(AppRoutes.onboardingIntro);
        return;
      }

      context.go(AppRoutes.home);
      return;
    }

    // Wait for animation only if not logged in
    await Future.delayed(const Duration(milliseconds: 2000));

    if (!mounted) return;

    // Go directly to login (skip onboarding)
    context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo/Icon
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withOpacity(0.4),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.local_fire_department,
                color: Colors.white,
                size: 60,
              ),
            )
                .animate()
                .scale(
                  begin: const Offset(0.5, 0.5),
                  end: const Offset(1, 1),
                  duration: 600.ms,
                  curve: Curves.elasticOut,
                )
                .fadeIn(duration: 400.ms),

            const SizedBox(height: 24),

            // App name
            const Text(
              'HotStreak',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 36,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            )
                .animate(delay: 300.ms)
                .fadeIn(duration: 400.ms)
                .slideY(begin: 0.3, end: 0, duration: 400.ms),

            const SizedBox(height: 8),

            // Tagline
            const Text(
              'Predict. Win. Dominate.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
                letterSpacing: 0.5,
              ),
            ).animate(delay: 500.ms).fadeIn(duration: 400.ms),

            const SizedBox(height: 60),

            // Loading indicator
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.accent.withOpacity(0.7),
                ),
              ),
            ).animate(delay: 800.ms).fadeIn(duration: 400.ms),
          ],
        ),
      ),
    );
  }
}
