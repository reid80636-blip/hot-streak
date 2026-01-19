import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../providers/leaderboard_provider.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LeaderboardProvider>().fetchLeaderboard();
    });
  }

  String _getFilterName(LeaderboardTimeFilter filter) {
    switch (filter) {
      case LeaderboardTimeFilter.daily:
        return 'Daily';
      case LeaderboardTimeFilter.weekly:
        return 'Weekly';
      case LeaderboardTimeFilter.allTime:
        return 'All Time';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  const Text(
                    'Leaderboard',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.emoji_events, color: AppColors.gold),
                ],
              ),
            ),

            // Time filter
            Consumer<LeaderboardProvider>(
              builder: (context, provider, child) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Row(
                    children: LeaderboardTimeFilter.values.map((filter) {
                      final isSelected = provider.timeFilter == filter;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => provider.setTimeFilter(filter),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.accent : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _getFilterName(filter),
                              style: TextStyle(
                                color: isSelected ? Colors.white : AppColors.textMuted,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // Leaderboard list
            Expanded(
              child: Consumer<LeaderboardProvider>(
                builder: (context, provider, child) {
                  if (provider.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final entries = provider.entries;

                  if (entries.isEmpty) {
                    return const Center(
                      child: Text(
                        'No leaderboard data',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return _LeaderboardItem(entry: entry, index: index)
                          .animate(delay: (index * 30).ms)
                          .fadeIn()
                          .slideX(begin: 0.05, end: 0);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaderboardItem extends StatelessWidget {
  final LeaderboardEntry entry;
  final int index;

  const _LeaderboardItem({
    required this.entry,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final isTopThree = entry.rank <= 3;

    Color? rankColor;
    IconData? rankIcon;

    if (entry.rank == 1) {
      rankColor = const Color(0xFFFFD700); // Gold
      rankIcon = Icons.emoji_events;
    } else if (entry.rank == 2) {
      rankColor = const Color(0xFFC0C0C0); // Silver
      rankIcon = Icons.emoji_events;
    } else if (entry.rank == 3) {
      rankColor = const Color(0xFFCD7F32); // Bronze
      rankIcon = Icons.emoji_events;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isTopThree
            ? rankColor?.withOpacity(0.1)
            : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isTopThree ? rankColor!.withOpacity(0.3) : AppColors.borderSubtle,
        ),
      ),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 40,
            child: isTopThree
                ? Icon(rankIcon, color: rankColor, size: 28)
                : Text(
                    '#${entry.rank}',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
          ),

          const SizedBox(width: 12),

          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.cardBackground,
            child: Text(
              entry.username.substring(0, 1).toUpperCase(),
              style: TextStyle(
                color: isTopThree ? rankColor : AppColors.accent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Name and stats
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      entry.username,
                      style: TextStyle(
                        color: isTopThree ? rankColor : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (entry.badges.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      ...entry.badges.take(2).map((badge) => Padding(
                            padding: const EdgeInsets.only(right: 2),
                            child: Icon(
                              Icons.verified,
                              color: AppColors.accent,
                              size: 14,
                            ),
                          )),
                    ],
                  ],
                ),
                Text(
                  '${entry.wins}W - ${entry.totalPredictions - entry.wins}L • ${entry.winRate.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Coins
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.monetization_on, color: AppColors.gold, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    _formatCoins(entry.coins),
                    style: TextStyle(
                      color: isTopThree ? rankColor : AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Text(
                'coins won',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatCoins(int coins) {
    if (coins >= 1000000) {
      return '${(coins / 1000000).toStringAsFixed(1)}M';
    } else if (coins >= 1000) {
      return '${(coins / 1000).toStringAsFixed(1)}K';
    }
    return coins.toString();
  }
}
