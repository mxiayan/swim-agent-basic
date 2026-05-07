import 'package:flutter/material.dart';

import 'lavender_indigo_tokens.dart';
import 'obsidian_volt_tokens.dart';
import 'swim_ui_tokens.dart';

/// Shared design tokens (colors, spacing, radius). Typography uses Sora in widgets.
abstract final class SwimDsTokens {
  static Color get primaryPurple => LavenderIndigoTokens.primary;
  static Color get softPurpleBackground => SwimUiTokens.surfaceCanvasAgent;
  static Color get cardBackground => LavenderIndigoTokens.bgSurface;
  static Color get textPrimary => LavenderIndigoTokens.textPrimary;
  static Color get textSecondary => LavenderIndigoTokens.textSecondary;
  static Color get borderSoft => SwimUiTokens.cardSurfaceEdgeBorder;
  static Color get successGreen => LavenderIndigoTokens.success;
  static Color get warningAmber => LavenderIndigoTokens.warning;
  static Color get dangerCoral => const Color(0xFFD97254);
  static Color get infoBlueGray => const Color(0xFF607D8B);
  static Color get tealApproved => const Color(0xFF269396);
  static Color get mutedGray => ObsidianVoltTokens.textSecondary;
  static Color get newUpdatePurple => const Color(0xFF9B8AFB);

  static const double pageHorizontalPadding = 20;
  static const double sectionSpacing = 20;
  static const double cardSpacing = 12;
  static const double cardPadding = 16;
  static const double smallGap = 8;
  static const double mediumGap = 12;
  static const double largeGap = 20;

  static const double headerToTabsGap = 20;
  static const double tabsToContentGap = 16;
  static const double sectionTitleToContentGap = 8;

  static const double cardRadius = 18;
  static const double pillRadius = 999;
  static const double bottomNavRadius = 24;

  static List<BoxShadow> get cardShadowSoft => LavenderIndigoTokens.shadowSm;
}
