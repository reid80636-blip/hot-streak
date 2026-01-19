import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../config/theme.dart';
import '../../models/sport.dart';
import '../../widgets/onboarding/sport_card.dart';

/// Step 1 of onboarding: Select favorite sports
/// Features premium styling with gradient backgrounds, animated progress, and polished UI
class SportSelectionScreen extends StatefulWidget {
  final Set<String> initialSelection;
  final ValueChanged<Set<String>> onSelectionChanged;
  final VoidCallback onNext;
  final VoidCallback? onSkip;
  final bool isSettingsMode;

  const SportSelectionScreen({
    super.key,
    required this.initialSelection,
    required this.onSelectionChanged,
    required this.onNext,
    this.onSkip,
    this.isSettingsMode = false,
  });

  @override
  State<SportSelectionScreen> createState() => _SportSelectionScreenState();
}

class _SportSelectionScreenState extends State<SportSelectionScreen>
    with SingleTickerProviderStateMixin {
  late Set<String> _selectedSports;
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _selectedSports = Set.from(widget.initialSelection);
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  void _toggleSport(String sportKey) {
    setState(() {
      if (_selectedSports.contains(sportKey)) {
        _selectedSports.remove(sportKey);
      } else {
        _selectedSports.add(sportKey);
      }
    });
    widget.onSelectionChanged(_selectedSports);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 400;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primaryDark,
            const Color(0xFF0A0E14),
          ],
          stops: const [0.0, 1.0],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              children: [
                // Header
                _buildHeader(),

                // Sports Grid
                Expanded(
                  child: _buildSportsGrid(isSmallScreen),
                ),

                // Bottom buttons
                _buildBottomButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      child: Column(
        children: [
          // Progress indicator
          if (!widget.isSettingsMode) ...[
            _buildProgressIndicator(1, 2),
            const SizedBox(height: 28),
          ],

          // Title with gradient effect
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Colors.white, Color(0xFFE0E0E0)],
            ).createShader(bounds),
            child: Text(
              widget.isSettingsMode ? 'FAVORITE SPORTS' : 'FOLLOW YOUR SPORTS',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.5,
              ),
            ),
          )
              .animate()
              .fadeIn(duration: 400.ms)
              .slideY(begin: -0.3, end: 0, duration: 400.ms, curve: Curves.easeOutCubic),

          const SizedBox(height: 10),

          // Subtitle with glow
          Text(
            widget.isSettingsMode
                ? 'Select the sports you want to follow'
                : 'Personalize your experience',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ).animate(delay: 100.ms).fadeIn(duration: 400.ms),

          const SizedBox(height: 14),

          // Selection count badge
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: animation,
              child: child,
            ),
            child: Container(
              key: ValueKey(_selectedSports.length),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: _selectedSports.isEmpty
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFF00FF7F), Color(0xFF00D68F)],
                      ),
                color: _selectedSports.isEmpty ? AppColors.cardBackground : null,
                borderRadius: BorderRadius.circular(20),
                boxShadow: _selectedSports.isNotEmpty
                    ? [
                        BoxShadow(
                          color: const Color(0xFF00FF7F).withOpacity(0.3),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_selectedSports.isNotEmpty) ...[
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Colors.black,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    '${_selectedSports.length} selected',
                    style: TextStyle(
                      color: _selectedSports.isEmpty
                          ? AppColors.textSecondary
                          : Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(int current, int total) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (index) {
        final isActive = index < current;
        final isCurrent = index == current - 1;

        return Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              width: isCurrent ? 40 : 14,
              height: 14,
              decoration: BoxDecoration(
                gradient: isActive
                    ? const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                      )
                    : null,
                color: isActive ? null : AppColors.cardBackground,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: isActive
                      ? const Color(0xFFFFD700).withOpacity(0.5)
                      : AppColors.borderSubtle.withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: isCurrent
                    ? [
                        BoxShadow(
                          color: const Color(0xFFFFD700).withOpacity(0.5),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: isCurrent
                  ? Center(
                      child: Text(
                        '${current}',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    )
                  : null,
            ),
            if (index < total - 1) ...[
              const SizedBox(width: 6),
              Container(
                width: 20,
                height: 2,
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFFFFD700).withOpacity(0.5)
                      : AppColors.borderSubtle.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              const SizedBox(width: 6),
            ],
          ],
        );
      }),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildSportsGrid(bool isSmallScreen) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 0.95,
        ),
        itemCount: Sport.all.length,
        itemBuilder: (context, index) {
          final sport = Sport.all[index];
          final isSelected = _selectedSports.contains(sport.key);

          return SportCard(
            sport: sport,
            isSelected: isSelected,
            onTap: () => _toggleSport(sport.key),
            animationDelay: 50 * index,
          );
        },
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF0A0E14).withOpacity(0),
            const Color(0xFF0A0E14),
            const Color(0xFF0A0E14),
          ],
          stops: const [0.0, 0.3, 1.0],
        ),
      ),
      child: Row(
        children: [
          // Skip/Cancel button
          if (widget.onSkip != null || widget.isSettingsMode)
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.textSecondary.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: TextButton(
                  onPressed: widget.isSettingsMode
                      ? () => Navigator.of(context).pop()
                      : widget.onSkip,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    widget.isSettingsMode ? 'Cancel' : 'Skip',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),

          if (widget.onSkip != null || widget.isSettingsMode)
            const SizedBox(width: 16),

          // Next/Save button
          Expanded(
            flex: widget.onSkip != null ? 2 : 1,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD700).withOpacity(0.4),
                    blurRadius: 16,
                    spreadRadius: 1,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: widget.onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.black,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.isSettingsMode ? 'Save' : 'Next',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    if (!widget.isSettingsMode) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 22),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate(delay: 300.ms).fadeIn(duration: 400.ms).slideY(begin: 0.3, end: 0);
  }
}
