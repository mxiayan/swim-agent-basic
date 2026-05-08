import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '/backend/schema/team_events_record.dart';
import '/theme/obsidian_volt_tokens.dart';
import '/theme/swim_design_tokens.dart';
import '/widgets/swim_ui_kit.dart';
import 'current_time_indicator.dart';
import 'schedule_display_item.dart';
import 'team_events_schedule.dart' show normalizeCoachLocationForUi;

/// Left column: start (+ end when known). Middle: dot + spine. Right: card.
const double _kTimelineTimeCol = 56;
const double _kTimelineDotCol = 28;
const double _kTimelineLeading = _kTimelineTimeCol + _kTimelineDotCol;

/// Vertical spine x-offset inside [_TimelineCard] (through event dots).
const double _kTimelineSpineLeft = _kTimelineTimeCol + 10;

/// Short venue-style label for list rows (detail sheet keeps full address).
String shortLocationForTimeline(String raw) {
  final n = normalizeCoachLocationForUi(raw).trim();
  if (n.isEmpty) return '';
  final byComma =
      n.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  if (byComma.length >= 2 && n.length > 34) {
    return byComma.first;
  }
  final lines =
      n.split(RegExp(r'\r?\n')).where((s) => s.trim().isNotEmpty).toList();
  if (lines.length >= 2 && n.length > 34) {
    return lines.first.trim();
  }
  if (n.length > 44) return '${n.substring(0, 41)}…';
  return n;
}

DateTime? _dateFromYyyyMmDd(String s) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(s.trim());
  if (m == null) return null;
  return DateTime(
    int.parse(m.group(1)!),
    int.parse(m.group(2)!),
    int.parse(m.group(3)!),
  );
}

bool _isMidnightWall(DateTime d) =>
    d.hour == 0 && d.minute == 0 && d.second == 0 && d.millisecond == 0;

/// Firestore [parsedStart] can be midnight when [startTimeLocal] failed strict parse;
/// recover using [parseHourMinuteLocal] so labels and grouping match the real session time.
DateTime? _effectiveEventStart(TeamEventsRecord e) {
  final p = e.parsedStart;
  final day = _dateFromYyyyMmDd(e.startDate);
  final hm = TeamEventsRecord.parseHourMinuteLocal(e.startTimeLocal);

  if (p != null) {
    if (_isMidnightWall(p) &&
        hm != null &&
        e.startTimeLocal.trim().isNotEmpty) {
      final d0 = day ?? DateTime(p.year, p.month, p.day);
      return DateTime(d0.year, d0.month, d0.day, hm.hour, hm.minute);
    }
    return p;
  }
  if (day != null && hm != null) {
    return DateTime(day.year, day.month, day.day, hm.hour, hm.minute);
  }
  return null;
}

DateTime? _effectiveEventEnd(TeamEventsRecord e) {
  final p = e.parsedEnd;
  final day = _dateFromYyyyMmDd(e.startDate);
  final hm = TeamEventsRecord.parseHourMinuteLocal(e.endTimeLocal);

  if (p != null) {
    if (_isMidnightWall(p) && hm != null && e.endTimeLocal.trim().isNotEmpty) {
      final d0 = day ?? DateTime(p.year, p.month, p.day);
      return DateTime(d0.year, d0.month, d0.day, hm.hour, hm.minute);
    }
    return p;
  }
  if (day != null && hm != null) {
    return DateTime(day.year, day.month, day.day, hm.hour, hm.minute);
  }
  return null;
}

/// Start clock for UI: omits bogus midnight when no usable local time was parsed
/// (Firestore often stores date-only → midnight placeholder).
DateTime? _reliableEventStartForDisplay(TeamEventsRecord e) {
  final raw = _effectiveEventStart(e);
  if (raw == null) return null;
  if (!_isMidnightWall(raw)) return raw;
  final hm = TeamEventsRecord.parseHourMinuteLocal(e.startTimeLocal);
  if (hm != null && e.startTimeLocal.trim().isNotEmpty) {
    final day = _dateFromYyyyMmDd(e.startDate) ??
        DateTime(raw.year, raw.month, raw.day);
    return DateTime(day.year, day.month, day.day, hm.hour, hm.minute);
  }
  return null;
}

/// End clock for UI; same midnight filtering as start.
DateTime? _reliableEventEndForDisplay(TeamEventsRecord e) {
  final raw = _effectiveEventEnd(e);
  if (raw == null) return null;
  if (!_isMidnightWall(raw)) return raw;
  final hm = TeamEventsRecord.parseHourMinuteLocal(e.endTimeLocal);
  if (hm != null && e.endTimeLocal.trim().isNotEmpty) {
    final day = _dateFromYyyyMmDd(e.startDate) ??
        DateTime(raw.year, raw.month, raw.day);
    return DateTime(day.year, day.month, day.day, hm.hour, hm.minute);
  }
  return null;
}

String _fmtClock(DateTime d) => DateFormat('h:mm a').format(d);

bool _sameWallClock(DateTime a, DateTime b) =>
    a.year == b.year &&
    a.month == b.month &&
    a.day == b.day &&
    a.hour == b.hour &&
    a.minute == b.minute;

/// Anchor date for turning parsed clock tokens into [DateTime]s.
DateTime? _eventCalendarDay(TeamEventsRecord e) {
  final p = e.parsedStart;
  if (p != null) return DateTime(p.year, p.month, p.day);
  return _dateFromYyyyMmDd(e.startDate);
}

({int hour, int minute})? _parseClockSegment(String segment) {
  final s = segment.trim();
  if (s.isEmpty) return null;
  final direct = TeamEventsRecord.parseHourMinuteLocal(s);
  if (direct != null) return direct;
  final m = RegExp(
    r'(\d{1,2}:\d{2}(?::\d{2})?(?:\s*[AaPp][Mm])?|\d{1,2}:\d{2}\s*[AaPp][Mm])',
    caseSensitive: false,
  ).firstMatch(s);
  if (m == null) return null;
  return TeamEventsRecord.parseHourMinuteLocal(m.group(1)!.trim());
}

