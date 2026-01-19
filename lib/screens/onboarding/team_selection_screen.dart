import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../config/teams_data.dart';
import '../../providers/auth_provider.dart';
import '../../providers/suggestions_provider.dart';

/// Mode for team selection screen behavior
enum TeamSelectionMode {
  onboarding, // After registration - shows Skip/Continue
  settings,   // From settings - shows Cancel/Save
}

class TeamSelectionScreen extends StatefulWidget {
  final TeamSelectionMode mode;

  const TeamSelectionScreen({
    super.key,
    this.mode = TeamSelectionMode.onboarding,
  });

  @override
  State<TeamSelectionScreen> createState() => _TeamSelectionScreenState();
}

class _TeamSelectionScreenState extends State<TeamSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedTeams = {};
  String _searchQuery = '';
  String? _selectedSport;
  bool _isLoading = false;

  bool get _isFromSettings => widget.mode == TeamSelectionMode.settings;

  @override
  void initState() {
    super.initState();
    // Pre-populate with existing teams when from settings
    if (_isFromSettings) {
      final auth = context.read<AuthProvider>();
      _selectedTeams.addAll(auth.user?.favoriteTeams ?? []);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<TeamInfo> get _filteredTeams {
    var teams = _searchQuery.isNotEmpty
        ? TeamsData.searchTeams(_searchQuery)
        : _selectedSport != null
            ? TeamsData.getTeamsForSport(_selectedSport!)
            : TeamsData.allTeams;
    return teams;
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

  void _cancel() {
    if (_isFromSettings) {
      Navigator.of(context).pop();
    } else {
      // Skip during onboarding - still mark as complete but with no teams
      _saveAndNavigate([]);
    }
  }

  Future<void> _saveAndNavigate(List<String> teams) async {
    setState(() => _isLoading = true);

    try {
      if (_isFromSettings) {
        // Settings mode: just update teams
        await context.read<AuthProvider>().updateFavoriteTeams(teams);
      } else {
        // Onboarding mode: set teams AND mark onboarding complete
        await context.read<AuthProvider>().setFavoriteTeams(teams);
      }

      if (mounted) {
        context.read<SuggestionsProvider>().setFollowedTeams(teams);

        if (_isFromSettings) {
          Navigator.of(context).pop();
        } else {
          context.go(AppRoutes.home);
        }
      }
    } catch (e) {
      debugPrint('Error saving teams: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save preferences')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              children: [
                _buildHeader(),
                _buildSportFilters(),
                _buildSearchBar(),
                Expanded(child: _buildTeamsGrid()),
                _buildActionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _isFromSettings ? 'Edit Teams' : 'Follow Teams',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (_isFromSettings)
                IconButton(
                  icon: const Icon(Icons.close),
                  color: AppColors.textSecondary,
                  onPressed: _cancel,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _isFromSettings
                ? 'Update your followed teams'
                : 'Get personalized bets and updates',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildSportFilters() {
    final sports = ['All', ...TeamsData.allSports];

    return Container(
      height: 44,
      margin: const EdgeInsets.only(top: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: sports.length,
        itemBuilder: (context, index) {
          final sport = sports[index];
          final isSelected = (sport == 'All' && _selectedSport == null) ||
              sport == _selectedSport;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(sport),
              selected: isSelected,
              onSelected: (selected) {
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedSport = sport == 'All' ? null : sport;
                  _searchQuery = '';
                  _searchController.clear();
                });
              },
              backgroundColor: AppColors.cardBackground,
              selectedColor: AppColors.accent.withValues(alpha: 0.2),
              checkmarkColor: AppColors.accent,
              labelStyle: TextStyle(
                color: isSelected ? AppColors.accent : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              side: BorderSide(
                color: isSelected ? AppColors.accent : AppColors.borderSubtle,
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
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search teams...',
          hintStyle: const TextStyle(color: AppColors.textMuted),
          prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: AppColors.textMuted),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
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

  Widget _buildTeamsGrid() {
    final teams = _filteredTeams;

    if (teams.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: AppColors.textMuted.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No teams found',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 16,
              ),
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
          onTap: () => _toggleTeam(team.name),
        ).animate(delay: Duration(milliseconds: 30 * (index % 12))).fadeIn().scale(
              begin: const Offset(0.9, 0.9),
              end: const Offset(1, 1),
              duration: 200.ms,
            );
      },
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_selectedTeams.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '${_selectedTeams.length} team${_selectedTeams.length == 1 ? '' : 's'} selected',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Row(
              children: [
                // Left button - Skip/Cancel
                TextButton(
                  onPressed: _isLoading ? null : _cancel,
                  child: Text(
                    _isFromSettings ? 'Cancel' : 'Skip',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Right button - Continue/Save
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading || _selectedTeams.isEmpty
                        ? null
                        : () => _saveAndNavigate(_selectedTeams.toList()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      disabledBackgroundColor: AppColors.cardBackground,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _isFromSettings ? 'Save' : 'Continue',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

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
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accent.withValues(alpha: 0.15)
              : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.borderSubtle,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CachedNetworkImage(
                  imageUrl: team.logoUrl,
                  width: 48,
                  height: 48,
                  placeholder: (context, url) => Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.borderSubtle,
                      shape: BoxShape.circle,
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.borderSubtle,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.sports,
                      color: AppColors.textMuted,
                      size: 24,
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
                      color: isSelected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  team.sport,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
            if (isSelected)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
