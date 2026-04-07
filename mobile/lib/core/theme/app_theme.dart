import 'package:flutter/material.dart';

class AppTheme {
  static const Color pine = Color(0xFF1F5C57);
  static const Color pineDeep = Color(0xFF153C3A);
  static const Color cream = Color(0xFFF8F1E7);
  static const Color sand = Color(0xFFE7D8C6);
  static const Color clay = Color(0xFFBF6D4F);
  static const Color ink = Color(0xFF213330);
  static const Color mist = Color(0xFFF4EFE8);

  static ThemeData light() {
    return byId('heritage');
  }

  static ThemeData byId(String themeId) {
    switch (themeId) {
      case 'ocean':
        return _buildTheme(
          primary: const Color(0xFF0F4C81),
          primaryDeep: const Color(0xFF0A3559),
          secondary: const Color(0xFF2A9D8F),
          ink: const Color(0xFF17324D),
          cream: const Color(0xFFEAF4F4),
          sand: const Color(0xFFCAE7E2),
          mist: const Color(0xFFF5FAFA),
        );
      case 'sunset':
        return _buildTheme(
          primary: const Color(0xFFA33B20),
          primaryDeep: const Color(0xFF6C2412),
          secondary: const Color(0xFFF4A261),
          ink: const Color(0xFF4C251B),
          cream: const Color(0xFFFEF3E7),
          sand: const Color(0xFFF7D7B8),
          mist: const Color(0xFFFFF8F1),
        );
      case 'forest':
        return _buildTheme(
          primary: const Color(0xFF2F5D50),
          primaryDeep: const Color(0xFF1E3E35),
          secondary: const Color(0xFF7A9E7E),
          ink: const Color(0xFF22342E),
          cream: const Color(0xFFF1F5EC),
          sand: const Color(0xFFD9E4D3),
          mist: const Color(0xFFF8FBF5),
        );
      case 'heritage':
      default:
        return _buildTheme(
          primary: pine,
          primaryDeep: pineDeep,
          secondary: clay,
          ink: ink,
          cream: cream,
          sand: sand,
          mist: mist,
        );
    }
  }

  static ThemeData _buildTheme({
    required Color primary,
    required Color primaryDeep,
    required Color secondary,
    required Color ink,
    required Color cream,
    required Color sand,
    required Color mist,
  }) {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: pine,
      onPrimary: Colors.white,
      secondary: clay,
      onSecondary: Colors.white,
      error: Color(0xFFB94A48),
      onError: Colors.white,
      surface: Colors.white,
      onSurface: AppTheme.ink,
    );

    final resolvedColorScheme = colorScheme.copyWith(
      primary: primary,
      secondary: secondary,
      onSurface: ink,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: resolvedColorScheme,
      scaffoldBackgroundColor: mist,
      textTheme: TextTheme(
        headlineLarge: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w800,
          color: ink,
          letterSpacing: -0.8,
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: ink,
          letterSpacing: -0.6,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          height: 1.35,
          color: ink,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          height: 1.35,
          color: ink,
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: ink,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: Colors.white.withValues(alpha: 0.88),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: primaryDeep.withValues(alpha: 0.10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(
            color: primary.withValues(alpha: 0.08),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cream,
        labelStyle: const TextStyle(
          color: Color(0xFF57706B),
          fontWeight: FontWeight.w600,
        ),
        hintStyle: const TextStyle(
          color: Color(0xFF8A948F),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: primary.withValues(alpha: 0.08),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: secondary,
            width: 1.4,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary.withValues(alpha: 0.28)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white.withValues(alpha: 0.94),
        indicatorColor: sand,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: cream,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: primaryDeep,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
