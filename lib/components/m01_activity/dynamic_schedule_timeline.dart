import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '/backend/schema/team_events_record.dart';
import '/theme/obsidian_volt_tokens.dart';
import '/theme/swim_design_tokens.dart';
import '/widgets/swim_ui_kit.dart';
import 'schedule_display_item.dart';
import 'team_events_schedule.dart' show normalizeCoachLocationForUi;

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

  DateTime get _now => widget.currentDateTime ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
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
  }

  void _scheduleVisibleDayUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateVisibleDayFromScroll();
    });
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

  double get _spineFill {
    if (!_scrollController.hasClients) return 0;
    final max = _scrollController.position.maxScrollExtent;
    if (max <= 0) return 0;
    return (_scrollOffset / max).clamp(0.0, 1.0);
  }

  bool get _showFloatNow {
    if (_todayOnlyContext() == false) return false;
    return _scrollOffset >= _floatNowThreshold;
  }

  double get _inlineNowOpacity {
    if (_todayOnlyContext() == false) return 0;
    return (1.0 - (_scrollOffset / 140).clamp(0.0, 1.0)).clamp(0.0, 1.0);
  }

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
        duration: _anim,
        curve: Curves.easeOut,
        alignment: 0.12,
      );
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
                  child: _TimelineCard(
                    spineFill: _spineFill,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: _buildRowWidgets(
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

  List<Widget> _buildRowWidgets({
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
    final rows = <Widget>[];
    final byDay = groupEventsByDateAndTimeOfDay(sorted, today);
    var insertedNow = false;

    for (var di = 0; di < byDay.length; di++) {
      final g = byDay[di];
      final day = g.day;
      final items = g.items;

      if (day != today) {
        rows.add(
          _DayDivider(label: _futureDaySectionLabel(day, today)),
        );
        for (final item in items) {
          rows.add(
            _EventRowWidget(
              key: _keyFor(item),
              item: item,
              now: now,
              isNext: identical(item, nextItem),
              isPast: _isFullyPast(item, now, today),
              mutedPast: _isFullyPast(item, now, today),
              pageBg: pageBg,
              muted: muted,
              titleColor: titleColor,
              onTap: () => onOpenDetail(item),
              upNextSubtitle: identical(item, nextItem)
                  ? formatUpNextTime(item.record.parsedStart, now)
                  : null,
            ),
          );
        }
        continue;
      }

      // Today
      if (pastTodayCount > 0 && (collapsePast || pastExpanded)) {
        rows.add(
          _PastSummaryChip(
            count: pastTodayCount,
            expanded: pastExpanded,
            onTap: onTogglePast,
          ),
        );
      }

      String? lastTod;
      for (final item in items) {
        if (collapsePast &&
            !pastExpanded &&
            _isFullyPast(item, now, today)) {
          continue;
        }

        final ps = item.record.parsedStart;
        final tod = ps == null ? 'TODAY' : _timeOfDayGroup(ps);
        if (tod != lastTod) {
          rows.add(_DayDivider(label: tod, emphasize: _isActiveTod(tod, now)));
          lastTod = tod;
        }

        if (!insertedNow &&
            !_isFullyPast(item, now, today) &&
            !day.isAfter(today)) {
          rows.add(
            AnimatedOpacity(
              duration: _anim,
              opacity: _inlineNowOpacity,
              child: _NowMarkerRow(key: _nowMarkerKey),
            ),
          );
          insertedNow = true;
        }

        rows.add(
          _EventRowWidget(
            key: _keyFor(item),
            item: item,
            now: now,
            isNext: identical(item, nextItem),
            isPast: _isFullyPast(item, now, today),
            mutedPast: _isFullyPast(item, now, today),
            pageBg: pageBg,
            muted: muted,
            titleColor: titleColor,
            onTap: () => onOpenDetail(item),
            upNextSubtitle: identical(item, nextItem)
                ? formatUpNextTime(item.record.parsedStart, now)
                : null,
          ),
        );
      }
    }

    return rows;
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
  final ra = _todaySubsectionRank(a.record, now, today);
  final rb = _todaySubsectionRank(b.record, now, today);
  if (ra != rb) return ra.compareTo(rb);
  return pa.compareTo(pb);
}

int _todaySubsectionRank(TeamEventsRecord e, DateTime now, DateTime today) {
  final ps = e.parsedStart;
  if (ps == null) return 2;
  if (_isHappeningNow(e, now)) return 0;
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
    if (_isHappeningNow(i.record, now)) {
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
    if (_isHappeningNow(i.record, now)) {
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
  const _TimelineCard({
    required this.spineFill,
    required this.child,
  });

  final double spineFill;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SwimDsTokens.cardBackground,
        borderRadius: BorderRadius.circular(SwimDsTokens.cardRadius),
        border: Border.all(color: SwimDsTokens.borderSoft, width: 1),
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
            width: 2,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: ObsidianVoltTokens.timelineSpine),
                  Align(
                    alignment: Alignment.topCenter,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOut,
                      height: (spineFill * 320).clamp(8.0, 320.0),
                      width: 2,
                      decoration: BoxDecoration(
                        color: SwimDsTokens.primaryPurple.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ],
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
  const _DayDivider({required this.label, this.emphasize = false});

  final String label;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 26 + 8, top: 12, bottom: 8),
      child: Text(
        label,
        style: GoogleFonts.sora(
          fontSize: 10,
          letterSpacing: 0.6,
          fontWeight: FontWeight.w700,
          color: emphasize
              ? SwimDsTokens.primaryPurple
              : SwimDsTokens.textSecondary,
        ),
      ),
    );
  }
}

class _NowMarkerRow extends StatelessWidget {
  const _NowMarkerRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 26 + 8, bottom: 8, top: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: SwimDsTokens.primaryPurple,
              boxShadow: [
                BoxShadow(
                  color: SwimDsTokens.primaryPurple.withValues(alpha: 0.35),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: SwimDsTokens.primaryPurple.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: SwimDsTokens.primaryPurple.withValues(alpha: 0.35),
              ),
            ),
            child: Text(
              'NOW',
              style: GoogleFonts.sora(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: SwimDsTokens.primaryPurple,
              ),
            ),
          ),
        ],
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
      padding: const EdgeInsets.only(left: 26 + 4, right: 0, bottom: 10),
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
    required this.isNext,
    required this.isPast,
    required this.mutedPast,
    required this.pageBg,
    required this.muted,
    required this.titleColor,
    required this.onTap,
    this.upNextSubtitle,
  });

  final ScheduleDisplayItem item;
  final DateTime now;
  final bool isNext;
  final bool isPast;
  final bool mutedPast;
  final Color pageBg;
  final Color muted;
  final Color titleColor;
  final VoidCallback onTap;
  final String? upNextSubtitle;

  @override
  Widget build(BuildContext context) {
    final cancelled = _isCancelled(item.record);
    final style = cancelled
        ? _TimelinePalette.cancelled()
        : _TimelinePalette.forType(item.record.eventType);

    final dotRing =
        !cancelled && (isNext || (!isPast && _isHappeningNow(item.record, now)));

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

    final typeLabel = teamEventTypeLabel(item.record.eventType);
    final hint = _agentHintForEvent(item);

    final borderColor = isNext
        ? SwimDsTokens.primaryPurple.withValues(alpha: 0.55)
        : (cancelled
            ? ObsidianVoltTokens.borderSubtle
            : SwimDsTokens.borderSoft);
    final cardBg = isNext
        ? SwimDsTokens.primaryPurple.withValues(alpha: 0.06)
        : (cancelled
            ? ObsidianVoltTokens.eventCancelledCardBg
            : SwimDsTokens.cardBackground);

    Widget card = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(SwimDsTokens.cardRadius),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(SwimDsTokens.cardPadding - 4),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(SwimDsTokens.cardRadius),
            border: Border.all(color: borderColor, width: isNext ? 1.5 : 1),
            boxShadow: cancelled ? null : SwimDsTokens.cardShadowSoft,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isNext && upNextSubtitle != null) ...[
                Text(
                  'UP NEXT · $upNextSubtitle',
                  style: GoogleFonts.sora(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: SwimDsTokens.primaryPurple,
                  ),
                ),
                const SizedBox(height: 6),
              ] else if (isNext) ...[
                Text(
                  'UP NEXT',
                  style: GoogleFonts.sora(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: SwimDsTokens.primaryPurple,
                  ),
                ),
                const SizedBox(height: 6),
              ],
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
                item.record.title.isEmpty ? '(Untitled)' : item.record.title,
                style: GoogleFonts.sora(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                  color: titleColor,
                  decoration: cancelled
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
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
    } else if (mutedPast && !isNext) {
      card = Opacity(opacity: 0.78, child: card);
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

// ─── Shared logic ───────────────────────────────────────────────────────────

String _futureDaySectionLabel(DateTime day, DateTime today) {
  final diff = day.difference(today).inDays;
  if (diff == 1) {
    return 'TOMORROW · ${DateFormat('EEE MMM d').format(day).toUpperCase()}';
  }
  return DateFormat('EEE, MMM d').format(day).toUpperCase();
}

String _timeOfDayGroup(DateTime ps) {
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
  if (_isHappeningNow(e, now)) return false;
  final end = _eventEndLocal(e);
  if (end != null) {
    return !end.isAfter(now);
  }
  return s.isBefore(now);
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
