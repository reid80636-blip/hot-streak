import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../config/theme.dart';
import '../../models/collectible.dart';

class CollectiblesScreen extends StatefulWidget {
  const CollectiblesScreen({super.key});

  @override
  State<CollectiblesScreen> createState() => _CollectiblesScreenState();
}

class _CollectiblesScreenState extends State<CollectiblesScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  CollectibleRarity? _selectedRarity;

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    final collectibles = SampleCollectibles.all;

    // Filter by rarity if selected
    final filteredCollectibles = _selectedRarity == null
        ? collectibles
        : collectibles.where((c) => c.rarity == _selectedRarity).toList();

    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back_rounded, size: 20),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
          ).createShader(bounds),
          child: const Text(
            'Collectibles',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: collectibles.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    // Stats header
                    _buildStatsHeader(collectibles),

                    // Rarity filter chips
                    _buildRarityFilter(),

                    // Grid of collectibles
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.all(20),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: 0.78,
                        ),
                        itemCount: filteredCollectibles.length,
                        itemBuilder: (context, index) {
                          return _PremiumCollectibleCard(
                            collectible: filteredCollectibles[index],
                            shimmerController: _shimmerController,
                            delay: index * 100,
                          );
                        },
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF8B5CF6).withOpacity(0.2),
                  const Color(0xFFEC4899).withOpacity(0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Icon(
              Icons.collections_bookmark_rounded,
              size: 50,
              color: Color(0xFF8B5CF6),
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'No Collectibles Yet',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Finish in the top 5% of weekly leaderboards to earn collectibles!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 15,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          // How to earn section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Column(
              children: [
                _buildHowToEarnItem(
                  Icons.emoji_events_rounded,
                  'Top 5%',
                  'Finish in the top 5% weekly',
                  const [Color(0xFFFFD700), Color(0xFFF59E0B)],
                ),
                const SizedBox(height: 16),
                _buildHowToEarnItem(
                  Icons.local_fire_department_rounded,
                  'Hot Streaks',
                  'Win 5+ predictions in a row',
                  const [Color(0xFFFF6B35), Color(0xFFE74C3C)],
                ),
                const SizedBox(height: 16),
                _buildHowToEarnItem(
                  Icons.event_rounded,
                  'Special Events',
                  'Participate in limited-time events',
                  const [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildHowToEarnItem(
      IconData icon, String title, String description, List<Color> colors) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: colors.first.withOpacity(0.3),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsHeader(List<Collectible> collectibles) {
    final legendaryCount =
        collectibles.where((c) => c.rarity == CollectibleRarity.legendary).length;
    final epicCount =
        collectibles.where((c) => c.rarity == CollectibleRarity.epic).length;
    final rareCount =
        collectibles.where((c) => c.rarity == CollectibleRarity.rare).length;
    final commonCount =
        collectibles.where((c) => c.rarity == CollectibleRarity.common).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF8B5CF6).withOpacity(0.15),
            const Color(0xFFEC4899).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Total', '${collectibles.length}', null),
          _buildStatItem('Legendary', '$legendaryCount', const Color(0xFFFFD700)),
          _buildStatItem('Epic', '$epicCount', const Color(0xFF8B5CF6)),
          _buildStatItem('Rare', '$rareCount', const Color(0xFF3B82F6)),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: -0.1, end: 0);
  }

  Widget _buildStatItem(String label, String value, Color? color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color ?? AppColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildRarityFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          _buildFilterChip(null, 'All'),
          const SizedBox(width: 10),
          _buildFilterChip(CollectibleRarity.legendary, 'Legendary'),
          const SizedBox(width: 10),
          _buildFilterChip(CollectibleRarity.epic, 'Epic'),
          const SizedBox(width: 10),
          _buildFilterChip(CollectibleRarity.rare, 'Rare'),
          const SizedBox(width: 10),
          _buildFilterChip(CollectibleRarity.common, 'Common'),
        ],
      ),
    ).animate(delay: 200.ms).fadeIn();
  }

  Widget _buildFilterChip(CollectibleRarity? rarity, String label) {
    final isSelected = _selectedRarity == rarity;
    final Color color;
    if (rarity == null) {
      color = const Color(0xFF8B5CF6);
    } else {
      switch (rarity) {
        case CollectibleRarity.legendary:
          color = const Color(0xFFFFD700);
        case CollectibleRarity.epic:
          color = const Color(0xFF8B5CF6);
        case CollectibleRarity.rare:
          color = const Color(0xFF3B82F6);
        case CollectibleRarity.common:
          color = const Color(0xFF6B7280);
      }
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _selectedRarity = rarity;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected ? LinearGradient(colors: [color, color.withOpacity(0.7)]) : null,
          color: isSelected ? null : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : AppColors.borderSubtle,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.35),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

/// Premium collectible card with holographic effect
class _PremiumCollectibleCard extends StatelessWidget {
  final Collectible collectible;
  final AnimationController shimmerController;
  final int delay;

  const _PremiumCollectibleCard({
    required this.collectible,
    required this.shimmerController,
    this.delay = 0,
  });

  @override
  Widget build(BuildContext context) {
    final rarityColor = Color(collectible.rarityColor);
    final isLegendary = collectible.rarity == CollectibleRarity.legendary;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _showCollectibleDetails(context);
      },
      child: AnimatedBuilder(
        animation: shimmerController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: rarityColor.withOpacity(isLegendary ? 0.6 : 0.4),
                width: isLegendary ? 2 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: rarityColor.withOpacity(0.25),
                  blurRadius: isLegendary ? 20 : 12,
                  spreadRadius: isLegendary ? 2 : 1,
                ),
              ],
            ),
            child: Stack(
              children: [
                // Holographic shimmer for legendary
                if (isLegendary)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: ShaderMask(
                        shaderCallback: (bounds) {
                          return LinearGradient(
                            begin: Alignment(-2 + shimmerController.value * 4, -0.5),
                            end: Alignment(-1 + shimmerController.value * 4, 0.5),
                            colors: const [
                              Colors.transparent,
                              Colors.white10,
                              Colors.transparent,
                            ],
                          ).createShader(bounds);
                        },
                        blendMode: BlendMode.srcATop,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                rarityColor.withOpacity(0.1),
                                Colors.white.withOpacity(0.05),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                // Content
                Column(
                  children: [
                    // Rarity banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            rarityColor.withOpacity(0.3),
                            rarityColor.withOpacity(0.15),
                          ],
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (isLegendary) ...[
                            Icon(Icons.auto_awesome,
                                color: rarityColor, size: 12),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            collectible.rarityDisplay.toUpperCase(),
                            style: TextStyle(
                              color: rarityColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                            ),
                          ),
                          if (isLegendary) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.auto_awesome,
                                color: rarityColor, size: 12),
                          ],
                        ],
                      ),
                    ),

                    // Icon
                    Expanded(
                      child: Center(
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                rarityColor.withOpacity(0.2),
                                rarityColor.withOpacity(0.1),
                              ],
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: rarityColor.withOpacity(0.3),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: rarityColor.withOpacity(0.2),
                                blurRadius: 12,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Icon(
                            _getIconForType(collectible.type),
                            color: rarityColor,
                            size: 36,
                          ),
                        ),
                      ),
                    ),

                    // Info
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                      child: Column(
                        children: [
                          Text(
                            collectible.name,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (collectible.xpBonus != null) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF10B981).withOpacity(0.2),
                                    const Color(0xFF059669).withOpacity(0.1),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFF10B981).withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.bolt_rounded,
                                      color: Color(0xFF10B981), size: 12),
                                  const SizedBox(width: 4),
                                  Text(
                                    '+${(collectible.xpBonus! * 100).toInt()}% XP',
                                    style: const TextStyle(
                                      color: Color(0xFF10B981),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    ).animate(delay: Duration(milliseconds: delay)).fadeIn().scale(
          begin: const Offset(0.9, 0.9),
          end: const Offset(1, 1),
          curve: Curves.easeOutBack,
        );
  }

  IconData _getIconForType(CollectibleType type) {
    switch (type) {
      case CollectibleType.player:
        return Icons.person_rounded;
      case CollectibleType.team:
        return Icons.groups_rounded;
      case CollectibleType.achievement:
        return Icons.emoji_events_rounded;
      case CollectibleType.event:
        return Icons.stadium_rounded;
    }
  }

  void _showCollectibleDetails(BuildContext context) {
    final rarityColor = Color(collectible.rarityColor);
    final isLegendary = collectible.rarity == CollectibleRarity.legendary;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: rarityColor.withOpacity(0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: rarityColor.withOpacity(0.2),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: [
                    // Icon
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            rarityColor.withOpacity(0.2),
                            rarityColor.withOpacity(0.1),
                          ],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: rarityColor,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: rarityColor.withOpacity(0.35),
                            blurRadius: 25,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: Icon(
                        _getIconForType(collectible.type),
                        color: rarityColor,
                        size: 55,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Rarity badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [rarityColor, rarityColor.withOpacity(0.7)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: rarityColor.withOpacity(0.4),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isLegendary) ...[
                            const Icon(Icons.auto_awesome,
                                color: Colors.white, size: 14),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            collectible.rarityDisplay.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Name
                    Text(
                      collectible.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 10),

                    // Description
                    Text(
                      collectible.description,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 15,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    if (collectible.xpBonus != null) ...[
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF10B981).withOpacity(0.15),
                              const Color(0xFF059669).withOpacity(0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF10B981).withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.bolt_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'XP BONUS',
                                  style: TextStyle(
                                    color: Color(0xFF10B981),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1,
                                  ),
                                ),
                                Text(
                                  '+${(collectible.xpBonus! * 100).toInt()}% on related predictions',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 28),

                    // Earned date
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_today_rounded,
                            color: AppColors.textMuted, size: 14),
                        const SizedBox(width: 8),
                        Text(
                          'Earned ${_formatDate(collectible.earnedAt)}',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Close button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: rarityColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Close',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;

    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    if (difference < 7) return '$difference days ago';

    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
