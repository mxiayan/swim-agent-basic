import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/meet_preferences_api.dart';
import '/backend/schema/meet_preferences_record.dart';
import '/components/m02_meet_entered/m02_meet_entered_widget.dart';
import '/custom_code/actions/refresh_swimmer_app_state.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/theme/swim_ui_tokens.dart';
import '/theme/obsidian_volt_tokens.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'meet_list_quick_filter.dart';
import 'm02_meet_model.dart';
export 'm02_meet_model.dart';

enum _MeetPrimaryView { myMeets, allMeets }

enum _MyMeetSectionTone { needsAction, entered, skipped, neutral }

class M02MeetWidget extends StatefulWidget {
  const M02MeetWidget({super.key});

  @override
  State<M02MeetWidget> createState() => _M02MeetWidgetState();
}

class _M02MeetWidgetState extends State<M02MeetWidget> {
  late M02MeetModel _model;

  bool _meetBannerReady = false;
  _MeetPrimaryView _primaryView = _MeetPrimaryView.myMeets;
  final TextEditingController _allMeetsSearchController =
      TextEditingController();

  static const List<String> _otherClassTokens = <String>[
    'observed',
    'approved',
    'invitational',
    'hs',
    'masters',
  ];

  bool _containsClassToken(MonitoredMeetsRecord meet, String token) {
    final t = token.trim().toLowerCase();
    if (t.isEmpty) {
      return false;
    }
    for (final raw in meet.meetClasses) {
      final c = raw.trim().toLowerCase();
      if (c.isEmpty) {
        continue;
      }
      if (c == t || c.contains(t)) {
        return true;
      }
    }
    return false;
  }

  bool _isOtherClass(MonitoredMeetsRecord meet) {
    for (final t in _otherClassTokens) {
      if (_containsClassToken(meet, t)) {
        return true;
      }
    }
    return false;
  }

  bool _matchesClassFilters(MonitoredMeetsRecord meet) {
    final app = FFAppState();
    if (meet.meetClasses.isEmpty) {
      return false;
    }
    final ageMatch =
        app.meetFilterShowAgeGroup && _containsClassToken(meet, 'age group');
    final seniorMatch =
        app.meetFilterShowSenior && _containsClassToken(meet, 'senior');
    final otherMatch = app.meetFilterShowOther && _isOtherClass(meet);
    return ageMatch || seniorMatch || otherMatch;
  }

  bool _anyMyListFilterOn(FFAppState app) =>
      app.meetFilterPendingEntries ||
      app.meetFilterEntered ||
      app.meetFilterNotGoing ||
      app.meetFilterRemindMe;

  /// Tune icon badge: any non-default filter (including showing Not going meets).
  bool _meetTuneFiltersNonDefault(FFAppState app) {
    if (app.meetsShowAllZones) {
      return true;
    }
    if (!app.meetFilterShowAgeGroup ||
        !app.meetFilterShowSenior ||
        !app.meetFilterShowOther) {
      return true;
    }
    if (_anyMyListFilterOn(app)) {
      return true;
    }
    if (app.meetShowNotGoingInList) {
      return true;
    }
    if (app.meetShowPastEvents) {
      return true;
    }
    return false;
  }

  bool _isMyMeet(
    MonitoredMeetsRecord m,
    MeetPreferencesRecord? pref,
  ) {
    if (pref == null) {
      return false;
    }
    if (pref.status == MeetPreferenceStatus.entered) {
      return true;
    }
    if (pref.status == MeetPreferenceStatus.newStatus) {
      return true;
    }
    return MeetListQuickFilter.meetNeedsAction(m, pref) ||
        pref.status == MeetPreferenceStatus.needEntry;
  }

  int _myMeetUrgencyRank(
    MonitoredMeetsRecord m,
    MeetPreferencesRecord? pref,
  ) {
    if (MeetListQuickFilter.meetNeedsAction(m, pref)) {
      return 0;
    }
    if (pref?.status == MeetPreferenceStatus.newStatus) {
      return 1;
    }
    if (pref?.status == MeetPreferenceStatus.entered) {
      return 2;
    }
    if (MeetListQuickFilter.isNotGoingCategory(pref)) {
      return 3;
    }
    return 4;
  }

  DateTime _sortDate(MonitoredMeetsRecord m) =>
      m.startTime ?? m.endTime ?? DateTime.fromMillisecondsSinceEpoch(0);

  String _searchText() => _allMeetsSearchController.text.trim().toLowerCase();

