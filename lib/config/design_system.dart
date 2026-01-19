import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme.dart';

/// Blue Aura Design System - Liquid Glass Components
class DesignSystem {
  // ===== SPACING =====
  static const double spacingXxs = 2.0;
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 12.0;
  static const double spacingLg = 16.0;
  static const double spacingXl = 20.0;
  static const double spacingXxl = 24.0;
  static const double spacingXxxl = 32.0;
  static const double spacingHuge = 48.0;

  // ===== BORDER RADIUS - Round & Clean =====
  static const double radiusXs = 4.0;
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXl = 20.0;
  static const double radiusXxl = 24.0;
  static const double radiusXxxl = 32.0;
  static const double radiusRound = 9999.0;

  // ===== GLASS EFFECT DECORATIONS =====

  /// Primary glass card decoration - Liquid Glass effect
  static BoxDecoration glassDecoration({
    double opacity = 0.6,
    double borderOpacity = 0.3,
    double radius = radiusXxl,
    bool hasGlow = true,
  }) {
    return BoxDecoration(
      color: const Color(0xFF1E3A5F).withOpacity(opacity),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: const Color(0xFF00A3FF).withOpacity(borderOpacity),
        width: 1,
      ),
      boxShadow: hasGlow
          ? [
              BoxShadow(
                color: const Color(0xFF00D4FF).withOpacity(0.15),
                blurRadius: 30,
                offset: const Offset(0, 0),
              ),
              // Inner highlight simulation
              BoxShadow(
                color: Colors.white.withOpacity(0.05),
                blurRadius: 1,
                offset: const Offset(0, 1),
              ),
            ]
          : null,
    );
  }

  /// Elevated glass decoration - for prominent cards/modals
  static BoxDecoration glassElevated({
    double opacity = 0.7,
    double radius = radiusXxl,
  }) {
    return BoxDecoration(
      color: const Color(0xFF1E3A5F).withOpacity(opacity),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: const Color(0xFF00D4FF).withOpacity(0.4),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF00D4FF).withOpacity(0.2),
          blurRadius: 40,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.3),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  /// Subtle glass decoration - for background sections
  static BoxDecoration glassSubtle({
    double opacity = 0.4,
    double radius = radiusXl,
  }) {
    return BoxDecoration(
      color: const Color(0xFF1E3A5F).withOpacity(opacity),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: Colors.white.withOpacity(0.1),
        width: 1,
      ),
    );
  }

  /// Active/Selected glass decoration
  static BoxDecoration glassActive({
    double radius = radiusXxl,
  }) {
    return BoxDecoration(
      color: const Color(0xFF1E3A5F).withOpacity(0.8),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: const Color(0xFF0066FF).withOpacity(0.5),
        width: 2,
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF0066FF).withOpacity(0.3),
          blurRadius: 20,
          offset: const Offset(0, 0),
        ),
      ],
    );
  }

  /// Live game glass decoration
  static BoxDecoration glassLive({
    double radius = radiusXxl,
  }) {
    return BoxDecoration(
      color: const Color(0xFF1E3A5F).withOpacity(0.6),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: const Color(0xFFFF416C).withOpacity(0.5),
        width: 2,
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFFFF416C).withOpacity(0.25),
          blurRadius: 25,
          offset: const Offset(0, 0),
        ),
      ],
    );
  }

  /// Won state glass decoration
  static BoxDecoration glassWon({
    double radius = radiusXl,
  }) {
    return BoxDecoration(
      color: const Color(0xFF1E3A5F).withOpacity(0.6),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: const Color(0xFF00FF7F).withOpacity(0.5),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF00FF7F).withOpacity(0.2),
          blurRadius: 20,
          offset: const Offset(0, 0),
        ),
      ],
    );
  }

  /// Lost state glass decoration
  static BoxDecoration glassLost({
    double radius = radiusXl,
  }) {
    return BoxDecoration(
      color: const Color(0xFF1E3A5F).withOpacity(0.4),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: const Color(0xFFFF3B30).withOpacity(0.3),
        width: 1,
      ),
    );
  }

  // ===== LEGACY CARD DECORATIONS (updated for Blue Aura) =====

  static BoxDecoration cardDecoration({
    Color? backgroundColor,
    bool hasBorder = true,
    double borderRadius = radiusXxl,
    Color? borderColor,
  }) {
    return BoxDecoration(
      color: backgroundColor ?? AppColors.glassBackground(0.6),
      borderRadius: BorderRadius.circular(borderRadius),
      border: hasBorder
          ? Border.all(color: borderColor ?? AppColors.borderGlow)
          : null,
    );
  }

  static BoxDecoration cardDecorationCustom({
    Color? backgroundColor,
    bool hasBorder = true,
    BorderRadius? borderRadius,
    Color? borderColor,
  }) {
    return BoxDecoration(
      color: backgroundColor ?? AppColors.glassBackground(0.6),
      borderRadius: borderRadius ?? BorderRadius.circular(radiusXxl),
      border: hasBorder
          ? Border.all(color: borderColor ?? AppColors.borderGlow)
          : null,
    );
  }

  // ===== BUTTON DECORATIONS =====

  /// Primary CTA button decoration
  static BoxDecoration buttonPrimary({
    double radius = radiusXxl,
  }) {
    return BoxDecoration(
      gradient: AppColors.primaryGradient,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: AppColors.primaryGlow,
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  /// Secondary button decoration
  static BoxDecoration buttonSecondary({
    double radius = radiusXl,
  }) {
    return BoxDecoration(
      color: AppColors.glassBackground(0.6),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: AppColors.borderGlow,
        width: 1,
      ),
    );
  }

  /// Outline button decoration
  static BoxDecoration buttonOutline({
    double radius = radiusXl,
    Color? borderColor,
  }) {
    return BoxDecoration(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor ?? AppColors.accentCyan,
        width: 1.5,
      ),
    );
  }

  // ===== SPECIAL DECORATIONS =====

  /// Section header decoration with gradient
  static BoxDecoration sectionHeaderDecoration(Color accentColor) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [accentColor.withOpacity(0.2), Colors.transparent],
      ),
      borderRadius: BorderRadius.circular(radiusSmall),
    );
  }

  /// Header background decoration
  static BoxDecoration headerBackgroundDecoration({
    BorderRadius? borderRadius,
  }) {
    return BoxDecoration(
      color: Colors.white.withOpacity(0.03),
      borderRadius: borderRadius ??
          const BorderRadius.vertical(top: Radius.circular(radiusXxl)),
    );
  }

  /// Live badge decoration with glow
  static BoxDecoration liveBadgeDecoration() {
    return BoxDecoration(
      gradient: AppColors.liveGradient,
      borderRadius: BorderRadius.circular(radiusRound),
      boxShadow: [
        BoxShadow(
          color: AppColors.liveGlow,
          blurRadius: 15,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  /// Team color gradient decoration
  static BoxDecoration teamGradientDecoration(Color teamColor) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          teamColor.withOpacity(0.2),
          teamColor.withOpacity(0.05),
        ],
      ),
      borderRadius: BorderRadius.circular(radiusXxl),
      border: Border.all(color: teamColor.withOpacity(0.3)),
    );
  }

  /// Gold/Coins decoration (kept for rewards)
  static BoxDecoration goldDecoration({
    double radius = radiusXxl,
  }) {
    return BoxDecoration(
      gradient: AppColors.goldGradient,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: AppColors.goldGlow,
          blurRadius: 25,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  // ===== UI ELEMENTS =====

  /// Accent bar for section headers
  static Widget accentBar(Color color, {double height = 16, double width = 4}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.5),
            blurRadius: 8,
          ),
        ],
      ),
    );
  }

  /// Pulsing dot for live indicator
  static Widget pulsingDot({
    Color color = const Color(0xFFFF416C),
    double size = 8,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.6),
            blurRadius: 6,
          ),
        ],
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .fadeIn(duration: 800.ms)
        .then()
        .fadeOut(duration: 800.ms);
  }

  /// Timeline dot
  static Widget timelineDot(Color color, {double size = 12}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.5),
            blurRadius: 10,
          ),
        ],
      ),
    );
  }

  /// Timeline connector
  static Widget timelineConnector({double height = 80, double width = 2}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withOpacity(0.2),
            Colors.white.withOpacity(0.05),
          ],
        ),
      ),
    );
  }

  /// Modal handle bar
  static Widget handleBar() {
    return Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.only(top: 12, bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  /// Glass blur wrapper widget
  static Widget glassBlur({
    required Widget child,
    double blur = 20,
    double opacity = 0.6,
    double radius = radiusXxl,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: glassDecoration(opacity: opacity, radius: radius),
          child: child,
        ),
      ),
    );
  }
}

