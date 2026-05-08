import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '/backend/schema/team_events_record.dart';
import '/theme/obsidian_volt_tokens.dart';
import '/theme/swim_design_tokens.dart';
import '/widgets/swim_ui_kit.dart';
import 'schedule_display_item.dart';
import 'schedule_title_normalizer.dart';
import 'team_events_schedule.dart' show normalizeCoachLocationForUi;

/// Vertical timeline + type-colored cards for the Schedule **Upcoming** tab.
class UpcomingTimelineTab extends StatelessWidget {
  const UpcomingTimelineTab({
    super.key,
    required this.items,
    required this.bottomPad,
    required this.onOpenDetail,
  });

  final List<ScheduleDisplayItem> items;
  final double bottomPad;
  final void Function(ScheduleDisplayItem item) onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final pageBg = ObsidianVoltTokens.bgBase;
    final muted = ObsidianVoltTokens.textSecondary;
    final titleColor = ObsidianVoltTokens.textPrimary;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (items.isEmpty) {
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: ColoredBox(
              color: pageBg,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  SwimDsTokens.pageHorizontalPadding,
                  SwimDsTokens.smallGap,
                  SwimDsTokens.pageHorizontalPadding,
                  bottomPad,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TimelineHeader(
                      headerDay: today,
                      totalEvents: 0,
                      cancelledCount: 0,
                      titleColor: titleColor,
                      muted: muted,
                    ),
                    SizedBox(height: SwimDsTokens.cardSpacing),
                    EmptyStateCard(
                      title: 'No events today',
                      message:
                          'Upcoming practices and meets will appear on your timeline.',
                      icon: Icons.event_note_outlined,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    final sorted = List<ScheduleDisplayItem>.from(items)
      ..sort((a, b) => _compareTimelineItems(a, b, now: now, today: today));

    final cancelled =
        sorted.where((i) => _isCancelled(i.record)).length;
    final headerDay = _headerAnchorDay(sorted, today);

    final rows = _buildRows(sorted, today, now);

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: ColoredBox(
            color: pageBg,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                SwimDsTokens.pageHorizontalPadding,
                SwimDsTokens.smallGap,
                SwimDsTokens.pageHorizontalPadding,
                bottomPad,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TimelineHeader(
                    headerDay: headerDay,
                    totalEvents: sorted.length,
                    cancelledCount: cancelled,
                    titleColor: titleColor,
                    muted: muted,
                  ),
                  SizedBox(height: SwimDsTokens.sectionTitleToContentGap + 2),
                  Container(
                    decoration: BoxDecoration(
                      color: SwimDsTokens.cardBackground,
                      borderRadius:
                          BorderRadius.circular(SwimDsTokens.cardRadius),
                      border: Border.all(
                        color: SwimDsTokens.borderSoft,
                        width: 1,
                      ),
                      boxShadow: SwimDsTokens.cardShadowSoft,
                    ),
                    padding: const EdgeInsets.fromLTRB(0, 14, 12, 16),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: 8,
                          top: 26,
                          bottom: 26,
                          width: 1.5,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: ObsidianVoltTokens.timelineSpine,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ...rows.map(
                              (row) => row.build(
                                context,
                                pageBg: pageBg,
                                muted: muted,
                                titleColor: titleColor,
                                now: now,
                                today: today,
                                onTap: onOpenDetail,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  static int _todaySubsectionRank(
    TeamEventsRecord e,
    DateTime now,
    DateTime today,
  ) {
    final ps = e.parsedStart;
    if (ps == null) return 2;
    if (_isHappeningNow(e, now)) return 0;
    if (ps.hour < 12) return 1;
    return 2;
  }

  static int _compareTimelineItems(
    ScheduleDisplayItem a,
    ScheduleDisplayItem b, {
    required DateTime now,
    required DateTime today,
  }) {
    final pa = a.record.parsedStart;
    final pb = b.record.parsedStart;
    if (pa == null && pb == null) {
      return a.record.title.compareTo(b.record.title);
    }
    if (pa == null) return 1;
    if (pb == null) return -1;
    final da = DateTime(pa.year, pa.month, pa.day);
    final db = DateTime(pb.year, pb.month, pb.day);
    final dayCmp = da.compareTo(db);
    if (dayCmp != 0) return dayCmp;
    final ra = _todaySubsectionRank(a.record, now, today);
    final rb = _todaySubsectionRank(b.record, now, today);
    if (ra != rb) return ra.compareTo(rb);
    return pa.compareTo(pb);
  }

  static DateTime _headerAnchorDay(
    List<ScheduleDisplayItem> sorted,
    DateTime today,
  ) {
    DateTime? first;
    for (final i in sorted) {
      final p = i.record.parsedStart;
      if (p == null) continue;
      final d = DateTime(p.year, p.month, p.day);
      if (first == null || d.isBefore(first)) first = d;
    }
    return first ?? today;
  }

  static List<_TimelineRow> _buildRows(
    List<ScheduleDisplayItem> sorted,
    DateTime today,
    DateTime now,
  ) {
    final out = <_TimelineRow>[];
    String? lastDiv;

    for (final item in sorted) {
      final ps = item.record.parsedStart;

      final divLabel = ps == null
          ? 'Date TBD'
          : _sectionDividerLabel(item.record, ps, today, now);

      if (divLabel != lastDiv) {
        out.add(_DividerRow(divLabel));
        lastDiv = divLabel;
      }

      out.add(_EventRow(item: item));
    }

    return out;
  }

  /// Now / Morning / Afternoon for today; Tomorrow; weekday for later dates.
  static String _sectionDividerLabel(
    TeamEventsRecord e,
    DateTime ps,
    DateTime today,
    DateTime now,
  ) {
    final day = DateTime(ps.year, ps.month, ps.day);
    final diff = day.difference(today).inDays;

    if (diff == 0) {
      if (_isHappeningNow(e, now)) return 'Now';
      if (ps.hour < 12) return 'Morning';
      return 'Afternoon';
    }
    if (diff == 1) {
      return 'Tomorrow';
    }
    return DateFormat('EEE, MMM d').format(day);
  }
}

String? _agentHintForEvent(ScheduleDisplayItem item) {
  final blob = '${item.record.details} ${item.summaryPreview}'.toLowerCase();
  if (blob.contains('15 min') || blob.contains('fifteen minute')) {
    return 'Leave 15 minutes early';
  }
  if (blob.contains('coach') &&
      (blob.contains('update') || blob.contains('note'))) {
    return 'Coach update available';
  }
  return null;
}

bool _isCancelled(TeamEventsRecord e) {
  final s = e.status.toLowerCase();
  return s.contains('cancel');
}

bool _isHappeningNow(TeamEventsRecord e, DateTime now) {
  if (_isCancelled(e)) return false;
  final start = e.parsedStart;
  if (start == null) return false;
  final day = DateTime(now.year, now.month, now.day);
  final sd = DateTime(start.year, start.month, start.day);
  if (sd != day) return false;

  final end = e.parsedEnd;
  if (end != null) {
    return !now.isBefore(start) && !now.isAfter(end);
  }
  if (e.endTimeLocal.trim().isNotEmpty) {
    return false;
  }
  return !now.isBefore(start);
}

bool _isFutureDayOrLater(TeamEventsRecord e, DateTime today) {
  final p = e.parsedStart;
  if (p == null) return false;
  final d = DateTime(p.year, p.month, p.day);
  return d.isAfter(today);
}

bool _isTomorrow(TeamEventsRecord e, DateTime today) {
  final p = e.parsedStart;
  if (p == null) return false;
  final d = DateTime(p.year, p.month, p.day);
  final tom = today.add(const Duration(days: 1));
  return d.year == tom.year && d.month == tom.month && d.day == tom.day;
}

abstract class _TimelineRow {
  Widget build(
    BuildContext context, {
    required Color pageBg,
    required Color muted,
    required Color titleColor,
    required DateTime now,
    required DateTime today,
    required void Function(ScheduleDisplayItem item) onTap,
  });
}

class _DividerRow implements _TimelineRow {
  _DividerRow(this.label);
  final String label;

  @override
  Widget build(
    BuildContext context, {
    required Color pageBg,
    required Color muted,
    required Color titleColor,
    required DateTime now,
    required DateTime today,
    required void Function(ScheduleDisplayItem item) onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 26 + 8, top: 12, bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.sora(
          fontSize: 10,
          letterSpacing: 0.6,
          fontWeight: FontWeight.w700,
          color: SwimDsTokens.textSecondary,
        ),
      ),
    );
  }
}

SwimStatusPillKind _typePillKind(TeamEventType t) {
  switch (t) {
    case TeamEventType.meet:
      return SwimStatusPillKind.meet;
    case TeamEventType.training:
      return SwimStatusPillKind.training;
    case TeamEventType.social:
      return SwimStatusPillKind.newUpdate;
    case TeamEventType.admin:
      return SwimStatusPillKind.today;
    case TeamEventType.unknown:
      return SwimStatusPillKind.neutral;
  }
}

class _EventRow implements _TimelineRow {
  _EventRow({required this.item});

  final ScheduleDisplayItem item;

  @override
  Widget build(
    BuildContext context, {
    required Color pageBg,
    required Color muted,
    required Color titleColor,
    required DateTime now,
    required DateTime today,
    required void Function(ScheduleDisplayItem item) onTap,
  }) {
    final cancelled = _isCancelled(item.record);
    final futureWrap =
        !cancelled && (_isFutureDayOrLater(item.record, today) || _isTomorrow(item.record, today));

    final active = !cancelled &&
        !futureWrap &&
        _isHappeningNow(item.record, now);

    final style = cancelled
        ? _TimelinePalette.cancelled()
        : _TimelinePalette.forType(item.record.eventType);

    final dotRing = active && !cancelled;

    final dot = Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: cancelled ? ObsidianVoltTokens.eventCancelledDot : style.dot,
        boxShadow: dotRing
            ? [
                BoxShadow(
                  color: pageBg,
                  blurRadius: 0,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: style.dot,
                  blurRadius: 0,
                  spreadRadius: 3.5,
                ),
              ]
            : null,
      ),
    );

    final detailParts = <String>[];
    if (item.timeDisplayLabel.isNotEmpty) {
      detailParts.add(item.timeDisplayLabel);
    }
    final loc = normalizeCoachLocationForUi(item.locationDisplay);
    if (loc.isNotEmpty) detailParts.add(loc);
    final detailText = detailParts.join(' · ');

    final hint = _agentHintForEvent(item);

    final typeLabel = teamEventTypeLabel(item.record.eventType);
    Widget card = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(SwimDsTokens.cardRadius),
        onTap: () => onTap(item),
        child: Container(
          padding: const EdgeInsets.all(SwimDsTokens.cardPadding - 4),
          decoration: BoxDecoration(
            color: cancelled
                ? ObsidianVoltTokens.eventCancelledCardBg
                : SwimDsTokens.cardBackground,
            borderRadius: BorderRadius.circular(SwimDsTokens.cardRadius),
            border: Border.all(
              color: cancelled
                  ? ObsidianVoltTokens.borderSubtle
                  : SwimDsTokens.borderSoft,
              width: 1,
            ),
            boxShadow:
                cancelled ? null : SwimDsTokens.cardShadowSoft,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (!cancelled)
                    StatusPill(
                      label: typeLabel,
                      kind: _typePillKind(item.record.eventType),
                    )
                  else
                    StatusPill(
                      label: 'CANCELLED',
                      kind: SwimStatusPillKind.neutral,
                    ),
                  if (!cancelled && item.squadLabel.trim().isNotEmpty) ...[
                    const SizedBox(width: 8),
                    StatusPill(
                      label: item.squadLabel,
                      kind: SwimStatusPillKind.notDecided,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(
                scheduleEventTitleForUi(item.record).isEmpty
                    ? '(Untitled)'
                    : scheduleEventTitleForUi(item.record),
                style: GoogleFonts.sora(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                  color: titleColor,
                  decoration:
                      cancelled ? TextDecoration.lineThrough : TextDecoration.none,
                ),
              ),
              if (detailText.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  detailText,
                  style: GoogleFonts.sora(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: muted,
                  ),
                ),
              ],
              if (hint != null && !cancelled) ...[
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 14,
                      color: SwimDsTokens.primaryPurple.withValues(alpha: 0.85),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        hint,
                        style: GoogleFonts.sora(
                          fontSize: 11.5,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                          color: SwimDsTokens.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (cancelled) {
      card = Opacity(opacity: 0.38, child: card);
    } else if (futureWrap) {
      card = Opacity(opacity: 0.72, child: card);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 26,
            child: Padding(
              padding: const EdgeInsets.only(left: 3.75, top: 14),
              child: dot,
            ),
          ),
          Expanded(child: card),
        ],
      ),
    );
  }
}

class _TimelineHeader extends StatelessWidget {
  const _TimelineHeader({
    required this.headerDay,
    required this.totalEvents,
    required this.cancelledCount,
    required this.titleColor,
    required this.muted,
  });

  final DateTime headerDay;
  final int totalEvents;
  final int cancelledCount;
  final Color titleColor;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final title =
        '${weekdays[headerDay.weekday - 1]}, ${months[headerDay.month - 1]} ${headerDay.day}';
    final sub = cancelledCount > 0
        ? '$totalEvents events · $cancelledCount cancelled'
        : '$totalEvents events';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.sora(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: GoogleFonts.sora(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelinePalette {
  _TimelinePalette({
    required this.dot,
    required this.tagBg,
    required this.tagText,
    required this.cardBg,
    required this.cardBorder,
  });

  final Color dot;
  final Color tagBg;
  final Color tagText;
  final Color cardBg;
  final Color cardBorder;

  static _TimelinePalette forType(TeamEventType t) {
    switch (t) {
      case TeamEventType.training:
        return _TimelinePalette(
          dot: ObsidianVoltTokens.eventTrainingDot,
          tagBg: ObsidianVoltTokens.eventTrainingTagBg,
          tagText: ObsidianVoltTokens.eventTrainingTagText,
          cardBg: ObsidianVoltTokens.eventTrainingCardTint,
          cardBorder: ObsidianVoltTokens.eventTrainingCardBorder,
        );
      case TeamEventType.meet:
        return _TimelinePalette(
          dot: ObsidianVoltTokens.eventMeetDot,
          tagBg: ObsidianVoltTokens.eventMeetTagBg,
          tagText: ObsidianVoltTokens.eventMeetTagText,
          cardBg: ObsidianVoltTokens.eventMeetCardTint,
          cardBorder: ObsidianVoltTokens.eventMeetCardBorder,
        );
      case TeamEventType.admin:
        return _TimelinePalette(
          dot: ObsidianVoltTokens.eventAdminDot,
          tagBg: ObsidianVoltTokens.eventAdminTagBg,
          tagText: ObsidianVoltTokens.eventAdminTagText,
          cardBg: ObsidianVoltTokens.eventAdminCardTint,
          cardBorder: ObsidianVoltTokens.eventAdminCardBorder,
        );
      case TeamEventType.social:
        return _TimelinePalette(
          dot: ObsidianVoltTokens.eventSocialDot,
          tagBg: ObsidianVoltTokens.eventSocialTagBg,
          tagText: ObsidianVoltTokens.eventSocialTagText,
          cardBg: ObsidianVoltTokens.eventSocialCardTint,
          cardBorder: ObsidianVoltTokens.eventSocialCardBorder,
        );
      case TeamEventType.unknown:
        return _TimelinePalette(
          dot: ObsidianVoltTokens.textSecondary,
          tagBg: ObsidianVoltTokens.bgOverlay,
          tagText: ObsidianVoltTokens.textSecondary,
          cardBg: ObsidianVoltTokens.bgOverlay,
          cardBorder: ObsidianVoltTokens.borderSubtle,
        );
    }
  }

  static _TimelinePalette cancelled() => _TimelinePalette(
        dot: ObsidianVoltTokens.eventCancelledDot,
        tagBg: ObsidianVoltTokens.bgOverlay,
        tagText: ObsidianVoltTokens.textTertiary,
        cardBg: ObsidianVoltTokens.eventCancelledCardBg,
        cardBorder: ObsidianVoltTokens.borderSubtle,
      );
}
