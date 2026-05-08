import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '/widgets/swimmer_group_badge_logic.dart';
import '/widgets/swimmer_profile_avatar.dart';

/// Layout preset: avatar diameter and derived badge metrics.
enum SwimmerAvatarGroupBadgeLayout {
  /// Header (~44px avatar, ~18px badge).
  header,

  /// Compact card (~34px avatar, ~16px badge).
  card,

  /// Profile hero — set [avatarDiameter] (e.g. 104).
  profile,
}

/// Swimmer photo (or initials) with a small bottom-right practice-group badge.
class SwimmerAvatarWithGroupBadge extends StatelessWidget {
  const SwimmerAvatarWithGroupBadge({
    super.key,
    required this.filePath,
    required this.webBase64,
    required this.swimmerDisplayName,
    required this.practiceTierLabel,
    required this.clubProfilePracticeGroupRaw,
    required this.allowAutoUnresolvedBadge,
    this.layout = SwimmerAvatarGroupBadgeLayout.header,
    this.avatarDiameter,
  });

  final String? filePath;
  final String? webBase64;
  final String swimmerDisplayName;
  final String practiceTierLabel;
  final String clubProfilePracticeGroupRaw;
  final bool allowAutoUnresolvedBadge;
  final SwimmerAvatarGroupBadgeLayout layout;

  /// Used when [layout] is [SwimmerAvatarGroupBadgeLayout.profile].
  final double? avatarDiameter;

  double get _avatarSize {
    switch (layout) {
      case SwimmerAvatarGroupBadgeLayout.header:
        return 44;
      case SwimmerAvatarGroupBadgeLayout.card:
        return 34;
      case SwimmerAvatarGroupBadgeLayout.profile:
        return avatarDiameter ?? 104;
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final avatar = _avatarSize;
    final badgeD = (avatar * 18 / 44).clamp(16.0, 26.0);
    final fontSize = (avatar * 10.5 / 44).clamp(9.0, 12.5);
    final visual = swimmerGroupBadgeForUi(
      brightness: brightness,
      practiceTierLabel: practiceTierLabel,
      clubProfilePracticeGroupRaw: clubProfilePracticeGroupRaw,
      allowAutoUnresolvedBadge: allowAutoUnresolvedBadge,
    );

    return SizedBox(
      width: avatar,
      height: avatar,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          buildSwimmerProfileAvatar(
            filePath: filePath,
            webBase64: webBase64,
            swimmerDisplayName: swimmerDisplayName,
            size: avatar,
          ),
          if (visual != null)
            Positioned(
              right: -badgeD * 0.06,
              bottom: -badgeD * 0.06,
              child: Semantics(
                label: visual.semanticsLabel,
                container: true,
                child: Container(
                  width: badgeD,
                  height: badgeD,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: visual.backgroundColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    visual.label,
                    style: GoogleFonts.sora(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w700,
                      height: 1,
                      color: visual.foregroundColor,
                      letterSpacing: visual.label.length >= 3 ? -0.2 : 0,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
