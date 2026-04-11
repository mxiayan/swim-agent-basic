import '/auth/firebase_auth/auth_util.dart';
import '/backend/meet_preferences_api.dart';
import '/backend/schema/meet_preferences_record.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'm02_meet_entered_model.dart';
export 'm02_meet_entered_model.dart';

/// Meet card with Firestore-backed [MeetPreferencesRecord] (optional).
class M02MeetEnteredWidget extends StatefulWidget {
  const M02MeetEnteredWidget({
    super.key,
    required this.meetDoc,
    this.preference,
  });

  final MonitoredMeetsRecord? meetDoc;
  final MeetPreferencesRecord? preference;

  @override
  State<M02MeetEnteredWidget> createState() => _M02MeetEnteredWidgetState();
}

class _M02MeetEnteredWidgetState extends State<M02MeetEnteredWidget> {
  late M02MeetEnteredModel _model;

  static const Color _slateTitle = Color(0xFF1E293B);
  static const Color _slateSecondary = Color(0xFF64748B);
  static const Color _electricBlue = Color(0xFF007AFF);
  static const Color _cardBorder = Color(0xFFE2E8F0);

  DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  TextStyle _metaTextStyle() => GoogleFonts.sora(
        fontSize: 12.0,
        fontWeight: FontWeight.w500,
        color: _slateSecondary,
        letterSpacing: 0.0,
      );

  Color _metaIconColor() => _slateSecondary;

  DateTime? _entryDeadline(MonitoredMeetsRecord m) {
    final end = m.endTime ?? m.startTime;
    if (end != null) {
      return _dayOnly(end).subtract(const Duration(days: 7));
    }
    final blob =
        m.apiNotes.isNotEmpty ? m.apiNotes : m.description;
    return _parseDeadlineFromNotes(blob);
  }

  DateTime? _parseDeadlineFromNotes(String text) {
    if (text.trim().isEmpty) {
      return null;
    }
    final re = RegExp(
      r'(Sunday|Monday|Tuesday|Wednesday|Thursday|Friday|Saturday),?\s+'
      r'([A-Za-z]+)\s+(\d{1,2}),?\s+(\d{4})',
      caseSensitive: false,
    );
    final m = re.firstMatch(text);
    if (m == null) {
      return null;
    }
    try {
      final s =
          '${m.group(1)}, ${m.group(2)} ${m.group(3)}, ${m.group(4)}';
      return DateFormat('EEEE, MMMM d, y').parse(s);
    } catch (_) {
      return null;
    }
  }

  /// Short deadline fragment for the date line (e.g. "Apr 12").
  String _deadlineShort(MonitoredMeetsRecord m) {
    final d = _entryDeadline(m);
    if (d == null) {
      return 'see meet info';
    }
    return dateTimeFormat('MMM d', d);
  }

  TextStyle _dateLineStyle() => GoogleFonts.sora(
        fontSize: 12.0,
        fontWeight: FontWeight.w500,
        color: _slateSecondary,
        letterSpacing: 0.0,
      );

  Widget _buildMeetDateRangeRow(
      BuildContext context, MonitoredMeetsRecord m) {
    final dates =
        '${dateTimeFormat("MMM d", m.startDate)} - ${dateTimeFormat("MMM d, y", m.endDate)}';
    return Text(
      dates,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: _dateLineStyle(),
    );
  }

