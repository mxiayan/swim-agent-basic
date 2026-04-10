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
import 'm02_meet_model.dart';
export 'm02_meet_model.dart';

class M02MeetWidget extends StatefulWidget {
  const M02MeetWidget({super.key});

  @override
  State<M02MeetWidget> createState() => _M02MeetWidgetState();
}

class _M02MeetWidgetState extends State<M02MeetWidget> {
  late M02MeetModel _model;

  bool _meetBannerReady = false;

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

  static const Color _chipUnselectedFg = Color(0xFF475569);
  static const Color _chipBorder = Color(0xFFE2E8F0);
  static const Color _pillSelectedBg = Color(0xFF0F172A);

  Widget _buildTimeSegmentTab(
    BuildContext context, {
    required String label,
    required int segment,
    required int selected,
    required VoidCallback onTap,
  }) {
    final primary = FlutterFlowTheme.of(context).primary;
    final isSel = selected == segment;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        splashColor: primary.withValues(alpha: 0.08),
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
                  color: isSel ? const Color(0xFF0F172A) : Colors.grey,
                  letterSpacing: 0.0,
                ),
              ),
              const SizedBox(height: 8.0),
              Container(
                height: 3.0,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isSel ? primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryPill({
    required BuildContext context,
    required String label,
    required bool selected,
    required ValueChanged<bool> onSelected,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onSelected(!selected),
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: selected ? _pillSelectedBg : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: selected
                ? null
                : Border.all(color: _chipBorder, width: 1.0),
          ),
          child: Text(
            label,
            style: GoogleFonts.sora(
              fontWeight: FontWeight.w600,
              fontSize: 11.0,
              letterSpacing: 0.0,
              color: selected ? Colors.white : _chipUnselectedFg,
            ),
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
      color: const Color(0xFFF1F5F9),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 0.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                constraints: const BoxConstraints(minHeight: 40.0),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12.0,
                  vertical: 8.0,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(20.0),
                ),
                alignment: Alignment.center,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 16.0,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 8.0),
                    Expanded(
                      child: !_meetBannerReady
                          ? SizedBox(
                              height: 18.0,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.0,
                                    color: FlutterFlowTheme.of(context)
                                        .primary,
                                  ),
                                ),
                              ),
                            )
                          : Text(
                              _meetsContextMessage(app),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.sora(
                                fontSize: 13.0,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                                letterSpacing: 0.0,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                    ),
                    Tooltip(
                      message: app.meetsShowAllZones
                          ? 'Zone filter off (all zones)'
                          : 'Show all zones',
                      child: IconButton(
                        iconSize: 18.0,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.all(4.0),
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        style: IconButton.styleFrom(
                          foregroundColor: app.meetsShowAllZones
                              ? FlutterFlowTheme.of(context).primary
                              : const Color(0xFF64748B),
                        ),
                        onPressed: () {
                          app.update(
                            () =>
                                app.meetsShowAllZones = !app.meetsShowAllZones,
                          );
                          app.persistMeetUiState();
                        },
                        icon: Icon(
                          app.meetsShowAllZones
                              ? Icons.public_rounded
                              : Icons.location_on_outlined,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14.0),
              Row(
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
              ),
              const SizedBox(height: 12.0),
              LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: constraints.maxWidth,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildCategoryPill(
                            context: context,
                            label: 'Age Group',
                            selected: app.meetFilterShowAgeGroup,
                            onSelected: (v) {
                              _setClassFilter(
                                nextValue: v,
                                currentValue: app.meetFilterShowAgeGroup,
                                apply: (a, x) => a.meetFilterShowAgeGroup = x,
                              );
                            },
                          ),
                          const SizedBox(width: 8.0),
                          _buildCategoryPill(
                            context: context,
                            label: 'Senior',
                            selected: app.meetFilterShowSenior,
                            onSelected: (v) {
                              _setClassFilter(
                                nextValue: v,
                                currentValue: app.meetFilterShowSenior,
                                apply: (a, x) => a.meetFilterShowSenior = x,
                              );
                            },
                          ),
                          const SizedBox(width: 8.0),
                          _buildCategoryPill(
                            context: context,
                            label: 'Other',
                            selected: app.meetFilterShowOther,
                            onSelected: (v) {
                              _setClassFilter(
                                nextValue: v,
                                currentValue: app.meetFilterShowOther,
                                apply: (a, x) => a.meetFilterShowOther = x,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<Map<String, MeetPreferencesRecord>>(
            stream: streamMeetPreferencesMap(currentUserUid),
            builder: (context, prefSnap) {
              final prefs = prefSnap.data ?? <String, MeetPreferencesRecord>{};
              return StreamBuilder<List<MonitoredMeetsRecord>>(
                stream: streamMonitoredMeetsForSwimmer(
                  zoneId: app.currentSwimmerZoneForMeets,
                  priorityHostGroup: app.currentSwimmerGroup,
                  showAll: app.meetsShowAllZones,
                  widePastWindow: app.meetTimeSegment == 0,
                ),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(
                      child: SizedBox(
                        width: 50.0,
                        height: 50.0,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            FlutterFlowTheme.of(context).primary,
                          ),
                        ),
                      ),
                    );
                  }
                  final list = snapshot.data!
                      .where(_matchesClassFilters)
                      .where(
                          (m) => _meetMatchesTimeSegment(m, app.meetTimeSegment))
                      .toList();

                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: list.isEmpty
                        ? KeyedSubtree(
                            key: const ValueKey<String>('meets_empty'),
                            child: Center(
                              child: Padding(
                                padding: EdgeInsets.all(24.0),
                                child: Text(
                                  'No meets match your filters.',
                                  textAlign: TextAlign.center,
                                  style:
                                      FlutterFlowTheme.of(context).bodyMedium,
                                ),
                              ),
                            ),
                          )
                        : KeyedSubtree(
                            key: ValueKey<String>(
                              'meets_${app.meetTimeSegment}_${list.length}_${prefs.length}',
                            ),
                            child: ListView.builder(
                              padding: EdgeInsets.only(bottom: 24.0, top: 8.0),
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
