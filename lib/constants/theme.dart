import 'package:flutter/material.dart';

// ─── Brand Colors ──────────────────────────────────────────────────────────
const Color kPrimary = Color(0xFFDC4C3E);
const Color kSuccess = Color(0xFF058527);

// Priority colors
const Color kP1Red = Color(0xFFD1453B);
const Color kP2Orange = Color(0xFFEB8909);
const Color kP3Blue = Color(0xFF4073FF);
const Color kP4Gray = Color(0xFF8C8C8C);
const Color kTextMuted = Color(0xFF8C8C8C);

// ─── Dark Theme ────────────────────────────────────────────────────────────
const Color kDarkBg = Color(0xFF1F1F1F);
const Color kDarkSurface = Color(0xFF282828);
const Color kDarkBorder = Color(0xFF3A3A3A);
const Color kDarkTextPrimary = Color(0xFFFFFFFF);

// ─── Light Theme ───────────────────────────────────────────────────────────
const Color kLightBg = Color(0xFFFAFAFA);
const Color kLightSurface = Color(0xFFFFFFFF);
const Color kLightBorder = Color(0xFFE5E5E5);
const Color kLightTextPrimary = Color(0xFF202020);

// ─── Spacing ───────────────────────────────────────────────────────────────
const double kSpace4 = 4;
const double kSpace8 = 8;
const double kSpace12 = 12;
const double kSpace16 = 16;
const double kSpace20 = 20;
const double kSpace24 = 24;
const double kSpace32 = 32;
const double kSpace48 = 48;

// ─── Themes ────────────────────────────────────────────────────────────────
ThemeData buildDarkTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: kDarkBg,
    colorScheme: const ColorScheme.dark(
      primary: kPrimary,
      surface: kDarkSurface,
      onSurface: kDarkTextPrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: kDarkBg,
      foregroundColor: kDarkTextPrimary,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: const CardThemeData(
      color: kDarkSurface,
      elevation: 0,
      margin: EdgeInsets.zero,
    ),
    dividerTheme: const DividerThemeData(
      color: kDarkBorder,
      thickness: 0.5,
    ),
    listTileTheme: const ListTileThemeData(
      tileColor: kDarkSurface,
      textColor: kDarkTextPrimary,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kDarkSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kDarkBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kDarkBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kPrimary),
      ),
      hintStyle: const TextStyle(color: kTextMuted),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: kDarkSurface,
      indicatorColor: Color(0x33DC4C3E),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: kPrimary,
      foregroundColor: Colors.white,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(color: kDarkTextPrimary, fontWeight: FontWeight.w700, fontSize: 28),
      titleLarge: TextStyle(color: kDarkTextPrimary, fontWeight: FontWeight.w600, fontSize: 20),
      titleMedium: TextStyle(color: kDarkTextPrimary, fontWeight: FontWeight.w500, fontSize: 16),
      bodyLarge: TextStyle(color: kDarkTextPrimary, fontSize: 16),
      bodyMedium: TextStyle(color: kDarkTextPrimary, fontSize: 14),
      bodySmall: TextStyle(color: kTextMuted, fontSize: 12),
      labelSmall: TextStyle(color: kTextMuted, fontSize: 11),
    ),
  );
}

ThemeData buildLightTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: kLightBg,
    colorScheme: const ColorScheme.light(
      primary: kPrimary,
      surface: kLightSurface,
      onSurface: kLightTextPrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: kLightBg,
      foregroundColor: kLightTextPrimary,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: const CardThemeData(
      color: kLightSurface,
      elevation: 0,
      margin: EdgeInsets.zero,
    ),
    dividerTheme: const DividerThemeData(
      color: kLightBorder,
      thickness: 0.5,
    ),
    listTileTheme: const ListTileThemeData(
      tileColor: kLightSurface,
      textColor: kLightTextPrimary,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kLightSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kLightBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kLightBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kPrimary),
      ),
      hintStyle: const TextStyle(color: kTextMuted),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: kLightSurface,
      indicatorColor: Color(0x22DC4C3E),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: kPrimary,
      foregroundColor: Colors.white,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(color: kLightTextPrimary, fontWeight: FontWeight.w700, fontSize: 28),
      titleLarge: TextStyle(color: kLightTextPrimary, fontWeight: FontWeight.w600, fontSize: 20),
      titleMedium: TextStyle(color: kLightTextPrimary, fontWeight: FontWeight.w500, fontSize: 16),
      bodyLarge: TextStyle(color: kLightTextPrimary, fontSize: 16),
      bodyMedium: TextStyle(color: kLightTextPrimary, fontSize: 14),
      bodySmall: TextStyle(color: kTextMuted, fontSize: 12),
      labelSmall: TextStyle(color: kTextMuted, fontSize: 11),
    ),
  );
}

// ─── Priority Helpers ─────────────────────────────────────────────────────
Color priorityColor(int priority) {
  switch (priority) {
    case 1: return kP1Red;
    case 2: return kP2Orange;
    case 3: return kP3Blue;
    default: return kP4Gray;
  }
}

String priorityLabel(int priority) {
  switch (priority) {
    case 1: return 'P1';
    case 2: return 'P2';
    case 3: return 'P3';
    default: return 'P4';
  }
}
