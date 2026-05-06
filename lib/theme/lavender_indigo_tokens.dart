import 'package:flutter/material.dart';

/// Minimal light aesthetic — lavender page canvas + indigo primary.
abstract final class LavenderIndigoTokens {
  static const Color bgPage = Color(0xFFECEFFE);
  static const Color bgSurface = Color(0xFFFFFFFF);
  static const Color bgSurfaceAlt = Color(0xFFF4F6FE);

  static const Color primary = Color(0xFF6366F1);
  static const Color primaryLight = Color(0xFF7C7FF5);

  static Color get primarySoft =>
      const Color.fromRGBO(99, 102, 241, 0.10);
  static Color get primaryBorder =>
      const Color.fromRGBO(99, 102, 241, 0.20);

  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF8B8FA8);
  static const Color textDisabled = Color(0xFFC5C8DC);

  static Color get borderDefault =>
      const Color.fromRGBO(0, 0, 0, 0.06);
  static Color get borderMedium =>
      const Color.fromRGBO(0, 0, 0, 0.10);

  static const Color accentBlue = Color(0xFF6366F1);
  static const Color accentYellow = Color(0xFFF5C842);
  static const Color accentPink = Color(0xFFFF6B9D);
  static const Color accentGreen = Color(0xFF34D399);

  static const Color danger = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color success = Color(0xFF10B981);

  /// Indigo-tinted elevation shadows (card-on-page).
  static List<BoxShadow> get shadowSm => [
        BoxShadow(
          color: const Color.fromRGBO(99, 102, 241, 0.08),
          blurRadius: 8,
          offset: const Offset(0, 2),
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> get shadowMd => [
        BoxShadow(
          color: const Color.fromRGBO(99, 102, 241, 0.10),
          blurRadius: 16,
          offset: const Offset(0, 4),
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> get shadowLg => [
        BoxShadow(
          color: const Color.fromRGBO(99, 102, 241, 0.12),
          blurRadius: 32,
          offset: const Offset(0, 8),
          spreadRadius: 0,
        ),
      ];

  /// Schedule row — softer blur than generic shadow-sm.
  static List<BoxShadow> get shadowScheduleRow => [
        BoxShadow(
          color: const Color.fromRGBO(99, 102, 241, 0.07),
          blurRadius: 8,
          offset: const Offset(0, 2),
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> get shadowHero => [
        BoxShadow(
          color: const Color.fromRGBO(99, 102, 241, 0.25),
          blurRadius: 32,
          offset: const Offset(0, 8),
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> get shadowPrimaryButton => [
        BoxShadow(
          color: const Color.fromRGBO(99, 102, 241, 0.35),
          blurRadius: 12,
          offset: const Offset(0, 4),
          spreadRadius: 0,
        ),
      ];

  /// Bottom nav lift — upward shadow.
  static List<BoxShadow> get shadowNavUp => [
        BoxShadow(
          color: const Color.fromRGBO(99, 102, 241, 0.08),
          blurRadius: 16,
          offset: const Offset(0, -4),
          spreadRadius: 0,
        ),
      ];

  static const BorderRadius radiusXs =
      BorderRadius.all(Radius.circular(8));
  static const BorderRadius radiusSm =
      BorderRadius.all(Radius.circular(12));
  static const BorderRadius radiusMd =
      BorderRadius.all(Radius.circular(16));
  static const BorderRadius radiusLg =
      BorderRadius.all(Radius.circular(20));

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
  );

  static const LinearGradient progressFillGradient = LinearGradient(
    colors: [Color(0xFF818CF8), Color(0xFF6366F1)],
  );

  static Color get navActiveBackdrop =>
      const Color.fromRGBO(99, 102, 241, 0.12);
}
