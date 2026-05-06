import 'package:flutter/material.dart';

import 'lavender_indigo_tokens.dart';

/// App-wide chrome tokens (legacy class name for FlutterFlow imports).
/// Values follow the light lavender + indigo palette.
abstract final class ObsidianVoltTokens {
  static const Color bgBase = LavenderIndigoTokens.bgPage;
  static const Color bgSurface = LavenderIndigoTokens.bgSurface;
  static const Color bgCard = LavenderIndigoTokens.bgSurfaceAlt;

  static Color get bgOverlay =>
      const Color.fromRGBO(0, 0, 0, 0.04);

  static const Color textPrimary = LavenderIndigoTokens.textPrimary;
  static const Color textSecondary = LavenderIndigoTokens.textSecondary;
  static const Color textTertiary = LavenderIndigoTokens.textDisabled;

  static Color get borderDefault => LavenderIndigoTokens.borderDefault;
  static Color get borderSubtle => LavenderIndigoTokens.borderDefault;
  static Color get borderMuted => LavenderIndigoTokens.borderMedium;

  static const Color accent = LavenderIndigoTokens.primary;
  static Color get accentBg => LavenderIndigoTokens.primarySoft;
  static Color get accentBorder => LavenderIndigoTokens.primaryBorder;
  static const Color accentText = LavenderIndigoTokens.primaryLight;

  static const Color tabContainerBg = LavenderIndigoTokens.bgSurfaceAlt;
  static const Color tabSelectedBg = LavenderIndigoTokens.bgSurface;
  static Color get tabBorder => LavenderIndigoTokens.primaryBorder;

  static const Color bottomNavBg = LavenderIndigoTokens.bgSurface;
  static const Color bottomNavTopBorder =
      Color(0x00000000); // shadow replaces stroke
  static const Color bottomNavInactive = LavenderIndigoTokens.textDisabled;

  static Color get navActiveBackdrop =>
      LavenderIndigoTokens.navActiveBackdrop;

  static Color get timelineSpine =>
      const Color.fromRGBO(0, 0, 0, 0.08);

  static Color get nowBadgeBg => LavenderIndigoTokens.primarySoft;
  static const Color nowBadgeText = LavenderIndigoTokens.primary;

  static const Color dateBlockBg = LavenderIndigoTokens.bgSurfaceAlt;
  static const Color dateBlockMonth = LavenderIndigoTokens.textSecondary;
  static const Color dateBlockDay = LavenderIndigoTokens.textPrimary;

  static const Color avatarRing = LavenderIndigoTokens.primary;

  static Color get filterBorder => LavenderIndigoTokens.primaryBorder;

  static const Color chatInputBg = LavenderIndigoTokens.bgSurfaceAlt;
  static Color get chatInputBorder =>
      const Color.fromRGBO(99, 102, 241, 0.15);
  static const Color chatPlaceholder = LavenderIndigoTokens.textDisabled;
  static const Color chatSendIcon = LavenderIndigoTokens.primary;

  static const Color chipBg = LavenderIndigoTokens.bgSurfaceAlt;
  static Color get chipBorder => LavenderIndigoTokens.borderDefault;
  static const Color chipText = LavenderIndigoTokens.textSecondary;

  static const Color infoStripBg = LavenderIndigoTokens.bgSurfaceAlt;
  static Color get infoStripBorder => LavenderIndigoTokens.primaryBorder;
  static const Color infoStripIcon = LavenderIndigoTokens.primary;
  static const Color infoStripText = LavenderIndigoTokens.textSecondary;

  static Color get urgentCardBg =>
      const Color.fromRGBO(245, 158, 11, 0.12);
  static Color get urgentCardBorder =>
      const Color.fromRGBO(245, 158, 11, 0.28);
  static const Color urgentLeftBorder = LavenderIndigoTokens.warning;
  static const Color urgentCta = LavenderIndigoTokens.warning;

  static Color get dangerCardBg =>
      const Color.fromRGBO(239, 68, 68, 0.12);
  static Color get dangerCardBorder =>
      const Color.fromRGBO(239, 68, 68, 0.25);
  static const Color dangerLeftBorder = LavenderIndigoTokens.danger;
  static const Color dangerCta = LavenderIndigoTokens.danger;

  static Color get badgeCompletedBg =>
      const Color.fromRGBO(16, 185, 129, 0.12);
  static const Color badgeCompletedText = LavenderIndigoTokens.success;

  static Color get badgeEnteredBg =>
      LavenderIndigoTokens.primarySoft;
  static const Color badgeEnteredText = LavenderIndigoTokens.primary;

  static Color get badgeCancelledBg =>
      const Color.fromRGBO(0, 0, 0, 0.05);
  static const Color badgeCancelledText = LavenderIndigoTokens.textSecondary;

  static Color get badgeUpcomingBg =>
      const Color.fromRGBO(245, 200, 66, 0.14);
  static const Color badgeUpcomingText = LavenderIndigoTokens.accentYellow;

  static const Color eventTrainingDot = LavenderIndigoTokens.accentBlue;
  static Color get eventTrainingTagBg =>
      const Color.fromRGBO(99, 102, 241, 0.14);
  static const Color eventTrainingTagText = LavenderIndigoTokens.primary;
  static Color get eventTrainingCardTint =>
      const Color.fromRGBO(255, 255, 255, 0);
  static Color get eventTrainingCardBorder => LavenderIndigoTokens.borderDefault;

  static const Color eventMeetDot = LavenderIndigoTokens.accentYellow;
  static Color get eventMeetTagBg =>
      const Color.fromRGBO(245, 200, 66, 0.18);
  static const Color eventMeetTagText = Color(0xFFB45309);
  static Color get eventMeetCardTint =>
      const Color.fromRGBO(255, 255, 255, 0);
  static Color get eventMeetCardBorder => LavenderIndigoTokens.borderDefault;

  static const Color eventAdminDot = Color(0xFF818CF8);
  static Color get eventAdminTagBg =>
      const Color.fromRGBO(129, 140, 248, 0.18);
  static const Color eventAdminTagText = Color(0xFF4F46E5);
  static Color get eventAdminCardTint =>
      const Color.fromRGBO(255, 255, 255, 0);
  static Color get eventAdminCardBorder => LavenderIndigoTokens.borderDefault;

  static const Color eventSocialDot = LavenderIndigoTokens.accentPink;
  static Color get eventSocialTagBg =>
      const Color.fromRGBO(255, 107, 157, 0.14);
  static const Color eventSocialTagText = Color(0xFFE11D48);
  static Color get eventSocialCardTint =>
      const Color.fromRGBO(255, 255, 255, 0);
  static Color get eventSocialCardBorder => LavenderIndigoTokens.borderDefault;

  static Color get squadJuniorBg => LavenderIndigoTokens.primarySoft;
  static const Color squadJuniorText = LavenderIndigoTokens.primary;

  static Color get squadSeniorBg =>
      const Color.fromRGBO(99, 102, 241, 0.08);
  static const Color squadSeniorText = LavenderIndigoTokens.primary;

  static Color get squadAllBg =>
      const Color.fromRGBO(129, 140, 248, 0.15);
  static const Color squadAllText = Color(0xFF4338CA);

  static Color get eventCancelledDot =>
      LavenderIndigoTokens.borderMedium;
  static Color get eventCancelledCardBg =>
      const Color.fromRGBO(0, 0, 0, 0.03);

  static Color get generalCardBg => bgSurface;
  static Color get generalCardBorder =>
      const Color.fromRGBO(255, 255, 255, 0);
}
