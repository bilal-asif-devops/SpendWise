import 'package:flutter/material.dart';

class AppColors {
  // Brand Colors matching Figma Design
  static const Color primaryNavy = Color(0xFF1A365D);
  static const Color darkCard = Color(0xFF1E293B);
  static const Color accentGreen = Color(0xFF10B981);
  static const Color alertAmber = Color(0xFFF59E0B);
  static const Color alertRed = Color(0xFFEF4444);

  // Neutral Tones
  static const Color background = Color(0xFFF8FAFC);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color chipBackground = Color(0xFFF1F5F9);

  // Theme-adaptive helpers
  static Color backgroundOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF0F172A)
          : AppColors.background;

  static Color surfaceOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkCard
          : AppColors.surfaceWhite;

  static Color textDarkOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFF8FAFC)
          : AppColors.textDark;

  static Color textMutedOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF94A3B8)
          : AppColors.textMuted;

  static Color borderOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF334155)
          : AppColors.borderLight;
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryNavy,
        brightness: Brightness.light,
        primary: AppColors.primaryNavy,
        secondary: AppColors.accentGreen,
        surface: AppColors.surfaceWhite,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.textDark),
        titleTextStyle: TextStyle(
          color: AppColors.textDark,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      fontFamily: 'Roboto',
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accentGreen,
        secondary: AppColors.accentGreen,
        surface: AppColors.darkCard,
        onSurface: Color(0xFFF8FAFC),
        outline: Color(0xFF334155),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0F172A),
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Color(0xFFF8FAFC)),
        titleTextStyle: TextStyle(
          color: Color(0xFFF8FAFC),
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFF334155)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.darkCard,
        indicatorColor: AppColors.accentGreen.withValues(alpha: 0.2),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.accentGreen);
          }
          return const IconThemeData(color: Color(0xFF94A3B8));
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: AppColors.accentGreen,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            );
          }
          return const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 12,
          );
        }),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.darkCard,
        titleTextStyle: TextStyle(
          color: Color(0xFFF8FAFC),
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF334155),
      ),
      fontFamily: 'Roboto',
    );
  }
}
