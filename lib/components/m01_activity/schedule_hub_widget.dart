import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '/app_state.dart';
import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/meet_preferences_api.dart';
import '/backend/schema/meet_preferences_record.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/theme/lavender_indigo_tokens.dart';
import '/theme/swim_design_tokens.dart';
import '/theme/swim_ui_tokens.dart';
import '/widgets/swim_ui_kit.dart';
import '/theme/obsidian_volt_tokens.dart';

import '/components/m02_meet/my_meets_timeline_filter.dart';

import 'schedule_display_item.dart';
import 'training_schedule_tab.dart';
import 'team_events_schedule.dart' show showScheduleEventDetailSheet;
import 'dynamic_schedule_timeline.dart';

/// **Debug / simulator only** (`kDebugMode`): when non-null, Schedule → Today uses
/// this instead of the real clock so you can preview HAPPENING NOW, UP NEXT, and
/// the current-time line without waiting.
///
/// Example: `DateTime(2026, 5, 7, 19, 10)` → May 7, 2026 at 7:10 PM **local**.
/// Set back to `null` for normal behavior. **Release** builds always ignore this
/// (debug & profile can use the override).
DateTime? debugScheduleTimelineNow() {
  if (kReleaseMode) return null;
  // return null;
  return DateTime(2026, 5, 7, 20, 10);
}

/// Four-tab Schedule experience: Upcoming, Training Schedule, All Events, From Coach.
class ScheduleHubWidget extends StatefulWidget {
  const ScheduleHubWidget({
    super.key,
    required this.teamId,
  });

  final String teamId;

  @override
  State<ScheduleHubWidget> createState() => _ScheduleHubWidgetState();
}

enum _DateMenu { all, thisWeek, thisMonth }

