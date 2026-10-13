import 'package:flutter/material.dart';

/// Melody Design System — ألوان ثابتة. الألوان المتغيرة حسب الغلاف في ArtworkPalette.
class AppColors {
  static const bg = Color(0xFF08080C);
  static const surface = Color(0xFF14141B);
  static const surfaceHigh = Color(0xFF1D1D27);
  static const field = Color(0xFF1A1A23);
  static const border = Color(0x1FFFFFFF);
  static const textSecondary = Color(0xFFA3A3B2);
  static const brand = Color(0xFF8B6CFF);
  static const success = Color(0xFF3DDC84);
  static const warning = Color(0xFFFFB84D);
  static const error = Color(0xFFFF5C7A);
}

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final scheme = dark
      ? ColorScheme.fromSeed(seedColor: AppColors.brand, brightness: b)
          .copyWith(surface: AppColors.bg, onSurface: Colors.white, error: AppColors.error)
      : ColorScheme.fromSeed(seedColor: AppColors.brand, brightness: b);
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: 'Cairo');
  return base.copyWith(
    scaffoldBackgroundColor: dark ? AppColors.bg : scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: scheme.onSurface),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 64,
      backgroundColor: dark ? const Color(0xF2101016) : null,
      indicatorColor: AppColors.brand.withOpacity(.22),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? AppColors.field : null,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: dark ? AppColors.surface : null,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