  Widget _buildDeadlineRow(BuildContext context, MonitoredMeetsRecord m) {
    final dl = _deadlineShort(m);
    final meta = _slateSecondary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(Icons.access_time_rounded, size: 15.0, color: meta),
        const SizedBox(width: 6.0),
        Expanded(
          child: Text(
            'Entry deadline: $dl',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.sora(
              fontSize: 12.0,
              fontWeight: FontWeight.w500,
              color: meta,
              letterSpacing: 0.0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMeetMetaRow(BuildContext context, MonitoredMeetsRecord m) {
    final location = m.location.trim();
    final sheetUrl = m.meetSheetUrl.trim();
    final hasSheet = sheetUrl.isNotEmpty;

    if (location.isEmpty && !hasSheet) {
      return const SizedBox.shrink();
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (location.isNotEmpty) ...[
          Icon(
            Icons.location_on_outlined,
            size: 14.0,
            color: _metaIconColor(),
          ),
          const SizedBox(width: 4.0),
          Expanded(
            child: Text(
              location,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _metaTextStyle(),
            ),
          ),
        ],
        if (location.isNotEmpty && hasSheet) const SizedBox(width: 12.0),
        if (hasSheet)
          InkWell(
            splashColor: Colors.transparent,
            focusColor: Colors.transparent,
            hoverColor: Colors.transparent,
            highlightColor: Colors.transparent,
            onTap: () async {
              await launchURL(sheetUrl);
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.article_outlined,
                  size: 14.0,
                  color: _metaIconColor(),
                ),
                const SizedBox(width: 4.0),
                Text('Meet Sheet', style: _metaTextStyle()),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _mergePref({
    MeetPreferenceStatus? status,
    bool? hasAlert,
    bool? isHidden,
  }) async {
    final doc = widget.meetDoc;
    if (doc == null) {
      return;
    }
    try {
      await mergeMeetPreference(
        currentUserUid,
        doc.reference.id,
        status: status,
        hasAlert: hasAlert,
        isHidden: isHidden,
      );
    } on FirebaseException catch (e) {
      if (!mounted) {
        return;
      }
      final message = e.code == 'permission-denied'
          ? 'Could not save meet settings (permission denied).'
          : (e.message ?? 'Could not save meet settings.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => M02MeetEnteredModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.meetDoc;
    if (doc == null) {
      return const SizedBox.shrink();
    }

    final pref = widget.preference;
    final hidden = pref?.isHidden ?? false;

    if (hidden) {
      final theme = FlutterFlowTheme.of(context);
      return Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(20.0, 0.0, 20.0, 12.0),
        child: Material(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
            side: const BorderSide(color: _cardBorder, width: 1.0),
          ),
          child: ListTile(
            title: Text(
              valueOrDefault<String>(doc.name, 'Meet'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.sora(
                fontSize: 14.0,
                fontWeight: FontWeight.w500,
                fontStyle: FontStyle.italic,
                color: theme.secondaryText,
              ),
            ),
            trailing: TextButton(
              onPressed: () => _mergePref(isHidden: false),
              child: Text(
                'Show',
                style: GoogleFonts.sora(
                  fontWeight: FontWeight.w600,
                  color: _electricBlue,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 420.0;
        const innerHPad = 16.0;
        final status = pref?.status ?? MeetPreferenceStatus.skipped;
        final hasAlert = pref?.hasAlert ?? false;
        return Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
              20.0, 0.0, 20.0, 30.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: _cardBorder, width: 1.0),
              borderRadius: BorderRadius.circular(12.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12.0,
                  offset: const Offset(0.0, 4.0),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                  innerHPad, 16.0, innerHPad, 16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                          top: 4.0,
                          right: 88.0,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                valueOrDefault<String>(doc.name, '[Meet Name]'),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.sora(
                                  fontSize: 16.0,
                                  fontWeight: FontWeight.w700,
                                  height: 1.25,
                                  letterSpacing: 0.0,
                                  color: _slateTitle,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.all(8.0),
                              constraints: const BoxConstraints(
                                minWidth: 40,
                                minHeight: 40,
                              ),
                              tooltip: hasAlert ? 'Alert on' : 'Set alert',
                              onPressed: () async {
                                final next = !hasAlert;
                                if (next) {
                                  await _mergePref(
                                    hasAlert: true,
                                    status:
                                        status == MeetPreferenceStatus.entered
                                            ? MeetPreferenceStatus.entered
                                            : MeetPreferenceStatus.interested,
                                  );
                                } else {
                                  if (status == MeetPreferenceStatus.entered) {
                                    await _mergePref(hasAlert: false);
                                  } else {
                                    await _mergePref(
                                      hasAlert: false,
                                      status: MeetPreferenceStatus.skipped,
                                    );
                                  }
                                }
                              },
                              icon: Icon(
                                hasAlert
                                    ? Icons.notifications_active_rounded
                                    : Icons.notifications_none_rounded,
                                size: 20.0,
                                color: hasAlert
                                    ? _electricBlue
                                    : _slateSecondary,
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.all(8.0),
                              constraints: const BoxConstraints(
                                minWidth: 40,
                                minHeight: 40,
                              ),
                              tooltip: 'Hide meet',
                              onPressed: () => _mergePref(isHidden: true),
                              icon: Icon(
                                Icons.close_rounded,
                                size: 20.0,
                                color: _slateSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMeetDateRangeRow(context, doc),
                        const SizedBox(height: 8.0),
                        _buildDeadlineRow(context, doc),
                        const SizedBox(height: 8.0),
                        _buildMeetMetaRow(context, doc),
                      ],
                    ),
                  ),
                  Divider(
                    thickness: 1.0,
                    color: FlutterFlowTheme.of(context).lineColor,
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Events Entered',
                        style: FlutterFlowTheme.of(context)
                            .labelSmall
                            .override(
                              font: GoogleFonts.sora(
                                fontWeight: FlutterFlowTheme.of(context)
                                    .labelSmall
                                    .fontWeight,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .labelSmall
                                    .fontStyle,
                              ),
                              letterSpacing: 0.0,
                              fontWeight: FlutterFlowTheme.of(context)
                                  .labelSmall
                                  .fontWeight,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .labelSmall
                                  .fontStyle,
                            ),
                      ),
                      Text(
                        '100m Free · 200m Free · 4x100 Relay',
                        maxLines: isNarrow ? 3 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: FlutterFlowTheme.of(context)
                            .bodySmall
                            .override(
                              font: GoogleFonts.sora(
                                fontWeight: FlutterFlowTheme.of(context)
                                    .bodySmall
                                    .fontWeight,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .bodySmall
                                    .fontStyle,
                              ),
                              color: _electricBlue,
                              letterSpacing: 0.0,
                              fontWeight: FlutterFlowTheme.of(context)
                                  .bodySmall
                                  .fontWeight,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .bodySmall
                                  .fontStyle,
                            ),
                      ),
                    ].divide(const SizedBox(height: 2.0)),
                  ),
                  const SizedBox(height: 6.0),
                  _buildEnteredToggleRow(context, status, hasAlert),
                  const SizedBox(height: 12.0),
                  SizedBox(
                    width: double.infinity,
                    child: _buildEntryUrlButton(context, doc, status),
                  ),
                ].divide(const SizedBox(height: 12.0)),
              ),
            ),
          ),
        );
      },
    );
  }

  static const BorderRadius _actionRadius =
      BorderRadius.all(Radius.circular(12.0));

  Future<void> _setEnteredState({
    required bool entered,
    required bool hasAlert,
  }) async {
    if (entered) {
      await _mergePref(status: MeetPreferenceStatus.entered);
    } else if (hasAlert) {
      await _mergePref(status: MeetPreferenceStatus.interested);
    } else {
      await _mergePref(status: MeetPreferenceStatus.skipped);
    }
  }

  Widget _buildEnteredToggleRow(
    BuildContext context,
    MeetPreferenceStatus status,
    bool hasAlert,
  ) {
    final entered = status == MeetPreferenceStatus.entered;
    final theme = FlutterFlowTheme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            "I've entered this meet",
            style: GoogleFonts.sora(
              fontSize: 14.0,
              fontWeight: FontWeight.w600,
              color: _slateTitle,
            ),
          ),
        ),
        SwitchTheme(
          data: SwitchThemeData(
            thumbColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return Colors.white;
              }
              return null;
            }),
            trackColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return _electricBlue;
              }
              return theme.lineColor;
            }),
          ),
          child: Switch(
            value: entered,
            onChanged: (next) async {
              await _setEnteredState(entered: next, hasAlert: hasAlert);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEntryUrlButton(
    BuildContext context,
    MonitoredMeetsRecord doc,
    MeetPreferenceStatus status,
  ) {
    final hasUrl = doc.hasEntryPage;
    final url = doc.entryUrl.trim();
    final theme = FlutterFlowTheme.of(context);
    final entered = status == MeetPreferenceStatus.entered;
    const pad = EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0);
    final labelStyle =
        GoogleFonts.sora(fontWeight: FontWeight.w600, fontSize: 15.0);

    Future<void> open() async {
      if (!hasUrl) {
        return;
      }
      await launchURL(url);
    }

    if (entered) {
      return OutlinedButton(
        onPressed: hasUrl ? open : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: _electricBlue,
          backgroundColor: Colors.white,
          side: const BorderSide(color: _electricBlue, width: 2.0),
          padding: pad,
          minimumSize: const Size(double.infinity, 48.0),
          shape: const RoundedRectangleBorder(borderRadius: _actionRadius),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.list_alt_rounded, size: 20.0, color: _electricBlue),
            const SizedBox(width: 10.0),
            Text(
              'View Entries',
              style: labelStyle.copyWith(color: _electricBlue),
            ),
          ],
        ),
      );
    }

    return ElevatedButton(
      onPressed: hasUrl ? open : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: _electricBlue,
        foregroundColor: theme.primaryBtnText,
        disabledBackgroundColor: theme.accent3,
        disabledForegroundColor: theme.secondaryText,
        padding: pad,
        minimumSize: const Size(double.infinity, 48.0),
        elevation: 2,
        shadowColor: _electricBlue.withValues(alpha: 0.28),
        shape: const RoundedRectangleBorder(borderRadius: _actionRadius),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.open_in_new_rounded, size: 20.0, color: theme.primaryBtnText),
          const SizedBox(width: 10.0),
          Text(
            'Sign Up',
            style: labelStyle.copyWith(color: theme.primaryBtnText),
          ),
        ],
      ),
    );
  }
}
