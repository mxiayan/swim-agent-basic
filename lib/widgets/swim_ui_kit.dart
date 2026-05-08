import '/app_state.dart';
import '/theme/lavender_indigo_tokens.dart';
import '/theme/swim_design_tokens.dart';
import '/theme/swim_ui_tokens.dart';
import '/widgets/swimmer_avatar_with_group_badge.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

/// Bell badge style for [AppPageHeader]. When null, legacy amber dot is shown when bell exists.
enum SwimBellDotKind {
  none,
  updatesAmber,
  urgentRed,
}

/// Page header — title, subtitle, optional bell + profile avatar.
class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.onBellTap,
    this.onAvatarTap,
    this.trailing,
    this.bellDotKind,
    this.topPadding = SwimDsTokens.smallGap,
    this.bottomPadding = SwimDsTokens.sectionTitleToContentGap,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onBellTap;
  final VoidCallback? onAvatarTap;
  final Widget? trailing;

  /// Overrides default bell notification dot. Null keeps prior behavior (amber dot).
  final SwimBellDotKind? bellDotKind;
  final double topPadding;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final right = trailing ??
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onBellTap != null)
              Material(
                color: SwimDsTokens.cardBackground,
                elevation: 2,
                shadowColor: Colors.black.withValues(alpha: 0.06),
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onBellTap,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(Icons.notifications_none_rounded,
                            size: 22, color: SwimDsTokens.textPrimary),
                        if (_bellDotColor(bellDotKind) != null)
                          Positioned(
                            top: 11,
                            right: 11,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _bellDotColor(bellDotKind)!,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 1.5),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            if (onBellTap != null && onAvatarTap != null)
              const SizedBox(width: SwimDsTokens.smallGap),
            if (onAvatarTap != null)
              Material(
                color: Colors.transparent,
                elevation: 0,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onAvatarTap,
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Center(
                      child: Consumer<FFAppState>(
                        builder: (context, app, _) =>
                            DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: SwimDsTokens.cardBackground,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black
                                    .withValues(alpha: 0.06),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: SwimmerAvatarWithGroupBadge(
                              filePath: app.profileAvatarLocalPath,
                              webBase64: app.profileAvatarWebBase64,
                              swimmerDisplayName: app.currentSwimmerName,
                              practiceTierLabel: app.swimmerPracticeTierLabel,
                              clubProfilePracticeGroupRaw:
                                  app.clubProfilePracticeGroupRaw,
                              allowAutoUnresolvedBadge: false,
                              layout:
                                  SwimmerAvatarGroupBadgeLayout.header,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        SwimDsTokens.pageHorizontalPadding,
        topPadding,
        SwimDsTokens.pageHorizontalPadding,
        bottomPadding,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.sora(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                    color: SwimDsTokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.sora(
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w400,
                    color: SwimDsTokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          right,
        ],
      ),
    );
  }

  /// Legacy default: amber dot when [bellDotKind] is null.
  static Color? _bellDotColor(SwimBellDotKind? kind) {
    if (kind == null) return SwimDsTokens.warningAmber;
    switch (kind) {
      case SwimBellDotKind.none:
        return null;
      case SwimBellDotKind.updatesAmber:
        return SwimDsTokens.warningAmber;
      case SwimBellDotKind.urgentRed:
        return SwimDsTokens.dangerCoral;
    }
  }
}

/// Schedule / Meets shell — avatar only (no bell).
class AppShellHeader extends StatelessWidget {
  const AppShellHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onAvatarTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    return AppPageHeader(
      title: title,
      subtitle: subtitle,
      onBellTap: null,
      onAvatarTap: onAvatarTap,
      bottomPadding: SwimDsTokens.headerToTabsGap,
    );
  }
}

/// Lavender track + white selected pill segmented control.
class AppSegmentedTabs extends StatelessWidget {
  const AppSegmentedTabs({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    this.padding = EdgeInsets.zero,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: SwimDsTokens.softPurpleBackground.withValues(alpha: 0.92),
          borderRadius:
              BorderRadius.circular(SwimUiTokens.radiusSegmentShell),
          border: Border.all(color: LavenderIndigoTokens.primaryBorder),
        ),
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: selectedIndex == i
                          ? SwimDsTokens.cardBackground
                          : Colors.transparent,
                      borderRadius:
                          BorderRadius.circular(SwimDsTokens.cardRadius * 0.65),
                      border: Border.all(
                        color: selectedIndex == i
                            ? SwimDsTokens.borderSoft
                            : Colors.transparent,
                      ),
                      boxShadow: selectedIndex == i
                          ? SwimDsTokens.cardShadowSoft
                          : null,
                    ),
                    child: Text(
                      labels[i],
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.sora(
                        fontSize: 12.5,
                        fontWeight: selectedIndex == i
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: selectedIndex == i
                            ? SwimDsTokens.textPrimary
                            : SwimDsTokens.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(SwimDsTokens.cardPadding),
    this.margin,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final inner = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: SwimDsTokens.cardBackground,
        borderRadius: BorderRadius.circular(SwimDsTokens.cardRadius),
        border: Border.all(color: SwimDsTokens.borderSoft),
        boxShadow: SwimDsTokens.cardShadowSoft,
      ),
      child: child,
    );
    if (onTap == null) return inner;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(SwimDsTokens.cardRadius),
        onTap: onTap,
        child: inner,
      ),
    );
  }
}

