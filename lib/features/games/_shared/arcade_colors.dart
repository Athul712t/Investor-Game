import 'dart:ui';

/// Night-arcade palette for the game canvases (runner, stack, merge).
/// Games paint their own worlds, so they do not follow the app's paper theme.
abstract final class ArcadeColors {
  static const ink = Color(0xFF0B1022);
  static const surface = Color(0xFF151B36);
  static const surfaceHi = Color(0xFF1F2750);
  static const line = Color(0xFF2B3466);
  static const text = Color(0xFFF4F6FF);
  static const textDim = Color(0xFF9AA3C7);
  static const mint = Color(0xFF2EE6A6);
  static const amber = Color(0xFFFFC857);
  static const coral = Color(0xFFFF6B6B);
  static const violet = Color(0xFF8B7CFF);
  static const sky = Color(0xFF4CC9F0);
}
