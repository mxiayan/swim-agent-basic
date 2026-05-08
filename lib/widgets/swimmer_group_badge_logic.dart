import 'package:flutter/material.dart';

import '/theme/lavender_indigo_tokens.dart';
import '/theme/swim_design_tokens.dart';

/// Normalized practice / age-group mode from profile or club metadata strings.
enum NormalizedSwimmerGroup {
  junior,
  senior,
  auto,
  unknown,
}

/// Paints + semantics for the small group badge (Jr / Sr / Auto).
class SwimmerGroupBadgeVisual {
  const SwimmerGroupBadgeVisual({
    required this.label,
    required this.semanticsLabel,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final String semanticsLabel;
  final Color backgroundColor;
  final Color foregroundColor;
}

String _collapseKey(String s) {
  return s.trim().toLowerCase().replaceAll('_', ' ').replaceAll('-', ' ');
}

/// Maps free-form strings to [NormalizedSwimmerGroup].
/// Empty string is **auto** (matches in-app "Auto (from club profile)" storage).
NormalizedSwimmerGroup normalizeSwimmerGroupInput(String? raw) {
  final t = raw?.trim() ?? '';
  if (t.isEmpty) {
    return NormalizedSwimmerGroup.auto;
  }
  final k = _collapseKey(t);

  if (k == 'auto' ||
      k == 'club profile' ||
      k == 'from club profile' ||
      k.contains('club profile') ||
      k.contains('from club profile')) {
    return NormalizedSwimmerGroup.auto;
  }

  if (k.contains('senior') && !k.contains('junior')) {
    return NormalizedSwimmerGroup.senior;
  }
  if (k == 'senior') {
    return NormalizedSwimmerGroup.senior;
  }

  if (k.contains('junior') ||
      k.contains('age group') ||
      k.contains('agegroup')) {
    return NormalizedSwimmerGroup.junior;
  }

  return NormalizedSwimmerGroup.unknown;
}

/// Full pipeline: profile string + club hint → badge or null.
SwimmerGroupBadgeVisual? swimmerGroupBadgeForUi({
  required Brightness brightness,
  required String practiceTierLabel,
  required String clubProfilePracticeGroupRaw,
  required bool allowAutoUnresolvedBadge,
}) {
  final dark = brightness == Brightness.dark;
  final tierMode = normalizeSwimmerGroupInput(practiceTierLabel);

  // Junior: lavender / purple (aligned with app indigo–lavender family).
  SwimmerGroupBadgeVisual jr() => SwimmerGroupBadgeVisual(
        label: 'Jr',
        semanticsLabel: 'Junior group',
        backgroundColor: dark
            ? const Color(0xFF4C1D95)
            : const Color(0xFFEDE9FE),
        foregroundColor:
            dark ? const Color(0xFFF5F3FF) : LavenderIndigoTokens.primary,
      );

  // Senior: teal / blue (app teal + cyan-tinted fill).
  SwimmerGroupBadgeVisual sr() => SwimmerGroupBadgeVisual(
        label: 'Sr',
        semanticsLabel: 'Senior group',
        backgroundColor: dark
            ? const Color(0xFF134E4A)
            : const Color(0xFFCCFBF1),
        foregroundColor:
            dark ? const Color(0xFFECFEFF) : SwimDsTokens.tealApproved,
      );

  /// Auto / unresolved: neutral gray (light and dark).
  SwimmerGroupBadgeVisual? autoUnresolved() {
    if (!allowAutoUnresolvedBadge) {
      return null;
    }
    return SwimmerGroupBadgeVisual(
      label: 'Auto',
      semanticsLabel: 'Auto from club profile',
      backgroundColor:
          dark ? const Color(0xFF52525B) : const Color(0xFFE5E7EB),
      foregroundColor:
          dark ? const Color(0xFFF4F4F5) : const Color(0xFF374151),
    );
  }

  if (tierMode == NormalizedSwimmerGroup.junior) {
    return jr();
  }
  if (tierMode == NormalizedSwimmerGroup.senior) {
    return sr();
  }
  if (tierMode == NormalizedSwimmerGroup.auto) {
    final fromClub =
        normalizeSwimmerGroupInput(clubProfilePracticeGroupRaw);
    if (fromClub == NormalizedSwimmerGroup.junior) {
      return jr();
    }
    if (fromClub == NormalizedSwimmerGroup.senior) {
      return sr();
    }
    return autoUnresolved();
  }
  return null;
}
