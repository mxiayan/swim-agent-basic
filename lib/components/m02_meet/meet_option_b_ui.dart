import '/theme/lavender_indigo_tokens.dart';
import '/theme/swim_design_tokens.dart';
import '/theme/swim_ui_tokens.dart';
import '/widgets/top_pill_tabs.dart';
import 'meet_overview_metrics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

/// Polished My Meets / All Meets pill tabs (Option B).
class MeetPillTabs extends StatelessWidget {
  const MeetPillTabs({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
  });

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return TopPillTabs(
      items: const [
        TopPillTabItem(label: 'My Meets', icon: Icons.person_rounded),
        TopPillTabItem(label: 'All Meets', icon: Icons.public_rounded),
      ],
      selectedIndex: selectedIndex,
      onChanged: onChanged,
    );
  }
}

/// Purple gradient summary card with four metrics.
class MeetOverviewGradientCard extends StatelessWidget {
  const MeetOverviewGradientCard({
    super.key,
    required this.counts,
  });

  final MeetOverviewCounts counts;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF4C3FA8),
            Color(0xFF2D2A5C),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2D2A5C).withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Your Meet Overview',
                  style: GoogleFonts.sora(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              Text(
                'This Season',
                style: GoogleFonts.sora(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _metric(
                  icon: Icons.check_circle_outline_rounded,
                  iconColor: const Color(0xFFBBF7D0),
                  value: counts.entered,
                  label: 'Entered',
                ),
              ),
              Expanded(
                child: _metric(
                  icon: Icons.schedule_rounded,
                  iconColor: const Color(0xFFFDE68A),
                  value: counts.pending,
                  label: 'Pending',
                ),
              ),
              Expanded(
                child: _metric(
                  icon: Icons.radio_button_unchecked_rounded,
                  iconColor: Colors.white.withValues(alpha: 0.9),
                  value: counts.notEntered,
                  label: 'Not Entered',
                ),
              ),
              Expanded(
                child: _metric(
                  icon: Icons.visibility_outlined,
                  iconColor: const Color(0xFFFDE68A),
                  value: counts.toReview,
                  label: 'To Review',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric({
    required IconData icon,
    required Color iconColor,
    required int value,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(height: 4),
        Text(
          '$value',
          style: GoogleFonts.sora(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          style: GoogleFonts.sora(
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            height: 1.15,
            color: Colors.white.withValues(alpha: 0.82),
          ),
        ),
      ],
    );
  }
}

/// Agent nudge after the upcoming list (hidden when [undecidedCount] == 0).
class MeetAgentSuggestionCard extends StatelessWidget {
  const MeetAgentSuggestionCard({
    super.key,
    required this.undecidedCount,
    required this.onReview,
  });

  final int undecidedCount;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    if (undecidedCount <= 0) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: SwimDsTokens.borderSoft),
          boxShadow: SwimDsTokens.cardShadowSoft,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome_rounded,
                    size: 18, color: SwimDsTokens.primaryPurple),
                const SizedBox(width: 8),
                Text(
                  'Agent suggestion',
                  style: GoogleFonts.sora(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: SwimDsTokens.primaryPurple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              undecidedCount == 1
                  ? 'You have 1 upcoming meet you have not decided on yet.'
                  : 'You have $undecidedCount upcoming meets not decided yet.',
              style: GoogleFonts.sora(
                fontSize: 13,
                height: 1.35,
                color: SwimUiTokens.textTitle,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LavenderIndigoTokens.heroGradient,
                  boxShadow: LavenderIndigoTokens.shadowSm,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: onReview,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Center(
                        child: Text(
                          'Review All Meets',
                          style: GoogleFonts.sora(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(
          delay: 180.ms,
          duration: 220.ms,
          curve: Curves.easeOutCubic,
        ).slideY(
          begin: 0.08,
          delay: 180.ms,
          duration: 220.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

/// Bottom row: open past meets (toggles app flag if available).
class MeetViewPastRow extends StatelessWidget {
  const MeetViewPastRow({
    super.key,
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: SwimDsTokens.borderSoft),
              boxShadow: SwimDsTokens.cardShadowSoft,
            ),
            child: Row(
              children: [
                Icon(Icons.history_rounded,
                    color: SwimUiTokens.textMuted, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'View past meets',
                    style: GoogleFonts.sora(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: SwimUiTokens.textTitle,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: SwimUiTokens.textFaint, size: 24),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(
          delay: 180.ms,
          duration: 220.ms,
          curve: Curves.easeOutCubic,
        ).slideY(
          begin: 0.08,
          delay: 180.ms,
          duration: 220.ms,
          curve: Curves.easeOutCubic,
        );
  }
}
