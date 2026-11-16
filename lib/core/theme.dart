import 'package:flutter/material.dart';

/// Design tokens. Dark-first "night market" look. Use these, never raw hex.
abstract final class AppColors {
  static const ink = Color(0xFF0B1022); // page background
  static const surface = Color(0xFF151B36);
  static const surfaceHi = Color(0xFF1F2750);
  static const line = Color(0xFF2B3466);
  static const text = Color(0xFFF4F6FF);
  static const textDim = Color(0xFF9AA3C7);
  static const mint = Color(0xFF2EE6A6); // growth, success, primary action
  static const amber = Color(0xFFFFC857); // coins, rewards
  static const coral = Color(0xFFFF6B6B); // danger, wrong
  static const violet = Color(0xFF8B7CFF); // knowledge, XP
  static const sky = Color(0xFF4CC9F0); // info, story

  /// Content JSON refers to colours by name.
  static Color named(String? name) => switch (name) {
    'amber' => amber,
    'coral' => coral,
    'violet' => violet,
    'sky' => sky,
    _ => mint,
  };
}

abstract final class AppSpace {
  static const xs = 4.0, sm = 8.0, md = 16.0, lg = 24.0, xl = 32.0;
  static const radius = 20.0;
  static const maxWidth = 560.0; // content column on tablets and web
}

abstract final class AppMotion {
  static const fast = Duration(milliseconds: 150);
  static const base = Duration(milliseconds: 300);
  static const curve = Curves.easeOutCubic;
}

ThemeData buildTheme() {
  const display = 'Fredoka';
  TextStyle d(double size, FontWeight w) =>
      TextStyle(fontFamily: display, fontSize: size, fontWeight: w, color: AppColors.text, height: 1.15);
  TextStyle b(double size, FontWeight w, [Color c = AppColors.text]) =>
      TextStyle(fontSize: size, fontWeight: w, color: c, height: 1.4);

  final scheme = ColorScheme.fromSeed(seedColor: AppColors.mint, brightness: Brightness.dark).copyWith(
    primary: AppColors.mint,
    onPrimary: AppColors.ink,
    secondary: AppColors.violet,
    tertiary: AppColors.amber,
    error: AppColors.coral,
    surface: AppColors.surface,
    onSurface: AppColors.text,
    onSurfaceVariant: AppColors.textDim,
    outline: AppColors.line,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.ink,
    fontFamily: 'Nunito',
    textTheme: TextTheme(
      displaySmall: d(36, FontWeight.w700),
      headlineMedium: d(28, FontWeight.w700),
      headlineSmall: d(24, FontWeight.w600),
      titleLarge: d(20, FontWeight.w600),
      titleMedium: b(16, FontWeight.w800),
      titleSmall: b(14, FontWeight.w800),
      bodyLarge: b(16, FontWeight.w600),
      bodyMedium: b(14, FontWeight.w600, AppColors.textDim),
      bodySmall: b(12, FontWeight.w600, AppColors.textDim),
      labelLarge: b(15, FontWeight.w800),
      labelSmall: b(11, FontWeight.w800, AppColors.textDim),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      titleTextStyle: d(20, FontWeight.w600),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.mint.withValues(alpha: 0.18),
      height: 68,
      labelTextStyle: WidgetStatePropertyAll(b(12, FontWeight.w800)),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(color: s.contains(WidgetState.selected) ? AppColors.mint : AppColors.textDim),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder()},
    ),
  );
}

extension ThemeX on BuildContext {
  TextTheme get text => Theme.of(this).textTheme;
}