/// Animation extensions for consistent animations
extension AnimateListItem on Widget {
  /// Standard list item animation with staggered delay
  Widget animateListItem(int index, {int delayMs = 50}) {
    return animate(delay: Duration(milliseconds: index * delayMs))
        .fadeIn(duration: 250.ms, curve: Curves.easeOut)
        .slideX(begin: -0.05, end: 0);
  }

  /// Card fade in animation
  Widget animateCard({int delayMs = 0}) {
    return animate(delay: Duration(milliseconds: delayMs))
        .fadeIn(duration: 250.ms, curve: Curves.easeOut)
        .slideY(begin: 0.03, end: 0);
  }

  /// Section fade in
  Widget animateSection({int delayMs = 0}) {
    return animate(delay: Duration(milliseconds: delayMs))
        .fadeIn(duration: 300.ms);
  }

  /// Scale in effect for emphasis
  Widget animateScaleIn({int delayMs = 0}) {
    return animate(delay: Duration(milliseconds: delayMs))
        .fadeIn(duration: 200.ms)
        .scale(
          begin: const Offset(0.95, 0.95),
          end: const Offset(1, 1),
          curve: Curves.easeOutBack,
        );
  }

  /// Glow pulse animation
  Widget animateGlowPulse({int delayMs = 0}) {
    return animate(
      onPlay: (c) => c.repeat(reverse: true),
      delay: Duration(milliseconds: delayMs),
    ).shimmer(
      duration: 1500.ms,
      color: const Color(0xFF00D4FF).withOpacity(0.3),
    );
  }
}

