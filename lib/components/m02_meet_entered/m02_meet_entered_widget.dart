import 'dart:math' as math;
import 'dart:ui' as ui;

import '/auth/firebase_auth/auth_util.dart';
import '/backend/meet_preferences_api.dart';
import '/backend/schema/meet_preferences_record.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'm02_meet_entered_model.dart';
export 'm02_meet_entered_model.dart';

enum _DeadlineUrgency { none, approaching, passed }

/// Visual state for paired YES / NO actions (no implicit default).
enum _BinaryChoice { none, no, yes }

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
  bool _swipeSkipPanelOpen = false;

  /// Plays when the user turns “I’ve entered this meet” on (after confirm).
  late final AnimationController _enteredCelebrateController;
  late final Animation<double> _celebrateScale;
  late final Animation<double> _celebrateFade;

  static const Color _slateTitle = Color(0xFF1E293B);
  static const Color _slateSecondary = Color(0xFF64748B);
  static const Color _electricBlue = Color(0xFF007AFF);
  static const Color _cardBorder = Color(0xFFE2E8F0);
  static const Color _verifiedGreen = Color(0xFF15803D);

  /// “Following” / interested (header heart), distinct from entered green.
  static const Color _followingHeart = Color(0xFFE11D48);

  /// Interested + reminders on (sign-up / alerts).
  static const Color _watchingAmber = Color(0xFFF59E0B);

  /// “Need decision” / no saved choice yet — light yellow stripe so it’s easy to spot.
  static const Color _untouchedStripe = Color(0xFFFDE047);

  /// Skipped — muted slate (no longer “action needed” like yellow/orange).
  static const Color _skippedFill = Color(0xFFE2E8F0);
  static const Color _skippedIcon = Color(0xFF64748B);
  static const Color _skippedStripe = Color(0xFF94A3B8);

  /// Pending entries / planning — orange family (complete sign-up or entries).
  static const Color _pendingEntriesFill = Color(0xFFFFEDD5);
  static const Color _pendingEntriesIcon = Color(0xFFEA580C);
  static const Color _pendingEntriesStripe = Color(0xFFFB923C);
  static const Color _parentNoteBg = Color(0xFFF8FAFC);
  static const Color _parentNoteDashBorder = Color(0xFFCBD5E1);
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
            'Sign-up isn’t open yet. Tap YES I’m going below if you plan to enter, then choose whether to get a reminder when registration opens.',
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
                      math.sin(_deadlinePulseController.value * 2.0 * math.pi);
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
    final tightBeforeLocation =
        _meetSignupPendingContext(m) && !_signupsClosedContext(m);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildLogisticsRow1DatesCountdown(m),
        const SizedBox(height: _logisticsRowGap),
        _buildLogisticsRow2Deadline(context, m, entered),
        SizedBox(
          height: tightBeforeLocation ? 0.0 : _logisticsRowGap,
        ),
        _buildLogisticsRow3LocationSheet(m),
      ],
    );
  }

  Future<bool> _mergePref({
    MeetPreferenceStatus? status,
    bool? hasAlert,
    bool? isHidden,
    bool? skipSelected,
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
        skipSelected: skipSelected,
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

  bool _eligibleForSwipeSkip({
    required bool hasPreference,
    required MeetPreferenceStatus status,
    required bool hasAlert,
    required bool skipSelected,
  }) {
    final needDecision = _meetCardIsUndecided(
      hasPreference: hasPreference,
      status: status,
      skipSelected: skipSelected,
    );
    final pendingEntries =
        _meetCardIsPendingEntriesLane(status: status, hasAlert: hasAlert);
    final remindMe = status == MeetPreferenceStatus.interested && hasAlert;
    return needDecision || pendingEntries || remindMe;
  }

  Future<bool> _showSwipeSkipActionPanel() async {
    if (_swipeSkipPanelOpen) {
      return false;
    }
    _swipeSkipPanelOpen = true;
    final shouldSkip = await showModalBottomSheet<bool>(
          context: context,
          useSafeArea: true,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
          ),
          builder: (sheetContext) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Skip this meet?',
                    style: GoogleFonts.sora(
                      fontSize: 16.0,
                      fontWeight: FontWeight.w700,
                      color: _slateTitle,
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    'You can restore skipped meets from Filters later.',
                    style: GoogleFonts.sora(
                      fontSize: 13.0,
                      fontWeight: FontWeight.w500,
                      color: _slateSecondary,
                    ),
                  ),
                  const SizedBox(height: 14.0),
                  OutlinedButton(
                    onPressed: () => Navigator.of(sheetContext).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _slateSecondary,
                      side: const BorderSide(color: _meetSecondaryOutline),
                      minimumSize: const Size(double.infinity, 42.0),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(10.0)),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(height: 8.0),
                  FilledButton(
                    onPressed: () => Navigator.of(sheetContext).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: _skippedIcon,
                      minimumSize: const Size(double.infinity, 42.0),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(10.0)),
                      ),
                    ),
                    child: const Text('Skip Meet'),
                  ),
                ],
              ),
            );
          },
        ) ??
        false;
    _swipeSkipPanelOpen = false;
    return shouldSkip;
  }

  Future<void> _applySwipeSkipWithUndo(
      MeetPreferencesRecord? previousPref) async {
    final ok = await _mergePref(
      status: MeetPreferenceStatus.skipped,
      hasAlert: false,
      skipSelected: true,
      isHidden: true,
    );
    if (!ok || !mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Meet skipped. You can view or restore skipped meets in Filters.',
        ),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            final meetId = widget.meetDoc?.reference.id;
            if (meetId == null || meetId.isEmpty) {
              return;
            }
            if (previousPref == null) {
              await deleteMeetPreference(currentUserUid, meetId);
              return;
            }
            await mergeMeetPreference(
              currentUserUid,
              meetId,
              status: previousPref.status,
              hasAlert: previousPref.hasAlert,
              isHidden: previousPref.isHidden,
              skipSelected: previousPref.skipSelected,
              notes: previousPref.notes,
            );
          },
        ),
      ),
    );
  }

  Widget _wrapSwipeToSkipIfEligible({
    required Widget child,
    required MeetPreferencesRecord? pref,
    required bool hasPreference,
    required MeetPreferenceStatus status,
    required bool hasAlert,
    required bool skipSelected,
  }) {
    if (!_eligibleForSwipeSkip(
      hasPreference: hasPreference,
      status: status,
      hasAlert: hasAlert,
      skipSelected: skipSelected,
    )) {
      return child;
    }
    final meetId = widget.meetDoc?.reference.id ?? '';
    return ClipRRect(
      borderRadius: BorderRadius.circular(_meetCardCornerRadius),
      child: Dismissible(
        key: ValueKey<String>(
          'm02_swipe_${meetId}_${status.name}_${hasAlert ? 1 : 0}_${skipSelected ? 1 : 0}',
        ),
        direction: DismissDirection.endToStart,
        background: Container(
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(_meetCardCornerRadius),
          ),
        ),
        secondaryBackground: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsetsDirectional.only(end: 20.0),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(_meetCardCornerRadius),
          ),
          child: const Icon(
            Icons.archive_outlined,
            color: _slateSecondary,
            size: 24.0,
          ),
        ),
        confirmDismiss: (_) async {
          HapticFeedback.mediumImpact();
          final shouldSkip = await _showSwipeSkipActionPanel();
          if (shouldSkip) {
            await _applySwipeSkipWithUndo(pref);
          }
          return false;
        },
        child: child,
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

    /// No Firestore doc yet → start collapsed so the list stays scannable.
    final hidden = pref?.isHidden ?? true;

    if (hidden) {
      final theme = FlutterFlowTheme.of(context);
      final hStatus = pref?.status ?? MeetPreferenceStatus.skipped;
      final hHasAlert = pref?.hasAlert ?? false;
      final hEntered = hStatus == MeetPreferenceStatus.entered;
      final hHasPreference = pref != null;
      final hSkipSelected = pref?.skipSelected ?? false;
      final hAccent = _meetCardStatusAccentColor(
        hasPreference: hHasPreference,
        status: hStatus,
        entered: hEntered,
        hasAlert: hHasAlert,
        skipSelected: hSkipSelected,
      );
      final hTagLabel = _meetStatusTagLabel(
        hasPreference: hHasPreference,
        status: hStatus,
        entered: hEntered,
        hasAlert: hHasAlert,
        skipSelected: hSkipSelected,
      );
      // Top inset so status pill (Positioned with negative top) paints inside layout bounds
      // and is not clipped by ListView / outer ClipRRect on Dismissible.
      final hiddenCard = Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(20.0, 10.0, 20.0, 12.0),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(_meetCardCornerRadius),
              clipBehavior: Clip.antiAlias,
              child: Container(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                      16.0, 14.0, 8.0, 10.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          valueOrDefault<String>(doc.name, 'Meet'),
                          maxLines: 8,
                          softWrap: true,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.sora(
                            fontSize: 12.0,
                            fontWeight: FontWeight.w500,
                            fontStyle: FontStyle.italic,
                            height: 1.25,
                            color: theme.secondaryText,
                          ),
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsetsDirectional.only(
                            start: 6.0,
                            top: 0.0,
                            bottom: 0.0,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => _mergePref(isHidden: false),
                        child: Text(
                          'Show',
                          style: GoogleFonts.sora(
                            fontSize: 13.0,
                            fontWeight: FontWeight.w600,
                            color: _electricBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _buildMeetCardFramePaintOverlay(hAccent),
            PositionedDirectional(
              start: 10.0,
              top: -6.0,
              child: _buildMeetStatusTagPill(
                context,
                label: hTagLabel,
                accent: hAccent,
                compact: true,
              ),
            ),
          ],
        ),
      );
      return _wrapSwipeToSkipIfEligible(
        child: hiddenCard,
        pref: pref,
        hasPreference: hHasPreference,
        status: hStatus,
        hasAlert: hHasAlert,
        skipSelected: hSkipSelected,
      );
    }

    const innerHPad = 20.0;
    final hasPreference = pref != null;
    final status = pref?.status ?? MeetPreferenceStatus.skipped;
    final hasAlert = pref?.hasAlert ?? false;
    final entered = status == MeetPreferenceStatus.entered;
    final skipSelected = pref?.skipSelected ?? false;
    final wantsToEnter = entered ||
        status == MeetPreferenceStatus.planning ||
        status == MeetPreferenceStatus.interested;
    final pendingEntriesLane = _meetCardIsPendingEntriesLane(
      status: status,
      hasAlert: hasAlert,
    );
    final isExplicitNotGoing =
        hasPreference && skipSelected && status == MeetPreferenceStatus.skipped;
    final remindMeLane = status == MeetPreferenceStatus.interested && hasAlert;
    final suppressDisabledSignupButton = pendingEntriesLane || remindMeLane;
    final meetUndecided = _meetCardIsUndecided(
      hasPreference: hasPreference,
      status: status,
      skipSelected: skipSelected,
    );
    final viewOnlyMeet = _signupsClosedContext(doc);
    final pendingViewOnlyPair = pendingEntriesLane &&
        viewOnlyMeet &&
        !meetUndecided &&
        !isExplicitNotGoing;
    final showNotInterestedHeaderIcon = !entered &&
        !(status == MeetPreferenceStatus.skipped && skipSelected) &&
        !_meetCardIsUndecided(
          hasPreference: hasPreference,
          status: status,
          skipSelected: skipSelected,
        ) &&
        !_meetCardIsPendingEntriesLane(status: status, hasAlert: hasAlert);

    /// Space for [Stack]-positioned header actions (40px targets; two when slotted actions show).
    final titleEndInsetForHeaderActions =
        showNotInterestedHeaderIcon ? 84.0 : 44.0;
    final statusAccent = _meetCardStatusAccentColor(
      hasPreference: hasPreference,
      status: status,
      entered: entered,
      hasAlert: hasAlert,
      skipSelected: skipSelected,
    );
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
    // Top inset for corner disk + tag row (negative [PositionedDirectional.top]).
    final fullCard = Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20.0, 16.0, 20.0, 30.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(_meetCardCornerRadius),
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
              borderRadius: BorderRadius.circular(_meetCardCornerRadius),
              child: Opacity(
                opacity: isExplicitNotGoing ? 0.5 : 1.0,
                child: Container(
                  color: Colors.white,
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
                          padding: const EdgeInsets.only(top: 6.0, bottom: 4.0),
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
                            _buildMeetDecisionRows(
                              context,
                              doc: doc,
                              status: status,
                              hasAlert: hasAlert,
                              hasPreference: hasPreference,
                              skipSelected: skipSelected,
                            ),
                            const SizedBox(height: 16.0),
                            if (pendingViewOnlyPair)
                              _buildPendingEntriesViewOnlyActionRow(
                                context,
                                doc,
                              )
                            else ...[
                              SizedBox(
                                width: double.infinity,
                                child: _buildEntryUrlButton(
                                  context,
                                  doc,
                                  status,
                                  entered,
                                  wantsToEnter,
                                  meetUndecided: meetUndecided,
                                  isPendingEntriesLane: pendingEntriesLane,
                                  isExplicitNotGoing: isExplicitNotGoing,
                                  suppressDisabledSignupButton:
                                      suppressDisabledSignupButton,
                                ),
                              ),
                              if (pendingEntriesLane) ...[
                                const SizedBox(height: 10.0),
                                SizedBox(
                                  width: double.infinity,
                                  child: _buildNotGoingAnymoreButton(context),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ].divide(const SizedBox(height: 12.0)),
                    ),
                  ),
                ),
              ),
            ),
            _buildMeetCardFramePaintOverlay(statusAccent),
            ..._buildMeetCornerStateOverlay(
              context,
              hasPreference: hasPreference,
              status: status,
              entered: entered,
              hasAlert: hasAlert,
              skipSelected: skipSelected,
            ),
            ..._buildMeetCardActionOverlay(
              context,
              hasPreference: hasPreference,
              status: status,
              entered: entered,
              hasAlert: hasAlert,
              skipSelected: skipSelected,
            ),
          ],
        ),
      ),
    );
    return _wrapSwipeToSkipIfEligible(
      child: fullCard,
      pref: pref,
      hasPreference: hasPreference,
      status: status,
      hasAlert: hasAlert,
      skipSelected: skipSelected,
    );
  }

  static const BorderRadius _actionRadius =
      BorderRadius.all(Radius.circular(12.0));

  /// Meet-card CTAs (Submit / View / Sign Up / Not Going / Change Mind).
  static const double _meetActionButtonHeight = 40.0;
  static const EdgeInsets _meetActionButtonPadding =
      EdgeInsets.symmetric(horizontal: 16.0);

  /// Side-by-side Submit / Not Going: a bit shorter than full-width 40px CTAs.
  static const double _meetPendingPairButtonHeight = 36.0;

  /// Tighter horizontal inset so both labels fit without clipping.
  static const EdgeInsets _meetPendingPairPadding =
      EdgeInsets.symmetric(horizontal: 10.0, vertical: 0.0);
  static const Color _meetSecondaryOutline = Color(0xFFE2E8F0);

  TextStyle _meetPrimaryButtonTextStyle(Color color) => GoogleFonts.sora(
        fontWeight: FontWeight.w600,
        fontSize: 14.0,
        color: color,
      );

  TextStyle _meetSecondaryButtonTextStyle() => GoogleFonts.sora(
        fontWeight: FontWeight.w600,
        fontSize: 14.0,
        color: _slateSecondary,
      );

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
                    color: _parentNoteDashBorder,
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

  /// Stripe color for the meet card left edge; matches corner status disk colors.
  Color _meetCardStatusAccentColor({
    required bool hasPreference,
    required MeetPreferenceStatus status,
    required bool entered,
    required bool hasAlert,
    required bool skipSelected,
  }) {
    if (!hasPreference) {
      return _untouchedStripe;
    }
    if (entered) {
      return _verifiedGreen;
    }
    if (status == MeetPreferenceStatus.interested && hasAlert) {
      return _watchingAmber;
    }
    if (status == MeetPreferenceStatus.planning ||
        (status == MeetPreferenceStatus.interested && !hasAlert)) {
      return _pendingEntriesStripe;
    }
    if (status == MeetPreferenceStatus.interested) {
      return _followingHeart;
    }
    if (skipSelected &&
        status == MeetPreferenceStatus.skipped &&
        hasPreference) {
      return _skippedStripe;
    }
    return _untouchedStripe;
  }

  static const double _meetCardCornerRadius = 12.0;

  /// Paints a uniform frame under badges/tags so the pill hides the stroke (no line through label).
  Widget _buildMeetCardFramePaintOverlay(Color accent) {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _MeetCardFramePainter(accent: accent),
          child: const SizedBox.expand(),
        ),
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

  /// No Firestore doc, or saved neutral row — user still owes a YES/NO on “Enter this meet?”.
  bool _meetCardIsUndecided({
    required bool hasPreference,
    required MeetPreferenceStatus status,
    required bool skipSelected,
  }) {
    if (!hasPreference) {
      return true;
    }
    return status == MeetPreferenceStatus.skipped && !skipSelected;
  }

  /// Same cases as the “Pending entries” tag (planning / interested without alerts yet).
  bool _meetCardIsPendingEntriesLane({
    required MeetPreferenceStatus status,
    required bool hasAlert,
  }) {
    return status == MeetPreferenceStatus.planning ||
        (status == MeetPreferenceStatus.interested && !hasAlert);
  }

  /// Header actions in the [Stack] so they do not reserve a full-width row above the title.
  List<Widget> _buildMeetCardActionOverlay(
    BuildContext context, {
    required bool hasPreference,
    required MeetPreferenceStatus status,
    required bool entered,
    required bool hasAlert,
    required bool skipSelected,
  }) {
    return [
      PositionedDirectional(
        top: 2.0,
        end: 2.0,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!entered &&
                !(status == MeetPreferenceStatus.skipped && skipSelected) &&
                !_meetCardIsUndecided(
                  hasPreference: hasPreference,
                  status: status,
                  skipSelected: skipSelected,
                ) &&
                !_meetCardIsPendingEntriesLane(
                  status: status,
                  hasAlert: hasAlert,
                ))
              _meetHeaderIconAction(
                context: context,
                tooltip:
                    'Not interested — stop reminders and following for this meet',
                onTap: () async {
                  await _mergePref(
                    status: MeetPreferenceStatus.skipped,
                    hasAlert: false,
                    skipSelected: true,
                  );
                  if (context.mounted) {
                    HapticFeedback.selectionClick();
                  }
                },
                icon: Icons.not_interested_rounded,
                iconColor: _skippedIcon,
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

  double _cornerGlyphSize(double diameter, double atFullSize) {
    return atFullSize * diameter / _cornerStateBadgeSize;
  }

  /// Same status disks as the corner overlay; [diameter] smaller for minimized rows.
  Widget? _buildMeetPreferenceStatusBadge(
    BuildContext context, {
    required bool hasPreference,
    required MeetPreferenceStatus status,
    required bool entered,
    required bool hasAlert,
    required bool skipSelected,
    double diameter = _cornerStateBadgeSize,
  }) {
    if (entered) {
      return _buildCornerEnteredBadge(context, diameter: diameter);
    }
    if (status == MeetPreferenceStatus.interested && hasAlert) {
      return _buildCornerInterestedRemindersBadge(context, diameter: diameter);
    }
    if (status == MeetPreferenceStatus.planning ||
        (status == MeetPreferenceStatus.interested && !hasAlert)) {
      return _buildCornerPlanningBadge(context, diameter: diameter);
    }
    if (status == MeetPreferenceStatus.interested) {
      return _buildCornerInterestedBadge(context, diameter: diameter);
    }
    if (skipSelected &&
        status == MeetPreferenceStatus.skipped &&
        hasPreference) {
      return _buildCornerSkippedBadge(context, diameter: diameter);
    }
    return null;
  }

  String _meetStatusTagLabel({
    required bool hasPreference,
    required MeetPreferenceStatus status,
    required bool entered,
    required bool hasAlert,
    required bool skipSelected,
  }) {
    if (!hasPreference) {
      return 'Need Decision';
    }
    if (entered) {
      return 'Entered';
    }
    if (status == MeetPreferenceStatus.interested && hasAlert) {
      return 'Remind me';
    }
    if (status == MeetPreferenceStatus.planning ||
        (status == MeetPreferenceStatus.interested && !hasAlert)) {
      return 'Pending entries';
    }
    if (skipSelected &&
        status == MeetPreferenceStatus.skipped &&
        hasPreference) {
      return 'Not Going';
    }
    return 'Need Decision';
  }

  /// Solid (opaque) fill so the tag never shows the card edge through it.
  Color _opaqueMeetTagFill(Color accent, {required bool compact}) {
    return Color.lerp(
      Colors.white,
      accent,
      compact ? 0.30 : 0.36,
    )!;
  }

  Color _opaqueMeetTagBorder(Color accent) {
    return Color.lerp(accent, _slateTitle, 0.42)!;
  }

  /// Small pill beside the corner disk; sits in the card [Stack] (outside [ClipRRect]).
  Widget _buildMeetStatusTagPill(
    BuildContext context, {
    required String label,
    required Color accent,
    required bool compact,
  }) {
    final padH = compact ? 6.0 : 8.0;
    final padV = compact ? 3.0 : 4.0;
    final fontSize = compact ? 9.0 : 10.5;
    final fill = _opaqueMeetTagFill(accent, compact: compact);
    final stroke = _opaqueMeetTagBorder(accent);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(999.0),
        border: Border.all(
          color: stroke,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 5.0,
            offset: const Offset(0.0, 1.5),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.sora(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.12,
            height: 1.0,
            color: _slateTitle,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildMeetCornerStateOverlay(
    BuildContext context, {
    required bool hasPreference,
    required MeetPreferenceStatus status,
    required bool entered,
    required bool hasAlert,
    required bool skipSelected,
  }) {
    final badge = _buildMeetPreferenceStatusBadge(
      context,
      hasPreference: hasPreference,
      status: status,
      entered: entered,
      hasAlert: hasAlert,
      skipSelected: skipSelected,
      diameter: _cornerStateBadgeSize,
    );
    final accent = _meetCardStatusAccentColor(
      hasPreference: hasPreference,
      status: status,
      entered: entered,
      hasAlert: hasAlert,
      skipSelected: skipSelected,
    );
    final tagLabel = _meetStatusTagLabel(
      hasPreference: hasPreference,
      status: status,
      entered: entered,
      hasAlert: hasAlert,
      skipSelected: skipSelected,
    );
    const half = _cornerStateBadgeSize / 2.0;
    final hasDisk = badge != null;
    return [
      PositionedDirectional(
        start: hasDisk ? -half : 10.0,
        top: hasDisk ? -half : -6.0,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (badge != null) ...[
              badge,
              const SizedBox(width: 6.0),
            ],
            _buildMeetStatusTagPill(
              context,
              label: tagLabel,
              accent: accent,
              compact: false,
            ),
          ],
        ),
      ),
    ];
  }

  Widget _buildCornerStateDisk({
    required Color backgroundColor,
    required Widget child,
    double diameter = _cornerStateBadgeSize,
  }) {
    final borderW = diameter >= 24.0 ? 2.5 : 2.0;
    final blur = diameter >= 24.0 ? 8.0 : 5.0;
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: borderW),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: blur,
            offset: const Offset(0.0, 2.0),
          ),
        ],
      ),
      child: Center(child: child),
    );
  }

  Widget _buildCornerEnteredBadge(
    BuildContext context, {
    double diameter = _cornerStateBadgeSize,
  }) {
    final g = _cornerGlyphSize(diameter, 16.0);
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
                diameter: diameter,
                backgroundColor: _verifiedGreen,
                child: Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: g,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCornerInterestedBadge(
    BuildContext context, {
    double diameter = _cornerStateBadgeSize,
  }) {
    final g = _cornerGlyphSize(diameter, 14.0);
    return Tooltip(
      message:
          'Interested — following this meet. Turn on “notify when sign-up opens” for reminders, or use the Meets filter (tune → Interested only) to see all followed meets.',
      child: _buildCornerStateDisk(
        diameter: diameter,
        backgroundColor: _followingHeart,
        child: Icon(
          Icons.favorite_rounded,
          color: Colors.white,
          size: g,
        ),
      ),
    );
  }

  Widget _buildCornerInterestedRemindersBadge(
    BuildContext context, {
    double diameter = _cornerStateBadgeSize,
  }) {
    final g = _cornerGlyphSize(diameter, 15.0);
    return Tooltip(
      message:
          'Reminders on — you’ll get updates about this meet. See all followed meets in the Meets filter (tune icon → Interested only).',
      child: _buildCornerStateDisk(
        diameter: diameter,
        backgroundColor: _watchingAmber,
        child: Icon(
          Icons.notifications_active_rounded,
          color: Colors.white,
          size: g,
        ),
      ),
    );
  }

  Widget _buildCornerPlanningBadge(
    BuildContext context, {
    double diameter = _cornerStateBadgeSize,
  }) {
    final g = _cornerGlyphSize(diameter, 15.0);
    return Tooltip(
      message:
          'Pending entries — you want to enter this meet, but entries are not confirmed yet.',
      child: _buildCornerStateDisk(
        diameter: diameter,
        backgroundColor: _pendingEntriesFill,
        child: Icon(
          Icons.pending_actions_rounded,
          color: _pendingEntriesIcon,
          size: g,
        ),
      ),
    );
  }

  Widget _buildCornerSkippedBadge(
    BuildContext context, {
    double diameter = _cornerStateBadgeSize,
  }) {
    final g = _cornerGlyphSize(diameter, 14.0);
    return Tooltip(
      message:
          'Not going — no reminders for this meet. Tap Change Mind below if you want to enter again.',
      child: _buildCornerStateDisk(
        diameter: diameter,
        backgroundColor: _skippedFill,
        child: Icon(
          Icons.close_rounded,
          color: _slateSecondary,
          size: g,
        ),
      ),
    );
  }

  String _verifiedTooltipMessage(BuildContext context) {
    // read: avoid listenable subscriptions from tooltip/badge subtree (semantics).
    final raw = context.read<FFAppState>().currentSwimmerName.trim();
    final firstName =
        raw.isEmpty ? 'Swimmer' : raw.split(RegExp(r'\s+')).first.trim();
    return 'Verified: $firstName is entered';
  }

  /// “Not going” or remind-me-watching cards: restore [MeetPreferenceStatus.planning]
  /// (pending entries) and clear skip / alerts.
  Widget _buildChangeMindButton(BuildContext context) {
    Future<void> onTap() async {
      await _mergePref(
        status: MeetPreferenceStatus.planning,
        hasAlert: false,
        skipSelected: false,
        isHidden: false,
      );
      if (context.mounted) {
        HapticFeedback.lightImpact();
      }
    }

    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: _slateSecondary,
        backgroundColor: Colors.transparent,
        side: const BorderSide(color: _meetSecondaryOutline, width: 1.0),
        padding: _meetActionButtonPadding,
        minimumSize: const Size(double.infinity, _meetActionButtonHeight),
        maximumSize: const Size(double.infinity, _meetActionButtonHeight),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: const RoundedRectangleBorder(borderRadius: _actionRadius),
        visualDensity: VisualDensity.compact,
      ),
      child: Text(
        'Change Mind',
        style: _meetSecondaryButtonTextStyle(),
      ),
    );
  }

  /// Not-decided cards: wide “YES I’m going” + compact “Skip”.
  /// Uses [Material]/[InkWell] instead of [OutlinedButton] to avoid semantics merge churn
  /// with nested rows (see header actions note on `parentDataDirty`).
  Widget _buildNeedDecisionActionsRow(BuildContext context) {
    const chipRadius = BorderRadius.all(Radius.circular(10.0));
    Future<void> onYes() async {
      await _mergePref(
        status: MeetPreferenceStatus.planning,
        hasAlert: false,
        skipSelected: false,
        isHidden: false,
      );
      if (context.mounted) {
        HapticFeedback.lightImpact();
      }
    }

    Future<void> onSkip() async {
      await _mergePref(
        status: MeetPreferenceStatus.skipped,
        hasAlert: false,
        skipSelected: true,
        isHidden: false,
      );
      if (context.mounted) {
        _enteredCelebrateController.reset();
      }
    }

    Widget chip({
      required VoidCallback onTap,
      required Widget child,
      Color fillColor = Colors.white,
      BorderSide outline = const BorderSide(color: _cardBorder, width: 1.0),
      double? minHeight,
      EdgeInsetsGeometry padding =
          const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
      Color? splashColor,
      Color? highlightColor,
    }) {
      final h = minHeight ?? 44.0;
      final lockHeight = minHeight != null;
      return Material(
        color: fillColor,
        shape: RoundedRectangleBorder(
          side: outline,
          borderRadius: chipRadius,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: chipRadius,
          splashColor: splashColor,
          highlightColor: highlightColor,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: h,
              maxHeight: lockHeight ? h : double.infinity,
              minWidth: lockHeight ? 88.0 : 0.0,
            ),
            child: Padding(
              padding: padding,
              child: Center(child: child),
            ),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.fromSTEB(14.0, 12.0, 14.0, 12.0),
      decoration: BoxDecoration(
        color: _parentNoteBg,
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(color: _cardBorder, width: 1.0),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: chip(
              fillColor: _electricBlue,
              outline: BorderSide(
                color: Color.lerp(_electricBlue, Colors.black, 0.14)!,
                width: 1.0,
              ),
              splashColor: Colors.white.withValues(alpha: 0.22),
              highlightColor: Colors.white.withValues(alpha: 0.12),
              minHeight: _meetActionButtonHeight,
              padding: _meetActionButtonPadding,
              onTap: () {
                onYes();
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'YES',
                    style: GoogleFonts.sora(
                      fontWeight: FontWeight.w800,
                      fontSize: 14.0,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                  Text(
                    " I'm going",
                    style: GoogleFonts.sora(
                      fontWeight: FontWeight.w600,
                      fontSize: 14.0,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10.0),
          chip(
            onTap: () {
              onSkip();
            },
            minHeight: _meetActionButtonHeight,
            padding: _meetActionButtonPadding,
            child: Text(
              'Skip',
              style: GoogleFonts.sora(
                fontWeight: FontWeight.w600,
                fontSize: 14.0,
                color: _slateTitle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Follow-up steps only (after “Enter this meet?”); primary choice stays YES/NO.
  Widget _buildFollowUpToggleRow(
    BuildContext context, {
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = FlutterFlowTheme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.sora(
              fontSize: 14.0,
              fontWeight: FontWeight.w600,
              color: _slateTitle,
              height: 1.25,
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
          child: Switch(value: value, onChanged: onChanged),
        ),
      ],
    );
  }

  /// Gray band + label + NO / YES (matches meet-card mockup; avoids switch “off = NO”).
  Widget _buildBinaryChoiceBand(
    BuildContext context, {
    required String label,
    required _BinaryChoice selected,
    required Future<void> Function() onNo,
    required Future<void> Function() onYes,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.fromSTEB(14.0, 12.0, 14.0, 12.0),
      decoration: BoxDecoration(
        color: _parentNoteBg,
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(color: _cardBorder, width: 1.0),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.sora(
                fontSize: 14.0,
                fontWeight: FontWeight.w600,
                color: _slateSecondary,
                height: 1.25,
              ),
            ),
          ),
          const SizedBox(width: 10.0),
          _binaryNoChip(
            context,
            selected: selected,
            onPressed: () async {
              await onNo();
            },
          ),
          const SizedBox(width: 8.0),
          _binaryYesChip(
            context,
            selected: selected,
            onPressed: () async {
              await onYes();
            },
          ),
        ],
      ),
    );
  }

  Widget _binaryNoChip(
    BuildContext context, {
    required _BinaryChoice selected,
    required Future<void> Function() onPressed,
  }) {
    final on = selected == _BinaryChoice.no;
    return OutlinedButton(
      onPressed: () async {
        await onPressed();
      },
      style: OutlinedButton.styleFrom(
        foregroundColor: on ? _slateTitle : _slateSecondary,
        backgroundColor: Colors.white,
        side: BorderSide(
          color: on ? _slateTitle : _meetSecondaryOutline,
          width: on ? 2.0 : 1.0,
        ),
        padding: _meetActionButtonPadding,
        minimumSize: const Size(56.0, _meetActionButtonHeight),
        maximumSize: const Size(double.infinity, _meetActionButtonHeight),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: const RoundedRectangleBorder(borderRadius: _actionRadius),
        visualDensity: VisualDensity.compact,
      ),
      child: Text(
        'NO',
        style: GoogleFonts.sora(
          fontWeight: FontWeight.w800,
          fontSize: 13.0,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _binaryYesChip(
    BuildContext context, {
    required _BinaryChoice selected,
    required Future<void> Function() onPressed,
  }) {
    final on = selected == _BinaryChoice.yes;
    final muted = selected == _BinaryChoice.no;
    return FilledButton(
      onPressed: () async {
        await onPressed();
      },
      style: FilledButton.styleFrom(
        elevation: on ? 2.0 : 0.0,
        shadowColor:
            on ? _electricBlue.withValues(alpha: 0.25) : Colors.transparent,
        backgroundColor: muted
            ? _cardBorder
            : (on ? _electricBlue : _electricBlue.withValues(alpha: 0.92)),
        foregroundColor: muted ? _slateSecondary : Colors.white,
        padding: _meetActionButtonPadding,
        minimumSize: const Size(56.0, _meetActionButtonHeight),
        maximumSize: const Size(double.infinity, _meetActionButtonHeight),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: const RoundedRectangleBorder(borderRadius: _actionRadius),
        visualDensity: VisualDensity.compact,
      ),
      child: Text(
        'YES',
        style: GoogleFonts.sora(
          fontWeight: FontWeight.w800,
          fontSize: 13.0,
          letterSpacing: 0.4,
          color: muted ? _slateSecondary : Colors.white,
        ),
      ),
    );
  }

  Widget _buildMeetDecisionRows(
    BuildContext context, {
    required MonitoredMeetsRecord doc,
    required MeetPreferenceStatus status,
    required bool hasAlert,
    required bool hasPreference,
    required bool skipSelected,
  }) {
    final registrationPending = _meetSignupPendingContext(doc);
    final wantsToEnter = status == MeetPreferenceStatus.entered ||
        status == MeetPreferenceStatus.planning ||
        status == MeetPreferenceStatus.interested;
    final entered = status == MeetPreferenceStatus.entered;
    final skipped =
        skipSelected && status == MeetPreferenceStatus.skipped && hasPreference;
    final interestedPick = wantsToEnter
        ? _BinaryChoice.yes
        : (skipped ? _BinaryChoice.no : _BinaryChoice.none);
    final undecided = _meetCardIsUndecided(
      hasPreference: hasPreference,
      status: status,
      skipSelected: skipSelected,
    );
    final pendingEntriesLane = _meetCardIsPendingEntriesLane(
      status: status,
      hasAlert: hasAlert,
    );
    final remindMeLane = status == MeetPreferenceStatus.interested && hasAlert;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (undecided)
          _buildNeedDecisionActionsRow(context)
        else if (!pendingEntriesLane && !skipped && !entered && !remindMeLane)
          _buildBinaryChoiceBand(
            context,
            label: 'Enter this meet?',
            selected: interestedPick,
            onNo: () async {
              await _mergePref(
                status: MeetPreferenceStatus.skipped,
                hasAlert: false,
                skipSelected: true,
                isHidden: false,
              );
              if (context.mounted) {
                _enteredCelebrateController.reset();
              }
            },
            onYes: () async {
              await _mergePref(
                status: MeetPreferenceStatus.planning,
                hasAlert: false,
                skipSelected: false,
              );
              if (context.mounted) {
                HapticFeedback.lightImpact();
              }
            },
          ),
        if (skipped)
          SizedBox(
            width: double.infinity,
            child: _buildChangeMindButton(context),
          ),
        if (wantsToEnter && registrationPending) ...[
          const SizedBox(height: 10.0),
          _buildNotifyWhenSignUpOpensRow(
            context,
            status,
            hasAlert,
          ),
        ],
        if (wantsToEnter && !registrationPending) ...[
          const SizedBox(height: 10.0),
          _buildFollowUpToggleRow(
            context,
            label: 'Have you created your entries?',
            value: entered,
            onChanged: (next) async {
              if (next) {
                await _mergePref(
                  status: MeetPreferenceStatus.entered,
                  hasAlert: false,
                  skipSelected: false,
                );
                if (context.mounted) {
                  HapticFeedback.lightImpact();
                  _enteredCelebrateController.forward(from: 0);
                }
              } else {
                await _mergePref(
                  status: MeetPreferenceStatus.planning,
                  hasAlert: false,
                );
                if (context.mounted) {
                  _enteredCelebrateController.reset();
                }
              }
            },
          ),
        ],
        if (remindMeLane) ...[
          const SizedBox(height: 10.0),
          SizedBox(
            width: double.infinity,
            child: _buildChangeMindButton(context),
          ),
        ],
      ],
    );
  }

  /// For pending sign-up: `interested` + `has_alert` when the user wants reminders.
  Widget _buildNotifyWhenSignUpOpensRow(
    BuildContext context,
    MeetPreferenceStatus status,
    bool hasAlert,
  ) {
    final notifyOn = hasAlert &&
        (status == MeetPreferenceStatus.interested ||
            status == MeetPreferenceStatus.entered);
    return _buildFollowUpToggleRow(
      context,
      label: 'Want a reminder when sign-up opens?',
      value: notifyOn,
      onChanged: (next) async {
        if (next) {
          await _mergePref(
            hasAlert: true,
            status: MeetPreferenceStatus.interested,
            skipSelected: false,
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
            status: MeetPreferenceStatus.planning,
            skipSelected: false,
          );
        }
      },
    );
  }

  Widget _buildNotGoingAnymoreButton(BuildContext context) {
    return OutlinedButton(
      onPressed: () async {
        await _mergePref(
          status: MeetPreferenceStatus.skipped,
          hasAlert: false,
          skipSelected: true,
          isHidden: false,
        );
        if (context.mounted) {
          _enteredCelebrateController.reset();
        }
      },
      style: OutlinedButton.styleFrom(
        foregroundColor: _slateSecondary,
        backgroundColor: Colors.transparent,
        side: const BorderSide(color: _meetSecondaryOutline, width: 1.0),
        padding: _meetActionButtonPadding,
        minimumSize: const Size(double.infinity, _meetActionButtonHeight),
        maximumSize: const Size(double.infinity, _meetActionButtonHeight),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: const RoundedRectangleBorder(borderRadius: _actionRadius),
        visualDensity: VisualDensity.compact,
      ),
      child: Text(
        'Not Going',
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _meetSecondaryButtonTextStyle(),
      ),
    );
  }

  /// Pending entries on a view-only meet: compact primary [FilledButton] + text opt-out.
  Widget _buildPendingEntriesViewOnlyActionRow(
    BuildContext context,
    MonitoredMeetsRecord doc,
  ) {
    final hasUrl = doc.hasEntryPage;
    final url = doc.entryUrl.trim();
    final theme = FlutterFlowTheme.of(context);

    Future<void> open() async {
      if (!hasUrl) {
        return;
      }
      await launchURL(url);
    }

    Future<void> onNotGoing() async {
      await _mergePref(
        status: MeetPreferenceStatus.skipped,
        hasAlert: false,
        skipSelected: true,
        isHidden: false,
      );
      if (context.mounted) {
        _enteredCelebrateController.reset();
      }
    }

    final pendingPrimaryStyle = FilledButton.styleFrom(
      backgroundColor: _electricBlue,
      foregroundColor: theme.primaryBtnText,
      disabledBackgroundColor: theme.accent3,
      disabledForegroundColor: theme.secondaryText,
      elevation: hasUrl ? 2.0 : 0.0,
      shadowColor: _electricBlue.withValues(alpha: 0.28),
      padding: _meetPendingPairPadding,
      minimumSize: const Size(double.infinity, _meetPendingPairButtonHeight),
      maximumSize: const Size(double.infinity, _meetPendingPairButtonHeight),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: const RoundedRectangleBorder(borderRadius: _actionRadius),
      visualDensity: VisualDensity.compact,
    );
    final pendingSecondaryStyle = OutlinedButton.styleFrom(
      foregroundColor: _slateSecondary,
      backgroundColor: Colors.transparent,
      side: const BorderSide(color: _meetSecondaryOutline, width: 1.0),
      padding: _meetPendingPairPadding,
      minimumSize: const Size(double.infinity, _meetPendingPairButtonHeight),
      maximumSize: const Size(double.infinity, _meetPendingPairButtonHeight),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: const RoundedRectangleBorder(borderRadius: _actionRadius),
      visualDensity: VisualDensity.compact,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 3,
          child: FilledButton(
            onPressed: hasUrl ? open : null,
            style: pendingPrimaryStyle,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Submit Entries',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: _meetPrimaryButtonTextStyle(
                    hasUrl ? theme.primaryBtnText : theme.secondaryText,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10.0),
        Expanded(
          flex: 2,
          child: OutlinedButton(
            onPressed: onNotGoing,
            style: pendingSecondaryStyle,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: Text(
                  'Not Going',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: _meetSecondaryButtonTextStyle(),
                ),
              ),
            ),
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
    bool wantsToEnter, {
    required bool meetUndecided,
    required bool isPendingEntriesLane,
    required bool isExplicitNotGoing,
    required bool suppressDisabledSignupButton,
  }) {
    if (meetUndecided || isExplicitNotGoing) {
      return const SizedBox.shrink();
    }
    final hasUrl = doc.hasEntryPage;
    final url = doc.entryUrl.trim();
    final theme = FlutterFlowTheme.of(context);
    final viewOnlyMeet = _signupsClosedContext(doc);
    final signupPending = _meetSignupPendingContext(doc);

    Future<void> open() async {
      if (!hasUrl) {
        return;
      }
      await launchURL(url);
    }

    if (entered) {
      return FilledButton(
        onPressed: hasUrl ? open : null,
        style: FilledButton.styleFrom(
          backgroundColor: _electricBlue,
          foregroundColor: theme.primaryBtnText,
          disabledBackgroundColor: theme.accent3,
          disabledForegroundColor: theme.secondaryText,
          elevation: hasUrl ? 2.0 : 0.0,
          shadowColor: _electricBlue.withValues(alpha: 0.28),
          padding: _meetActionButtonPadding,
          minimumSize: const Size(double.infinity, _meetActionButtonHeight),
          maximumSize: const Size(double.infinity, _meetActionButtonHeight),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: const RoundedRectangleBorder(borderRadius: _actionRadius),
          visualDensity: VisualDensity.compact,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.list_alt_rounded,
              size: 18.0,
              color: hasUrl ? theme.primaryBtnText : theme.secondaryText,
            ),
            const SizedBox(width: 8.0),
            Text(
              'View Entries',
              style: _meetPrimaryButtonTextStyle(
                hasUrl ? theme.primaryBtnText : theme.secondaryText,
              ),
            ),
          ],
        ),
      );
    }

    if (viewOnlyMeet) {
      if (isPendingEntriesLane) {
        return const SizedBox.shrink();
      }
      return FilledButton(
        onPressed: hasUrl ? open : null,
        style: FilledButton.styleFrom(
          backgroundColor: _electricBlue,
          foregroundColor: theme.primaryBtnText,
          disabledBackgroundColor: theme.accent3,
          disabledForegroundColor: theme.secondaryText,
          elevation: hasUrl ? 2.0 : 0.0,
          shadowColor: _electricBlue.withValues(alpha: 0.28),
          padding: _meetActionButtonPadding,
          minimumSize: const Size(double.infinity, _meetActionButtonHeight),
          maximumSize: const Size(double.infinity, _meetActionButtonHeight),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: const RoundedRectangleBorder(borderRadius: _actionRadius),
          visualDensity: VisualDensity.compact,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.open_in_new_rounded,
              size: 18.0,
              color: hasUrl ? theme.primaryBtnText : theme.secondaryText,
            ),
            const SizedBox(width: 8.0),
            Text(
              'View the meet',
              style: _meetPrimaryButtonTextStyle(
                hasUrl ? theme.primaryBtnText : theme.secondaryText,
              ),
            ),
          ],
        ),
      );
    }

    if (signupPending) {
      if (suppressDisabledSignupButton) {
        return const SizedBox.shrink();
      }
      return FilledButton(
        onPressed: null,
        style: FilledButton.styleFrom(
          disabledBackgroundColor: theme.accent3,
          disabledForegroundColor: theme.secondaryText,
          padding: _meetActionButtonPadding,
          minimumSize: const Size(double.infinity, _meetActionButtonHeight),
          maximumSize: const Size(double.infinity, _meetActionButtonHeight),
          elevation: 0,
          shape: const RoundedRectangleBorder(borderRadius: _actionRadius),
          visualDensity: VisualDensity.compact,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.schedule_rounded,
              size: 18.0,
              color: theme.secondaryText,
            ),
            const SizedBox(width: 8.0),
            Text(
              'Sign Up',
              style: _meetPrimaryButtonTextStyle(theme.secondaryText),
            ),
          ],
        ),
      );
    }

    if (!wantsToEnter) {
      return const SizedBox.shrink();
    }

    return FilledButton(
      onPressed: hasUrl ? open : null,
      style: FilledButton.styleFrom(
        backgroundColor: _electricBlue,
        foregroundColor: theme.primaryBtnText,
        disabledBackgroundColor: theme.accent3,
        disabledForegroundColor: theme.secondaryText,
        padding: _meetActionButtonPadding,
        minimumSize: const Size(double.infinity, _meetActionButtonHeight),
        maximumSize: const Size(double.infinity, _meetActionButtonHeight),
        elevation: 2,
        shadowColor: _electricBlue.withValues(alpha: 0.28),
        shape: const RoundedRectangleBorder(borderRadius: _actionRadius),
        visualDensity: VisualDensity.compact,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.open_in_new_rounded,
            size: 18.0,
            color: theme.primaryBtnText,
          ),
          const SizedBox(width: 8.0),
          Text(
            'Sign Up',
            style: _meetPrimaryButtonTextStyle(theme.primaryBtnText),
          ),
        ],
      ),
    );
  }
}

/// Owns the note [TextEditingController] so it is disposed after the sheet route
/// finishes teardown (avoids "used after being disposed" on save).
/// Uniform rounded stroke; drawn under badges/tags so the label masks the top edge.
class _MeetCardFramePainter extends CustomPainter {
  _MeetCardFramePainter({required this.accent});

  final Color accent;

  static const double _radius = 12.0;
  static const double _stroke = 1.75;
  static const Color _frameBlendBase = Color(0xFFE2E8F0);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final outer = RRect.fromRectAndRadius(rect, const Radius.circular(_radius));
    canvas.clipRRect(outer);

    final strokeColor = Color.lerp(accent, _frameBlendBase, 0.38)!;
    final inset = _stroke / 2;
    final inner = RRect.fromRectAndRadius(
      rect.deflate(inset),
      Radius.circular(math.max(0.0, _radius - inset)),
    );
    canvas.drawRRect(
      inner,
      Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _MeetCardFramePainter oldDelegate) =>
      oldDelegate.accent != accent;
}

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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0),
                  minimumSize: const Size(double.infinity, 40.0),
                  maximumSize: const Size(double.infinity, 40.0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  visualDensity: VisualDensity.compact,
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
                    fontSize: 14.0,
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
