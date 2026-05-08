import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/meet_preferences_api.dart';
import '/backend/schema/meet_preferences_record.dart';
import '/components/m02_meet_entered/m02_meet_entered_widget.dart';
import '/custom_code/actions/refresh_swimmer_app_state.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/theme/lavender_indigo_tokens.dart';
import '/theme/swim_design_tokens.dart';
import '/theme/swim_ui_tokens.dart';
import '/theme/obsidian_volt_tokens.dart';
import '/widgets/swim_ui_kit.dart';
import 'meet_option_b_ui.dart';
import 'meet_overview_metrics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'meet_list_quick_filter.dart';
import 'm02_meet_model.dart';
export 'm02_meet_model.dart';

enum _MeetPrimaryView { myMeets, allMeets }

class M02MeetWidget extends StatefulWidget {
  const M02MeetWidget({super.key});

  @override
  State<M02MeetWidget> createState() => _M02MeetWidgetState();
}

class _M02MeetWidgetState extends State<M02MeetWidget> {
  late M02MeetModel _model;

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
    return MeetPillTabs(
      selectedIndex:
          _primaryView == _MeetPrimaryView.myMeets ? 0 : 1,
      onChanged: (i) => setState(() {
        _primaryView =
            i == 0 ? _MeetPrimaryView.myMeets : _MeetPrimaryView.allMeets;
      }),
    );
  }

  Widget _buildZoneAndFiltersRow(BuildContext context, FFAppState app) {
    final filtersOn = _meetTuneFiltersNonDefault(app);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text.rich(
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
                Icons.filter_list_rounded,
                size: 18.0,
                color: LavenderIndigoTokens.primary,
              ),
              label: Text(
                filtersOn ? 'Filters on' : 'Filters',
                style: GoogleFonts.sora(
                  fontSize: 12.0,
                  fontWeight: FontWeight.w700,
                  color: LavenderIndigoTokens.primary,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: filtersOn
                      ? LavenderIndigoTokens.primary
                          .withValues(alpha: 0.5)
                      : SwimDsTokens.borderSoft,
                  width: 1.0,
                ),
                backgroundColor: filtersOn
                    ? LavenderIndigoTokens.primarySoft.withValues(alpha: 0.4)
                    : SwimDsTokens.cardBackground,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(SwimDsTokens.pillRadius),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
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
                    color: SwimDsTokens.dangerCoral,
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
      height: 46.0,
      decoration: BoxDecoration(
        color: SwimDsTokens.cardBackground,
        borderRadius: BorderRadius.circular(SwimDsTokens.cardRadius),
        border: Border.all(color: SwimDsTokens.borderSoft, width: 1.0),
        boxShadow: SwimDsTokens.cardShadowSoft,
      ),
      child: TextField(
        controller: _allMeetsSearchController,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          hintText: 'Search meets by name, location, zone',
          hintStyle: GoogleFonts.sora(
            fontSize: 13,
            color: SwimUiTokens.textMuted,
          ),
          prefixIcon: Icon(Icons.search_rounded,
              color: SwimUiTokens.textMuted, size: 22.0),
          suffixIcon: _allMeetsSearchController.text.isEmpty
              ? null
              : IconButton(
                  icon: Icon(Icons.close_rounded,
                      color: SwimUiTokens.textMuted, size: 20.0),
                  onPressed: () {
                    _allMeetsSearchController.clear();
                    setState(() {});
                  },
                ),
        ),
        style: GoogleFonts.sora(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: SwimUiTokens.textBannerTitle,
        ),
      ),
    );
  }

  /// Upcoming meets the parent has not decided on (new / no preference).
  int _undecidedUpcomingMeetCount(
    List<MonitoredMeetsRecord> meets,
    Map<String, MeetPreferencesRecord> prefs,
  ) {
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    var c = 0;
    for (final m in meets) {
      final p = prefs[m.reference.id];
      final undecided = p == null || p.status == MeetPreferenceStatus.newStatus;
      if (!undecided) continue;
      final sd = m.startDate ?? m.startTime;
      if (sd != null && DateTime(sd.year, sd.month, sd.day).isBefore(today)) {
        continue;
      }
      c++;
    }
    return c;
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
      await refreshSwimmerAppState();
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
    final reduceMotion = MediaQuery.disableAnimationsOf(context) ||
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.reduceMotion;

    return ColoredBox(
      color: SwimUiTokens.surfaceCanvas,
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              SwimDsTokens.pageHorizontalPadding,
              SwimDsTokens.headerToTabsGap - 12,
              SwimDsTokens.pageHorizontalPadding,
              0,
            ),
            child: _buildPrimarySegmentedControl(),
          )
              .let((w) => reduceMotion
                  ? w
                  : w
                      .animate()
                      .fadeIn(duration: 320.ms, curve: Curves.easeOutCubic)
                      .slideY(begin: 0.06, duration: 320.ms, curve: Curves.easeOutCubic)),
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

                    final today = DateTime.now();
                    final midnight =
                        DateTime(today.year, today.month, today.day);
                    final hasPastMeetsInFeed = snapshot.data!.any((m) {
                      final e = m.endDate ?? m.startDate;
                      return e != null && e.isBefore(midnight);
                    });

                    final overviewMeets = _primaryView ==
                            _MeetPrimaryView.myMeets
                        ? filtered
                            .where(
                                (m) => _isMyMeet(m, prefs[m.reference.id]))
                            .toList()
                        : filtered;
                    final counts = computeMeetOverviewCounts(
                      meets: overviewMeets,
                      prefs: prefs,
                    );

                    final overviewBlock = Padding(
                      padding: const EdgeInsets.fromLTRB(20.0, 4.0, 20.0, 0.0),
                      child: MeetOverviewGradientCard(counts: counts),
                    ).let((w) => reduceMotion
                        ? w
                        : w
                            .animate()
                            .fadeIn(delay: 80.ms, duration: 360.ms, curve: Curves.easeOutCubic)
                            .slideY(begin: 0.06, delay: 80.ms, duration: 360.ms, curve: Curves.easeOutCubic));

                    final zoneFilters = Padding(
                      padding: EdgeInsets.fromLTRB(
                        SwimDsTokens.pageHorizontalPadding,
                        12.0,
                        SwimDsTokens.pageHorizontalPadding,
                        0,
                      ),
                      child: _buildZoneAndFiltersRow(context, app),
                    );

                    if (_primaryView == _MeetPrimaryView.allMeets) {
                      if (filtered.isEmpty) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            overviewBlock,
                            zoneFilters,
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                  20.0, 12.0, 20.0, 2.0),
                              child: _buildAllMeetsSearchRow(),
                            ),
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
                                        'No meets found',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.sora(
                                          fontSize: 16.0,
                                          fontWeight: FontWeight.w600,
                                          color: SwimUiTokens.textBannerTitle,
                                        ),
                                      ),
                                      const SizedBox(height: 6.0),
                                      Text(
                                        'Try changing your filters or check back later.',
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
                          overviewBlock,
                          zoneFilters,
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                                20.0, 12.0, 20.0, 2.0),
                            child: _buildAllMeetsSearchRow(),
                          ),
                          const SizedBox(height: 6.0),
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                0.0,
                                4.0,
                                0.0,
                                28.0,
                              ),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final meet = filtered[index];
                                return M02MeetEnteredWidget(
                                  key: Key(
                                      'all_meet_${meet.reference.id}_$index'),
                                  meetDoc: meet,
                                  preference: prefs[meet.reference.id],
                                  listStyleOptionB: true,
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
                    final deadlineInsight =
                        _deadlineThisWeekInsightLine(needsAction, prefs);
                    final undecidedUpcoming =
                        _undecidedUpcomingMeetCount(filtered, prefs);

                    if (myMeets.isEmpty) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          overviewBlock,
                          zoneFilters,
                          Expanded(
                            child: Center(
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  SwimDsTokens.pageHorizontalPadding,
                                  16.0,
                                  SwimDsTokens.pageHorizontalPadding,
                                  32.0,
                                ),
                                child: EmptyStateCard(
                                  title: 'No meets selected yet',
                                  message:
                                      'Review upcoming meets and decide which ones your swimmer will attend.',
                                  icon: Icons.pool_outlined,
                                  ctaLabel: 'Browse All Meets',
                                  onCta: () => setState(
                                    () => _primaryView =
                                        _MeetPrimaryView.allMeets,
                                  ),
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
                        overviewBlock,
                        zoneFilters,
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.only(bottom: 28.0),
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    20.0, 14.0, 20.0, 6.0),
                                child: Text(
                                  'UPCOMING MEETS',
                                  style: GoogleFonts.sora(
                                    fontSize: 11.0,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.1,
                                    color: SwimUiTokens.textMuted,
                                  ),
                                ),
                              ),
                              if (deadlineInsight != null)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                      20.0, 0.0, 20.0, 8.0),
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
                              ...myMeets.asMap().entries.map((entry) {
                                final meet = entry.value;
                                final i = entry.key;
                                return M02MeetEnteredWidget(
                                  key: Key(
                                      'my_flat_${meet.reference.id}_$i'),
                                  meetDoc: meet,
                                  preference: prefs[meet.reference.id],
                                  listStyleOptionB: true,
                                );
                              }),
                              if (hasPastMeetsInFeed &&
                                  !app.meetShowPastEvents)
                                MeetViewPastRow(
                                  onTap: () {
                                    app.update(
                                        () => app.meetShowPastEvents = true);
                                    app.persistMeetUiState();
                                  },
                                ),
                              MeetAgentSuggestionCard(
                                undecidedCount: undecidedUpcoming,
                                onReview: () => setState(
                                  () => _primaryView =
                                      _MeetPrimaryView.allMeets,
                                ),
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
          ),
        ],
      ),
    );
  }
}

extension _WidgetLetX on Widget {
  Widget let(Widget Function(Widget w) fn) => fn(this);
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
