import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/meet_preferences_api.dart';
import '/backend/schema/meet_preferences_record.dart';
import '/components/m02_meet_entered/m02_meet_entered_widget.dart';
import '/custom_code/actions/refresh_swimmer_app_state.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'meet_list_quick_filter.dart';
import 'm02_meet_model.dart';
export 'm02_meet_model.dart';

enum _MeetQuickFilter { none, deadlineThisWeek }

class M02MeetWidget extends StatefulWidget {
  const M02MeetWidget({super.key});

  @override
  State<M02MeetWidget> createState() => _M02MeetWidgetState();
}

class _M02MeetWidgetState extends State<M02MeetWidget> {
  late M02MeetModel _model;

  bool _meetBannerReady = false;
  _MeetQuickFilter _meetQuickFilter = _MeetQuickFilter.none;

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

  static DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// 0 Past, 1 Live, 2 Upcoming.
  bool _meetMatchesTimeSegment(MonitoredMeetsRecord m, int seg) {
    final today = _dayOnly(DateTime.now());
    final s = m.startTime;
    final e = m.endTime ?? m.startTime;
    if (s == null && e == null) {
      return seg == 1;
    }
    final sd = s != null ? _dayOnly(s) : _dayOnly(e!);
    final ed = e != null ? _dayOnly(e) : sd;
    if (seg == 2) {
      return sd.isAfter(today);
    }
    if (seg == 0) {
      return ed.isBefore(today);
    }
    return !sd.isAfter(today) && !ed.isBefore(today);
  }

  bool _anyMyListFilterOn(FFAppState app) =>
      app.meetFilterPendingEntries ||
      app.meetFilterEntered ||
      app.meetFilterNotGoing ||
      app.meetFilterRemindMe;

  bool _anyQuickFilterOn() => _meetQuickFilter != _MeetQuickFilter.none;

  bool _anyMyListOrQuickFilterOn(FFAppState app) =>
      _anyMyListFilterOn(app) ||
      _anyQuickFilterOn() ||
      app.meetListChipFilter != 0;

