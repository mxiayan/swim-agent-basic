import 'package:flutter/material.dart';

import 'lavender_indigo_tokens.dart';
import 'obsidian_volt_tokens.dart';

/// Shared layout chrome tokens — lavender surfaces + indigo accents (light-only).
abstract final class SwimUiTokens {
  // Surfaces
  static const Color surfaceCanvas = ObsidianVoltTokens.bgBase;
  static const Color surfaceCanvasSchedule = ObsidianVoltTokens.bgBase;
  static const Color surfaceCard = ObsidianVoltTokens.bgSurface;
  static Color get surfaceMuted => LavenderIndigoTokens.bgSurfaceAlt;

  static Color get surfaceElevated => LavenderIndigoTokens.bgSurfaceAlt;

  static const Color segmentTrackBg = ObsidianVoltTokens.tabContainerBg;
  static const Color segmentSelectedBg = ObsidianVoltTokens.tabSelectedBg;
  static Color get segmentBorder => ObsidianVoltTokens.tabBorder;

  static Color get borderSubtle => ObsidianVoltTokens.borderSubtle;

  /// Horizontal inset for primary scroll/content on main tabs (lavender shell).
  static const double screenHorizontalInset = 24.0;

  /// Vertical gap between major page sections (hero → section headers → lists).
  static const double sectionBlockSpacing = 24.0;

  /// Barely-visible rim so white/light cards read crisply on lavender canvas.
  static const Color cardSurfaceEdgeBorder = Color.fromRGBO(220, 224, 240, 0.8);

  static Color get borderSection => LavenderIndigoTokens.primaryBorder;
  static Color get borderSegmentTrack => ObsidianVoltTokens.tabBorder;

  static Color get meetRowRing => LavenderIndigoTokens.primaryBorder;

  static const Color textBannerTitle = ObsidianVoltTokens.textPrimary;
  static const Color textTitle = ObsidianVoltTokens.textPrimary;
  static const Color textMuted = ObsidianVoltTokens.textSecondary;
  static const Color textFaint = ObsidianVoltTokens.textTertiary;

  static const Color accentBlue = ObsidianVoltTokens.accent;
  static const Color accentBlueSheet = ObsidianVoltTokens.accent;

  static Color get sectionNeedsAction => ObsidianVoltTokens.urgentCardBg;
  static Color get sectionEntered => ObsidianVoltTokens.badgeEnteredBg;
  static Color get sectionSkipped => ObsidianVoltTokens.bgOverlay;

  /// Matches Lavender radius ladder — geometry unchanged elsewhere where feasible.
  static const double radiusXs = 8.0;
  static const double radiusSm = 12.0;
  static const double radiusMd = 16.0;
  static const double radiusCard = 12.0;
  static const double radiusLg = 20.0;
  static const double radiusSegmentShell = 12.0;
  static const double radiusSection = 18.0;

  static List<BoxShadow> get shadowCard => LavenderIndigoTokens.shadowMd;
  static List<BoxShadow> get shadowCardLift => LavenderIndigoTokens.shadowLg;
  static List<BoxShadow> get shadowSegmentPill =>
      LavenderIndigoTokens.shadowSm;

  static const Color swipeBackground = ObsidianVoltTokens.bgSurface;
  static const Color swipeIcon = ObsidianVoltTokens.textSecondary;
}
