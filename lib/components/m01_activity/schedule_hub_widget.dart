import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/theme/swim_ui_tokens.dart';
import '/theme/obsidian_volt_tokens.dart';

import 'schedule_display_item.dart';
import 'training_schedule_tab.dart';
import 'team_events_schedule.dart' show showScheduleEventDetailSheet;
import 'upcoming_timeline_tab.dart';

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

enum _SquadMenu { all, junior, senior }

enum _DateMenu { all, thisWeek, thisMonth }

class _ScheduleHubWidgetState extends State<ScheduleHubWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _coachSearch = TextEditingController();

  TeamEventType? _allTypeFilter;
  _SquadMenu _allSquadMenu = _SquadMenu.all;
  _DateMenu _allDateMenu = _DateMenu.all;

  TeamEventType? _coachTypeFilter;

  @override
  void initState() {
    super.initState();
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

  int _compareStartAsc(TeamEventsRecord a, TeamEventsRecord b) {
    if (a.parsedStart == null && b.parsedStart == null) {
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    }
    if (a.parsedStart == null) return 1;
    if (b.parsedStart == null) return -1;
    final c = a.parsedStart!.compareTo(b.parsedStart!);
    if (c != 0) return c;
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  }

  bool _isUpcomingDay(TeamEventsRecord e, DateTime today) {
    if (e.parsedStart == null) return false;
    final d = DateTime(
      e.parsedStart!.year,
      e.parsedStart!.month,
      e.parsedStart!.day,
    );
    return !d.isBefore(today);
  }

  bool _itemMatchesSquad(ScheduleDisplayItem i, _SquadMenu m) {
    if (m == _SquadMenu.all) return true;
    final s = i.squadLabel.toUpperCase();
    if (s == 'ALL' || s.isEmpty) return true;
    if (m == _SquadMenu.junior) {
      return s.contains('JUNIOR');
    }
    return s.contains('SENIOR');
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

  List<TeamEventsRecord> _normalize(List<TeamEventsRecord> raw) {
    final deduped = dedupeTeamEvents(raw);
    final expanded = expandScheduleList(deduped);
    expanded.sort(_compareStartAsc);
    return expanded;
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
      if (!_itemMatchesSquad(i, _allSquadMenu)) return false;
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
      _allSquadMenu = _SquadMenu.all;
      _allDateMenu = _DateMenu.all;
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
    return 24.0 + MediaQuery.paddingOf(context).bottom + 76.0;
  }

  @override
  Widget build(BuildContext context) {
    final primary = FlutterFlowTheme.of(context).primary;

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
              final displayAll = _toDisplay(normalized, baselines);
              final today = _todayDay();

              final upcomingRecords =
                  normalized.where((e) => _isUpcomingDay(e, today)).toList();
              final upcomingDisplay =
                  _toDisplay(upcomingRecords, baselines);

              final filteredAll =
                  _filterAllEvents(displayAll, today);
              final groupedRows = _groupByMonthHeader(filteredAll);
              final coachItems = _filterCoachFeed(displayAll);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 8.0),
                    child: _buildScheduleSegmentedControl(),
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildUpcomingTab(
                          context: context,
                          upcoming: upcomingDisplay,
                          baselines: baselines,
                          bottomPad: _bottomContentPadding(context),
                        ),
                        TrainingScheduleTabContent(
                          baselines: baselines,
                          primary: primary,
                          bottomPad: _bottomContentPadding(context),
                        ),
                        _buildAllEventsTab(
                          context: context,
                          groupedRows: groupedRows,
                          baselines: baselines,
                          primary: primary,
                          bottomPad: _bottomContentPadding(context),
                        ),
                        _buildCoachTab(
                          context: context,
                          items: coachItems,
                          baselines: baselines,
                          primary: primary,
                          bottomPad: _bottomContentPadding(context),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  /// Matches Meets page segmented shell (`m02_meet_widget.dart` primary control).
  Widget _buildScheduleSegmentedControl() {
    Widget segment(int index, String label) {
      final selected = _tabController.index == index;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (_tabController.index != index) {
              _tabController.animateTo(index);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            decoration: BoxDecoration(
              color: selected ? SwimUiTokens.surfaceCard : Colors.transparent,
              borderRadius: BorderRadius.circular(SwimUiTokens.radiusSm),
              border: Border.all(
                color:
                    selected ? SwimUiTokens.borderSubtle : Colors.transparent,
                width: 1.0,
              ),
              boxShadow: selected ? SwimUiTokens.shadowSegmentPill : null,
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.sora(
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected
                    ? SwimUiTokens.textBannerTitle
                    : SwimUiTokens.textMuted,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3.0),
      decoration: BoxDecoration(
        color: SwimUiTokens.surfaceCanvasSchedule,
        borderRadius: BorderRadius.circular(SwimUiTokens.radiusSegmentShell),
        border: Border.all(color: SwimUiTokens.borderSegmentTrack),
      ),
      child: Row(
        children: [
          segment(0, 'Upcoming'),
          const SizedBox(width: 4.0),
          segment(1, 'Training'),
          const SizedBox(width: 4.0),
          segment(2, 'Events'),
          const SizedBox(width: 4.0),
          segment(3, 'Coach'),
        ],
      ),
    );
  }

  Widget _buildUpcomingTab({
    required BuildContext context,
    required List<ScheduleDisplayItem> upcoming,
    required List<ScheduleBaseline> baselines,
    required double bottomPad,
  }) {
    return UpcomingTimelineTab(
      items: upcoming,
      bottomPad: bottomPad,
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
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
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
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Expanded(
                  child: _FilterDropdown<_SquadMenu>(
                    label: _squadLabel(_allSquadMenu),
                    items: _SquadMenu.values,
                    itemLabel: _squadLabel,
                    value: _allSquadMenu,
                    onChanged: (v) =>
                        setState(() => _allSquadMenu = v ?? _SquadMenu.all),
                  ),
                ),
                const SizedBox(width: 10),
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
              ],
            ),
          ),
        ),
        if (groupedRows.isEmpty)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(24, 48, 24, bottomPad),
            sliver: const SliverToBoxAdapter(
              child: _EmptyPanel(
                title: 'No events found',
                subtitle: 'Try changing your filters.',
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(24, 6, 24, bottomPad),
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
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _CompactEventTile(
                      item: i,
                      accent: _accent(i.type),
                      squadBg: _squadPillBg(i.squadLabel),
                      squadFg: _squadPillFg(i.squadLabel),
                      showTimeRow: true,
                      showChevron: true,
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

  String _squadLabel(_SquadMenu m) {
    switch (m) {
      case _SquadMenu.all:
        return 'All Squads';
      case _SquadMenu.junior:
        return 'Junior';
      case _SquadMenu.senior:
        return 'Senior';
    }
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
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 10),
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
                      prefixIcon: const Icon(Icons.search_rounded, size: 22),
                      filled: true,
                      fillColor: SwimUiTokens.surfaceCard,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: ObsidianVoltTokens.borderDefault),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: ObsidianVoltTokens.borderDefault),
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
            padding: EdgeInsets.fromLTRB(24, 36, 24, bottomPad),
            sliver: const SliverToBoxAdapter(
              child: _EmptyPanel(
                title: 'No coach updates yet',
                subtitle:
                    'Parsed messages from coach emails will appear here.',
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(24, 4, 24, bottomPad),
            sliver: SliverList.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, idx) {
                final i = items[idx];
                return _CompactEventTile(
                  item: i,
                  accent: _accent(i.type),
                  squadBg: _squadPillBg(i.squadLabel),
                  squadFg: _squadPillFg(i.squadLabel),
                  showPreview: true,
                  showChevron: true,
                  onTap: () => showScheduleEventDetailSheet(
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
                      'Use category chips on the main view for type. Advanced squad/date filters match the All Events tab logic in a future update.',
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

class _GroupedRow {
  _GroupedRow({this.header, this.item});
  final String? header;
  final ScheduleDisplayItem? item;
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      decoration: BoxDecoration(
        color: SwimUiTokens.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ObsidianVoltTokens.borderDefault, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.sora(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: SwimUiTokens.textBannerTitle,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: GoogleFonts.sora(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.35,
              color: SwimUiTokens.textMuted,
            ),
          ),
        ],
      ),
    );
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
    this.dense = false,
  });

  final ScheduleDisplayItem item;
  final Color accent;
  final Color squadBg;
  final Color squadFg;
  final VoidCallback onTap;
  final bool showChevron;
  final bool showTimeRow;
  final bool showPreview;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final typeLabel = teamEventTypeLabel(item.type).toUpperCase();
    return Material(
      color: SwimUiTokens.surfaceCard,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ObsidianVoltTokens.borderDefault, width: 0.5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 4, color: accent),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        12,
                        dense ? 10 : 12,
                        8,
                        dense ? 10 : 12,
                      ),
                      child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _TypePill(label: typeLabel, accent: accent),
                            const SizedBox(width: 6),
                            if (item.squadLabel.isNotEmpty)
                              _SquadPill(
                                label: item.squadLabel,
                                bg: squadBg,
                                fg: squadFg,
                              ),
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
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.record.title.isEmpty
                              ? '(Untitled)'
                              : item.record.title,
                          maxLines: dense ? 2 : 3,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.sora(
                            fontSize: dense ? 13.5 : 14,
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
                    ),
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

class _TypePill extends StatelessWidget {
  const _TypePill({required this.label, required this.accent});
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: GoogleFonts.sora(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          color: accent,
        ),
      ),
    );
  }
}

class _SquadPill extends StatelessWidget {
  const _SquadPill({
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.sora(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
          color: fg,
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