/// Parses [ScheduleDisplayItem.timeDisplayLabel] (often from squad baselines when
/// Firestore `start_time_local` / `end_time_local` are blank — e.g. `6:45 PM – 8:00 PM`).
({DateTime? start, DateTime? end}) _clocksFromTimeDisplayLabel(
  ScheduleDisplayItem item,
) {
  var raw = item.timeDisplayLabel.trim();
  if (raw.isEmpty) return (start: null, end: null);

  raw = raw.replaceAll(RegExp(r'\s+'), ' ');
  raw = raw.replaceAll(RegExp(r'\([^)]*\)'), '').trim();
  if (raw.isEmpty) return (start: null, end: null);

  final day = _eventCalendarDay(item.record);
  if (day == null) return (start: null, end: null);

  List<String> parts = raw.split(RegExp(r'\s*[–\-]\s*'));
  if (parts.length < 2) {
    parts = raw.split(RegExp(r'\s+to\s+', caseSensitive: false));
  }
  if (parts.length >= 2) {
    final a = _parseClockSegment(parts[0]);
    final b = _parseClockSegment(parts[1]);
    if (a != null && b != null) {
      return (
        start: DateTime(day.year, day.month, day.day, a.hour, a.minute),
        end: DateTime(day.year, day.month, day.day, b.hour, b.minute),
      );
    }
  }

  final one = _parseClockSegment(raw);
  if (one != null) {
    return (
      start: DateTime(day.year, day.month, day.day, one.hour, one.minute),
      end: null,
    );
  }

  return (start: null, end: null);
}

/// Structured Firestore times when valid; otherwise coach-ingest / baseline label.
({DateTime? start, DateTime? end}) _timelineClocksForItem(
  ScheduleDisplayItem item,
) {
  final rs = _reliableEventStartForDisplay(item.record);
  final re = _reliableEventEndForDisplay(item.record);
  final fb = _clocksFromTimeDisplayLabel(item);

  final start = rs ?? fb.start;
  final end = re ?? fb.end;

  return (start: start, end: end);
}

/// Session window for “happening now” + progress — matches gutter times
/// ([_timelineClocksForItem]), not raw [TeamEventsRecord.parsedStart] which is
/// often **midnight** when `start_time_local` is empty (would wrongly span
/// midnight→8pm if only `end_time_local` is set).
({DateTime? start, DateTime? end}) _sessionWindowForProgress(
  ScheduleDisplayItem item,
) {
  return _timelineClocksForItem(item);
}

/// Scroll-driven schedule timeline for the **Today** tab: collapsing date header,
/// spine progress, Now marker, Up Next emphasis, past summary chip, and
/// floating context shortcuts.
class DynamicScheduleTimeline extends StatefulWidget {
  const DynamicScheduleTimeline({
    super.key,
    required this.items,
    required this.bottomPad,
    required this.onOpenDetail,
    this.currentDateTime,
    this.selectedDate,
    this.onJumpToNow,
    this.onJumpToNextMeet,
    this.onJumpToNextDeadline,
  });

  final List<ScheduleDisplayItem> items;
  final double bottomPad;
  final void Function(ScheduleDisplayItem item) onOpenDetail;
  final DateTime? currentDateTime;
  final DateTime? selectedDate;
  final VoidCallback? onJumpToNow;
  final VoidCallback? onJumpToNextMeet;
  final VoidCallback? onJumpToNextDeadline;

  @override
  State<DynamicScheduleTimeline> createState() =>
      _DynamicScheduleTimelineState();
}

class _DynamicScheduleTimelineState extends State<DynamicScheduleTimeline> {
  static const double _headerMax = 96;
  static const double _headerMin = 52;
  static const double _floatNowThreshold = 140;
  static const double _pastCollapseScroll = 100;
  static const Duration _anim = Duration(milliseconds: 320);

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _nowMarkerKey = GlobalKey();
  final Map<String, GlobalKey> _eventKeys = {};

  double _scrollOffset = 0;
  DateTime? _visibleSectionDay;
  bool _pastExpanded = false;
  Timer? _clockTicker;
  /// Null until first layout; then whether the now line intersects the viewport.
  bool? _nowLineVisibleInViewport;

