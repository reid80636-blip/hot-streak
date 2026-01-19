import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../models/sport.dart';

class SportChip extends StatelessWidget {
  final Sport sport;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool showEmoji;

  const SportChip({
    super.key,
    required this.sport,
    this.isSelected = false,
    this.onTap,
    this.showEmoji = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? sport.color.withOpacity(0.15) : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? sport.color : AppColors.borderSubtle,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showEmoji) ...[
              Text(
                sport.emoji,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              sport.shortName,
              style: TextStyle(
                color: isSelected ? sport.color : AppColors.textSecondaryOp,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SportChipsRow extends StatelessWidget {
  final String? selectedSportKey;
  final ValueChanged<String?> onSportSelected;
  final bool showAll;

  const SportChipsRow({
    super.key,
    this.selectedSportKey,
    required this.onSportSelected,
    this.showAll = true,
  });

  @override
  Widget build(BuildContext context) {
    // Use main sports (which has combined Soccer option)
    final sports = Sport.mainSports;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          if (showAll)
            GestureDetector(
              onTap: () => onSportSelected(null),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: selectedSportKey == null
                      ? AppColors.accent.withOpacity(0.15)
                      : AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selectedSportKey == null
                        ? AppColors.accent
                        : AppColors.borderSubtle,
                    width: selectedSportKey == null ? 2 : 1,
                  ),
                ),
                child: Text(
                  'All',
                  style: TextStyle(
                    color: selectedSportKey == null
                        ? AppColors.accent
                        : AppColors.textSecondaryOp,
                    fontWeight: selectedSportKey == null
                        ? FontWeight.w600
                        : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          if (showAll) const SizedBox(width: 8),
          ...sports.map((sport) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: SportChip(
                  sport: sport,
                  isSelected: _isSportSelected(selectedSportKey, sport.key),
                  onTap: () => onSportSelected(sport.key),
                ),
              )),
        ],
      ),
    );
  }

  /// Check if a sport is selected (handles soccer_all matching any soccer_* key)
  bool _isSportSelected(String? selectedKey, String sportKey) {
    if (selectedKey == null) return false;
    if (selectedKey == sportKey) return true;
    // If soccer_all is selected, highlight it when any soccer key is passed
    if (sportKey == 'soccer_all' && selectedKey.startsWith('soccer_')) return true;
    return false;
  }
}
