import 'dart:math' as math;
import 'dart:ui' as ui;

import '/auth/firebase_auth/auth_util.dart';
import '/backend/meet_preferences_api.dart';
import '/backend/schema/meet_preferences_record.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'm02_meet_entered_model.dart';
export 'm02_meet_entered_model.dart';

enum _DeadlineUrgency { none, approaching, passed }

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

class _M02MeetEnteredWidgetState extends State<M02MeetEnteredWidget>
    with TickerProviderStateMixin {
  late M02MeetEnteredModel _model;

  /// Plays when the user turns “I’ve entered this meet” on (after confirm).
  late final AnimationController _enteredCelebrateController;
  late final Animation<double> _celebrateScale;
  late final Animation<double> _celebrateFade;

  static const Color _slateTitle = Color(0xFF1E293B);
  static const Color _slateSecondary = Color(0xFF64748B);
  static const Color _electricBlue = Color(0xFF007AFF);
  static const Color _cardBorder = Color(0xFFE2E8F0);
  /// Entered meet: left accent only (no green card fill).
  static const Color _enteredSidebarBlue = Color(0xFF007AFF);
  static const Color _verifiedGreen = Color(0xFF15803D);
  /// “Following” / interested (header heart), distinct from entered green.
  static const Color _followingHeart = Color(0xFFE11D48);
  static const Color _parentNoteBg = Color(0xFFF8FAFC);
  static const Color _softRedGlow = Color(0xFFFECACA);

  /// Aligns calendar / clock / pin / sheet icons across logistics rows.
  static const double _logisticsIconColWidth = 22.0;
  static const double _logisticsIconGap = 6.0;
  static const double _logisticsRowGap = 8.0;

  late final AnimationController _deadlinePulseController;

  DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Today falls on a calendar day between meet start and end (inclusive).
  bool _isMeetLive(MonitoredMeetsRecord m) {
    final today = _dayOnly(DateTime.now());
    final s = m.startTime;
    final e = m.endTime ?? m.startTime;
    if (s == null && e == null) {
      return false;
    }
    final sd = s != null ? _dayOnly(s) : _dayOnly(e!);
    final ed = e != null ? _dayOnly(e) : sd;
    return !sd.isAfter(today) && !ed.isBefore(today);
  }

  bool _entryDeadlineHasPassed(MonitoredMeetsRecord m) {
    final end = _entryDeadlineEnd(m);
    if (end == null) {
      return false;
    }
    return DateTime.now().isAfter(end);
  }

  /// Firestore meet `status` indicates registration is no longer open.
  bool _meetSignupsClosedByStatus(MonitoredMeetsRecord m) {
    final s = m.status.trim().toLowerCase();
    if (s.isEmpty) {
      return false;
    }
    return s.contains('closed') ||
        s.contains('cancel') ||
        s.contains('canceled');
  }

  /// Live meet, past entry deadline, or meet status says sign-ups are closed.
  bool _signupsClosedContext(MonitoredMeetsRecord m) {
    return _isMeetLive(m) ||
        _meetSignupsClosedByStatus(m) ||
        _entryDeadlineHasPassed(m);
  }

  /// Same rule as [MonitoredMeetsRecord.entryUrl]: numeric id gets a default OME URL.
  bool _meetIdIsNumericFastswim(MonitoredMeetsRecord m) {
    return RegExp(r'^\d+$').hasMatch(m.meetId.trim());
  }

  /// Firestore `status` is `pending` — host has not opened registration yet.
  bool _meetStatusIsPending(MonitoredMeetsRecord m) {
    return m.status.trim().toLowerCase() == 'pending';
  }

  /// Registration not open yet: `status: pending`, or placeholder meet id (e.g. `pac_…`) without a numeric FastSwim id.
  bool _meetSignupPendingContext(MonitoredMeetsRecord m) {
    return _meetStatusIsPending(m) || !_meetIdIsNumericFastswim(m);
  }

  /// End of calendar day for deadline comparisons.
  DateTime? _entryDeadlineEnd(MonitoredMeetsRecord m) {
    final d = _entryDeadline(m);
    if (d == null) {
      return null;
    }
    return DateTime(d.year, d.month, d.day, 23, 59, 59);
  }

  /// Passed / approaching (last 48h) / none. Ignored when [entered] is true.
  _DeadlineUrgency _deadlineUrgency(MonitoredMeetsRecord m, bool entered) {
    if (entered) {
      return _DeadlineUrgency.none;
    }
    final end = _entryDeadlineEnd(m);
    if (end == null) {
      return _DeadlineUrgency.none;
    }
    final now = DateTime.now();
    if (now.isAfter(end)) {
      return _DeadlineUrgency.passed;
    }
    final remaining = end.difference(now);
    if (remaining <= const Duration(hours: 48) && remaining > Duration.zero) {
      return _DeadlineUrgency.approaching;
    }
    return _DeadlineUrgency.none;
  }

  /// One-shot "Closes in DD:HH:MM" (no timer; updates when this widget rebuilds).
  String _formatClosesInFromEnd(DateTime end) {
    final d = end.difference(DateTime.now());
    if (d <= Duration.zero) {
      return 'Closes in 00:00:00';
    }
    String two(int n) => n.clamp(0, 99).toString().padLeft(2, '0');
    final days = d.inDays;
    final hours = d.inHours.remainder(24);
    final mins = d.inMinutes.remainder(60);
    return 'Closes in ${two(days)}:${two(hours)}:${two(mins)}';
  }

  bool _entryDeadlineWithin24h(MonitoredMeetsRecord m, bool entered) {
    if (entered) {
      return false;
    }
    final end = _entryDeadlineEnd(m);
    if (end == null) {
      return false;
    }
    final rem = end.difference(DateTime.now());
    return rem > Duration.zero && rem < const Duration(hours: 24);
  }

  int _calendarDaysUntilMeetStart(MonitoredMeetsRecord m) {
    final s = m.startDate;
    if (s == null) {
      return 999;
    }
    return _dayOnly(s).difference(_dayOnly(DateTime.now())).inDays;
  }

  /// Subtle pill next to meet dates (time-to-start).
  String? _timeToStartPillText(MonitoredMeetsRecord m) {
    if (_isMeetLive(m)) {
      return 'Live';
    }
    final d = _calendarDaysUntilMeetStart(m);
    if (m.startDate == null) {
      return null;
    }
    if (d < 0) {
      return 'Started';
    }
    if (d < 3) {
      return 'Starts ${dateTimeFormat('EEEE', m.startDate!)}!';
    }
    if (d <= 7) {
      return d == 0 ? 'Starts today' : 'In $d days';
    }
    final w = math.max(1, (d + 6) ~/ 7);
    return w == 1 ? 'In 1 week' : 'In $w weeks';
  }

  TextStyle _monoDeadlineStyle(Color color) => GoogleFonts.robotoMono(
        fontSize: 12.0,
        fontWeight: FontWeight.w700,
        color: color,
        height: 1.2,
        fontFeatures: [FontFeature.tabularFigures()],
      );

  Future<bool?> _confirmEntryDialog(BuildContext context, String meetName) {
    return showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Confirm Entry'),
        content: Text(
          'Are you sure you have already submitted your entry for $meetName?',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

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
    final blob = m.apiNotes.isNotEmpty ? m.apiNotes : m.description;
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
      final s = '${m.group(1)}, ${m.group(2)} ${m.group(3)}, ${m.group(4)}';
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

  TextStyle _pillTextStyle() => GoogleFonts.sora(
        fontSize: 11.0,
        fontWeight: FontWeight.w600,
        color: _slateSecondary,
        letterSpacing: 0.0,
      );

  /// Shorter countdown when deadline is 24–48h away (not the DD:HH:MM line).
  String? _deadlineApproachingShort(MonitoredMeetsRecord m, bool entered) {
    if (entered || _entryDeadlineWithin24h(m, entered)) {
      return null;
    }
    final end = _entryDeadlineEnd(m);
    if (end == null) {
      return null;
    }
    final d = end.difference(DateTime.now());
    if (d <= Duration.zero || d > const Duration(hours: 48)) {
      return null;
    }
    final days = d.inDays;
    final hours = d.inHours.remainder(24);
    if (days > 0) {
      return '${days}d ${hours}h';
    }
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    }
    return '${d.inMinutes}m';
  }

  /// Row 1: meet dates + time-to-start pill (single row).
  Widget _buildLogisticsRow1DatesCountdown(MonitoredMeetsRecord m) {
    final dates =
        '${dateTimeFormat("MMM d", m.startDate)} - ${dateTimeFormat("MMM d, y", m.endDate)}';
    final pill = _timeToStartPillText(m);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: _logisticsIconColWidth,
          child: Icon(
            Icons.calendar_today_outlined,
            size: 14.0,
            color: _slateSecondary,
          ),
        ),
        SizedBox(width: _logisticsIconGap),
        Expanded(
          child: Text(
            dates,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _dateLineStyle(),
          ),
        ),
        if (pill != null) ...[
          const SizedBox(width: 8.0),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(999.0),
              border: Border.all(color: _cardBorder, width: 1.0),
            ),
            child: Text(pill, style: _pillTextStyle()),
          ),
        ],
      ],
    );
  }

  /// Muted row when sign-ups are not relevant (live meet, status closed, or past deadline).
  Widget _buildSignupsClosedHintRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: _logisticsIconColWidth,
          child: Icon(
            Icons.event_busy_outlined,
            size: 15.0,
            color: _slateSecondary,
          ),
        ),
        SizedBox(width: _logisticsIconGap),
        Expanded(
          child: Text(
            'Sign up closed',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.sora(
              fontSize: 12.0,
              fontWeight: FontWeight.w600,
              color: _slateSecondary,
              letterSpacing: 0.0,
            ),
          ),
        ),
      ],
    );
  }

  /// Row 2 variant: registration not open yet (pending status or placeholder meet id).
  Widget _buildSignupsPendingHintRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: _logisticsIconColWidth,
          child: Padding(
            padding: const EdgeInsets.only(top: 1.0),
            child: Icon(
              Icons.schedule_rounded,
              size: 15.0,
              color: _slateSecondary,
            ),
          ),
        ),
        SizedBox(width: _logisticsIconGap),
        Expanded(
          child: Text(
            'Sign-up isn’t open yet. Use the switch below to be reminded when registration opens.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.sora(
              fontSize: 12.0,
              fontWeight: FontWeight.w600,
              color: _slateSecondary,
              letterSpacing: 0.0,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }

  /// Row 2: entry deadline + countdown on one line.
  Widget _buildLogisticsRow2Deadline(
    BuildContext context,
    MonitoredMeetsRecord m,
    bool entered,
  ) {
    if (_signupsClosedContext(m)) {
      return _buildSignupsClosedHintRow();
    }
    if (_meetSignupPendingContext(m)) {
      return _buildSignupsPendingHintRow();
    }
    final dl = _deadlineShort(m);
    final urgency = _deadlineUrgency(m, entered);
    final iconColor = entered
        ? _slateSecondary
        : switch (urgency) {
            _DeadlineUrgency.passed => Colors.red,
            _DeadlineUrgency.approaching => Colors.orange,
            _DeadlineUrgency.none => _slateSecondary,
          };
    final lineColor = entered
        ? _slateSecondary
        : switch (urgency) {
            _DeadlineUrgency.passed => Colors.red,
            _DeadlineUrgency.approaching => Colors.orange,
            _DeadlineUrgency.none => _slateSecondary,
          };
    final showUrgent = !entered && urgency == _DeadlineUrgency.approaching;
    final within24h = _entryDeadlineWithin24h(m, entered);
    final short = _deadlineApproachingShort(m, entered);
    final deadlineEnd = _entryDeadlineEnd(m);

    final deadlineTextStyle = (entered || urgency == _DeadlineUrgency.none)
        ? GoogleFonts.sora(
            fontSize: 12.0,
            fontWeight: FontWeight.w500,
            color: lineColor,
            letterSpacing: 0.0,
          )
        : _monoDeadlineStyle(lineColor);

    final deadlineLabel = Text(
      'Entry deadline: $dl',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: deadlineTextStyle,
    );

    final Widget deadlineLabelVisual = showUrgent
        ? AnimatedBuilder(
            animation: _deadlinePulseController,
            builder: (context, _) {
              final t = 0.5 +
                  0.5 *
                      math.sin(
                          _deadlinePulseController.value * 2.0 * math.pi);
              return DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8.0),
                  boxShadow: [
                    BoxShadow(
                      color: _softRedGlow.withValues(alpha: 0.35 + 0.35 * t),
                      blurRadius: 10.0 + 6.0 * t,
                      spreadRadius: 0.0,
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4.0,
                    vertical: 2.0,
                  ),
                  child: deadlineLabel,
                ),
              );
            },
          )
        : deadlineLabel;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: _logisticsIconColWidth,
          child: Icon(
            Icons.access_time_rounded,
            size: 15.0,
            color: iconColor,
          ),
        ),
        SizedBox(width: _logisticsIconGap),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: deadlineLabelVisual,
                ),
              ),
              if (within24h && deadlineEnd != null) ...[
                const SizedBox(width: 8.0),
                Text(
                  _formatClosesInFromEnd(deadlineEnd),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _monoDeadlineStyle(Colors.red.shade700),
                ),
              ] else if (short != null) ...[
                const SizedBox(width: 8.0),
                Text(
                  'Expires in $short',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _monoDeadlineStyle(Colors.orange.shade800),
                ),
              ],
              if (showUrgent) ...[
                const SizedBox(width: 4.0),
                Text(
                  '⚠️',
                  style: GoogleFonts.sora(fontSize: 13.0, height: 1.1),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Row 3: location + meet sheet (single row).
  Widget _buildLogisticsRow3LocationSheet(MonitoredMeetsRecord m) {
    final location = m.location.trim();
    final sheetUrl = m.meetSheetUrl.trim();
    final hasSheet = sheetUrl.isNotEmpty;

    if (location.isEmpty && !hasSheet) {
      return const SizedBox.shrink();
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: _logisticsIconColWidth,
          child: Padding(
            padding: const EdgeInsets.only(top: 1.0),
            child: Icon(
              Icons.location_on_outlined,
              size: 14.0,
              color: _metaIconColor(),
            ),
          ),
        ),
        SizedBox(width: _logisticsIconGap),
        if (location.isNotEmpty)
          Expanded(
            child: Text(
              location,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _metaTextStyle(),
            ),
          )
        else
          Expanded(child: const SizedBox.shrink()),
        if (hasSheet) ...[
          SizedBox(width: location.isNotEmpty ? 12.0 : 8.0),
          Material(
            color: Colors.transparent,
            child: InkWell(
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
          ),
        ],
      ],
    );
  }

  Widget _buildLogisticsSection(
    BuildContext context,
    MonitoredMeetsRecord m,
    bool entered,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildLogisticsRow1DatesCountdown(m),
        const SizedBox(height: _logisticsRowGap),
        _buildLogisticsRow2Deadline(context, m, entered),
        const SizedBox(height: _logisticsRowGap),
        _buildLogisticsRow3LocationSheet(m),
      ],
    );
  }

  Future<bool> _mergePref({
    MeetPreferenceStatus? status,
    bool? hasAlert,
    bool? isHidden,
    String? notes,
  }) async {
    final doc = widget.meetDoc;
    if (doc == null) {
      return false;
    }
    try {
      await mergeMeetPreference(
        currentUserUid,
        doc.reference.id,
        status: status,
        hasAlert: hasAlert,
        isHidden: isHidden,
        notes: notes,
      );
      return true;
    } on FirebaseException catch (e) {
      if (!mounted) {
        return false;
      }
      final message = e.code == 'permission-denied'
          ? 'Could not save meet settings (permission denied).'
          : (e.message ?? 'Could not save meet settings.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return false;
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

    _deadlinePulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _enteredCelebrateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 680),
    );
    _celebrateScale = Tween<double>(begin: 0.86, end: 1.0).animate(
      CurvedAnimation(
        parent: _enteredCelebrateController,
        curve: Curves.elasticOut,
      ),
    );
    _celebrateFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _enteredCelebrateController,
        curve: const Interval(0.0, 0.42, curve: Curves.easeOut),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      safeSetState(() {});
      final s = widget.preference?.status;
      if (s == MeetPreferenceStatus.entered) {
        _enteredCelebrateController.value = 1.0;
      }
    });
  }

  @override
  void dispose() {
    _deadlinePulseController.dispose();
    _enteredCelebrateController.dispose();
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
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
                16.0, 10.0, 8.0, 10.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
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
                ),
                TextButton(
                  onPressed: () => _mergePref(isHidden: false),
                  child: Text(
                    'Show',
                    style: GoogleFonts.sora(
                      fontWeight: FontWeight.w600,
                      color: _electricBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    const innerHPad = 20.0;
    final status = pref?.status ?? MeetPreferenceStatus.skipped;
    final hasAlert = pref?.hasAlert ?? false;
    final entered = status == MeetPreferenceStatus.entered;
    final showNotInterestedAction = !entered &&
        (status == MeetPreferenceStatus.interested || hasAlert);
    /// Space for [Stack]-positioned header actions (40px targets; two when not-interested shows).
    final titleEndInsetForHeaderActions =
        showNotInterestedAction ? 84.0 : 44.0;
    final urgency = _deadlineUrgency(doc, entered);
    final pulseEligible = !entered &&
        !_isMeetLive(doc) &&
        !_meetSignupsClosedByStatus(doc) &&
        !_meetSignupPendingContext(doc) &&
        urgency == _DeadlineUrgency.approaching;
    if (pulseEligible) {
      if (!_deadlinePulseController.isAnimating) {
        _deadlinePulseController.repeat(reverse: true);
      }
    } else if (_deadlinePulseController.isAnimating) {
      _deadlinePulseController.stop();
      _deadlinePulseController.value = 0.0;
    }
    return Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20.0, 0.0, 20.0, 30.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12.0,
                  offset: const Offset(0.0, 4.0),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: entered
                          ? const Border(
                              left: BorderSide(
                                color: _enteredSidebarBlue,
                                width: 4.0,
                              ),
                              top: BorderSide(color: _cardBorder, width: 1.0),
                              right: BorderSide(color: _cardBorder, width: 1.0),
                              bottom:
                                  BorderSide(color: _cardBorder, width: 1.0),
                            )
                          : Border.all(color: _cardBorder, width: 1.0),
                    ),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                          innerHPad, 12.0, innerHPad, 16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsetsDirectional.only(
                              end: titleEndInsetForHeaderActions,
                            ),
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
                          Padding(
                            padding:
                                const EdgeInsets.only(top: 6.0, bottom: 4.0),
                            child: _buildLogisticsSection(context, doc, entered),
                          ),
                          Divider(
                            thickness: 1.0,
                            color: FlutterFlowTheme.of(context).lineColor,
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildParentNoteBox(context, pref),
                              const SizedBox(height: 8.0),
                              if (_meetSignupPendingContext(doc) && !entered)
                                _buildNotifyWhenSignUpOpensRow(
                                  context,
                                  status,
                                  hasAlert,
                                )
                              else if (!_meetSignupPendingContext(doc))
                                _buildEnteredToggleRow(
                                  context,
                                  doc,
                                  status,
                                  hasAlert,
                                ),
                              const SizedBox(height: 12.0),
                              SizedBox(
                                width: double.infinity,
                                child: _buildEntryUrlButton(
                                  context,
                                  doc,
                                  status,
                                  entered,
                                ),
                              ),
                            ],
                          ),
                        ].divide(const SizedBox(height: 12.0)),
                      ),
                    ),
                  ),
                ),
                ..._buildMeetCornerStateOverlay(
                  context,
                  status: status,
                  entered: entered,
                ),
                ..._buildMeetCardActionOverlay(
                  context,
                  status: status,
                  entered: entered,
                  hasAlert: hasAlert,
                ),
              ],
            ),
          ),
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

  static const String _parentNotePlaceholder =
      'Tap to add a reminder (e.g. Bring extra towels...)';

  Widget _buildParentNoteBox(
    BuildContext context,
    MeetPreferencesRecord? pref,
  ) {
    final notes = pref?.notes ?? '';
    final isEmpty = notes.isEmpty;
    return Material(
      color: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      child: InkWell(
        borderRadius: BorderRadius.circular(8.0),
        onTap: () => _openParentNoteEditor(context, notes),
        child: Stack(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: _parentNoteBg,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.attach_file,
                      size: 20.0,
                      color: _slateSecondary,
                    ),
                    const SizedBox(width: 10.0),
                    Expanded(
                      child: Text(
                        isEmpty ? _parentNotePlaceholder : notes,
                        style: GoogleFonts.sora(
                          fontSize: 12.0,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                          color: isEmpty ? _slateSecondary : _slateTitle,
                          fontStyle:
                              isEmpty ? FontStyle.italic : FontStyle.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _DashedRRectPainter(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: 8.0,
                    strokeWidth: 1.0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openParentNoteEditor(
    BuildContext context,
    String currentNotes,
  ) async {
    if (widget.meetDoc == null) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      builder: (sheetContext) => _ParentNoteEditorSheet(
        initialText: currentNotes,
        onSave: (text) => _mergePref(notes: text),
      ),
    );
  }

  /// Hide: `IconButton` merges semantics in ways that can trip
  /// `parentDataDirty` on some Flutter versions; use [InkWell] under [Material] instead.
  Widget _meetHeaderIconAction({
    required BuildContext context,
    required String tooltip,
    required VoidCallback onTap,
    required IconData icon,
    required Color iconColor,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 40.0,
            height: 40.0,
            child: Center(
              child: Icon(icon, size: 20.0, color: iconColor),
            ),
          ),
        ),
      ),
    );
  }

  /// Header actions in the [Stack] so they do not reserve a full-width row above the title.
  List<Widget> _buildMeetCardActionOverlay(
    BuildContext context, {
    required MeetPreferenceStatus status,
    required bool entered,
    required bool hasAlert,
  }) {
    return [
      PositionedDirectional(
        top: 2.0,
        end: 2.0,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!entered &&
                (status == MeetPreferenceStatus.interested || hasAlert))
              _meetHeaderIconAction(
                context: context,
                tooltip:
                    'Not interested — stop reminders and following for this meet',
                onTap: () async {
                  await _mergePref(
                    status: MeetPreferenceStatus.skipped,
                    hasAlert: false,
                  );
                  if (context.mounted) {
                    HapticFeedback.selectionClick();
                  }
                },
                icon: Icons.not_interested_rounded,
                iconColor: _slateSecondary,
              ),
            _meetHeaderIconAction(
              context: context,
              tooltip: 'Hide meet from list',
              onTap: () => _mergePref(isHidden: true),
              icon: Icons.visibility_off_outlined,
              iconColor: _slateSecondary,
            ),
          ],
        ),
      ),
    ];
  }

  /// Floating disks on the card vertex; does not consume in-card layout height.
  static const double _cornerStateBadgeSize = 28.0;

  List<Widget> _buildMeetCornerStateOverlay(
    BuildContext context, {
    required MeetPreferenceStatus status,
    required bool entered,
  }) {
    final half = _cornerStateBadgeSize / 2.0;
    if (entered) {
      return [
        PositionedDirectional(
          start: -half,
          top: -half,
          child: _buildCornerEnteredBadge(context),
        ),
      ];
    }
    if (status == MeetPreferenceStatus.interested) {
      return [
        PositionedDirectional(
          start: -half,
          top: -half,
          child: _buildCornerInterestedBadge(context),
        ),
      ];
    }
    return const <Widget>[];
  }

  Widget _buildCornerStateDisk({
    required Color backgroundColor,
    required Widget child,
  }) {
    return Container(
      width: _cornerStateBadgeSize,
      height: _cornerStateBadgeSize,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 8.0,
            offset: const Offset(0.0, 2.0),
          ),
        ],
      ),
      child: Center(child: child),
    );
  }

  Widget _buildCornerEnteredBadge(BuildContext context) {
    return Tooltip(
      message: _verifiedTooltipMessage(context),
      child: AnimatedBuilder(
        animation: _enteredCelebrateController,
        builder: (context, _) {
          return Transform.scale(
            scale: _celebrateScale.value,
            alignment: Alignment.center,
            child: Opacity(
              opacity: _celebrateFade.value.clamp(0.0, 1.0),
              child: _buildCornerStateDisk(
                backgroundColor: _verifiedGreen,
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 16.0,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCornerInterestedBadge(BuildContext context) {
    return Tooltip(
      message:
          'Following this meet — you’ll get updates. See all followed meets in the Meets filter (tune icon → Interested only).',
      child: _buildCornerStateDisk(
        backgroundColor: _followingHeart,
        child: const Icon(
          Icons.favorite_rounded,
          color: Colors.white,
          size: 14.0,
        ),
      ),
    );
  }

  String _verifiedTooltipMessage(BuildContext context) {
    // read: avoid listenable subscriptions from tooltip/badge subtree (semantics).
    final raw = context.read<FFAppState>().currentSwimmerName.trim();
    final firstName = raw.isEmpty
        ? 'Swimmer'
        : raw.split(RegExp(r'\s+')).first.trim();
    return 'Verified: $firstName is entered';
  }

  Widget _buildEnteredToggleRow(
    BuildContext context,
    MonitoredMeetsRecord doc,
    MeetPreferenceStatus status,
    bool hasAlert,
  ) {
    final entered = status == MeetPreferenceStatus.entered;
    final theme = FlutterFlowTheme.of(context);
    final meetName = valueOrDefault<String>(doc.name, 'this meet');
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
              if (next) {
                final ok = await _confirmEntryDialog(context, meetName);
                if (!context.mounted) {
                  return;
                }
                if (ok == true) {
                  await _setEnteredState(entered: true, hasAlert: hasAlert);
                  if (!context.mounted) {
                    return;
                  }
                  HapticFeedback.lightImpact();
                  _enteredCelebrateController.forward(from: 0);
                }
              } else {
                await _setEnteredState(entered: false, hasAlert: hasAlert);
                if (!context.mounted) {
                  return;
                }
                _enteredCelebrateController.reset();
              }
            },
          ),
        ),
      ],
    );
  }

  /// For pending sign-up: `interested` + `has_alert` when the user wants reminders.
  Widget _buildNotifyWhenSignUpOpensRow(
    BuildContext context,
    MeetPreferenceStatus status,
    bool hasAlert,
  ) {
    final theme = FlutterFlowTheme.of(context);
    final notifyOn = hasAlert &&
        (status == MeetPreferenceStatus.interested ||
            status == MeetPreferenceStatus.entered);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            'I want to enter — notify me when sign-up opens',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.sora(
              fontSize: 14.0,
              fontWeight: FontWeight.w600,
              color: _slateTitle,
              height: 1.2,
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
            value: notifyOn,
            onChanged: (next) async {
              if (next) {
                await _mergePref(
                  hasAlert: true,
                  status: MeetPreferenceStatus.interested,
                );
                if (context.mounted) {
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'You’ll get a reminder when sign-up opens. To see every meet you’re following, tap the tune icon on Meets, then turn on «Interested only».',
                        style: GoogleFonts.sora(
                          fontSize: 14.0,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                        ),
                      ),
                      duration: const Duration(seconds: 5),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } else {
                await _mergePref(
                  hasAlert: false,
                  status: MeetPreferenceStatus.skipped,
                );
              }
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
    bool entered,
  ) {
    final hasUrl = doc.hasEntryPage;
    final url = doc.entryUrl.trim();
    final theme = FlutterFlowTheme.of(context);
    final viewOnlyMeet = _signupsClosedContext(doc);
    final signupPending = _meetSignupPendingContext(doc);
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
          side: const BorderSide(color: _electricBlue, width: 1.5),
          padding: pad,
          minimumSize: const Size(double.infinity, 48.0),
          shape: const RoundedRectangleBorder(borderRadius: _actionRadius),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.list_alt_rounded,
              size: 20.0,
              color: hasUrl ? _electricBlue : theme.secondaryText,
            ),
            const SizedBox(width: 10.0),
            Text(
              'View Entries',
              style: labelStyle.copyWith(
                color: hasUrl ? _electricBlue : theme.secondaryText,
              ),
            ),
          ],
        ),
      );
    }

    if (viewOnlyMeet) {
      return OutlinedButton(
        onPressed: hasUrl ? open : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: _electricBlue,
          backgroundColor: Colors.white,
          side: const BorderSide(color: _electricBlue, width: 1.5),
          padding: pad,
          minimumSize: const Size(double.infinity, 48.0),
          shape: const RoundedRectangleBorder(borderRadius: _actionRadius),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.open_in_new_rounded,
              size: 20.0,
              color: hasUrl ? _electricBlue : theme.secondaryText,
            ),
            const SizedBox(width: 10.0),
            Text(
              'View the meet',
              style: labelStyle.copyWith(
                color: hasUrl ? _electricBlue : theme.secondaryText,
              ),
            ),
          ],
        ),
      );
    }

    if (signupPending) {
      return ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.accent3,
          foregroundColor: theme.secondaryText,
          disabledBackgroundColor: theme.accent3,
          disabledForegroundColor: theme.secondaryText,
          padding: pad,
          minimumSize: const Size(double.infinity, 48.0),
          elevation: 0,
          shape: const RoundedRectangleBorder(borderRadius: _actionRadius),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.schedule_rounded,
              size: 20.0,
              color: theme.secondaryText,
            ),
            const SizedBox(width: 10.0),
            Text(
              'Sign Up',
              style: labelStyle.copyWith(color: theme.secondaryText),
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
          Icon(Icons.open_in_new_rounded,
              size: 20.0, color: theme.primaryBtnText),
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

/// Owns the note [TextEditingController] so it is disposed after the sheet route
/// finishes teardown (avoids "used after being disposed" on save).
class _ParentNoteEditorSheet extends StatefulWidget {
  const _ParentNoteEditorSheet({
    required this.initialText,
    required this.onSave,
  });

  final String initialText;
  final Future<bool> Function(String text) onSave;

  @override
  State<_ParentNoteEditorSheet> createState() => _ParentNoteEditorSheetState();
}

class _ParentNoteEditorSheetState extends State<_ParentNoteEditorSheet> {
  late final TextEditingController _controller;

  static const Color _sheetSlateTitle = Color(0xFF1E293B);
  static const Color _sheetCardBorder = Color(0xFFE2E8F0);
  static const Color _sheetElectricBlue = Color(0xFF007AFF);

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Parent note',
                style: GoogleFonts.sora(
                  fontSize: 17.0,
                  fontWeight: FontWeight.w700,
                  color: _sheetSlateTitle,
                ),
              ),
              const SizedBox(height: 12.0),
              TextField(
                controller: _controller,
                autofocus: true,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                style: GoogleFonts.sora(
                  fontSize: 15.0,
                  color: _sheetSlateTitle,
                ),
                decoration: InputDecoration(
                  hintText: 'e.g. Bring extra towels…',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide:
                        const BorderSide(color: _sheetCardBorder, width: 1.0),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide:
                        const BorderSide(color: _sheetCardBorder, width: 1.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: const BorderSide(
                      color: _sheetElectricBlue,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16.0),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _sheetElectricBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
                onPressed: () async {
                  final text = _controller.text.trim();
                  final ok = await widget.onSave(text);
                  if (ok && context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
                child: Text(
                  'Save',
                  style: GoogleFonts.sora(
                    fontWeight: FontWeight.w600,
                    fontSize: 15.0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dashed rounded outline (BorderStyle.dashed is not supported on all Flutter targets).
class _DashedRRectPainter extends CustomPainter {
  _DashedRRectPainter({
    required this.color,
    required this.borderRadius,
    required this.strokeWidth,
  });

  final Color color;
  final double borderRadius;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = strokeWidth / 2.0;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final r = RRect.fromRectAndRadius(
      rect,
      Radius.circular(math.max(0.0, borderRadius - inset)),
    );
    final path = Path()..addRRect(r);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    const dash = 5.0;
    const gap = 3.0;
    for (final ui.PathMetric metric in path.computeMetrics()) {
      var dist = 0.0;
      while (dist < metric.length) {
        final next = math.min(dist + dash, metric.length);
        canvas.drawPath(metric.extractPath(dist, next), paint);
        dist = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.borderRadius != borderRadius ||
      oldDelegate.strokeWidth != strokeWidth;
}