  /// Hide Not going meets unless user opted in or the list filter is "Not going only".
  bool _passesNotGoingListVisibility(
    MonitoredMeetsRecord m,
    Map<String, MeetPreferencesRecord> prefs,
    FFAppState app,
  ) {
    if (app.meetShowNotGoingInList || app.meetFilterNotGoing) {
      return true;
    }
    return !MeetListQuickFilter.isNotGoingCategory(prefs[m.reference.id]);
  }

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
    if (app.meetListChipFilter != 0) {
      return true;
    }
    return false;
  }

  /// After class / time / tune filters: apply default Not-going hiding and list chips.
  List<MonitoredMeetsRecord> _applyNotGoingVisibilityAndChips(
    List<MonitoredMeetsRecord> base,
    Map<String, MeetPreferencesRecord> prefs,
    FFAppState app,
  ) {
    switch (app.meetListChipFilter) {
      case 3:
        return base
            .where(
              (m) => MeetListQuickFilter.isNotGoingCategory(
                prefs[m.reference.id],
              ),
            )
            .toList();
      case 1:
        return base
            .where((m) => _passesNotGoingListVisibility(m, prefs, app))
            .where(
              (m) => MeetListQuickFilter.meetNeedsAction(
                m,
                prefs[m.reference.id],
              ),
            )
            .toList();
      case 2:
        return base
            .where((m) => _passesNotGoingListVisibility(m, prefs, app))
            .where(
              (m) =>
                  prefs[m.reference.id]?.status ==
                  MeetPreferenceStatus.entered,
            )
            .toList();
      default:
        return base
            .where((m) => _passesNotGoingListVisibility(m, prefs, app))
            .toList();
    }
  }

  Widget _buildMeetListChipStrip(BuildContext context, FFAppState app) {
    Widget chip(String label, int index) {
      final selected = app.meetListChipFilter == index;
      return Padding(
        padding: const EdgeInsets.only(right: 8.0),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              app.update(() => app.meetListChipFilter = index);
              app.persistMeetUiState();
            },
            borderRadius: BorderRadius.circular(999.0),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
              decoration: BoxDecoration(
                color: selected ? _electricBlue : Colors.white,
                borderRadius: BorderRadius.circular(999.0),
                border: Border.all(
                  color: selected ? _electricBlue : const Color(0xFFE2E8F0),
                  width: 1.0,
                ),
              ),
              child: Text(
                label,
                style: GoogleFonts.sora(
                  fontSize: 13.0,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : _bannerTitle,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip('All', 0),
          chip('Need Action', 1),
          chip('Entered', 2),
          chip('Not Going', 3),
        ],
      ),
    );
  }

  Widget _buildMeetSegmentChipsAndDivider(BuildContext context, FFAppState app) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20.0, 14.0, 20.0, 0.0),
          child: _buildMeetTimeSegmentRow(context, app),
        ),
        const SizedBox(height: 10.0),
        Padding(
          padding: const EdgeInsets.fromLTRB(20.0, 0.0, 20.0, 0.0),
          child: _buildMeetListChipStrip(context, app),
        ),
        const SizedBox(height: 8.0),
        Divider(
          height: 1.0,
          thickness: 1.0,
          color: FlutterFlowTheme.of(context).lineColor,
        ),
        const SizedBox(height: 4.0),
      ],
    );
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
    final status = pref?.status ?? MeetPreferenceStatus.skipped;
    final skipSelected = pref?.skipSelected ?? false;
    final hasAlert = pref?.hasAlert ?? false;

    final pendingEntries = hasPreference &&
        (status == MeetPreferenceStatus.planning ||
            (status == MeetPreferenceStatus.interested && !hasAlert));
    final entered = hasPreference && status == MeetPreferenceStatus.entered;
    final notGoing =
        hasPreference && skipSelected && status == MeetPreferenceStatus.skipped;
    final remindMe =
        hasPreference && status == MeetPreferenceStatus.interested && hasAlert;

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

  void _setClassFilter({
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
      ScaffoldMessenger.of(context).showSnackBar(
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

  static const Color _electricBlue = Color(0xFF007AFF);
  static const Color _pageBackground = Color(0xFFF1F5F9);
  static const Color _bannerTint = Color(0xFFEFF6FF);
  static const Color _bannerTitle = Color(0xFF0F172A);
  static const Color _bannerMuted = Color(0xFF64748B);
  static const Color _quickFilterDeadlineBg = Color(0xFFDC2626);
  static const Color _quickFilterDeadlineBorder = Color(0xFFB91C1C);

  Widget _buildMeetQuickFilterPill({
    required String label,
    required IconData icon,
    required bool selected,
    required Color backgroundColor,
    required Color borderColor,
    required Color foregroundColor,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999.0),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(999.0),
            border: Border.all(
              color: selected ? _electricBlue : borderColor,
              width: selected ? 2.5 : 1.5,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: _electricBlue.withValues(alpha: 0.22),
                      blurRadius: 10.0,
                      offset: const Offset(0.0, 3.0),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: iconColor ?? foregroundColor,
                size: 22.0,
              ),
              const SizedBox(width: 10.0),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.sora(
                    fontSize: 15.0,
                    fontWeight: FontWeight.w600,
                    color: foregroundColor,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMeetTimeSegmentRow(BuildContext context, FFAppState app) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTimeSegmentTab(
          context,
          label: 'Past',
          segment: 0,
          selected: app.meetTimeSegment,
          onTap: () {
            app.update(() => app.meetTimeSegment = 0);
            app.persistMeetUiState();
          },
        ),
        _buildTimeSegmentTab(
          context,
          label: 'Live',
          segment: 1,
          selected: app.meetTimeSegment,
          onTap: () {
            app.update(() => app.meetTimeSegment = 1);
            app.persistMeetUiState();
          },
        ),
        _buildTimeSegmentTab(
          context,
          label: 'Upcoming',
          segment: 2,
          selected: app.meetTimeSegment,
          onTap: () {
            app.update(() => app.meetTimeSegment = 2);
            app.persistMeetUiState();
          },
        ),
      ],
    );
  }

  Widget _buildTimeSegmentTab(
    BuildContext context, {
    required String label,
    required int segment,
    required int selected,
    required VoidCallback onTap,
  }) {
    final metaGrey = FlutterFlowTheme.of(context).secondaryText;
    final isSel = selected == segment;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        splashColor: _electricBlue.withValues(alpha: 0.12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.sora(
                  fontSize: isSel ? 16.0 : 15.0,
                  fontWeight: isSel ? FontWeight.w700 : FontWeight.w400,
                  color: isSel ? Colors.black : metaGrey,
                  letterSpacing: 0.0,
                ),
              ),
              const SizedBox(height: 8.0),
              Container(
                height: 3.0,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isSel ? _electricBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Short line listing active meet-class filters (shown under the scope title).
  String _classFiltersSummary(FFAppState app) {
    final parts = <String>[];
    if (app.meetFilterShowAgeGroup) {
      parts.add('Age Group');
    }
    if (app.meetFilterShowSenior) {
      parts.add('Senior');
    }
    if (app.meetFilterShowOther) {
      parts.add('Other');
    }
    if (parts.isEmpty) {
      return 'No meet types selected — tap filters to choose.';
    }
    var line = 'Meet types: ${parts.join(' · ')}';
    final my = <String>[];
    if (app.meetFilterPendingEntries) {
      my.add('pending entries');
    }
    if (app.meetFilterEntered) {
      my.add('entered');
    }
    if (app.meetFilterNotGoing) {
      my.add('not going');
    }
    if (app.meetFilterRemindMe) {
      my.add('remind me');
    }
    if (my.isNotEmpty) {
      line = '$line · Only: ${my.join(' · ')}';
    }
    if (app.meetShowNotGoingInList) {
      line = '$line · “Not going” meets visible';
    }
    return line;
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

  void _onMeetFilterMenuSelected(
    BuildContext context,
    FFAppState app,
    int value,
  ) {
    if (value == 0) {
      app.update(() => app.meetsShowAllZones = false);
      app.persistMeetUiState();
      return;
    }
    if (value == 1) {
      app.update(() => app.meetsShowAllZones = true);
      app.persistMeetUiState();
      return;
    }
    if (value == 2) {
      _setClassFilter(
        nextValue: !app.meetFilterShowAgeGroup,
        currentValue: app.meetFilterShowAgeGroup,
        apply: (a, x) => a.meetFilterShowAgeGroup = x,
      );
      return;
    }
    if (value == 3) {
      _setClassFilter(
        nextValue: !app.meetFilterShowSenior,
        currentValue: app.meetFilterShowSenior,
        apply: (a, x) => a.meetFilterShowSenior = x,
      );
      return;
    }
    if (value == 4) {
      _setClassFilter(
        nextValue: !app.meetFilterShowOther,
        currentValue: app.meetFilterShowOther,
        apply: (a, x) => a.meetFilterShowOther = x,
      );
      return;
    }
    if (value == 5) {
      app.update(
        () => app.meetFilterPendingEntries = !app.meetFilterPendingEntries,
      );
      app.persistMeetUiState();
      return;
    }
    if (value == 6) {
      app.update(() => app.meetFilterEntered = !app.meetFilterEntered);
      app.persistMeetUiState();
      return;
    }
    if (value == 7) {
      app.update(() => app.meetFilterNotGoing = !app.meetFilterNotGoing);
      app.persistMeetUiState();
      return;
    }
    if (value == 8) {
      app.update(() => app.meetFilterRemindMe = !app.meetFilterRemindMe);
      app.persistMeetUiState();
      return;
    }
    if (value == 9) {
      app.update(
        () => app.meetShowNotGoingInList = !app.meetShowNotGoingInList,
      );
      app.persistMeetUiState();
      return;
    }
  }

  /// Checkbox row plus the same glyphs as meet-card status disks, in neutral gray.
  Widget _meetFilterCheckboxRow({
    required bool selected,
    required String label,
    required Widget hint,
  }) {
    return Row(
      children: [
        Icon(
          selected
              ? Icons.check_box_rounded
              : Icons.check_box_outline_blank_rounded,
          color: _electricBlue,
          size: 22.0,
        ),
        const SizedBox(width: 8.0),
        hint,
        const SizedBox(width: 10.0),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.sora(fontSize: 14.0),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  List<PopupMenuEntry<int>> _meetFilterMenuEntries(FFAppState app) {
    Widget zoneRow({
      required IconData icon,
      required String label,
      required bool selected,
    }) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20.0, color: _bannerTitle),
          const SizedBox(width: 10.0),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.sora(
                fontSize: 14.0,
                fontWeight: FontWeight.w500,
                color: _bannerTitle,
              ),
            ),
          ),
          if (selected) ...[
            const SizedBox(width: 6.0),
            Icon(Icons.check_rounded, color: _electricBlue, size: 22.0),
          ],
        ],
      );
    }

    return <PopupMenuEntry<int>>[
      PopupMenuItem<int>(
        value: 0,
        child: zoneRow(
          icon: Icons.near_me_outlined,
          label: 'Current zone only',
          selected: !app.meetsShowAllZones,
        ),
      ),
      PopupMenuItem<int>(
        value: 1,
        child: zoneRow(
          icon: Icons.public_rounded,
          label: 'All Pacific zones',
          selected: app.meetsShowAllZones,
        ),
      ),
      const PopupMenuDivider(),
      PopupMenuItem<int>(
        value: 2,
        child: Row(
          children: [
            Icon(
              app.meetFilterShowAgeGroup
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank_rounded,
              color: _electricBlue,
              size: 22.0,
            ),
            const SizedBox(width: 10.0),
            Expanded(
              child: Text(
                'Age Group',
                style: GoogleFonts.sora(fontSize: 14.0),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      PopupMenuItem<int>(
        value: 3,
        child: Row(
          children: [
            Icon(
              app.meetFilterShowSenior
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank_rounded,
              color: _electricBlue,
              size: 22.0,
            ),
            const SizedBox(width: 10.0),
            Expanded(
              child: Text(
                'Senior',
                style: GoogleFonts.sora(fontSize: 14.0),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      PopupMenuItem<int>(
        value: 4,
        child: Row(
          children: [
            Icon(
              app.meetFilterShowOther
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank_rounded,
              color: _electricBlue,
              size: 22.0,
            ),
            const SizedBox(width: 10.0),
            Expanded(
              child: Text(
                'Other',
                style: GoogleFonts.sora(fontSize: 14.0),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      const PopupMenuDivider(),
      PopupMenuItem<int>(
        value: 5,
        child: _meetFilterCheckboxRow(
          selected: app.meetFilterPendingEntries,
          label: 'Pending entries',
          hint: Icon(
            Icons.pending_actions_rounded,
            size: 20.0,
            color: _bannerTitle.withValues(alpha: 0.52),
          ),
        ),
      ),
      PopupMenuItem<int>(
        value: 6,
        child: _meetFilterCheckboxRow(
          selected: app.meetFilterEntered,
          label: 'Entered',
          hint: Icon(
            Icons.check_rounded,
            size: 20.0,
            color: _bannerTitle.withValues(alpha: 0.52),
          ),
        ),
      ),
      PopupMenuItem<int>(
        value: 7,
        child: _meetFilterCheckboxRow(
          selected: app.meetFilterNotGoing,
          label: 'Not Going',
          hint: Icon(
            Icons.close_rounded,
            size: 20.0,
            color: _bannerTitle.withValues(alpha: 0.52),
          ),
        ),
      ),
      PopupMenuItem<int>(
        value: 8,
        child: _meetFilterCheckboxRow(
          selected: app.meetFilterRemindMe,
          label: 'Remind me',
          hint: Icon(
            Icons.notifications_active_rounded,
            size: 20.0,
            color: _bannerTitle.withValues(alpha: 0.52),
          ),
        ),
      ),
      const PopupMenuDivider(),
      PopupMenuItem<int>(
        value: 9,
        child: _meetFilterCheckboxRow(
          selected: app.meetShowNotGoingInList,
          label: "Show 'Not going' meets in list",
          hint: Icon(
            Icons.visibility_outlined,
            size: 20.0,
            color: _bannerTitle.withValues(alpha: 0.52),
          ),
        ),
      ),
    ];
  }

  Future<void> _openMeetFilterMenu(
    BuildContext buttonContext,
    BuildContext pageContext,
    FFAppState app,
  ) async {
    final overlayObject =
        Overlay.of(buttonContext, rootOverlay: true).context.findRenderObject();
    if (overlayObject is! RenderBox) {
      return;
    }
    final overlay = overlayObject;
    final box = buttonContext.findRenderObject()! as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        box.localToGlobal(Offset.zero, ancestor: overlay),
        box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );
    final selected = await showMenu<int>(
      context: buttonContext,
      position: position,
      items: _meetFilterMenuEntries(app),
    );
    if (!pageContext.mounted || selected == null) {
      return;
    }
    _onMeetFilterMenuSelected(pageContext, app, selected);
  }

  Widget _buildMeetsScopeBanner(BuildContext context, FFAppState app) {
    return Container(
      constraints: const BoxConstraints(minHeight: 56.0),
      decoration: BoxDecoration(
        color: _bannerTint,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10.0,
            offset: const Offset(0.0, 2.0),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4.0,
            color: _electricBlue,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12.0, 12.0, 4.0, 12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36.0,
                    height: 36.0,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    child: Icon(
                      Icons.pool_rounded,
                      size: 20.0,
                      color: _electricBlue,
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: !_meetBannerReady
                        ? SizedBox(
                            height: 20.0,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: SizedBox(
                                width: 20.0,
                                height: 20.0,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.0,
                                  color: _electricBlue,
                                ),
                              ),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'YOUR MEET LIST',
                                style: GoogleFonts.sora(
                                  fontSize: 10.0,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.85,
                                  color: _bannerMuted,
                                ),
                              ),
                              const SizedBox(height: 4.0),
                              Text(
                                _meetsScopeHeadline(app),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.sora(
                                  fontSize: 15.0,
                                  fontWeight: FontWeight.w700,
                                  height: 1.25,
                                  letterSpacing: 0.0,
                                  color: _bannerTitle,
                                ),
                              ),
                              const SizedBox(height: 4.0),
                              Text(
                                _classFiltersSummary(app),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.sora(
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.w500,
                                  height: 1.25,
                                  color: _bannerMuted,
                                ),
                              ),
                            ],
                          ),
                  ),
                  Builder(
                    builder: (buttonContext) {
                      final filtersOn = _meetTuneFiltersNonDefault(app);
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          IconButton(
                            tooltip: filtersOn
                                ? 'Filters active — zone & meet types'
                                : 'Zone & meet type filters',
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.all(8.0),
                            constraints: const BoxConstraints(
                              minWidth: 40.0,
                              minHeight: 40.0,
                            ),
                            icon: Icon(
                              Icons.tune_rounded,
                              color: _electricBlue,
                              size: 24.0,
                            ),
                            onPressed: () => _openMeetFilterMenu(
                              buttonContext,
                              context,
                              app,
                            ),
                          ),
                          if (filtersOn)
                            PositionedDirectional(
                              top: 4.0,
                              end: 4.0,
                              child: Container(
                                width: 9.0,
                                height: 9.0,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEA580C),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<FFAppState>();

    return ColoredBox(
      color: _pageBackground,
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20.0, 12.0, 20.0, 0.0),
            child: _buildMeetsScopeBanner(context, app),
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
                    widePastWindow: app.meetTimeSegment == 0 ||
                        _anyMyListOrQuickFilterOn(app),
                  ),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildMeetSegmentChipsAndDivider(context, app),
                          Expanded(
                            child: Center(
                              child: SizedBox(
                                width: 50.0,
                                height: 50.0,
                                child: CircularProgressIndicator(
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                    _electricBlue,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                    final afterTune = snapshot.data!
                        .where(_matchesClassFilters)
                        .where(
                          (m) =>
                              _meetMatchesTimeSegment(m, app.meetTimeSegment),
                        )
                        .where((m) => _matchesMyMeetListFilters(m, prefs, app))
                        .toList();

                    var deadlineWeekCount = 0;
                    for (final m in afterTune) {
                      if (MeetListQuickFilter.entryDeadlineThisCalendarWeek(
                        m,
                        prefs[m.reference.id],
                      )) {
                        deadlineWeekCount++;
                      }
                    }

                    final quickFilterStale = _meetQuickFilter ==
                            _MeetQuickFilter.deadlineThisWeek &&
                        deadlineWeekCount == 0;
                    if (quickFilterStale) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          setState(
                              () => _meetQuickFilter = _MeetQuickFilter.none);
                        }
                      });
                    }

                    Iterable<MonitoredMeetsRecord> afterQuick = afterTune;
                    if (_meetQuickFilter ==
                        _MeetQuickFilter.deadlineThisWeek) {
                      afterQuick = afterTune.where(
                        (m) =>
                            MeetListQuickFilter.entryDeadlineThisCalendarWeek(
                          m,
                          prefs[m.reference.id],
                        ),
                      );
                    }
                    final list = _applyNotGoingVisibilityAndChips(
                      afterQuick.toList(),
                      prefs,
                      app,
                    );

                    if (afterTune.isEmpty) {
                      return KeyedSubtree(
                        key: const ValueKey<String>('meets_empty'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildMeetSegmentChipsAndDivider(context, app),
                            Expanded(
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24.0),
                                  child: Text(
                                    'No meets match your filters.',
                                    textAlign: TextAlign.center,
                                    style:
                                        FlutterFlowTheme.of(context).bodyMedium,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    if (list.isEmpty) {
                      return KeyedSubtree(
                        key: const ValueKey<String>('meets_quick_empty'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildMeetSegmentChipsAndDivider(context, app),
                            if (deadlineWeekCount > 0) ...[
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  40.0,
                                  0.0,
                                  40.0,
                                  0.0,
                                ),
                                child: _buildMeetQuickFilterPill(
                                  label:
                                      '$deadlineWeekCount Deadline${deadlineWeekCount == 1 ? '' : 's'} This Week',
                                  icon: Icons.event_busy_rounded,
                                  selected: _meetQuickFilter ==
                                      _MeetQuickFilter.deadlineThisWeek,
                                  backgroundColor: _quickFilterDeadlineBg,
                                  borderColor: _quickFilterDeadlineBorder,
                                  foregroundColor: Colors.white,
                                  onTap: () => setState(() {
                                    _meetQuickFilter = _meetQuickFilter ==
                                            _MeetQuickFilter.deadlineThisWeek
                                        ? _MeetQuickFilter.none
                                        : _MeetQuickFilter.deadlineThisWeek;
                                  }),
                                ),
                              ),
                              const SizedBox(height: 8.0),
                            ],
                            Expanded(
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24.0),
                                  child: Text(
                                    'No meets match your filters.',
                                    textAlign: TextAlign.center,
                                    style:
                                        FlutterFlowTheme.of(context).bodyMedium,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return KeyedSubtree(
                      key: ValueKey<String>(
                        'meets_${app.meetTimeSegment}_${list.length}_${prefs.length}_'
                        '${_meetQuickFilter.name}_${app.meetListChipFilter}',
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildMeetSegmentChipsAndDivider(context, app),
                          if (deadlineWeekCount > 0) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                40.0,
                                0.0,
                                40.0,
                                0.0,
                              ),
                              child: _buildMeetQuickFilterPill(
                                label:
                                    '$deadlineWeekCount Deadline${deadlineWeekCount == 1 ? '' : 's'} This Week',
                                icon: Icons.event_busy_rounded,
                                selected: _meetQuickFilter ==
                                    _MeetQuickFilter.deadlineThisWeek,
                                backgroundColor: _quickFilterDeadlineBg,
                                borderColor: _quickFilterDeadlineBorder,
                                foregroundColor: Colors.white,
                                onTap: () => setState(() {
                                  _meetQuickFilter = _meetQuickFilter ==
                                          _MeetQuickFilter.deadlineThisWeek
                                      ? _MeetQuickFilter.none
                                      : _MeetQuickFilter.deadlineThisWeek;
                                }),
                              ),
                            ),
                            const SizedBox(height: 8.0),
                          ],
                          Expanded(
                            child: ListView.builder(
                              // Default clip (hardEdge) — Clip.none lets cards paint above
                              // the header/tabs in the parent [Column].
                              padding: const EdgeInsets.fromLTRB(
                                20.0,
                                12.0,
                                20.0,
                                24.0,
                              ),
                              itemCount: list.length,
                              itemBuilder: (context, columnIndex) {
                                final meet = list[columnIndex];
                                final pref = prefs[meet.reference.id];
                                return M02MeetEnteredWidget(
                                  key: Key(
                                    'meet_${meet.reference.id}_$columnIndex',
                                  ),
                                  meetDoc: meet,
                                  preference: pref,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
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
