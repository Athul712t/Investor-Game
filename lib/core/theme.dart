import 'package:flutter/material.dart';

/// Design tokens for the "Bazaar Board" theme (docs/DESIGN.md).
/// Every colour is a solid fill. No gradients, glows or blurred shadows in app screens.
abstract final class AppColors {
  static const paper = Color(0xFFFFF3DC); // page ground
  static const paperDeep = Color(0xFFF7E2B8); // bands, inactive fills
  static const card = Color(0xFFFFFFFF);
  static const ink = Color(0xFF1D1B2E); // text, outlines, hard shadows
  static const inkDim = Color(0xFF6B6780);
  static const track = Color(0xFFE9D6AC); // progress tracks, dividers
  static const green = Color(0xFF1FB86B); // primary action, correct
  static const yellow = Color(0xFFFFC530); // coins, arcade
  static const red = Color(0xFFFF5348); // wrong, lives
  static const blue = Color(0xFF2F8CFF); // XP, knowledge
  static const teal = Color(0xFF12B5A6); // story
  static const orange = Color(0xFFFF8A2B); // streak

  /// Content JSON refers to colours by name.
  static Color named(String? name) => switch (name) {
    'amber' || 'yellow' => yellow,
    'coral' || 'red' => red,
    'violet' || 'blue' => blue,
    'sky' || 'teal' => teal,
    'orange' => orange,
    _ => green,
  };

  /// Text colour that reads on a solid [fill].
  static Color on(Color fill) => fill.computeLuminance() > 0.36 ? ink : card;

  /// A lighter solid tint of [c] for large fills behind ink text.
  static Color tint(Color c, [double amount = 0.78]) => Color.lerp(c, card, amount)!;
}

abstract final class AppSpace {
  static const xs = 4.0, sm = 8.0, md = 16.0, lg = 24.0, xl = 32.0;
  static const radius = 18.0;
  static const outline = 2.5;
  static const depth = 5.0; // hard shadow offset of a card
  static const maxWidth = 560.0;
}

abstract final class AppMotion {
  static const fast = Duration(milliseconds: 120);
  static const base = Duration(milliseconds: 280);
  static const curve = Curves.easeOutCubic;

  /// Critically damped: default for UI. [bouncy] only for rewards and flicked things.
  static const spring = SpringDescription(mass: 1, stiffness: 320, damping: 36);
  static const bouncy = SpringDescription(mass: 1, stiffness: 320, damping: 20);
}

/// Outlined piece: solid fill, ink border, hard shadow. The one surface style of the app.
BoxDecoration pieceDecoration({
  Color fill = AppColors.card,
  double radius = AppSpace.radius,
  double depth = AppSpace.depth,
  Color outline = AppColors.ink,
}) => BoxDecoration(
  color: fill,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: outline, width: AppSpace.outline),
  boxShadow: depth <= 0 ? null : [BoxShadow(color: outline, offset: Offset(0, depth))],
);

ThemeData buildTheme() {
  TextStyle d(double size, [double height = 1.05]) => TextStyle(
    fontFamily: 'Baloo2',
    fontSize: size,
    fontWeight: FontWeight.w800,
    color: AppColors.ink,
    height: height,
    letterSpacing: size >= 28 ? -0.5 : 0,
  );
  TextStyle b(double size, FontWeight w, [Color c = AppColors.ink]) =>
      TextStyle(fontSize: size, fontWeight: w, color: c, height: 1.4);

  final scheme = ColorScheme.fromSeed(seedColor: AppColors.green, brightness: Brightness.light).copyWith(
    primary: AppColors.green,
    onPrimary: AppColors.ink,
    secondary: AppColors.blue,
    tertiary: AppColors.yellow,
    error: AppColors.red,
    surface: AppColors.card,
    onSurface: AppColors.ink,
    onSurfaceVariant: AppColors.inkDim,
    outline: AppColors.ink,
    surfaceTint: Colors.transparent,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.paper,
    fontFamily: 'Nunito',
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    textTheme: TextTheme(
      displaySmall: d(40),
      headlineMedium: d(32),
      headlineSmall: d(26),
      titleLarge: d(20, 1.15),
      titleMedium: b(17, FontWeight.w800),
      titleSmall: b(14, FontWeight.w800),
      bodyLarge: b(16, FontWeight.w700),
      bodyMedium: b(14, FontWeight.w700, AppColors.inkDim),
      bodySmall: b(12, FontWeight.w700, AppColors.inkDim),
      labelLarge: b(15, FontWeight.w800),
      labelSmall: b(11, FontWeight.w800, AppColors.inkDim),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.ink,
      centerTitle: true,
      titleTextStyle: d(20, 1.15),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpace.radius),
        side: const BorderSide(color: AppColors.ink, width: AppSpace.outline),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.ink,
      contentTextStyle: b(14, FontWeight.w800, AppColors.card),
      behavior: SnackBarBehavior.floating,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.card,
      indicatorColor: AppColors.yellow,
      height: 68,
      labelTextStyle: WidgetStatePropertyAll(b(12, FontWeight.w800)),
      iconTheme: const WidgetStatePropertyAll(IconThemeData(color: AppColors.ink)),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder()},
    ),
  );
}

extension ThemeX on BuildContext {
  TextTheme get text => Theme.of(this).textTheme;
  bool get reduceMotion => MediaQuery.disableAnimationsOf(this);
}
