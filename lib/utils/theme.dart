// lib/utils/theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // Strict Black & White Palette
  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);
  static const Color grayBorder = Color(0xFF222222);
  static const Color graySecondary = Color(0xFF888888);
  static const Color grayMuted = Color(0xFF444444);

  // Aliases for compatibility
  static const Color background = black;
  static const Color surface = black;
  static const Color surfaceLighter = Color(0xFF1E293B);
  static const Color border = grayBorder;
  static const Color primaryTeal = white;
  static const Color primaryBlue = Color(0xFF2563EB); // Real blue for snacks/errors
  static const Color textSecondary = graySecondary;
  static const Color textMuted = grayMuted;
  static const Color primaryGradient = Colors.transparent; 
  static const Color terminalGreen = white;
  static const Color accent = white;

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: black,
      colorScheme: const ColorScheme.dark(
        primary: white,
        onPrimary: black,
        surface: black,
        onSurface: white,
        outline: grayBorder,
      ),
      textTheme: GoogleFonts.jetBrainsMonoTextTheme(base.textTheme).apply(
        bodyColor: white,
        displayColor: white,
      ),
      cardTheme: const CardThemeData(
        color: black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: grayBorder),
        ),
        elevation: 0,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: black,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: graySecondary),
        titleTextStyle: TextStyle(
          color: white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: black,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: grayBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: grayBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: white),
        ),
        labelStyle: TextStyle(color: graySecondary),
        hintStyle: TextStyle(color: grayMuted),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: black,
          foregroundColor: white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
            side: BorderSide(color: grayBorder),
          ),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: white,
          side: const BorderSide(color: grayBorder),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: graySecondary,
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ),
      dividerColor: grayBorder,
      tabBarTheme: const TabBarThemeData(
        labelColor: white,
        unselectedLabelColor: graySecondary,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: white, width: 2),
        ),
      ),
    );
  }
}