  bool _matchesSearch(MonitoredMeetsRecord m) {
    final q = _searchText();
    if (q.isEmpty) {
      return true;
    }
    final name = m.name.toLowerCase();
    final location = m.location.toLowerCase();
    final zone = m.meetZone.toLowerCase();
    return name.contains(q) || location.contains(q) || zone.contains(q);
  }

  bool _matchesNotGoingVisibility(
    MonitoredMeetsRecord m,
    Map<String, MeetPreferencesRecord> prefs,
    FFAppState app,
  ) {
    if (app.meetShowNotGoingInList || app.meetFilterNotGoing) {
      return true;
    }
    return !MeetListQuickFilter.isNotGoingCategory(prefs[m.reference.id]);
  }

  /// Returns false for past meets unless the user has enabled "Show Past Meets".
  /// A meet is past when its end date (or start date) is before today's midnight.
  bool _matchesPastFilter(MonitoredMeetsRecord m, FFAppState app) {
    if (app.meetShowPastEvents) {
      return true;
    }
    final today = DateTime.now();
    final midnight = DateTime(today.year, today.month, today.day);
    final meetEnd = m.endDate ?? m.startDate;
    if (meetEnd == null) {
      return true;
    }
    return !meetEnd.isBefore(midnight);
  }

  /// Optional my-list filters from the tune menu (pending / entered / not going / remind).
  /// When several are on, a meet passes if it matches any selected category.
  bool _matchesMyMeetListFilters(
    MonitoredMeetsRecord m,
    Map<String, MeetPreferencesRecord> prefs,
    FFAppState app,
  ) {
    if (!_anyMyListFilterOn(app)) {
      return true;
    }
    final pref = prefs[m.reference.id];
    final hasPreference = pref != null;
    final status = pref?.status ?? MeetPreferenceStatus.newStatus;
    final hasAlert = pref?.hasAlert ?? false;

    final pendingEntries =
        hasPreference && status == MeetPreferenceStatus.needEntry;
    final entered = hasPreference && status == MeetPreferenceStatus.entered;
    final notGoing = MeetListQuickFilter.isNotGoingCategory(pref);
    final remindMe =
        hasPreference && status == MeetPreferenceStatus.needEntry && hasAlert;

    if (app.meetFilterPendingEntries && pendingEntries) {
      return true;
    }
    if (app.meetFilterEntered && entered) {
      return true;
    }
    if (app.meetFilterNotGoing && notGoing) {
      return true;
    }
    if (app.meetFilterRemindMe && remindMe) {
      return true;
    }
    return false;
  }

