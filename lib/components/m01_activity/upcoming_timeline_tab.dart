import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '/backend/schema/team_events_record.dart';
import '/theme/obsidian_volt_tokens.dart';
import '/theme/swim_ui_tokens.dart';
import 'schedule_display_item.dart';
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
    final surfaceBg = ObsidianVoltTokens.bgSurface;
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
                padding: EdgeInsets.fromLTRB(24, 12, 24, bottomPad),
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
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: surfaceBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: SwimUiTokens.cardSurfaceEdgeBorder,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'No upcoming events',
                        style: GoogleFonts.sora(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: muted,
                        ),
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

    final sorted = List<ScheduleDisplayItem>.from(items)
      ..sort((a, b) {
        final pa = a.record.parsedStart;
        final pb = b.record.parsedStart;
        if (pa == null && pb == null) {
          return a.record.title.compareTo(b.record.title);
        }
        if (pa == null) return 1;
        if (pb == null) return -1;
        return pa.compareTo(pb);
      });

    final cancelled =
        sorted.where((i) => _isCancelled(i.record)).length;
    final headerDay = _headerAnchorDay(sorted, today);

    final rows = _buildRows(sorted, today);
    final showNow = sorted.any((i) => _isHappeningNow(i.record, now));

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: ColoredBox(
            color: pageBg,
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 12, 24, bottomPad),
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
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: surfaceBg,
                      borderRadius:
                          BorderRadius.circular(SwimUiTokens.radiusMd),
                      border: Border.all(
                        color: SwimUiTokens.cardSurfaceEdgeBorder,
                        width: 1,
                      ),
                      boxShadow: SwimUiTokens.shadowCard,
                    ),
                    padding: const EdgeInsets.fromLTRB(0, 14, 14, 16),
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
                            if (showNow)
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Padding(
                                  padding:
                                      EdgeInsets.only(left: 26 + 8, bottom: 10),
                                  child: _NowBadge(),
                                ),
                              ),
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
  ) {
    final out = <_TimelineRow>[];
    String? lastDiv;

    for (final item in sorted) {
      final ps = item.record.parsedStart;

      final divLabel = ps == null
          ? 'DATE TBD'
          : _sectionDividerLabel(ps, today);

      if (divLabel != lastDiv) {
        out.add(_DividerRow(divLabel));
        lastDiv = divLabel;
      }

      out.add(_EventRow(item: item));
    }

    return out;
  }

  /// MORNING / EVENING for today; TOMORROW; weekday header for later dates.
  static String _sectionDividerLabel(DateTime ps, DateTime today) {
    final day = DateTime(ps.year, ps.month, ps.day);
    final diff = day.difference(today).inDays;

    if (diff == 0) {
      return ps.hour < 12 ? 'MORNING' : 'EVENING';
    }
    if (diff == 1) {
      return 'TOMORROW';
    }
    const wds = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    const mos = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
    ];
    return '${wds[day.weekday - 1]}, ${mos[day.month - 1]} ${day.day}';
  }
}

bool _isCancelled(TeamEventsRecord e) {
  final s = e.status.toLowerCase();
  return s.contains('cancel');
}

DateTime? _eventEndLocal(TeamEventsRecord e) {
  final s = e.parsedStart;
  if (s == null) return null;
  final t = e.endTimeLocal.trim();
  final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(t);
  if (m == null) return null;
  return DateTime(
    s.year,
    s.month,
    s.day,
    int.parse(m.group(1)!),
    int.parse(m.group(2)!),
  );
}

bool _isHappeningNow(TeamEventsRecord e, DateTime now) {
  if (_isCancelled(e)) return false;
  final start = e.parsedStart;
  if (start == null) return false;
  final day = DateTime(now.year, now.month, now.day);
  final sd = DateTime(start.year, start.month, start.day);
  if (sd != day) return false;

  final end = _eventEndLocal(e);
  if (end != null) {
    return !now.isBefore(start) && !now.isAfter(end);
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
        label,
        style: GoogleFonts.sora(
          fontSize: 10,
          letterSpacing: 0.5,
          fontWeight: FontWeight.w400,
          color: ObsidianVoltTokens.textTertiary,
        ),
      ),
    );
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

    Widget card = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => onTap(item),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: cancelled
                ? ObsidianVoltTokens.eventCancelledCardBg
                : style.cardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: cancelled
                  ? ObsidianVoltTokens.borderSubtle
                  : SwimUiTokens.cardSurfaceEdgeBorder,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _TypeTag(
                    label: teamEventTypeLabel(item.record.eventType).toUpperCase(),
                    bg: cancelled
                        ? ObsidianVoltTokens.bgOverlay
                        : style.tagBg,
                    fg: cancelled
                        ? ObsidianVoltTokens.textTertiary
                        : style.tagText,
                  ),
                  if (!cancelled && item.squadLabel.trim().isNotEmpty) ...[
                    const SizedBox(width: 8),
                    _SquadTag(label: item.squadLabel),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                item.record.title.isEmpty ? '(Untitled)' : item.record.title,
                style: GoogleFonts.sora(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                  color: titleColor,
                  decoration:
                      cancelled ? TextDecoration.lineThrough : TextDecoration.none,
                ),
              ),
              if (detailText.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  detailText,
                  style: GoogleFonts.sora(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: muted,
                  ),
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
      card = Opacity(opacity: 0.5, child: card);
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
              fontSize: 18,
              fontWeight: FontWeight.w500,
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

class _NowBadge extends StatelessWidget {
  const _NowBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ObsidianVoltTokens.nowBadgeBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: ObsidianVoltTokens.accent,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              'Now',
              style: GoogleFonts.sora(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: ObsidianVoltTokens.nowBadgeText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeTag extends StatelessWidget {
  const _TypeTag({
    required this.label,
    required this.bg,
    required this.fg,
  });

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: GoogleFonts.sora(
          fontSize: 9,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.18,
          color: fg,
        ),
      ),
    );
  }
}

class _SquadTag extends StatelessWidget {
  const _SquadTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final u = label.toUpperCase();
    late Color bg;
    late Color fg;

    if (u.contains('JUNIOR') || u.contains('JR')) {
      bg = ObsidianVoltTokens.squadJuniorBg;
      fg = ObsidianVoltTokens.squadJuniorText;
    } else if (u.contains('SENIOR') || u.contains('SR')) {
      bg = ObsidianVoltTokens.squadSeniorBg;
      fg = ObsidianVoltTokens.squadSeniorText;
    } else {
      bg = ObsidianVoltTokens.squadAllBg;
      fg = ObsidianVoltTokens.squadAllText;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: GoogleFonts.sora(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
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
