import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Blue Aura Theme - Liquid Glass Design System
class AppColors {
  // ===== PRIMARY COLORS - Blue Aura Palette =====
  static const Color primaryDark = Color(0xFF0A1628);    // Deep Blue - app background
  static const Color primaryLight = Color(0xFF0A1628);
  static const Color cardBackground = Color(0xFF1E3A5F); // Glass Blue - card surfaces
  static const Color surfaceColor = Color(0xFF1A3A5C);   // Soft Blue - secondary surfaces
  static const Color glassBlue = Color(0xFF1E3A5F);      // Glass overlay color
  static const Color iceBlue = Color(0xFFE0F4FF);        // Light accents

  // ===== ACCENT COLORS - Blue Aura =====
  static const Color accent = Color(0xFF0066FF);         // Primary Blue - main CTAs
  static const Color accentLight = Color(0xFF00A3FF);    // Glow Blue - highlights
  static const Color accentCyan = Color(0xFF00D4FF);     // Accent Cyan - bright accents
  static const Color accentGreen = Color(0xFF00FF7F);    // Success Green - wins
  static const Color accentRed = Color(0xFFFF3B30);      // Error Red - losses
  static const Color liveRed = Color(0xFFFF416C);        // Live indicators

  // ===== GOLD - Only for coins/rewards =====
  static const Color gold = Color(0xFFFFD700);
  static const Color orange = Color(0xFFFFA500);

  // ===== BORDER COLORS =====
  static Color get borderSubtle => Colors.white.withOpacity(0.05);
  static Color get borderMedium => Colors.white.withOpacity(0.1);
  static Color get borderStrong => Colors.white.withOpacity(0.2);
  static Color get borderGlow => const Color(0xFF00A3FF).withOpacity(0.3);     // Glass effect borders
  static Color get borderCyan => const Color(0xFF00D4FF).withOpacity(0.3);     // Cyan borders

  // ===== TEXT COLORS - Opacity Hierarchy =====
  static const Color textPrimary = Color(0xFFFFFFFF);
  static Color get textEmphasis => Colors.white.withOpacity(0.95);
  static Color get textSecondaryOp => Colors.white.withOpacity(0.70);
  static Color get textMutedOp => Colors.white.withOpacity(0.50);
  static Color get textSubtle => Colors.white.withOpacity(0.40);
  static Color get textDim => Colors.white.withOpacity(0.30);
  static Color get textDisabled => Colors.white.withOpacity(0.30);

  // Legacy text colors (for compatibility)
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color textMuted = Color(0xFF808080);

  // ===== SPORT-SPECIFIC COLORS =====
  static const Color nfl = Color(0xFF013369);
  static const Color nba = Color(0xFFC8102E);
  static const Color nhl = Color(0xFF000000);
  static const Color mlb = Color(0xFF002D72);
  static const Color soccer = Color(0xFF38003C);
  static const Color ncaaf = Color(0xFF8B4513);
  static const Color ncaab = Color(0xFFFF6B00);