/// Typography helpers - Blue Aura style
class AppTypography {
  // Score display (large emphasis)
  static TextStyle score({Color? color, double fontSize = 48}) {
    return GoogleFonts.publicSans(
      color: color ?? Colors.white,
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      height: 1,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  // Section title - Lora Italic Bold
  static TextStyle sectionTitle({Color? color}) {
    return GoogleFonts.lora(
      color: color ?? Colors.white,
      fontSize: 20,
      fontWeight: FontWeight.w600,
      fontStyle: FontStyle.italic,
    );
  }

  // Category label (uppercase)
  static TextStyle categoryLabel({Color? color}) {
    return GoogleFonts.publicSans(
      color: color ?? Colors.white.withOpacity(0.7),
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
    );
  }

  // Stat value (emphasis) - now cyan
  static TextStyle statValue({Color? color, double fontSize = 24}) {
    return GoogleFonts.publicSans(
      color: color ?? AppColors.accentCyan,
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
    );
  }

  // Player name
  static TextStyle playerName({Color? color}) {
    return GoogleFonts.publicSans(
      color: color ?? Colors.white,
      fontSize: 14,
      fontWeight: FontWeight.w600,
    );
  }

  // Muted label
  static TextStyle mutedLabel({Color? color, double fontSize = 12}) {
    return GoogleFonts.publicSans(
      color: color ?? Colors.white.withOpacity(0.5),
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
    );
  }

  // Team abbreviation
  static TextStyle teamAbbr({Color? color}) {
    return GoogleFonts.publicSans(
      color: color ?? Colors.white.withOpacity(0.6),
      fontSize: 11,
      fontWeight: FontWeight.w600,
    );
  }

  // Odds display
  static TextStyle odds({Color? color, bool selected = false}) {
    return GoogleFonts.publicSans(
      color: selected ? Colors.white : (color ?? AppColors.accentCyan),
      fontSize: 16,
      fontWeight: FontWeight.w600,
    );
  }

  // Button text
  static TextStyle button({Color? color, double fontSize = 18}) {
    return GoogleFonts.publicSans(
      color: color ?? Colors.white,
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
    );
  }

  // Page title - Lora Italic Bold
  static TextStyle pageTitle({Color? color}) {
    return GoogleFonts.lora(
      color: color ?? Colors.white,
      fontSize: 32,
      fontWeight: FontWeight.w600,
      fontStyle: FontStyle.italic,
    );
  }

  // Heading 2 - Lora Italic Bold
  static TextStyle heading2({Color? color}) {
    return GoogleFonts.lora(
      color: color ?? Colors.white,
      fontSize: 24,
      fontWeight: FontWeight.w600,
      fontStyle: FontStyle.italic,
    );
  }
}

/// Alias for backward compatibility with existing widgets
typedef AppDecorations = DesignSystem;
