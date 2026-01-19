import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../config/theme.dart';
import '../../config/design_system.dart';
import '../../models/game.dart';
import '../../models/sport.dart';
import '../../providers/games_provider.dart';

class GamePickerSheet extends StatefulWidget {
  const GamePickerSheet({super.key});

  @override
  State<GamePickerSheet> createState() => _GamePickerSheetState();
}

class _GamePickerSheetState extends State<GamePickerSheet> {
  String? _selectedSportKey;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Fetch games if not already loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GamesProvider>().fetchGames();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Game> _getFilteredGames(List<Game> allGames) {
    var games = allGames;

    // Filter by sport
    if (_selectedSportKey != null) {
      if (_selectedSportKey == 'soccer_all') {
        games = games.where((g) => g.sportKey.startsWith('soccer_')).toList();
      } else {
        games = games.where((g) => g.sportKey == _selectedSportKey).toList();
      }
    }

    // Filter by search
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      games = games.where((g) {
        return g.homeTeam.name.toLowerCase().contains(query) ||
            g.awayTeam.name.toLowerCase().contains(query);
      }).toList();
    }

    // Sort by start time
    games.sort((a, b) => a.startTime.compareTo(b.startTime));

    return games;
  }

  String _formatGameTime(DateTime time) {
    final now = DateTime.now();
    final diff = time.difference(now);

    if (diff.inDays == 0) {
      // Today
      final hour = time.hour > 12 ? time.hour - 12 : time.hour;
      final amPm = time.hour >= 12 ? 'PM' : 'AM';
      final minute = time.minute.toString().padLeft(2, '0');
      return 'Today ${hour == 0 ? 12 : hour}:$minute $amPm';
    } else if (diff.inDays == 1) {
      return 'Tomorrow';
    } else if (diff.inDays < 7) {
      final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[time.weekday - 1];
    } else {
      return '${time.month}/${time.day}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.primaryDark,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(DesignSystem.radiusXxl),
            ),
            border: Border.all(color: AppColors.borderGlow),
          ),
          child: Column(
            children: [
              // Handle + Header
              _buildHeader(),

              // Sport filter chips
              _buildSportChips(),

              // Search bar
              _buildSearchBar(),

              // Games list
              Expanded(
                child: Consumer<GamesProvider>(
                  builder: (context, gamesProvider, child) {
                    if (gamesProvider.isLoading && gamesProvider.allGames.isEmpty) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.accentCyan,
                        ),
                      );
                    }

                    final games = _getFilteredGames(gamesProvider.allGames);

                    if (games.isEmpty) {
                      return _buildEmptyState();
                    }

                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      itemCount: games.length,
                      itemBuilder: (context, index) {
                        final game = games[index];
                        return _GameTile(
                          game: game,
                          timeLabel: _formatGameTime(game.startTime),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            Navigator.of(context).pop(game);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Column(
        children: [
          DesignSystem.handleBar(),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              const Text(
                'Select Game',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.close, color: AppColors.textSubtle),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSportChips() {
    final sports = [
      {'key': null, 'label': 'All'},
      {'key': 'basketball_nba', 'label': 'NBA'},
      {'key': 'americanfootball_nfl', 'label': 'NFL'},
      {'key': 'baseball_mlb', 'label': 'MLB'},
      {'key': 'icehockey_nhl', 'label': 'NHL'},
      {'key': 'soccer_all', 'label': 'Soccer'},
      {'key': 'basketball_ncaab', 'label': 'NCAAB'},
    ];

    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: sports.length,
        itemBuilder: (context, index) {
          final sport = sports[index];
          final isSelected = _selectedSportKey == sport['key'];

          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedSportKey = sport['key'] as String?;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.accentCyan.withOpacity(0.2)
                      : AppColors.glassBackground(0.4),
                  borderRadius: BorderRadius.circular(AppRadius.round),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.accentCyan
                        : AppColors.borderSubtle,
                  ),
                ),
                child: Text(
                  sport['label'] as String,
                  style: TextStyle(
                    color: isSelected
                        ? AppColors.accentCyan
                        : AppColors.textSubtle,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Container(
        decoration: DesignSystem.glassDecoration(
          opacity: 0.4,
          borderOpacity: 0.2,
          radius: DesignSystem.radiusLarge,
        ),
        child: TextField(
          controller: _searchController,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Search teams...',
            hintStyle: TextStyle(color: AppColors.textSubtle),
            prefixIcon: Icon(Icons.search, color: AppColors.textSubtle),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.sports,
            color: AppColors.textSubtle,
            size: 48,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'No games found',
            style: TextStyle(
              color: AppColors.textSecondaryOp,
              fontSize: 16,
            ),
          ),
          if (_selectedSportKey != null || _searchQuery.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _selectedSportKey = null;
                    _searchQuery = '';
                    _searchController.clear();
                  });
                },
                child: const Text('Clear filters'),
              ),
            ),
        ],
      ),
    );
  }
}

class _GameTile extends StatelessWidget {
  final Game game;
  final String timeLabel;
  final VoidCallback onTap;

  const _GameTile({
    required this.game,
    required this.timeLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: DesignSystem.glassDecoration(
          opacity: 0.4,
          borderOpacity: 0.2,
          radius: DesignSystem.radiusLarge,
        ),
        child: Row(
          children: [
            // Teams
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Away team
                  Row(
                    children: [
                      if (game.awayTeam.logoUrl != null)
                        Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.sm),
                          child: CachedNetworkImage(
                            imageUrl: game.awayTeam.logoUrl!,
                            width: 24,
                            height: 24,
                            errorWidget: (_, __, ___) => const SizedBox.shrink(),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          game.awayTeam.name,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  // Home team
                  Row(
                    children: [
                      if (game.homeTeam.logoUrl != null)
                        Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.sm),
                          child: CachedNetworkImage(
                            imageUrl: game.homeTeam.logoUrl!,
                            width: 24,
                            height: 24,
                            errorWidget: (_, __, ___) => const SizedBox.shrink(),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          '@ ${game.homeTeam.name}',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Time + Sport badge
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  timeLabel,
                  style: TextStyle(
                    color: AppColors.textSecondaryOp,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.glassBackground(0.5),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    _getSportLabel(game.sportKey),
                    style: TextStyle(
                      color: AppColors.textSubtle,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(width: AppSpacing.md),
            Icon(
              Icons.chevron_right,
              color: AppColors.textSubtle,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  String _getSportLabel(String sportKey) {
    if (sportKey.startsWith('soccer_')) return 'Soccer';
    switch (sportKey) {
      case 'basketball_nba':
        return 'NBA';
      case 'americanfootball_nfl':
        return 'NFL';
      case 'baseball_mlb':
        return 'MLB';
      case 'icehockey_nhl':
        return 'NHL';
      case 'basketball_ncaab':
        return 'NCAAB';
      case 'americanfootball_ncaaf':
        return 'NCAAF';
      default:
        return sportKey.split('_').last.toUpperCase();
    }
  }
}
