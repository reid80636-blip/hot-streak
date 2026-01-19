import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../config/routes.dart';

/// Navigation bar for popups/modals that allows quick navigation to main tabs
/// Automatically closes the popup when a tab is selected
class PopupNavBar extends StatelessWidget {
  const PopupNavBar({super.key});

  void _navigateTo(BuildContext context, String targetRoute) {
    debugPrint('PopupNavBar: Navigating to $targetRoute');
    HapticFeedback.lightImpact();

    // Close the modal and navigate
    Navigator.of(context).pop();
    context.go(targetRoute);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavButton(
            context,
            icon: Icons.home_rounded,
            label: 'Home',
            route: AppRoutes.home,
          ),
          _buildNavButton(
            context,
            icon: Icons.sports_rounded,
            label: 'Games',
            route: AppRoutes.games,
          ),
          _buildNavButton(
            context,
            icon: Icons.receipt_long_rounded,
            label: 'Picks',
            route: AppRoutes.predictions,
          ),
          _buildNavButton(
            context,
            icon: Icons.scoreboard_rounded,
            label: 'Live',
            route: AppRoutes.live,
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String route,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _navigateTo(context, route),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: AppColors.textSecondary,
                size: 18,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
