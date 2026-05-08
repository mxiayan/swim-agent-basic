import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '/theme/swim_design_tokens.dart';

/// Horizontal “current time” line for calendar-style timelines.
///
/// Layout: `[time] [dot aligned with spine] [──────────] [Now]`
/// Shown only when [isVisible] and [timelineDate] matches “today” for the
/// schedule (enforced by the parent).
///
/// When [embeddedInCard] is true (drawn only over the **card** column): thin
/// line + dot + clock — no background pill; trailing “Now” hidden.
class CurrentTimeIndicator extends StatelessWidget {
  const CurrentTimeIndicator({
    super.key,
    required this.currentDateTime,
    required this.timelineDate,
    this.leftLabelWidth = 56,
    this.timelineDotColumnWidth = 26,
    this.lineStartGap = 6,
    this.showTimeLabel = true,
    this.showNowLabel = true,
    this.embeddedInCard = false,
    this.isVisible = true,
    this.opacity = 0.82,
    this.onTap,
  });

  final DateTime currentDateTime;
  final DateTime timelineDate;
  final double leftLabelWidth;
  final double timelineDotColumnWidth;
  final double lineStartGap;
  final bool showTimeLabel;

  /// Ignored when [embeddedInCard] is true (label hidden on-card).
  final bool showNowLabel;

  /// Drawn in the card column only (parent supplies narrow width).
  final bool embeddedInCard;

  final bool isVisible;

  /// Applied only when **not** [embeddedInCard]; embedded mode keeps labels crisp.
  final double opacity;
  final VoidCallback? onTap;

  /// Height used to vertically center the overlay on the card (line-only).
  static const double kEmbeddedLayoutHeight = 20;

  static String formatClockLabel(DateTime t) {
    return DateFormat('h:mm a').format(t);
  }

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();
    if (!DateUtils.isSameDay(timelineDate, currentDateTime)) {
      return const SizedBox.shrink();
    }

    final purple = SwimDsTokens.primaryPurple;
    final lineColor = purple.withValues(alpha: embeddedInCard ? 0.45 : 0.40);
    final dotColor = purple;
    final timeColor = embeddedInCard
        ? SwimDsTokens.textPrimary
        : SwimDsTokens.textSecondary;
    final nowColor = purple;
    final timeText =
        showTimeLabel ? formatClockLabel(currentDateTime) : '';

    final mq = MediaQuery.sizeOf(context);
    final wide = mq.width >= 340;
    final showNow =
        !embeddedInCard && showNowLabel && wide;

    Widget row = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (showTimeLabel)
          SizedBox(
            width: leftLabelWidth,
            child: Text(
              timeText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: GoogleFonts.sora(
                fontSize: embeddedInCard ? 11 : 11,
                fontWeight: FontWeight.w700,
                color: timeColor,
              ),
            ),
          ),
        SizedBox(
          width: timelineDotColumnWidth,
          child: Padding(
            padding: const EdgeInsets.only(left: 3.75),
            child: Align(
              alignment: Alignment.center,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor,
                  boxShadow: [
                    BoxShadow(
                      color: dotColor.withValues(alpha: 0.28),
                      blurRadius: 5,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: lineStartGap),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              color: lineColor,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
        if (showNow) ...[
          const SizedBox(width: 8),
          Text(
            'Now',
            style: GoogleFonts.sora(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: nowColor.withValues(alpha: 0.9),
            ),
          ),
        ],
      ],
    );

    if (!embeddedInCard) {
      row = Opacity(opacity: opacity.clamp(0.0, 1.0), child: row);
    }

    final inner = SizedBox(
      height: embeddedInCard ? 20 : 28,
      child: row,
    );

    return Padding(
      padding: EdgeInsets.only(
        bottom: embeddedInCard ? 0 : 10,
        top: embeddedInCard ? 0 : 2,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(embeddedInCard ? 8 : 8),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: embeddedInCard ? 0 : 2,
              vertical: embeddedInCard ? 0 : 4,
            ),
            child: inner,
          ),
        ),
      ),
    );
  }
}