  DateTime get _now => widget.currentDateTime ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _clockTicker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateNowLineVisibility();
    });
  }

  @override
  void dispose() {
    _clockTicker?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final px = _scrollController.offset;
    if ((px - _scrollOffset).abs() > 2) {
      setState(() => _scrollOffset = px);
    }
    _scheduleVisibleDayUpdate();
    _scheduleNowLineVisibility();
  }

  void _scheduleVisibleDayUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateVisibleDayFromScroll();
    });
  }

  void _scheduleNowLineVisibility() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateNowLineVisibility();
    });
  }

  void _updateNowLineVisibility() {
    final ctx = _nowMarkerKey.currentContext;
    if (ctx == null) {
      return;
    }
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;
    final dy = box.localToGlobal(Offset.zero).dy;
    final h = box.size.height;
    final mq = MediaQuery.of(context);
    final top = mq.padding.top + _headerMin + 2;
    final bottom = mq.size.height - mq.padding.bottom - 88;
    final visible = dy < bottom && dy + h > top;
    if (_nowLineVisibleInViewport != visible) {
      setState(() => _nowLineVisibleInViewport = visible);
    }
  }

  void _updateVisibleDayFromScroll() {
    if (!_scrollController.hasClients) return;
    final sorted = _sortedItems();
    final anchor = widget.selectedDate ?? headerAnchorDay(sorted, _today());
    final day = visibleDateFromScrollHeuristic(
      scrollOffset: _scrollOffset,
      sorted: sorted,
      fallback: anchor,
    );
    if (_visibleSectionDay != day) {
      setState(() => _visibleSectionDay = day);
    }
  }

  GlobalKey _keyFor(ScheduleDisplayItem item) {
    final id =
        '${item.record.docId}|${item.record.startDate}|${item.record.title}';
    return _eventKeys.putIfAbsent(id, GlobalKey.new);
  }

  List<ScheduleDisplayItem> _sortedItems() {
    final now = _now;
    final today = _today();
    if (widget.items.isEmpty) return [];
    final sorted = List<ScheduleDisplayItem>.from(widget.items)
      ..sort((a, b) => compareTimelineItems(a, b, now: now, today: today));
    return sorted;
  }

  DateTime _today() {
    final n = _now;
    return DateTime(n.year, n.month, n.day);
  }

  bool _shouldCollapsePast({
    required bool hasPastToday,
    required DateTime today,
  }) {
    if (!hasPastToday) return false;
    return _scrollOffset >= _pastCollapseScroll;
  }

  bool get _showFloatNow {
    if (_todayOnlyContext() == false) return false;
    if (_sortedItems().isEmpty) return false;
    if (_nowMarkerKey.currentContext == null) return false;
    if (_nowLineVisibleInViewport == false) return true;
    if (_nowLineVisibleInViewport == null) {
      return _scrollOffset >= _floatNowThreshold;
    }
    return false;
  }

  /// Inline “Now” row stays fully visible (scroll-linked fade caused readability issues).
  double get _inlineNowOpacity => _todayOnlyContext() ? 1.0 : 0.0;

  /// Timeline list is for "today onward"; treat as today context when first day is today.
  bool _todayOnlyContext() {
    final sorted = _sortedItems();
    if (sorted.isEmpty) return true;
    final p = sorted.first.record.parsedStart;
    if (p == null) return true;
    final d = DateTime(p.year, p.month, p.day);
    return !d.isAfter(_today());
  }

  void _jumpToNow() {
    widget.onJumpToNow?.call();
    final ctx = _nowMarkerKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        alignment: 0.12,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _updateNowLineVisibility();
      });
    } else {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: _anim,
          curve: Curves.easeOut,
        );
      }
    }
  }

  void _jumpToNextMeetInList() {
    widget.onJumpToNextMeet?.call();
    final sorted = _sortedItems();
    final meet = getNextMeetAfterVisiblePosition(
      events: sorted,
      visibleDate: _visibleSectionDay ?? headerAnchorDay(sorted, _today()),
      now: _now,
    );
    if (meet == null) return;
    final ctx = _keyFor(meet).currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: _anim,
        curve: Curves.easeOut,
        alignment: 0.2,
      );
    }
  }

  void _showNowLineTapFeedback(BuildContext context) {
    if (!context.mounted) return;
    final t = _now;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Current time · ${CurrentTimeIndicator.formatClockLabel(t)}',
          style: GoogleFonts.sora(fontWeight: FontWeight.w600),
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _jumpToNextDeadlineOrToday() {
    if (widget.onJumpToNextDeadline != null) {
      widget.onJumpToNextDeadline!();
      return;
    }
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: _anim,
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pageBg = ObsidianVoltTokens.bgBase;
    final muted = ObsidianVoltTokens.textSecondary;
    final titleColor = ObsidianVoltTokens.textPrimary;
    final now = _now;
    final today = _today();
    final sorted = _sortedItems();

    if (sorted.isEmpty) {
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
                  widget.bottomPad,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _EmptyTimelineHeader(
                      headerDay: widget.selectedDate ?? today,
                      titleColor: titleColor,
                      muted: muted,
                    ),
                    SizedBox(height: SwimDsTokens.cardSpacing),
                    EmptyStateCard(
                      title: 'No events today',
                      message:
                          'You are all caught up. Upcoming practices and meets will appear here.',
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

    final cancelled = sorted.where((i) => _isCancelled(i.record)).length;
    final headerDay = widget.selectedDate ?? headerAnchorDay(sorted, today);
    final nextItem = getNextUpcomingEvent(sorted, now, today);
    final pastTodayCount = sorted
        .where(
          (i) =>
              _isSameDay(i.record.parsedStart, today) &&
              _isFullyPast(i, now, today) &&
              !_isCancelled(i.record),
        )
        .length;
    final collapsePast = _shouldCollapsePast(
      hasPastToday: pastTodayCount > 0,
      today: today,
    );

    final visibleDay = _visibleSectionDay ?? headerDay;
    final daysAhead = visibleDay.difference(today).inDays;
    final showAheadPill = daysAhead > 0;
    final nextMeet = getNextMeetAfterVisiblePosition(
      events: sorted,
      visibleDate: visibleDay,
      now: now,
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _CollapsingDateHeaderDelegate(
                maxExtent: _headerMax,
                minExtent: _headerMin,
                headerDay: headerDay,
                totalEvents: sorted.length,
                cancelledCount: cancelled,
              ),
            ),
            SliverToBoxAdapter(
              child: ColoredBox(
                color: pageBg,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    SwimDsTokens.pageHorizontalPadding,
                    0,
                    SwimDsTokens.pageHorizontalPadding,
                    0,
                  ),
                  child: _buildTimelineColumn(
                    context: context,
                    sorted: sorted,
                    today: today,
                    now: now,
                    nextItem: nextItem,
                    collapsePast: collapsePast,
                    pastExpanded: _pastExpanded,
                    pastTodayCount: pastTodayCount,
                    pageBg: pageBg,
                    muted: muted,
                    titleColor: titleColor,
                    onOpenDetail: widget.onOpenDetail,
                    onTogglePast: () => setState(() {
                      _pastExpanded = !_pastExpanded;
                    }),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(height: widget.bottomPad),
            ),
          ],
        ),
        Positioned(
          top: _headerMin + 6,
          right: SwimDsTokens.pageHorizontalPadding,
          child: AnimatedSlide(
            duration: _anim,
            curve: Curves.easeOut,
            offset: _showFloatNow ? Offset.zero : const Offset(0.06, 0),
            child: AnimatedOpacity(
              duration: _anim,
              opacity: _showFloatNow ? 1 : 0,
              child: IgnorePointer(
                ignoring: !_showFloatNow,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _jumpToNow,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: SwimDsTokens.primaryPurple,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: SwimDsTokens.cardShadowSoft,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.arrow_upward_rounded,
                            size: 16,
                            color: Colors.white.withValues(alpha: 0.95),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Now',
                            style: GoogleFonts.sora(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: _headerMin + 8,
          left: SwimDsTokens.pageHorizontalPadding,
          child: AnimatedSwitcher(
            duration: _anim,
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeOut,
            child: showAheadPill
                ? _DaysAheadPill(daysAhead: daysAhead)
                : const SizedBox.shrink(),
          ),
        ),
        Positioned(
          left: SwimDsTokens.pageHorizontalPadding,
          right: SwimDsTokens.pageHorizontalPadding,
          bottom: 12 + MediaQuery.paddingOf(context).bottom,
          child: AnimatedSwitcher(
            duration: _anim,
            child: _shortcutChild(
              daysAhead: daysAhead,
              nextMeet: nextMeet,
            ),
          ),
        ),
      ],
    );
  }

  Widget _shortcutChild({
    required int daysAhead,
    required ScheduleDisplayItem? nextMeet,
  }) {
    if (daysAhead >= 1 && nextMeet != null) {
      return _SmartShortcutButton(
        label: 'Jump to next meet',
        icon: Icons.arrow_downward_rounded,
        onTap: _jumpToNextMeetInList,
      );
    }
    if (daysAhead >= 2) {
      return _SmartShortcutButton(
        label: 'Back to today',
        icon: Icons.today_rounded,
        onTap: _jumpToNextDeadlineOrToday,
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildTimelineColumn({
    required BuildContext context,
    required List<ScheduleDisplayItem> sorted,
    required DateTime today,
    required DateTime now,
    required ScheduleDisplayItem? nextItem,
    required bool collapsePast,
    required bool pastExpanded,
    required int pastTodayCount,
    required Color pageBg,
    required Color muted,
    required Color titleColor,
    required void Function(ScheduleDisplayItem item) onOpenDetail,
    required VoidCallback onTogglePast,
  }) {
    final sections = _buildTimelineSections(
      context: context,
      sorted: sorted,
      today: today,
      now: now,
      nextItem: nextItem,
      collapsePast: collapsePast,
      pastExpanded: pastExpanded,
      pastTodayCount: pastTodayCount,
      pageBg: pageBg,
      muted: muted,
      titleColor: titleColor,
      onOpenDetail: onOpenDetail,
      onTogglePast: onTogglePast,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (sections.today.isNotEmpty)
          _TimelineCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: sections.today,
            ),
          ),
        if (sections.futureDays.isNotEmpty) ...[
          SizedBox(height: SwimDsTokens.sectionSpacing + 6),
          for (var fi = 0; fi < sections.futureDays.length; fi++) ...[
            if (fi > 0) SizedBox(height: SwimDsTokens.cardSpacing),
            _TimelineCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: sections.futureDays[fi],
              ),
            ),
          ],
        ],
      ],
    );
  }

  ({List<Widget> today, List<List<Widget>> futureDays}) _buildTimelineSections({
    required BuildContext context,
    required List<ScheduleDisplayItem> sorted,
    required DateTime today,
    required DateTime now,
    required ScheduleDisplayItem? nextItem,
    required bool collapsePast,
    required bool pastExpanded,
    required int pastTodayCount,
    required Color pageBg,
    required Color muted,
    required Color titleColor,
    required void Function(ScheduleDisplayItem item) onOpenDetail,
    required VoidCallback onTogglePast,
  }) {
    final todayRows = <Widget>[];
    final futureDayCards = <List<Widget>>[];
    final byDay = groupEventsByDateAndTimeOfDay(sorted, today);
    final selectedOk = widget.selectedDate == null ||
        DateUtils.isSameDay(widget.selectedDate!, now);

    for (var di = 0; di < byDay.length; di++) {
      final g = byDay[di];
      final day = g.day;
      final items = g.items;

      if (day != today) {
        final dayRows = <Widget>[];
        final gapTop = futureDayCards.isEmpty ? 4.0 : 12.0;
        dayRows.add(
          _DayDivider(
            label: _futureDaySectionLabel(day, today),
            gapTop: gapTop,
            futureDateHeader: true,
          ),
        );
        for (final item in items) {
          dayRows.add(
            _EventRowWidget(
              key: _keyFor(item),
              item: item,
              now: now,
              isHappeningNow: false,
              isNext: identical(item, nextItem),
              mutedPast: _isFullyPast(item, now, today),
              pageBg: pageBg,
              muted: muted,
              titleColor: titleColor,
              onTap: () => onOpenDetail(item),
              upNextSubtitle: identical(item, nextItem)
                  ? formatUpNextTime(item.record.parsedStart, now)
                  : null,
              happeningProgress: null,
            ),
          );
        }
        futureDayCards.add(dayRows);
        continue;
      }

      // Today
      final visibleToday = items
          .where(
            (item) => !collapsePast ||
                pastExpanded ||
                !_isFullyPast(item, now, today),
          )
          .toList();
      final showTodayNowLine =
          selectedOk && DateUtils.isSameDay(day, now);

      final happeningOverlay = showTodayNowLine
          ? computeHappeningNowOverlay(visibleToday, now)
          : null;
      final lineAt = showTodayNowLine
          ? (happeningOverlay != null
              ? -1
              : computeNowLineInsertIndex(visibleToday, now))
          : -1;

      if (pastTodayCount > 0 && (collapsePast || pastExpanded)) {
        todayRows.add(
          _PastSummaryChip(
            count: pastTodayCount,
            expanded: pastExpanded,
            onTap: onTogglePast,
          ),
        );
      }

      String? lastTod;
      var visibleIdx = 0;
      var isFirstVisibleTodayItem = true;
      for (final item in items) {
        if (collapsePast &&
            !pastExpanded &&
            _isFullyPast(item, now, today)) {
          continue;
        }

        final eff = _effectiveEventStart(item.record);
        final todRaw =
            eff == null ? 'TODAY' : _timeOfDayGroupFromDateTime(eff);
        if (todRaw != lastTod) {
          final skipRedundantMorning =
              isFirstVisibleTodayItem && todRaw == 'MORNING';
          if (!skipRedundantMorning) {
            todayRows.add(
              _DayDivider(
                label: todRaw,
                emphasize: _isActiveTod(todRaw, now),
              ),
            );
          }
          lastTod = todRaw;
        }
        isFirstVisibleTodayItem = false;

        if (lineAt >= 0 && visibleIdx == lineAt) {
          todayRows.add(
            AnimatedOpacity(
              duration: _anim,
              opacity: _inlineNowOpacity,
              child: CurrentTimeIndicator(
                key: _nowMarkerKey,
                currentDateTime: now,
                timelineDate: today,
                leftLabelWidth: _kTimelineTimeCol,
                timelineDotColumnWidth: _kTimelineDotCol,
                isVisible: true,
                onTap: () => _showNowLineTapFeedback(context),
              ),
            ),
          );
        }

        final happening = !_isCancelled(item.record) &&
            _isHappeningNowForTimelineItem(item, now);
        final isAboveNowLine = happeningOverlay != null
            ? visibleIdx < happeningOverlay.visibleIndex
            : (lineAt >= 0 && visibleIdx < lineAt);

        final isHappeningRow = happeningOverlay != null &&
            happeningOverlay.visibleIndex == visibleIdx;

        todayRows.add(
          _EventRowWidget(
            key: isHappeningRow ? _nowMarkerKey : _keyFor(item),
            item: item,
            now: now,
            isHappeningNow: happening,
            isNext: identical(item, nextItem),
            mutedPast: isAboveNowLine,
            pageBg: pageBg,
            muted: muted,
            titleColor: titleColor,
            onTap: () => onOpenDetail(item),
            upNextSubtitle: identical(item, nextItem)
                ? formatUpNextTime(item.record.parsedStart, now)
                : null,
            happeningProgress:
                happening ? happeningNowYFraction(item, now) : null,
          ),
        );
        visibleIdx++;
      }

      if (lineAt >= 0 && visibleIdx == lineAt) {
        todayRows.add(
          AnimatedOpacity(
            duration: _anim,
            opacity: _inlineNowOpacity,
            child: CurrentTimeIndicator(
              key: _nowMarkerKey,
              currentDateTime: now,
              timelineDate: today,
              leftLabelWidth: _kTimelineTimeCol,
              timelineDotColumnWidth: _kTimelineDotCol,
              isVisible: true,
              onTap: () => _showNowLineTapFeedback(context),
            ),
          ),
        );
      }
    }

    return (today: todayRows, futureDays: futureDayCards);
  }

  bool _isActiveTod(String tod, DateTime now) {
    final h = now.hour;
    if (tod == 'MORNING') return h < 12;
    if (tod == 'AFTERNOON') return h >= 12 && h < 17;
    if (tod == 'EVENING') return h >= 17;
    return false;
  }
}

// ─── Public helpers (for tests / reuse) ─────────────────────────────────────

int compareTimelineItems(
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
  final ra = _todaySubsectionRank(a, now, today);
  final rb = _todaySubsectionRank(b, now, today);
  if (ra != rb) return ra.compareTo(rb);
  return pa.compareTo(pb);
}

int _todaySubsectionRank(ScheduleDisplayItem item, DateTime now, DateTime today) {
  final clocks = _sessionWindowForProgress(item);
  final ps = clocks.start ?? item.record.parsedStart;
  if (ps == null) return 2;
  if (_isHappeningNowForTimelineItem(item, now)) return 0;
  if (ps.hour < 12) return 1;
  if (ps.hour < 17) return 2;
  return 3;
}

DateTime headerAnchorDay(List<ScheduleDisplayItem> sorted, DateTime today) {
  DateTime? first;
  for (final i in sorted) {
    final p = i.record.parsedStart;
    if (p == null) continue;
    final d = DateTime(p.year, p.month, p.day);
    if (first == null || d.isBefore(first)) first = d;
  }
  return first ?? today;
}

ScheduleDisplayItem? getNextUpcomingEvent(
  List<ScheduleDisplayItem> events,
  DateTime now,
  DateTime today,
) {
  for (final i in events) {
    if (_isCancelled(i.record)) continue;
    if (_isHappeningNowForTimelineItem(i, now)) {
      continue;
    }
    final s = i.record.parsedStart;
    if (s == null) continue;
    final d = DateTime(s.year, s.month, s.day);
    if (d.isBefore(today)) continue;
    if (s.isAfter(now)) return i;
  }
  for (final i in events) {
    if (_isCancelled(i.record)) continue;
    if (_isHappeningNowForTimelineItem(i, now)) {
      final idx = events.indexOf(i);
      for (var j = idx + 1; j < events.length; j++) {
        final n = events[j];
        if (!_isCancelled(n.record)) return n;
      }
      return null;
    }
  }
  return null;
}

List<ScheduleDisplayItem> getPastEventsForToday(
  List<ScheduleDisplayItem> events,
  DateTime now,
  DateTime today,
) {
  return events
      .where(
        (i) =>
            _isSameDay(i.record.parsedStart, today) &&
            _isFullyPast(i, now, today) &&
            !_isCancelled(i.record),
      )
      .toList();
}

DateTime visibleDateFromScrollHeuristic({
  required double scrollOffset,
  required List<ScheduleDisplayItem> sorted,
  required DateTime fallback,
}) {
  if (sorted.isEmpty) return fallback;
  const headerAllowance = 140.0;
  const rowHeight = 108.0;
  final idx =
      (((scrollOffset - headerAllowance) / rowHeight).floor()).clamp(
        0,
        sorted.length - 1,
      );
  final p = sorted[idx].record.parsedStart;
  if (p == null) return fallback;
  return DateTime(p.year, p.month, p.day);
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

ScheduleDisplayItem? getNextMeetAfterVisiblePosition({
  required List<ScheduleDisplayItem> events,
  required DateTime visibleDate,
  required DateTime now,
}) {
  for (final i in events) {
    if (i.record.eventType != TeamEventType.meet) continue;
    if (_isCancelled(i.record)) continue;
    final s = i.record.parsedStart;
    if (s == null) continue;
    final d = DateTime(s.year, s.month, s.day);
    if (d.isBefore(visibleDate)) continue;
    if (d.isAtSameMomentAs(visibleDate) && !s.isAfter(now)) {
      continue;
    }
    return i;
  }
  return null;
}

String? formatUpNextTime(DateTime? start, DateTime now) {
  if (start == null) return null;
  if (!start.isAfter(now)) return null;
  final diff = start.difference(now);
  if (diff.inHours >= 1) {
    return 'IN ${diff.inHours} HOUR${diff.inHours == 1 ? '' : 'S'}';
  }
  if (diff.inMinutes >= 1) {
    return 'IN ${diff.inMinutes} MIN';
  }
  return 'SOON';
}

/// Live session row: provides list index + progress (0–1) for in-card emphasis only.
/// The Now row is never drawn over the card.
class HappeningNowOverlayPlan {
  const HappeningNowOverlayPlan({
    required this.visibleIndex,
    required this.yFraction,
  });

  final int visibleIndex;
  /// 0 = top of row, 1 = bottom; derived from (now - start) / (end - start).
  final double yFraction;
}

HappeningNowOverlayPlan? computeHappeningNowOverlay(
  List<ScheduleDisplayItem> visibleTodayItems,
  DateTime now,
) {
  for (var i = 0; i < visibleTodayItems.length; i++) {
    final item = visibleTodayItems[i];
    final r = item.record;
    if (_isCancelled(r)) continue;
    if (!_isHappeningNowForTimelineItem(item, now)) continue;
    return HappeningNowOverlayPlan(
      visibleIndex: i,
      yFraction: happeningNowYFraction(item, now),
    );
  }
  return null;
}

double happeningNowYFraction(ScheduleDisplayItem item, DateTime now) {
  final w = _sessionWindowForProgress(item);
  final s = w.start;
  final e = w.end;
  if (s == null || e == null) return 0.5;
  final totalMs = e.difference(s).inMilliseconds;
  if (totalMs <= 0) return 0.5;
  final elapsedMs = now.difference(s).inMilliseconds;
  return (elapsedMs / totalMs).clamp(0.0, 1.0);
}

/// Insert the current-time row before index `k` in today's **visible** list;
/// `k == length` means after the last visible item.
/// Does not insert **before** an in-progress event — use [computeHappeningNowOverlay] for that.
int computeNowLineInsertIndex(
  List<ScheduleDisplayItem> visibleTodayItems,
  DateTime now,
) {
  if (visibleTodayItems.isEmpty) return 0;
  for (var i = 0; i < visibleTodayItems.length; i++) {
    final item = visibleTodayItems[i];
    final r = item.record;
    if (_isCancelled(r)) continue;
    if (_isHappeningNowForTimelineItem(item, now)) continue;
    final s =
        _sessionWindowForProgress(item).start ?? r.parsedStart;
    if (s == null) continue;
    if (now.isBefore(s)) return i;
  }
  return visibleTodayItems.length;
}

/// One calendar day bucket for timeline grouping helpers.
class TimelineDayGroup {
  const TimelineDayGroup({required this.day, required this.items});
  final DateTime day;
  final List<ScheduleDisplayItem> items;
}

List<TimelineDayGroup> groupEventsByDateAndTimeOfDay(
  List<ScheduleDisplayItem> sorted,
  DateTime today,
) {
  final map = <DateTime, List<ScheduleDisplayItem>>{};
  for (final i in sorted) {
    final p = i.record.parsedStart;
    final d = p == null ? today : DateTime(p.year, p.month, p.day);
    map.putIfAbsent(d, () => []).add(i);
  }
  final keys = map.keys.toList()..sort((a, b) => a.compareTo(b));
  return keys
      .map((k) => TimelineDayGroup(day: k, items: map[k]!))
      .toList();
}

// ─── Private widgets / delegates ───────────────────────────────────────────

class _CollapsingDateHeaderDelegate extends SliverPersistentHeaderDelegate {
  _CollapsingDateHeaderDelegate({
    required this.maxExtent,
    required this.minExtent,
    required this.headerDay,
    required this.totalEvents,
    required this.cancelledCount,
  });

  @override
  final double maxExtent;

  @override
  final double minExtent;

  final DateTime headerDay;
  final int totalEvents;
  final int cancelledCount;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final titleColor = ObsidianVoltTokens.textPrimary;
    final muted = ObsidianVoltTokens.textSecondary;
    final bg = ObsidianVoltTokens.bgBase;
    final range = maxExtent - minExtent;
    final t = range <= 0 ? 1.0 : (shrinkOffset / range).clamp(0.0, 1.0);
    final bigOpacity = 1.0 - t;
    final sub = cancelledCount > 0
        ? '$totalEvents events · $cancelledCount cancelled'
        : '$totalEvents events';
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

    return Material(
      color: bg,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          SwimDsTokens.pageHorizontalPadding,
          4,
          SwimDsTokens.pageHorizontalPadding,
          4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            AnimatedOpacity(
              duration: const Duration(milliseconds: 260),
              opacity: bigOpacity.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, -6 * t),
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.sora(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
              ),
            ),
            Text(
              sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.sora(
                fontSize: t > 0.65 ? 11.5 : 12,
                fontWeight: FontWeight.w500,
                color: muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _CollapsingDateHeaderDelegate oldDelegate) {
    return oldDelegate.headerDay != headerDay ||
        oldDelegate.totalEvents != totalEvents ||
        oldDelegate.cancelledCount != cancelledCount ||
        oldDelegate.maxExtent != maxExtent ||
        oldDelegate.minExtent != minExtent;
  }
}

class _EmptyTimelineHeader extends StatelessWidget {
  const _EmptyTimelineHeader({
    required this.headerDay,
    required this.titleColor,
    required this.muted,
  });

  final DateTime headerDay;
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
    return Column(
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
          '0 events',
          style: GoogleFonts.sora(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: muted,
          ),
        ),
      ],
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final track = SwimDsTokens.primaryPurple.withValues(alpha: 0.12);
    return Container(
      decoration: BoxDecoration(
        color: SwimDsTokens.cardBackground,
        borderRadius: BorderRadius.circular(SwimDsTokens.cardRadius),
        border: Border.all(color: SwimDsTokens.borderSoft, width: 1),
        boxShadow: SwimDsTokens.cardShadowSoft,
      ),
      padding: const EdgeInsets.fromLTRB(0, 10, 10, 12),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: _kTimelineSpineLeft,
            top: 18,
            bottom: 18,
            width: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: track,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [child],
          ),
        ],
      ),
    );
  }
}

