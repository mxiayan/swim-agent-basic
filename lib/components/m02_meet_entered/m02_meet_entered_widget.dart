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

  static const Color _metaTone = Color(0xFF757575);

  DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  TextStyle _metaTextStyle() => GoogleFonts.sora(
        fontSize: 12.0,
        fontWeight: FontWeight.w500,
        color: _metaTone,
        letterSpacing: 0.0,
      );

  Widget _metaSeparator() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Text(
          '|',
          style: GoogleFonts.sora(
            fontSize: 12.0,
            fontWeight: FontWeight.w400,
            color: const Color(0xFFCBD5E1),
            height: 1.0,
          ),
        ),
      );

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

  TextStyle _dateLineStyle(BuildContext context) => GoogleFonts.sora(
        fontSize: 12.0,
        fontWeight: FontWeight.w500,
        color: FlutterFlowTheme.of(context).secondaryText,
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
      style: _dateLineStyle(context),
    );
  }

  Widget _buildDeadlineRow(BuildContext context, MonitoredMeetsRecord m) {
    final dl = _deadlineShort(m);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(Icons.access_time_rounded, size: 15.0, color: _metaTone),
        const SizedBox(width: 6.0),
        Expanded(
          child: Text(
            'Entry deadline: $dl',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.sora(
              fontSize: 12.0,
              fontWeight: FontWeight.w500,
              color: _metaTone,
              letterSpacing: 0.0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMeetMetaRow(MonitoredMeetsRecord m) {
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
          Icon(Icons.location_on_outlined, size: 14.0, color: _metaTone),
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
        if (location.isNotEmpty && hasSheet) _metaSeparator(),
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
                Icon(Icons.article_outlined, size: 14.0, color: _metaTone),
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
      return SizedBox.shrink();
    }

    final pref = widget.preference;
    final hidden = pref?.isHidden ?? false;

    if (hidden) {
      return Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 12.0),
        child: Material(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12.0),
          child: ListTile(
            title: Text(
              valueOrDefault<String>(doc.name, 'Meet'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.sora(
                fontSize: 14.0,
                fontWeight: FontWeight.w500,
                fontStyle: FontStyle.italic,
                color: const Color(0xFF94A3B8),
              ),
            ),
            trailing: TextButton(
              onPressed: () => _mergePref(isHidden: false),
              child: Text(
                'Show',
                style: GoogleFonts.sora(
                  fontWeight: FontWeight.w600,
                  color: FlutterFlowTheme.of(context).primary,
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
        final outerHPad = isNarrow ? 16.0 : 24.0;
        final innerHPad = 16.0;
        final status = pref?.status ?? MeetPreferenceStatus.skipped;
        final hasAlert = pref?.hasAlert ?? false;
        return Padding(
          padding: EdgeInsetsDirectional.fromSTEB(outerHPad, 0.0, outerHPad, 30.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.0),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 4.0,
                  color: Color(0x14000000),
                  offset: Offset(0.0, 2.0),
                  spreadRadius: 0.0,
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
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
                                style: FlutterFlowTheme.of(context)
                                    .titleMedium
                                    .override(
                                      font: GoogleFonts.sora(
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .titleMedium
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .titleMedium
                                            .fontStyle,
                                      ),
                                      letterSpacing: 0.0,
                                      fontWeight: FontWeight.w600,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .titleMedium
                                          .fontStyle,
                                    ),
                              ),
                            ),
                            if (status == MeetPreferenceStatus.entered) ...[
                              const SizedBox(width: 8.0),
                              Container(
                                height: 30.0,
                                padding:
                                    const EdgeInsetsDirectional.fromSTEB(
                                  10.0,
                                  0.0,
                                  10.0,
                                  0.0,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(15.0),
                                ),
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      color: Colors.white,
                                      size: 15.0,
                                    ),
                                    const SizedBox(width: 5.0),
                                    Text(
                                      'ENTERED',
                                      style: GoogleFonts.sora(
                                        fontSize: 10.0,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
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
                                    ? FlutterFlowTheme.of(context).primary
                                    : _metaTone,
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
                                color:
                                    FlutterFlowTheme.of(context).secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16.0),
                  _buildMeetDateRangeRow(context, doc),
                  const SizedBox(height: 8.0),
                  _buildDeadlineRow(context, doc),
                  const SizedBox(height: 16.0),
                  _buildMeetMetaRow(doc),
                  Divider(
                    thickness: 1.0,
                    color: FlutterFlowTheme.of(context).alternate,
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
                              color: FlutterFlowTheme.of(context).primary,
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
                  const SizedBox(height: 14.0),
                  SizedBox(
                    width: double.infinity,
                    child: _buildDynamicAction(
                      context,
                      doc,
                      status,
                      hasAlert,
                    ),
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

  Widget _buildDynamicAction(
    BuildContext context,
    MonitoredMeetsRecord doc,
    MeetPreferenceStatus status,
    bool hasAlert,
  ) {
    final hasUrl = doc.hasEntryPage;
    final url = doc.entryUrl.trim();
    final primary = FlutterFlowTheme.of(context).primary;
    final alertStyle = status == MeetPreferenceStatus.interested ||
        (hasAlert && status != MeetPreferenceStatus.entered);

    final pad = const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0);

    final actionLabelStyle =
        GoogleFonts.sora(fontWeight: FontWeight.w600, fontSize: 15.0);

    if (status == MeetPreferenceStatus.entered) {
      return FilledButton.tonal(
        onPressed: () {},
        style: FilledButton.styleFrom(
          foregroundColor: const Color(0xFF14532D),
          backgroundColor: const Color(0xFFDCFCE7),
          padding: pad,
          minimumSize: const Size(double.infinity, 48.0),
          shape: const RoundedRectangleBorder(borderRadius: _actionRadius),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, size: 20.0),
            const SizedBox(width: 10.0),
            Text('Entered', style: actionLabelStyle),
          ],
        ),
      );
    }

    if (alertStyle) {
      return FilledButton.tonal(
        onPressed: hasUrl ? () async => launchURL(url) : null,
        style: FilledButton.styleFrom(
          foregroundColor: primary,
          padding: pad,
          minimumSize: const Size(double.infinity, 48.0),
          shape: const RoundedRectangleBorder(borderRadius: _actionRadius),
          elevation: 1,
          shadowColor: const Color(0x40000000),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.notifications_active_rounded, size: 20.0),
            const SizedBox(width: 10.0),
            Text('Alert Set', style: actionLabelStyle),
          ],
        ),
      );
    }

    return ElevatedButton(
      onPressed: hasUrl
          ? () async {
              await launchURL(url);
              if (!context.mounted) {
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Finished entering?'),
                  action: SnackBarAction(
                    label: 'I entered',
                    onPressed: () {
                      _mergePref(status: MeetPreferenceStatus.entered);
                    },
                  ),
                ),
              );
            }
          : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFFE2E8F0),
        disabledForegroundColor: const Color(0xFF94A3B8),
        padding: pad,
        minimumSize: const Size(double.infinity, 48.0),
        elevation: 2,
        shadowColor: const Color(0x45000000),
        shape: const RoundedRectangleBorder(borderRadius: _actionRadius),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.open_in_new_rounded, size: 20.0),
          const SizedBox(width: 10.0),
          Text(
            'Sign Up',
            style: GoogleFonts.sora(
              fontWeight: FontWeight.w600,
              fontSize: 15.0,
            ),
          ),
        ],
      ),
    );
  }
}
