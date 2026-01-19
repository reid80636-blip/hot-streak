import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/theme.dart';
import '../../config/design_system.dart';

class PlayerPickerSheet extends StatefulWidget {
  const PlayerPickerSheet({super.key});

  @override
  State<PlayerPickerSheet> createState() => _PlayerPickerSheetState();
}

class _PlayerPickerSheetState extends State<PlayerPickerSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _teamController = TextEditingController();
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _teamFocus = FocusNode();

  bool get _canConfirm =>
      _nameController.text.trim().isNotEmpty &&
      _teamController.text.trim().isNotEmpty;

  // Popular players for quick selection
  static const _popularPlayers = [
    {'name': 'LeBron James', 'team': 'Los Angeles Lakers'},
    {'name': 'Stephen Curry', 'team': 'Golden State Warriors'},
    {'name': 'Giannis Antetokounmpo', 'team': 'Milwaukee Bucks'},
    {'name': 'Luka Doncic', 'team': 'Dallas Mavericks'},
    {'name': 'Patrick Mahomes', 'team': 'Kansas City Chiefs'},
    {'name': 'Jalen Hurts', 'team': 'Philadelphia Eagles'},
    {'name': 'Shohei Ohtani', 'team': 'Los Angeles Dodgers'},
    {'name': 'Aaron Judge', 'team': 'New York Yankees'},
    {'name': 'Connor McDavid', 'team': 'Edmonton Oilers'},
    {'name': 'Lionel Messi', 'team': 'Inter Miami'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nameFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _teamController.dispose();
    _nameFocus.dispose();
    _teamFocus.dispose();
    super.dispose();
  }

  void _selectPlayer(String name, String team) {
    HapticFeedback.selectionClick();
    Navigator.of(context).pop({'name': name, 'team': team});
  }

  void _confirmSelection() {
    if (!_canConfirm) return;
    _selectPlayer(
      _nameController.text.trim(),
      _teamController.text.trim(),
    );
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

              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name input
                      _buildInputField(
                        controller: _nameController,
                        focusNode: _nameFocus,
                        label: 'Player Name',
                        hint: 'e.g., LeBron James',
                        onSubmitted: (_) => _teamFocus.requestFocus(),
                      ),

                      const SizedBox(height: AppSpacing.lg),

                      // Team input
                      _buildInputField(
                        controller: _teamController,
                        focusNode: _teamFocus,
                        label: 'Team',
                        hint: 'e.g., Los Angeles Lakers',
                        onSubmitted: (_) {
                          if (_canConfirm) _confirmSelection();
                        },
                      ),

                      const SizedBox(height: AppSpacing.xl),

                      // Confirm button
                      _buildConfirmButton(),

                      const SizedBox(height: AppSpacing.xxl),

                      // Popular players
                      _buildPopularSection(),

                      const SizedBox(height: AppSpacing.xl),
                    ],
                  ),
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
                'Select Player',
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

  Widget _buildInputField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required ValueChanged<String> onSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.textSecondaryOp,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          decoration: DesignSystem.glassDecoration(
            opacity: 0.4,
            borderOpacity: 0.2,
            radius: DesignSystem.radiusLarge,
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
            ),
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: AppColors.textSubtle),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(AppSpacing.lg),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: onSubmitted,
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _canConfirm ? _confirmSelection : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _canConfirm
              ? AppColors.accent
              : AppColors.glassBackground(0.3),
          foregroundColor: _canConfirm ? Colors.white : AppColors.textSubtle,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignSystem.radiusLarge),
          ),
          elevation: 0,
        ),
        child: const Text(
          'Select Player',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildPopularSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Popular Players',
          style: TextStyle(
            color: AppColors.textSecondaryOp,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: _popularPlayers.map((player) {
            return GestureDetector(
              onTap: () => _selectPlayer(
                player['name']!,
                player['team']!,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.glassBackground(0.4),
                  borderRadius: BorderRadius.circular(AppRadius.round),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.person,
                      size: 14,
                      color: AppColors.accentCyan,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      player['name']!,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