class _DayDivider extends StatelessWidget {
  const _DayDivider({
    required this.label,
    this.emphasize = false,
    this.futureDateHeader = false,
    this.gapTop = 12,
  });

  final String label;
  final bool emphasize;
  /// Future calendar-day titles (e.g. TOMORROW · FRI MAY 8): stronger than MORNING/AFTERNOON.
  final bool futureDateHeader;
  final double gapTop;

  @override
  Widget build(BuildContext context) {
    final Color labelColor;
    if (emphasize) {
      labelColor = SwimDsTokens.primaryPurple;
    } else if (futureDateHeader) {
      labelColor = SwimDsTokens.textPrimary.withValues(alpha: 0.88);
    } else {
      labelColor = SwimDsTokens.textSecondary;
    }
    return Padding(
      padding: EdgeInsets.only(
        left: _kTimelineLeading + 8,
        top: gapTop,
        bottom: 6,
      ),
      child: Text(
        label,
        style: GoogleFonts.sora(
          fontSize: futureDateHeader ? 11 : 10,
          letterSpacing: futureDateHeader ? 0.55 : 0.6,
          fontWeight: FontWeight.w700,
          color: labelColor,
        ),
      ),
    );
  }
}

class _PastSummaryChip extends StatelessWidget {
  const _PastSummaryChip({
    required this.count,
    required this.expanded,
    required this.onTap,
  });