  void _setClassFilter(
    BuildContext snackContext, {
    required bool nextValue,
    required bool currentValue,
    required void Function(FFAppState app, bool v) apply,
  }) {
    if (nextValue == currentValue) {
      return;
    }
    final app = FFAppState();
    final activeCount = (app.meetFilterShowAgeGroup ? 1 : 0) +
        (app.meetFilterShowSenior ? 1 : 0) +
        (app.meetFilterShowOther ? 1 : 0);
    if (!nextValue && activeCount <= 1) {
      ScaffoldMessenger.of(snackContext).showSnackBar(
        const SnackBar(
          content: Text('Keep at least one class filter active.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    app.update(() => apply(app, nextValue));
    app.persistMeetUiState();
  }

  Widget _buildPrimarySegmentedControl() {
    Widget segment({
      required String label,
      required _MeetPrimaryView view,
    }) {
      final selected = _primaryView == view;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _primaryView = view),
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
              style: GoogleFonts.sora(
                fontSize: 13.0,
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
        border: Border.all(
          color: SwimUiTokens.borderSegmentTrack,
        ),
      ),
      child: Row(
        children: [
          segment(label: 'My Meets', view: _MeetPrimaryView.myMeets),
          const SizedBox(width: 4.0),
          segment(label: 'All Meets', view: _MeetPrimaryView.allMeets),
        ],
      ),
    );
  }

  Widget _buildZoneAndFiltersRow(BuildContext context, FFAppState app) {
    final filtersOn = _meetTuneFiltersNonDefault(app);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: !_meetBannerReady
              ? const SizedBox(
                  height: 20.0,
                  width: 20.0,
                  child: CircularProgressIndicator(strokeWidth: 2.0),
                )
              : Text.rich(
                  TextSpan(
                    style: GoogleFonts.sora(
                      fontSize: 13.0,
                      fontWeight: FontWeight.w600,
                      color: SwimUiTokens.textBannerTitle,
                    ),
                    children: [
                      TextSpan(
                        text: 'Zone: ',
                        style: GoogleFonts.sora(
                          fontSize: 13.0,
                          fontWeight: FontWeight.w500,
                          color: SwimUiTokens.textMuted,
                        ),
                      ),
                      TextSpan(text: _meetsScopeHeadline(app)),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
        ),
        const SizedBox(width: 8.0),
        Stack(
          clipBehavior: Clip.none,
          children: [
            OutlinedButton.icon(
              onPressed: () => _openMeetRefineSheet(context),
              icon: Icon(
                Icons.tune_rounded,
                size: 16.0,
                color: SwimUiTokens.accentBlue,
              ),
              label: Text(
                filtersOn ? 'Filters on' : 'Filters',
                style: GoogleFonts.sora(
                  fontSize: 12.0,
                  fontWeight: FontWeight.w600,
                  color: SwimUiTokens.accentBlue,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: filtersOn
                      ? SwimUiTokens.accentBlue
                      : SwimUiTokens.borderSubtle,
                  width: 1.0,
                ),
                backgroundColor: filtersOn
                    ? SwimUiTokens.accentBlue.withValues(alpha: 0.06)
                    : SwimUiTokens.surfaceCard,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(SwimUiTokens.radiusSm),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10.0, vertical: 7.0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
            if (filtersOn)
              Positioned(
                top: -3.0,
                right: -3.0,
                child: Container(
                  width: 9.0,
                  height: 9.0,
                  decoration: BoxDecoration(
                    color: SwimUiTokens.accentBlue,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: SwimUiTokens.surfaceCanvas,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildAllMeetsSearchRow() {
    return Container(
      height: 38.0,
      decoration: BoxDecoration(
        color: SwimUiTokens.surfaceCard,
        borderRadius: BorderRadius.circular(SwimUiTokens.radiusMd),
        border: Border.all(
          color: SwimUiTokens.borderSubtle,
          width: 1.0,
        ),
      ),
      child: TextField(
        controller: _allMeetsSearchController,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          hintText: 'Search meets by name, location, zone',
          hintStyle: GoogleFonts.sora(
            fontSize: 12.5,
            color: SwimUiTokens.textMuted,
          ),
          prefixIcon: Icon(Icons.search_rounded,
              color: SwimUiTokens.textMuted, size: 18.0),
          suffixIcon: _allMeetsSearchController.text.isEmpty
              ? null
              : IconButton(
                  icon: Icon(Icons.close_rounded,
                      color: SwimUiTokens.textMuted, size: 18.0),
                  onPressed: () {
                    _allMeetsSearchController.clear();
                    setState(() {});
                  },
                ),
        ),
        style: GoogleFonts.sora(
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          color: SwimUiTokens.textBannerTitle,
        ),
      ),
    );
  }

  Color _myMeetSectionSurface(_MyMeetSectionTone tone) {
    switch (tone) {
      case _MyMeetSectionTone.needsAction:
        return SwimUiTokens.sectionNeedsAction;
      case _MyMeetSectionTone.entered:
        return SwimUiTokens.sectionEntered;
      case _MyMeetSectionTone.skipped:
        return SwimUiTokens.sectionSkipped;
      case _MyMeetSectionTone.neutral:
        return SwimUiTokens.surfaceCard;
    }
  }

  /// One contextual line when a need-action meet has an entry deadline this calendar week.
  String? _deadlineThisWeekInsightLine(
    List<MonitoredMeetsRecord> needsAction,
    Map<String, MeetPreferencesRecord> prefs,
  ) {
    for (final m in needsAction) {
      if (!MeetListQuickFilter.entryDeadlineThisCalendarWeek(
        m,
        prefs[m.reference.id],
      )) {
        continue;
      }
      final d = MeetListQuickFilter.entryDeadline(m);
      if (d == null) {
        continue;
      }
      final name = m.name.trim();
      if (name.isEmpty) {
        continue;
      }
      return 'Deadline this week: $name closes ${dateTimeFormat('MMM d', d)}';
    }
    return null;
  }

  void _sortNeedsActionByUrgencyThenDate(
    List<MonitoredMeetsRecord> list,
    Map<String, MeetPreferencesRecord> prefs,
  ) {
    int weekRank(MonitoredMeetsRecord m) {
      return MeetListQuickFilter.entryDeadlineThisCalendarWeek(
        m,
        prefs[m.reference.id],
      )
          ? 0
          : 1;
    }

    list.sort((a, b) {
      final rw = weekRank(a).compareTo(weekRank(b));
      if (rw != 0) {
        return rw;
      }
      return _sortDate(a).compareTo(_sortDate(b));
    });
  }

  Widget _myMeetsSummaryChip({
    required String label,
    required Color background,
    required Color border,
    required Color foreground,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999.0),
        border: Border.all(color: border, width: 1.0),
      ),
      child: Text(
        label,
        style: GoogleFonts.sora(
          fontSize: 12.0,
          fontWeight: FontWeight.w600,
          color: foreground,
          height: 1.2,
        ),
      ),
    );
  }

  List<Widget> _interleaveGroupedMeetRows(List<Widget> rows) {
    if (rows.isEmpty) {
      return const <Widget>[];
    }
    final out = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      out.add(rows[i]);
      if (i < rows.length - 1) {
        out.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5.0),
            child: Divider(
              height: 1.0,
              thickness: 1.0,
              color: SwimUiTokens.borderSubtle.withValues(alpha: 0.65),
            ),
          ),
        );
      }
    }
    return out;
  }

  Widget _buildMyMeetGroupedSection({
    required String title,
    required int count,
    required _MyMeetSectionTone tone,
    required List<Widget> meetRows,
    bool collapsible = false,
    bool expanded = true,
    VoidCallback? onToggleExpanded,
  }) {
    if (meetRows.isEmpty) {
      return const SizedBox.shrink();
    }
    final surface = _myMeetSectionSurface(tone);
    final showRows = !collapsible || expanded;
    final bottomPad = (collapsible && !expanded) ? 14.0 : 12.0;

    final titleStyle = GoogleFonts.sora(
      fontSize: 15.0,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.15,
      color: SwimUiTokens.textBannerTitle,
    );

    Widget sectionCountChip() {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
        decoration: BoxDecoration(
          color: SwimUiTokens.surfaceCanvasSchedule,
          borderRadius: BorderRadius.circular(999.0),
          border: Border.all(
            color: SwimUiTokens.borderSubtle,
            width: 0.5,
          ),
        ),
        child: Text(
          '$count',
          style: GoogleFonts.sora(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: SwimUiTokens.textFaint,
          ),
        ),
      );
    }

    final headerRow = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(title, style: titleStyle),
        ),
        sectionCountChip(),
        if (collapsible) ...[
          const SizedBox(width: 4.0),
          AnimatedRotation(
            turns: expanded ? 0.5 : 0.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 22.0,
              color: SwimUiTokens.textMuted,
            ),
          ),
        ],
      ],
    );

    final header = collapsible
        ? Semantics(
            button: true,
            expanded: expanded,
            label:
                '$title, $count ${count == 1 ? 'meet' : 'meets'}. ${expanded ? 'Collapse' : 'Expand'} section.',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onToggleExpanded,
                borderRadius: BorderRadius.circular(10.0),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: headerRow,
                ),
              ),
            ),
          )
        : headerRow;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24.0, 10.0, 24.0, 0.0),
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(SwimUiTokens.radiusSection),
          border: Border.all(
            color: SwimUiTokens.borderSection,
            width: 0.5,
          ),
          boxShadow: SwimUiTokens.shadowCardLift,
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(14.0, 14.0, 14.0, bottomPad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              if (showRows) ...[
                const SizedBox(height: 10.0),
                ..._interleaveGroupedMeetRows(meetRows),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Meets tab context line: zone-scoped vs all Pacific zones.
  String _meetsContextMessage(FFAppState app) {
    if (app.meetsShowAllZones) {
      return 'Showing Meets of All Pacific Swimming Zones';
    }
    final z = app.currentSwimmerZoneLabel.trim();
    if (z.isNotEmpty) {
      return 'Showing Meets of $z';
    }
    final meetsId = app.currentSwimmerZoneForMeets.trim();
    if (meetsId.isNotEmpty) {
      final human = pacificSwimmingBannerFallbackForGranularZone(meetsId);
      if (human.isNotEmpty) {
        return 'Showing Meets of $human';
      }
      return 'Showing Meets of $meetsId';
    }
    return 'Showing Meets of Pacific Swimming';
  }

  /// Shorter headline under the label (drops the repeated "Showing Meets of" prefix).
  String _meetsScopeHeadline(FFAppState app) {
    final full = _meetsContextMessage(app);
    const prefix = 'Showing Meets of ';
    if (full.startsWith(prefix)) {
      return full.substring(prefix.length);
    }
    return full;
  }

  Future<void> _openMeetRefineSheet(BuildContext pageContext) async {
    await showModalBottomSheet<void>(
      context: pageContext,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: ObsidianVoltTokens.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      builder: (sheetContext) {
        return _MeetRefineSheetContent(
          onMeetClassToggle: ({
            required bool nextValue,
            required bool currentValue,
            required void Function(FFAppState app, bool v) apply,
          }) {
            _setClassFilter(
              pageContext,
              nextValue: nextValue,
              currentValue: currentValue,
              apply: apply,
            );
          },
        );
      },
    );
  }

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => M02MeetModel());

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await refreshSwimmerAppState();
      } finally {
        if (mounted) {
          safeSetState(() => _meetBannerReady = true);
        }
      }
    });
  }

  @override
  void dispose() {
    _allMeetsSearchController.dispose();
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<FFAppState>();

    return ColoredBox(
      color: SwimUiTokens.surfaceCanvas,
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24.0, 8.0, 24.0, 0.0),
            child: _buildPrimarySegmentedControl(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24.0, 8.0, 24.0, 0.0),
            child: _buildZoneAndFiltersRow(context, app),
          ),
          Expanded(
            child: StreamBuilder<Map<String, MeetPreferencesRecord>>(
              stream: streamMeetPreferencesMap(currentUserUid),
              builder: (context, prefSnap) {
                final prefs =
                    prefSnap.data ?? <String, MeetPreferencesRecord>{};
                return StreamBuilder<List<MonitoredMeetsRecord>>(
                  stream: streamMonitoredMeetsForSwimmer(
                    zoneId: app.currentSwimmerZoneForMeets,
                    priorityHostGroup: app.currentSwimmerGroup,
                    showAll: app.meetsShowAllZones,
                    widePastWindow: true,
                  ),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                        child: SizedBox(
                          width: 50.0,
                          height: 50.0,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              SwimUiTokens.accentBlue,
                            ),
                          ),
                        ),
                      );
                    }

                    final filtered = snapshot.data!
                        .where(_matchesClassFilters)
                        .where((m) => _matchesSearch(m))
                        .where((m) => _matchesNotGoingVisibility(m, prefs, app))
                        .where((m) => _matchesPastFilter(m, app))
                        .where((m) => _matchesMyMeetListFilters(m, prefs, app))
                        .toList()
                      ..sort((a, b) => _sortDate(a).compareTo(_sortDate(b)));

                    if (_primaryView == _MeetPrimaryView.allMeets) {
                      if (filtered.isEmpty) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                  20.0, 10.0, 20.0, 2.0),
                              child: _buildAllMeetsSearchRow(),
                            ),
                            const SizedBox(height: 10.0),
                            Expanded(
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32.0,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.search_off_rounded,
                                        size: 40.0,
                                        color: SwimUiTokens.textFaint,
                                      ),
                                      const SizedBox(height: 12.0),
                                      Text(
                                        'No meets match',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.sora(
                                          fontSize: 16.0,
                                          fontWeight: FontWeight.w600,
                                          color: SwimUiTokens.textBannerTitle,
                                        ),
                                      ),
                                      const SizedBox(height: 6.0),
                                      Text(
                                        'Try another search, or open Filters to widen class or zone.',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.sora(
                                          fontSize: 13.0,
                                          fontWeight: FontWeight.w500,
                                          height: 1.35,
                                          color: SwimUiTokens.textMuted,
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
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                                20.0, 10.0, 20.0, 2.0),
                            child: _buildAllMeetsSearchRow(),
                          ),
                          const SizedBox(height: 6.0),
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                20.0,
                                6.0,
                                20.0,
                                24.0,
                              ),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final meet = filtered[index];
                                return M02MeetEnteredWidget(
                                  key: Key(
                                      'all_meet_${meet.reference.id}_$index'),
                                  meetDoc: meet,
                                  preference: prefs[meet.reference.id],
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    }

                    final myMeets = filtered
                        .where((m) => _isMyMeet(m, prefs[m.reference.id]))
                        .toList()
                      ..sort((a, b) {
                        final rankA =
                            _myMeetUrgencyRank(a, prefs[a.reference.id]);
                        final rankB =
                            _myMeetUrgencyRank(b, prefs[b.reference.id]);
                        if (rankA != rankB) {
                          return rankA.compareTo(rankB);
                        }
                        return _sortDate(a).compareTo(_sortDate(b));
                      });

                    final needsAction = myMeets
                        .where((m) => MeetListQuickFilter.meetNeedsAction(
                              m,
                              prefs[m.reference.id],
                            ))
                        .toList();
                    _sortNeedsActionByUrgencyThenDate(needsAction, prefs);
                    final entered = myMeets
                        .where((m) =>
                            prefs[m.reference.id]?.status ==
                            MeetPreferenceStatus.entered)
                        .toList()
                      ..sort((a, b) => _sortDate(a).compareTo(_sortDate(b)));
                    final newToReview = myMeets
                        .where((m) =>
                            prefs[m.reference.id]?.status ==
                            MeetPreferenceStatus.newStatus)
                        .toList();
                    final other = myMeets
                        .where((m) =>
                            !needsAction.contains(m) &&
                            !entered.contains(m) &&
                            !newToReview.contains(m))
                        .toList();

                    var deadlineWeekCount = 0;
                    for (final m in needsAction) {
                      if (MeetListQuickFilter.entryDeadlineThisCalendarWeek(
                        m,
                        prefs[m.reference.id],
                      )) {
                        deadlineWeekCount++;
                      }
                    }
                    final anyDeadlineUrgent48h = needsAction.any(
                      MeetListQuickFilter.entryDeadlineWithin48Hours,
                    );
                    final deadlineInsight =
                        _deadlineThisWeekInsightLine(needsAction, prefs);

                    if (myMeets.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            32.0,
                            24.0,
                            32.0,
                            32.0,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.event_available_outlined,
                                size: 44.0,
                                color: SwimUiTokens.textFaint,
                              ),
                              const SizedBox(height: 14.0),
                              Text(
                                'My Meets is empty',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.sora(
                                  fontSize: 17.0,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.15,
                                  color: SwimUiTokens.textBannerTitle,
                                ),
                              ),
                              const SizedBox(height: 8.0),
                              Text(
                                'Switch to All Meets to browse, then follow or enter meets — they will appear here.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.sora(
                                  fontSize: 13.5,
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

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(0.0, 2.0, 0.0, 28.0),
                      children: [
                        if (needsAction.isNotEmpty ||
                            deadlineWeekCount > 0) ...[
                          Padding(
                            padding:
                                const EdgeInsets.fromLTRB(24.0, 4.0, 24.0, 0.0),
                            child: Wrap(
                              spacing: 8.0,
                              runSpacing: 8.0,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (needsAction.isNotEmpty)
                                  _myMeetsSummaryChip(
                                    label: '${needsAction.length} Need Action',
                                    background: ObsidianVoltTokens.bgSurface,
                                    border: ObsidianVoltTokens.borderDefault,
                                    foreground: ObsidianVoltTokens.textPrimary,
                                  ),
                                if (deadlineWeekCount > 0)
                                  Tooltip(
                                    message: anyDeadlineUrgent48h
                                        ? 'Summary only. Meets with a deadline in the next 48 hours are marked below.'
                                        : 'Summary only — not a filter. Meets that count show “Due this week · closes …” on the row.',
                                    child: _myMeetsSummaryChip(
                                      label: deadlineWeekCount == 1
                                          ? '1 deadline this week'
                                          : '$deadlineWeekCount deadlines this week',
                                      background: anyDeadlineUrgent48h
                                          ? ObsidianVoltTokens.dangerCardBg
                                          : ObsidianVoltTokens.urgentCardBg,
                                      border: anyDeadlineUrgent48h
                                          ? ObsidianVoltTokens.dangerCardBorder
                                          : ObsidianVoltTokens.urgentCardBorder,
                                      foreground: anyDeadlineUrgent48h
                                          ? ObsidianVoltTokens.dangerCta
                                          : ObsidianVoltTokens.urgentCta,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                        if (deadlineInsight != null) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              20.0,
                              8.0,
                              20.0,
                              0.0,
                            ),
                            child: Text(
                              deadlineInsight,
                              style: GoogleFonts.sora(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                height: 1.35,
                                color: SwimUiTokens.textMuted,
                              ),
                            ),
                          ),
                        ],
                        _buildMyMeetGroupedSection(
                          title: 'New to review',
                          count: newToReview.length,
                          tone: _MyMeetSectionTone.neutral,
                          meetRows: newToReview.asMap().entries.map((entry) {
                            final meet = entry.value;
                            return M02MeetEnteredWidget(
                              key: Key(
                                  'my_new_${meet.reference.id}_${entry.key}'),
                              meetDoc: meet,
                              preference: prefs[meet.reference.id],
                              groupedInSection: true,
                            );
                          }).toList(),
                        ),
                        _buildMyMeetGroupedSection(
                          title: 'Needs Action',
                          count: needsAction.length,
                          tone: _MyMeetSectionTone.needsAction,
                          meetRows: needsAction.asMap().entries.map((entry) {
                            final meet = entry.value;
                            return M02MeetEnteredWidget(
                              key: Key(
                                  'my_need_${meet.reference.id}_${entry.key}'),
                              meetDoc: meet,
                              preference: prefs[meet.reference.id],
                              groupedInSection: true,
                            );
                          }).toList(),
                        ),
                        _buildMyMeetGroupedSection(
                          title: 'Already Entered',
                          count: entered.length,
                          tone: _MyMeetSectionTone.entered,
                          meetRows: entered.asMap().entries.map((entry) {
                            final meet = entry.value;
                            return M02MeetEnteredWidget(
                              key: Key(
                                  'my_entered_${meet.reference.id}_${entry.key}'),
                              meetDoc: meet,
                              preference: prefs[meet.reference.id],
                              groupedInSection: true,
                            );
                          }).toList(),
                        ),
                        _buildMyMeetGroupedSection(
                          title: 'Other My Meets',
                          count: other.length,
                          tone: _MyMeetSectionTone.neutral,
                          meetRows: other.asMap().entries.map((entry) {
                            final meet = entry.value;
                            return M02MeetEnteredWidget(
                              key: Key(
                                  'my_other_${meet.reference.id}_${entry.key}'),
                              meetDoc: meet,
                              preference: prefs[meet.reference.id],
                              groupedInSection: true,
                            );
                          }).toList(),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

typedef _MeetClassToggle = void Function({
  required bool nextValue,
  required bool currentValue,
  required void Function(FFAppState app, bool v) apply,
});

/// Full-screen style refine sheet: Location, Meet Type chips, collapsible Status, Advanced.
class _MeetRefineSheetContent extends StatelessWidget {
  const _MeetRefineSheetContent({
    required this.onMeetClassToggle,
  });

  final _MeetClassToggle onMeetClassToggle;

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
      child: Text(
        text,
        style: GoogleFonts.sora(
          fontSize: 12.0,
          fontWeight: FontWeight.w600,
          color: SwimUiTokens.textMuted,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _locationTile({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0),
        child: Row(
          children: [
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: selected
                  ? SwimUiTokens.accentBlueSheet
                  : SwimUiTokens.borderSubtle,
              size: 22.0,
            ),
            const SizedBox(width: 12.0),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.sora(
                  fontSize: 14.0,
                  fontWeight: FontWeight.w500,
                  color: SwimUiTokens.textBannerTitle,
                ),
              ),
            ),
            if (selected)
              Icon(Icons.check_rounded,
                  color: SwimUiTokens.accentBlueSheet, size: 22.0),
          ],
        ),
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999.0),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 7.0),
            decoration: BoxDecoration(
              color: selected
                  ? ObsidianVoltTokens.tabSelectedBg
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(999.0),
              border: Border.all(
                color: selected
                    ? ObsidianVoltTokens.borderDefault
                    : ObsidianVoltTokens.borderSubtle,
                width: 1.0,
              ),
            ),
            child: Text(
              label,
              style: GoogleFonts.sora(
                fontSize: 12.0,
                fontWeight: FontWeight.w600,
                color: selected
                    ? ObsidianVoltTokens.textPrimary
                    : ObsidianVoltTokens.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _chipScroller(List<Widget> chips) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: chips),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<FFAppState>();
    final line = FlutterFlowTheme.of(context).lineColor;

    void persist() => app.persistMeetUiState();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24.0,
        10.0,
        24.0,
        MediaQuery.paddingOf(context).bottom + 16.0,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              child: Container(
                width: 42.0,
                height: 4.0,
                decoration: BoxDecoration(
                  color: ObsidianVoltTokens.borderMuted,
                  borderRadius: BorderRadius.circular(999.0),
                ),
              ),
            ),
            const SizedBox(height: 10.0),
            SizedBox(
              height: 44.0,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: SwimUiTokens.textMuted,
                        size: 26.0,
                      ),
                      onPressed: () => Navigator.pop(context),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  Text(
                    'Refine',
                    style: GoogleFonts.sora(
                      fontSize: 17.0,
                      fontWeight: FontWeight.w700,
                      color: SwimUiTokens.textBannerTitle,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        app.update(() {
                          app.meetsShowAllZones = false;
                          app.meetFilterShowAgeGroup = true;
                          app.meetFilterShowSenior = true;
                          app.meetFilterShowOther = true;
                          app.meetFilterPendingEntries = false;
                          app.meetFilterEntered = false;
                          app.meetFilterNotGoing = false;
                          app.meetFilterRemindMe = false;
                          app.meetShowNotGoingInList = false;
                          app.meetShowPastEvents = false;
                          app.meetListChipFilter = 0;
                        });
                        persist();
                      },
                      child: Text(
                        'Reset',
                        style: GoogleFonts.sora(
                          fontSize: 14.0,
                          fontWeight: FontWeight.w600,
                          color: SwimUiTokens.accentBlueSheet,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _sectionLabel('Location'),
            _locationTile(
              label: 'Current Zone',
              selected: !app.meetsShowAllZones,
              onTap: () {
                app.update(() => app.meetsShowAllZones = false);
                persist();
              },
            ),
            _locationTile(
              label: 'All Zones',
              selected: app.meetsShowAllZones,
              onTap: () {
                app.update(() => app.meetsShowAllZones = true);
                persist();
              },
            ),
            Divider(height: 24.0, thickness: 1.0, color: line),
            _sectionLabel('Meet Type'),
            _chipScroller([
              _filterChip(
                label: 'Age Group',
                selected: app.meetFilterShowAgeGroup,
                onTap: () => onMeetClassToggle(
                  nextValue: !app.meetFilterShowAgeGroup,
                  currentValue: app.meetFilterShowAgeGroup,
                  apply: (a, x) => a.meetFilterShowAgeGroup = x,
                ),
              ),
              _filterChip(
                label: 'Senior',
                selected: app.meetFilterShowSenior,
                onTap: () => onMeetClassToggle(
                  nextValue: !app.meetFilterShowSenior,
                  currentValue: app.meetFilterShowSenior,
                  apply: (a, x) => a.meetFilterShowSenior = x,
                ),
              ),
              _filterChip(
                label: 'Other',
                selected: app.meetFilterShowOther,
                onTap: () => onMeetClassToggle(
                  nextValue: !app.meetFilterShowOther,
                  currentValue: app.meetFilterShowOther,
                  apply: (a, x) => a.meetFilterShowOther = x,
                ),
              ),
            ]),
            const SizedBox(height: 6.0),
            Divider(height: 24.0, thickness: 1.0, color: line),
            Theme(
              data: Theme.of(context).copyWith(
                dividerColor: Colors.transparent,
                splashColor:
                    SwimUiTokens.accentBlueSheet.withValues(alpha: 0.08),
              ),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                initiallyExpanded: true,
                title: Text(
                  'Status',
                  style: GoogleFonts.sora(
                    fontSize: 12.0,
                    fontWeight: FontWeight.w600,
                    color: SwimUiTokens.textMuted,
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: _chipScroller([
                      _filterChip(
                        label: 'Pending',
                        selected: app.meetFilterPendingEntries,
                        onTap: () {
                          app.update(
                            () => app.meetFilterPendingEntries =
                                !app.meetFilterPendingEntries,
                          );
                          persist();
                        },
                      ),
                      _filterChip(
                        label: 'Entered',
                        selected: app.meetFilterEntered,
                        onTap: () {
                          app.update(
                            () =>
                                app.meetFilterEntered = !app.meetFilterEntered,
                          );
                          persist();
                        },
                      ),
                      _filterChip(
                        label: 'Not Going',
                        selected: app.meetFilterNotGoing,
                        onTap: () {
                          app.update(
                            () => app.meetFilterNotGoing =
                                !app.meetFilterNotGoing,
                          );
                          persist();
                        },
                      ),
                      _filterChip(
                        label: 'Remind Me',
                        selected: app.meetFilterRemindMe,
                        onTap: () {
                          app.update(
                            () => app.meetFilterRemindMe =
                                !app.meetFilterRemindMe,
                          );
                          persist();
                        },
                      ),
                    ]),
                  ),
                ],
              ),
            ),
            Divider(height: 24.0, thickness: 1.0, color: line),
            _sectionLabel('Advanced'),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Hide Not Going Meets',
                style: GoogleFonts.sora(
                  fontSize: 14.0,
                  fontWeight: FontWeight.w500,
                  color: SwimUiTokens.textBannerTitle,
                ),
              ),
              value: !app.meetShowNotGoingInList,
              onChanged: (v) {
                if (v == null) {
                  return;
                }
                app.update(() => app.meetShowNotGoingInList = !v);
                persist();
              },
              activeColor: SwimUiTokens.accentBlueSheet,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Show Past Meets',
                style: GoogleFonts.sora(
                  fontSize: 14.0,
                  fontWeight: FontWeight.w500,
                  color: SwimUiTokens.textBannerTitle,
                ),
              ),
              value: app.meetShowPastEvents,
              onChanged: (v) {
                if (v == null) {
                  return;
                }
                app.update(() => app.meetShowPastEvents = v);
                persist();
              },
              activeColor: SwimUiTokens.accentBlueSheet,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 18.0),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: SwimUiTokens.accentBlueSheet,
                  foregroundColor: ObsidianVoltTokens.bgBase,
                  padding: const EdgeInsets.symmetric(vertical: 14.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  elevation: 0.0,
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'View Results',
                  style: GoogleFonts.sora(
                    fontSize: 15.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
