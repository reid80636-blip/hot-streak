import 'package:cached_network_image/cached_network_image.dart';
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

/// Mode for the preferences flow
enum PreferencesMode {
  onboarding, // New account - shows welcome, full flow
  settings,   // From settings - edit mode
}

/// Unified preferences flow: Sports → Teams
/// Used for both new account onboarding and editing from settings
class PreferencesFlow extends StatefulWidget {
  final PreferencesMode mode;

  const PreferencesFlow({
    super.key,
    this.mode = PreferencesMode.onboarding,
  });

  @override
  State<PreferencesFlow> createState() => _PreferencesFlowState();
}

class _PreferencesFlowState extends State<PreferencesFlow>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  final TextEditingController _sportSearchController = TextEditingController();
  final TextEditingController _teamSearchController = TextEditingController();

  late ConfettiController _confettiController;

  int _currentPage = 0;
  Set<String> _selectedSports = {};
  Set<String> _selectedTeams = {};
  String _sportSearchQuery = '';
  String _teamSearchQuery = '';
  String? _teamFilterSport;
  bool _isLoading = false;
  bool _showSuccess = false;

  bool get _isSettingsMode => widget.mode == PreferencesMode.settings;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));

    // Pre-populate with existing selections in settings mode
    if (_isSettingsMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final auth = context.read<AuthProvider>();
        setState(() {
          _selectedSports = Set.from(auth.user?.favoriteSports ?? []);
          _selectedTeams = Set.from(auth.user?.favoriteTeams ?? []);
        });
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _sportSearchController.dispose();
    _teamSearchController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  List<Sport> get _filteredSports {
    if (_sportSearchQuery.isEmpty) return Sport.mainSports;
    final query = _sportSearchQuery.toLowerCase();
    return Sport.mainSports.where((sport) {
      return sport.name.toLowerCase().contains(query) ||
          sport.shortName.toLowerCase().contains(query) ||
          sport.key.toLowerCase().contains(query);
    }).toList();
  }

  List<TeamInfo> get _teamsForSelectedSports {
    if (_selectedSports.isEmpty) return TeamsData.allTeams;

    final sportNames = <String>{};

    for (final key in _selectedSports) {
      // Handle combined soccer option
      if (key == 'soccer_all') {
        sportNames.addAll(['EPL', 'La Liga', 'UCL', 'MLS', 'Serie A', 'Bundesliga', 'Ligue 1']);
        continue;
      }

      final sport = Sport.fromKey(key);
      if (sport != null) {
        sportNames.add(sport.shortName);
        sportNames.add(sport.name);
      }
    }

    return TeamsData.allTeams.where((team) {
      return sportNames.contains(team.sport);
    }).toList();
  }

  List<TeamInfo> get _filteredTeams {
    var teams = _teamsForSelectedSports;

    if (_teamSearchQuery.isNotEmpty) {
      teams = teams
          .where((t) => t.name.toLowerCase().contains(_teamSearchQuery.toLowerCase()))
          .toList();
    } else if (_teamFilterSport != null) {
      teams = teams.where((t) => t.sport == _teamFilterSport).toList();
    }

    return teams;
  }

  void _toggleSport(String sportKey) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_selectedSports.contains(sportKey)) {
        _selectedSports.remove(sportKey);
        // Remove teams from deselected sport
        final sport = Sport.fromKey(sportKey);
        if (sport != null) {
          _selectedTeams.removeWhere((teamName) {
            final team = TeamsData.allTeams.firstWhere(
              (t) => t.name == teamName,
              orElse: () => TeamInfo(name: '', sport: '', sportKey: '', logoUrl: ''),
            );
            return team.sport == sport.shortName || team.sport == sport.name;
          });
        }
      } else {
        _selectedSports.add(sportKey);
      }
    });
  }

  void _toggleTeam(String teamName) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_selectedTeams.contains(teamName)) {
        _selectedTeams.remove(teamName);
      } else {
        _selectedTeams.add(teamName);
      }
    });
  }

  void _goToTeams() {
    HapticFeedback.mediumImpact();
    _pageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
    setState(() => _currentPage = 1);
  }

  void _goBackToSports() {
    HapticFeedback.lightImpact();
    _pageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
    setState(() => _currentPage = 0);
  }

  void _cancel() {
    Navigator.of(context).pop();
  }

  Future<void> _complete() async {
    HapticFeedback.heavyImpact();
    setState(() => _isLoading = true);

    try {
      final auth = context.read<AuthProvider>();
      final suggestions = context.read<SuggestionsProvider>();

      if (_isSettingsMode) {
        await auth.updateFavoriteSports(_selectedSports.toList());
        await auth.updateFavoriteTeams(_selectedTeams.toList());
      } else {
        await auth.completeOnboardingWithPreferences(
          sports: _selectedSports.toList(),
          teams: _selectedTeams.toList(),
        );
      }

      suggestions.setFollowedSports(_selectedSports.toList());
      suggestions.setFollowedTeams(_selectedTeams.toList());

      // Show success animation
      if (_selectedSports.isNotEmpty || _selectedTeams.isNotEmpty) {
        setState(() => _showSuccess = true);
        _confettiController.play();
        await Future.delayed(const Duration(milliseconds: 1500));
      }

      if (mounted) {
        if (_isSettingsMode) {
          Navigator.of(context).pop();
        } else {
          context.go(AppRoutes.home);
        }
      }
    } catch (e) {
      debugPrint('Error completing preferences: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Something went wrong')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showSuccess) {
      return _buildSuccessScreen();
    }

    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: Stack(
        children: [
          // Background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primaryDark,
                  const Color(0xFF0A0E14),
                ],
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  children: [
                    // Progress indicator
                    _buildProgressBar(),

                    // Pages
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        physics: const NeverScrollableScrollPhysics(),
                        onPageChanged: (page) => setState(() => _currentPage = page),
                        children: [
                          _buildSportsPage(),
                          _buildTeamsPage(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Confetti
          Positioned.fill(
            child: IgnorePointer(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirectionality: BlastDirectionality.explosive,
                  particleDrag: 0.05,
                  emissionFrequency: 0.05,
                  numberOfParticles: 50,
                  gravity: 0.1,
                  shouldLoop: false,
                  colors: const [
                    Color(0xFFFFD700),
                    Color(0xFF00FF7F),
                    Color(0xFFFF6B35),
                    Colors.white,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        children: [
          // Close/Cancel button for settings
          if (_isSettingsMode)
            IconButton(
              icon: const Icon(Icons.close),
              color: AppColors.textSecondary,
              onPressed: _cancel,
            )
          else
            const SizedBox(width: 48),

          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildProgressDot(0, 'Sports'),
                Container(
                  width: 40,
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: _currentPage >= 1
                        ? const Color(0xFFFFD700)
                        : AppColors.borderSubtle.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                _buildProgressDot(1, 'Teams'),
              ],
            ),
          ),

          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildProgressDot(int page, String label) {
    final isActive = _currentPage >= page;
    final isCurrent = _currentPage == page;

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: isCurrent ? 32 : 12,
          height: 12,
          decoration: BoxDecoration(
            gradient: isActive
                ? const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                  )
                : null,
            color: isActive ? null : AppColors.cardBackground,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isActive
                  ? const Color(0xFFFFD700).withOpacity(0.5)
                  : AppColors.borderSubtle.withOpacity(0.3),
            ),
            boxShadow: isCurrent
                ? [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withOpacity(0.4),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: isActive ? AppColors.textPrimary : AppColors.textMuted,
            fontSize: 11,
            fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  // ============ SPORTS PAGE ============

  Widget _buildSportsPage() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                _buildSportsHeader(),
                const SizedBox(height: 24),
                _buildSportSearch(),
                const SizedBox(height: 16),
                _buildSportsGrid(),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
        _buildSportsBottomButtons(),
      ],
    );
  }

  Widget _buildSportsHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!_isSettingsMode) ...[
          // Logo row for onboarding
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.local_fire_department,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                    ).createShader(bounds),
                    child: const Text(
                      'HotStreak',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    'Predict. Win. Dominate.',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ).animate().fadeIn(duration: 400.ms),
          const SizedBox(height: 24),
        ],

        Text(
          _isSettingsMode ? 'Edit Your Sports' : 'Select Your Sports',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
        ).animate().fadeIn(duration: 400.ms),

        const SizedBox(height: 8),

        Text(
          _isSettingsMode
              ? 'Update which sports you want to follow'
              : "Pick the sports you love - we'll personalize your feed",
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 15,
            height: 1.4,
          ),
        ).animate(delay: 100.ms).fadeIn(duration: 400.ms),
      ],
    );
  }

  Widget _buildSportSearch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Sports',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            if (_selectedSports.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00FF7F), Color(0xFF00D68F)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_selectedSports.length} selected',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _sportSearchController,
          onChanged: (v) => setState(() => _sportSearchQuery = v),
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Search sports...',
            hintStyle: TextStyle(color: AppColors.textMuted),
            prefixIcon: Icon(Icons.search, color: AppColors.textMuted, size: 20),
            suffixIcon: _sportSearchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, color: AppColors.textMuted, size: 20),
                    onPressed: () {
                      _sportSearchController.clear();
                      setState(() => _sportSearchQuery = '');
                    },
                  )
                : null,
            filled: true,
            fillColor: AppColors.cardBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildSportsGrid() {
    final sports = _filteredSports;

    if (sports.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.search_off, size: 48, color: AppColors.textMuted.withOpacity(0.5)),
              const SizedBox(height: 12),
              Text('No sports found', style: TextStyle(color: AppColors.textMuted)),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemCount: sports.length,
      itemBuilder: (context, index) {
        final sport = sports[index];
        final isSelected = _selectedSports.contains(sport.key);

        return _SportTile(
          sport: sport,
          isSelected: isSelected,
          onTap: () => _toggleSport(sport.key),
        ).animate(delay: Duration(milliseconds: 50 * index)).fadeIn().scale(
          begin: const Offset(0.95, 0.95),
          end: const Offset(1, 1),
          duration: 200.ms,
        );
      },
    );
  }

  Widget _buildSportsBottomButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (!_isSettingsMode)
              TextButton(
                onPressed: () => _complete(), // Skip
                child: Text(
                  'Skip',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 15),
                ),
              ),
            const Spacer(),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _goToTeams,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 4,
                  shadowColor: const Color(0xFFFFD700).withOpacity(0.4),
                ),
                child: Row(
                  children: [
                    const Text(
                      'Next',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward, size: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============ TEAMS PAGE ============

  Widget _buildTeamsPage() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                _buildTeamsHeader(),
                const SizedBox(height: 16),
                if (_selectedSports.isNotEmpty) _buildSportFilterChips(),
                const SizedBox(height: 12),
                _buildTeamSearch(),
                const SizedBox(height: 16),
                _buildTeamsGrid(),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
        _buildTeamsBottomButtons(),
      ],
    );
  }

  Widget _buildTeamsHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isSettingsMode ? 'Edit Your Teams' : 'Follow Your Teams',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _isSettingsMode
              ? 'Update which teams you want to follow'
              : "We'll highlight their games for you",
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 15,
          ),
        ),
        if (_selectedTeams.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00FF7F), Color(0xFF00D68F)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.black, size: 16),
                const SizedBox(width: 6),
                Text(
                  '${_selectedTeams.length} team${_selectedTeams.length == 1 ? '' : 's'} selected',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSportFilterChips() {
    final selectedSportsList = _selectedSports
        .map((key) => Sport.fromKey(key))
        .where((s) => s != null)
        .cast<Sport>()
        .toList();

    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: selectedSportsList.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            final isSelected = _teamFilterSport == null;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: const Text('All'),
                selected: isSelected,
                onSelected: (_) {
                  HapticFeedback.selectionClick();
                  setState(() => _teamFilterSport = null);
                },
                backgroundColor: AppColors.cardBackground,
                selectedColor: const Color(0xFFFFD700).withOpacity(0.2),
                checkmarkColor: const Color(0xFFFFD700),
                labelStyle: TextStyle(
                  color: isSelected ? const Color(0xFFFFD700) : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
                side: BorderSide(
                  color: isSelected ? const Color(0xFFFFD700) : AppColors.borderSubtle,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                visualDensity: VisualDensity.compact,
              ),
            );
          }

          final sport = selectedSportsList[index - 1];
          final isSelected = _teamFilterSport == sport.shortName;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              avatar: Text(sport.emoji, style: const TextStyle(fontSize: 12)),
              label: Text(sport.shortName),
              selected: isSelected,
              onSelected: (_) {
                HapticFeedback.selectionClick();
                setState(() => _teamFilterSport = isSelected ? null : sport.shortName);
              },
              backgroundColor: AppColors.cardBackground,
              selectedColor: (sport.gradientStart ?? sport.color).withOpacity(0.2),
              checkmarkColor: sport.gradientStart ?? sport.color,
              labelStyle: TextStyle(
                color: isSelected ? (sport.gradientStart ?? sport.color) : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
              side: BorderSide(
                color: isSelected ? (sport.gradientStart ?? sport.color) : AppColors.borderSubtle,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              visualDensity: VisualDensity.compact,
            ),
          );
        },
      ),
    );
  }

  Widget _buildTeamSearch() {
    return TextField(
      controller: _teamSearchController,
      onChanged: (v) => setState(() => _teamSearchQuery = v),
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: 'Search teams...',
        hintStyle: TextStyle(color: AppColors.textMuted),
        prefixIcon: Icon(Icons.search, color: AppColors.textMuted, size: 20),
        suffixIcon: _teamSearchQuery.isNotEmpty
            ? IconButton(
                icon: Icon(Icons.clear, color: AppColors.textMuted, size: 20),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildTeamsGrid() {
    final teams = _filteredTeams;

    if (teams.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.search_off, size: 48, color: AppColors.textMuted.withOpacity(0.5)),
              const SizedBox(height: 12),
              Text(
                _selectedSports.isEmpty ? 'Select sports first' : 'No teams found',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemCount: teams.length,
      itemBuilder: (context, index) {
        final team = teams[index];
        final isSelected = _selectedTeams.contains(team.name);

        return _TeamTile(
          team: team,
          isSelected: isSelected,
          onTap: () => _toggleTeam(team.name),
        ).animate(delay: Duration(milliseconds: 30 * (index % 12))).fadeIn().scale(
          begin: const Offset(0.95, 0.95),
          end: const Offset(1, 1),
          duration: 200.ms,
        );
      },
    );
  }

  Widget _buildTeamsBottomButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Back button
            SizedBox(
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _goBackToSports,
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Back'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: BorderSide(color: AppColors.borderSubtle),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Done button
            Expanded(
              child: SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _complete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00FF7F),
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: const Color(0xFF00FF7F).withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 4,
                    shadowColor: const Color(0xFF00FF7F).withOpacity(0.4),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              _isSettingsMode ? 'Save' : 'Done',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessScreen() {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
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
                    size: 60,
                  ),
                )
                    .animate()
                    .scale(
                      begin: const Offset(0, 0),
                      end: const Offset(1, 1),
                      duration: 500.ms,
                      curve: Curves.elasticOut,
                    )
                    .fadeIn(),
                const SizedBox(height: 28),
                Text(
                  _isSettingsMode ? 'Preferences Saved!' : "You're all set!",
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.2, end: 0),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildStatChip(Icons.sports, '${_selectedSports.length}', 'sports', const Color(0xFFFFD700)),
                    const SizedBox(width: 12),
                    _buildStatChip(Icons.favorite, '${_selectedTeams.length}', 'teams', const Color(0xFF00FF7F)),
                  ],
                ).animate(delay: 350.ms).fadeIn(),
              ],
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirectionality: BlastDirectionality.explosive,
                  particleDrag: 0.05,
                  emissionFrequency: 0.05,
                  numberOfParticles: 50,
                  gravity: 0.1,
                  shouldLoop: false,
                  colors: const [
                    Color(0xFFFFD700),
                    Color(0xFF00FF7F),
                    Color(0xFFFF6B35),
                    Colors.white,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color.withOpacity(0.8), fontSize: 12)),
        ],
      ),
    );
  }
}

