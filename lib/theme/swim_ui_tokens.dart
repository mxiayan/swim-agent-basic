import 'package:flutter/material.dart';

/// Shared layout and chrome tokens for Schedule / Meets (and related cards).
/// Keeps surfaces, borders, and typography accents consistent without touching
/// generated FlutterFlow theme.
abstract final class SwimUiTokens {
  // Surfaces
  /// Meets tab and similar full-width shells.
  static const Color surfaceCanvas = Color(0xFFF8FAFC);
  static const Color surfaceCanvasSchedule = Color(0xFFF1F5F9);
  static const Color surfaceCard = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF8FAFC);

  // Borders
  static const Color borderSubtle = Color(0xFFE2E8F0);
  static const Color borderSection = Color(0xFFD0D9E6);
  static const Color borderSegmentTrack = Color(0xFFE2E8F0);

  /// Subtle iOS-blue ring for meet rows on Schedule.
  static const Color meetRowRing = Color(0x38007AFF);

  // Text
  static const Color textBannerTitle = Color(0xFF0F172A);
  static const Color textTitle = Color(0xFF1E293B);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textFaint = Color(0xFF94A3B8);

  // Accent (use sparingly for links, filters, selected chrome)
  static const Color accentBlue = Color(0xFF007AFF);
  static const Color accentBlueSheet = Color(0xFF3B82F6);

  // Meets — grouped section shells
  static const Color sectionNeedsAction = Color(0xFFFFFAF6);
  static const Color sectionEntered = Color(0xFFF2F7FF);
  static const Color sectionSkipped = Color(0xFFF1F5F9);

  // Radii
  static const double radiusSm = 9.0;
  static const double radiusMd = 10.0;
  static const double radiusCard = 12.0;
  static const double radiusSegmentShell = 11.0;
  static const double radiusSection = 18.0;

  // Shadows (~4% black)
  static const List<BoxShadow> shadowCard = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 12.0,
      offset: Offset(0.0, 4.0),
    ),
  ];

  static const List<BoxShadow> shadowCardLift = [
    BoxShadow(
      color: Color(0x0B000000),
      blurRadius: 14.0,
      offset: Offset(0.0, 4.0),
    ),
  ];

  static const List<BoxShadow> shadowSegmentPill = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 6.0,
      offset: Offset(0.0, 1.0),
    ),
  ];

  // Swipe / utility
  static const Color swipeBackground = Color(0xFFF1F5F9);
  static const Color swipeIcon = Color(0xFF64748B);
}
