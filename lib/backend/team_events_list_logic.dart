import '/backend/schema/team_events_record.dart';

/// Normalize titles so slug-equivalent duplicates dedupe together.
String normalizedEventTitleKey(String title) {
  return title
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _groupsDedupeKey(List<String> groups) {
  final copy = groups.map((g) => g.trim().toUpperCase()).toList()..sort();
  return copy.join('|');
}

/// Firestore keys that collapse obvious duplicate rows (same logical event).
String teamEventDedupeKey(TeamEventsRecord e) {
  return '${e.teamId}|${e.eventType.name}|'
      '${normalizedEventTitleKey(e.title)}|'
      '${e.startDate.trim()}|'
      '${e.startTimeLocal.trim()}|${e.endTimeLocal.trim()}|'
      '${_groupsDedupeKey(e.appliesToGroups)}';
}

TeamEventsRecord _pickBetterDuplicate(TeamEventsRecord a, TeamEventsRecord b) {
  if (b.parsingConfidence != a.parsingConfidence) {
    return b.parsingConfidence > a.parsingConfidence ? b : a;
  }
  final pa = a.processedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  final pb = b.processedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  if (pb.compareTo(pa) != 0) {
    return pb.isAfter(pa) ? b : a;
  }
  return a.docId.compareTo(b.docId) <= 0 ? a : b;
}

/// Keeps one record per logical event so duplicate Firestore docs do not crowd the UI.
List<TeamEventsRecord> dedupeTeamEvents(List<TeamEventsRecord> input) {
  final best = <String, TeamEventsRecord>{};
  for (final e in input) {
    final k = teamEventDedupeKey(e);
    final existing = best[k];
    best[k] =
        existing == null ? e : _pickBetterDuplicate(existing, e);
  }
  return best.values.toList();
}

const _rfcByDayToDartWeekday = <String, int>{
  'MO': DateTime.monday,
  'TU': DateTime.tuesday,
  'WE': DateTime.wednesday,
  'TH': DateTime.thursday,
  'FR': DateTime.friday,
  'SA': DateTime.saturday,
  'SU': DateTime.sunday,
};

List<String> parseRruleByDayCodes(String rrule) {
  final compact = rrule.toUpperCase().replaceAll(' ', '');
  String? segment;
  for (final seg in compact.split(';')) {
    if (seg.startsWith('BYDAY=')) {
      segment = seg.substring('BYDAY='.length);
      break;
    }
  }
  if (segment == null || segment.isEmpty) return const [];

  final codes = <String>[];
  for (final part in segment.split(',')) {
    final token =
        part.replaceAll(RegExp(r'^[\-+]?\d+'), '').trim().toUpperCase();
    if (token.length >= 2) {
      final code = token.substring(0, 2);
      if (_rfcByDayToDartWeekday.containsKey(code)) {
        codes.add(code);
      }
    }
  }
  return codes;
}

bool _rruleWeeklyIntervalIsOne(String rrule) {
  final m =
      RegExp(r'INTERVAL=(\d+)', caseSensitive: false).firstMatch(rrule);
  if (m == null) return true;
  return m.group(1) == '1';
}

DateTime? _dateOnlyFromRecord(TeamEventsRecord e) {
  final ps = e.parsedStart;
  if (ps != null) {
    return DateTime(ps.year, ps.month, ps.day);
  }
  final sd = e.startDate.trim();
  final dm = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(sd);
  if (dm == null) return null;
  return DateTime(
    int.parse(dm.group(1)!),
    int.parse(dm.group(2)!),
    int.parse(dm.group(3)!),
  );
}

DateTime _nextOccurrenceOnOrAfter(DateTime anchorDate, int dartWeekday) {
  final a =
      DateTime(anchorDate.year, anchorDate.month, anchorDate.day);
  var delta = dartWeekday - a.weekday;
  if (delta < 0) {
    delta += 7;
  }
  return a.add(Duration(days: delta));
}

String _formatYmd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

TeamEventsRecord _copyScheduleDay(
  TeamEventsRecord e, {
  required DateTime occurrenceDate,
  required String byDayCode,
}) {
  var parsed = DateTime(
    occurrenceDate.year,
    occurrenceDate.month,
    occurrenceDate.day,
  );
  final ps = e.parsedStart;
  if (ps != null) {
    parsed = DateTime(
      occurrenceDate.year,
      occurrenceDate.month,
      occurrenceDate.day,
      ps.hour,
      ps.minute,
    );
  }

  return TeamEventsRecord(
    reference: e.reference,
    docId: e.docId,
    teamId: e.teamId,
    eventType: e.eventType,
    title: e.title,
    startDate: _formatYmd(parsed),
    endDate: e.endDate,
    startTimeLocal: e.startTimeLocal,
    endTimeLocal: e.endTimeLocal,
    timezone: e.timezone,
    isRecurring: e.isRecurring,
    recurrenceRule: 'FREQ=WEEKLY;BYDAY=$byDayCode',
    appliesToGroups: e.appliesToGroups,
    location: e.location,
    entryDeadline: e.entryDeadline,
    entryUrl: e.entryUrl,
    status: e.status,
    details: e.details,
    parsingConfidence: e.parsingConfidence,
    subject: e.subject,
    sender: e.sender,
    sourceSection: e.sourceSection,
    processedAt: e.processedAt,
    parsedStart: parsed,
  );
}

/// One logical recurring row → one card per weekday for weekly multi-day practices.
List<TeamEventsRecord> expandMultiDayWeeklyTraining(TeamEventsRecord e) {
  if (e.eventType != TeamEventType.training || !e.isRecurring) {
    return [e];
  }
  final rrule = e.recurrenceRule.trim().toUpperCase();
  if (!rrule.contains('FREQ=WEEKLY')) {
    return [e];
  }
  if (!_rruleWeeklyIntervalIsOne(e.recurrenceRule)) {
    return [e];
  }
  final days = parseRruleByDayCodes(e.recurrenceRule);
  if (days.length < 2) {
    return [e];
  }
  final anchor = _dateOnlyFromRecord(e);
  if (anchor == null) {
    return [e];
  }

  return [
    for (final code in days)
      _copyScheduleDay(
        e,
        occurrenceDate: _nextOccurrenceOnOrAfter(
          anchor,
          _rfcByDayToDartWeekday[code]!,
        ),
        byDayCode: code,
      ),
  ];
}

List<TeamEventsRecord> expandScheduleList(List<TeamEventsRecord> input) {
  final out = <TeamEventsRecord>[];
  for (final e in input) {
    out.addAll(expandMultiDayWeeklyTraining(e));
  }
  return out;
}