// ============ SPORT TILE ============

class _SportTile extends StatelessWidget {
  final Sport sport;
  final bool isSelected;
  final VoidCallback onTap;

  const _SportTile({
    required this.sport,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final gradientStart = sport.gradientStart ?? sport.color;
    final gradientEnd = sport.gradientEnd ?? sport.color.withOpacity(0.7);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [gradientStart, gradientEnd],
                )
              : null,
          color: isSelected ? null : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? Colors.white.withOpacity(0.4) : AppColors.borderSubtle.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: gradientStart.withOpacity(0.4), blurRadius: 12, spreadRadius: 1)]
              : null,
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Text(sport.emoji, style: const TextStyle(fontSize: 26)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sport.shortName,
                          style: TextStyle(
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          sport.name,
                          style: TextStyle(
                            color: isSelected ? Colors.white.withOpacity(0.8) : AppColors.textMuted,
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4)],
                  ),
                  child: Icon(Icons.check, color: gradientStart, size: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ============ TEAM TILE ============

class _TeamTile extends StatelessWidget {
  final TeamInfo team;
  final bool isSelected;
  final VoidCallback onTap;

  const _TeamTile({
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
              : null,
          color: isSelected ? null : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFFFFD700).withOpacity(0.7) : AppColors.borderSubtle.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: const Color(0xFFFFD700).withOpacity(0.3), blurRadius: 10)]
              : null,
        ),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: isSelected
                            ? const Color(0xFFFFD700).withOpacity(0.3)
                            : Colors.black.withOpacity(0.1),
                        blurRadius: isSelected ? 8 : 4,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Padding(
                      padding: const EdgeInsets.all(5),
                      child: CachedNetworkImage(
                        imageUrl: team.logoUrl,
                        fit: BoxFit.contain,
                        placeholder: (_, __) => Icon(Icons.sports, color: AppColors.textMuted, size: 20),
                        errorWidget: (_, __, ___) => Icon(Icons.sports, color: AppColors.textMuted, size: 20),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    team.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  team.sport,
                  style: TextStyle(
                    color: isSelected ? Colors.white.withOpacity(0.7) : AppColors.textMuted,
                    fontSize: 8,
                  ),
                ),
              ],
            ),
            if (isSelected)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 3)],
                  ),
                  child: const Icon(Icons.check, size: 11, color: Colors.black),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
