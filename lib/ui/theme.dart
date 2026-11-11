import 'package:flutter/material.dart';

class PosColors {
  static const brandDark = Color(0xFF0F172A);
  static const brand = Color(0xFF1D4ED8);
  static const accent = Color(0xFF3B82F6);
  static const surface = Color(0xFFF8FAFC);
  static const card = Color(0xFFFFFFFF);
  static const text = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const danger = Color(0xFFEF4444);
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const border = Color(0xFFE2E8F0);
}

ThemeData posTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: PosColors.brand).copyWith(
    surface: PosColors.surface,
    error: PosColors.danger,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: 'Cairo');
  return base.copyWith(
    scaffoldBackgroundColor: PosColors.surface,
    textTheme: base.textTheme.apply(bodyColor: PosColors.text, displayColor: PosColors.text),
    appBarTheme: const AppBarTheme(
      backgroundColor: PosColors.brandDark,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: PosColors.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: PosColors.border),
      ),
    ),
    dividerTheme: const DividerThemeData(color: PosColors.border, thickness: 1, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: PosColors.card,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      hintStyle: const TextStyle(color: PosColors.muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: PosColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: PosColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: PosColors.brand, width: 1.6),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: PosColors.brand,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: PosColors.brandDark,
        side: const BorderSide(color: PosColors.border),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600, fontSize: 13),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: PosColors.brand,
        textStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: PosColors.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titleTextStyle: const TextStyle(
        fontFamily: 'Cairo',
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: PosColors.text,
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: PosColors.brandDark,
      contentTextStyle: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 14),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: PosColors.surface,
      side: const BorderSide(color: PosColors.border),
      labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w600),
    ),
  );
}