class _ScheduleHubWidgetState extends State<ScheduleHubWidget>
    with SingleTickerProviderStateMixin {
  int _lastHandledScheduleJumpGen = 0;
  late TabController _tabController;
  final TextEditingController _coachSearch = TextEditingController();

  TeamEventType? _allTypeFilter;
  _DateMenu _allDateMenu = _DateMenu.all;

  /// When true, schedule lists follow junior practice tier (hide senior-only rows).
  late bool _scheduleJuniorTier;
  late String _lastProfilePracticeTierLabel;

  TeamEventType? _coachTypeFilter;

  @override
  void initState() {
    super.initState();
    _lastProfilePracticeTierLabel = FFAppState().swimmerPracticeTierLabel;
    _scheduleJuniorTier = _juniorFromPracticeLabel(_lastProfilePracticeTierLabel);
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onScheduleTabChanged);
    _coachSearch.addListener(() => setState(() {}));
  }

  void _onScheduleTabChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _tabController.removeListener(_onScheduleTabChanged);
    _tabController.dispose();
    _coachSearch.dispose();
    super.dispose();
  }

  DateTime _todayDay() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  DateTime _startOfWeekMonday(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    final diff = day.weekday - DateTime.monday;
    return day.subtract(Duration(days: diff));
  }

  bool _inThisWeek(DateTime? parsed, DateTime today) {
    if (parsed == null) return false;
    final eDay = DateTime(parsed.year, parsed.month, parsed.day);
    final s = _startOfWeekMonday(today);
    final e = s.add(const Duration(days: 6));
    return !eDay.isBefore(s) && !eDay.isAfter(e);
  }

  bool _inThisMonth(DateTime? parsed, DateTime today) {
    if (parsed == null) return false;
    return parsed.year == today.year && parsed.month == today.month;
  }

  bool _isUpcomingDay(TeamEventsRecord e, DateTime today) {
    final d = calendarDayForTeamEventListing(e);
    if (d == null) return false;
    return !d.isBefore(today);
  }

  static bool _juniorFromPracticeLabel(String raw) {
    final t = raw.trim().toLowerCase();
    if (t.contains('senior')) {
      return false;
    }
    return true;
  }
  bool _recordMatchesDate(TeamEventsRecord e, _DateMenu m, DateTime today) {
    switch (m) {
      case _DateMenu.all:
        return true;
      case _DateMenu.thisWeek:
        return _inThisWeek(e.parsedStart, today);
      case _DateMenu.thisMonth:
        return _inThisMonth(e.parsedStart, today);
    }
  }

  List<TeamEventsRecord> _normalize(List<TeamEventsRecord> raw) =>
      normalizeTeamEventsList(raw);

  void _handleAgentScheduleJumpIfNeeded(
    BuildContext context,
    List<TeamEventsRecord> normalized,
    List<ScheduleBaseline> baselines,
  ) {
    final jump = FFAppState().peekPendingScheduleJump();
    if (jump == null) {
      return;
    }
    if (jump.generation == _lastHandledScheduleJumpGen) {
      return;
    }
    TeamEventsRecord? match;
    for (final e in normalized) {
      if (e.docId == jump.docId &&
          e.startDate.trim() == jump.startDate.trim()) {
        match = e;
        break;
      }
    }
    if (match == null) {
      for (final e in normalized) {
        if (e.docId == jump.docId) {
          match = e;
          break;
        }
      }
    }
    if (match == null) {
      if (normalized.isNotEmpty) {
        _lastHandledScheduleJumpGen = jump.generation;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          FFAppState().clearPendingScheduleJump();
        });
      }
      return;
    }
    _lastHandledScheduleJumpGen = jump.generation;
    final event = match;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      FFAppState().clearPendingScheduleJump();
      if (!context.mounted) return;
      await showScheduleEventDetailSheet(
        context,
        event: event,
        baselines: baselines,
      );
    });
  }

  List<ScheduleDisplayItem> _toDisplay(
    List<TeamEventsRecord> records,
    List<ScheduleBaseline> baselines,
  ) =>
      records
          .map((e) => ScheduleDisplayItem.fromRecord(e, baselines))
          .toList();

  List<ScheduleDisplayItem> _filterAllEvents(
    List<ScheduleDisplayItem> items,
    DateTime today,
  ) {
    return items.where((i) {
      final e = i.record;
      if (_allTypeFilter != null && e.eventType != _allTypeFilter) {
        return false;
      }
      if (!i.matchesPracticeTierFilter(forJuniorTier: _scheduleJuniorTier)) {
        return false;
      }
      if (!_recordMatchesDate(e, _allDateMenu, today)) return false;
      return true;
    }).toList();
  }

  bool _isLikelyCoachEmailEvent(TeamEventsRecord e) {
    return e.subject.trim().isNotEmpty ||
        e.sender.trim().isNotEmpty ||
        e.sourceSection.trim().isNotEmpty;
  }

  List<ScheduleDisplayItem> _filterCoachFeed(List<ScheduleDisplayItem> items) {
    final q = _coachSearch.text.trim().toLowerCase();
    return items.where((i) {
      if (!_isLikelyCoachEmailEvent(i.record)) return false;
      if (_coachTypeFilter != null && i.record.eventType != _coachTypeFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return i.searchBlob.contains(q);
    }).toList();
  }

  void _clearAllFilters() {
    setState(() {
      _allTypeFilter = null;
      _allDateMenu = _DateMenu.all;
      _lastProfilePracticeTierLabel = FFAppState().swimmerPracticeTierLabel;
      _scheduleJuniorTier =
          _juniorFromPracticeLabel(_lastProfilePracticeTierLabel);
    });
  }

  Color _accent(TeamEventType t) {
    switch (t) {
      case TeamEventType.training:
        return ObsidianVoltTokens.eventTrainingDot;
      case TeamEventType.meet:
        return ObsidianVoltTokens.eventMeetDot;
      case TeamEventType.social:
        return ObsidianVoltTokens.eventSocialDot;
      case TeamEventType.admin:
        return ObsidianVoltTokens.eventAdminDot;
      case TeamEventType.unknown:
        return ObsidianVoltTokens.textSecondary;
    }
  }

  Color _squadPillBg(String label) {
    final u = label.toUpperCase();
    if (u.contains('JUNIOR')) return ObsidianVoltTokens.squadJuniorBg;
    if (u.contains('SENIOR')) return ObsidianVoltTokens.squadSeniorBg;
    return ObsidianVoltTokens.squadAllBg;
  }

  Color _squadPillFg(String label) {
    final u = label.toUpperCase();
    if (u.contains('JUNIOR')) return ObsidianVoltTokens.squadJuniorText;
    if (u.contains('SENIOR')) return ObsidianVoltTokens.squadSeniorText;
    return ObsidianVoltTokens.squadAllText;
  }

  double _bottomContentPadding(BuildContext context) {
    final safe = MediaQuery.paddingOf(context).bottom;
    // Bottom nav + safe area + breathing room so last cards clear the tab bar.
    return 32.0 + safe + 96.0;
  }

  @override
  Widget build(BuildContext context) {
    final primary = FlutterFlowTheme.of(context).primary;
    final app = context.watch<FFAppState>();
    final tierLabel = app.swimmerPracticeTierLabel;
    if (tierLabel != _lastProfilePracticeTierLabel) {
      final captured = tierLabel;
      _lastProfilePracticeTierLabel = captured;
      final jr = _juniorFromPracticeLabel(captured);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _scheduleJuniorTier = jr);
      });
    }

    return ColoredBox(
      color: ObsidianVoltTokens.bgBase,
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: streamTeamRegistryDocument(widget.teamId),
        builder: (context, registrySnap) {
          final baselines = (!registrySnap.hasError && registrySnap.hasData)
              ? ScheduleBaseline.listFromSnapshotData(
                  registrySnap.data!.data(),
                )
              : <ScheduleBaseline>[];

          return StreamBuilder<List<TeamEventsRecord>>(
            stream: streamTeamEvents(widget.teamId),
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      snap.error.toString(),
                      style: GoogleFonts.sora(
                        fontSize: 13.0,
                        color: SwimUiTokens.textMuted,
                      ),
                    ),
                  ),
                );
              }
              if (!snap.hasData) {
                return const Center(
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                );
              }

              final normalized = _normalize(snap.data!);
              _handleAgentScheduleJumpIfNeeded(context, normalized, baselines);
              final displayAll = _toDisplay(normalized, baselines);
              final today = _todayDay();

              final upcomingRecords =
                  normalized.where((e) => _isUpcomingDay(e, today)).toList();
              final upcomingDisplay =
                  _toDisplay(upcomingRecords, baselines);

              final filteredAll =
                  _filterAllEvents(displayAll, today);
              final groupedRows = _groupByMonthHeader(filteredAll);
              final coachItems = _filterCoachFeed(displayAll)
                  .where(
                    (i) => i.matchesPracticeTierFilter(
                      forJuniorTier: _scheduleJuniorTier,
                    ),
                  )
                  .toList();

              final tierFiltered = upcomingDisplay
                  .where(
                    (i) => i.matchesPracticeTierFilter(
                      forJuniorTier: _scheduleJuniorTier,
                    ),
                  )
                  .toList();

              if (currentUserUid.isEmpty) {
                return _buildScheduleHubMainColumn(
                  context: context,
                  primary: primary,
                  baselines: baselines,
                  upcomingFiltered: tierFiltered,
                  groupedRows: groupedRows,
                  coachItems: coachItems,
                );
              }

              return StreamBuilder<Map<String, MeetPreferencesRecord>>(
                stream: streamMeetPreferencesMap(currentUserUid),
                builder: (context, prefSnap) {
                  return StreamBuilder<List<MonitoredMeetsRecord>>(
                    stream: streamMonitoredMeetsForSwimmer(
                      zoneId: app.currentSwimmerZoneForMeets,
                      priorityHostGroup: app.currentSwimmerGroup,
                      showAll: app.meetsShowAllZones,
                      widePastWindow: true,
                    ),
                    builder: (context, monSnap) {
                      if (!prefSnap.hasData || !monSnap.hasData) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                SwimDsTokens.pageHorizontalPadding,
                                SwimDsTokens.smallGap,
                                SwimDsTokens.pageHorizontalPadding,
                                SwimDsTokens.tabsToContentGap,
                              ),
                              child: _buildScheduleSegmentedControl(),
                            ),
                            const Expanded(
                              child: Center(
                                child: SizedBox(
                                  width: 36,
                                  height: 36,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }

                      final prefs = prefSnap.data!;
                      final monitored = monSnap.data!;
                      final upcomingFiltered = tierFiltered
                          .where(
                            (i) => teamEventMeetPassesMyMeetsTimelineFilter(
                              i.record,
                              prefs,
                              monitored,
                            ),
                          )
                          .toList();

                      return _buildScheduleHubMainColumn(
                        context: context,
                        primary: primary,
                        baselines: baselines,
                        upcomingFiltered: upcomingFiltered,
                        groupedRows: groupedRows,
                        coachItems: coachItems,
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  /// Tab shell: segmented control + [TabBarView] (Today, Training, Events, Coach).
  Widget _buildScheduleHubMainColumn({
    required BuildContext context,
    required Color primary,
    required List<ScheduleBaseline> baselines,
    required List<ScheduleDisplayItem> upcomingFiltered,
    required List<_GroupedRow> groupedRows,
    required List<ScheduleDisplayItem> coachItems,
  }) {
    final bottomPad = _bottomContentPadding(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            SwimDsTokens.pageHorizontalPadding,
            SwimDsTokens.smallGap,
            SwimDsTokens.pageHorizontalPadding,
            SwimDsTokens.tabsToContentGap,
          ),
          child: _buildScheduleSegmentedControl(),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildUpcomingTab(
                context: context,
                upcoming: upcomingFiltered,
                baselines: baselines,
                bottomPad: bottomPad,
              ),
              TrainingScheduleTabContent(
                baselines: baselines,
                primary: primary,
                bottomPad: bottomPad,
              ),
              _buildAllEventsTab(
                context: context,
                groupedRows: groupedRows,
                baselines: baselines,
                primary: primary,
                bottomPad: bottomPad,
              ),
              _buildCoachTab(
                context: context,
                items: coachItems,
                baselines: baselines,
                primary: primary,
                bottomPad: bottomPad,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleSegmentedControl() {
    return AppSegmentedTabs(
      labels: const ['Today', 'Training', 'Events', 'Coach'],
      selectedIndex: _tabController.index,
      onChanged: (i) {
        if (_tabController.index != i) {
          _tabController.animateTo(i);
        }
      },
    );
  }

  Widget _buildUpcomingTab({
    required BuildContext context,
    required List<ScheduleDisplayItem> upcoming,
    required List<ScheduleBaseline> baselines,
    required double bottomPad,
  }) {
    return DynamicScheduleTimeline(
      items: upcoming,
      bottomPad: bottomPad,
      currentDateTime: debugScheduleTimelineNow(),
      onOpenDetail: (item) => showScheduleEventDetailSheet(
        context,
        event: item.record,
        baselines: baselines,
      ),
    );
  }

  Widget _buildAllEventsTab({
    required BuildContext context,
    required List<_GroupedRow> groupedRows,
    required List<ScheduleBaseline> baselines,
    required Color primary,
    required double bottomPad,
  }) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            SwimDsTokens.pageHorizontalPadding,
            12,
            SwimDsTokens.pageHorizontalPadding,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'All Events',
                    style: GoogleFonts.sora(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: SwimUiTokens.textBannerTitle,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showAllEventsFilterSheet(context, primary),
                  icon: Icon(Icons.tune_rounded, size: 18, color: primary),
                  label: Text(
                    'Filter',
                    style: GoogleFonts.sora(
                      fontWeight: FontWeight.w700,
                      color: primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          sliver: SliverToBoxAdapter(
            child: _CategoryChipsRow(
              selected: _allTypeFilter,
              onSelected: (t) => setState(() => _allTypeFilter = t),
              primary: primary,
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            SwimDsTokens.pageHorizontalPadding,
            0,
            SwimDsTokens.pageHorizontalPadding,
            8,
          ),
          sliver: SliverToBoxAdapter(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: _FilterDropdown<_DateMenu>(
                    label: _dateLabel(_allDateMenu),
                    items: _DateMenu.values,
                    itemLabel: _dateLabel,
                    value: _allDateMenu,
                    onChanged: (v) =>
                        setState(() => _allDateMenu = v ?? _DateMenu.all),
                  ),
                ),
                const SizedBox(width: 10),
                _JuniorSeniorScheduleToggle(
                  juniorSelected: _scheduleJuniorTier,
                  onChanged: (junior) =>
                      setState(() => _scheduleJuniorTier = junior),
                ),
              ],
            ),
          ),
        ),
        if (groupedRows.isEmpty)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              SwimDsTokens.pageHorizontalPadding,
              48,
              SwimDsTokens.pageHorizontalPadding,
              bottomPad,
            ),
            sliver: SliverToBoxAdapter(
              child: EmptyStateCard(
                title: 'No events found',
                message: 'Try changing your filters or date range.',
                icon: Icons.event_busy_outlined,
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              SwimDsTokens.pageHorizontalPadding,
              6,
              SwimDsTokens.pageHorizontalPadding,
              bottomPad,
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final entry = groupedRows[index];
                  if (entry.header != null) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 8),
                      child: Text(
                        entry.header!,
                        style: GoogleFonts.sora(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: SwimUiTokens.textMuted,
                          letterSpacing: 0.3,
                        ),
                      ),
                    );
                  }
                  final i = entry.item!;
                  return Padding(
                    padding: EdgeInsets.only(bottom: SwimDsTokens.cardSpacing),
                    child: _CompactEventTile(
                      item: i,
                      accent: _accent(i.type),
                      squadBg: _squadPillBg(i.squadLabel),
                      squadFg: _squadPillFg(i.squadLabel),
                      showTimeRow: true,
                      showChevron: true,
                      showLeadingDateTile: true,
                      showPreview: true,
                      onTap: () => showScheduleEventDetailSheet(
                        context,
                        event: i.record,
                        baselines: baselines,
                      ),
                    ),
                  );
                },
                childCount: groupedRows.length,
              ),
            ),
          ),
      ],
    );
  }

  String _dateLabel(_DateMenu m) {
    switch (m) {
      case _DateMenu.all:
        return 'All Dates';
      case _DateMenu.thisWeek:
        return 'This Week';
      case _DateMenu.thisMonth:
        return 'This Month';
    }
  }

  Future<void> _showAllEventsFilterSheet(
    BuildContext context,
    Color primary,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: ObsidianVoltTokens.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Filters',
                  style: GoogleFonts.sora(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () {
                      _clearAllFilters();
                      Navigator.pop(ctx);
                    },
                    child: Text(
                      'Clear all',
                      style: GoogleFonts.sora(
                        fontWeight: FontWeight.w700,
                        color: primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Done',
                    style: GoogleFonts.sora(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    setState(() {});
  }

  List<_GroupedRow> _groupByMonthHeader(List<ScheduleDisplayItem> items) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final out = <_GroupedRow>[];
    var lastKey = '';
    for (final i in items) {
      final ps = i.record.parsedStart;
      final key = ps == null ? 'Undated' : '${months[ps.month - 1]} ${ps.year}';
      if (key != lastKey) {
        lastKey = key;
        out.add(_GroupedRow(header: key));
      }
      out.add(_GroupedRow(item: i));
    }
    return out;
  }

  Widget _buildCoachTab({
    required BuildContext context,
    required List<ScheduleDisplayItem> items,
    required List<ScheduleBaseline> baselines,
    required Color primary,
    required double bottomPad,
  }) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            SwimDsTokens.pageHorizontalPadding,
            12,
            SwimDsTokens.pageHorizontalPadding,
            10,
          ),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _coachSearch,
                    decoration: InputDecoration(
                      hintText: 'Search coach updates…',
                      hintStyle: GoogleFonts.sora(
                        fontSize: 13.5,
                        color: SwimUiTokens.textMuted,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        size: 22,
                        color: SwimUiTokens.textMuted,
                      ),
                      filled: true,
                      fillColor: SwimDsTokens.cardBackground,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(SwimDsTokens.cardRadius),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(SwimDsTokens.cardRadius),
                        borderSide: BorderSide(color: SwimDsTokens.borderSoft),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(SwimDsTokens.cardRadius),
                        borderSide: BorderSide(
                          color: LavenderIndigoTokens.primary
                              .withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: () => _showCoachFilterSheet(context, primary),
                  icon: const Icon(Icons.filter_list_rounded),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          sliver: SliverToBoxAdapter(
            child: _CategoryChipsRow(
              selected: _coachTypeFilter,
              onSelected: (t) => setState(() => _coachTypeFilter = t),
              primary: primary,
            ),
          ),
        ),
        if (items.isEmpty)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              SwimDsTokens.pageHorizontalPadding,
              36,
              SwimDsTokens.pageHorizontalPadding,
              bottomPad,
            ),
            sliver: SliverToBoxAdapter(
              child: EmptyStateCard(
                title: 'No coach updates yet',
                message:
                    'Parsed coach messages will appear here when your team posts them.',
                icon: Icons.forum_outlined,
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              SwimDsTokens.pageHorizontalPadding,
              4,
              SwimDsTokens.pageHorizontalPadding,
              bottomPad,
            ),
            sliver: SliverList.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) =>
                  SizedBox(height: SwimDsTokens.cardSpacing),
              itemBuilder: (context, idx) {
                final i = items[idx];
                return _CoachUpdateCard(
                  item: i,
                  onOpen: () => showScheduleEventDetailSheet(
                    context,
                    event: i.record,
                    baselines: baselines,
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Future<void> _showCoachFilterSheet(
    BuildContext context,
    Color primary,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: ObsidianVoltTokens.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModal) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Coach feed filters',
                      style: GoogleFonts.sora(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Use category chips on the main view for type. Junior/Senior on the Events tab filters squads there and on Upcoming/Coach.',
                      style: GoogleFonts.sora(
                        fontSize: 12.5,
                        color: SwimUiTokens.textMuted,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        'Close',
                        style: GoogleFonts.sora(
                          fontWeight: FontWeight.w700,
                          color: primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _JuniorSeniorScheduleToggle extends StatelessWidget {
  const _JuniorSeniorScheduleToggle({
    required this.juniorSelected,
    required this.onChanged,
  });

  final bool juniorSelected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget segment({required String label, required bool selected, required VoidCallback onTap}) {
      return GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? SwimUiTokens.surfaceCard : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? SwimUiTokens.borderSubtle : Colors.transparent,
            ),
            boxShadow: selected ? SwimUiTokens.shadowSegmentPill : null,
          ),
          child: Text(
            label,
            style: GoogleFonts.sora(
              fontSize: 11.5,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected
                  ? SwimUiTokens.textBannerTitle
                  : SwimUiTokens.textMuted,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: SwimUiTokens.surfaceCanvasSchedule,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: SwimUiTokens.borderSegmentTrack),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          segment(
            label: 'Junior',
            selected: juniorSelected,
            onTap: () => onChanged(true),
          ),
          segment(
            label: 'Senior',
            selected: !juniorSelected,
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }
}

class _GroupedRow {
  _GroupedRow({this.header, this.item});
  final String? header;
  final ScheduleDisplayItem? item;
}

String _scheduleCoachCategoryLabel(TeamEventType t) {
  switch (t) {
    case TeamEventType.meet:
      return 'Meet Entry';
    case TeamEventType.training:
      return 'Training Change';
    case TeamEventType.admin:
      return 'Announcement';
    case TeamEventType.social:
      return 'Social';
    case TeamEventType.unknown:
      return 'Announcement';
  }
}

SwimStatusPillKind _scheduleCoachCategoryPillKind(TeamEventType t) {
  switch (t) {
    case TeamEventType.meet:
      return SwimStatusPillKind.meet;
    case TeamEventType.training:
      return SwimStatusPillKind.training;
    case TeamEventType.admin:
      return SwimStatusPillKind.today;
    case TeamEventType.social:
      return SwimStatusPillKind.newUpdate;
    case TeamEventType.unknown:
      return SwimStatusPillKind.neutral;
  }
}

class _CoachUpdateCard extends StatelessWidget {
  const _CoachUpdateCard({
    required this.item,
    required this.onOpen,
  });

  final ScheduleDisplayItem item;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final ps = item.record.parsedStart;
    final dateStr = ps != null
        ? DateFormat.yMMMd().format(ps)
        : item.dateShortLabel;
    final rawSource = item.record.sourceSection.trim();
    final source = rawSource.isNotEmpty
        ? rawSource
        : (item.record.sender.trim().isNotEmpty ? 'Coach' : 'Team schedule');

    return AppCard(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.record.title.isEmpty ? 'Update' : item.record.title,
                  style: GoogleFonts.sora(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: SwimDsTokens.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                dateStr,
                style: GoogleFonts.sora(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: SwimDsTokens.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              StatusPill(
                label: _scheduleCoachCategoryLabel(item.type),
                kind: _scheduleCoachCategoryPillKind(item.type),
              ),
              StatusPill(
                label: source,
                kind: SwimStatusPillKind.neutral,
              ),
            ],
          ),
          if (item.summaryPreview.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              item.summaryPreview,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.sora(
                fontSize: 13,
                height: 1.35,
                color: SwimDsTokens.textSecondary,
              ),
            ),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onOpen,
              style: TextButton.styleFrom(
                foregroundColor: SwimDsTokens.tealApproved,
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'View full message',
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

SwimStatusPillKind _eventTypePillKind(TeamEventType t) {
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

class _CompactEventTile extends StatelessWidget {
  const _CompactEventTile({
    required this.item,
    required this.accent,
    required this.squadBg,
    required this.squadFg,
    required this.onTap,
    this.showChevron = false,
    this.showTimeRow = false,
    this.showPreview = false,
    this.showLeadingDateTile = false,
  });

  final ScheduleDisplayItem item;
  final Color accent;
  final Color squadBg;
  final Color squadFg;
  final VoidCallback onTap;
  final bool showChevron;
  final bool showTimeRow;
  final bool showPreview;
  final bool showLeadingDateTile;

  @override
  Widget build(BuildContext context) {
    final typeLabel = teamEventTypeLabel(item.type);
    final ps = item.record.parsedStart;
    final month =
        ps != null ? DateFormat('MMM').format(ps) : '—';
    final day = ps != null ? '${ps.day}' : '—';

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StatusPill(
              label: typeLabel,
              kind: _eventTypePillKind(item.type),
            ),
            const SizedBox(width: 6),
            if (item.squadLabel.isNotEmpty)
              StatusPill(
                label: item.squadLabel,
                kind: SwimStatusPillKind.notDecided,
              ),
            if (!showLeadingDateTile) ...[
              const Spacer(),
              Text(
                item.dateShortLabel,
                style: GoogleFonts.sora(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: SwimUiTokens.textTitle,
                ),
              ),
            ],
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
            color: SwimUiTokens.textBannerTitle,
          ),
        ),
        if (showTimeRow && item.timeDisplayLabel.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            item.timeDisplayLabel,
            style: GoogleFonts.sora(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: SwimUiTokens.textMuted,
            ),
          ),
        ],
        if (item.locationDisplay.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            item.locationDisplay,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.sora(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: SwimUiTokens.textMuted,
            ),
          ),
        ],
        if (showPreview && item.summaryPreview.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            item.summaryPreview,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.sora(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              height: 1.35,
              color: SwimUiTokens.textMuted,
            ),
          ),
        ],
      ],
    );

    return Material(
      color: SwimDsTokens.cardBackground,
      borderRadius: BorderRadius.circular(SwimDsTokens.cardRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(SwimDsTokens.cardRadius),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SwimDsTokens.cardRadius),
            border: Border.all(color: SwimDsTokens.borderSoft, width: 1),
            boxShadow: SwimDsTokens.cardShadowSoft,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(SwimDsTokens.cardRadius),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!showLeadingDateTile)
                    Container(width: 4, color: accent),
                  if (showLeadingDateTile) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 10, top: 12, bottom: 12),
                      child: SwimDateTile(
                        monthAbbrev: month,
                        dayText: day,
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                      child: body,
                    ),
                  ),
                  if (showChevron)
                    Padding(
                      padding: const EdgeInsets.only(right: 6, top: 12),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: SwimUiTokens.textMuted,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryChipsRow extends StatelessWidget {
  const _CategoryChipsRow({
    required this.selected,
    required this.onSelected,
    required this.primary,
  });

  final TeamEventType? selected;
  final ValueChanged<TeamEventType?> onSelected;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    final types = <TeamEventType?>[
      null,
      TeamEventType.training,
      TeamEventType.meet,
      TeamEventType.social,
      TeamEventType.admin,
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          for (final t in types) ...[
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(t == null ? 'All' : teamEventTypeLabel(t)),
                selected: selected == t,
                onSelected: (_) => onSelected(t),
                selectedColor: ObsidianVoltTokens.tabSelectedBg,
                labelStyle: GoogleFonts.sora(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: selected == t
                      ? ObsidianVoltTokens.textPrimary
                      : ObsidianVoltTokens.textSecondary,
                ),
                backgroundColor: ObsidianVoltTokens.tabContainerBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                  side: BorderSide(
                    color: selected == t
                        ? ObsidianVoltTokens.borderDefault
                        : ObsidianVoltTokens.borderSubtle,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.items,
    required this.itemLabel,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final List<T> items;
  final String Function(T) itemLabel;
  final T value;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: SwimUiTokens.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: ObsidianVoltTokens.borderDefault, width: 0.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: value,
          hint: Text(label, style: GoogleFonts.sora(fontSize: 12.5)),
          items: items
              .map(
                (e) => DropdownMenuItem(
                  value: e,
                  child: Text(itemLabel(e), style: GoogleFonts.sora()),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
