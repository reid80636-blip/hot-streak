import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../config/design_system.dart';
import '../../config/routes.dart';
import '../../providers/bet_slip_provider.dart';

class MainScaffold extends StatelessWidget {
  final Widget child;

  const MainScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primaryDark,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Scaffold(
            backgroundColor: AppColors.primaryDark,
            body: child,
            bottomNavigationBar: const _BottomNavBar(),
            floatingActionButton: const _BetSlipFAB(),
            floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
          ),
        ),
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar();

  int _getCurrentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/games')) return 1;
    if (location.startsWith('/live')) return 3;
    if (location.startsWith('/feed')) return 4;
    if (location.startsWith('/predictions')) return 5;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _getCurrentIndex(context);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.glassBackground(0.8),
        border: Border(
          top: BorderSide(
            color: AppColors.borderGlow,
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.cyanGlow,
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Home',
                isActive: currentIndex == 0,
                onTap: () => context.go(AppRoutes.home),
              ),
              _NavItem(
                icon: Icons.sports_outlined,
                activeIcon: Icons.sports_rounded,
                label: 'Games',
                isActive: currentIndex == 1,
                onTap: () => context.go(AppRoutes.games),
              ),
              const SizedBox(width: 56), // Space for FAB
              _NavItem(
                icon: Icons.live_tv_outlined,
                activeIcon: Icons.live_tv_rounded,
                label: 'Live',
                isActive: currentIndex == 3,
                onTap: () => context.go(AppRoutes.live),
              ),
              _NavItem(
                icon: Icons.dynamic_feed_outlined,
                activeIcon: Icons.dynamic_feed_rounded,
                label: 'Feed',
                isActive: currentIndex == 4,
                onTap: () => context.go(AppRoutes.feed),
              ),
              _NavItem(
                icon: Icons.receipt_long_outlined,
                activeIcon: Icons.receipt_long_rounded,
                label: 'My Picks',
                isActive: currentIndex == 5,
                onTap: () => context.go(AppRoutes.predictions),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xs),
              decoration: isActive
                  ? BoxDecoration(
                      color: AppColors.accentCyan.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    )
                  : null,
              child: Icon(
                isActive ? activeIcon : icon,
                color: isActive ? AppColors.accentCyan : AppColors.textSubtle,
                size: 22,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive ? AppColors.accentCyan : AppColors.textSubtle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BetSlipFAB extends StatelessWidget {
  const _BetSlipFAB();

  @override
  Widget build(BuildContext context) {
    return Consumer<BetSlipProvider>(
      builder: (context, betSlip, child) {
        final hasItems = betSlip.itemCount > 0;

        return GestureDetector(
          onTap: () => context.push(AppRoutes.betSlip),
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.accentCyan.withOpacity(0.5),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryGlow,
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: AppColors.cyanGlow,
                  blurRadius: 30,
                  spreadRadius: -5,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  hasItems ? Icons.receipt_rounded : Icons.receipt_outlined,
                  color: Colors.white,
                  size: 28,
                ),
                if (hasItems)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        gradient: AppColors.liveGradient,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primaryDark,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.liveGlow,
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Text(
                        '${betSlip.itemCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