  // ===== GRADIENTS - Blue Aura =====
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF0066FF), Color(0xFF00A3FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cyanGradient = LinearGradient(
    colors: [Color(0xFF00A3FF), Color(0xFF00D4FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Gold gradient - only for coins/rewards
  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient winGradient = LinearGradient(
    colors: [Color(0xFF00FF7F), Color(0xFF00D68F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient lossGradient = LinearGradient(
    colors: [Color(0xFFFF3B30), Color(0xFFD32F2F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient liveGradient = LinearGradient(
    colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)],
  );

  static const LinearGradient deepOceanGradient = LinearGradient(
    colors: [Color(0xFF0A1628), Color(0xFF1E3A5F)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ===== GLOW EFFECTS =====
  static Color get liveGlow => const Color(0xFFFF416C).withOpacity(0.4);
  static Color get primaryGlow => const Color(0xFF0066FF).withOpacity(0.4);
  static Color get cyanGlow => const Color(0xFF00D4FF).withOpacity(0.3);
  static Color get successGlow => const Color(0xFF00FF7F).withOpacity(0.35);
  static Color get goldGlow => const Color(0xFFFFD700).withOpacity(0.4);

  // ===== GLASS EFFECT COLORS =====
  static Color glassBackground([double opacity = 0.6]) =>
      const Color(0xFF1E3A5F).withOpacity(opacity);
  static Color glassBorder([double opacity = 0.3]) =>
      const Color(0xFF00A3FF).withOpacity(opacity);
}

/// Border Radius constants - Round & Clean
class AppRadius {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double round = 9999;  // Pill shape
}

/// Spacing constants
class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 48;
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.primaryDark,
      primaryColor: AppColors.accent,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accent,
        secondary: AppColors.accentCyan,
        surface: AppColors.cardBackground,
        error: AppColors.accentRed,
        onPrimary: Color(0xFFFFFFFF),
        onSecondary: AppColors.textPrimary,
        onSurface: AppColors.textPrimary,
        onError: AppColors.textPrimary,
      ),
      // Typography - Lora for headers (italic), Public Sans for body
      textTheme: GoogleFonts.loraTextTheme(
        TextTheme(
          // Display styles - Italic Bold for headers
          displayLarge: GoogleFonts.lora(
            fontSize: 48,
            fontWeight: FontWeight.w600,
            fontStyle: FontStyle.italic,
            color: AppColors.textPrimary,
          ),
          displayMedium: GoogleFonts.lora(
            fontSize: 40,
            fontWeight: FontWeight.w600,
            fontStyle: FontStyle.italic,
            color: AppColors.textPrimary,
          ),
          displaySmall: GoogleFonts.lora(
            fontSize: 32,
            fontWeight: FontWeight.w600,
            fontStyle: FontStyle.italic,
            color: AppColors.textPrimary,
          ),
          // Headline styles
          headlineLarge: GoogleFonts.lora(
            fontSize: 32,
            fontWeight: FontWeight.w600,
            fontStyle: FontStyle.italic,
            color: AppColors.textPrimary,
          ),
          headlineMedium: GoogleFonts.lora(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          headlineSmall: GoogleFonts.lora(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          // Title styles - Bold (non-italic)
          titleLarge: GoogleFonts.publicSans(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          titleMedium: GoogleFonts.publicSans(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          titleSmall: GoogleFonts.publicSans(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          // Body styles
          bodyLarge: GoogleFonts.publicSans(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          bodyMedium: GoogleFonts.publicSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
          bodySmall: GoogleFonts.publicSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
          // Label styles
          labelLarge: GoogleFonts.publicSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          labelMedium: GoogleFonts.publicSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          labelSmall: GoogleFonts.publicSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primaryDark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: GoogleFonts.lora(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          fontStyle: FontStyle.italic,
          color: AppColors.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xxl),
          side: BorderSide(color: AppColors.borderGlow),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xxl),
          ),
          textStyle: GoogleFonts.publicSans(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accentCyan,
          side: BorderSide(color: AppColors.borderGlow),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.glassBackground(0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.borderMedium),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.borderMedium),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.accentLight, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.accentRed, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: TextStyle(color: AppColors.textSubtle),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.primaryDark,
        selectedItemColor: AppColors.accentCyan,
        unselectedItemColor: AppColors.textMutedOp,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.glassBackground(0.4),
        selectedColor: AppColors.accent,
        labelStyle: GoogleFonts.publicSans(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        side: BorderSide(color: AppColors.borderGlow),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.round),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.borderSubtle,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.cardBackground,
        contentTextStyle: GoogleFonts.publicSans(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.primaryDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xxl),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.primaryDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxxl)),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.accentCyan,
        unselectedLabelColor: AppColors.textMutedOp,
        indicatorColor: AppColors.accentCyan,
        dividerColor: AppColors.borderSubtle,
      ),
    );
  }
}
