import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '/backend/backend.dart';
import '/theme/swim_ui_tokens.dart';

/// Renders the parser-produced `team_events` collection as a scannable list
/// for the Schedule tab. This is the user-facing replacement for poking at
/// raw Firestore JSON.
class TeamEventsScheduleList extends StatefulWidget {
  const TeamEventsScheduleList({super.key, required this.teamId});

  final String teamId;

  @override
  State<TeamEventsScheduleList> createState() => _TeamEventsScheduleListState();
}

class _TeamEventsScheduleListState extends State<TeamEventsScheduleList> {
  TeamEventType? _typeFilter;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: SwimUiTokens.surfaceCanvasSchedule,
      child: StreamBuilder<List<TeamEventsRecord>>(
        stream: streamTeamEvents(widget.teamId),
        builder: (context, snap) {
          if (snap.hasError) {
            return _ErrorState(message: snap.error.toString());
          }
          if (!snap.hasData) {
            return const _LoadingState();
          }
          final all = snap.data!;
          if (all.isEmpty) {
            return const _EmptyState();
          }

          final counts = <TeamEventType, int>{};
          for (final e in all) {
            counts[e.eventType] = (counts[e.eventType] ?? 0) + 1;
          }

          final filtered = (_typeFilter == null
                  ? all
                  : all.where((e) => e.eventType == _typeFilter).toList())
              .toList();

          // Sort: dated upcoming asc → dated past desc → undated last.
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          int bucket(TeamEventsRecord e) {
            if (e.parsedStart == null) return 2;
            final eDay = DateTime(
              e.parsedStart!.year,
              e.parsedStart!.month,
              e.parsedStart!.day,
            );
            return eDay.isBefore(today) ? 1 : 0;
          }

          filtered.sort((a, b) {
            final ba = bucket(a);
            final bb = bucket(b);
            if (ba != bb) return ba.compareTo(bb);
            if (a.parsedStart != null && b.parsedStart != null) {
              if (ba == 0) {
                return a.parsedStart!.compareTo(b.parsedStart!);
              }
              if (ba == 1) {
                return b.parsedStart!.compareTo(a.parsedStart!);
              }
            }
            return a.title.toLowerCase().compareTo(b.title.toLowerCase());
          });

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _FilterStrip(
                  totalCount: all.length,
                  counts: counts,
                  selected: _typeFilter,
                  onChanged: (t) => setState(() => _typeFilter = t),
                ),
              ),
              if (filtered.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyFilterState(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(14.0, 4.0, 14.0, 28.0),
                  sliver: SliverList.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10.0),
                    itemBuilder: (context, i) =>
                        _TeamEventCard(event: filtered[i]),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Top filter strip ───────────────────────────────────────────────────────

class _FilterStrip extends StatelessWidget {
  const _FilterStrip({
    required this.totalCount,
    required this.counts,
    required this.selected,
    required this.onChanged,
  });

  final int totalCount;
  final Map<TeamEventType, int> counts;
  final TeamEventType? selected;
  final ValueChanged<TeamEventType?> onChanged;

  static const _orderedTypes = [
    TeamEventType.meet,
    TeamEventType.training,
    TeamEventType.social,
    TeamEventType.admin,
  ];

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      _Chip(
        label: 'All',
        count: totalCount,
        selected: selected == null,
        onTap: () => onChanged(null),
        accent: SwimUiTokens.accentBlue,
      ),
    ];
    for (final t in _orderedTypes) {
      final c = counts[t] ?? 0;
      if (c == 0 && selected != t) continue;
      final visual = _typeVisual(t);
      chips.add(
        _Chip(
          label: teamEventTypeLabel(t),
          count: c,
          selected: selected == t,
          onTap: () => onChanged(t),
          accent: visual.accent,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(14.0, 14.0, 14.0, 6.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < chips.length; i++) ...[
              if (i > 0) const SizedBox(width: 8.0),
              chips[i],
            ],
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    required this.accent,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? accent : Colors.white;
    final fg = selected ? Colors.white : SwimUiTokens.textTitle;
    final border = selected ? accent : SwimUiTokens.borderSubtle;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(999.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(999.0),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999.0),
            border: Border.all(color: border, width: 1.0),
          ),
          padding:
              const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.sora(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: fg,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(width: 6.0),
              Text(
                '$count',
                style: GoogleFonts.sora(
                  fontSize: 12.0,
                  fontWeight: FontWeight.w500,
                  color: selected
                      ? Colors.white.withValues(alpha: 0.85)
                      : SwimUiTokens.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Per-event card ─────────────────────────────────────────────────────────

class _TeamEventCard extends StatelessWidget {
  const _TeamEventCard({required this.event});

  final TeamEventsRecord event;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static const _weekdays = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
  ];

  @override
  Widget build(BuildContext context) {
    final visual = _typeVisual(event.eventType);
    final dateLine = _formatDateLine(event);
    final timeLine = _formatTimeLine(event);
    final isPast = _isPast(event);

    final r = BorderRadius.circular(SwimUiTokens.radiusCard);

    // Left accent + gray outline: cannot use one BoxDecoration with
    // borderRadius + non-uniform Border colors (Flutter asserts at paint).
    // Uniform border on the outer box + a 4px strip in a Stack instead.
    return ClipRRect(
      borderRadius: r,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: SwimUiTokens.surfaceCard,
          borderRadius: r,
          border: Border.all(color: SwimUiTokens.borderSubtle, width: 1.0),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: () => _showEventSheet(context, event),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 4.0,
                    color: visual.accent,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4.0 + 14.0, 12.0, 14.0, 14.0),
                  child: DefaultTextStyle.merge(
                    style: const TextStyle(
                      color: SwimUiTokens.textTitle,
                      fontSize: 14.0,
                      height: 1.35,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.title.isEmpty
                              ? '(untitled event)'
                              : event.title,
                          style: GoogleFonts.sora(
                            fontSize: 16.0,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                            color: isPast
                                ? SwimUiTokens.textMuted
                                : SwimUiTokens.textBannerTitle,
                          ),
                        ),
                        const SizedBox(height: 10.0),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _TypeBadge(visual: visual),
                            const SizedBox(width: 8.0),
                            if (event.appliesToGroups.isNotEmpty)
                              Expanded(
                                child: Wrap(
                                  spacing: 6.0,
                                  runSpacing: 4.0,
                                  alignment: WrapAlignment.start,
                                  children: event.appliesToGroups
                                      .map((g) => _GroupChip(label: g))
                                      .toList(),
                                ),
                              )
                            else
                              const Spacer(),
                            if (dateLine.isNotEmpty)
                              Text(
                                dateLine,
                                textAlign: TextAlign.right,
                                style: GoogleFonts.sora(
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.w600,
                                  color: isPast
                                      ? SwimUiTokens.textFaint
                                      : SwimUiTokens.textTitle,
                                  letterSpacing: 0.1,
                                ),
                              ),
                          ],
                        ),
                        if (timeLine.isNotEmpty ||
                            event.location.isNotEmpty) ...[
                          const SizedBox(height: 8.0),
                          _IconLine(
                            icon: Icons.access_time_rounded,
                            text: [
                              if (timeLine.isNotEmpty) timeLine,
                              if (event.location.isNotEmpty) event.location,
                            ].join('  ·  '),
                          ),
                        ],
                        if (event.isRecurring &&
                            event.recurrenceRule.isNotEmpty) ...[
                          const SizedBox(height: 4.0),
                          _IconLine(
                            icon: Icons.repeat_rounded,
                            text: _humanRecurrence(event.recurrenceRule),
                          ),
                        ],
                        if (event.entryDeadline.isNotEmpty) ...[
                          const SizedBox(height: 4.0),
                          _IconLine(
                            icon: Icons.event_busy_rounded,
                            text:
                                'Entry deadline: ${event.entryDeadline}',
                            emphasize: !isPast,
                          ),
                        ],
                        if (event.status.isNotEmpty &&
                            event.status.toUpperCase() != 'TBD') ...[
                          const SizedBox(height: 4.0),
                          _IconLine(
                            icon: Icons.flag_outlined,
                            text: 'Status: ${event.status}',
                          ),
                        ],
                        if (event.details.isNotEmpty) ...[
                          const SizedBox(height: 8.0),
                          Text(
                            event.details,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.sora(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w400,
                              height: 1.4,
                              color: SwimUiTokens.textMuted,
                            ),
                          ),
                        ],
                        if (event.sourceSection.isNotEmpty) ...[
                          const SizedBox(height: 8.0),
                          Text(
                            'Source: ${event.sourceSection}',
                            style: GoogleFonts.sora(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              color: SwimUiTokens.textFaint,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static bool _isPast(TeamEventsRecord e) {
    final s = e.parsedStart;
    if (s == null) return false;
    final today = DateTime.now();
    final eDay = DateTime(s.year, s.month, s.day);
    final todayDay = DateTime(today.year, today.month, today.day);
    return eDay.isBefore(todayDay);
  }

  static String _formatDateLine(TeamEventsRecord e) {
    final s = e.parsedStart;
    if (s == null) {
      return e.startDate; // Show whatever raw value we have, even if odd.
    }
    final wd = _weekdays[(s.weekday - 1).clamp(0, 6)];
    final mo = _months[(s.month - 1).clamp(0, 11)];
    return '$wd, $mo ${s.day}';
  }

  static String _formatTimeLine(TeamEventsRecord e) {
    String fmt(String hhmm) {
      final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(hhmm);
      if (m == null) return hhmm;
      var h = int.parse(m.group(1)!);
      final mins = m.group(2)!;
      final am = h < 12;
      var hh12 = h % 12;
      if (hh12 == 0) hh12 = 12;
      return mins == '00'
          ? '$hh12${am ? 'a' : 'p'}'
          : '$hh12:$mins${am ? 'a' : 'p'}';
    }

    final start = e.startTimeLocal.isNotEmpty ? fmt(e.startTimeLocal) : '';
    final end = e.endTimeLocal.isNotEmpty ? fmt(e.endTimeLocal) : '';
    if (start.isEmpty && end.isEmpty) return '';
    if (end.isEmpty) return start;
    return '$start–$end';
  }

  static String _humanRecurrence(String rrule) {
    // Best-effort prettify: FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR → "Weekly · Mon-Fri"
    final freqMatch = RegExp(r'FREQ=([A-Z]+)').firstMatch(rrule);
    final byDayMatch = RegExp(r'BYDAY=([A-Z,]+)').firstMatch(rrule);
    final freq = freqMatch?.group(1) ?? '';
    final byDay = byDayMatch?.group(1) ?? '';
    final freqPart = switch (freq) {
      'DAILY' => 'Daily',
      'WEEKLY' => 'Weekly',
      'MONTHLY' => 'Monthly',
      'YEARLY' => 'Yearly',
      _ => 'Recurs',
    };
    if (byDay.isEmpty) return freqPart;
    const map = {
      'MO': 'Mon',
      'TU': 'Tue',
      'WE': 'Wed',
      'TH': 'Thu',
      'FR': 'Fri',
      'SA': 'Sat',
      'SU': 'Sun',
    };
    final pretty = byDay.split(',').map((d) => map[d] ?? d).join(', ');
    return '$freqPart · $pretty';
  }

  static Future<void> _showEventSheet(
      BuildContext context, TeamEventsRecord e) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(18.0)),
      ),
      builder: (_) => _EventDetailSheet(event: e),
    );
  }
}

class _IconLine extends StatelessWidget {
  const _IconLine({
    required this.icon,
    required this.text,
    this.emphasize = false,
  });

  final IconData icon;
  final String text;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 14.0,
          color: emphasize
              ? SwimUiTokens.accentBlue
              : SwimUiTokens.textMuted,
        ),
        const SizedBox(width: 6.0),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.sora(
              fontSize: 12.5,
              fontWeight:
                  emphasize ? FontWeight.w600 : FontWeight.w500,
              color: emphasize
                  ? SwimUiTokens.accentBlue
                  : SwimUiTokens.textTitle,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.visual});
  final _TypeVisual visual;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: visual.fill,
        borderRadius: BorderRadius.circular(999.0),
        border: Border.all(color: visual.border, width: 0.6),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(visual.icon, size: 12.0, color: visual.accent),
          const SizedBox(width: 4.0),
          Text(
            visual.label,
            style: GoogleFonts.sora(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: visual.accent,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupChip extends StatelessWidget {
  const _GroupChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(999.0),
        border: Border.all(color: const Color(0xFFC7D2FE), width: 0.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 2.0),
      child: Text(
        label,
        style: GoogleFonts.sora(
          fontSize: 10.0,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF4338CA),
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// ─── Detail bottom sheet ────────────────────────────────────────────────────

class _EventDetailSheet extends StatelessWidget {
  const _EventDetailSheet({required this.event});
  final TeamEventsRecord event;

  @override
  Widget build(BuildContext context) {
    final visual = _typeVisual(event.eventType);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20.0, 12.0, 20.0, 20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38.0,
                height: 4.0,
                decoration: BoxDecoration(
                  color: SwimUiTokens.borderSection,
                  borderRadius: BorderRadius.circular(999.0),
                ),
              ),
            ),
            const SizedBox(height: 14.0),
            Row(
              children: [
                _TypeBadge(visual: visual),
                const Spacer(),
                if (event.parsingConfidence > 0)
                  Text(
                    'Confidence: ${(event.parsingConfidence * 100).round()}%',
                    style: GoogleFonts.sora(
                      fontSize: 11.0,
                      fontWeight: FontWeight.w600,
                      color: SwimUiTokens.textMuted,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10.0),
            Text(
              event.title.isEmpty ? '(untitled event)' : event.title,
              style: GoogleFonts.sora(
                fontSize: 19.0,
                fontWeight: FontWeight.w700,
                color: SwimUiTokens.textBannerTitle,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 16.0),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _kv('Date', _kvDate(event)),
                    _kv('Time', _kvTime(event)),
                    if (event.appliesToGroups.isNotEmpty)
                      _kv('Groups', event.appliesToGroups.join(', ')),
                    if (event.location.isNotEmpty)
                      _kv('Location', event.location),
                    if (event.timezone.isNotEmpty)
                      _kv('Timezone', event.timezone),
                    if (event.isRecurring)
                      _kv(
                        'Recurrence',
                        event.recurrenceRule.isNotEmpty
                            ? event.recurrenceRule
                            : 'recurring',
                      ),
                    if (event.entryDeadline.isNotEmpty)
                      _kv('Entry deadline', event.entryDeadline),
                    if (event.status.isNotEmpty)
                      _kv('Status', event.status),
                    if (event.entryUrl.isNotEmpty)
                      _kvLink(context, 'Entry URL', event.entryUrl),
                    if (event.details.isNotEmpty) ...[
                      const SizedBox(height: 6.0),
                      Text(
                        'Details',
                        style: GoogleFonts.sora(
                          fontSize: 12.0,
                          fontWeight: FontWeight.w700,
                          color: SwimUiTokens.textMuted,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      Text(
                        event.details,
                        style: GoogleFonts.sora(
                          fontSize: 13.0,
                          fontWeight: FontWeight.w500,
                          height: 1.45,
                          color: SwimUiTokens.textTitle,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18.0),
                    Container(
                      decoration: BoxDecoration(
                        color: SwimUiTokens.surfaceCanvasSchedule,
                        borderRadius: BorderRadius.circular(10.0),
                        border: Border.all(
                          color: SwimUiTokens.borderSubtle,
                          width: 1.0,
                        ),
                      ),
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Source',
                            style: GoogleFonts.sora(
                              fontSize: 11.0,
                              fontWeight: FontWeight.w700,
                              color: SwimUiTokens.textMuted,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 6.0),
                          if (event.subject.isNotEmpty)
                            _smallKv('Subject', event.subject),
                          if (event.sender.isNotEmpty)
                            _smallKv('From', event.sender),
                          if (event.sourceSection.isNotEmpty)
                            _smallKv('Section', event.sourceSection),
                          if (event.processedAt != null)
                            _smallKv(
                              'Processed',
                              event.processedAt!.toLocal().toString(),
                            ),
                          _smallKv('Doc id', event.docId),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _kvDate(TeamEventsRecord e) {
    if (e.startDate.isEmpty && e.endDate.isEmpty) {
      return '(none)';
    }
    if (e.endDate.isNotEmpty && e.endDate != e.startDate) {
      return '${e.startDate} → ${e.endDate}';
    }
    return e.startDate;
  }

  static String _kvTime(TeamEventsRecord e) {
    if (e.startTimeLocal.isEmpty && e.endTimeLocal.isEmpty) {
      return '(none)';
    }
    if (e.endTimeLocal.isEmpty) return e.startTimeLocal;
    return '${e.startTimeLocal} – ${e.endTimeLocal}';
  }

  static Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110.0,
            child: Text(
              label,
              style: GoogleFonts.sora(
                fontSize: 12.0,
                fontWeight: FontWeight.w600,
                color: SwimUiTokens.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.sora(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: SwimUiTokens.textTitle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _kvLink(BuildContext context, String label, String url) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110.0,
            child: Text(
              label,
              style: GoogleFonts.sora(
                fontSize: 12.0,
                fontWeight: FontWeight.w600,
                color: SwimUiTokens.textMuted,
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () async {
                final uri = Uri.tryParse(url);
                if (uri != null) {
                  await launchUrl(uri,
                      mode: LaunchMode.externalApplication);
                }
              },
              child: Text(
                url,
                style: GoogleFonts.sora(
                  fontSize: 13.0,
                  fontWeight: FontWeight.w600,
                  color: SwimUiTokens.accentBlue,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _smallKv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: GoogleFonts.sora(
                fontSize: 11.0,
                fontWeight: FontWeight.w700,
                color: SwimUiTokens.textMuted,
              ),
            ),
            TextSpan(
              text: value,
              style: GoogleFonts.sora(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: SwimUiTokens.textTitle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Visuals per event type ─────────────────────────────────────────────────

class _TypeVisual {
  const _TypeVisual({
    required this.label,
    required this.icon,
    required this.accent,
    required this.fill,
    required this.border,
  });
  final String label;
  final IconData icon;
  final Color accent;
  final Color fill;
  final Color border;
}

_TypeVisual _typeVisual(TeamEventType t) {
  switch (t) {
    case TeamEventType.meet:
      return const _TypeVisual(
        label: 'MEET',
        icon: Icons.pool_rounded,
        accent: Color(0xFF1D4ED8),
        fill: Color(0xFFEFF6FF),
        border: Color(0xFFBFDBFE),
      );
    case TeamEventType.training:
      return const _TypeVisual(
        label: 'TRAINING',
        icon: Icons.fitness_center_rounded,
        accent: Color(0xFF15803D),
        fill: Color(0xFFF0FDF4),
        border: Color(0xFFBBF7D0),
      );
    case TeamEventType.social:
      return const _TypeVisual(
        label: 'SOCIAL',
        icon: Icons.celebration_rounded,
        accent: Color(0xFFB45309),
        fill: Color(0xFFFFFBEB),
        border: Color(0xFFFDE68A),
      );
    case TeamEventType.admin:
      return const _TypeVisual(
        label: 'ADMIN',
        icon: Icons.assignment_outlined,
        accent: Color(0xFF7C3AED),
        fill: Color(0xFFF5F3FF),
        border: Color(0xFFDDD6FE),
      );
    case TeamEventType.unknown:
      return const _TypeVisual(
        label: 'OTHER',
        icon: Icons.event_note_rounded,
        accent: Color(0xFF475569),
        fill: Color(0xFFF1F5F9),
        border: Color(0xFFE2E8F0),
      );
  }
}

// ─── States ─────────────────────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 38.0,
        height: 38.0,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(SwimUiTokens.accentBlue),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 36.0, color: Color(0xFFB91C1C)),
            const SizedBox(height: 10.0),
            Text(
              "Couldn't load schedule",
              style: GoogleFonts.sora(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: SwimUiTokens.textBannerTitle,
              ),
            ),
            const SizedBox(height: 6.0),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.sora(
                fontSize: 12.0,
                fontWeight: FontWeight.w500,
                color: SwimUiTokens.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32.0, 24.0, 32.0, 32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/vineyard.png',
              fit: BoxFit.contain,
              height: 140.0,
            ),
            const SizedBox(height: 18.0),
            Text(
              'Nothing on the schedule',
              textAlign: TextAlign.center,
              style: GoogleFonts.sora(
                fontSize: 16.0,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: SwimUiTokens.textBannerTitle,
              ),
            ),
            const SizedBox(height: 6.0),
            Text(
              'Forward a coach email to the Postmark inbox; events will show up here once the parser ingests them.',
              textAlign: TextAlign.center,
              style: GoogleFonts.sora(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                height: 1.4,
                color: SwimUiTokens.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyFilterState extends StatelessWidget {
  const _EmptyFilterState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Text(
          'No events match this filter.',
          textAlign: TextAlign.center,
          style: GoogleFonts.sora(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: SwimUiTokens.textMuted,
          ),
        ),
      ),
    );
  }
}
