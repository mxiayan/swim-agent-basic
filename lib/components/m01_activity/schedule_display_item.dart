import '/backend/schema/team_events_record.dart';
import '/backend/schedule_baseline.dart';

import 'team_events_schedule.dart'
    show
        normalizeCoachLocationForUi,
        standingGridBaselineHints;

/// Presentation row for Schedule tabs (backed by ``TeamEventsRecord``).
class ScheduleDisplayItem {
  ScheduleDisplayItem._({
    required this.record,
    required this.dateShortLabel,
    required this.timeDisplayLabel,
    this.drylandLabel,
    required this.locationDisplay,
    required this.squadLabel,
    required this.repeatSummary,
    required this.summaryPreview,
    required this.searchBlob,
  });

  final TeamEventsRecord record;
  final String dateShortLabel;
  final String timeDisplayLabel;
  final String? drylandLabel;
  final String locationDisplay;
  /// Upper-case chip text e.g. JUNIOR, SENIOR, mixed ALL.
  final String squadLabel;
  final String repeatSummary;
  final String summaryPreview;
  final String searchBlob;

  TeamEventType get type => record.eventType;

  /// Hides senior-only rows for junior viewers and junior-only rows for senior viewers.
  /// [ALL], ambiguous, and non-squad-specific rows stay visible for both.
  bool matchesPracticeTierFilter({required bool forJuniorTier}) {
    final s = squadLabel.toUpperCase().trim();
    if (s.isEmpty || s == 'ALL') return true;
    if (forJuniorTier) {
      return s != 'SENIOR';
    }
    return s != 'JUNIOR';
  }

  factory ScheduleDisplayItem.fromRecord(
    TeamEventsRecord e,
    List<ScheduleBaseline> baselines,
  ) {
    final hints = standingGridBaselineHints(e, baselines);
    final primary = _formatPrimaryTime(e);
    var timeDisp =
        primary.isNotEmpty ? primary : (hints.scheduleSummary ?? '');
    timeDisp = _compactPoolTimeLabel(timeDisp);
    final dry = hints.drylandLine != null
        ? _compactDrylandLabel(hints.drylandLine!)
        : null;

    return ScheduleDisplayItem._(
      record: e,
      dateShortLabel: _formatDateShort(e),
      timeDisplayLabel: timeDisp,
      drylandLabel: dry,
      locationDisplay: normalizeCoachLocationForUi(e.location),
      squadLabel: _squadLabel(e),
      repeatSummary:
          e.isRecurring && e.recurrenceRule.isNotEmpty
              ? humanRecurrence(e.recurrenceRule)
              : '',
      summaryPreview: _truncate(e.details, 140),
      searchBlob: _searchBlob(e),
    );
  }

  static String _compactPoolTimeLabel(String raw) {
    final trimmed = raw.trim();
    final m = RegExp(
      r'typical pool\s+(.+?)\s*\(Season schedules\)',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (m != null) {
      return m.group(1)!.trim();
    }
    return trimmed;
  }

  static String _compactDrylandLabel(String raw) {
    return raw.replaceFirst(RegExp(r'^Dryland\s+', caseSensitive: false), '');
  }

  static String _truncate(String s, int max) {
    final t = s.trim();
    if (t.length <= max) return t;
    return '${t.substring(0, max - 1)}…';
  }

  static String _searchBlob(TeamEventsRecord e) {
    return [
      e.title,
      e.details,
      e.location,
      e.subject,
      e.sender,
      e.sourceSection,
      ...e.appliesToGroups,
    ].join(' ').toLowerCase();
  }

  static String _squadLabel(TeamEventsRecord e) {
    final jr = _mentionsJunior(e);
    final sr = _mentionsSenior(e);
    if (jr && sr) return 'ALL';
    if (jr) return 'JUNIOR';
    if (sr) return 'SENIOR';
    if (e.appliesToGroups.isEmpty) return '';
    if (e.appliesToGroups.any((g) => g.toUpperCase() == 'ALL')) {
      return 'ALL';
    }
    return e.appliesToGroups.first.toUpperCase();
  }

  static bool _mentionsJunior(TeamEventsRecord e) {
    bool textHas(String s) {
      final t = s.toLowerCase();
      return t.contains('junior') ||
          t.contains('age group') ||
          t.contains('age-group') ||
          RegExp(r'\bjr\.?\b').hasMatch(t) ||
          t.contains('jr pm') ||
          t.contains('jr group');
    }

    if (textHas(e.title)) return true;
    for (final g in e.appliesToGroups) {
      if (textHas(g)) return true;
    }
    if (textHas(e.details)) return true;
    return false;
  }

  static bool _mentionsSenior(TeamEventsRecord e) {
    bool textHas(String s) {
      final t = s.toLowerCase();
      return t.contains('senior') ||
          RegExp(r'\bsr\.?\b').hasMatch(t) ||
          t.contains('sr pm') ||
          t.contains('sr group');
    }

    if (textHas(e.title)) return true;
    for (final g in e.appliesToGroups) {
      if (textHas(g)) return true;
    }
    if (textHas(e.details)) return true;
    return false;
  }

  static String _formatDateShort(TeamEventsRecord e) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final s = e.parsedStart;
    if (s == null) {
      return e.startDate.isEmpty ? 'TBD' : e.startDate;
    }
    final wd = weekdays[(s.weekday - 1).clamp(0, 6)];
    final mo = months[(s.month - 1).clamp(0, 11)];
    return '$wd, $mo ${s.day}';
  }

  static String _formatPrimaryTime(TeamEventsRecord e) {
    String fmt(String hhmm) {
      final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(hhmm);
      if (m == null) return hhmm;
      var h = int.parse(m.group(1)!);
      final mins = m.group(2)!;
      final am = h < 12;
      var hh12 = h % 12;
      if (hh12 == 0) hh12 = 12;
      return mins == '00'
          ? '$hh12${am ? 'am' : 'pm'}'
          : '$hh12:$mins${am ? 'am' : 'pm'}';
    }

    final start = e.startTimeLocal.isNotEmpty ? fmt(e.startTimeLocal) : '';
    final end = e.endTimeLocal.isNotEmpty ? fmt(e.endTimeLocal) : '';
    if (start.isEmpty && end.isEmpty) return '';
    if (end.isEmpty) return start;
    return '$start – $end';
  }
}

String humanRecurrence(String rrule) {
  final freqMatch = RegExp(r'FREQ=([A-Z]+)').firstMatch(rrule);
  final byDayMatch = RegExp(r'BYDAY=([A-Z,]+)').firstMatch(rrule);
  final freq = freqMatch?.group(1) ?? '';
  final byDay = byDayMatch?.group(1) ?? '';
  final freqPart = switch (freq) {
    'DAILY' => 'Daily',
    'WEEKLY' => 'Weekly',
    'MONTHLY' => 'Monthly',
    'YEARLY' => 'Yearly',
    _ => 'Recurs',
  };
  if (byDay.isEmpty) return freqPart;
  const map = {
    'MO': 'Mon',
    'TU': 'Tue',
    'WE': 'Wed',
    'TH': 'Thu',
    'FR': 'Fri',
    'SA': 'Sat',
    'SU': 'Sun',
  };
  final pretty = byDay.split(',').map((d) => map[d] ?? d).join(', ');
  return '$freqPart · $pretty';
}