  final int count;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: _kTimelineLeading + 4, right: 0, bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: SwimDsTokens.primaryPurple.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: SwimDsTokens.borderSoft,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    expanded
                        ? 'Hide completed ($count)'
                        : 'Today · $count event${count == 1 ? '' : 's'} done',
                    style: GoogleFonts.sora(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: ObsidianVoltTokens.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 20,
                  color: SwimDsTokens.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DaysAheadPill extends StatelessWidget {
  const _DaysAheadPill({required this.daysAhead});

  final int daysAhead;

  String get _label {
    if (daysAhead == 1) return 'Tomorrow';
    if (daysAhead >= 7) return 'Next week';
    return '$daysAhead days ahead';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey(daysAhead),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: SwimDsTokens.warningAmber.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: SwimDsTokens.warningAmber.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.schedule_rounded,
            size: 14,
            color: SwimDsTokens.warningAmber.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 6),
          Text(
            _label,
            style: GoogleFonts.sora(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: ObsidianVoltTokens.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SmartShortcutButton extends StatelessWidget {
  const _SmartShortcutButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SwimDsTokens.cardBackground,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: SwimDsTokens.borderSoft),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: SwimDsTokens.primaryPurple),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.sora(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: SwimDsTokens.primaryPurple,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventRowWidget extends StatelessWidget {
  const _EventRowWidget({
    super.key,
    required this.item,
    required this.now,
    required this.isHappeningNow,
    required this.isNext,
    required this.mutedPast,
    required this.pageBg,
    required this.muted,
    required this.titleColor,
    required this.onTap,
    this.upNextSubtitle,
    this.happeningProgress,
  });

  final ScheduleDisplayItem item;
  final DateTime now;
  final bool isHappeningNow;
  final bool isNext;
  final bool mutedPast;
  final Color pageBg;
  final Color muted;
  final Color titleColor;
  final VoidCallback onTap;
  final String? upNextSubtitle;

  /// 0–1 progress through current session when [isHappeningNow].
  final double? happeningProgress;

  Color _dotFill({
    required bool cancelled,
    required _TimelinePalette style,
    required TeamEventType type,
  }) {
    if (cancelled) return ObsidianVoltTokens.eventCancelledDot;
    if (mutedPast) {
      return SwimDsTokens.textSecondary.withValues(alpha: 0.42);
    }
    switch (type) {
      case TeamEventType.meet:
        return SwimDsTokens.warningAmber;
      case TeamEventType.training:
        return SwimDsTokens.primaryPurple;
      default:
        return style.dot;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cancelled = _isCancelled(item.record);
    final style = cancelled
        ? _TimelinePalette.cancelled()
        : _TimelinePalette.forType(item.record.eventType);

    final promote = !cancelled && (isHappeningNow || isNext);
    final dotRing = !cancelled && (isNext || isHappeningNow);

    final dotColor = _dotFill(
      cancelled: cancelled,
      style: style,
      type: item.record.eventType,
    );

    final dot = Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: dotColor,
        border: dotRing
            ? Border.all(
                color: pageBg,
                width: 2,
              )
            : null,
        boxShadow: dotRing
            ? [
                BoxShadow(
                  color: dotColor.withValues(alpha: 0.35),
                  blurRadius: 0,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
    );

    final clocks = _timelineClocksForItem(item);
    final startDt = clocks.start;
    final endDt = clocks.end;
    final startStr = startDt != null ? _fmtClock(startDt) : null;
    final endStr = endDt != null ? _fmtClock(endDt) : null;

    final bothDifferentClockTimes = startDt != null &&
        endDt != null &&
        !_sameWallClock(startDt, endDt);

    String? rangeLabel;
    if (startStr != null && endStr != null && bothDifferentClockTimes) {
      rangeLabel = '$startStr – $endStr';
    } else if (startStr != null) {
      rangeLabel = startStr;
    } else if (endStr != null) {
      rangeLabel = endStr;
    }

    final typeLabel = teamEventTypeLabel(item.record.eventType);
    final hint = _agentHintForEvent(item);

    final shortLoc =
        shortLocationForTimeline(item.locationDisplay);

    final rl = rangeLabel;
    final metaParts = <String>[
      if (rl != null && rl.isNotEmpty) rl,
      if (shortLoc.isNotEmpty) shortLoc,
    ];
    final metaLine = metaParts.join(' · ');

    final borderColor = isHappeningNow
        ? SwimDsTokens.primaryPurple.withValues(alpha: 0.42)
        : promote
            ? SwimDsTokens.primaryPurple.withValues(alpha: 0.38)
            : (cancelled
                ? ObsidianVoltTokens.borderSubtle
                : SwimDsTokens.borderSoft);
    final cardBg = isHappeningNow
        ? SwimDsTokens.primaryPurple.withValues(alpha: 0.09)
        : promote
            ? SwimDsTokens.primaryPurple.withValues(alpha: 0.05)
            : (cancelled
                ? ObsidianVoltTokens.eventCancelledCardBg
                : SwimDsTokens.cardBackground);

    Widget card = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(SwimDsTokens.cardRadius),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(SwimDsTokens.cardRadius),
            border: Border.all(
              color: borderColor,
              width: isHappeningNow ? 1.5 : (promote ? 1.25 : 1),
            ),
            boxShadow: cancelled ? null : SwimDsTokens.cardShadowSoft,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
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
                  if (!cancelled && item.squadLabel.trim().isNotEmpty)
                    StatusPill(
                      label: item.squadLabel,
                      kind: SwimStatusPillKind.notDecided,
                    ),
                  if (isHappeningNow)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: SwimDsTokens.primaryPurple.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color:
                              SwimDsTokens.primaryPurple.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        'HAPPENING NOW',
                        style: GoogleFonts.sora(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.45,
                          color: SwimDsTokens.primaryPurple,
                        ),
                      ),
                    )
                  else if (isNext && upNextSubtitle != null)
                    Text(
                      'UP NEXT · $upNextSubtitle',
                      style: GoogleFonts.sora(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: SwimDsTokens.primaryPurple,
                      ),
                    )
                  else if (isNext)
                    Text(
                      'UP NEXT',
                      style: GoogleFonts.sora(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: SwimDsTokens.primaryPurple,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                item.record.title.isEmpty ? '(Untitled)' : item.record.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.sora(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                  color: titleColor,
                  decoration: cancelled
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                ),
              ),
              if (metaLine.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  metaLine,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.sora(
                    fontSize: 11.5,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                    color: muted,
                  ),
                ),
              ],
              if (happeningProgress != null &&
                  isHappeningNow &&
                  !cancelled) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: happeningProgress!.clamp(0.0, 1.0),
                    minHeight: 4,
                    backgroundColor:
                        SwimDsTokens.primaryPurple.withValues(alpha: 0.12),
                    color: SwimDsTokens.primaryPurple.withValues(alpha: 0.65),
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
                      size: 13,
                      color: SwimDsTokens.primaryPurple.withValues(alpha: 0.85),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        hint,
                        style: GoogleFonts.sora(
                          fontSize: 11,
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
    } else if (mutedPast && !promote) {
      card = Opacity(opacity: 0.78, child: card);
    }

    final Widget timeCol;
    if (startStr == null && endStr == null) {
      timeCol = SizedBox(width: _kTimelineTimeCol);
    } else {
      timeCol = SizedBox(
        width: _kTimelineTimeCol,
        child: Padding(
          padding: const EdgeInsets.only(top: 10, right: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (startStr != null)
                Text(
                  startStr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.sora(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    color: mutedPast ? muted : titleColor,
                  ),
                ),
              if (startStr != null &&
                  endStr != null &&
                  bothDifferentClockTimes)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    endStr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.sora(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                      color: mutedPast
                          ? muted
                          : SwimDsTokens.textSecondary,
                    ),
                  ),
                )
              else if (startStr == null && endStr != null)
                Text(
                  endStr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.sora(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    color: mutedPast ? muted : titleColor,
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          timeCol,
          SizedBox(
            width: _kTimelineDotCol,
            child: Padding(
              padding: const EdgeInsets.only(left: 4, top: 11),
              child: dot,
            ),
          ),
          Expanded(child: card),
        ],
      ),
    );
  }
}

// ─── Shared logic ───────────────────────────────────────────────────────────

String _futureDaySectionLabel(DateTime day, DateTime today) {
  final diff = day.difference(today).inDays;
  if (diff == 1) {
    return 'TOMORROW · ${DateFormat('EEE MMM d').format(day).toUpperCase()}';
  }
  return DateFormat('EEE, MMM d').format(day).toUpperCase();
}

String _timeOfDayGroupFromDateTime(DateTime ps) {
  if (ps.hour < 12) return 'MORNING';
  if (ps.hour < 17) return 'AFTERNOON';
  return 'EVENING';
}

bool _isSameDay(DateTime? ps, DateTime day) {
  if (ps == null) return false;
  return ps.year == day.year && ps.month == day.month && ps.day == day.day;
}

bool _isFullyPast(
  ScheduleDisplayItem item,
  DateTime now,
  DateTime today,
) {
  if (_isCancelled(item.record)) return false;
  final e = item.record;
  final s = e.parsedStart;
  if (s == null) return false;
  final day = DateTime(s.year, s.month, s.day);
  if (day.isBefore(today)) return true;
  if (day.isAfter(today)) return false;
  if (_isHappeningNowForTimelineItem(item, now)) return false;
  final end = e.parsedEnd;
  if (end != null) {
    return !end.isAfter(now);
  }
  return s.isBefore(now);
}

bool _isCancelled(TeamEventsRecord e) {
  final s = e.status.toLowerCase();
  return s.contains('cancel');
}

bool _isHappeningNowForTimelineItem(ScheduleDisplayItem item, DateTime now) {
  final e = item.record;
  if (_isCancelled(e)) return false;
  final w = _sessionWindowForProgress(item);
  var start = w.start;
  var end = w.end;
  if (start == null) {
    start = e.parsedStart;
  }
  if (end == null) {
    end = e.parsedEnd;
  }
  if (start == null) return false;

  final day = DateTime(now.year, now.month, now.day);
  final sd = DateTime(start.year, start.month, start.day);
  if (sd != day) return false;

  if (end != null) {
    return !now.isBefore(start) && !now.isAfter(end);
  }
  if (e.endTimeLocal.trim().isNotEmpty) {
    return false;
  }
  return !now.isBefore(start);
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
