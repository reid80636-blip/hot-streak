import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../config/team_logos.dart';
import '../../config/theme.dart';

/// A widget that displays a team logo or falls back to initials
class TeamLogo extends StatelessWidget {
  final String teamName;
  final double size;
  final Color? backgroundColor;
  final Color? textColor;
  final String? logoUrl; // Direct URL from ESPN (takes priority)

  const TeamLogo({
    super.key,
    required this.teamName,
    this.size = 32,
    this.backgroundColor,
    this.textColor,
    this.logoUrl,
  });

  @override
  Widget build(BuildContext context) {
    // Priority: 1) ESPN-provided URL, 2) Static map lookup, 3) Initials
    final url = logoUrl ?? TeamLogos.getLogoUrl(teamName);

    if (url != null) {
      return _buildLogoImage(url);
    }

    return _buildInitialsAvatar();
  }

  Widget _buildLogoImage(String url) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.cardBackground,
        borderRadius: BorderRadius.circular(size / 4),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.contain,
        placeholder: (context, url) => _buildLoadingPlaceholder(),
        errorWidget: (context, url, error) => _buildInitialsAvatar(),
      ),
    );
  }

  Widget _buildLoadingPlaceholder() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.cardBackground,
        borderRadius: BorderRadius.circular(size / 4),
      ),
      child: Center(
        child: SizedBox(
          width: size * 0.5,
          height: size * 0.5,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.textSubtle,
          ),
        ),
      ),
    );
  }

  Widget _buildInitialsAvatar() {
    final initials = TeamLogos.getInitials(teamName);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? _getTeamColor(),
        borderRadius: BorderRadius.circular(size / 4),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: textColor ?? Colors.white,
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  /// Generate a consistent color based on team name
  Color _getTeamColor() {
    final hash = teamName.hashCode;
    final colors = [
      AppColors.accent,
      AppColors.accentGreen,
      AppColors.orange,
      AppColors.accentRed,
      const Color(0xFF9B59B6), // Purple
      const Color(0xFF3498DB), // Blue
      const Color(0xFF1ABC9C), // Teal
      const Color(0xFFE67E22), // Orange
    ];
    return colors[hash.abs() % colors.length];
  }
}

/// A smaller circular team logo for compact displays
class TeamLogoCircle extends StatelessWidget {
  final String teamName;
  final double size;
  final String? logoUrl; // Direct URL from ESPN (takes priority)

  const TeamLogoCircle({
    super.key,
    required this.teamName,
    this.size = 24,
    this.logoUrl,
  });

  @override
  Widget build(BuildContext context) {
    // Priority: 1) ESPN-provided URL, 2) Static map lookup, 3) Initials
    final url = logoUrl ?? TeamLogos.getLogoUrl(teamName);

    if (url != null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.borderSubtle),
        ),
        clipBehavior: Clip.antiAlias,
        child: CachedNetworkImage(
          imageUrl: url,
          width: size,
          height: size,
          fit: BoxFit.contain,
          placeholder: (context, url) => _buildPlaceholder(),
          errorWidget: (context, url, error) => _buildInitials(),
        ),
      );
    }

    return _buildInitials();
  }

  Widget _buildPlaceholder() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildInitials() {
    final initials = TeamLogos.getInitials(teamName);
    final hash = teamName.hashCode;
    final colors = [
      AppColors.accent,
      AppColors.accentGreen,
      AppColors.orange,
      AppColors.accentRed,
    ];
    final color = colors[hash.abs() % colors.length];

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: color,
            fontSize: size * 0.35,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
