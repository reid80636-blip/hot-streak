import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/routes.dart';
import '../../config/teams_data.dart';
import '../../config/theme.dart';
import '../../models/sport.dart';
import '../../providers/auth_provider.dart';
import '../../providers/suggestions_provider.dart';
import 'sport_selection_screen.dart';

/// Mode for the onboarding flow
enum OnboardingMode {
  onboarding, // After registration - shows full flow
  settings,   // From settings - shows sport selection only
}

/// Main onboarding flow that manages sports → teams selection
class OnboardingFlow extends StatefulWidget {
  final OnboardingMode mode;

  const OnboardingFlow({
    super.key,
    this.mode = OnboardingMode.onboarding,
  });

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final PageController _pageController = PageController();
  late ConfettiController _confettiController;

  int _currentStep = 0;
  Set<String> _selectedSports = {};
  Set<String> _selectedTeams = {};
  bool _isLoading = false;
  bool _showCompletion = false;

  bool get _isSettingsMode => widget.mode == OnboardingMode.settings;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));

    // Pre-populate with existing selections when from settings
    if (_isSettingsMode) {
      final auth = context.read<AuthProvider>();
      _selectedSports = Set.from(auth.user?.favoriteSports ?? []);
      _selectedTeams = Set.from(auth.user?.favoriteTeams ?? []);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    setState(() => _currentStep = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
  }

  void _onSportsNext() {
    HapticFeedback.mediumImpact();
    _goToStep(1);
  }

  void _onTeamsBack() {
    HapticFeedback.lightImpact();
    _goToStep(0);
  }

  void _onSkip() {
    HapticFeedback.lightImpact();
    _completeOnboarding(sports: [], teams: []);
  }

  Future<void> _onComplete() async {
    HapticFeedback.heavyImpact();
    await _completeOnboarding(
      sports: _selectedSports.toList(),
      teams: _selectedTeams.toList(),
    );
  }

  Future<void> _completeOnboarding({
    required List<String> sports,
    required List<String> teams,
  }) async {
    setState(() => _isLoading = true);

    try {
      final auth = context.read<AuthProvider>();

      if (_isSettingsMode) {
        // Settings mode: update both separately
        await auth.updateFavoriteSports(sports);
        await auth.updateFavoriteTeams(teams);
      } else {
        // Onboarding mode: complete with all preferences
        await auth.completeOnboardingWithPreferences(
          sports: sports,
          teams: teams,
        );
      }

      // Update suggestions provider
      if (mounted) {
        final suggestions = context.read<SuggestionsProvider>();
        suggestions.setFollowedSports(sports);
        suggestions.setFollowedTeams(teams);
      }

      // Show completion animation (only for non-empty selections)
      if (sports.isNotEmpty || teams.isNotEmpty) {
        setState(() => _showCompletion = true);
        _confettiController.play();

        await Future.delayed(const Duration(milliseconds: 1800));
      }

      if (mounted) {
        if (_isSettingsMode) {
          Navigator.of(context).pop();
        } else {
          context.go(AppRoutes.home);
        }
      }
    } catch (e) {
      debugPrint('Error completing onboarding: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save preferences')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  List<TeamInfo> get _teamsForSelectedSports {
    if (_selectedSports.isEmpty) {
      return TeamsData.allTeams;
    }

    // Map sport keys to sport display names for filtering
    final sportNames = _selectedSports
        .map((key) => Sport.fromKey(key)?.shortName)
        .where((name) => name != null)
        .cast<String>()
        .toSet();

    // Also add full names for soccer leagues
    for (final key in _selectedSports) {
      final sport = Sport.fromKey(key);
      if (sport != null) {
        sportNames.add(sport.name);
        // Handle soccer specifically - teams use league names like "EPL", "La Liga"
        if (sport.shortName == 'EPL') sportNames.add('EPL');
        if (sport.shortName == 'La Liga') sportNames.add('La Liga');
        if (sport.shortName == 'UCL') sportNames.add('UCL');
        if (sport.shortName == 'MLS') sportNames.add('MLS');
      }
    }

    return TeamsData.allTeams.where((team) {
      return sportNames.contains(team.sport);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: Stack(
        children: [
          // Main content
          if (_showCompletion)
            _buildCompletionScreen()
          else
            PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                // Step 1: Sports Selection
                SportSelectionScreen(
                  initialSelection: _selectedSports,
                  onSelectionChanged: (sports) {
                    setState(() => _selectedSports = sports);
                  },
                  onNext: _onSportsNext,
                  onSkip: _isSettingsMode ? null : _onSkip,
                  isSettingsMode: _isSettingsMode,
                ),

                // Step 2: Teams Selection
                _buildTeamsSelectionStep(),
              ],
            ),

          // Confetti overlay
          Positioned.fill(
            child: IgnorePointer(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirectionality: BlastDirectionality.explosive,
                  particleDrag: 0.05,
                  emissionFrequency: 0.05,
                  numberOfParticles: 40,
                  gravity: 0.1,
                  shouldLoop: false,
                  colors: const [
                    Color(0xFFFFD700),
                    Color(0xFF00FF7F),
                    Color(0xFFFF6B35),
                    Colors.white,
                    Color(0xFF3498DB),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamsSelectionStep() {
    final availableTeams = _teamsForSelectedSports;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primaryDark,
            AppColors.primaryDark.withOpacity(0.95),
          ],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              children: [
                // Header
                _buildTeamsHeader(),

                // Sport filter chips (only show selected sports)
                if (_selectedSports.isNotEmpty) _buildSportFilterChips(),

                // Search bar
                _buildSearchBar(),

                // Teams grid
                Expanded(
                  child: _buildTeamsGrid(availableTeams),
                ),

                // Bottom buttons
                _buildTeamsBottomButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTeamsHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Column(
        children: [
          // Progress indicator
          _buildProgressIndicator(2, 2),
          const SizedBox(height: 28),

          // Title with gradient
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Colors.white, Color(0xFFE0E0E0)],
            ).createShader(bounds),
            child: const Text(
              'FOLLOW YOUR TEAMS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.5,
              ),
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.3, end: 0),

          const SizedBox(height: 10),

          // Subtitle
          Text(
            "We'll highlight their games for you",
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
              key: ValueKey(_selectedTeams.length),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: _selectedTeams.isEmpty
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFF00FF7F), Color(0xFF00D68F)],
                      ),
                color: _selectedTeams.isEmpty ? AppColors.cardBackground : null,
                borderRadius: BorderRadius.circular(20),
                boxShadow: _selectedTeams.isNotEmpty
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
                  if (_selectedTeams.isNotEmpty) ...[
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Colors.black,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    '${_selectedTeams.length} selected',
                    style: TextStyle(
                      color: _selectedTeams.isEmpty
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
                        '$current',
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
    );
  }

  String? _teamFilterSport;
  final TextEditingController _teamSearchController = TextEditingController();
  String _teamSearchQuery = '';

  Widget _buildSportFilterChips() {
    final selectedSportsList = _selectedSports
        .map((key) => Sport.fromKey(key))
        .where((s) => s != null)
        .cast<Sport>()
        .toList();

    return Container(
      height: 44,
      margin: const EdgeInsets.only(top: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: selectedSportsList.length + 1, // +1 for "All"
        itemBuilder: (context, index) {
          if (index == 0) {
            // "All" chip
            final isSelected = _teamFilterSport == null;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: const Text('All'),
                selected: isSelected,
                onSelected: (selected) {
                  HapticFeedback.selectionClick();
                  setState(() => _teamFilterSport = null);
                },
                backgroundColor: AppColors.cardBackground,
                selectedColor: const Color(0xFFFFD700).withOpacity(0.2),
                checkmarkColor: const Color(0xFFFFD700),
                labelStyle: TextStyle(
                  color: isSelected ? const Color(0xFFFFD700) : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                side: BorderSide(
                  color: isSelected ? const Color(0xFFFFD700) : AppColors.borderSubtle,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            );
          }

          final sport = selectedSportsList[index - 1];
          final isSelected = _teamFilterSport == sport.shortName;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              avatar: Text(sport.emoji, style: const TextStyle(fontSize: 14)),
              label: Text(sport.shortName),
              selected: isSelected,
              onSelected: (selected) {
                HapticFeedback.selectionClick();
                setState(() {
                  _teamFilterSport = selected ? sport.shortName : null;
                });
              },
              backgroundColor: AppColors.cardBackground,
              selectedColor: (sport.gradientStart ?? sport.color).withOpacity(0.2),
              checkmarkColor: sport.gradientStart ?? sport.color,
              labelStyle: TextStyle(
                color: isSelected
                    ? (sport.gradientStart ?? sport.color)
                    : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              side: BorderSide(
                color: isSelected
                    ? (sport.gradientStart ?? sport.color)
                    : AppColors.borderSubtle,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        },
      ),
    ).animate().fadeIn(delay: 100.ms, duration: 300.ms);
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: _teamSearchController,
        onChanged: (value) => setState(() => _teamSearchQuery = value),
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search teams...',
          hintStyle: const TextStyle(color: AppColors.textMuted),
          prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
          suffixIcon: _teamSearchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: AppColors.textMuted),
                  onPressed: () {
                    _teamSearchController.clear();
                    setState(() => _teamSearchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: AppColors.cardBackground,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 300.ms);
  }

  Widget _buildTeamsGrid(List<TeamInfo> allTeams) {
    // Filter by search and sport
    var teams = allTeams;

    if (_teamSearchQuery.isNotEmpty) {
      teams = teams
          .where((t) => t.name.toLowerCase().contains(_teamSearchQuery.toLowerCase()))
          .toList();
    } else if (_teamFilterSport != null) {
      teams = teams.where((t) => t.sport == _teamFilterSport).toList();
    }

    if (teams.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: AppColors.textMuted.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No teams found',
              style: TextStyle(color: AppColors.textMuted, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.85,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: teams.length,
      itemBuilder: (context, index) {
        final team = teams[index];
        final isSelected = _selectedTeams.contains(team.name);

        return _TeamCard(
          team: team,
          isSelected: isSelected,
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() {
              if (isSelected) {
                _selectedTeams.remove(team.name);
              } else {
                _selectedTeams.add(team.name);
              }
            });
          },
        ).animate(delay: Duration(milliseconds: 30 * (index % 12))).fadeIn().scale(
              begin: const Offset(0.9, 0.9),
              end: const Offset(1, 1),
              duration: 200.ms,
            );
      },
    );
  }

  Widget _buildTeamsBottomButtons() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primaryDark.withOpacity(0),
            AppColors.primaryDark,
          ],
        ),
      ),
      child: Row(
        children: [
          // Back button
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isLoading ? null : _onTeamsBack,
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Back'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: BorderSide(color: AppColors.textSecondary.withOpacity(0.3)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Done button
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _onComplete,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FF7F),
                foregroundColor: Colors.black,
                disabledBackgroundColor: const Color(0xFF00FF7F).withOpacity(0.5),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
                shadowColor: const Color(0xFF00FF7F).withOpacity(0.4),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_rounded, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Done',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    ).animate(delay: 300.ms).fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildCompletionScreen() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
          // Success icon with rings
          Stack(
            alignment: Alignment.center,
            children: [
              // Outer pulsing ring
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF00FF7F).withOpacity(0.2),
                    width: 2,
                  ),
                ),
              )
                  .animate(onPlay: (c) => c.repeat())
                  .scale(
                    begin: const Offset(0.8, 0.8),
                    end: const Offset(1.2, 1.2),
                    duration: 1500.ms,
                  )
                  .fadeOut(duration: 1500.ms),
              // Middle ring
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF00FF7F).withOpacity(0.3),
                    width: 2,
                  ),
                ),
              )
                  .animate(delay: 500.ms, onPlay: (c) => c.repeat())
                  .scale(
                    begin: const Offset(0.9, 0.9),
                    end: const Offset(1.1, 1.1),
                    duration: 1500.ms,
                  )
                  .fadeOut(duration: 1500.ms),
              // Main icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF00FF7F).withOpacity(0.3),
                      const Color(0xFF00D68F).withOpacity(0.2),
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00FF7F).withOpacity(0.4),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF00FF7F),
                  size: 64,
                ),
              ),
            ],
          )
              .animate()
              .scale(
                begin: const Offset(0, 0),
                end: const Offset(1, 1),
                duration: 600.ms,
                curve: Curves.elasticOut,
              )
              .fadeIn(duration: 300.ms),

          const SizedBox(height: 32),

          // Title with gradient
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Colors.white, Color(0xFFE0E0E0)],
            ).createShader(bounds),
            child: const Text(
              "You're all set!",
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
          ).animate(delay: 200.ms).fadeIn(duration: 400.ms).slideY(begin: 0.3, end: 0),

          const SizedBox(height: 16),

          // Stats badges
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStatBadge(
                icon: Icons.sports,
                value: '${_selectedSports.length}',
                label: 'sports',
                color: const Color(0xFFFFD700),
              ),
              const SizedBox(width: 16),
              _buildStatBadge(
                icon: Icons.favorite,
                value: '${_selectedTeams.length}',
                label: 'teams',
                color: const Color(0xFF00FF7F),
              ),
            ],
          ).animate(delay: 350.ms).fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBadge({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.8),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Premium team card widget with polished styling
class _TeamCard extends StatelessWidget {
  final TeamInfo team;
  final bool isSelected;
  final VoidCallback onTap;

  const _TeamCard({
    required this.team,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFFFD700).withOpacity(0.25),
                    const Color(0xFFFFA500).withOpacity(0.15),
                  ],
                )
              : LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.cardBackground,
                    AppColors.cardBackground.withOpacity(0.8),
                  ],
                ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFFD700).withOpacity(0.8)
                : AppColors.borderSubtle.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            if (isSelected) ...[
              BoxShadow(
                color: const Color(0xFFFFD700).withOpacity(0.35),
                blurRadius: 16,
                spreadRadius: 1,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ] else ...[
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ],
        ),
        child: Stack(
          children: [
            // Inner highlight
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 35,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withOpacity(isSelected ? 0.15 : 0.05),
                        Colors.white.withOpacity(0),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Content
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Team logo with ring
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer ring for selected
                    if (isSelected)
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFFFD700).withOpacity(0.5),
                            width: 2,
                          ),
                        ),
                      ),
                    // Logo container
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: isSelected
                                ? const Color(0xFFFFD700).withOpacity(0.3)
                                : Colors.black.withOpacity(0.12),
                            blurRadius: isSelected ? 10 : 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Image.network(
                            team.logoUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.sports,
                              color: AppColors.textMuted,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Team name
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    team.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      height: 1.2,
                      shadows: isSelected
                          ? [
                              Shadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                // Sport badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withOpacity(0.15)
                        : AppColors.borderSubtle.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    team.sport,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white.withOpacity(0.9)
                          : AppColors.textMuted,
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),

            // Selection checkmark
            if (isSelected)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 14,
                    color: Colors.black,
                  ),
                )
                    .animate()
                    .scale(
                      begin: const Offset(0, 0),
                      end: const Offset(1, 1),
                      duration: 250.ms,
                      curve: Curves.elasticOut,
                    )
                    .fadeIn(duration: 150.ms),
              ),
          ],
        ),
      ),
    );
  }
}
