import '/backend/backend.dart';
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

  /// False until [refreshSwimmerAppState] finishes so we do not flash email / prefs.
  bool _meetBannerReady = false;
  bool _showAllZones = false;
  bool _showAgeGroup = true;
  bool _showSenior = true;
  bool _showOther = true;

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
    if (meet.meetClasses.isEmpty) {
      return false;
    }
    final ageMatch = _showAgeGroup && _containsClassToken(meet, 'age group');
    final seniorMatch = _showSenior && _containsClassToken(meet, 'senior');
    final otherMatch = _showOther && _isOtherClass(meet);
    return ageMatch || seniorMatch || otherMatch;
  }

  void _setClassFilter({
    required bool nextValue,
    required bool currentValue,
    required void Function(bool v) apply,
  }) {
    if (nextValue == currentValue) {
      return;
    }
    final activeCount = (_showAgeGroup ? 1 : 0) +
        (_showSenior ? 1 : 0) +
        (_showOther ? 1 : 0);
    if (!nextValue && activeCount <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Keep at least one class filter active.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    safeSetState(() => apply(nextValue));
  }

  Widget _buildClassFilterChip({
    required String label,
    required bool selected,
    required ValueChanged<bool> onSelected,
  }) {
    return FilterChip(
      label: Text(
        label,
        style: FlutterFlowTheme.of(context).labelSmall.override(
              font: GoogleFonts.sora(
                fontWeight: FontWeight.w500,
                fontStyle: FlutterFlowTheme.of(context).labelSmall.fontStyle,
              ),
              color: selected ? Colors.black : const Color(0xFF616161),
              fontSize: 11.0,
              letterSpacing: 0.0,
              fontWeight: FontWeight.w500,
              fontStyle: FlutterFlowTheme.of(context).labelSmall.fontStyle,
            ),
      ),
      avatar: Icon(
        selected ? Icons.check_rounded : Icons.close_rounded,
        size: 14.0,
        color: selected ? Colors.blue : const Color(0xFF9E9E9E),
      ),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: false,
      side: BorderSide(
        color: selected ? Colors.blue : const Color(0xFFE0E0E0),
        width: 1.0,
      ),
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFFE3F2FD),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
      ),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
    context.watch<FFAppState>();

    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(30.0, 0.0, 30.0, 0.0),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: FlutterFlowTheme.of(context).secondaryBackground,
                    border: Border.all(
                      color: Color(0xFFE0E3E7),
                      width: 1.0,
                    ),
                  ),
                  child: Padding(
                    padding:
                        EdgeInsetsDirectional.fromSTEB(12.0, 10.0, 12.0, 10.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 32.0,
                                height: 32.0,
                                decoration: BoxDecoration(
                                  color: Color(0x1A4B39EF),
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                alignment: AlignmentDirectional(0.0, 0.0),
                                child: Icon(
                                  Icons.info_outlined,
                                  color: FlutterFlowTheme.of(context).primary,
                                  size: 16.0,
                                ),
                              ),
                              SizedBox(width: 10.0),
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Personalized View',
                                      style: FlutterFlowTheme.of(context)
                                          .bodySmall
                                          .override(
                                            font: GoogleFonts.sora(
                                              fontWeight: FontWeight.bold,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodySmall
                                                      .fontStyle,
                                            ),
                                            color: FlutterFlowTheme.of(context)
                                                .primaryText,
                                            fontSize: 12.0,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.bold,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .bodySmall
                                                    .fontStyle,
                                          ),
                                    ),
                                    if (!_meetBannerReady)
                                      Row(
                                        mainAxisSize: MainAxisSize.max,
                                        children: [
                                          SizedBox(
                                            width: 16.0,
                                            height: 16.0,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.0,
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .primary,
                                            ),
                                          ),
                                          SizedBox(width: 10.0),
                                          Expanded(
                                            child: Text(
                                              'Loading swimmer profile…',
                                              style: FlutterFlowTheme.of(
                                                      context)
                                                  .bodySmall
                                                  .override(
                                                    font: GoogleFonts.sora(
                                                      fontWeight:
                                                          FontWeight.normal,
                                                      fontStyle:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .bodySmall
                                                              .fontStyle,
                                                    ),
                                                    color:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .secondaryText,
                                                    fontSize: 12.0,
                                                    letterSpacing: 0.0,
                                                    fontWeight:
                                                        FontWeight.normal,
                                                    fontStyle:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .bodySmall
                                                            .fontStyle,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      )
                                    else
                                      Text.rich(
                                        TextSpan(
                                          children: [
                                            TextSpan(
                                              text: 'Showing meets for ',
                                              style: FlutterFlowTheme.of(
                                                      context)
                                                  .bodySmall
                                                  .override(
                                                    font: GoogleFonts.sora(
                                                      fontWeight:
                                                          FontWeight.normal,
                                                      fontStyle:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .bodySmall
                                                              .fontStyle,
                                                    ),
                                                    color:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .secondaryText,
                                                    fontSize: 12.0,
                                                    letterSpacing: 0.0,
                                                    fontWeight:
                                                        FontWeight.normal,
                                                    fontStyle:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .bodySmall
                                                            .fontStyle,
                                                  ),
                                            ),
                                            TextSpan(
                                              text: FFAppState()
                                                      .currentSwimmerName
                                                      .trim()
                                                      .isNotEmpty
                                                  ? FFAppState()
                                                      .currentSwimmerName
                                                  : 'your swimmer',
                                              style: FlutterFlowTheme.of(
                                                      context)
                                                  .bodyMedium
                                                  .override(
                                                    font: GoogleFonts.sora(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontStyle:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .bodyMedium
                                                              .fontStyle,
                                                    ),
                                                    fontSize: 12.0,
                                                    letterSpacing: 0.0,
                                                    fontWeight: FontWeight.w600,
                                                    fontStyle:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .bodyMedium
                                                            .fontStyle,
                                                  ),
                                            ),
                                            TextSpan(
                                              text: ' in ',
                                              style: FlutterFlowTheme.of(
                                                      context)
                                                  .bodyMedium
                                                  .override(
                                                    font: GoogleFonts.sora(
                                                      fontWeight:
                                                          FontWeight.normal,
                                                      fontStyle:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .bodyMedium
                                                              .fontStyle,
                                                    ),
                                                    fontSize: 12.0,
                                                    letterSpacing: 0.0,
                                                    fontWeight:
                                                        FontWeight.normal,
                                                    fontStyle:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .bodyMedium
                                                            .fontStyle,
                                                  ),
                                            ),
                                            TextSpan(
                                              text: () {
                                                final label = FFAppState()
                                                    .currentSwimmerZoneLabel
                                                    .trim();
                                                if (label.isNotEmpty) {
                                                  return label;
                                                }
                                                final z = FFAppState()
                                                    .currentSwimmerZoneForMeets
                                                    .trim();
                                                if (z.isNotEmpty) {
                                                  return z;
                                                }
                                                return 'your zone';
                                              }(),
                                              style: FlutterFlowTheme.of(
                                                      context)
                                                  .bodyMedium
                                                  .override(
                                                    font: GoogleFonts.sora(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontStyle:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .bodyMedium
                                                              .fontStyle,
                                                    ),
                                                    fontSize: 12.0,
                                                    letterSpacing: 0.0,
                                                    fontWeight: FontWeight.w600,
                                                    fontStyle:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .bodyMedium
                                                            .fontStyle,
                                                  ),
                                            ),
                                          ],
                                        ),
                                        maxLines: 4,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    if (_showAllZones)
                                      Padding(
                                        padding: EdgeInsetsDirectional.fromSTEB(
                                            0.0, 4.0, 0.0, 0.0),
                                        child: Text(
                                          'Showing meets from all swim zones',
                                          style: FlutterFlowTheme.of(context)
                                              .bodySmall
                                              .override(
                                                font: GoogleFonts.sora(
                                                  fontWeight: FontWeight.normal,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .bodySmall
                                                          .fontStyle,
                                                ),
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .secondaryText,
                                                fontSize: 11.0,
                                                letterSpacing: 0.0,
                                                fontWeight: FontWeight.normal,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .bodySmall
                                                        .fontStyle,
                                              ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 12.0),
                        Container(
                          decoration: BoxDecoration(
                            color: FlutterFlowTheme.of(context)
                                .secondaryBackground,
                            border: Border.all(
                              color: Color(0xFFE0E3E7),
                              width: 1.0,
                            ),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          padding: EdgeInsetsDirectional.fromSTEB(
                              6.0, 4.0, 6.0, 4.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Switch.adaptive(
                                value: _showAllZones,
                                onChanged: (v) {
                                  safeSetState(() => _showAllZones = v);
                                },
                              ),
                              Text(
                                'All zones',
                                style: FlutterFlowTheme.of(context)
                                    .labelSmall
                                    .override(
                                      font: GoogleFonts.sora(
                                        fontWeight: FontWeight.w600,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .labelSmall
                                            .fontStyle,
                                      ),
                                      letterSpacing: 0.0,
                                      fontWeight: FontWeight.w600,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .labelSmall
                                          .fontStyle,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(16.0, 10.0, 16.0, 0.0),
                child: LayoutBuilder(
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
                            _buildClassFilterChip(
                              label: 'Age Group',
                              selected: _showAgeGroup,
                              onSelected: (v) {
                                _setClassFilter(
                                  nextValue: v,
                                  currentValue: _showAgeGroup,
                                  apply: (x) => _showAgeGroup = x,
                                );
                              },
                            ),
                            SizedBox(width: 8.0),
                            _buildClassFilterChip(
                              label: 'Senior',
                              selected: _showSenior,
                              onSelected: (v) {
                                _setClassFilter(
                                  nextValue: v,
                                  currentValue: _showSenior,
                                  apply: (x) => _showSenior = x,
                                );
                              },
                            ),
                            SizedBox(width: 8.0),
                            _buildClassFilterChip(
                              label: 'Other',
                              selected: _showOther,
                              onSelected: (v) {
                                _setClassFilter(
                                  nextValue: v,
                                  currentValue: _showOther,
                                  apply: (x) => _showOther = x,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<MonitoredMeetsRecord>>(
            stream: streamMonitoredMeetsForSwimmer(
              zoneId: FFAppState().currentSwimmerZoneForMeets,
              priorityHostGroup: FFAppState().currentSwimmerGroup,
              showAll: _showAllZones,
            ),
            builder: (context, snapshot) {
              // Customize what your widget looks like when it's loading.
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
              final columnMonitoredMeetsRecordList = snapshot.data!
                  .where(_matchesClassFilters)
                  .toList();

              if (columnMonitoredMeetsRecordList.isEmpty) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Text(
                      'No meets match your filters.',
                      textAlign: TextAlign.center,
                      style: FlutterFlowTheme.of(context).bodyMedium,
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: EdgeInsets.only(bottom: 24.0),
                itemCount: columnMonitoredMeetsRecordList.length,
                itemBuilder: (context, columnIndex) {
                  final columnMonitoredMeetsRecord =
                      columnMonitoredMeetsRecordList[columnIndex];
                  return M02MeetEnteredWidget(
                    key: Key(
                        'Key3vc_${columnIndex}_of_${columnMonitoredMeetsRecordList.length}'),
                    meetDoc: columnMonitoredMeetsRecord,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