enum SwimStatusPillKind {
  needsAction,
  today,
  newUpdate,
  entered,
  coachApproved,
  notDecided,
  active,
  deadlineSoon,
  training,
  meet,
  neutral,
}

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    this.kind = SwimStatusPillKind.neutral,
    this.icon,
  });

  final String label;
  final SwimStatusPillKind kind;
  final IconData? icon;

  (Color bg, Color fg) _colors() {
    switch (kind) {
      case SwimStatusPillKind.needsAction:
        return (
          SwimDsTokens.dangerCoral.withValues(alpha: 0.14),
          SwimDsTokens.dangerCoral,
        );
      case SwimStatusPillKind.today:
        return (
          SwimDsTokens.infoBlueGray.withValues(alpha: 0.14),
          SwimDsTokens.infoBlueGray,
        );
      case SwimStatusPillKind.newUpdate:
      case SwimStatusPillKind.entered:
      case SwimStatusPillKind.training:
        return (
          SwimDsTokens.newUpdatePurple.withValues(alpha: 0.14),
          SwimDsTokens.primaryPurple,
        );
      case SwimStatusPillKind.coachApproved:
        return (
          SwimDsTokens.tealApproved.withValues(alpha: 0.14),
          SwimDsTokens.tealApproved,
        );
      case SwimStatusPillKind.notDecided:
      case SwimStatusPillKind.neutral:
        return (
          SwimDsTokens.mutedGray.withValues(alpha: 0.12),
          SwimDsTokens.mutedGray,
        );
      case SwimStatusPillKind.active:
        return (
          SwimDsTokens.successGreen.withValues(alpha: 0.14),
          SwimDsTokens.successGreen,
        );
      case SwimStatusPillKind.deadlineSoon:
      case SwimStatusPillKind.meet:
        return (
          SwimDsTokens.warningAmber.withValues(alpha: 0.16),
          const Color(0xFFB45309),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _colors();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.$1,
        borderRadius: BorderRadius.circular(SwimDsTokens.pillRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: c.$2),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: GoogleFonts.sora(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              color: c.$2,
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.check_circle_outline_rounded,
    this.ctaLabel,
    this.onCta,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? ctaLabel;
  final VoidCallback? onCta;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 28, color: SwimDsTokens.textSecondary),
          const SizedBox(height: SwimDsTokens.smallGap),
          Text(
            title,
            style: GoogleFonts.sora(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: SwimDsTokens.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: GoogleFonts.sora(
              fontSize: 13,
              height: 1.4,
              color: SwimDsTokens.textSecondary,
            ),
          ),
          if (ctaLabel != null && onCta != null) ...[
            const SizedBox(height: SwimDsTokens.mediumGap),
            TextButton(
              onPressed: onCta,
              child: Text(
                ctaLabel!,
                style: GoogleFonts.sora(
                  fontWeight: FontWeight.w700,
                  color: SwimDsTokens.tealApproved,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SwimDateTile extends StatelessWidget {
  const SwimDateTile({
    super.key,
    required this.monthAbbrev,
    required this.dayText,
  });

  final String monthAbbrev;
  final String dayText;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: LavenderIndigoTokens.primarySoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: LavenderIndigoTokens.primaryBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            monthAbbrev.toUpperCase(),
            style: GoogleFonts.sora(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: SwimDsTokens.primaryPurple,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            dayText,
            style: GoogleFonts.sora(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: SwimDsTokens.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class SwimPrimaryButton extends StatelessWidget {
  const SwimPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final btn = FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: SwimDsTokens.tealApproved,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      onPressed: onPressed,
      child: Text(
        label,
        style: GoogleFonts.sora(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    );
    if (!expand) return btn;
    return SizedBox(width: double.infinity, child: btn);
  }
}

class SwimSecondaryButton extends StatelessWidget {
  const SwimSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final btn = TextButton(
      style: TextButton.styleFrom(
        foregroundColor: SwimDsTokens.infoBlueGray,
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      onPressed: onPressed,
      child: Text(
        label,
        style: GoogleFonts.sora(fontWeight: FontWeight.w700, fontSize: 14),
      ),
    );
    if (!expand) return btn;
    return SizedBox(width: double.infinity, child: btn);
  }
}

class SwimInsightCard extends StatelessWidget {
  const SwimInsightCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String ctaLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: SwimDsTokens.cardSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.sora(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: SwimDsTokens.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: GoogleFonts.sora(
              fontSize: 13,
              height: 1.35,
              color: SwimDsTokens.textSecondary,
            ),
          ),
          const SizedBox(height: SwimDsTokens.smallGap),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(
                foregroundColor: SwimDsTokens.tealApproved,
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                ctaLabel,
                style: GoogleFonts.sora(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
