import 'dart:math' as math;

import '/backend/schema/meet_preferences_record.dart';
import '/backend/schema/monitored_meets_record.dart';
import '/backend/schema/team_events_record.dart';

import 'meet_list_quick_filter.dart';

/// Calendar day for coach-ingest rows — shared with Today timeline meet linking.
DateTime? calendarDayForTeamEventListing(TeamEventsRecord e) =>
    _teamEventCalendarDay(e);

/// Same criteria as [M02MeetWidget] “My Meets” list (`_isMyMeet`): swimmer has a
/// preference row and is entered, new-to-review, needs entry, or actionable pending.
bool monitoredMeetIsOnMyMeetsTab(
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

String _normMeetUrl(String raw) {
  var s = raw.trim().toLowerCase();
  while (s.endsWith('/')) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}

String? _omeNumericMeetIdFromUrl(String raw) {
  final m = RegExp(r'/meets/(\d+)').firstMatch(raw);
  return m?.group(1);
}

/// Calendar day for a team-ingest row — prefers [TeamEventsRecord.parsedStart], else `YYYY-MM-DD`
/// from [TeamEventsRecord.startDate].
DateTime? _teamEventCalendarDay(TeamEventsRecord e) {
  final ps = e.parsedStart;
  if (ps != null) {
    return DateTime(ps.year, ps.month, ps.day);
  }
  final raw = e.startDate.trim();
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(raw);
  if (m == null) return null;
  return DateTime(
    int.parse(m.group(1)!),
    int.parse(m.group(2)!),
    int.parse(m.group(3)!),
  );
}

/// True when [day] (date-only) falls on the monitored meet’s start day, end day, or within its span.
bool _teamEventDayMatchesMonitoredMeet(
  DateTime day,
  MonitoredMeetsRecord m,
) {
  final start = m.startTime;
  final end = m.endTime ?? start;
  final d0 = DateTime(day.year, day.month, day.day);
  if (start != null) {
    final ds = DateTime(start.year, start.month, start.day);
    if (d0 == ds) return true;
  }
  if (end != null) {
    final de = DateTime(end.year, end.month, end.day);
    if (d0 == de) return true;
  }
  if (start != null && end != null) {
    final ds = DateTime(start.year, start.month, start.day);
    final de = DateTime(end.year, end.month, end.day);
    return !d0.isBefore(ds) && !d0.isAfter(de);
  }
  return false;
}

String _alnumCompact(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

/// Cheap edit distance for near-miss titles (e.g. Montclari vs Montclair).
int _levenshteinDistance(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  final la = a.length;
  final lb = b.length;
  final d = List.generate(
    la + 1,
    (i) => List<int>.generate(lb + 1, (j) => i == 0 ? j : (j == 0 ? i : 0)),
  );
  for (var i = 1; i <= la; i++) {
    for (var j = 1; j <= lb; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      d[i][j] = math.min(
        math.min(d[i - 1][j] + 1, d[i][j - 1] + 1),
        d[i - 1][j - 1] + cost,
      );
    }
  }
  return d[la][lb];
}

/// Coach-ingest titles often differ slightly from `monitored_meets.title`.
bool _titlesLikelySameMeet(String teamTitle, String monitoredTitle) {
  String normWords(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  final a = normWords(teamTitle);
  final b = normWords(monitoredTitle);
  if (a.isEmpty || b.isEmpty) return false;
  if (a == b) return true;
  if (a.contains(b) || b.contains(a)) return true;

  final ta =
      a.split(' ').where((t) => t.length > 2).toSet();
  final tb =
      b.split(' ').where((t) => t.length > 2).toSet();
  if (ta.isNotEmpty && tb.isNotEmpty) {
    final inter = ta.intersection(tb).length;
    final denom = ta.length < tb.length ? ta.length : tb.length;
    if (inter >= denom * 0.45) return true;
  }

  final ax = _alnumCompact(teamTitle);
  final bx = _alnumCompact(monitoredTitle);
  if (ax.isEmpty || bx.isEmpty) return false;
  if (ax == bx) return true;
  if (ax.contains(bx) || bx.contains(ax)) return true;
  final maxL = ax.length > bx.length ? ax.length : bx.length;
  if (maxL < 12) return false;
  final d = _levenshteinDistance(ax, bx);
  final allowed = (maxL * 0.14).ceil().clamp(2, 8);
  return d <= allowed;
}

double _titleMatchScore(String teamTitle, String monitoredTitle) {
  if (!_titlesLikelySameMeet(teamTitle, monitoredTitle)) return 0;
  final ta = teamTitle
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .split(RegExp(r'\s+'))
      .where((t) => t.length > 2)
      .toSet();
  final tb = monitoredTitle
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .split(RegExp(r'\s+'))
      .where((t) => t.length > 2)
      .toSet();
  if (ta.isEmpty || tb.isEmpty) {
    final ax = _alnumCompact(teamTitle);
    final bx = _alnumCompact(monitoredTitle);
    if (ax.isEmpty || bx.isEmpty) return 0.01;
    final maxL = ax.length > bx.length ? ax.length : bx.length;
    return 1.0 - _levenshteinDistance(ax, bx) / maxL;
  }
  return ta.intersection(tb).length /
      (ta.length < tb.length ? ta.length : tb.length);
}

/// Links a coach-ingest [TeamEventsRecord] meet row to a [MonitoredMeetsRecord] when possible.
MonitoredMeetsRecord? resolveMonitoredMeetForTeamEventMeet(
  TeamEventsRecord e,
  List<MonitoredMeetsRecord> monitored,
) {
  if (e.eventType != TeamEventType.meet) return null;
  final rawUrl = e.entryUrl.trim();
  if (rawUrl.isNotEmpty) {
    final nu = _normMeetUrl(rawUrl);
    for (final m in monitored) {
      final eu = m.entryUrl.trim();
      if (eu.isNotEmpty && _normMeetUrl(eu) == nu) {
        return m;
      }
    }
    final oid = _omeNumericMeetIdFromUrl(rawUrl);
    if (oid != null) {
      for (final m in monitored) {
        if (m.meetId.trim() == oid) return m;
        if (m.reference.id == oid) return m;
      }
    }
  }

  final day = _teamEventCalendarDay(e);
  final title = e.title.trim();
  if (day != null && title.isNotEmpty) {
    MonitoredMeetsRecord? best;
    var bestScore = 0.0;

    for (final mon in monitored) {
      if (!_teamEventDayMatchesMonitoredMeet(day, mon)) continue;
      final exact =
          mon.name.trim().toLowerCase() == title.toLowerCase();
      if (exact) return mon;
      if (!_titlesLikelySameMeet(title, mon.name)) continue;
      final sc = _titleMatchScore(title, mon.name);
      if (sc > bestScore) {
        bestScore = sc;
        best = mon;
      }
    }
    if (best != null) return best;
  }
  return null;
}

/// When strict URL/title resolution fails, match this team meet to **at most one** monitored meet
/// that is already on the swimmer’s My Meets list — avoids missing the timeline when coach email
/// titles differ from `monitored_meets.title`.
bool _fallbackMatchTeamMeetToMyMeetTab(
  TeamEventsRecord e,
  Map<String, MeetPreferencesRecord> prefs,
  List<MonitoredMeetsRecord> monitored,
) {
  final day = _teamEventCalendarDay(e);
  final title = e.title.trim();
  if (day == null || title.isEmpty) return false;

  MonitoredMeetsRecord? best;
  var bestScore = 0.0;

  for (final cand in monitored) {
    if (!monitoredMeetIsOnMyMeetsTab(cand, prefs[cand.reference.id])) {
      continue;
    }
    if (!_teamEventDayMatchesMonitoredMeet(day, cand)) continue;
    if (!_titlesLikelySameMeet(title, cand.name)) continue;
    final sc = _titleMatchScore(title, cand.name);
    if (sc > bestScore) {
      bestScore = sc;
      best = cand;
    }
  }
  return best != null;
}

/// Schedule Today timeline: show meet rows only when they correspond to a monitored meet
/// on the swimmer’s **My Meets** tab (see [monitoredMeetIsOnMyMeetsTab]).
bool teamEventMeetPassesMyMeetsTimelineFilter(
  TeamEventsRecord e,
  Map<String, MeetPreferencesRecord> prefs,
  List<MonitoredMeetsRecord> monitored,
) {
  if (e.eventType != TeamEventType.meet) return true;
  final m = resolveMonitoredMeetForTeamEventMeet(e, monitored);
  if (m != null && monitoredMeetIsOnMyMeetsTab(m, prefs[m.reference.id])) {
    return true;
  }
  return _fallbackMatchTeamMeetToMyMeetTab(e, prefs, monitored);
}
