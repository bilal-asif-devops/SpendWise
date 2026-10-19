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
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryNavy,
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
}
